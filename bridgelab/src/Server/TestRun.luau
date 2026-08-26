--[[
	TestRun
	-------
	Der Belastungstest einer Arena: Fahrzeuge erzeugen, ueber die Bruecke
	schicken, Kraefte pruefen, Erfolg oder Misserfolg feststellen.

	ABLAUF
	  1. Physik freigeben - die Bruecke traegt ab jetzt ihr eigenes Gewicht.
	  2. Kurzer Countdown. Die Fahrzeuge stehen noch, man sieht schon die
	     Belastungszahlen an jedem Bauteil.
	  3. Die Fahrzeuge fahren los. Wie schnell, bestimmt der Spieler selbst
	     am Tacho - auch waehrend der Fahrt noch.
	  4. Ueberschreitet ein Bauteil seinen Grenzwert, bricht es.
	  5. Bestanden ist erst, wenn ALLE Fahrzeuge ihr Ziel erreicht haben.

	MEHRERE FAHRZEUGE
	Ein Level kann mehrere Fahrzeuge haben - etwa Gegenverkehr auf derselben
	Fahrbahn oder je eines auf zwei uebereinanderliegenden Ebenen. Ihre
	Lasten werden zusammengezaehlt, bevor gerechnet wird. Genau dadurch wird
	die Begegnung in der Mitte zum eigentlichen Problem.

	Die Last wird zweimal gebraucht:
	  - als Zahl fuer den Fachwerk-Rechner (entscheidet ueber Bruch),
	  - als echter Impuls auf die Knotenkugeln, damit sich die Bruecke
	    sichtbar durchbiegt.
]]

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local ForceEngine = require(script.Parent.ForceEngine)

local TestRun = {}
TestRun.__index = TestRun

function TestRun.new(level, origin: Vector3, folders, structure, forceEngine)
	local self = setmetatable({}, TestRun)

	self.level = level
	self.origin = origin
	self.folders = folders
	self.structure = structure
	self.forceEngine = forceEngine

	self.connection = nil
	self.vehicles = {}
	self.running = false
	self.speed = Config.Test.defaultSpeed

	-- Nur Bauteil-Parts werden beim Abtasten der Fahrbahn getroffen.
	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Include
	self.raycastParams.FilterDescendantsInstances = { folders.members }

	-- Die laengste Strecke bestimmt spaeter das Zeitlimit.
	self.longestDistance = 0
	for _, spec in level.vehicles do
		local distance = math.abs(spec.finishX - spec.startX)
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
	local size = spec.size

	local body = Instance.new("Part")
	body.Name = "TestVehicle_" .. spec.index
	body.Size = size
	body.Anchored = true -- waehrend des Countdowns steht es still
	body.CanCollide = true
	body.Material = Enum.Material.Metal
	body.Color = spec.color or Color3.fromRGB(198, 72, 58)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body:SetAttribute("VehicleIndex", spec.index)

	-- Dichte so waehlen, dass die Roblox-Masse der Spielmasse entspricht.
	local volume = size.X * size.Y * size.Z
	body.CustomPhysicalProperties = PhysicalProperties.new(math.clamp(spec.mass / volume, 0.01, 100), 0.7, 0.1, 1, 1)

	-- Nach links fahrende Fahrzeuge werden gedreht, damit das Fahrerhaus vorn ist.
	local facing = if spec.direction > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
	body.CFrame = CFrame.new(
		self.origin + Vector3.new(spec.startX, spec.deckY + size.Y / 2 + 0.25, self.level.z + (spec.laneZ or 0))
	) * facing
	body.Parent = self.folders.vehicle

	-- --- Deko: Fahrerhaus ----------------------------------------------------
	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
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
			wheel.Name = "Wheel"
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
		startY = body.Position.Y,
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
function TestRun:computeVehicleLoads(): { [number]: number }
	local loads: { [number]: number } = {}
	local structure = self.structure

	for _, vehicle in self.vehicles do
		if vehicle.finished or not vehicle.part then
			continue
		end

		local spec = vehicle.spec
		local shareWeight = (spec.mass * Config.Gravity) / 3
		local position = vehicle.part.Position
		local halfLength = spec.size.X / 2

		for i = 1, 3 do
			local t = (i - 1) / 2
			local sampleX = position.X - halfLength + t * spec.size.X
			-- Auf der eigenen Fahrspur nach unten tasten, nicht in der Mitte:
			-- bei Gegenverkehr faehrt jedes Fahrzeug seitlich versetzt.
			local origin = Vector3.new(sampleX, position.Y, position.Z)

			local hit = workspace:Raycast(origin, Vector3.new(0, -(spec.size.Y / 2 + 4), 0), self.raycastParams)
			if hit and hit.Instance then
				local memberId = hit.Instance:GetAttribute("MemberId")
				if memberId then
					local member = structure:findMemberById(memberId)
					if member and not member.broken then
						local posA = structure:nodePosition(member.a)
						local posB = structure:nodePosition(member.b)
						local axis = posB - posA
						local lengthSquared = axis:Dot(axis)
						local fraction = 0.5
						if lengthSquared > 1e-6 then
							fraction = math.clamp((hit.Position - posA):Dot(axis) / lengthSquared, 0, 1)
						end
						loads[member.a] = (loads[member.a] or 0) + shareWeight * (1 - fraction)
						loads[member.b] = (loads[member.b] or 0) + shareWeight * fraction
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
	local nodes = self.structure.nodes
	for snapIndex, newtons in self.currentNodeLoads do
		local node = nodes[snapIndex]
		if node and not node.fixed and not node.part.Anchored then
			local force = newtons * Config.Physics.loadForceScale
			node.part:ApplyImpulse(Vector3.new(0, -force * dt, 0))
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
		local limit = ForceEngine.limitFor(member.kind, member.force)
		if math.abs(member.force) > limit then
			self.brokenMemberKind = Config.PartTypes[member.kind].displayName
			structure:breakMember(member)
			broke = true
		end
	end

	-- Ein Knoten, der seine Last ueberhaupt nicht abtragen kann, bedeutet:
	-- die Konstruktion ist dort nicht ausgesteift. Wir lassen das am staerksten
	-- belastete anhaengende Bauteil versagen, damit man den Fehler sieht.
	if not broke and result.unstable and result.worstNodeIndex then
		local worst = nil
		for _, member in structure:activeMembers() do
			if member.a == result.worstNodeIndex or member.b == result.worstNodeIndex then
				if worst == nil or math.abs(member.force) > math.abs(worst.force) then
					worst = member
				end
			end
		end
		if worst then
			self.brokenMemberKind = Config.PartTypes[worst.kind].displayName
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

	-- 1. Bauteile den Knoten nachfuehren
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
		-- 3. Gleichbleibende Fahrgeschwindigkeit, freier Fall in Y, kein Z-Versatz
		for _, vehicle in self.vehicles do
			if not vehicle.finished and vehicle.part then
				local velocity = vehicle.part.AssemblyLinearVelocity
				vehicle.part.AssemblyLinearVelocity =
					Vector3.new(self.speed * vehicle.spec.direction, velocity.Y, 0)
			end
		end
	end

	-- 4. Last verteilen
	self:applyLoadImpulses(dt)

	-- 5. Kraefte in festem Takt neu rechnen
	self.solveAccumulator += dt
	if self.solveAccumulator >= 1 / Config.Physics.solveRateTest then
		self.solveAccumulator = 0
		self.currentNodeLoads = self:computeVehicleLoads()
		local result = self.forceEngine:evaluate(self.currentNodeLoads)
		self.forceEngine:applyColors()
		self.lastResult = result

		-- Bauteile duerfen erst nach der Schonfrist brechen. Sonst zerstoert
		-- der kurze Ruck beim Loesen der Verankerung sofort etwas.
		if self.driveStartTime and os.clock() - self.driveStartTime > Config.Physics.breakGracePeriod then
			if self:checkForBreaks(result) then
				self:finish(false, string.format("Bauteil gebrochen: %s war ueberlastet.", self.brokenMemberKind or "?"))
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
				timeLimit = self:currentTimeLimit(),
				vehiclesDone = done,
				vehicleCount = #self.vehicles,
			})
		end
	end

	-- Waehrend des Countdowns gelten die Abbruchbedingungen noch nicht.
	if self.countdownLeft > 0 or not self.driveStartTime then
		return
	end

	-- 8. Jedes Fahrzeug einzeln pruefen
	local allFinished = true

	for _, vehicle in self.vehicles do
		if vehicle.finished then
			continue
		end

		local part = vehicle.part
		local spec = vehicle.spec
		local position = part.Position

		-- Ziel erreicht? Je nach Fahrtrichtung von links oder von rechts.
		local goal = self.origin.X + spec.finishX
		local reached = if spec.direction > 0 then position.X >= goal else position.X <= goal
		if reached then
			vehicle.finished = true
			-- Angekommene Fahrzeuge bleiben stehen, statt weiterzurollen.
			part.Anchored = true
			continue
		end

		allFinished = false

		if position.Y < vehicle.startY - self.level.maxDropStuds then
			self:finish(false, string.format(
				"Fahrzeug %d ist mehr als %d Studs abgesackt.",
				spec.index,
				self.level.maxDropStuds
			))
			return
		end

		-- Kippt ein Fahrzeug staerker als etwa 45 Grad, ist der Test gescheitert.
		if part.CFrame.UpVector:Dot(Vector3.yAxis) < 0.7 then
			self:finish(false, string.format("Fahrzeug %d ist gekippt.", spec.index))
			return
		end
	end

	if allFinished then
		if #self.vehicles > 1 then
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

	self.brokenMemberKind = nil
	self.solveAccumulator = 0
	self.labelAccumulator = 0
	self.progressAccumulator = 0
	self.currentNodeLoads = {}
	self.lastResult = nil
	self.countdownLeft = Config.Test.countdownSeconds
	self.driveStartTime = nil

	self.structure:setPhysicsEnabled(true)
	self.structure:setStressLabelsVisible(Config.Test.showStressLabels)

	self.vehicles = {}
	for _, spec in self.level.vehicles do
		table.insert(self.vehicles, self:spawnVehicle(spec))
	end

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
	self.structure:setPhysicsEnabled(false)
	self.structure:setStressLabelsVisible(false)
end

return TestRun
