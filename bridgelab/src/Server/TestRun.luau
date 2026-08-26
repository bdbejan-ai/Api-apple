--[[
	TestRun
	-------
	Der Belastungstest einer Arena: Fahrzeuge erzeugen, ueber die Bruecke
	schicken, Kraefte pruefen, Erfolg oder Misserfolg feststellen.

	ABLAUF
	  1. Physik freigeben - die Bruecke traegt ab jetzt ihr eigenes Gewicht.
	  2. Kurzer Countdown. Die Fahrzeuge stehen noch, man sieht schon die
	     Belastungszahlen an den am staerksten belasteten Bauteilen.
	  3. Die Fahrzeuge fahren los. Wie schnell, bestimmt der Spieler selbst
	     am Tacho - auch waehrend der Fahrt noch.
	  4. Ueberschreitet ein Bauteil seinen Grenzwert, bricht es.
	  5. Bestanden ist erst, wenn ALLE Fahrzeuge ihr Ziel erreicht haben -
	     und, falls das Level ein Schiff hat, auch dieses durch ist.

	MEHRERE FAHRZEUGE
	Ein Level kann mehrere Fahrzeuge haben - etwa Gegenverkehr auf derselben
	Fahrbahn oder je eines auf zwei uebereinanderliegenden Ebenen. Ihre
	Lasten werden zusammengezaehlt, bevor gerechnet wird. Genau dadurch wird
	die Begegnung in der Mitte zum eigentlichen Problem.

	DREI SONDERFAELLE
	  Hydraulik  Zylinder fahren auf Knopfdruck aus. Damit lassen sich
	             Klappbruecken bauen, die sich fuer ein Schiff oeffnen.
	  Schiff     faehrt auf dem Wasser durch. Steht die Bruecke im Weg, ist
	             der Test gescheitert - auch wenn kein Bauteil gebrochen ist.
	  Sprung     das Fahrzeug verlaesst die Rampe und fliegt. Waehrend des
	             Flugs gelten andere Regeln (siehe unten).

	Die Last wird zweimal gebraucht:
	  - als Zahl fuer den Fachwerk-Rechner (entscheidet ueber Bruch),
	  - als echter Impuls auf die Knotenkugeln, damit sich die Bruecke
	    sichtbar durchbiegt.
]]

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Materials = require(Shared.Materials)

local ForceEngine = require(script.Parent.ForceEngine)

local TestRun = {}
TestRun.__index = TestRun

--------------------------------------------------------------------------------
-- Umrechnung der Leveldaten
--------------------------------------------------------------------------------

--[[
	Levels.luau kommt bewusst ohne Roblox-Typen aus, damit das Pruefskript in
	tools/ die echten Leveldaten lesen kann. Groesse und Farbe stehen dort
	deshalb als schlichte Tabellen. Hier werden sie zu echten Roblox-Werten.
]]
local function toVector3(size): Vector3
	return Vector3.new(size.X, size.Y, size.Z)
end

local function toColor3(color): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

function TestRun.new(level, origin: Vector3, folders, structure, forceEngine)
	local self = setmetatable({}, TestRun)

	self.level = level
	self.origin = origin
	self.folders = folders
	self.structure = structure
	self.forceEngine = forceEngine

	self.connection = nil
	self.vehicles = {}
	self.boat = nil
	self.running = false
	self.speed = Config.Test.defaultSpeed
	self.phase = 0

	-- Nur Bauteil-Parts werden beim Abtasten der Fahrbahn getroffen.
	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Include
	self.raycastParams.FilterDescendantsInstances = { folders.members }

	-- Die laengste Strecke bestimmt spaeter das Zeitlimit.
	self.longestDistance = 0
	for _, spec in level.vehicles do
		local distance = math.abs(spec.toX - spec.fromX)
		if distance > self.longestDistance then
			self.longestDistance = distance
		end
	end

	return self
end

--------------------------------------------------------------------------------
-- Fahrzeuge
--------------------------------------------------------------------------------

--[[
	Ein Fahrzeug ist EIN Physikkoerper. Fahrerhaus und Raeder sind nur
	angeschweisste Deko und tragen keine Masse (Massless = true), damit die
	Rechnung von oben (Masse aus dem Level) exakt stimmt.
]]
function TestRun:spawnVehicle(spec)
	local size = toVector3(spec.size)

	local body = Instance.new("Part")
	body.Name = "TestVehicle_" .. spec.index
	body.Size = size
	body.Anchored = true -- waehrend des Countdowns steht es still
	body.CanCollide = true
	body.Material = Enum.Material.Metal
	body.Color = toColor3(spec.color)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body:SetAttribute("VehicleIndex", spec.index)

	-- Dichte so waehlen, dass die Roblox-Masse der Spielmasse entspricht.
	local volume = size.X * size.Y * size.Z
	body.CustomPhysicalProperties = PhysicalProperties.new(math.clamp(spec.mass / volume, 0.01, 100), 0.7, 0.1, 1, 1)

	-- Nach links fahrende Fahrzeuge werden gedreht, damit das Fahrerhaus vorn ist.
	local facing = if spec.direction > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
	body.CFrame = CFrame.new(
		self.origin
			+ Vector3.new(spec.fromX, spec.startY + size.Y / 2 + 0.25, (self.level.z or 0) + (spec.laneZ or 0))
	) * facing
	body.Parent = self.folders.vehicles

	-- --- Deko: Fahrerhaus ----------------------------------------------------
	local cabin = Instance.new("Part")
	cabin.Name = "Fahrerhaus"
	cabin.Size = Vector3.new(size.X * 0.4, size.Y * 0.7, size.Z * 0.9)
	cabin.CFrame = body.CFrame * CFrame.new(size.X * 0.28, size.Y * 0.82, 0)
	cabin.Color = Color3.fromRGB(226, 226, 232)
	cabin.Material = Enum.Material.Metal
	cabin.Massless = true
	cabin.CanCollide = false
	cabin.CanQuery = false
	cabin.TopSurface = Enum.SurfaceType.Smooth
	cabin.BottomSurface = Enum.SurfaceType.Smooth
	cabin.Parent = body

	local cabinWeld = Instance.new("WeldConstraint")
	cabinWeld.Part0 = body
	cabinWeld.Part1 = cabin
	cabinWeld.Parent = body

	-- --- Deko: Raeder --------------------------------------------------------
	for _, offsetX in { -size.X * 0.3, size.X * 0.3 } do
		for _, offsetZ in { -size.Z / 2, size.Z / 2 } do
			local wheel = Instance.new("Part")
			wheel.Name = "Rad"
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(0.6, 2.2, 2.2)
			-- Cylinder liegt in Roblox auf der X-Achse: einmal quer drehen.
			wheel.CFrame = body.CFrame
				* CFrame.new(offsetX, -size.Y / 2, offsetZ)
				* CFrame.Angles(0, math.rad(90), 0)
			wheel.Color = Color3.fromRGB(32, 32, 36)
			wheel.Material = Enum.Material.Rubber
			wheel.Massless = true
			wheel.CanCollide = false
			wheel.CanQuery = false
			wheel.Parent = body

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = wheel
			weld.Parent = body
		end
	end

	return {
		spec = spec,
		part = body,
		size = size,
		startY = body.Position.Y,
		--[[
			Der tiefste noch erlaubte Punkt. Gemessen wird ab der NIEDRIGEREN
			der beiden Seiten, nicht ab der Starthoehe: bei einem Sprung von
			einem hohen auf ein tieferes Ufer ist ein Absacken um genau diesen
			Hoehenunterschied ja gerade das Ziel und kein Fehler.
		]]
		floorY = self.origin.Y + math.min(spec.startY, spec.finishY) - self.level.maxDropStuds,
		finished = false,
	}
end

function TestRun:despawnVehicles()
	for _, vehicle in self.vehicles do
		if vehicle.part then
			vehicle.part:Destroy()
		end
	end
	self.vehicles = {}
end

--------------------------------------------------------------------------------
-- Schiff
--------------------------------------------------------------------------------

--[[
	Manche Level verlangen, dass ein Schiff unter der Bruecke durchfaehrt.
	Dann reicht es nicht, dass die Bruecke haelt - sie muss sich auch oeffnen.

	Das Schiff ist bewusst KEIN Physikkoerper: es wird Bild fuer Bild gesetzt.
	Ein anstossendes Schiff soll die Bruecke nicht wegschieben, sondern den
	Test scheitern lassen. Geprueft wird das rechnerisch, nicht ueber
	Beruehrungen - so gibt es keine Zufaelle durch die Physik-Engine.
]]
function TestRun:spawnBoat()
	local boat = self.level.boat
	if not boat then
		return nil
	end

	local size = Vector3.new(boat.length or 18, boat.height or 14, 8)

	local hull = Instance.new("Part")
	hull.Name = "Schiff"
	hull.Size = Vector3.new(size.X, 4, size.Z)
	hull.Anchored = true
	hull.CanCollide = false
	hull.CanQuery = false
	hull.CanTouch = false
	hull.Color = Color3.fromRGB(188, 78, 66)
	hull.Material = Enum.Material.Metal
	hull.Parent = self.folders.vehicles

	local mast = Instance.new("Part")
	mast.Name = "Mast"
	mast.Size = Vector3.new(0.8, size.Y - 4, 0.8)
	mast.Anchored = true
	mast.CanCollide = false
	mast.CanQuery = false
	mast.CanTouch = false
	mast.Color = Color3.fromRGB(228, 228, 232)
	mast.Material = Enum.Material.Metal
	mast.Parent = self.folders.vehicles

	return {
		spec = boat,
		hull = hull,
		mast = mast,
		size = size,
		x = boat.fromX,
		direction = if boat.toX >= boat.fromX then 1 else -1,
		finished = false,
	}
end

function TestRun:updateBoat(dt: number)
	local boat = self.boat
	if not boat or boat.finished then
		return
	end

	local spec = boat.spec
	local speed = spec.speed or 6
	boat.x += speed * boat.direction * dt

	local waterY = self.level.waterY or 0
	local z = self.level.z or 0
	local centre = self.origin + Vector3.new(boat.x, waterY, z)

	boat.hull.CFrame = CFrame.new(centre + Vector3.new(0, 1, 0))
	boat.mast.CFrame = CFrame.new(centre + Vector3.new(0, 2 + (boat.size.Y - 4) / 2, 0))

	local reached = if boat.direction > 0 then boat.x >= spec.toX else boat.x <= spec.toX
	if reached then
		boat.finished = true
	end
end

--[[
	Steht die Bruecke dem Schiff im Weg?

	Geprueft wird, ob ein Bauteil das Rechteck schneidet, das das Schiff
	beim Durchfahren einnimmt. Weil beides in der Seitenansicht liegt,
	genuegt eine ebene Rechnung: Strecke gegen Rechteck.
]]
local function segmentHitsBox(ax, ay, bx, by, minX, minY, maxX, maxY): boolean
	-- Liegt ein Endpunkt drin, ist die Sache klar.
	local function inside(x, y)
		return x >= minX and x <= maxX and y >= minY and y <= maxY
	end
	if inside(ax, ay) or inside(bx, by) then
		return true
	end

	--[[
		Sonst wird die Strecke am Rechteck abgeschnitten (Liang-Barsky).
		t laeuft von 0 (Punkt A) bis 1 (Punkt B); bleibt davon ein Stueck
		uebrig, schneidet die Strecke das Rechteck.
	]]
	local dx, dy = bx - ax, by - ay
	local t0, t1 = 0, 1

	local function clip(p: number, q: number): boolean
		if math.abs(p) < 1e-9 then
			-- Strecke verlaeuft parallel zu dieser Kante.
			return q >= 0
		end
		local r = q / p
		if p < 0 then
			if r > t1 then
				return false
			end
			t0 = math.max(t0, r)
		else
			if r < t0 then
				return false
			end
			t1 = math.min(t1, r)
		end
		return true
	end

	if not clip(-dx, ax - minX) then return false end
	if not clip(dx, maxX - ax) then return false end
	if not clip(-dy, ay - minY) then return false end
	if not clip(dy, maxY - ay) then return false end

	return t0 <= t1
end

function TestRun:boatIsBlocked(): boolean
	local boat = self.boat
	if not boat or boat.finished then
		return false
	end

	local clearance = boat.spec.clearance or 1
	local minX = boat.x - boat.size.X / 2 - clearance
	local maxX = boat.x + boat.size.X / 2 + clearance
	local minY = (self.level.waterY or 0) - 1
	local maxY = minY + boat.size.Y + clearance

	local structure = self.structure
	for _, member in structure:activeMembers() do
		-- In Levelkoordinaten rechnen, also ohne den Arena-Versatz.
		local posA = structure:jointPosition(member.keyA) - self.origin
		local posB = structure:jointPosition(member.keyB) - self.origin
		if segmentHitsBox(posA.X, posA.Y, posB.X, posB.Y, minX, minY, maxX, maxY) then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Hydraulik
--------------------------------------------------------------------------------

--[[
	Die Zylinder gehoeren zu Phasen. Phase 0 heisst: alles eingefahren.
	Schaltet der Spieler auf Phase n weiter, sind alle Zylinder mit
	member.phase <= n ausgefahren, alle anderen eingefahren.

	Gefahren wird nicht sprunghaft, sondern ueber Config.Hydraulics.
	travelSeconds hinweg. Ein Sprung wuerde die Physik-Engine ruckartig
	auseinanderreissen und die halbe Bruecke wegschleudern.
]]
function TestRun:setPhase(phase: number)
	self.phase = math.clamp(math.round(phase), 0, Config.Hydraulics.phaseCount)
end

function TestRun:updateHydraulics(dt: number)
	local extend = Config.Hydraulics.extendFactor
	local rate = (extend - 1) / math.max(Config.Hydraulics.travelSeconds, 0.05)

	for _, member in self.structure:hydraulicMembers() do
		local target = if (member.phase or 1) <= self.phase then extend else 1
		local current = member.extension or 1

		if math.abs(target - current) < 1e-3 then
			continue
		end

		local step = rate * dt
		if target > current then
			current = math.min(target, current + step)
		else
			current = math.max(target, current - step)
		end
		self.structure:setHydraulicExtension(member, current)
	end
end

--------------------------------------------------------------------------------
-- Last der Fahrzeuge auf die Knoten verteilen
--------------------------------------------------------------------------------

--[[
	Jedes Fahrzeug tastet an drei Stellen (hinten, Mitte, vorne) nach unten ab.
	Jede Stelle traegt ein Drittel seines Gewichts. Wird dort ein Bauteil
	getroffen, wird dieses Drittel auf die beiden Endknoten des Bauteils
	verteilt - je naeher am Knoten, desto mehr bekommt er ab.

	Die Lasten ALLER Fahrzeuge landen in derselben Tabelle. Stehen zwei
	Fahrzeuge uebereinander oder nebeneinander, addieren sich ihre Lasten
	an denselben Knoten - genau das macht Gegenverkehr gefaehrlich.
]]
function TestRun:computeVehicleLoads(): { [string]: number }
	local loads: { [string]: number } = {}
	local structure = self.structure

	for _, vehicle in self.vehicles do
		if vehicle.finished or not vehicle.part then
			continue
		end

		local spec = vehicle.spec
		local shareWeight = (spec.mass * Config.Gravity) / 3
		local position = vehicle.part.Position
		local halfLength = vehicle.size.X / 2

		for i = 1, 3 do
			local t = (i - 1) / 2
			local sampleX = position.X - halfLength + t * vehicle.size.X
			-- Auf der eigenen Fahrspur nach unten tasten, nicht in der Mitte:
			-- bei Gegenverkehr faehrt jedes Fahrzeug seitlich versetzt.
			local rayOrigin = Vector3.new(sampleX, position.Y, position.Z)

			local hit = workspace:Raycast(rayOrigin, Vector3.new(0, -(vehicle.size.Y / 2 + 4), 0), self.raycastParams)
			if hit and hit.Instance then
				local memberId = hit.Instance:GetAttribute("MemberId")
				if memberId then
					local member = structure:findMemberById(memberId)
					if member and not member.broken then
						local posA = structure:jointPosition(member.keyA)
						local posB = structure:jointPosition(member.keyB)
						local axis = posB - posA
						local lengthSquared = axis:Dot(axis)
						local fraction = 0.5
						if lengthSquared > 1e-6 then
							fraction = math.clamp((hit.Position - posA):Dot(axis) / lengthSquared, 0, 1)
						end
						loads[member.keyA] = (loads[member.keyA] or 0) + shareWeight * (1 - fraction)
						loads[member.keyB] = (loads[member.keyB] or 0) + shareWeight * fraction
					end
				end
			end
		end
	end

	return loads
end

-- Dieselbe Last als echten Impuls auf die Knotenkugeln geben, damit sich die
-- Konstruktion sichtbar durchbiegt.
function TestRun:applyLoadImpulses(dt: number)
	local joints = self.structure.joints
	for key, newtons in self.currentNodeLoads do
		local joint = joints[key]
		if joint and not joint.fixed and not joint.part.Anchored then
			local force = newtons * Config.Physics.loadForceScale
			joint.part:ApplyImpulse(Vector3.new(0, -force * dt, 0))
		end
	end
end

--------------------------------------------------------------------------------
-- Bruchpruefung
--------------------------------------------------------------------------------

function TestRun:checkForBreaks(result): boolean
	local structure = self.structure
	local broke = false

	for _, member in structure:activeMembers() do
		local limit = Materials.limitFor(member.material, member.force)
		if math.abs(member.force) > limit then
			self.brokenMaterial = Materials.get(member.material).displayName
			structure:breakMember(member)
			broke = true
		end
	end

	-- Ein Knoten, der seine Last ueberhaupt nicht abtragen kann, bedeutet:
	-- die Konstruktion ist dort nicht ausgesteift. Wir lassen das am staerksten
	-- belastete anhaengende Bauteil versagen, damit man den Fehler sieht.
	if not broke and result.unstable and result.worstJointKey then
		local worst = nil
		for _, member in structure:activeMembers() do
			if member.keyA == result.worstJointKey or member.keyB == result.worstJointKey then
				if worst == nil or math.abs(member.force) > math.abs(worst.force) then
					worst = member
				end
			end
		end
		if worst then
			self.brokenMaterial = Materials.get(worst.material).displayName
			structure:breakMember(worst)
			broke = true
		end
	end

	return broke
end

--------------------------------------------------------------------------------
-- Ein Simulationsschritt
--------------------------------------------------------------------------------

function TestRun:finish(success: boolean, reason: string)
	local callback = self.onFinished
	self:stop()
	if callback then
		callback(success, reason)
	end
end

-- Zeitlimit richtet sich nach der gewaehlten Geschwindigkeit: langsam fahren
-- darf nie zum Scheitern fuehren.
function TestRun:currentTimeLimit(): number
	return self.longestDistance / math.max(self.speed, 0.1) * 2 + 15
end

function TestRun:step(dt: number)
	if #self.vehicles == 0 then
		return
	end

	-- 1. Hydraulik bewegen und Bauteile den Knoten nachfuehren
	self:updateHydraulics(dt)
	self.structure:updateAllVisuals()

	-- 2. Countdown: die Fahrzeuge stehen noch, die Bruecke setzt sich bereits.
	if self.countdownLeft > 0 then
		self.countdownLeft -= dt
		if self.countdownLeft <= 0 then
			for _, vehicle in self.vehicles do
				vehicle.part.Anchored = false
			end
			self.driveStartTime = os.clock()
		end
	else
		--[[
			Gleichbleibende Fahrgeschwindigkeit in X, freier Fall in Y.

			In X wird die Geschwindigkeit fest vorgegeben, damit die Fahrt
			berechenbar bleibt - auch waehrend eines Sprungs. In Y greift
			die Physik-Engine: dadurch faellt das Fahrzeug in eine Luecke,
			landet nach einem Sprung und wackelt auf einer weichen Bruecke.
		]]
		for _, vehicle in self.vehicles do
			if not vehicle.finished and vehicle.part then
				local velocity = vehicle.part.AssemblyLinearVelocity
				vehicle.part.AssemblyLinearVelocity =
					Vector3.new(self.speed * vehicle.spec.direction, velocity.Y, 0)
			end
		end
	end

	-- 3. Schiff bewegen
	self:updateBoat(dt)

	-- 4. Last verteilen
	self:applyLoadImpulses(dt)

	-- 5. Kraefte in festem Takt neu rechnen
	self.solveAccumulator += dt
	if self.solveAccumulator >= 1 / Config.Physics.solveRateTest then
		self.solveAccumulator = 0
		self.currentNodeLoads = self:computeVehicleLoads()
		local result = self.forceEngine:evaluate(self.currentNodeLoads)
		-- Im Test zaehlt die Belastung, also faerben wir danach ein.
		self.forceEngine:applyColors(true)
		self.lastResult = result

		-- Bauteile duerfen erst nach der Schonfrist brechen. Sonst zerstoert
		-- der kurze Ruck beim Loesen der Verankerung sofort etwas.
		if self.driveStartTime and os.clock() - self.driveStartTime > Config.Physics.breakGracePeriod then
			if self:checkForBreaks(result) then
				self:finish(false, string.format("Bauteil gebrochen: %s war ueberlastet.", self.brokenMaterial or "?"))
				return
			end
		end
	end

	-- 6. Zahlen an den Bauteilen langsamer aktualisieren als gerechnet wird,
	--    sonst flackern sie unlesbar.
	self.labelAccumulator += dt
	if self.labelAccumulator >= 1 / Config.Test.labelUpdateRate then
		self.labelAccumulator = 0
		self.forceEngine:updateLabels()
	end

	-- 7. Fortschritt melden (fuer die Anzeige beim Spieler)
	self.progressAccumulator += dt
	if self.progressAccumulator >= 0.2 then
		self.progressAccumulator = 0
		if self.onProgress then
			local done = 0
			for _, vehicle in self.vehicles do
				if vehicle.finished then
					done += 1
				end
			end
			self.onProgress({
				countdown = math.max(self.countdownLeft, 0),
				elapsed = if self.driveStartTime then os.clock() - self.driveStartTime else 0,
				maxUtilisation = if self.lastResult then self.lastResult.maxUtilisation else 0,
				speed = self.speed,
				phase = self.phase,
				timeLimit = self:currentTimeLimit(),
				vehiclesDone = done,
				vehicleCount = #self.vehicles,
				boatDone = if self.boat then self.boat.finished else nil,
			})
		end
	end

	-- Waehrend des Countdowns gelten die Abbruchbedingungen noch nicht.
	if self.countdownLeft > 0 or not self.driveStartTime then
		return
	end

	-- 8. Steht die Bruecke dem Schiff im Weg?
	if self:boatIsBlocked() then
		self:finish(false, "Das Schiff kommt nicht durch - die Bruecke steht im Weg.")
		return
	end

	-- 9. Jedes Fahrzeug einzeln pruefen
	local allFinished = true

	for _, vehicle in self.vehicles do
		if vehicle.finished then
			continue
		end

		local part = vehicle.part
		local spec = vehicle.spec
		local position = part.Position

		-- Ziel erreicht? Je nach Fahrtrichtung von links oder von rechts.
		local goal = self.origin.X + spec.toX
		local reached = if spec.direction > 0 then position.X >= goal else position.X <= goal
		if reached then
			vehicle.finished = true
			-- Angekommene Fahrzeuge bleiben stehen, statt weiterzurollen.
			part.Anchored = true
			continue
		end

		allFinished = false

		if position.Y < vehicle.floorY then
			self:finish(false, string.format("Fahrzeug %d ist abgestuerzt.", spec.index))
			return
		end

		--[[
			Kippt ein Fahrzeug staerker als etwa 45 Grad, ist der Test
			gescheitert - ABER nicht waehrend eines Sprungs. In der Luft
			dreht sich ein Fahrzeug voellig normal, und ein Sprunglevel
			waere sonst gar nicht zu schaffen. Als "in der Luft" gilt, wer
			sich senkrecht deutlich bewegt.
		]]
		local airborne = math.abs(part.AssemblyLinearVelocity.Y) > 8
		if not airborne and part.CFrame.UpVector:Dot(Vector3.yAxis) < 0.7 then
			self:finish(false, string.format("Fahrzeug %d ist gekippt.", spec.index))
			return
		end
	end

	-- 10. Erst wenn alles durch ist, ist der Test bestanden.
	local boatPending = self.boat ~= nil and not self.boat.finished

	if allFinished and not boatPending then
		if self.boat then
			self:finish(true, "Geschafft! Fahrzeug und Schiff sind durchgekommen.")
		elseif #self.vehicles > 1 then
			self:finish(true, "Geschafft! Alle Fahrzeuge sind angekommen.")
		else
			self:finish(true, "Geschafft! Das Fahrzeug hat die andere Seite erreicht.")
		end
		return
	end

	if os.clock() - self.driveStartTime > self:currentTimeLimit() then
		self:finish(false, "Zeitlimit ueberschritten.")
		return
	end
end

--------------------------------------------------------------------------------
-- Oeffentliche Schnittstelle
--------------------------------------------------------------------------------

function TestRun:isRunning(): boolean
	return self.running
end

-- Geschwindigkeit am Tacho veraendern - auch waehrend der Fahrt erlaubt.
function TestRun:setSpeed(speed: number)
	self.speed = math.clamp(speed, Config.Test.minSpeed, Config.Test.maxSpeed)
end

function TestRun:start(speed: number, onProgress, onFinished)
	if self.running then
		return
	end

	self.running = true
	self.onProgress = onProgress
	self.onFinished = onFinished
	self:setSpeed(speed)

	self.brokenMaterial = nil
	self.solveAccumulator = 0
	self.labelAccumulator = 0
	self.progressAccumulator = 0
	self.currentNodeLoads = {}
	self.lastResult = nil
	self.countdownLeft = Config.Test.countdownSeconds
	self.driveStartTime = nil
	self.phase = 0

	-- Alle Zylinder beginnen eingefahren.
	for _, member in self.structure:hydraulicMembers() do
		self.structure:setHydraulicExtension(member, 1)
	end

	self.structure:setPhysicsEnabled(true)
	self.structure:setStressLabelsActive(true)

	self.vehicles = {}
	for _, spec in self.level.vehicles do
		table.insert(self.vehicles, self:spawnVehicle(spec))
	end
	self.boat = self:spawnBoat()

	self.connection = RunService.Heartbeat:Connect(function(dt)
		self:step(dt)
	end)
end

function TestRun:stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	self.running = false
	self.onProgress = nil
	self.onFinished = nil
	self:despawnVehicles()
	if self.boat then
		self.boat.hull:Destroy()
		self.boat.mast:Destroy()
		self.boat = nil
	end
	self.phase = 0
	self.structure:setPhysicsEnabled(false)
	self.structure:setStressLabelsActive(false)
end

return TestRun
