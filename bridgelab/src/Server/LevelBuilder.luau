--[[
	LevelBuilder
	------------
	Baut die unveraenderliche Umgebung des Levels auf:
	Plattformen, Schluchtgrund, Pylone, Ankerpunkt-Markierungen, Zielzone
	und den Spawnpunkt fuer die Spielerfigur.

	Alles landet in Workspace/BridgeLab. Nichts davon wird per Rojo als
	Instanz synchronisiert - die Welt entsteht komplett im Code. Das hat den
	Vorteil, dass sich Levelmasse nur in Level1.luau aendern lassen.
]]

local Workspace = game:GetService("Workspace")

local LevelBuilder = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[
	Baut das Level auf und gibt eine Tabelle mit allen wichtigen Ordnern zurueck.
]]
function LevelBuilder.build(level)
	-- Falls bereits ein Aufbau existiert (z. B. beim erneuten Start), entfernen.
	local old = Workspace:FindFirstChild("BridgeLab")
	if old then
		old:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "BridgeLab"
	root.Parent = Workspace

	local terrainFolder = Instance.new("Folder")
	terrainFolder.Name = "Terrain"
	terrainFolder.Parent = root

	local snapFolder = Instance.new("Folder")
	snapFolder.Name = "SnapPoints"
	snapFolder.Parent = root

	local nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "Nodes"
	nodesFolder.Parent = root

	local membersFolder = Instance.new("Folder")
	membersFolder.Name = "Members"
	membersFolder.Parent = root

	local effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "Effects"
	effectsFolder.Parent = root

	local vehicleFolder = Instance.new("Folder")
	vehicleFolder.Name = "Vehicle"
	vehicleFolder.Parent = root

	----------------------------------------------------------------------------
	-- Plattformen links und rechts
	----------------------------------------------------------------------------

	local platformHeight = level.deckY -- von y = 0 bis zur Fahrbahnhoehe
	local halfLength = level.platformLength / 2

	local leftPlatform = makePart(
		"PlatformLeft",
		Vector3.new(level.platformLength, platformHeight, level.platformDepth),
		CFrame.new(level.gapLeftX - halfLength, platformHeight / 2, level.z),
		terrainFolder
	)
	leftPlatform.Color = Color3.fromRGB(101, 121, 84)
	leftPlatform.Material = Enum.Material.Grass

	local rightPlatform = makePart(
		"PlatformRight",
		Vector3.new(level.platformLength, platformHeight, level.platformDepth),
		CFrame.new(level.gapRightX + halfLength, platformHeight / 2, level.z),
		terrainFolder
	)
	rightPlatform.Color = leftPlatform.Color
	rightPlatform.Material = leftPlatform.Material

	----------------------------------------------------------------------------
	-- Grund der Schlucht
	----------------------------------------------------------------------------

	local canyonFloor = makePart(
		"CanyonFloor",
		Vector3.new(level.gapWidth, level.groundY, level.platformDepth),
		CFrame.new(0, level.groundY / 2, level.z),
		terrainFolder
	)
	canyonFloor.Color = Color3.fromRGB(105, 102, 92)
	canyonFloor.Material = Enum.Material.Slate

	----------------------------------------------------------------------------
	-- Pylone: tragen die beiden festen Ankerpunkte der oberen Reihe.
	-- Sie stehen seitlich neben der Fahrspur, damit das Fahrzeug frei durchkommt.
	----------------------------------------------------------------------------

	local pylonHeight = level.upperY - level.deckY
	for _, x in { -24, 24 } do
		for _, z in { -5, 5 } do
			local pylon = makePart(
				"Pylon",
				Vector3.new(2, pylonHeight, 2),
				CFrame.new(x, level.deckY + pylonHeight / 2, level.z + z),
				terrainFolder
			)
			pylon.Color = Color3.fromRGB(150, 143, 130)
			pylon.Material = Enum.Material.Concrete
			pylon.CanCollide = false
		end
		-- Querbalken oben, rein optisch.
		local crossBeam = makePart(
			"PylonTop",
			Vector3.new(2, 1, 12),
			CFrame.new(x, level.upperY, level.z),
			terrainFolder
		)
		crossBeam.Color = Color3.fromRGB(150, 143, 130)
		crossBeam.Material = Enum.Material.Concrete
		crossBeam.CanCollide = false
	end

	----------------------------------------------------------------------------
	-- Zielzone
	----------------------------------------------------------------------------

	local finish = makePart(
		"FinishZone",
		Vector3.new(2, 8, level.platformDepth),
		CFrame.new(level.vehicle.finishX, level.deckY + 4, level.z),
		terrainFolder
	)
	finish.Color = Color3.fromRGB(70, 200, 110)
	finish.Material = Enum.Material.Neon
	finish.Transparency = 0.6
	finish.CanCollide = false
	finish.CanQuery = false

	----------------------------------------------------------------------------
	-- Ankerpunkte sichtbar machen
	----------------------------------------------------------------------------

	for _, snap in level.snapPoints do
		local marker = Instance.new("Part")
		marker.Name = "Snap_" .. snap.id
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(1.1, 1.1, 1.1)
		marker.CFrame = CFrame.new(snap.position)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Material = Enum.Material.Neon
		marker.Transparency = 0.35
		marker.Color = if snap.fixed then Color3.fromRGB(245, 180, 70) else Color3.fromRGB(120, 175, 245)
		marker:SetAttribute("SnapIndex", snap.id)
		marker:SetAttribute("Fixed", snap.fixed)
		marker.Parent = snapFolder
	end

	----------------------------------------------------------------------------
	-- Spawnpunkt fuer die Spielerfigur (seitlich, nicht auf der Fahrspur)
	----------------------------------------------------------------------------

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(level.gapLeftX - 22, level.deckY + 0.5, level.z + 14)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(80, 140, 220)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = terrainFolder

	return {
		root = root,
		terrain = terrainFolder,
		snapPoints = snapFolder,
		nodes = nodesFolder,
		members = membersFolder,
		effects = effectsFolder,
		vehicle = vehicleFolder,
	}
end

-- Kleiner Partikel-Platzhalter fuer ein brechendes Bauteil.
function LevelBuilder.playBreakEffect(effectsFolder: Instance, position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "BreakEffect"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = effectsFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.35, 0.9)
	emitter.Speed = NumberRange.new(14, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.7)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(130, 70, 30))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = anchor
	emitter:Emit(35)

	game:GetService("Debris"):AddItem(anchor, 2)
	return anchor
end

return LevelBuilder
