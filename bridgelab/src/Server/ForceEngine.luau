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

function ForceEngine.limitFor(kind: string, force: number): number
	local spec = Config.PartTypes[kind]
	if force >= 0 then
		return spec.maxTension
	end
	-- Druck: bei Seilen ist der Grenzwert 0, dort darf gar kein Druck entstehen.
	return math.max(spec.maxCompression, 1e-6)
end

function ForceEngine.utilisation(member): number
	local limit = ForceEngine.limitFor(member.kind, member.force)
	return math.abs(member.force) / limit
end

--------------------------------------------------------------------------------
-- Hauptfunktion
--------------------------------------------------------------------------------

--[[
	vehicleLoads (optional): { [Ankerpunkt-Nummer] = Last in N, positiv = nach unten }

	Rueckgabe:
	{
		solved         = boolean,
		unstable       = boolean,   -- irgendein Knoten kann seine Last nicht abtragen
		worstNodeIndex = number?,   -- Ankerpunkt-Nummer des schlimmsten Knotens
		maxUtilisation = number,
	}
]]
function ForceEngine:evaluate(vehicleLoads: { [number]: number }?)
	local structure = self.structure
	local members = structure:activeMembers()

	if #members == 0 then
		return { solved = true, unstable = false, worstNodeIndex = nil, maxUtilisation = 0 }
	end

	----------------------------------------------------------------------------
	-- 1. Knotenliste aufbauen (nur Ankerpunkte, an denen etwas haengt)
	----------------------------------------------------------------------------

	local isUsed: { [number]: boolean } = {}
	for _, member in members do
		isUsed[member.a] = true
		isUsed[member.b] = true
	end

	local solverNodes = {}
	local snapToSolver: { [number]: number } = {}
	local solverToSnap: { [number]: number } = {}

	-- In fester Reihenfolge durchgehen, damit das Ergebnis reproduzierbar ist.
	for snapIndex = 1, #self.level.snapPoints do
		if isUsed[snapIndex] then
			local position = structure:nodePosition(snapIndex)
			local snap = self.level.snapPoints[snapIndex]
			table.insert(solverNodes, {
				x = position.X,
				y = position.Y,
				fixed = snap.fixed,
			})
			local solverIndex = #solverNodes
			snapToSolver[snapIndex] = solverIndex
			solverToSnap[solverIndex] = snapIndex
		end
	end

	----------------------------------------------------------------------------
	-- 2. Stabliste aufbauen
	----------------------------------------------------------------------------

	local solverMembers = {}
	for _, member in members do
		local spec = Config.PartTypes[member.kind]
		table.insert(solverMembers, {
			a = snapToSolver[member.a],
			b = snapToSolver[member.b],
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
		local spec = Config.PartTypes[member.kind]
		local length = (structure:nodePosition(member.b) - structure:nodePosition(member.a)).Magnitude
		local weight = length * spec.massPerStud * Config.Gravity
		addLoad(snapToSolver[member.a], weight / 2)
		addLoad(snapToSolver[member.b], weight / 2)
	end

	-- Last des Testfahrzeugs.
	if vehicleLoads then
		for snapIndex, newtons in vehicleLoads do
			local solverIndex = snapToSolver[snapIndex]
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
	local worstNodeIndex = nil
	local worstResidual = 0

	for solverIndex, residual in result.residuals do
		local tolerance = math.max(
			Config.Physics.residualAbsolute,
			(loadMagnitude[solverIndex] or 0) * Config.Physics.residualRelative
		)
		if residual > tolerance and residual > worstResidual then
			unstable = true
			worstResidual = residual
			worstNodeIndex = solverToSnap[solverIndex]
		end
	end

	return {
		solved = result.solved,
		unstable = unstable,
		worstNodeIndex = worstNodeIndex,
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

		local spec = Config.PartTypes[member.kind]
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
