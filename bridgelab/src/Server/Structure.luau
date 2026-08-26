--[[
	Structure
	---------
	Verwaltet alle Bauteile EINER Arena. Jeder Spieler hat seine eigene
	Structure-Instanz (deshalb eine Klasse und kein einfaches Modul).

	WAS SICH GEGENUEBER FRUEHER GEAENDERT HAT - FREIES BAUEN

	Frueher gab es je Level eine feste Liste von Ankerpunkten, und ein Bauteil
	verband zwei davon ueber ihre NUMMER. Damit war die Bruecke im Grunde ein
	Ausmalbild: die moeglichen Knoten standen schon fest.

	Jetzt gibt es nur noch ein RASTER. Jeder Rasterpunkt im Baubereich kann ein
	Knoten werden, sobald das erste Bauteil ihn benutzt. Ein Knoten wird ueber
	seine Rasterkoordinate angesprochen:

	    key(x, y) = "gx:gy"        gx = x / 2, gy = y / 2

	Nur die wenigen ANKER des Levels sind fest mit dem Boden verbunden. Alles
	andere muss die Konstruktion selbst tragen - daraus entsteht die Aufgabe.

	ZWEI EBENEN, SAUBER GETRENNT

	1) Der BAUPLAN (self.members). Eine reine Datentabelle: welcher Baustoff
	   verbindet welche zwei Rasterpunkte. Der Bauplan geht nie verloren - auch
	   nicht, wenn im Test etwas bricht. Deshalb kann rebuild() jederzeit alles
	   wiederherstellen.

	2) Die SICHTBAREN TEILE. Fuer jedes Bauteil im Bauplan gibt es ein Model
	   aus mehreren Parts, ein Constraint zwischen den beiden Knotenkugeln
	   (RodConstraint = starr, RopeConstraint = nur Zug) und eine
	   Belastungsanzeige.

	WICHTIGE VEREINFACHUNG
	Die Bauteil-Parts sind immer verankert (Anchored) und werden Bild fuer Bild
	zwischen ihre beiden Knotenkugeln gesetzt. Nur die Knotenkugeln sind echte
	Physikkoerper. Dadurch bleibt die Simulation ruhig und vorhersehbar, und die
	Last des Testfahrzeugs kann gezielt auf die Knoten gegeben werden
	(siehe TestRun.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Materials = require(Shared.Materials)
local Terrain = require(Shared.Terrain)

local LevelBuilder = require(script.Parent.LevelBuilder)

local Structure = {}
Structure.__index = Structure

--------------------------------------------------------------------------------
-- Richtungshelfer
--------------------------------------------------------------------------------

--[[
	CFrame.lookAt braucht einen Hilfsvektor "oben". Zeigt das Bauteil selbst
	senkrecht nach oben (jede Stuetze tut das), waere der uebliche Hilfsvektor
	(0,1,0) parallel zur Bauteilachse - das Ergebnis waere unbrauchbar.
	In dem Fall wird auf (0,0,1) ausgewichen.
]]
local function lookUpVector(direction: Vector3): Vector3
	if math.abs(direction.Unit.Y) > 0.999 then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(0, 1, 0)
end

-- Senkrecht zur Bauteilachse, in der XY-Ebene, zeigt immer nach oben.
local function perpendicularUp(direction: Vector3): Vector3
	local perpendicular = Vector3.new(-direction.Y, direction.X, 0)
	if perpendicular.Magnitude < 1e-4 then
		return Vector3.new(0, 1, 0)
	end
	perpendicular = perpendicular.Unit
	if perpendicular.Y < 0 then
		perpendicular = -perpendicular
	end
	return perpendicular
end

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

function Structure.new(level, origin: Vector3, folders)
	local self = setmetatable({}, Structure)

	self.level = level
	self.origin = origin
	self.folders = folders

	self.members = {} -- der Bauplan
	self.joints = {} -- key -> Knoten, wird beim Bauen angelegt
	self.nextMemberId = 1
	self.labelsVisible = false

	return self
end

--------------------------------------------------------------------------------
-- Rasterpunkte und Knoten
--------------------------------------------------------------------------------

--[[
	Ein Knoten wird ueber seine RASTERKOORDINATE angesprochen, nicht ueber eine
	laufende Nummer. Zwei Bauteile, die auf denselben Rasterpunkt gezogen
	werden, treffen sich dadurch automatisch am selben Knoten - genau das macht
	freies Bauen ueberhaupt erst moeglich.
]]
local function jointKey(x: number, y: number): string
	local g = Config.Build.gridSize
	return string.format("%d:%d", math.round(x / g), math.round(y / g))
end

Structure.jointKey = jointKey

-- Ruheposition eines Rasterpunkts in Weltkoordinaten (inklusive Arena-Versatz).
function Structure:worldPosition(x: number, y: number): Vector3
	return self.origin + Vector3.new(x, y, self.level.z or 0)
end

-- Aktuelle Position eines Knotens (im Test bewegt er sich).
function Structure:jointPosition(key: string): Vector3
	local joint = self.joints[key]
	if not joint then
		return self.origin
	end
	if joint.part then
		return joint.part.Position
	end
	return self:worldPosition(joint.x, joint.y)
end

function Structure:ensureJoint(x: number, y: number)
	local key = jointKey(x, y)
	local existing = self.joints[key]
	if existing then
		return existing, key
	end

	local anchor = self.level.anchorAt(x, y)
	local size = Config.Build.jointSize

	local part = Instance.new("Part")
	part.Name = "Joint_" .. key
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(self:worldPosition(x, y))
	part.Anchored = true -- im Baumodus haelt alles still
	part.CanCollide = false -- die Kugeln sollen dem Fahrzeug nicht im Weg sein
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Metal
	part.Reflectance = 0.15
	--[[
		Anker sind golden, freie Knoten grau. Das ist die wichtigste optische
		Auskunft im ganzen Spiel: nur an den goldenen Punkten kann die Bruecke
		Last in den Boden abgeben.
	]]
	part.Color = if anchor then Color3.fromRGB(228, 168, 72) else Color3.fromRGB(108, 112, 124)
	part:SetAttribute("JointKey", key)
	part.Parent = self.folders.nodes

	local attachment = Instance.new("Attachment")
	attachment.Name = "JointAttachment"
	attachment.Parent = part

	local joint = {
		key = key,
		x = x,
		y = y,
		part = part,
		attachment = attachment,
		fixed = anchor ~= nil,
	}
	self.joints[key] = joint
	return joint, key
end

-- Knoten entfernen, sobald kein Bauteil mehr daran haengt.
function Structure:cleanUnusedJoints()
	local used: { [string]: boolean } = {}
	for _, member in self.members do
		used[member.keyA] = true
		used[member.keyB] = true
	end
	for key, joint in self.joints do
		if not used[key] then
			joint.part:Destroy()
			self.joints[key] = nil
		end
	end
end

--[[
	Masse der Knoten setzen.
	Jeder Knoten bekommt die Haelfte des Eigengewichts aller Bauteile, die an
	ihm haengen. So wirkt die Bruecke in der Roblox-Physik plausibel schwer.
]]
function Structure:refreshJointMasses()
	local tributary: { [string]: number } = {}

	for _, member in self.members do
		if member.broken then
			continue
		end
		local spec = Materials.get(member.material)
		local half = member.length * spec.massPerStud / 2
		tributary[member.keyA] = (tributary[member.keyA] or 0) + half
		tributary[member.keyB] = (tributary[member.keyB] or 0) + half
	end

	local size = Config.Build.jointSize
	local volume = (4 / 3) * math.pi * (size / 2) ^ 3

	for key, joint in self.joints do
		local mass = math.max(tributary[key] or 0, Config.Physics.minNodeMass)
		local density = math.clamp(mass / volume, 0.05, 100)
		joint.part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.6, 0.1, 1, 1)
	end
end

--------------------------------------------------------------------------------
-- Aussehen eines Bauteils
--------------------------------------------------------------------------------

--[[
	Jedes Bauteil besteht aus mehreren Parts. Damit sie jedes Bild neu
	ausgerichtet werden koennen, merkt sich jeder Part, WIE er sitzt:

	  mode = "span"  -> laeuft ueber die ganze Laenge (Traeger, Fahrbahn)
	  mode = "end"   -> sitzt an einem Ende (Klemme, Sockel, Kopf)
	  mode = "part"  -> nur ueber einen Abschnitt von "from" bis "to"
	                    (Anteile der Gesamtlaenge, jeweils 0 bis 1)
	  mode = "sag"   -> wie "part", haengt aber nach unten durch (Seile)

	  up    Versatz senkrecht zur Bauteilachse in der Bildebene
	  side  Versatz quer dazu (in die Tiefe) - dafuer sind Bohlen nebeneinander
	  endAt nur bei mode = "end": 1 = beim Knoten a, 2 = beim Knoten b
]]
local function addVisual(member, part: Part, options)
	table.insert(member.visuals, {
		part = part,
		mode = options.mode,
		up = options.up or 0,
		side = options.side or 0,
		endAt = options.endAt,
		from = options.from,
		to = options.to,
		sag = options.sag,
	})
end

--------------------------------------------------------------------------------
-- Die einzelnen Bauformen
--------------------------------------------------------------------------------

--[[
	FAHRBAHN
	Eine Platte mit zwei Randstreifen und einer Mittelmarkierung. Die
	Oberkante liegt genau auf der Verbindungslinie der beiden Knoten, damit
	die Fahrbahn buendig an die Ufer anschliesst.
]]
local function buildRoadway(self, member, spec, newPart, length)
	local slabThickness = spec.thickness
	local width = spec.width

	local slab = newPart("Fahrbahn", Vector3.new(width, slabThickness, length), spec.color, spec.material)
	addVisual(member, slab, { mode = "span", up = -slabThickness / 2 })

	-- Zwei Randstreifen aus Metall - die Bordkante.
	for _, side in { -1, 1 } do
		local kerb = newPart("Bordkante", Vector3.new(0.5, slabThickness * 1.4, length), spec.accentColor, spec.accentMaterial)
		addVisual(member, kerb, { mode = "span", up = -slabThickness / 2, side = side * (width / 2 - 0.25) })
	end

	-- Mittelstrich, damit man die Fahrtrichtung sieht.
	local stripe = newPart("Mittelstrich", Vector3.new(0.5, 0.08, length * 0.55), Color3.fromRGB(232, 232, 226), Enum.Material.SmoothPlastic)
	addVisual(member, stripe, { mode = "part", from = 0.225, to = 0.775, up = 0.04 })

	member.mainPart = slab
	member.stressParts = { slab }
	return slab
end

--[[
	STAHL ALS DOPPEL-T-TRAEGER
	Ein echter Stahltraeger ist kein Balken, sondern ein "I": zwei breite
	Gurte oben und unten, dazwischen ein duenner Steg. Genau so wird er hier
	auch gebaut - aus drei Parts.

	    ============   Obergurt
	         ||         Steg
	    ============   Untergurt
]]
local function buildSteelBeam(self, member, spec, newPart, length)
	local half = spec.thickness / 2
	local flange = newPart("Obergurt", Vector3.new(spec.width * 1.6, 0.22, length), spec.color, spec.material)
	addVisual(member, flange, { mode = "span", up = half })

	local lower = newPart("Untergurt", Vector3.new(spec.width * 1.6, 0.22, length), spec.color, spec.material)
	addVisual(member, lower, { mode = "span", up = -half })

	local web = newPart("Steg", Vector3.new(spec.width * 0.45, spec.thickness, length), spec.accentColor, spec.accentMaterial)
	addVisual(member, web, { mode = "span", up = 0 })

	member.mainPart = web
	member.stressParts = { flange, lower, web }
	return web
end

--[[
	HOLZ ALS BOHLENBUENDEL
	Drei Bohlen nebeneinander, an beiden Enden mit einem Stahlband
	zusammengehalten. Die Bohlen sind minimal verschieden dick - dadurch
	sieht das Bauteil nach Holz aus und nicht nach einem Klotz.
]]
local function buildWoodBeam(self, member, spec, newPart, length)
	local planks = {}
	for i = -1, 1 do
		local plank = newPart("Bohle", Vector3.new(spec.width * 0.8, spec.thickness * (1 - math.abs(i) * 0.12), length), spec.color, spec.material)
		addVisual(member, plank, { mode = "span", side = i * spec.width * 0.85 })
		table.insert(planks, plank)
	end

	-- Stahlbaender an den Enden.
	for endIndex = 1, 2 do
		local band = newPart("Band", Vector3.new(spec.width * 2.9, spec.thickness * 1.25, 0.4), spec.accentColor, spec.accentMaterial)
		addVisual(member, band, { mode = "end", endAt = endIndex })
	end

	member.mainPart = planks[2]
	member.stressParts = planks
	return planks[2]
end

--[[
	SEIL UND KABEL MIT DURCHHANG
	Ein straff gespanntes Seil sieht falsch aus - echte Seile haengen durch.
	Deshalb besteht ein Seil hier aus fuenf kurzen Stuecken entlang einer
	Parabel. Der Durchhang waechst mit der Laenge, bleibt aber gedeckelt,
	damit ein langes Kabel nicht bis in die Schlucht durchhaengt.

	Fuer die Kraefteberechnung ist der Durchhang ohne Bedeutung: dort zaehlt
	nur die gerade Verbindung zwischen den beiden Knoten.
]]
local function buildCable(self, member, spec, newPart, length)
	local segments = 5
	local sag = math.clamp(length * 0.035, 0.15, 1.6)

	for i = 1, segments do
		local strand = newPart("Strang", Vector3.new(spec.width, spec.thickness, 1), spec.color, spec.material)
		addVisual(member, strand, {
			mode = "sag",
			from = (i - 1) / segments,
			to = i / segments,
			sag = sag,
		})
		if i == 1 then
			member.mainPart = strand
		end
	end

	-- Klemmen an beiden Enden.
	for endIndex = 1, 2 do
		local clamp = newPart("Klemme", Vector3.new(0.75, 0.75, 0.9), spec.accentColor, spec.accentMaterial)
		addVisual(member, clamp, { mode = "end", endAt = endIndex })
	end

	member.stressParts = { member.mainPart }
	return member.mainPart
end

--[[
	HYDRAULIKZYLINDER
	Ein dicker Zylinder auf der einen Haelfte, eine duennere Kolbenstange auf
	der anderen. Faehrt der Zylinder aus, wandern die Knoten auseinander - die
	Stange schaut dann weiter heraus, weil sie ihren Anteil an der Gesamtlaenge
	behaelt. Genau so sieht echte Hydraulik aus.

	    [======#####]---->   eingefahren
	    [======#########]->  ausgefahren
]]
local function buildHydraulic(self, member, spec, newPart, length)
	local barrel = newPart("Zylinder", Vector3.new(spec.width, spec.thickness, 1), spec.color, spec.material)
	addVisual(member, barrel, { mode = "part", from = 0, to = 0.55 })

	local rod = newPart("Kolbenstange", Vector3.new(spec.width * 0.45, spec.thickness * 0.45, 1), spec.accentColor, spec.accentMaterial)
	addVisual(member, rod, { mode = "part", from = 0.5, to = 1 })

	for endIndex = 1, 2 do
		local eye = newPart("Auge", Vector3.new(spec.width * 1.15, spec.thickness * 1.15, 0.6), spec.accentColor, spec.accentMaterial)
		addVisual(member, eye, { mode = "end", endAt = endIndex })
	end

	member.mainPart = barrel
	member.stressParts = { barrel, rod }
	return barrel
end

--------------------------------------------------------------------------------
-- Ein Bauteil sichtbar machen
--------------------------------------------------------------------------------

function Structure:createMemberInstances(member)
	local spec = Materials.get(member.material)
	local jointA = self:ensureJoint(member.ax, member.ay)
	local jointB = self:ensureJoint(member.bx, member.by)
	local posA = self:worldPosition(member.ax, member.ay)
	local posB = self:worldPosition(member.bx, member.by)
	local length = member.length

	local model = Instance.new("Model")
	model.Name = spec.key .. "_" .. member.id
	model:SetAttribute("MemberId", member.id)
	--[[
		Die beiden Endpunkte als Attribut mitgeben. Der Client braucht sie,
		um beim Abreissen genau zu bestimmen, welches Bauteil unter dem
		Zeiger liegt - dafuer rechnet er den Abstand zur Bauteilachse aus,
		statt sich auf einen Strahl zu verlassen, der immer nur das
		vorderste sichtbare Teil trifft.
	]]
	model:SetAttribute("PointA", posA)
	model:SetAttribute("PointB", posB)
	model.Parent = self.folders.members

	member.visuals = {}
	member.model = model

	local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part:SetAttribute("MemberId", member.id)
		part:SetAttribute("MemberMaterial", member.material)
		part.Parent = model
		return part
	end

	--[[
		IST DIESES BAUTEIL FAHRBAHN?

		Nur flach liegende Fahrbahnstuecke traegt das Fahrzeug. Ein steiles
		Stueck Strasse ist eine Rampe, die zu steil ist - und alles andere
		(Holz, Stahl, Seile) ist ohnehin nur Tragwerk.

		Tragwerk darf das Fahrzeug NICHT ausbremsen. Wuerde es das tun,
		koennte man seine Bruecke nicht aussteifen, ohne sich selbst den Weg
		zu verbauen. Deshalb bekommt nur die Fahrbahn eine Kollision.
	]]
	local rise = math.abs(posB.Y - posA.Y) / math.max(length, 1e-4)
	member.isRoadway = spec.drivable and rise <= Config.Test.roadwayMaxRise

	if spec.drivable then
		local slab = buildRoadway(self, member, spec, newPart, length)
		slab.CanCollide = member.isRoadway
		slab.CanQuery = member.isRoadway
	elseif spec.hydraulic then
		buildHydraulic(self, member, spec, newPart, length)
	elseif not spec.rigid then
		buildCable(self, member, spec, newPart, length)
	elseif member.material == "Wood" then
		buildWoodBeam(self, member, spec, newPart, length)
	else
		buildSteelBeam(self, member, spec, newPart, length)
	end

	----------------------------------------------------------------------------
	-- Constraint zwischen den beiden Knoten
	----------------------------------------------------------------------------

	local constraint
	if spec.rigid then
		-- Starrer Stab: haelt den Abstand in beide Richtungen.
		local rod = Instance.new("RodConstraint")
		rod.Length = length
		rod.Thickness = 0.15
		rod.Visible = false
		constraint = rod
	else
		-- Seil: verhindert nur, dass die Knoten weiter auseinandergehen.
		local rope = Instance.new("RopeConstraint")
		rope.Length = length
		rope.Restitution = 0
		rope.Thickness = 0.1
		rope.Visible = false
		constraint = rope
	end
	constraint.Name = "Constraint_" .. member.id
	constraint.Attachment0 = jointA.attachment
	constraint.Attachment1 = jointB.attachment
	constraint.Parent = jointA.part

	member.label = self:createStressLabel(member)
	member.constraint = constraint
	member.broken = false
	member.force = 0

	self:updateMemberVisual(member)
end

--[[
	Kleine Tafel ueber dem Bauteil, die im Test zeigt, wie stark es belastet ist.
	Sie haengt am Hauptteil und wird von Roblox automatisch zu den Clients
	uebertragen - dafuer braucht es kein eigenes RemoteEvent.

	Sichtbar ist sie nur bei den am staerksten belasteten Bauteilen; wer sie
	bei allen einblendet, sieht vor lauter Zahlen die Bruecke nicht mehr
	(siehe Config.Test.maxStressLabels).
]]
function Structure:createStressLabel(member)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StressLabel"
	billboard.Size = UDim2.fromOffset(78, 38)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = Config.Test.labelMaxDistance
	billboard.Enabled = false
	billboard.Parent = member.mainPart

	local frame = Instance.new("Frame")
	frame.Name = "Box"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local percent = Instance.new("TextLabel")
	percent.Name = "Percent"
	percent.Size = UDim2.new(1, 0, 0, 20)
	percent.Position = UDim2.fromOffset(0, 2)
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamBold
	percent.TextSize = 15
	percent.TextColor3 = Color3.fromRGB(240, 240, 245)
	percent.Text = "0%"
	percent.Parent = frame

	local newtons = Instance.new("TextLabel")
	newtons.Name = "Newtons"
	newtons.Size = UDim2.new(1, 0, 0, 12)
	newtons.Position = UDim2.new(0, 0, 0, 21)
	newtons.BackgroundTransparency = 1
	newtons.Font = Enum.Font.Gotham
	newtons.TextSize = 11
	newtons.TextColor3 = Color3.fromRGB(170, 175, 190)
	newtons.Text = "0 N"
	newtons.Parent = frame

	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBg"
	barBackground.Size = UDim2.new(1, -10, 0, 3)
	barBackground.Position = UDim2.new(0, 5, 1, -6)
	barBackground.BackgroundColor3 = Color3.fromRGB(55, 58, 68)
	barBackground.BorderSizePixel = 0
	barBackground.Parent = frame

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Config.UtilisationColors.low
	bar.BorderSizePixel = 0
	bar.Parent = barBackground

	return {
		gui = billboard,
		percent = percent,
		newtons = newtons,
		bar = bar,
		visible = false,
	}
end

function Structure:destroyMemberInstances(member)
	if member.constraint then
		member.constraint:Destroy()
		member.constraint = nil
	end
	if member.model then
		member.model:Destroy()
		member.model = nil
	end
	member.visuals = nil
	member.mainPart = nil
	member.stressParts = nil
	member.label = nil
end

--------------------------------------------------------------------------------
-- Parts zu den aktuellen Knotenpositionen setzen
--------------------------------------------------------------------------------

function Structure:updateMemberVisual(member)
	if not member.visuals then
		return
	end

	local posA = self:jointPosition(member.keyA)
	local posB = self:jointPosition(member.keyB)
	local delta = posB - posA
	local length = delta.Magnitude
	if length < 0.05 then
		return
	end

	local direction = delta.Unit
	local up = perpendicularUp(direction)
	local side = Vector3.new(0, 0, 1)
	local helper = lookUpVector(delta)

	for _, visual in member.visuals do
		local part = visual.part
		local offset = up * visual.up + side * visual.side

		if visual.mode == "span" then
			-- Ueber die ganze Laenge: nur die Laenge (Z) waechst mit.
			local midpoint = posA + delta / 2 + offset
			part.Size = Vector3.new(part.Size.X, part.Size.Y, length)
			part.CFrame = CFrame.lookAt(midpoint, midpoint + direction, helper)
		elseif visual.mode == "end" then
			-- An einem Ende: feste Groesse, sitzt auf dem Knoten.
			local anchorPoint = (if visual.endAt == 1 then posA else posB) + offset
			part.CFrame = CFrame.lookAt(anchorPoint, anchorPoint + direction, helper)
		elseif visual.mode == "part" then
			-- Nur ein Abschnitt der Gesamtlaenge.
			local from = posA + delta * visual.from + offset
			local to = posA + delta * visual.to + offset
			local piece = to - from
			local pieceLength = piece.Magnitude
			if pieceLength > 0.02 then
				local middle = from + piece / 2
				part.Size = Vector3.new(part.Size.X, part.Size.Y, pieceLength)
				part.CFrame = CFrame.lookAt(middle, middle + piece.Unit, helper)
			end
		elseif visual.mode == "sag" then
			--[[
				Durchhaengendes Seilstueck. Die Parabel ist an beiden Enden
				null und in der Mitte am tiefsten:  4 * t * (1 - t)
			]]
			local function pointAt(t: number): Vector3
				local drop = visual.sag * 4 * t * (1 - t)
				return posA + delta * t + offset - Vector3.new(0, drop, 0)
			end
			local from = pointAt(visual.from)
			local to = pointAt(visual.to)
			local piece = to - from
			local pieceLength = piece.Magnitude
			if pieceLength > 0.02 then
				local middle = from + piece / 2
				part.Size = Vector3.new(part.Size.X, part.Size.Y, pieceLength)
				part.CFrame = CFrame.lookAt(middle, middle + piece.Unit, helper)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Belastungsanzeige
--------------------------------------------------------------------------------

function Structure:hideAllStressLabels()
	self.labelsVisible = false
	for _, member in self.members do
		if member.label and member.label.visible then
			member.label.gui.Enabled = false
			member.label.visible = false
		end
	end
end

--[[
	Traegt die aktuellen Kraefte in die Tafeln ein.

	NUR DIE WICHTIGSTEN TAFELN WERDEN GEZEIGT
	Frueher bekam jedes Bauteil eine Tafel. Bei vierzig Teilen war der
	Bildschirm zugepflastert und man sah die Bruecke nicht mehr. Jetzt werden
	die Bauteile nach Auslastung sortiert, und nur die vordersten bekommen
	eine Tafel - und auch nur, wenn sie ueberhaupt nennenswert belastet sind.

	Die FARBE am Bauteil bleibt immer sichtbar. Sie ist die Hauptinformation,
	die Zahlen sind die Feinheit.

	utilisationOf ist eine Funktion, die zu einem Bauteil die Auslastung
	zwischen 0 und 1 liefert (kommt aus ForceEngine).
]]
function Structure:updateStressLabels(utilisationOf)
	if not self.labelsVisible then
		return
	end

	local ranked = {}
	for _, member in self.members do
		if member.label and not member.broken and not member.slack then
			table.insert(ranked, { member = member, utilisation = utilisationOf(member) })
		end
	end

	table.sort(ranked, function(a, b)
		return a.utilisation > b.utilisation
	end)

	local shown: { [number]: boolean } = {}
	local limit = math.min(#ranked, Config.Test.maxStressLabels)

	for i = 1, limit do
		local entry = ranked[i]
		if entry.utilisation < Config.Test.minLabelUtilisation then
			break
		end

		local member = entry.member
		local label = member.label
		local utilisation = entry.utilisation
		local color = Config.utilisationColor(utilisation)

		label.percent.Text = string.format("%d%%", math.floor(utilisation * 100 + 0.5))
		label.percent.TextColor3 = color

		-- Vorzeichen verstaendlich machen: Zug zieht auseinander, Druck staucht.
		local kindOfLoad = if member.force >= 0 then "Zug" else "Druck"
		label.newtons.Text = string.format("%s %d N", kindOfLoad, math.floor(math.abs(member.force) + 0.5))

		label.bar.Size = UDim2.fromScale(math.clamp(utilisation, 0, 1), 1)
		label.bar.BackgroundColor3 = color

		if not label.visible then
			label.gui.Enabled = true
			label.visible = true
		end
		shown[member.id] = true
	end

	-- Alles, was diesmal nicht unter den vordersten war, wieder ausblenden.
	for _, member in self.members do
		local label = member.label
		if label and label.visible and not shown[member.id] then
			label.gui.Enabled = false
			label.visible = false
		end
	end
end

function Structure:setStressLabelsActive(active: boolean)
	self.labelsVisible = active
	if not active then
		self:hideAllStressLabels()
	end
end

--------------------------------------------------------------------------------
-- Budget
--------------------------------------------------------------------------------

--[[
	KOSTEN JE STUD - der wichtigste Unterschied zum frueheren Modell

	Frueher kostete ein Bauteil einen Festpreis, egal wie lang es war. Beim
	freien Bauen waere das unsinnig: jeder wuerde nur noch die laengsten
	moeglichen Teile setzen, weil Laenge nichts kostet. Jetzt kostet jedes
	Bauteil costPerStud mal Laenge, und das Budget steuert wirklich, wie viel
	Material verbaut werden darf.
]]
function Structure:usedBudget(): number
	local total = 0
	for _, member in self.members do
		total += member.cost
	end
	return total
end

function Structure:remainingBudget(): number
	return self.level.budget - self:usedBudget()
end

--------------------------------------------------------------------------------
-- Bauen
--------------------------------------------------------------------------------

--[[
	Prueft, ob ein Bauteil gesetzt werden darf.
	Gibt zurueck: erlaubt (boolean), Begruendung (string)

	Diese Funktion ist die einzige Stelle, an der ueber Bauen entschieden wird.
	Der Client prueft dasselbe noch einmal fuer die Vorschau, aber verlassen
	tut sich der Server ausschliesslich auf diese Pruefung hier: was der
	Client schickt, ist ein WUNSCH, keine Tatsache.
]]
function Structure:canPlace(material: string, ax: number, ay: number, bx: number, by: number): (boolean, string)
	local spec = Materials.get(material)
	if not spec then
		return false, "Unbekannter Baustoff."
	end

	if not self.level.allowsMaterial(material) then
		return false, spec.displayName .. " ist in diesem Level gesperrt."
	end

	if #self.members >= Config.Build.maxMembers then
		return false, string.format("Mehr als %d Bauteile gehen nicht.", Config.Build.maxMembers)
	end

	----------------------------------------------------------------------------
	-- Auf dem Raster?
	----------------------------------------------------------------------------

	local grid = Config.Build.gridSize
	for _, value in { ax, ay, bx, by } do
		if math.abs(value - math.round(value / grid) * grid) > 0.01 then
			return false, "Knoten muessen auf dem Raster liegen."
		end
	end

	if jointKey(ax, ay) == jointKey(bx, by) then
		return false, "Anfang und Ende sind derselbe Punkt."
	end

	----------------------------------------------------------------------------
	-- Laenge
	----------------------------------------------------------------------------

	local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	if length < spec.minLength - 0.01 then
		return false, string.format("%s ist zu kurz (mindestens %d Studs).", spec.displayName, spec.minLength)
	end
	if length > spec.maxLength + 0.01 then
		return false, string.format("%s ist zu lang (hoechstens %d Studs).", spec.displayName, spec.maxLength)
	end

	----------------------------------------------------------------------------
	-- Im Baubereich?
	----------------------------------------------------------------------------

	--[[
		Anker duerfen AUSSERHALB des Baubereichs liegen - sie sind ja der
		Anschluss ans Ufer. Alles andere muss drin sein, sonst koennte man
		die Bruecke einfach neben dem Level entlangbauen.
	]]
	local area = self.level.buildArea
	local function insideArea(x: number, y: number): boolean
		if self.level.anchorAt(x, y) then
			return true
		end
		return x >= area.minX - 0.01
			and x <= area.maxX + 0.01
			and y >= area.minY - 0.01
			and y <= area.maxY + 0.01
	end

	if not insideArea(ax, ay) or not insideArea(bx, by) then
		return false, "Ausserhalb des Baubereichs."
	end

	----------------------------------------------------------------------------
	-- Steckt das Bauteil im Berg?
	----------------------------------------------------------------------------

	if Terrain.segmentBlocked(self.level.terrain, ax, ay, bx, by) then
		return false, "Das Bauteil laeuft durch den Felsen."
	end

	----------------------------------------------------------------------------
	-- Steht hier schon dasselbe?
	----------------------------------------------------------------------------

	--[[
		Zwei Bauteile auf denselben zwei Knoten sind ausdruecklich ERLAUBT -
		eine Strasse mit einem Stahltraeger daneben zu verstaerken ist eine
		der wichtigsten Techniken im Spiel. Verboten ist nur, ZWEIMAL DENSELBEN
		Baustoff dorthin zu legen: das waere kein Bauen mehr, sondern nur noch
		Budget verbrennen.
	]]
	local keyA, keyB = jointKey(ax, ay), jointKey(bx, by)
	for _, member in self.members do
		local sameEnds = (member.keyA == keyA and member.keyB == keyB)
			or (member.keyA == keyB and member.keyB == keyA)
		if sameEnds and member.material == material then
			return false, "Hier liegt schon " .. spec.displayName .. "."
		end
	end

	----------------------------------------------------------------------------
	-- Budget
	----------------------------------------------------------------------------

	local cost = Materials.cost(material, length)
	if self:usedBudget() + cost > self.level.budget then
		return false, string.format("Das Budget reicht nicht (%d noetig, %d uebrig).", cost, self:remainingBudget())
	end

	return true, ""
end

function Structure:place(material: string, ax: number, ay: number, bx: number, by: number, phase: number?)
	local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	local spec = Materials.get(material)

	local member = {
		id = self.nextMemberId,
		material = material,
		ax = ax,
		ay = ay,
		bx = bx,
		by = by,
		keyA = jointKey(ax, ay),
		keyB = jointKey(bx, by),
		length = length,
		cost = Materials.cost(material, length),
		broken = false,
		slack = false,
		force = 0,

		--[[
			Die Phase merkt sich nur ein Zylinder. Bei allen anderen Baustoffen
			bliebe sie ein Feld, das nie jemand liest - und das beim Suchen
			nach Fehlern nur ablenkt.
		]]
		phase = if spec and spec.hydraulic
			then math.clamp(math.round(phase or 1), 1, Config.Hydraulics.phaseCount)
			else nil,
		extension = 1,
	}
	self.nextMemberId += 1
	table.insert(self.members, member)

	self:createMemberInstances(member)
	self:refreshJointMasses()
	return member
end

function Structure:findMemberById(id: number)
	for index, member in self.members do
		if member.id == id then
			return member, index
		end
	end
	return nil, nil
end

function Structure:remove(id: number): boolean
	local member, index = self:findMemberById(id)
	if not member or not index then
		return false
	end
	self:destroyMemberInstances(member)
	table.remove(self.members, index)
	self:cleanUnusedJoints()
	self:refreshJointMasses()
	return true
end

-- Ein Bauteil versagt unter Ueberlast: Effekt abspielen und Teil zerstoeren.
-- Der Bauplan bleibt erhalten, damit "Zuruecksetzen" alles wiederherstellt.
function Structure:breakMember(member)
	if member.broken then
		return
	end
	local position = (self:jointPosition(member.keyA) + self:jointPosition(member.keyB)) / 2
	member.broken = true
	member.force = 0
	self:destroyMemberInstances(member)
	LevelBuilder.playBreakEffect(self.folders.effects, position)
	self:refreshJointMasses()
end

--------------------------------------------------------------------------------
-- Hydraulik
--------------------------------------------------------------------------------

--[[
	Einen Hydraulikzylinder aus- oder einfahren.

	factor = 1   eingefahren, also genau die gebaute Laenge
	factor = 1.5 ausgefahren (Config.Hydraulics.extendFactor)

	Bewegt wird ueber die Laenge des RodConstraint. Die Roblox-Physik zieht
	die beiden Knoten dann selbst auseinander und nimmt alles mit, was daran
	haengt - genau das ist der Sinn einer Klappbruecke.
]]
function Structure:setHydraulicExtension(member, factor: number)
	if not member.constraint or member.broken then
		return
	end
	local spec = Materials.get(member.material)
	if not spec or not spec.hydraulic then
		return
	end
	member.extension = factor
	member.constraint.Length = member.length * factor
end

function Structure:hydraulicMembers(phase: number?)
	local list = {}
	for _, member in self.members do
		local spec = Materials.get(member.material)
		if spec and spec.hydraulic and not member.broken then
			if phase == nil or (member.phase or 1) == phase then
				table.insert(list, member)
			end
		end
	end
	return list
end

-- Welcher Phase ein Zylinder zugeordnet ist (1 bis Config.Hydraulics.phaseCount).
function Structure:setMemberPhase(id: number, phase: number): boolean
	local member = self:findMemberById(id)
	if not member then
		return false
	end
	local spec = Materials.get(member.material)
	if not spec or not spec.hydraulic then
		return false
	end
	member.phase = math.clamp(math.round(phase), 1, Config.Hydraulics.phaseCount)
	return true
end

--------------------------------------------------------------------------------
-- Zuruecksetzen und Physik ein-/ausschalten
--------------------------------------------------------------------------------

-- Baut alle Bauteile aus dem Bauplan neu auf und stellt den Ausgangszustand her.
function Structure:rebuild()
	for _, member in self.members do
		self:destroyMemberInstances(member)
	end
	for key, joint in self.joints do
		joint.part:Destroy()
		self.joints[key] = nil
	end

	for _, member in self.members do
		member.broken = false
		member.slack = false
		member.force = 0
		member.extension = 1
		self:createMemberInstances(member)
	end
	self:refreshJointMasses()
end

-- Alles loeschen, auch den Bauplan.
function Structure:clear()
	for _, member in self.members do
		self:destroyMemberInstances(member)
	end
	for key, joint in self.joints do
		joint.part:Destroy()
		self.joints[key] = nil
	end
	self.members = {}
	self.nextMemberId = 1
end

--[[
	Physik freigeben oder sperren.
	Im Baumodus sind alle Knoten verankert - die Konstruktion steht still, auch
	wenn sie eigentlich einstuerzen wuerde. Erst der Test loest die Bremse.
]]
function Structure:setPhysicsEnabled(enabled: boolean)
	for _, joint in self.joints do
		if joint.fixed then
			joint.part.Anchored = true
		else
			joint.part.Anchored = not enabled
			if enabled then
				joint.part.AssemblyLinearVelocity = Vector3.zero
				joint.part.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end

function Structure:activeMembers()
	local list = {}
	for _, member in self.members do
		if not member.broken then
			table.insert(list, member)
		end
	end
	return list
end

function Structure:updateAllVisuals()
	for _, member in self.members do
		if not member.broken then
			self:updateMemberVisual(member)
		end
	end
end

--[[
	Der Bauplan als schlichte Tabelle - fuer das Speichern im Profil und fuer
	die Uebertragung zum Client.
]]
function Structure:toPlan()
	local out = {}
	for _, member in self.members do
		table.insert(out, {
			id = member.id,
			material = member.material,
			ax = member.ax,
			ay = member.ay,
			bx = member.bx,
			by = member.by,
			cost = member.cost,
			phase = member.phase,
		})
	end
	return out
end

return Structure
