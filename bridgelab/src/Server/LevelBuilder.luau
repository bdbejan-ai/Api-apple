--[[
	LevelBuilder
	------------
	Baut die unveraenderliche Umgebung eines Levels auf: Felsplattformen,
	Schluchtgrund mit Fluss, Widerlager, Pylone, Bewuchs, Hintergrund und
	die Ankerpunkte.

	Alles entsteht im Code - nichts davon wird per Rojo als Instanz
	synchronisiert. Vorteil: Levelmasse aendert man nur in Levels.luau.

	ARENA-VERSATZ
	Jeder Spieler hat seine eigene Arena. Damit sich die Arenen nicht ins
	Gehege kommen, bekommt jede einen Versatz nach oben (origin). Alle
	Positionen hier sind deshalb "Levelposition + origin".

	MEHRERE FAHRBAHNEN
	Ein Level kann mehrere Fahrbahnhoehen haben. Fuer jede entsteht auf
	beiden Plattformen ein Strassenstueck; liegt sie hoeher als die unterste,
	traegt sie zusaetzlich ein Widerlager - sonst haenge die Strasse in der
	Luft und das Fahrzeug haette nichts, worauf es startet.
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

-- Deko beruehrt nichts und wird von keinem Strahl getroffen.
local function makeDecor(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = makePart(name, size, position, parent)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Ein einfacher Baum: Stamm plus Krone.
local function makeTree(position: Vector3, scale: number, parent: Instance)
	local trunk = makeDecor("Trunk", Vector3.new(1.1 * scale, 5 * scale, 1.1 * scale), position + Vector3.new(0, 2.5 * scale, 0), parent)
	trunk.Color = Color3.fromRGB(96, 72, 52)
	trunk.Material = Enum.Material.Wood

	local crown = makeDecor("Crown", Vector3.new(6 * scale, 6.5 * scale, 6 * scale), position + Vector3.new(0, 7 * scale, 0), parent)
	crown.Shape = Enum.PartType.Ball
	crown.Color = Color3.fromRGB(72, 118, 62)
	crown.Material = Enum.Material.Grass
end

-- Ein Felsbrocken, leicht schraeg fuer ein natuerlicheres Bild.
local function makeBoulder(position: Vector3, size: number, parent: Instance)
	local rock = makeDecor("Boulder", Vector3.new(size, size * 0.8, size * 0.9), position, parent)
	rock.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(12), math.rad(size * 37), math.rad(8))
	rock.Color = Color3.fromRGB(104, 100, 92)
	rock.Material = Enum.Material.Rock
end

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

function LevelBuilder.build(level, origin: Vector3, parent: Instance)
	local root = Instance.new("Folder")
	root.Name = "Level_" .. level.id
	root.Parent = parent

	local function newFolder(name: string): Folder
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = root
		return folder
	end

	local terrain = newFolder("Terrain")
	local decor = newFolder("Decor")
	local snapFolder = newFolder("SnapPoints")
	local nodesFolder = newFolder("Nodes")
	local membersFolder = newFolder("Members")
	local effectsFolder = newFolder("Effects")
	local vehicleFolder = newFolder("Vehicle")

	local z = level.z
	local depth = level.platformDepth
	local halfLength = level.platformLength / 2
	local lowestDeckY = level.decks[1].y

	----------------------------------------------------------------------------
	-- Plattformen links und rechts
	-- Aufbau von unten nach oben: Fels, darauf eine duenne Grasschicht.
	----------------------------------------------------------------------------

	local rockHeight = lowestDeckY - 2

	for _, side in { -1, 1 } do
		local centerX = if side < 0 then level.gapLeftX - halfLength else level.gapRightX + halfLength

		local rock = makePart(
			"PlatformRock",
			Vector3.new(level.platformLength, rockHeight, depth),
			origin + Vector3.new(centerX, rockHeight / 2, z),
			terrain
		)
		rock.Color = Color3.fromRGB(116, 109, 98)
		rock.Material = Enum.Material.Rock

		local grass = makePart(
			"PlatformTop",
			Vector3.new(level.platformLength, 2, depth),
			origin + Vector3.new(centerX, rockHeight + 1, z),
			terrain
		)
		grass.Color = Color3.fromRGB(108, 138, 86)
		grass.Material = Enum.Material.Grass

		-- Kantenmarkierung an der Abbruchkante
		local edgeX = if side < 0 then level.gapLeftX - 0.4 else level.gapRightX + 0.4
		local edge = makeDecor(
			"CliffEdge",
			Vector3.new(0.8, 1.2, depth),
			origin + Vector3.new(edgeX, lowestDeckY - 0.6, z),
			terrain
		)
		edge.Color = Color3.fromRGB(228, 194, 96)
		edge.Material = Enum.Material.Concrete

		------------------------------------------------------------------------
		-- Bewuchs auf der Plattform
		------------------------------------------------------------------------
		for i = 1, 3 do
			local treeX = centerX - halfLength * 0.55 + (i - 1) * halfLength * 0.5
			makeTree(origin + Vector3.new(treeX, lowestDeckY, z - depth * 0.32), 0.9 + i * 0.12, decor)
			makeTree(origin + Vector3.new(treeX + 6, lowestDeckY, z + depth * 0.34), 0.8 + i * 0.1, decor)
		end
	end

	----------------------------------------------------------------------------
	-- Strassen und Widerlager je Fahrbahnhoehe
	----------------------------------------------------------------------------

	for index, deck in level.decks do
		for _, side in { -1, 1 } do
			local centerX = if side < 0 then level.gapLeftX - halfLength else level.gapRightX + halfLength

			--[[
				Liegt diese Fahrbahn hoeher als die unterste, bekommt sie ein
				Widerlager - zwei Betonwaende, die sie optisch tragen.

				Warum zwei Waende und kein voller Block? Ein voller Block wuerde
				die Strasse der Ebene DARUNTER einmauern. Die Waende stehen
				deshalb seitlich neben der Fahrspur, die Mitte bleibt frei.

				Statisch braucht es sie ohnehin nicht: alle Teile der Umgebung
				sind verankert, das Fahrzeug steht auf dem Strassenstueck selbst.
			]]
			if index > 1 then
				local below = level.decks[index - 1].y
				local height = deck.y - below
				for _, wallZ in { -depth * 0.26, depth * 0.26 } do
					local wall = makePart(
						"Abutment",
						Vector3.new(level.platformLength, height, depth * 0.16),
						origin + Vector3.new(centerX, below + height / 2, z + wallZ),
						terrain
					)
					wall.Color = Color3.fromRGB(150, 145, 136)
					wall.Material = Enum.Material.Concrete
					wall.CanCollide = false
				end
			end

			local road = makePart(
				"Road",
				Vector3.new(level.platformLength, 0.4, 8),
				origin + Vector3.new(centerX, deck.y + 0.2, z),
				terrain
			)
			road.Color = Color3.fromRGB(58, 60, 66)
			road.Material = Enum.Material.Asphalt

			-- Mittelstreifen, damit man die Fahrspur erkennt
			for i = 0, 5 do
				local stripe = makeDecor(
					"Stripe",
					Vector3.new(4, 0.05, 0.5),
					origin + Vector3.new(centerX - halfLength + 6 + i * 9, deck.y + 0.42, z),
					decor
				)
				stripe.Color = Color3.fromRGB(232, 232, 224)
				stripe.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	----------------------------------------------------------------------------
	-- Schluchtgrund und Fluss
	----------------------------------------------------------------------------

	if level.groundY > 0 then
		local floor = makePart(
			"CanyonFloor",
			Vector3.new(level.gapWidth + 6, level.groundY, depth),
			origin + Vector3.new(0, level.groundY / 2, z),
			terrain
		)
		floor.Color = Color3.fromRGB(96, 94, 86)
		floor.Material = Enum.Material.Slate
	end

	-- Auffangboden, damit ein abstuerzendes Fahrzeug liegen bleibt
	local catcher = makePart(
		"CanyonBase",
		Vector3.new(level.gapWidth + 8, 2, depth),
		origin + Vector3.new(0, math.max(level.groundY, 1) - 1, z),
		terrain
	)
	catcher.Color = Color3.fromRGB(78, 76, 70)
	catcher.Material = Enum.Material.Slate

	if level.river then
		--[[
			Der Fluss ist reine Optik: er kollidiert mit nichts und wird von
			keinem Strahl getroffen. Auf die Physik oder die Kraefteberechnung
			hat er keinerlei Einfluss - Stuetzen duerfen mitten hindurch.
		]]
		local riverDepth = 3.5
		local bed = makePart(
			"RiverBed",
			Vector3.new(level.gapWidth + 6, riverDepth, depth * 0.55),
			origin + Vector3.new(0, level.groundY - riverDepth / 2 + 0.5, z),
			terrain
		)
		bed.Color = Color3.fromRGB(74, 78, 72)
		bed.Material = Enum.Material.Sand

		local water = makeDecor(
			"River",
			Vector3.new(level.gapWidth + 6, 2.6, depth * 0.55),
			origin + Vector3.new(0, level.riverY - 1.3, z),
			decor
		)
		water.Color = Color3.fromRGB(58, 122, 158)
		water.Material = Enum.Material.Glass
		water.Transparency = 0.35
		water.Reflectance = 0.28

		-- Kiesbaenke am Ufer
		for _, side in { -1, 1 } do
			local bank = makeDecor(
				"Bank",
				Vector3.new(level.gapWidth + 6, 1.4, depth * 0.14),
				origin + Vector3.new(0, level.groundY + 0.2, z + side * depth * 0.32),
				decor
			)
			bank.Color = Color3.fromRGB(150, 142, 124)
			bank.Material = Enum.Material.Sand
		end

		-- Ein paar Steine im Wasser
		for i = 1, 4 do
			local x = -level.gapWidth / 2 + i * (level.gapWidth / 5)
			makeBoulder(origin + Vector3.new(x, level.groundY + 0.8, z + (if i % 2 == 0 then 6 else -7)), 2 + i % 3, decor)
		end
	end

	----------------------------------------------------------------------------
	-- Pylone: sie tragen die beiden festen Ankerpunkte der oberen Reihe
	----------------------------------------------------------------------------

	local topDeckY = level.topDeckY
	local pylonHeight = level.upperY - topDeckY
	local outerX = level.gapRightX + level.snapSpacing

	if pylonHeight > 0 then
		for _, x in { -outerX, outerX } do
			for _, offsetZ in { -5, 5 } do
				local pylon = makeDecor(
					"Pylon",
					Vector3.new(2.2, pylonHeight, 2.2),
					origin + Vector3.new(x, topDeckY + pylonHeight / 2, z + offsetZ),
					terrain
				)
				pylon.Color = Color3.fromRGB(162, 156, 146)
				pylon.Material = Enum.Material.Concrete
			end

			local crossBeam = makeDecor(
				"PylonTop",
				Vector3.new(2.4, 1.2, 12),
				origin + Vector3.new(x, level.upperY, z),
				terrain
			)
			crossBeam.Color = Color3.fromRGB(142, 136, 126)
			crossBeam.Material = Enum.Material.Concrete
		end
	end

	----------------------------------------------------------------------------
	-- Start- und Zielmarkierung je Fahrzeug
	----------------------------------------------------------------------------

	for _, vehicle in level.vehicles do
		-- Auf die Fahrspur des jeweiligen Fahrzeugs setzen. Bei Gegenverkehr
		-- liegen Start und Ziel sonst uebereinander.
		local lane = vehicle.laneZ or 0
		local width = if lane ~= 0 then 3.6 else 8

		local start = makeDecor(
			"StartMarker",
			Vector3.new(1.2, 0.4, width),
			origin + Vector3.new(vehicle.startX, vehicle.deckY + 0.45, z + lane),
			decor
		)
		start.Color = if vehicle.color then vehicle.color else Color3.fromRGB(235, 235, 235)
		start.Material = Enum.Material.Neon

		local finish = makeDecor(
			"FinishZone",
			Vector3.new(1.6, 9, if lane ~= 0 then 5 else 12),
			origin + Vector3.new(vehicle.finishX, vehicle.deckY + 4.5, z + lane),
			decor
		)
		finish.Color = Color3.fromRGB(74, 208, 118)
		finish.Material = Enum.Material.Neon
		finish.Transparency = 0.55
	end

	----------------------------------------------------------------------------
	-- Hintergrund: ein paar Huegel weit hinten geben Tiefe
	----------------------------------------------------------------------------

	for i = 1, 6 do
		local hillX = level.bounds.minX + (i - 0.5) * (level.bounds.maxX - level.bounds.minX) / 6
		local height = 34 + (i % 3) * 20
		local hill = makeDecor(
			"Hill",
			Vector3.new(70 + (i % 4) * 26, height, 30),
			origin + Vector3.new(hillX + (i % 2) * 14, height / 2 - 6, z - 130 - (i % 3) * 26),
			decor
		)
		-- Weiter hinten heisst blasser: das erzeugt Tiefenwirkung.
		hill.Color = Color3.fromRGB(104 + i * 4, 122 + i * 3, 116 + i * 5)
		hill.Material = Enum.Material.Grass
	end

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
		decor = decor,
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
