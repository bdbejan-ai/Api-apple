--[[
	LevelSelectGui
	--------------
	Das Startmenue: hier waehlt der Spieler sein Level.

	Jede Levelkarte zeigt
	  - eine kleine Vorschau des Gelaendes (Plattformen, Luecke, Fahrbahnen)
	  - Nummer und Namen
	  - den Schwierigkeitsgrad als Balken und als Wort
	  - Budget, Breite der Luecke und Zahl der Fahrzeuge
	  - Besonderheiten wie Gegenverkehr oder zwei Ebenen
	  - ob das Level schon geschafft wurde

	Die Liste passt sich dem Geraet an: auf einem Handy sind die Karten
	groesser und untereinander, auf einem breiten Bildschirm stehen zwei
	nebeneinander.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)

local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)

local LevelSelectGui = {}
LevelSelectGui.__index = LevelSelectGui

local CARD_HEIGHT = 152

function LevelSelectGui.new()
	local self = setmetatable({}, LevelSelectGui)

	self.player = Players.LocalPlayer
	self.profile = nil
	self.cards = {}

	-- Rueckmeldungen nach aussen
	self.onLevelChosen = nil
	self.onTutorialRequested = nil

	self:build()

	Device.changed(function()
		self:applyScale()
	end)

	return self
end

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

function LevelSelectGui:build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BridgeLabLevelSelect"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = self.player:WaitForChild("PlayerGui")
	self.gui = gui

	-- Hintergrund mit weichem Farbverlauf statt einer flachen Flaeche.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.colors.background
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local backdropGradient = Instance.new("UIGradient")
	backdropGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 38, 58)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 24, 34)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 16, 22)),
	})
	backdropGradient.Rotation = 70
	backdropGradient.Parent = backdrop

	local scale = Instance.new("UIScale")
	scale.Parent = backdrop
	self.scale = scale

	----------------------------------------------------------------------------
	-- Kopfzeile
	----------------------------------------------------------------------------

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 112)
	header.BackgroundTransparency = 1
	header.Parent = backdrop
	self.header = header

	local title = Theme.label(header, "Title", {
		size = UDim2.new(1, -48, 0, 46),
		position = UDim2.fromOffset(28, 22),
		text = "BridgeLab",
		textSize = 38,
		bold = true,
	})

	-- Der Titel bekommt einen Farbverlauf - das hebt ihn vom Rest ab.
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(96, 140, 240)),
	})
	titleGradient.Rotation = 20
	titleGradient.Parent = title

	Theme.label(header, "Subtitle", {
		size = UDim2.new(1, -48, 0, 22),
		position = UDim2.fromOffset(30, 66),
		text = "Baue eine Bruecke, die haelt. Waehle ein Level.",
		textSize = 15,
		color = Theme.colors.textDim,
	})

	-- Anzeige der Tipp-Gutscheine
	self.creditChip = Theme.panel(header, "Credits")
	self.creditChip.Size = UDim2.fromOffset(210, 32)
	self.creditChip.Position = UDim2.new(1, -238, 0, 24)
	self.creditChip.BackgroundColor3 = Theme.colors.panelLight
	self.creditChip.Visible = false

	self.creditLabel = Theme.label(self.creditChip, "Text", {
		size = UDim2.new(1, -20, 1, 0),
		position = UDim2.fromOffset(10, 0),
		text = "",
		textSize = 14,
		bold = true,
		color = Theme.colors.robux,
		align = Enum.TextXAlignment.Center,
	})

	-- Knopf: Anleitung noch einmal ansehen
	local tutorialButton = Theme.button(header, "TutorialButton", {
		size = UDim2.fromOffset(210, 38),
		position = UDim2.new(1, -238, 0, 62),
		text = "Anleitung ansehen",
		textSize = 14,
		color = Theme.colors.panelLight,
	})
	tutorialButton.Selectable = true
	tutorialButton.Activated:Connect(function()
		if self.onTutorialRequested then
			self.onTutorialRequested()
		end
	end)
	self.tutorialButton = tutorialButton

	----------------------------------------------------------------------------
	-- Scrollende Levelliste
	----------------------------------------------------------------------------

	local list = Instance.new("ScrollingFrame")
	list.Name = "LevelList"
	list.Size = UDim2.new(1, -56, 1, -136)
	list.Position = UDim2.fromOffset(28, 118)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.colors.border
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = backdrop
	self.list = list

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -20, 0, CARD_HEIGHT)
	grid.CellPadding = UDim2.fromOffset(16, 16)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = list
	self.grid = grid

	for _, summary in Levels.summaries() do
		self:createCard(summary)
	end

	self:applyScale()
end

--------------------------------------------------------------------------------
-- Kleine Gelaendevorschau auf der Karte
--------------------------------------------------------------------------------

--[[
	Zeichnet das Level schematisch: zwei Plattformen, dazwischen die Luecke,
	darin Wasser, darueber eine oder zwei Fahrbahnlinien. Aus einem Blick ist
	damit klar, worum es geht - ohne dass man die Zahlen lesen muss.

	Alles sind einfache Frames. Das reicht voellig und braucht keine Bilder.
]]
local function createPreview(parent: Instance, summary): Frame
	local box = Instance.new("Frame")
	box.Name = "Preview"
	box.Size = UDim2.fromOffset(116, 78)
	box.Position = UDim2.fromOffset(14, 14)
	box.BackgroundColor3 = Color3.fromRGB(24, 32, 46)
	box.BorderSizePixel = 0
	box.ClipsDescendants = true
	box.Parent = parent
	Theme.corner(box, 8)

	-- Himmel
	local sky = Instance.new("UIGradient")
	sky.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 84, 122)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 36, 50)),
	})
	sky.Rotation = 90
	sky.Parent = box

	-- Wie breit ist die Luecke im Verhaeltnis? Von 40 bis 80 Studs.
	local gapFraction = math.clamp(summary.gapWidth / 110, 0.24, 0.62)
	local sideWidth = (1 - gapFraction) / 2

	-- Wasser im Graben
	local water = Instance.new("Frame")
	water.Name = "Water"
	water.Size = UDim2.new(gapFraction, 0, 0, 10)
	water.Position = UDim2.new(sideWidth, 0, 1, -12)
	water.BackgroundColor3 = Color3.fromRGB(56, 116, 152)
	water.BorderSizePixel = 0
	water.Parent = box

	-- Plattformen links und rechts
	for _, side in { 0, 1 } do
		local platform = Instance.new("Frame")
		platform.Name = "Platform"
		platform.Size = UDim2.new(sideWidth, 0, 0, 40)
		platform.Position = UDim2.new(if side == 0 then 0 else 1 - sideWidth, 0, 1, -40)
		platform.BackgroundColor3 = Color3.fromRGB(88, 92, 84)
		platform.BorderSizePixel = 0
		platform.Parent = box

		local grass = Instance.new("Frame")
		grass.Name = "Grass"
		grass.Size = UDim2.new(1, 0, 0, 5)
		grass.BackgroundColor3 = Color3.fromRGB(104, 138, 84)
		grass.BorderSizePixel = 0
		grass.Parent = platform
	end

	-- Fahrbahnen: die unterste liegt auf Plattformhoehe, jede weitere darueber.
	for index = 1, summary.deckCount do
		local deck = Instance.new("Frame")
		deck.Name = "Deck" .. index
		deck.Size = UDim2.new(1, -8, 0, 3)
		deck.Position = UDim2.new(0, 4, 1, -42 - (index - 1) * 18)
		deck.BackgroundColor3 = Color3.fromRGB(206, 210, 220)
		deck.BorderSizePixel = 0
		deck.Parent = box

		-- Ein Fahrzeug als kleiner Klotz auf der Fahrbahn
		local car = Instance.new("Frame")
		car.Name = "Car"
		car.Size = UDim2.fromOffset(11, 6)
		car.Position = UDim2.new(if index % 2 == 1 then 0.16 else 0.62, 0, 1, -48 - (index - 1) * 18)
		car.BackgroundColor3 = if index == 1
			then Color3.fromRGB(198, 72, 58)
			else Color3.fromRGB(232, 172, 62)
		car.BorderSizePixel = 0
		car.Parent = box
		Theme.corner(car, 2)
	end

	-- Bei Gegenverkehr faehrt ein zweites Fahrzeug von rechts.
	if summary.vehicleCount > 1 and summary.deckCount == 1 then
		local car = Instance.new("Frame")
		car.Name = "CarOncoming"
		car.Size = UDim2.fromOffset(11, 6)
		car.Position = UDim2.new(0.66, 0, 1, -48)
		car.BackgroundColor3 = Color3.fromRGB(64, 118, 206)
		car.BorderSizePixel = 0
		car.Parent = box
		Theme.corner(car, 2)
	end

	return box
end

--------------------------------------------------------------------------------
-- Eine Levelkarte
--------------------------------------------------------------------------------

-- Kleines beschriftetes Feld fuer Budget, Luecke und Besonderheiten.
local function chip(parent: Instance, name: string, text: string, x: number, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(0, 22)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Position = UDim2.new(0, x, 1, -32)
	frame.BackgroundColor3 = Theme.colors.panelLight
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 6)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = frame

	local label = Theme.label(frame, "Text", {
		size = UDim2.fromOffset(0, 22),
		text = text,
		textSize = 12,
		bold = true,
		color = color,
	})
	label.AutomaticSize = Enum.AutomaticSize.X

	return frame
end

function LevelSelectGui:createCard(summary)
	local card = Instance.new("TextButton")
	card.Name = "Level_" .. summary.id
	card.LayoutOrder = summary.order
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.Selectable = true
	card.Parent = self.list
	Theme.corner(card, 12)

	local stroke = Theme.stroke(card)

	createPreview(card, summary)

	-- Nummer, klein ueber dem Namen
	Theme.label(card, "Number", {
		size = UDim2.new(1, -160, 0, 14),
		position = UDim2.fromOffset(142, 16),
		text = string.format("LEVEL %d", summary.order),
		textSize = 11,
		bold = true,
		color = Theme.colors.accent,
	})

	Theme.label(card, "Name", {
		size = UDim2.new(1, -160, 0, 26),
		position = UDim2.fromOffset(142, 30),
		text = summary.displayName,
		textSize = 20,
		bold = true,
	})

	Theme.label(card, "Subtitle", {
		size = UDim2.new(1, -166, 0, 32),
		position = UDim2.fromOffset(142, 55),
		text = summary.subtitle,
		textSize = 12,
		color = Theme.colors.textDim,
		wrapped = true,
		alignY = Enum.TextYAlignment.Top,
	})

	----------------------------------------------------------------------------
	-- Schwierigkeit als fuenf Segmente
	----------------------------------------------------------------------------

	local info = Config.difficultyInfo(summary.difficulty)

	for step = 1, 5 do
		local segment = Instance.new("Frame")
		segment.Name = "Diff" .. step
		segment.Size = UDim2.fromOffset(14, 5)
		segment.Position = UDim2.new(1, -100 + (step - 1) * 17, 0, 20)
		segment.BackgroundColor3 = if step <= summary.difficulty
			then info.color
			else Theme.colors.panelLight
		segment.BorderSizePixel = 0
		segment.Parent = card
		Theme.corner(segment, 2)
	end

	Theme.label(card, "DifficultyText", {
		size = UDim2.fromOffset(120, 16),
		position = UDim2.new(1, -134, 0, 28),
		text = info.label,
		textSize = 11,
		bold = true,
		color = info.color,
		align = Enum.TextXAlignment.Right,
	})

	----------------------------------------------------------------------------
	-- Eckdaten als Felder unten
	----------------------------------------------------------------------------

	local x = 142
	chip(card, "Budget", string.format("Budget %d", summary.budget), x, Theme.colors.text)
	x += 92
	chip(card, "Gap", string.format("%d Studs", summary.gapWidth), x, Theme.colors.text)
	x += 78

	-- Besonderheiten deutlich hervorheben
	if summary.deckCount > 1 then
		chip(card, "Decks", "2 Ebenen", x, Theme.colors.warning)
		x += 76
	elseif summary.vehicleCount > 1 then
		chip(card, "Traffic", "Gegenverkehr", x, Theme.colors.warning)
		x += 100
	end

	if summary.freeHints > 0 then
		chip(card, "Hints", "1 Tipp gratis", x, Theme.colors.textDim)
	else
		chip(card, "Hints", "Tipps kostenpflichtig", x, Theme.colors.robux)
	end

	----------------------------------------------------------------------------
	-- Haken oben rechts, wenn geschafft
	----------------------------------------------------------------------------

	local done = Theme.label(card, "Done", {
		size = UDim2.fromOffset(130, 20),
		position = UDim2.new(1, -144, 1, -32),
		text = "✓ geschafft",
		textSize = 13,
		bold = true,
		color = Theme.colors.success,
		align = Enum.TextXAlignment.Right,
	})
	done.Visible = false

	----------------------------------------------------------------------------
	-- Verhalten
	----------------------------------------------------------------------------

	-- Sanfte Hervorhebung, wenn der Zeiger auf der Karte liegt.
	local function highlight(active: boolean)
		TweenService:Create(card, TweenInfo.new(0.15), {
			BackgroundColor3 = if active then Theme.colors.panelLight else Theme.colors.panel,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.15), {
			Color = if active then Theme.colors.accent else Theme.colors.border,
		}):Play()
	end

	card.MouseEnter:Connect(function()
		highlight(true)
	end)
	card.MouseLeave:Connect(function()
		highlight(false)
	end)
	-- Beim Gamepad zaehlt die Auswahl statt des Zeigers.
	card.SelectionGained:Connect(function()
		highlight(true)
	end)
	card.SelectionLost:Connect(function()
		highlight(false)
	end)

	card.Activated:Connect(function()
		if self.onLevelChosen then
			self.onLevelChosen(summary.id)
		end
	end)

	self.cards[summary.id] = { card = card, done = done, stroke = stroke }
end

--------------------------------------------------------------------------------
-- Anzeige aktualisieren
--------------------------------------------------------------------------------

function LevelSelectGui:setProfile(profile)
	self.profile = profile

	for levelId, entry in self.cards do
		local completed = profile and profile.completed and profile.completed[levelId] == true
		entry.done.Visible = completed
	end

	local credits = if profile then profile.hintCredits or 0 else 0
	self.creditChip.Visible = credits > 0
	self.creditLabel.Text = string.format("%d Tipp-Gutschein%s", credits, if credits == 1 then "" else "e")
end

--------------------------------------------------------------------------------
-- Groessen an das Geraet anpassen
--------------------------------------------------------------------------------

function LevelSelectGui:applyScale()
	self.scale.Scale = Device.uiScale()

	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	local effectiveWidth = width / math.max(self.scale.Scale, 0.1)

	-- Auf schmalen Bildschirmen eine Karte pro Zeile, sonst zwei.
	if effectiveWidth < 1000 then
		self.grid.CellSize = UDim2.new(1, -12, 0, CARD_HEIGHT)
	else
		self.grid.CellSize = UDim2.new(0.5, -20, 0, CARD_HEIGHT)
	end

	local inset = Device.edgeInset()
	self.list.Position = UDim2.fromOffset(inset + 12, 118)
	self.list.Size = UDim2.new(1, -(inset + 12) * 2, 1, -136)
end

--------------------------------------------------------------------------------
-- Ein- und ausblenden
--------------------------------------------------------------------------------

function LevelSelectGui:show()
	self:applyScale()
	self.gui.Enabled = true

	-- Beim Gamepad muss ein Element ausgewaehlt sein, sonst laesst sich
	-- nichts bedienen.
	if Device.isGamepad() then
		local first = self.cards[Levels.list[1].id]
		if first then
			GuiService.SelectedObject = first.card
		end
	end
end

function LevelSelectGui:hide()
	self.gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject = nil
	end
end

function LevelSelectGui:isVisible(): boolean
	return self.gui.Enabled
end

return LevelSelectGui
