--[[
	LevelBuilder
	------------
	Baut die unveraenderliche Umgebung eines Levels auf:
	Plattformen, Schluchtwaende, Pylone, Ankerpunkte, Ziellinie.

	Alles entsteht im Code - nichts davon wird per Rojo als Instanz
	synchronisiert. Vorteil: Levelmasse aendert man nur in Levels.luau.

	ARENA-VERSATZ
	Jeder Spieler hat seine eigene Arena. Damit sich die Arenen nicht ins
	Gehege kommen, bekommt jede einen Versatz nach oben (origin). Alle
	Positionen hier sind deshalb "Levelposition + origin".
]]

local Debris = game:GetService("Debris")

local LevelBuilder = {}

--------------------------------------------------------------------------------
-- Kleine Helfer
--------------------------------------------------------------------------------

local function makePart(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

--[[
	level  Leveldaten aus Levels.luau
	origin Versatz dieser Arena (Vector3, meist nur Y)
	parent Ordner, in dem die Arena entstehen soll

	Rueckgabe: Tabelle mit allen Unterordnern.
]]
function LevelBuilder.build(level, origin: Vector3, parent: Instance)
	local root = Instance.new("Folder")
	root.Name = "Level_" .. level.id
	root.Parent = parent

	local terrain = Instance.new("Folder")
	terrain.Name = "Terrain"
	terrain.Parent = root

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

	local z = level.z

	----------------------------------------------------------------------------
	-- Plattformen links und rechts
	-- Aufbau von unten nach oben: Fels, darauf eine duenne Grasschicht.
	----------------------------------------------------------------------------

	local rockHeight = level.deckY - 2
	local halfLength = level.platformLength / 2

	for _, side in { -1, 1 } do
		local centerX = if side < 0
			then level.gapLeftX - halfLength
			else level.gapRightX + halfLength

		local rock = makePart(
			"PlatformRock",
			Vector3.new(level.platformLength, rockHeight, level.platformDepth),
			origin + Vector3.new(centerX, rockHeight / 2, z),
			terrain
		)
		rock.Color = Color3.fromRGB(112, 106, 96)
		rock.Material = Enum.Material.Rock

		local grass = makePart(
			"PlatformTop",
			Vector3.new(level.platformLength, 2, level.platformDepth),
			origin + Vector3.new(centerX, rockHeight + 1, z),
			terrain
		)
		grass.Color = Color3.fromRGB(104, 132, 84)
		grass.Material = Enum.Material.Grass

		-- Strassenbelag auf der Fahrspur, damit sichtbar ist, wo gefahren wird.
		local road = makePart(
			"PlatformRoad",
			Vector3.new(level.platformLength, 0.3, 8),
			origin + Vector3.new(centerX, level.deckY + 0.15, z),
			terrain
		)
		road.Color = Color3.fromRGB(58, 60, 66)
		road.Material = Enum.Material.Asphalt
		road.CanCollide = false

		-- Kantenmarkierung an der Abbruchkante.
		local edgeX = if side < 0 then level.gapLeftX - 0.4 else level.gapRightX + 0.4
		local edge = makePart(
			"CliffEdge",
			Vector3.new(0.8, 1.2, level.platformDepth),
			origin + Vector3.new(edgeX, level.deckY - 0.6, z),
			terrain
		)
		edge.Color = Color3.fromRGB(226, 190, 90)
		edge.Material = Enum.Material.Concrete
		edge.CanCollide = false
	end

	----------------------------------------------------------------------------
	-- Grund der Schlucht
	----------------------------------------------------------------------------

	if level.groundY > 0 then
		local floor = makePart(
			"CanyonFloor",
			Vector3.new(level.gapWidth, level.groundY, level.platformDepth),
			origin + Vector3.new(0, level.groundY / 2, z),
			terrain
		)
		floor.Color = Color3.fromRGB(96, 94, 86)
		floor.Material = Enum.Material.Slate
	end

	-- Duenne Bodenplatte, damit ein abstuerzendes Fahrzeug irgendwo liegen bleibt
	-- und nicht endlos faellt.
	local catcher = makePart(
		"CanyonBase",
		Vector3.new(level.gapWidth + 4, 2, level.platformDepth),
		origin + Vector3.new(0, math.max(level.groundY, 1) - 1, z),
		terrain
	)
	catcher.Color = Color3.fromRGB(78, 76, 70)
	catcher.Material = Enum.Material.Slate

	----------------------------------------------------------------------------
	-- Pylone: sie tragen die beiden festen Ankerpunkte der oberen Reihe.
	-- Sie stehen seitlich neben der Fahrspur, damit das Fahrzeug durchpasst.
	----------------------------------------------------------------------------

	local pylonHeight = level.upperY - level.deckY
	local outerX = level.gapRightX + level.snapSpacing

	for _, x in { -outerX, outerX } do
		for _, offsetZ in { -5, 5 } do
			local pylon = makePart(
				"Pylon",
				Vector3.new(2.2, pylonHeight, 2.2),
				origin + Vector3.new(x, level.deckY + pylonHeight / 2, z + offsetZ),
				terrain
			)
			pylon.Color = Color3.fromRGB(158, 152, 142)
			pylon.Material = Enum.Material.Concrete
			pylon.CanCollide = false
		end

		-- Querbalken oben, rein optisch.
		local crossBeam = makePart(
			"PylonTop",
			Vector3.new(2.4, 1.2, 12),
			origin + Vector3.new(x, level.upperY, z),
			terrain
		)
		crossBeam.Color = Color3.fromRGB(140, 134, 124)
		crossBeam.Material = Enum.Material.Concrete
		crossBeam.CanCollide = false
	end

	----------------------------------------------------------------------------
	-- Start- und Zielmarkierung
	----------------------------------------------------------------------------

	local start = makePart(
		"StartMarker",
		Vector3.new(1.2, 0.4, 8),
		origin + Vector3.new(level.vehicle.startX, level.deckY + 0.35, z),
		terrain
	)
	start.Color = Color3.fromRGB(235, 235, 235)
	start.Material = Enum.Material.Neon
	start.CanCollide = false
	start.CanQuery = false

	local finish = makePart(
		"FinishZone",
		Vector3.new(1.6, 9, level.platformDepth * 0.5),
		origin + Vector3.new(level.vehicle.finishX, level.deckY + 4.5, z),
		terrain
	)
	finish.Color = Color3.fromRGB(74, 208, 118)
	finish.Material = Enum.Material.Neon
	finish.Transparency = 0.55
	finish.CanCollide = false
	finish.CanQuery = false

	----------------------------------------------------------------------------
	-- Ankerpunkte sichtbar machen
	----------------------------------------------------------------------------

	for _, snap in level.snapPoints do
		local marker = Instance.new("Part")
		marker.Name = "Snap_" .. snap.id
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(1.2, 1.2, 1.2)
		marker.CFrame = CFrame.new(origin + snap.position)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Material = Enum.Material.Neon
		marker.Transparency = 0.4
		-- Orange = fest verankert, Blau = beweglich.
		marker.Color = if snap.fixed
			then Color3.fromRGB(248, 186, 76)
			else Color3.fromRGB(118, 178, 248)
		marker:SetAttribute("SnapIndex", snap.id)
		marker:SetAttribute("Fixed", snap.fixed)
		marker.Parent = snapFolder
	end

	return {
		root = root,
		terrain = terrain,
		snapPoints = snapFolder,
		nodes = nodesFolder,
		members = membersFolder,
		effects = effectsFolder,
		vehicle = vehicleFolder,
	}
end

--------------------------------------------------------------------------------
-- Effekt beim Bruch eines Bauteils
--------------------------------------------------------------------------------

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

	-- Funken und Bruchstuecke
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.35, 0.9)
	sparks.Speed = NumberRange.new(16, 34)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.6)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(150, 70, 30))
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Parent = anchor
	sparks:Emit(40)

	-- Kurze Staubwolke
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 0
	dust.Lifetime = NumberRange.new(0.6, 1.2)
	dust.Speed = NumberRange.new(2, 7)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(3)
	dust.Color = ColorSequence.new(Color3.fromRGB(160, 155, 145))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Parent = anchor
	dust:Emit(18)

	Debris:AddItem(anchor, 2.5)
	return anchor
end

return LevelBuilder
