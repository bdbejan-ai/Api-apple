--[[
	Structure
	---------
	Verwaltet alle vom Spieler gesetzten Bauteile.

	Zwei Ebenen sind hier sauber getrennt:

	1) Der BAUPLAN (ctx.members). Eine reine Datentabelle:
	   welcher Bauteiltyp verbindet welche zwei Ankerpunkte.
	   Der Bauplan geht nie verloren - auch nicht, wenn im Test etwas bricht.
	   Deshalb laesst sich mit rebuild() jederzeit alles wiederherstellen.

	2) Die SICHTBAREN TEILE. Fuer jedes Bauteil im Bauplan gibt es
	   - einen Part (Aussehen und Kollision),
	   - ein Constraint zwischen den beiden Knotenkugeln
	     (RodConstraint = starr, RopeConstraint = nur Zug),
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

local ctx -- wird in init() gesetzt

-- Knotenkugeln, indiziert nach Ankerpunkt-Nummer.
-- { part = Part, attachment = Attachment, fixed = boolean }
local nodes: { [number]: any } = {}

--------------------------------------------------------------------------------
-- Hilfsfunktionen
--------------------------------------------------------------------------------

local function snapPosition(index: number): Vector3
	return ctx.level.snapPoints[index].position
end

-- Aktuelle Position eines Knotens (im Test bewegt er sich).
function Structure.nodePosition(index: number): Vector3
	local node = nodes[index]
	if node and node.part then
		return node.part.Position
	end
	return snapPosition(index)
end

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

-- Senkrecht zur Bauteilachse, in der XY-Ebene, zeigt nach oben.
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
-- Knotenkugeln
--------------------------------------------------------------------------------

local function ensureNode(index: number)
	if nodes[index] then
		return nodes[index]
	end

	local snap = ctx.level.snapPoints[index]

	local part = Instance.new("Part")
	part.Name = "Node_" .. index
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(Config.Physics.nodeSize, Config.Physics.nodeSize, Config.Physics.nodeSize)
	part.CFrame = CFrame.new(snap.position)
	part.Anchored = true -- im Baumodus haelt alles still
	part.CanCollide = false -- die Kugeln sollen dem Fahrzeug nicht im Weg sein
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Metal
	part.Color = if snap.fixed then Color3.fromRGB(230, 160, 60) else Color3.fromRGB(70, 70, 78)
	part:SetAttribute("SnapIndex", index)
	part.Parent = ctx.folders.nodes

	local attachment = Instance.new("Attachment")
	attachment.Name = "NodeAttachment"
	attachment.Parent = part

	nodes[index] = {
		part = part,
		attachment = attachment,
		fixed = snap.fixed,
	}
	return nodes[index]
end

-- Knoten entfernen, sobald kein Bauteil mehr daran haengt.
local function cleanUnusedNodes()
	local used: { [number]: boolean } = {}
	for _, member in ctx.members do
		used[member.a] = true
		used[member.b] = true
	end
	for index, node in nodes do
		if not used[index] then
			node.part:Destroy()
			nodes[index] = nil
		end
	end
end

--[[
	Masse der Knoten setzen.
	Jeder Knoten bekommt die Haelfte des Eigengewichts aller Bauteile, die an
	ihm haengen. So wirkt die Bruecke in der Roblox-Physik plausibel schwer.
]]
local function refreshNodeMasses()
	local tributary: { [number]: number } = {}

	for _, member in ctx.members do
		if member.broken then
			continue
		end
		local spec = Config.PartTypes[member.kind]
		local length = (snapPosition(member.b) - snapPosition(member.a)).Magnitude
		local half = length * spec.massPerStud / 2
		tributary[member.a] = (tributary[member.a] or 0) + half
		tributary[member.b] = (tributary[member.b] or 0) + half
	end

	local size = Config.Physics.nodeSize
	local volume = (4 / 3) * math.pi * (size / 2) ^ 3

	for index, node in nodes do
		local mass = math.max(tributary[index] or 0, Config.Physics.minNodeMass)
		local density = math.clamp(mass / volume, 0.05, 100)
		node.part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.6, 0.1, 1, 1)
	end
end

--------------------------------------------------------------------------------
-- Sichtbare Teile eines Bauteils
--------------------------------------------------------------------------------

local function createMemberInstances(member)
	local spec = Config.PartTypes[member.kind]
	local posA = snapPosition(member.a)
	local posB = snapPosition(member.b)
	local length = (posB - posA).Magnitude

	local nodeA = ensureNode(member.a)
	local nodeB = ensureNode(member.b)

	-- Sichtbarer Part
	local part = Instance.new("Part")
	part.Name = spec.key .. "_" .. member.id
	part.Size = Vector3.new(spec.width, spec.thickness, length)
	part.Anchored = true
	part.CanCollide = spec.drivable or spec.key == "Pillar"
	part.CanTouch = false
	part.Material = spec.material
	part.Color = spec.baseColor
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("MemberId", member.id)
	part:SetAttribute("MemberKind", member.kind)
	part.Parent = ctx.folders.members

	-- Constraint zwischen den beiden Knoten
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

	member.part = part
	member.constraint = constraint
	member.broken = false
	member.force = 0

	Structure.updateMemberVisual(member)
end

local function destroyMemberInstances(member)
	if member.constraint then
		member.constraint:Destroy()
		member.constraint = nil
	end
	if member.part then
		member.part:Destroy()
		member.part = nil
	end
end

-- Setzt Part-Groesse und -Lage passend zu den aktuellen Knotenpositionen.
function Structure.updateMemberVisual(member)
	local part = member.part
	if not part then
		return
	end

	local posA = Structure.nodePosition(member.a)
	local posB = Structure.nodePosition(member.b)
	local delta = posB - posA
	local length = delta.Magnitude
	if length < 0.05 then
		return
	end

	local spec = Config.PartTypes[member.kind]

	-- Bei befahrbaren Bauteilen liegt die OBERKANTE auf der Ankerlinie,
	-- damit die Fahrbahn buendig an die Plattformen anschliesst.
	local offset = Vector3.zero
	if spec.drivable then
		offset = -perpendicularUp(delta.Unit) * (spec.thickness / 2)
	end

	part.Size = Vector3.new(spec.width, spec.thickness, length)
	part.CFrame = CFrame.lookAt(posA + delta / 2 + offset, posB + offset, lookUpVector(delta))
end

--------------------------------------------------------------------------------
-- Bauen und Entfernen
--------------------------------------------------------------------------------

function Structure.usedBudget(): number
	local total = 0
	for _, member in ctx.members do
		total += Config.PartTypes[member.kind].cost
	end
	return total
end

--[[
	Prueft, ob ein Bauteil gesetzt werden darf.
	Gibt zurueck: erlaubt (boolean), Begruendung (string)
]]
function Structure.canPlace(kind: string, a: number, b: number): (boolean, string)
	local spec = Config.PartTypes[kind]
	if not spec then
		return false, "Unbekannter Bauteiltyp."
	end

	local snapA = ctx.level.snapPoints[a]
	local snapB = ctx.level.snapPoints[b]
	if not snapA or not snapB then
		return false, "Ankerpunkt gibt es nicht."
	end
	if a == b then
		return false, "Bitte zwei verschiedene Ankerpunkte waehlen."
	end

	for _, member in ctx.members do
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

	-- Zwei feste Ankerpunkte zu verbinden bringt nichts und wuerde nur Budget kosten.
	if snapA.fixed and snapB.fixed then
		return false, "Beide Ankerpunkte sind schon fest verankert."
	end

	if Structure.usedBudget() + spec.cost > ctx.level.budget then
		return false, "Das Budget reicht nicht mehr."
	end

	return true, ""
end

function Structure.place(kind: string, a: number, b: number)
	local member = {
		id = ctx.nextMemberId,
		kind = kind,
		a = a,
		b = b,
		part = nil,
		constraint = nil,
		broken = false,
		force = 0,
	}
	ctx.nextMemberId += 1
	table.insert(ctx.members, member)

	createMemberInstances(member)
	refreshNodeMasses()
	return member
end

function Structure.findMemberById(id: number)
	for index, member in ctx.members do
		if member.id == id then
			return member, index
		end
	end
	return nil, nil
end

function Structure.remove(id: number): boolean
	local member, index = Structure.findMemberById(id)
	if not member then
		return false
	end
	destroyMemberInstances(member)
	table.remove(ctx.members, index)
	cleanUnusedNodes()
	refreshNodeMasses()
	return true
end

-- Ein Bauteil versagt unter Ueberlast: Effekt abspielen und Teil zerstoeren.
-- Der Bauplan bleibt erhalten, damit "Zuruecksetzen" alles wiederherstellt.
function Structure.breakMember(member)
	if member.broken then
		return
	end
	local position = (Structure.nodePosition(member.a) + Structure.nodePosition(member.b)) / 2
	member.broken = true
	member.force = 0
	destroyMemberInstances(member)
	LevelBuilder.playBreakEffect(ctx.folders.effects, position)
	refreshNodeMasses()
end

--------------------------------------------------------------------------------
-- Zuruecksetzen und Physik ein-/ausschalten
--------------------------------------------------------------------------------

-- Baut alle Bauteile aus dem Bauplan neu auf und stellt den Ausgangszustand her.
function Structure.rebuild()
	for _, member in ctx.members do
		destroyMemberInstances(member)
	end
	for index, node in nodes do
		node.part:Destroy()
		nodes[index] = nil
	end

	for _, member in ctx.members do
		member.broken = false
		member.force = 0
		createMemberInstances(member)
	end
	refreshNodeMasses()
end

--[[
	Physik freigeben oder sperren.
	Im Baumodus sind alle Knoten verankert - die Konstruktion steht still, auch
	wenn sie eigentlich einstuerzen wuerde. Erst der Test loest die Bremse.
]]
function Structure.setPhysicsEnabled(enabled: boolean)
	for _, node in nodes do
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

function Structure.getNodes()
	return nodes
end

function Structure.activeMembers()
	local list = {}
	for _, member in ctx.members do
		if not member.broken then
			table.insert(list, member)
		end
	end
	return list
end

function Structure.updateAllVisuals()
	for _, member in ctx.members do
		if not member.broken then
			Structure.updateMemberVisual(member)
		end
	end
end

function Structure.init(context)
	ctx = context
	nodes = {}
end

return Structure
