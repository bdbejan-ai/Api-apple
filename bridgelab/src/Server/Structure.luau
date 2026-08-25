--[[
	Structure
	---------
	Verwaltet alle Bauteile EINER Arena. Jeder Spieler hat seine eigene
	Structure-Instanz (deshalb eine Klasse und kein einfaches Modul).

	ZWEI EBENEN, SAUBER GETRENNT

	1) Der BAUPLAN (self.members). Eine reine Datentabelle: welcher Bauteiltyp
	   verbindet welche zwei Ankerpunkte. Der Bauplan geht nie verloren - auch
	   nicht, wenn im Test etwas bricht. Deshalb kann rebuild() jederzeit alles
	   wiederherstellen.

	2) Die SICHTBAREN TEILE. Fuer jedes Bauteil im Bauplan gibt es
	   - ein Model mit mehreren Parts (Traeger, Fahrbahndecke, Klemmen ...),
	   - ein Constraint zwischen den beiden Knotenkugeln
	     (RodConstraint = starr, RopeConstraint = nur Zug),
	   - eine Belastungsanzeige (BillboardGui),
	   - und je Ankerpunkt eine Knotenkugel, sobald dieser genutzt wird.

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
	self.nodes = {} -- Knotenkugeln, indiziert nach Ankerpunkt-Nummer
	self.nextMemberId = 1
	self.labelsVisible = false

	return self
end

--------------------------------------------------------------------------------
-- Positionen
--------------------------------------------------------------------------------

-- Ruheposition eines Ankerpunkts in Weltkoordinaten (inklusive Arena-Versatz).
function Structure:snapPosition(index: number): Vector3
	return self.origin + self.level.snapPoints[index].position
end

-- Aktuelle Position eines Knotens (im Test bewegt er sich).
function Structure:nodePosition(index: number): Vector3
	local node = self.nodes[index]
	if node and node.part then
		return node.part.Position
	end
	return self:snapPosition(index)
end

--------------------------------------------------------------------------------
-- Knotenkugeln
--------------------------------------------------------------------------------

function Structure:ensureNode(index: number)
	if self.nodes[index] then
		return self.nodes[index]
	end

	local snap = self.level.snapPoints[index]
	local size = Config.Physics.nodeSize

	local part = Instance.new("Part")
	part.Name = "Node_" .. index
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(self:snapPosition(index))
	part.Anchored = true -- im Baumodus haelt alles still
	part.CanCollide = false -- die Kugeln sollen dem Fahrzeug nicht im Weg sein
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Metal
	part.Reflectance = 0.15
	part.Color = if snap.fixed then Color3.fromRGB(228, 168, 72) else Color3.fromRGB(92, 96, 108)
	part:SetAttribute("SnapIndex", index)
	part.Parent = self.folders.nodes

	local attachment = Instance.new("Attachment")
	attachment.Name = "NodeAttachment"
	attachment.Parent = part

	self.nodes[index] = {
		part = part,
		attachment = attachment,
		fixed = snap.fixed,
	}
	return self.nodes[index]
end

-- Knoten entfernen, sobald kein Bauteil mehr daran haengt.
function Structure:cleanUnusedNodes()
	local used: { [number]: boolean } = {}
	for _, member in self.members do
		used[member.a] = true
		used[member.b] = true
	end
	for index, node in self.nodes do
		if not used[index] then
			node.part:Destroy()
			self.nodes[index] = nil
		end
	end
end

--[[
	Masse der Knoten setzen.
	Jeder Knoten bekommt die Haelfte des Eigengewichts aller Bauteile, die an
	ihm haengen. So wirkt die Bruecke in der Roblox-Physik plausibel schwer.
]]
function Structure:refreshNodeMasses()
	local tributary: { [number]: number } = {}

	for _, member in self.members do
		if member.broken then
			continue
		end
		local spec = Config.PartTypes[member.kind]
		local length = (self:snapPosition(member.b) - self:snapPosition(member.a)).Magnitude
		local half = length * spec.massPerStud / 2
		tributary[member.a] = (tributary[member.a] or 0) + half
		tributary[member.b] = (tributary[member.b] or 0) + half
	end

	local size = Config.Physics.nodeSize
	local volume = (4 / 3) * math.pi * (size / 2) ^ 3

	for index, node in self.nodes do
		local mass = math.max(tributary[index] or 0, Config.Physics.minNodeMass)
		local density = math.clamp(mass / volume, 0.05, 100)
		node.part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.6, 0.1, 1, 1)
	end
end

--------------------------------------------------------------------------------
-- Aussehen eines Bauteils
--------------------------------------------------------------------------------

--[[
	Jedes Bauteil besteht aus mehreren Parts. Damit sie jedes Bild neu
	ausgerichtet werden koennen, merkt sich jeder Part, WIE er sitzt:

	  mode = "span"  -> laeuft ueber die ganze Laenge (Traeger, Fahrbahn, Seil)
	  mode = "end"   -> sitzt an einem Ende (Klemme, Sockel, Kopf)

	  up      Versatz senkrecht zur Bauteilachse (positiv = nach oben)
	  endAt   nur bei mode = "end": 1 = beim Knoten a, 2 = beim Knoten b
]]
local function addVisual(member, part: Part, mode: string, up: number, endAt: number?)
	table.insert(member.visuals, {
		part = part,
		mode = mode,
		up = up,
		endAt = endAt,
	})
end

function Structure:createMemberInstances(member)
	local spec = Config.PartTypes[member.kind]
	local posA = self:snapPosition(member.a)
	local posB = self:snapPosition(member.b)
	local length = (posB - posA).Magnitude

	local nodeA = self:ensureNode(member.a)
	local nodeB = self:ensureNode(member.b)

	local model = Instance.new("Model")
	model.Name = spec.key .. "_" .. member.id
	model:SetAttribute("MemberId", member.id)
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
		part:SetAttribute("MemberKind", member.kind)
		part.Parent = model
		return part
	end

	----------------------------------------------------------------------------
	-- Je nach Bauteiltyp anders zusammengesetzt
	----------------------------------------------------------------------------

	if member.kind == "Beam" then
		-- Oben eine Fahrbahndecke, darunter ein schmalerer Stahltraeger.
		local deckThickness = 0.3
		local girderThickness = spec.thickness - deckThickness

		local deck = newPart("Deck", Vector3.new(spec.width, deckThickness, length), spec.accentColor, spec.accentMaterial)
		-- Die Oberkante der Decke liegt genau auf der Ankerlinie, damit die
		-- Fahrbahn buendig an die Plattformen anschliesst.
		deck.CanCollide = true
		deck.CanQuery = true
		addVisual(member, deck, "span", -deckThickness / 2)

		local girder = newPart(
			"Girder",
			Vector3.new(spec.width * 0.5, girderThickness, length),
			spec.color,
			spec.material
		)
		addVisual(member, girder, "span", -(deckThickness + girderThickness / 2))

		member.mainPart = girder
		member.stressParts = { girder }
	elseif member.kind == "Cable" then
		-- Duenner Strang mit einer Klemme an jedem Ende.
		local rope = newPart("Strand", Vector3.new(spec.width, spec.thickness, length), spec.color, spec.material)
		addVisual(member, rope, "span", 0)

		for endIndex = 1, 2 do
			local clamp = newPart("Clamp", Vector3.new(0.7, 0.7, 0.8), spec.accentColor, spec.accentMaterial)
			addVisual(member, clamp, "end", 0, endIndex)
		end

		member.mainPart = rope
		member.stressParts = { rope }
	else
		-- Stuetze: Saeule mit Sockel unten und Kopfplatte oben.
		local column = newPart("Column", Vector3.new(spec.width, spec.thickness, length), spec.color, spec.material)
		column.CanCollide = true
		column.CanQuery = true
		addVisual(member, column, "span", 0)

		for endIndex = 1, 2 do
			local plate = newPart("Plate", Vector3.new(spec.width * 1.8, spec.thickness * 1.8, 0.8), spec.accentColor, spec.accentMaterial)
			addVisual(member, plate, "end", 0, endIndex)
		end

		member.mainPart = column
		member.stressParts = { column }
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
	constraint.Attachment0 = nodeA.attachment
	constraint.Attachment1 = nodeB.attachment
	constraint.Parent = nodeA.part

	----------------------------------------------------------------------------
	-- Belastungsanzeige
	----------------------------------------------------------------------------

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
]]
function Structure:createStressLabel(member)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StressLabel"
	billboard.Size = UDim2.fromOffset(78, 38)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 260
	billboard.Enabled = self.labelsVisible
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

	-- Prozentzahl
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

	-- Kraft in Newton, kleiner darunter
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

	-- Balken ganz unten als schnelle optische Anzeige
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

-- Setzt alle Parts eines Bauteils passend zu den aktuellen Knotenpositionen.
function Structure:updateMemberVisual(member)
	if not member.visuals then
		return
	end

	local posA = self:nodePosition(member.a)
	local posB = self:nodePosition(member.b)
	local delta = posB - posA
	local length = delta.Magnitude
	if length < 0.05 then
		return
	end

	local direction = delta.Unit
	local up = perpendicularUp(direction)
	local helper = lookUpVector(delta)
	local midpoint = posA + delta / 2

	for _, visual in member.visuals do
		local part = visual.part
		if visual.mode == "span" then
			-- Ueber die ganze Laenge: nur die Laenge (Z) waechst mit.
			part.Size = Vector3.new(part.Size.X, part.Size.Y, length)
			part.CFrame = CFrame.lookAt(midpoint + up * visual.up, midpoint + direction + up * visual.up, helper)
		else
			-- An einem Ende: feste Groesse, sitzt auf dem Knoten.
			local anchorPoint = if visual.endAt == 1 then posA else posB
			part.CFrame = CFrame.lookAt(anchorPoint + up * visual.up, anchorPoint + direction + up * visual.up, helper)
		end
	end
end

--------------------------------------------------------------------------------
-- Belastungsanzeige
--------------------------------------------------------------------------------

function Structure:setStressLabelsVisible(visible: boolean)
	self.labelsVisible = visible
	for _, member in self.members do
		if member.label then
			member.label.gui.Enabled = visible
		end
	end
end

--[[
	Traegt die aktuellen Kraefte in die Tafeln ein.
	utilisationOf ist eine Funktion, die zu einem Bauteil die Auslastung
	zwischen 0 und 1 liefert (kommt aus ForceEngine).
]]
function Structure:updateStressLabels(utilisationOf)
	if not self.labelsVisible then
		return
	end

	for _, member in self.members do
		local label = member.label
		if not label or member.broken then
			continue
		end

		local utilisation = utilisationOf(member)
		local color = Config.utilisationColor(utilisation)

		label.percent.Text = string.format("%d%%", math.floor(utilisation * 100 + 0.5))
		label.percent.TextColor3 = color

		-- Vorzeichen verstaendlich machen: Zug zieht auseinander, Druck staucht.
		local kindOfLoad = if member.force >= 0 then "Zug" else "Druck"
		label.newtons.Text = string.format("%s %d N", kindOfLoad, math.floor(math.abs(member.force) + 0.5))

		label.bar.Size = UDim2.fromScale(math.clamp(utilisation, 0, 1), 1)
		label.bar.BackgroundColor3 = color
	end
end

--------------------------------------------------------------------------------
-- Budget, Bauen und Entfernen
--------------------------------------------------------------------------------

function Structure:usedBudget(): number
	local total = 0
	for _, member in self.members do
		total += Config.PartTypes[member.kind].cost
	end
	return total
end

--[[
	Prueft, ob ein Bauteil gesetzt werden darf.
	Gibt zurueck: erlaubt (boolean), Begruendung (string)
]]
function Structure:canPlace(kind: string, a: number, b: number): (boolean, string)
	local spec = Config.PartTypes[kind]
	if not spec then
		return false, "Unbekannter Bauteiltyp."
	end

	if not self.level.allowsPart(kind) then
		return false, spec.displayName .. " ist in diesem Level gesperrt."
	end

	local snapA = self.level.snapPoints[a]
	local snapB = self.level.snapPoints[b]
	if not snapA or not snapB then
		return false, "Ankerpunkt gibt es nicht."
	end
	if a == b then
		return false, "Bitte zwei verschiedene Ankerpunkte waehlen."
	end

	for _, member in self.members do
		if (member.a == a and member.b == b) or (member.a == b and member.b == a) then
			return false, "Hier steht schon ein Bauteil."
		end
	end

	local delta = snapB.position - snapA.position
	local length = delta.Magnitude
	if length < spec.minLength then
		return false, string.format("%s ist zu kurz (mindestens %d Studs).", spec.displayName, spec.minLength)
	end
	if length > spec.maxLength then
		return false, string.format("%s ist zu lang (hoechstens %d Studs).", spec.displayName, spec.maxLength)
	end

	if spec.verticalOnly and math.abs(delta.X) > 0.01 then
		return false, spec.displayName .. " laesst sich nur senkrecht bauen."
	end

	-- Zwei feste Ankerpunkte zu verbinden bringt nichts und kostet nur Budget.
	if snapA.fixed and snapB.fixed then
		return false, "Beide Ankerpunkte sind schon fest verankert."
	end

	if self:usedBudget() + spec.cost > self.level.budget then
		return false, "Das Budget reicht nicht mehr."
	end

	return true, ""
end

function Structure:place(kind: string, a: number, b: number)
	local member = {
		id = self.nextMemberId,
		kind = kind,
		a = a,
		b = b,
		broken = false,
		force = 0,
	}
	self.nextMemberId += 1
	table.insert(self.members, member)

	self:createMemberInstances(member)
	self:refreshNodeMasses()
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
	self:cleanUnusedNodes()
	self:refreshNodeMasses()
	return true
end

-- Ein Bauteil versagt unter Ueberlast: Effekt abspielen und Teil zerstoeren.
-- Der Bauplan bleibt erhalten, damit "Zuruecksetzen" alles wiederherstellt.
function Structure:breakMember(member)
	if member.broken then
		return
	end
	local position = (self:nodePosition(member.a) + self:nodePosition(member.b)) / 2
	member.broken = true
	member.force = 0
	self:destroyMemberInstances(member)
	LevelBuilder.playBreakEffect(self.folders.effects, position)
	self:refreshNodeMasses()
end

--------------------------------------------------------------------------------
-- Zuruecksetzen und Physik ein-/ausschalten
--------------------------------------------------------------------------------

-- Baut alle Bauteile aus dem Bauplan neu auf und stellt den Ausgangszustand her.
function Structure:rebuild()
	for _, member in self.members do
		self:destroyMemberInstances(member)
	end
	for index, node in self.nodes do
		node.part:Destroy()
		self.nodes[index] = nil
	end

	for _, member in self.members do
		member.broken = false
		member.force = 0
		self:createMemberInstances(member)
	end
	self:refreshNodeMasses()
end

-- Alles loeschen, auch den Bauplan.
function Structure:clear()
	for _, member in self.members do
		self:destroyMemberInstances(member)
	end
	for index, node in self.nodes do
		node.part:Destroy()
		self.nodes[index] = nil
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
	for _, node in self.nodes do
		if node.fixed then
			node.part.Anchored = true
		else
			node.part.Anchored = not enabled
			if enabled then
				node.part.AssemblyLinearVelocity = Vector3.zero
				node.part.AssemblyAngularVelocity = Vector3.zero
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

return Structure
