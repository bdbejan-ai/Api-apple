--[[
	TestRun
	-------
	Der Belastungstest einer Arena: Fahrzeug erzeugen, ueber die Bruecke
	schicken, Kraefte pruefen, Erfolg oder Misserfolg feststellen.

	ABLAUF
	  1. Physik freigeben - die Bruecke traegt ab jetzt ihr eigenes Gewicht.
	  2. Kurzer Countdown. Das Fahrzeug steht noch, man sieht schon die
	     Belastungszahlen an jedem Bauteil.
	  3. Das Fahrzeug faehrt mit konstanter, bewusst langsamer Geschwindigkeit
	     los. Waehrend der Fahrt wird laufend nachgerechnet.
	  4. Ueberschreitet ein Bauteil seinen Grenzwert, bricht es.
	  5. Erfolg (Ziel erreicht) oder Misserfolg (Bruch, Absturz, Kippen, Zeit).

	Die Last wird dabei zweimal gebraucht:
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
	self.vehicle = nil
	self.running = false

	-- Nur Bauteil-Parts werden beim Abtasten der Fahrbahn getroffen.
	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Include
	self.raycastParams.FilterDescendantsInstances = { folders.members }

	return self
end

--------------------------------------------------------------------------------
-- Fahrzeug
--------------------------------------------------------------------------------

--[[
	Das Fahrzeug ist EIN Physikkoerper. Fahrerhaus und Raeder sind nur
	angeschweisste Deko und tragen keine Masse (Massless = true), damit die
	Rechnung von oben (Masse 1000) exakt stimmt.
]]
function TestRun:spawnVehicle()
	local spec = self.level.vehicle
	local level = self.level

	local body = Instance.new("Part")
	body.Name = "TestVehicle"
	body.Size = spec.size
	body.Anchored = true -- waehrend des Countdowns steht es still
	body.CanCollide = true
	body.Material = Enum.Material.Metal
	body.Color = Color3.fromRGB(198, 72, 58)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth

	-- Dichte so waehlen, dass die Roblox-Masse der Spielmasse entspricht.
	local volume = spec.size.X * spec.size.Y * spec.size.Z
	local density = math.clamp(spec.mass / volume, 0.01, 100)
	body.CustomPhysicalProperties = PhysicalProperties.new(density, 0.7, 0.1, 1, 1)

	body.CFrame = CFrame.new(self.origin + Vector3.new(spec.startX, level.deckY + spec.size.Y / 2 + 0.25, level.z))
	body.Parent = self.folders.vehicle

	-- --- Deko: Fahrerhaus ----------------------------------------------------
	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(spec.size.X * 0.4, spec.size.Y * 0.7, spec.size.Z * 0.9)
	cabin.CFrame = body.CFrame * CFrame.new(spec.size.X * 0.28, spec.size.Y * 0.82, 0)
	cabin.Color = Color3.fromRGB(226, 226, 232)
	cabin.Material = Enum.Material.Metal
	cabin.Massless = true
	cabin.CanCollide = false
	cabin.TopSurface = Enum.SurfaceType.Smooth
	cabin.BottomSurface = Enum.SurfaceType.Smooth
	cabin.Parent = body

	local cabinWeld = Instance.new("WeldConstraint")
	cabinWeld.Part0 = body
	cabinWeld.Part1 = cabin
	cabinWeld.Parent = body

	-- --- Deko: Raeder --------------------------------------------------------
	for _, offsetX in { -spec.size.X * 0.3, spec.size.X * 0.3 } do
		for _, offsetZ in { -spec.size.Z / 2, spec.size.Z / 2 } do
			local wheel = Instance.new("Part")
			wheel.Name = "Wheel"
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(0.6, 2.2, 2.2)
			-- Cylinder liegt in Roblox auf der X-Achse: einmal quer drehen.
			wheel.CFrame = body.CFrame
				* CFrame.new(offsetX, -spec.size.Y / 2, offsetZ)
				* CFrame.Angles(0, math.rad(90), 0)
			wheel.Color = Color3.fromRGB(32, 32, 36)
			wheel.Material = Enum.Material.Rubber
			wheel.Massless = true
			wheel.CanCollide = false
			wheel.Parent = body

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = wheel
			weld.Parent = body
		end
	end

	self.vehicle = body
	self.startY = body.Position.Y
	return body
end

function TestRun:despawnVehicle()
	if self.vehicle then
		self.vehicle:Destroy()
		self.vehicle = nil
	end
end

--------------------------------------------------------------------------------
-- Last des Fahrzeugs auf die Knoten verteilen
--------------------------------------------------------------------------------

--[[
	Das Fahrzeug tastet an drei Stellen (hinten, Mitte, vorne) nach unten ab.
	Jede Stelle traegt ein Drittel des Gesamtgewichts. Wird dort ein Bauteil
	getroffen, wird dieses Drittel auf die beiden Endknoten des Bauteils
	verteilt - je naeher am Knoten, desto mehr bekommt er ab.

	So verteilt sich die Last realistisch ueber die Fahrzeuglaenge, statt an
	einem einzigen Punkt zu haengen.
]]
function TestRun:computeVehicleLoads(): { [number]: number }
	local loads: { [number]: number } = {}
	if not self.vehicle then
		return loads
	end

	local spec = self.level.vehicle
	local structure = self.structure
	local totalWeight = spec.mass * Config.Gravity
	local sampleCount = 3
	local shareWeight = totalWeight / sampleCount

	local position = self.vehicle.Position
	local halfLength = spec.size.X / 2

	for i = 1, sampleCount do
		-- i = 1 -> hinten, i = sampleCount -> vorne
		local t = (i - 1) / (sampleCount - 1)
		local sampleX = position.X - halfLength + t * spec.size.X
		local origin = Vector3.new(sampleX, position.Y, self.origin.Z + self.level.z)

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

function TestRun:step(dt: number)
	local vehicle = self.vehicle
	if not vehicle then
		return
	end

	local level = self.level
	local spec = level.vehicle

	-- 1. Bauteile den Knoten nachfuehren
	self.structure:updateAllVisuals()

	-- 2. Countdown: das Fahrzeug steht noch, die Bruecke setzt sich bereits.
	if self.countdownLeft > 0 then
		self.countdownLeft -= dt
		if self.countdownLeft <= 0 then
			vehicle.Anchored = false
			self.driveStartTime = os.clock()
		end
	else
		-- 3. Konstante Fahrgeschwindigkeit in X, freier Fall in Y, kein Versatz in Z
		local velocity = vehicle.AssemblyLinearVelocity
		vehicle.AssemblyLinearVelocity = Vector3.new(spec.speed, velocity.Y, 0)
	end

	-- 4. Last verteilen
	self:applyLoadImpulses(dt)

	-- 5. Kraefte in festem Takt neu rechnen
	self.solveAccumulator += dt
	local interval = 1 / Config.Physics.solveRateTest
	if self.solveAccumulator >= interval then
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
	local labelInterval = 1 / Config.Test.labelUpdateRate
	if self.labelAccumulator >= labelInterval then
		self.labelAccumulator = 0
		self.forceEngine:updateLabels()
	end

	-- 7. Fortschritt melden (fuer die Anzeige beim Spieler)
	self.progressAccumulator += dt
	if self.progressAccumulator >= 0.2 then
		self.progressAccumulator = 0
		if self.onProgress then
			self.onProgress({
				countdown = math.max(self.countdownLeft, 0),
				elapsed = if self.driveStartTime then os.clock() - self.driveStartTime else 0,
				maxUtilisation = if self.lastResult then self.lastResult.maxUtilisation else 0,
			})
		end
	end

	-- Waehrend des Countdowns gelten die Abbruchbedingungen noch nicht.
	if self.countdownLeft > 0 or not self.driveStartTime then
		return
	end

	-- 8. Erfolg und Misserfolg pruefen
	local position = vehicle.Position

	if position.X >= self.origin.X + spec.finishX then
		self:finish(true, "Geschafft! Das Fahrzeug hat die andere Seite erreicht.")
		return
	end

	if position.Y < self.startY - level.maxDropStuds then
		self:finish(false, string.format("Das Fahrzeug ist mehr als %d Studs abgesackt.", level.maxDropStuds))
		return
	end

	-- Kippt das Fahrzeug staerker als etwa 45 Grad, gilt der Test als gescheitert.
	if vehicle.CFrame.UpVector:Dot(Vector3.yAxis) < 0.7 then
		self:finish(false, "Das Fahrzeug ist gekippt.")
		return
	end

	if os.clock() - self.driveStartTime > level.timeLimit then
		self:finish(false, string.format("Zeitlimit von %d Sekunden ueberschritten.", level.timeLimit))
		return
	end
end

--------------------------------------------------------------------------------
-- Oeffentliche Schnittstelle
--------------------------------------------------------------------------------

function TestRun:isRunning(): boolean
	return self.running
end

function TestRun:start(onProgress, onFinished)
	if self.running then
		return
	end

	self.running = true
	self.onProgress = onProgress
	self.onFinished = onFinished

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
	self:spawnVehicle()

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
	self:despawnVehicle()
	self.structure:setPhysicsEnabled(false)
	self.structure:setStressLabelsVisible(false)
end

return TestRun
