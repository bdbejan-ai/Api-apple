--[[
	BuildingSchool
	--------------
	Die Bauschule: vier Zeichnungen, die zeigen, WARUM eine Bruecke haelt.

	WOZU DAS DA IST
	Die Anleitung erklaert die BEDIENUNG - klicken, ziehen, testen. Sie
	erklaert nicht, warum ein Viereck einstuerzt und ein Dreieck nicht. Wer
	das nicht weiss, baut eine schnurgerade Fahrbahn, sieht sie durchsacken
	und weiss nicht, was er anders machen soll.

	Die vier Bilder sind genau die vier Dinge, mit denen sich alle zwoelf
	Level loesen lassen:

	    1. Dreiecke halten, Vierecke nicht
	    2. So sieht ein Fachwerk aus
	    3. Bricht die Fahrbahn, ein zweites Bauteil daneben
	    4. Hoeher bauen heisst weniger Kraft

	WARUM ZEICHNUNGEN UND NICHT TEXT
	Ein Bild versteht auch, wer die Sprache nicht kann. Die Bildunterschriften
	sind uebersetzt, aber die Zeichnungen tragen die Aussage schon allein -
	und genau darum geht es beim Einstieg.

	Gezeichnet wird aus schmalen, gedrehten Rechtecken. Bilder muesste man bei
	Roblox hochladen und mitliefern, und das kann dieses Projekt nicht.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local I18n = require(Shared.I18n)

local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)

local BuildingSchool = {}
BuildingSchool.__index = BuildingSchool

--------------------------------------------------------------------------------
-- Zeichnen
--------------------------------------------------------------------------------

--[[
	Eine Linie von (x1,y1) nach (x2,y2) innerhalb des Elternelements.

	Roblox kennt keine Linien, nur Rechtecke. Ein schmales Rechteck, das um
	den richtigen Winkel gedreht ist, sieht aber genauso aus. Gedreht wird um
	die MITTE - deshalb wird das Rechteck auf den Mittelpunkt der Strecke
	gesetzt und bekommt deren Laenge.
]]
local function line(parent: Instance, x1: number, y1: number, x2: number, y2: number, options)
	options = options or {}
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.5 then
		return nil
	end

	local piece = Instance.new("Frame")
	piece.Name = options.name or "Linie"
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	piece.Size = UDim2.fromOffset(length, options.thickness or 3)
	-- Bildschirm-Y zeigt nach unten, deshalb das Minuszeichen im Winkel.
	piece.Rotation = math.deg(math.atan2(dy, dx))
	piece.BackgroundColor3 = options.color or Theme.colors.text
	piece.BackgroundTransparency = options.transparency or 0
	piece.BorderSizePixel = 0
	piece.ZIndex = options.zIndex or 2
	piece.Parent = parent
	Theme.corner(piece, 2)
	return piece
end

local function dot(parent: Instance, x: number, y: number, color: Color3?, size: number?)
	local point = Instance.new("Frame")
	point.Name = "Knoten"
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.Position = UDim2.fromOffset(x, y)
	point.Size = UDim2.fromOffset(size or 8, size or 8)
	point.BackgroundColor3 = color or Color3.fromRGB(228, 168, 72)
	point.BorderSizePixel = 0
	point.ZIndex = 3
	point.Parent = parent
	Theme.corner(point, 4)
	return point
end

--------------------------------------------------------------------------------
-- Die vier Zeichnungen
--------------------------------------------------------------------------------

local ROAD = Color3.fromRGB(126, 134, 148)
local WOOD = Color3.fromRGB(178, 128, 74)
local STEEL = Color3.fromRGB(168, 178, 194)
local BAD = Color3.fromRGB(226, 82, 70)
local GOOD = Color3.fromRGB(86, 196, 122)

--[[
	Bild 1: links ein Viereck, das zur Raute wird, rechts ein Dreieck.

	Das Viereck wird zweimal gezeichnet: einmal aufrecht und blass, einmal
	verschoben und rot. Genau das ist die Aussage - die Stablaengen aendern
	sich nicht, die Form aber schon.
]]
local function drawTriangles(box: Frame)
	-- Viereck, aufrecht und blass
	line(box, 20, 20, 90, 20, { color = ROAD, transparency = 0.6 })
	line(box, 20, 20, 20, 80, { color = ROAD, transparency = 0.6 })
	line(box, 90, 20, 90, 80, { color = ROAD, transparency = 0.6 })
	line(box, 20, 80, 90, 80, { color = ROAD, transparency = 0.6 })

	-- Dasselbe Viereck, zur Raute verschoben
	line(box, 45, 20, 115, 20, { color = BAD })
	line(box, 45, 20, 20, 80, { color = BAD })
	line(box, 115, 20, 90, 80, { color = BAD })
	line(box, 20, 80, 90, 80, { color = BAD })
	dot(box, 45, 20, BAD)
	dot(box, 115, 20, BAD)

	-- Dreieck: laesst sich nicht verziehen
	line(box, 165, 80, 235, 80, { color = GOOD })
	line(box, 165, 80, 200, 20, { color = GOOD })
	line(box, 235, 80, 200, 20, { color = GOOD })
	dot(box, 200, 20, GOOD)
	dot(box, 165, 80, GOOD)
	dot(box, 235, 80, GOOD)
end

-- Bild 2: ein Fachwerk mit Fahrbahn, Obergurt, Pfosten und Diagonalen.
local function drawTruss(box: Frame)
	local left, right, deckY, topY = 20, 236, 78, 26
	local bays = 4
	local step = (right - left) / bays

	for i = 0, bays - 1 do
		local x1 = left + step * i
		local x2 = left + step * (i + 1)
		line(box, x1, deckY, x2, deckY, { color = ROAD, thickness = 5 })
		line(box, x1, topY, x2, topY, { color = STEEL })
		-- Diagonalen abwechselnd, so entstehen lauter Dreiecke.
		if i % 2 == 0 then
			line(box, x1, deckY, x2, topY, { color = WOOD })
		else
			line(box, x1, topY, x2, deckY, { color = WOOD })
		end
	end

	for i = 0, bays do
		local x = left + step * i
		line(box, x, deckY, x, topY, { color = WOOD })
		dot(box, x, deckY, if i == 0 or i == bays then Color3.fromRGB(228, 168, 72) else Color3.fromRGB(150, 156, 170), 7)
	end
end

--[[
	Bild 3: dieselbe Strecke einmal einfach und einmal doppelt belegt.
	Oben reisst die Strasse, unten teilen sich zwei Bauteile die Kraft.
]]
local function drawDoubling(box: Frame)
	-- Oben: nur Strasse, gerissen
	line(box, 30, 26, 110, 26, { color = ROAD, thickness = 5 })
	line(box, 66, 14, 74, 38, { color = BAD, thickness = 3 })
	dot(box, 30, 26, Color3.fromRGB(150, 156, 170), 7)
	dot(box, 110, 26, Color3.fromRGB(150, 156, 170), 7)

	-- Unten: Strasse und Stahl auf denselben zwei Knoten
	line(box, 150, 62, 230, 62, { color = ROAD, thickness = 5 })
	line(box, 150, 74, 230, 74, { color = STEEL, thickness = 5 })
	dot(box, 150, 68, Color3.fromRGB(228, 168, 72), 8)
	dot(box, 230, 68, Color3.fromRGB(228, 168, 72), 8)
end

--[[
	Bild 4: dasselbe Fachwerk flach und hoch.
	Flach heisst viel Kraft im Gurt (dicker roter Strich), hoch wenig.
]]
local function drawDepth(box: Frame)
	-- Flach: Gurt dick und rot
	line(box, 16, 44, 108, 44, { color = BAD, thickness = 7 })
	line(box, 16, 70, 108, 70, { color = ROAD, thickness = 4 })
	line(box, 16, 44, 16, 70, { color = WOOD })
	line(box, 62, 44, 62, 70, { color = WOOD })
	line(box, 108, 44, 108, 70, { color = WOOD })
	line(box, 16, 70, 62, 44, { color = WOOD })
	line(box, 62, 70, 108, 44, { color = WOOD })

	-- Hoch: Gurt duenn und gruen
	line(box, 148, 18, 240, 18, { color = GOOD, thickness = 3 })
	line(box, 148, 70, 240, 70, { color = ROAD, thickness = 4 })
	line(box, 148, 18, 148, 70, { color = WOOD })
	line(box, 194, 18, 194, 70, { color = WOOD })
	line(box, 240, 18, 240, 70, { color = WOOD })
	line(box, 148, 70, 194, 18, { color = WOOD })
	line(box, 194, 70, 240, 18, { color = WOOD })
end

--[[
	Bild 5: wann ein Seil etwas bringt und wann nicht.

	Oben zieht ein Seil eine Last nach oben - es steht unter Zug und traegt.
	Unten soll es eine Last stuetzen, muesste dafuer druecken, und haengt
	deshalb einfach durch. Rechts der Fall, um den es im Spiel geht: der
	Untergurt eines Fachwerks steht unter Zug, also darf dort ein Kabel neben
	die Fahrbahn - zum halben Preis von Stahl.
]]
local CABLE = Color3.fromRGB(150, 160, 174)

local function drawCables(box: Frame)
	-- Oben: Seil zieht - haelt
	dot(box, 40, 14, Color3.fromRGB(228, 168, 72))
	line(box, 40, 14, 40, 44, { color = CABLE, thickness = 3 })
	local load = Instance.new("Frame")
	load.Size = UDim2.fromOffset(22, 12)
	load.AnchorPoint = Vector2.new(0.5, 0)
	load.Position = UDim2.fromOffset(40, 44)
	load.BackgroundColor3 = GOOD
	load.BorderSizePixel = 0
	load.ZIndex = 3
	load.Parent = box
	Theme.corner(load, 3)

	-- Unten: Seil muesste druecken - haengt durch
	dot(box, 100, 76, Color3.fromRGB(228, 168, 72))
	line(box, 100, 76, 108, 62, { color = BAD, thickness = 3, transparency = 0.35 })
	line(box, 108, 62, 116, 66, { color = BAD, thickness = 3, transparency = 0.35 })
	line(box, 116, 66, 124, 50, { color = BAD, thickness = 3, transparency = 0.35 })
	local weight = Instance.new("Frame")
	weight.Size = UDim2.fromOffset(22, 12)
	weight.Position = UDim2.fromOffset(114, 38)
	weight.BackgroundColor3 = BAD
	weight.BorderSizePixel = 0
	weight.ZIndex = 3
	weight.Parent = box
	Theme.corner(weight, 3)

	-- Rechts: Untergurt unter Zug - hier gehoert ein Kabel hin
	line(box, 160, 26, 240, 26, { color = STEEL })
	line(box, 160, 70, 240, 70, { color = ROAD, thickness = 5 })
	line(box, 160, 78, 240, 78, { color = CABLE, thickness = 4 })
	line(box, 160, 26, 160, 70, { color = WOOD })
	line(box, 200, 26, 200, 70, { color = WOOD })
	line(box, 240, 26, 240, 70, { color = WOOD })
	line(box, 160, 70, 200, 26, { color = WOOD })
	line(box, 200, 70, 240, 26, { color = WOOD })
	dot(box, 160, 74, Color3.fromRGB(228, 168, 72), 7)
	dot(box, 240, 74, Color3.fromRGB(228, 168, 72), 7)
end

local CARDS = {
	{ key = "school.triangles", draw = drawTriangles },
	{ key = "school.truss", draw = drawTruss },
	{ key = "school.doubling", draw = drawDoubling },
	{ key = "school.depth", draw = drawDepth },
	{ key = "school.cables", draw = drawCables },
}

--------------------------------------------------------------------------------
-- Das Fenster
--------------------------------------------------------------------------------

function BuildingSchool.new()
	local self = setmetatable({}, BuildingSchool)

	self.player = Players.LocalPlayer
	self.onClosed = nil

	self:build()

	Device.changed(function()
		self:applyScale()
	end)

	return self
end

function BuildingSchool:build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BridgeLabSchool"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	--[[
		Ueber allem anderen: die Bauschule ist ein Fenster, das man bewusst
		oeffnet, und solange es offen ist, soll nichts dahinter anklickbar
		sein.
	]]
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = self.player:WaitForChild("PlayerGui")
	self.gui = gui

	-- Abdunkelnder Hintergrund, der auch Klicks abfaengt.
	local shade = Instance.new("TextButton")
	shade.Name = "Hintergrund"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.AutoButtonColor = false
	shade.Text = ""
	shade.Parent = gui
	shade.Activated:Connect(function()
		self:hide()
	end)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	self.root = root

	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.scale = scale

	local panel = Theme.panel(root, "Panel")
	panel.Size = UDim2.fromOffset(600, 560)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	self.panel = panel

	Theme.label(panel, "Title", {
		size = UDim2.new(1, -40, 0, 30),
		position = UDim2.fromOffset(24, 18),
		text = I18n.t("school.title"),
		textSize = 22,
		bold = true,
	})

	Theme.label(panel, "Intro", {
		size = UDim2.new(1, -40, 0, 20),
		position = UDim2.fromOffset(24, 46),
		text = I18n.t("school.intro"),
		textSize = 13,
		color = Theme.colors.textDim,
	})

	----------------------------------------------------------------------------
	-- Die vier Karten untereinander
	----------------------------------------------------------------------------

	local list = Instance.new("ScrollingFrame")
	list.Name = "Karten"
	list.Size = UDim2.new(1, -32, 1, -132)
	list.Position = UDim2.fromOffset(16, 76)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.colors.border
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = list

	for order, card in CARDS do
		local frame = Instance.new("Frame")
		frame.Name = "Karte" .. order
		frame.Size = UDim2.new(1, -12, 0, 148)
		frame.BackgroundColor3 = Theme.colors.panelLight
		frame.BorderSizePixel = 0
		frame.LayoutOrder = order
		frame.Parent = list
		Theme.corner(frame, 10)

		--[[
			Die Zeichenflaeche ist bewusst FEST 256 mal 100 Pixel gross. Alle
			Bildkoordinaten oben sind darauf abgestimmt; waere sie
			mitwachsend, muesste jede einzelne Linie umgerechnet werden.
			Groesser wird das Bild ueber den UIScale des ganzen Fensters.
		]]
		local canvas = Instance.new("Frame")
		canvas.Name = "Bild"
		canvas.Size = UDim2.fromOffset(256, 100)
		canvas.Position = UDim2.fromOffset(16, 14)
		canvas.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
		canvas.BorderSizePixel = 0
		canvas.ClipsDescendants = true
		canvas.Parent = frame
		Theme.corner(canvas, 8)

		card.draw(canvas)

		Theme.label(frame, "Titel", {
			size = UDim2.new(1, -300, 0, 22),
			position = UDim2.fromOffset(288, 22),
			text = I18n.t(card.key .. ".title"),
			textSize = 16,
			bold = true,
		})

		Theme.label(frame, "Text", {
			size = UDim2.new(1, -300, 0, 90),
			position = UDim2.fromOffset(288, 46),
			text = I18n.t(card.key .. ".text"),
			textSize = 13,
			color = Theme.colors.textDim,
			wrapped = true,
			alignY = Enum.TextYAlignment.Top,
		})
	end

	----------------------------------------------------------------------------
	-- Schliessen
	----------------------------------------------------------------------------

	local closeButton = Theme.button(panel, "CloseButton", {
		size = UDim2.fromOffset(160, 40),
		position = UDim2.new(0.5, -80, 1, -52),
		text = I18n.t("common.close"),
		textSize = 15,
		color = Theme.colors.accent,
		textColor = Color3.fromRGB(10, 20, 34),
	})
	closeButton.Selectable = true
	closeButton.Activated:Connect(function()
		self:hide()
	end)

	self:applyScale()
end

--[[
	Auf kleinen Bildschirmen wird das Fenster mitverkleinert, damit es
	vollstaendig hineinpasst. Ein Fenster, dessen Schliessen-Knopf unter dem
	Bildrand liegt, laesst sich sonst gar nicht mehr zumachen.
]]
function BuildingSchool:applyScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	local fit = math.min(viewport.X / 640, viewport.Y / 600, 1)
	local factor = math.max(fit, 0.55) * Device.uiScale()
	self.scale.Scale = factor

	--[[
		Die Wurzel wird gegengerechnet, damit sie nach dem Skalieren wieder
		den ganzen Bildschirm fuellt. Sonst laege das mittig gesetzte Fenster
		nicht in der Bildschirmmitte, sondern in der Mitte einer geschrumpften
		Flaeche - also deutlich links oben.
	]]
	self.root.Size = UDim2.fromScale(1 / factor, 1 / factor)
end

function BuildingSchool:show()
	self:applyScale()
	self.gui.Enabled = true
end

function BuildingSchool:hide()
	self.gui.Enabled = false
	if self.onClosed then
		self.onClosed()
	end
end

function BuildingSchool:isOpen(): boolean
	return self.gui.Enabled
end

return BuildingSchool
