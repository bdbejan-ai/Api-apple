--[[
	ForceEngine
	-----------
	Bindeglied zwischen dem Bauplan (Structure) und dem Fachwerk-Rechner
	(TrussSolver).

	Aufgaben:
	  1. Aus den aktuellen Bauteilen eine Knoten- und Stabliste bauen.
	  2. Die aeusseren Lasten sammeln (Eigengewicht + Last des Testfahrzeugs).
	  3. Den Rechner aufrufen.
	  4. Ergebnis zurueckgeben: Kraft je Bauteil, Auslastung, instabile Knoten.

	Alles laeuft ausschliesslich auf dem Server. Der Client bekommt nur das
	fertige Ergebnis zu sehen (Farben der Bauteile, Belastungszahlen, Warnung).

	Wie Structure ist auch das hier eine Klasse: jede Arena rechnet fuer sich.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Materials = require(Shared.Materials)
local TrussSolver = require(Shared.TrussSolver)

local ForceEngine = {}
ForceEngine.__index = ForceEngine

function ForceEngine.new(level, structure)
	local self = setmetatable({}, ForceEngine)
	self.level = level
	self.structure = structure
	return self
end

--------------------------------------------------------------------------------
-- Grenzwert eines Bauteils, abhaengig von der Belastungsrichtung
--------------------------------------------------------------------------------

-- Der Grenzwert steht jetzt bei den Baustoffen; hier nur noch durchgereicht.
function ForceEngine.limitFor(material: string, force: number): number
	return Materials.limitFor(material, force)
end

function ForceEngine.utilisation(member): number
	local limit = Materials.limitFor(member.material, member.force)
	return math.abs(member.force) / limit
end

--------------------------------------------------------------------------------
-- Hauptfunktion
--------------------------------------------------------------------------------

--[[
	vehicleLoads (optional): { [Knotenschluessel] = Last in N, positiv = nach unten }

	Rueckgabe:
	{
		solved         = boolean,
		unstable       = boolean,   -- irgendein Knoten kann seine Last nicht abtragen
		worstJointKey  = string?,   -- Schluessel des schlimmsten Knotens
		maxUtilisation = number,
	}
]]
function ForceEngine:evaluate(vehicleLoads: { [number]: number }?)
	local structure = self.structure
	local members = structure:activeMembers()

	if #members == 0 then
		return { solved = true, unstable = false, worstJointKey = nil, maxUtilisation = 0 }
	end

	----------------------------------------------------------------------------
	-- 1. Knotenliste aufbauen (nur Knoten, an denen etwas haengt)
	----------------------------------------------------------------------------

	local isUsed: { [string]: boolean } = {}
	for _, member in members do
		isUsed[member.keyA] = true
		isUsed[member.keyB] = true
	end

	--[[
		Die Knoten liegen in einer Tabelle mit Zeichenketten als Schluessel, und
		die hat keine feste Reihenfolge. Fuer den Rechner wird deshalb erst eine
		SORTIERTE Liste gebaut.

		Das ist kein Schoenheitsfehler: ohne feste Reihenfolge saehe die Matrix
		bei jedem Aufruf anders aus, und die Kraefte wuerden von Bild zu Bild um
		Kleinigkeiten schwanken. Bei Bauteilen dicht am Grenzwert entscheidet
		das darueber, ob etwas bricht - dieselbe Bruecke wuerde mal halten und
		mal nicht.
	]]
	local usedKeys = {}
	for key in isUsed do
		table.insert(usedKeys, key)
	end
	table.sort(usedKeys)

	local solverNodes = {}
	local keyToSolver: { [string]: number } = {}
	local solverToKey: { [number]: string } = {}

	for _, key in usedKeys do
		local joint = structure.joints[key]
		if joint then
			local position = structure:jointPosition(key)
			table.insert(solverNodes, {
				x = position.X - structure.origin.X,
				y = position.Y - structure.origin.Y,
				fixed = joint.fixed,
			})
			local solverIndex = #solverNodes
			keyToSolver[key] = solverIndex
			solverToKey[solverIndex] = key
		end
	end

	----------------------------------------------------------------------------
	-- 2. Stabliste aufbauen
	----------------------------------------------------------------------------

	local solverMembers = {}
	for _, member in members do
		local spec = Materials.get(member.material)
		table.insert(solverMembers, {
			a = keyToSolver[member.keyA],
			b = keyToSolver[member.keyB],
			tensionOnly = not spec.rigid,
		})
	end

	----------------------------------------------------------------------------
	-- 3. Lasten sammeln
	----------------------------------------------------------------------------

	local loads: { [number]: { x: number, y: number } } = {}
	local loadMagnitude: { [number]: number } = {}

	local function addLoad(solverIndex: number, newtonsDown: number)
		local entry = loads[solverIndex]
		if not entry then
			entry = { x = 0, y = 0 }
			loads[solverIndex] = entry
		end
		entry.y -= newtonsDown
		loadMagnitude[solverIndex] = (loadMagnitude[solverIndex] or 0) + math.abs(newtonsDown)
	end

	-- Eigengewicht: jedes Bauteil gibt die Haelfte seiner Masse an jedes Ende ab.
	for _, member in members do
		local spec = Materials.get(member.material)
		local weight = member.length * spec.massPerStud * Config.Gravity
		addLoad(keyToSolver[member.keyA], weight / 2)
		addLoad(keyToSolver[member.keyB], weight / 2)
	end

	-- Last des Testfahrzeugs.
	if vehicleLoads then
		for key, newtons in vehicleLoads do
			local solverIndex = keyToSolver[key]
			if solverIndex then
				addLoad(solverIndex, newtons)
			end
		end
	end

	----------------------------------------------------------------------------
	-- 4. Rechnen lassen
	----------------------------------------------------------------------------

	local result = TrussSolver.solve(solverNodes, solverMembers, loads)

	-- Kraefte uebernehmen und dabei glaetten, damit einzelne Rechenspitzen
	-- kein Bauteil zerstoeren.
	local alpha = Config.Physics.forceSmoothing
	local maxUtilisation = 0
	for index, member in members do
		local newForce = result.forces[index] or 0
		member.force = member.force * (1 - alpha) + newForce * alpha

		--[[
			Ein Seil kann nur ZIEHEN. Muesste es an dieser Stelle druecken,
			nimmt der Rechner es aus der Rechnung heraus - es haengt dann
			einfach durch und traegt nichts. Das merken wir uns am Bauteil,
			damit der Spieler es auch sehen kann.
		]]
		member.slack = result.slack[index] == true

		local utilisation = ForceEngine.utilisation(member)
		if utilisation > maxUtilisation then
			maxUtilisation = utilisation
		end
	end

	----------------------------------------------------------------------------
	-- 5. Instabile Knoten finden
	----------------------------------------------------------------------------

	local unstable = false
	local worstJointKey = nil
	local worstResidual = 0

	--[[
		WOMIT WIRD DIE RESTKRAFT VERGLICHEN?

		Frueher nur mit der aeusseren Last am Knoten. Das ging schief: ein
		Knoten oben im Fachwerk traegt kaum aeussere Last - nur sein bisschen
		Eigengewicht -, waehrend in seinen Bauteilen 700 N stecken. Blieb dort
		eine Restkraft von 40 N stehen, war das gemessen an 20 N Eigengewicht
		riesig, gemessen an 700 N aber ein Rundungsfehler.

		Der Knoten wurde deshalb als "nicht ausgesteift" gemeldet, obwohl vier
		Bauteile daran hingen - und im Test hat das Spiel dort ein voellig
		gesundes Bauteil zerstoert. Fuer den Spieler sah das aus, als bräche
		die Bruecke ohne Grund.

		Verglichen wird jetzt mit dem GROESSEREN von beidem: der aeusseren
		Last und der groessten Kraft in den Bauteilen an diesem Knoten. Eine
		echte Wackelstelle traegt gar nichts ab - dort ist die Restkraft so
		gross wie die Last selbst und faellt weiterhin sofort auf.
	]]
	local strongestAt: { [number]: number } = {}
	for index, member in members do
		local force = math.abs(member.force)
		local a, b = keyToSolver[member.keyA], keyToSolver[member.keyB]
		if a and force > (strongestAt[a] or 0) then
			strongestAt[a] = force
		end
		if b and force > (strongestAt[b] or 0) then
			strongestAt[b] = force
		end
	end

	for solverIndex, residual in result.residuals do
		local reference = math.max(
			loadMagnitude[solverIndex] or 0,
			strongestAt[solverIndex] or 0
		)
		local tolerance = math.max(
			Config.Physics.residualAbsolute,
			reference * Config.Physics.residualRelative
		)
		if residual > tolerance and residual > worstResidual then
			unstable = true
			worstResidual = residual
			worstJointKey = solverToKey[solverIndex]
		end
	end

	return {
		solved = result.solved,
		unstable = unstable,
		worstJointKey = worstJointKey,
		maxUtilisation = maxUtilisation,
	}
end

--------------------------------------------------------------------------------
-- Faerbung und Zahlen
--------------------------------------------------------------------------------

--[[
	Faerbt die Bauteile ein.

	showLoad = true  (waehrend des Tests)
	    Nach Auslastung: gruen = locker, gelb = wird eng, rot = am Limit.
	    Genau darum geht es im Test, also faerben wir alles danach.

	showLoad = false (waehrend des Bauens)
	    In ihrer eigenen Farbe: Stahl, Beton, Seil. Wuerden wir auch hier nach
	    Auslastung faerben, waere im leeren Zustand einfach alles gruen - und
	    man saehe den Bauteilen nicht mehr an, was sie sind.
	    Nur wenn ein Bauteil schon beim blossen Danebenstehen ueber 60 Prozent
	    kommt, blenden wir zur Warnfarbe hinueber. Das ist ein echtes Problem
	    und soll auffallen, bevor der Test ueberhaupt losgeht.
]]
function ForceEngine:applyColors(showLoad: boolean)
	for _, member in self.structure:activeMembers() do
		if not member.stressParts then
			continue
		end

		local spec = Materials.get(member.material)
		local utilisation = ForceEngine.utilisation(member)
		local color

		if member.slack then
			-- Durchhaengendes Seil: blass, damit man sofort sieht, dass es
			-- gerade gar nichts tut.
			color = spec.color:Lerp(Color3.fromRGB(40, 42, 48), 0.55)
		elseif showLoad then
			color = Config.utilisationColor(utilisation)
		elseif utilisation > 0.6 then
			local blend = math.clamp((utilisation - 0.6) / 0.4, 0, 1)
			color = spec.color:Lerp(Config.utilisationColor(utilisation), blend)
		else
			color = spec.color
		end

		for _, part in member.stressParts do
			part.Color = color
		end
	end
end

-- Traegt die aktuellen Kraefte in die Tafeln ueber den Bauteilen ein.
function ForceEngine:updateLabels()
	self.structure:updateStressLabels(ForceEngine.utilisation)
end

return ForceEngine
