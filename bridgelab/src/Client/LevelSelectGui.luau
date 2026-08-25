--[[
	LevelSelectGui
	--------------
	Das Startmenue: hier waehlt der Spieler sein Level.

	Jede Levelkarte zeigt
	  - Nummer und Namen
	  - den Schwierigkeitsgrad als Punkte und als Wort
	  - Budget und Breite der Luecke
	  - ob das Level schon geschafft wurde
	  - wie viele Tipps es gibt und ob der erste davon gratis ist

	Die Liste passt sich dem Geraet an: auf einem Handy sind die Karten
	groesser und untereinander, auf einem breiten Bildschirm stehen zwei
	nebeneinander.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)

local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)

local LevelSelectGui = {}
LevelSelectGui.__index = LevelSelectGui

function LevelSelectGui.new()
	local self = setmetatable({}, LevelSelectGui)

	self.player = Players.LocalPlayer
	self.profile = nil
	self.cards = {}

	-- Rueckmeldungen nach aussen
	self.onLevelChosen = nil
	self.onTutorialRequested = nil

	self:build()

	-- Bei Geraetewechsel die Groessen neu setzen.
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

	-- Dunkler Hintergrund ueber der ganzen Flaeche
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.colors.background
	backdrop.BackgroundTransparency = 0.08
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Parent = backdrop
	self.scale = scale

	----------------------------------------------------------------------------
	-- Kopfzeile
	----------------------------------------------------------------------------

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 96)
	header.BackgroundTransparency = 1
	header.Parent = backdrop

	Theme.label(header, "Title", {
		size = UDim2.new(1, -48, 0, 42),
		position = UDim2.fromOffset(28, 20),
		text = "BridgeLab",
		textSize = 34,
		bold = true,
	})

	Theme.label(header, "Subtitle", {
		size = UDim2.new(1, -48, 0, 22),
		position = UDim2.fromOffset(28, 60),
		text = "Baue eine Bruecke, die haelt. Waehle ein Level.",
		textSize = 15,
		color = Theme.colors.textDim,
	})

	-- Anzeige der Tipp-Gutscheine
	self.creditLabel = Theme.label(header, "Credits", {
		size = UDim2.fromOffset(260, 22),
		position = UDim2.new(1, -288, 0, 26),
		text = "",
		textSize = 14,
		color = Theme.colors.robux,
		align = Enum.TextXAlignment.Right,
	})

	-- Knopf: Anleitung noch einmal ansehen
	local tutorialButton = Theme.button(header, "TutorialButton", {
		size = UDim2.fromOffset(190, 36),
		position = UDim2.new(1, -218, 0, 52),
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
	list.Size = UDim2.new(1, -56, 1, -128)
	list.Position = UDim2.fromOffset(28, 104)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.colors.border
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = backdrop
	self.list = list

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 420, 0, 132)
	grid.CellPadding = UDim2.fromOffset(16, 16)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = list
	self.grid = grid

	----------------------------------------------------------------------------
	-- Levelkarten anlegen
	----------------------------------------------------------------------------

	for _, summary in Levels.summaries() do
		self:createCard(summary)
	end

	self:applyScale()
end

--------------------------------------------------------------------------------
-- Eine Levelkarte
--------------------------------------------------------------------------------

function LevelSelectGui:createCard(summary)
	local card = Instance.new("TextButton")
	card.Name = "Level_" .. summary.id
	card.LayoutOrder = summary.order
	card.BackgroundColor3 = Theme.colors.panel
	card.BorderSizePixel = 0
	card.AutoButtonColor = true
	card.Text = ""
	card.Selectable = true
	card.Parent = self.list
	Theme.corner(card, 10)
	Theme.stroke(card)

	-- Nummer links in einem farbigen Feld
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(58, 58)
	badge.Position = UDim2.fromOffset(16, 16)
	badge.BackgroundColor3 = Theme.colors.panelLight
	badge.BorderSizePixel = 0
	badge.Parent = card
	Theme.corner(badge, 8)

	Theme.label(badge, "Number", {
		size = UDim2.fromScale(1, 1),
		text = tostring(summary.order),
		textSize = 26,
		bold = true,
		align = Enum.TextXAlignment.Center,
	})

	-- Name
	Theme.label(card, "Name", {
		size = UDim2.new(1, -180, 0, 24),
		position = UDim2.fromOffset(86, 16),
		text = summary.displayName,
		textSize = 19,
		bold = true,
	})

	-- Untertitel
	Theme.label(card, "Subtitle", {
		size = UDim2.new(1, -180, 0, 20),
		position = UDim2.fromOffset(86, 38),
		text = summary.subtitle,
		textSize = 13,
		color = Theme.colors.textDim,
		wrapped = true,
	})

	-- Schwierigkeit
	local info = Config.difficultyInfo(summary.difficulty)
	Theme.label(card, "Difficulty", {
		size = UDim2.new(1, -180, 0, 20),
		position = UDim2.fromOffset(86, 64),
		text = string.format("%s  %s", Theme.stars(summary.difficulty, 5), info.label),
		textSize = 14,
		bold = true,
		color = info.color,
	})

	-- Eckdaten
	Theme.label(card, "Facts", {
		size = UDim2.new(1, -180, 0, 18),
		position = UDim2.fromOffset(86, 86),
		text = string.format("Budget %d  ·  Luecke %d Studs", summary.budget, summary.gapWidth),
		textSize = 13,
		color = Theme.colors.textDim,
	})

	-- Tipp-Hinweis
	local hintText
	if summary.freeHints > 0 then
		hintText = string.format("%d Tipps · erster gratis", summary.hintCount)
	else
		hintText = string.format("%d Tipps · kostenpflichtig", summary.hintCount)
	end
	Theme.label(card, "Hints", {
		size = UDim2.new(1, -180, 0, 16),
		position = UDim2.fromOffset(86, 104),
		text = hintText,
		textSize = 12,
		color = if summary.freeHints > 0 then Theme.colors.textDim else Theme.colors.robux,
	})

	-- Haken oben rechts, wenn geschafft
	local done = Theme.label(card, "Done", {
		size = UDim2.fromOffset(120, 24),
		position = UDim2.new(1, -134, 0, 16),
		text = "✓ geschafft",
		textSize = 14,
		bold = true,
		color = Theme.colors.success,
		align = Enum.TextXAlignment.Right,
	})
	done.Visible = false

	card.Activated:Connect(function()
		if self.onLevelChosen then
			self.onLevelChosen(summary.id)
		end
	end)

	self.cards[summary.id] = { card = card, done = done, badge = badge }
end

--------------------------------------------------------------------------------
-- Anzeige aktualisieren
--------------------------------------------------------------------------------

function LevelSelectGui:setProfile(profile)
	self.profile = profile

	for levelId, entry in self.cards do
		local completed = profile and profile.completed and profile.completed[levelId] == true
		entry.done.Visible = completed
		entry.badge.BackgroundColor3 = if completed then Theme.colors.success else Theme.colors.panelLight
	end

	local credits = if profile then profile.hintCredits or 0 else 0
	if credits > 0 then
		self.creditLabel.Text = string.format("Tipp-Gutscheine: %d", credits)
	else
		self.creditLabel.Text = ""
	end
end

--------------------------------------------------------------------------------
-- Groessen an das Geraet anpassen
--------------------------------------------------------------------------------

function LevelSelectGui:applyScale()
	self.scale.Scale = Device.uiScale()

	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280

	-- Auf schmalen Bildschirmen eine Karte pro Zeile, sonst zwei.
	local effectiveWidth = width / math.max(self.scale.Scale, 0.1)
	if effectiveWidth < 900 then
		self.grid.CellSize = UDim2.new(1, -12, 0, 140)
	else
		self.grid.CellSize = UDim2.new(0.5, -20, 0, 132)
	end

	local inset = Device.edgeInset()
	self.list.Position = UDim2.fromOffset(inset + 12, 104)
	self.list.Size = UDim2.new(1, -(inset + 12) * 2, 1, -128)
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
