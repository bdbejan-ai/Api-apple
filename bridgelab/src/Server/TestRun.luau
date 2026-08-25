--[[
	TestRun
	-------
	Der Belastungstest: Fahrzeug erzeugen, ueber die Bruecke schicken,
	Kraefte pruefen, Erfolg oder Misserfolg feststellen.

	Ablauf pro Bild (Heartbeat):
	  1. Bauteil-Parts an die aktuellen Knotenpositionen setzen.
	  2. Fahrzeug auf konstanter Geschwindigkeit halten.
	  3. Ermitteln, auf welchen Bauteilen das Fahrzeug gerade steht, und
	     seine Last auf die zugehoerigen Knoten verteilen.
	  4. Mehrmals pro Sekunde: Kraefte neu ausrechnen und pruefen, ob ein
	     Bauteil ueber seinem Grenzwert liegt.
	  5. Erfolgs- und Abbruchbedingungen pruefen.

	Die Last wird dabei zweimal gebraucht:
	  - als Zahl fuer den Fachwerk-Rechner (entscheidet ueber Bruch),
	  - als echter Impuls auf die Knotenkugeln, damit sich die Bruecke
	    sichtbar durchbiegt.
]]

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local Structure = require(script.Parent.Structure)
local ForceEngine = require(script.Parent.ForceEngine)

local TestRun = {}

local ctx
local connection: RBXScriptConnection? = nil
local vehicle: Part? = nil
local startTime = 0
local startY = 0
local solveAccumulator = 0
local currentNodeLoads: { [number]: number } = {}
local onFinished: ((boolean, string) -> ())? = nil

-- Nur Bauteil-Parts werden beim Abtasten der Fahrbahn getroffen.
local raycastParams = RaycastParams.new()

--------------------------------------------------------------------------------
-- Fahrzeug
--------------------------------------------------------------------------------

local function spawnVehicle()
	local spec = ctx.level.vehicle

	local part = Instance.new("Part")
	part.Name = "TestVehicle"
	part.Size = spec.size
	part.Anchored = false
	part.CanCollide = true
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(205, 75, 55)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	-- Dichte so waehlen, dass die Roblox-Masse der Spielmasse entspricht.
	local volume = spec.size.X * spec.size.Y * spec.size.Z
	local density = math.clamp(spec.mass / volume, 0.01, 100)
	part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.7, 0.1, 1, 1)

	part.CFrame = CFrame.new(spec.startX, ctx.level.deckY + spec.size.Y / 2 + 0.2, ctx.level.z)
	part.Parent = ctx.folders.vehicle

	vehicle = part
	startY = part.Position.Y
	return part
end

local function despawnVehicle()
	if vehicle then
		vehicle:Destroy()
		vehicle = nil
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
local function computeVehicleLoads(): { [number]: number }
	local loads: { [number]: number } = {}
	if not vehicle then
		return loads
	end

	local spec = ctx.level.vehicle
	local totalWeight = spec.mass * Config.Gravity
	local sampleCount = 3
	local shareWeight = totalWeight / sampleCount

	local position = vehicle.Position
	local halfLength = spec.size.X / 2

	for i = 1, sampleCount do
		-- i = 1 -> hinten, i = sampleCount -> vorne
		local t = (i - 1) / (sampleCount - 1)
		local sampleX = position.X - halfLength + t * spec.size.X
		local origin = Vector3.new(sampleX, position.Y, ctx.level.z)

		local hit = workspace:Raycast(origin, Vector3.new(0, -(spec.size.Y / 2 + 4), 0), raycastParams)
		if hit and hit.Instance then
			local memberId = hit.Instance:GetAttribute("MemberId")
			if memberId then
				local member = Structure.findMemberById(memberId)
				if member and not member.broken then
					local posA = Structure.nodePosition(member.a)
					local posB = Structure.nodePosition(member.b)
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
local function applyLoadImpulses(dt: number)
	local nodes = Structure.getNodes()
	for snapIndex, newtons in currentNodeLoads do
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

local brokenMemberKind: string? = nil

local function checkForBreaks(result)
	local broke = false

	for _, member in Structure.activeMembers() do
		local limit = ForceEngine.limitFor(member.kind, member.force)
		if math.abs(member.force) > limit then
			brokenMemberKind = Config.PartTypes[member.kind].displayName
			Structure.breakMember(member)
			broke = true
		end
	end

	-- Ein Knoten, der seine Last ueberhaupt nicht abtragen kann, bedeutet:
	-- die Konstruktion ist dort nicht ausgesteift. Wir lassen das am staerksten
	-- belastete anhaengende Bauteil versagen, damit man den Fehler sieht.
	if not broke and result.unstable and result.worstNodeIndex then
		local worst = nil
		for _, member in Structure.activeMembers() do
			if member.a == result.worstNodeIndex or member.b == result.worstNodeIndex then
				if worst == nil or math.abs(member.force) > math.abs(worst.force) then
					worst = member
				end
			end
		end
		if worst then
			brokenMemberKind = Config.PartTypes[worst.kind].displayName
			Structure.breakMember(worst)
			broke = true
		end
	end

	return broke
end

--------------------------------------------------------------------------------
-- Ein Simulationsschritt
--------------------------------------------------------------------------------

local function finish(success: boolean, reason: string)
	TestRun.stop()
	if onFinished then
		onFinished(success, reason)
	end
end

local function step(dt: number)
	if not vehicle then
		return
	end

	local level = ctx.level
	local spec = level.vehicle

	-- 1. Bauteile den Knoten nachfuehren
	Structure.updateAllVisuals()

	-- 2. Konstante Fahrgeschwindigkeit in X, freier Fall in Y, kein Versatz in Z
	local velocity = vehicle.AssemblyLinearVelocity
	vehicle.AssemblyLinearVelocity = Vector3.new(spec.speed, velocity.Y, 0)

	-- 3. Last verteilen
	applyLoadImpulses(dt)

	-- 4. Kraefte in festem Takt neu rechnen
	solveAccumulator += dt
	local interval = 1 / Config.Physics.solveRateTest
	if solveAccumulator >= interval then
		solveAccumulator = 0
		currentNodeLoads = computeVehicleLoads()
		local result = ForceEngine.evaluate(currentNodeLoads)
		ForceEngine.applyColors()

		local elapsed = os.clock() - startTime
		if elapsed > Config.Physics.breakGracePeriod then
			if checkForBreaks(result) then
				finish(false, string.format("Bauteil gebrochen: %s war ueberlastet.", brokenMemberKind or "?"))
				return
			end
		end
	end

	-- 5. Erfolg und Misserfolg pruefen
	local position = vehicle.Position

	if position.X >= spec.finishX then
		finish(true, "Geschafft! Das Fahrzeug hat die andere Seite erreicht.")
		return
	end

	if position.Y < startY - level.maxDropStuds then
		finish(false, string.format("Das Fahrzeug ist mehr als %d Studs abgesackt.", level.maxDropStuds))
		return
	end

	-- Kippt das Fahrzeug staerker als etwa 45 Grad, gilt der Test als gescheitert.
	if vehicle.CFrame.UpVector:Dot(Vector3.yAxis) < 0.7 then
		finish(false, "Das Fahrzeug ist gekippt.")
		return
	end

	if os.clock() - startTime > level.timeLimit then
		finish(false, string.format("Zeitlimit von %d Sekunden ueberschritten.", level.timeLimit))
		return
	end
end

--------------------------------------------------------------------------------
-- Oeffentliche Schnittstelle
--------------------------------------------------------------------------------

function TestRun.isRunning(): boolean
	return connection ~= nil
end

function TestRun.start(callback: (boolean, string) -> ())
	if connection then
		return
	end

	onFinished = callback
	brokenMemberKind = nil
	solveAccumulator = 0
	currentNodeLoads = {}

	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { ctx.folders.members }

	Structure.setPhysicsEnabled(true)
	spawnVehicle()
	startTime = os.clock()

	connection = RunService.Heartbeat:Connect(step)
end

function TestRun.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	despawnVehicle()
	Structure.setPhysicsEnabled(false)
end

function TestRun.init(context)
	ctx = context
end

return TestRun
