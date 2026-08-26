--[[
	LevelBuilder
	------------
	Baut die sichtbare Welt einer Arena auf: Gelaende, Wasser, Anker, Zierrat.

	WAS SICH GEAENDERT HAT
	Frueher bestand ein Level aus zwei Plattformen mit einer Luecke dazwischen.
	Damit war jedes Level dieselbe Form, nur mit anderen Zahlen.

	Jetzt beschreibt jedes Level ein GELAENDEPROFIL - einen Linienzug aus
	Stuetzstellen (siehe Terrain.luau). Daraus laesst sich alles bauen: ein
	schmaler Graben, eine Schlucht mit Felsnadel, ein Kliff, zwei verschieden
	hohe Ufer.

	WIE AUS DEM LINIENZUG FELSEN WERDEN
	Das Profil wird in waagerechte Abschnitte zerlegt. Ein flacher Abschnitt
	wird ein einzelner Block. Ein schraeger Abschnitt wird eine Treppe aus
	schmalen Blocken - bei Felsen faellt das nicht auf, und es kommt ohne
	Roblox-Terrain aus, das sich nicht je Spieler getrennt aufbauen liesse.

	KEIN RASTERPUNKT-TEPPICH
	Die Rasterpunkte werden ABSICHTLICH nicht als Parts gebaut. Ein Baubereich
	von 120 mal 90 Studs hat auf dem 2-Studs-Raster ueber 2700 Punkte - so
	viele Parts je Spieler wuerden den Server erdruecken, und zu sehen waere
	ein grauer Nebel. Stattdessen zeigt der Client nur den einen Punkt an, auf
	den gerade gerastert wird (siehe BuildController).
]]

local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Terrain = require(Shared.Terrain)

local LevelBuilder = {}

--------------------------------------------------------------------------------
-- Bausteine
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

local function makeDecor(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = makePart(name, size, position, parent)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

--[[
	Ein Baum aus Stamm und zwei Kronen. Bewusst schlicht: er steht weit hinter
	der Bruecke und soll die Aufmerksamkeit nicht auf sich ziehen.
]]
local function makeTree(position: Vector3, scale: number, parent: Instance)
	local trunk = makeDecor("Stamm", Vector3.new(1.1 * scale, 5 * scale, 1.1 * scale), position, parent)
	trunk.Color = Color3.fromRGB(94, 68, 48)
	trunk.Material = Enum.Material.Wood

	local lower = makeDecor(
		"Krone",
		Vector3.new(6 * scale, 5 * scale, 6 * scale),
		position + Vector3.new(0, 4.2 * scale, 0),
		parent
	)
	lower.Color = Color3.fromRGB(62, 108, 62)
	lower.Material = Enum.Material.Grass
	lower.Shape = Enum.PartType.Ball

	local upper = makeDecor(
		"Krone",
		Vector3.new(4.2 * scale, 4.2 * scale, 4.2 * scale),
		position + Vector3.new(0, 7.4 * scale, 0),
		parent
	)
	upper.Color = Color3.fromRGB(74, 124, 70)
	upper.Material = Enum.Material.Grass
	upper.Shape = Enum.PartType.Ball
end

local function makeBoulder(position: Vector3, size: number, parent: Instance)
	local rock = makeDecor("Felsbrocken", Vector3.new(size, size * 0.8, size * 0.9), position, parent)
	rock.Color = Color3.fromRGB(112, 110, 106)
	rock.Material = Enum.Material.Slate
	rock.Shape = Enum.PartType.Ball
end

--------------------------------------------------------------------------------
-- Gelaende
--------------------------------------------------------------------------------

--[[
	Baut das Gelaendeprofil als Folge von Felsbloecken.

	Fuer jeden waagerechten Abschnitt:
	  * ist er flach, wird ein einziger Block gesetzt
	  * ist er schraeg, wird er in Stufen von hoechstens 3 Studs zerlegt

	Ganz oben liegt auf jedem Block eine duenne Grasschicht, damit die Felsen
	nicht wie ein Steinbruch aussehen.
]]
local function buildTerrain(level, origin: Vector3, parent: Instance)
	local bounds = Terrain.bounds(level.terrain)
	local depth = level.terrainDepth or 46
	local baseY = bounds.minY - 40
	local z = level.z or 0

	local rockColor = Color3.fromRGB(118, 114, 108)
	local grassColor = Color3.fromRGB(96, 138, 78)

	local function column(x1: number, x2: number, topY: number)
		local width = x2 - x1
		if width < 0.05 then
			return
		end
		local centreX = (x1 + x2) / 2
		local height = topY - baseY

		local rock = makePart(
			"Fels",
			Vector3.new(width, height, depth),
			origin + Vector3.new(centreX, baseY + height / 2, z),
			parent
		)
		rock.Color = rockColor
		rock.Material = Enum.Material.Rock

		-- Grasnarbe obenauf.
		local grass = makePart(
			"Grasnarbe",
			Vector3.new(width, 1.2, depth),
			origin + Vector3.new(centreX, topY - 0.6, z),
			parent
		)
		grass.Color = grassColor
		grass.Material = Enum.Material.Grass
	end

	for _, span in Terrain.spans(level.terrain) do
		if math.abs(span.y2 - span.y1) < 0.05 then
			column(span.x1, span.x2, span.y1)
		else
			--[[
				Schraege als Treppe. Die Stufenbreite richtet sich nach der
				Steigung: je steiler, desto schmaler die Stufen, damit die
				Treppe nicht als Treppe auffaellt.
			]]
			local run = span.x2 - span.x1
			local rise = math.abs(span.y2 - span.y1)
			local steps = math.clamp(math.ceil(math.max(run, rise) / 3), 1, 40)
			for i = 1, steps do
				local x1 = span.x1 + run * ((i - 1) / steps)
				local x2 = span.x1 + run * (i / steps)
				-- Die Stufe bekommt die HOEHERE der beiden Kanten, sonst
				-- entstehen Luecken, durch die man das Nichts sieht.
				local yA = span.y1 + (span.y2 - span.y1) * ((i - 1) / steps)
				local yB = span.y1 + (span.y2 - span.y1) * (i / steps)
				column(x1, x2, math.max(yA, yB))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Wasser
--------------------------------------------------------------------------------

local function buildWater(level, origin: Vector3, parent: Instance)
	if not level.waterY then
		return
	end

	local bounds = Terrain.bounds(level.terrain)
	local depth = (level.terrainDepth or 46) * 0.7
	local z = level.z or 0
	local width = bounds.maxX - bounds.minX

	local water = makeDecor(
		"Wasser",
		Vector3.new(width, 2, depth),
		origin + Vector3.new((bounds.minX + bounds.maxX) / 2, level.waterY - 1, z),
		parent
	)
	water.Color = Color3.fromRGB(58, 122, 158)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.35
	water.Reflectance = 0.28
end

--------------------------------------------------------------------------------
-- Anker
--------------------------------------------------------------------------------

--[[
	Jeder Anker bekommt ein Widerlager aus Beton mit einer goldenen Platte
	obenauf. Gold ist im ganzen Spiel die Farbe fuer "hier haelt es" - dieselbe
	Farbe haben die Knotenkugeln an Ankern (siehe Structure).
]]
local function buildAnchors(level, origin: Vector3, parent: Instance)
	local z = level.z or 0

	for _, anchor in level.anchors do
		local block = makePart(
			"Widerlager",
			Vector3.new(5, 4, 12),
			origin + Vector3.new(anchor.x, anchor.y - 2, z),
			parent
		)
		block.Color = Color3.fromRGB(150, 146, 138)
		block.Material = Enum.Material.Concrete
		block.CanCollide = false
		block.CanQuery = false

		local plate = makeDecor(
			"Ankerplatte",
			Vector3.new(5.6, 0.5, 12.6),
			origin + Vector3.new(anchor.x, anchor.y + 0.2, z),
			parent
		)
		plate.Color = Color3.fromRGB(214, 162, 70)
		plate.Material = Enum.Material.Metal
		plate.Reflectance = 0.1
	end
end

--------------------------------------------------------------------------------
-- Zierrat
--------------------------------------------------------------------------------

--[[
	Baeume und Felsbrocken auf den flachen Teilen des Gelaendes - aber nur weit
	genug ausserhalb des Baubereichs, damit sie nie vor der Bruecke stehen.
]]
local function buildDecor(level, origin: Vector3, parent: Instance)
	local z = (level.z or 0) - (level.terrainDepth or 46) * 0.3
	local area = level.buildArea
	local seed = 0
	for _, point in level.terrain do
		seed += math.abs(point.x) + math.abs(point.y)
	end
	local random = Random.new(math.floor(seed))

	for _, span in Terrain.spans(level.terrain) do
		if math.abs(span.y2 - span.y1) > 0.05 or span.x2 - span.x1 < 10 then
			continue
		end

		local count = math.floor((span.x2 - span.x1) / 14)
		for i = 1, count do
			local x = span.x1 + (span.x2 - span.x1) * ((i - 0.5) / count)
			-- Nichts im Baubereich abstellen.
			if x > area.minX - 6 and x < area.maxX + 6 then
				continue
			end
			if random:NextNumber() < 0.65 then
				makeTree(origin + Vector3.new(x, span.y1 + 2.5, z), random:NextNumber(0.8, 1.4), parent)
			else
				makeBoulder(origin + Vector3.new(x, span.y1 + 1, z), random:NextNumber(2.5, 4.5), parent)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Alles zusammen
--------------------------------------------------------------------------------

function LevelBuilder.build(level, origin: Vector3, parent: Instance)
	local root = Instance.new("Folder")
	root.Name = "Arena_" .. level.id
	root.Parent = parent

	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end

	local worldFolder = folder("Welt")
	local decorFolder = folder("Zierrat")
	local anchorFolder = folder("Anker")
	local memberFolder = folder("Bauteile")
	local nodeFolder = folder("Knoten")
	local vehicleFolder = folder("Fahrzeuge")
	local effectFolder = folder("Effekte")

	buildTerrain(level, origin, worldFolder)
	buildWater(level, origin, worldFolder)
	buildAnchors(level, origin, anchorFolder)
	buildDecor(level, origin, decorFolder)

	return {
		root = root,
		world = worldFolder,
		decor = decorFolder,
		anchors = anchorFolder,
		members = memberFolder,
		nodes = nodeFolder,
		vehicles = vehicleFolder,
		effects = effectFolder,
	}
end

--------------------------------------------------------------------------------
-- Brucheffekt
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
