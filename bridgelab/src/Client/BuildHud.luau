--[[
	BuildHud
	--------
	Die Oberflaeche waehrend des Spiels. Sie besteht aus fuenf Teilen:

	  1. Kopfzeile    Levelname, Budget, Knoepfe (Menue, Zuruecksetzen)
	  2. Fussleiste   Bauteilauswahl, Abriss, Test starten
	  3. Statuszeile  Warnungen ("Struktur nicht stabil")
	  4. Testanzeige  Countdown, Zeit, hoechste Auslastung, Farblegende
	  5. Ergebnis     Erfolg oder Misserfolg mit Begruendung

	Dazu kommt das Tipp-Fenster, das sich rechts einblenden laesst.

	Alle Groessen haengen an einem UIScale, den Device.uiScale() liefert.
	Dadurch ist die Bedienung auf dem Handy automatisch groesser als am PC.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)

local BuildHud = {}
BuildHud.__index = BuildHud

function BuildHud.new()
	local self = setmetatable({}, BuildHud)

	self.player = Players.LocalPlayer
	self.partButtons = {}
	self.selected = "Beam"
	self.state = nil
	self.hintOpen = false
	self.noticeToken = 0

	-- Rueckmeldungen nach aussen
	self.onSelectPart = nil
	self.onRemoveMode = nil
	self.onTest = nil
	self.onReset = nil
	self.onClear = nil
	self.onMenu = nil
	self.onHint = nil
	self.onRetry = nil

	self:build()

	Device.changed(function()
		self:applyScale()
	end)

	return self
end

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

function BuildHud:build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BridgeLabHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = self.player:WaitForChild("PlayerGui")
	self.gui = gui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	self.root = root

	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.scale = scale

	self:buildTopBar()
	self:buildBottomBar()
	self:buildStatus()
	self:buildTestPanel()
	self:buildHintPanel()
	self:buildResultPanel()

	self:applyScale()
end

--------------------------------------------------------------------------------
-- 1. Kopfzeile
--------------------------------------------------------------------------------

function BuildHud:buildTopBar()
	local bar = Theme.panel(self.root, "TopBar")
	bar.Size = UDim2.new(1, -24, 0, 58)
	bar.Position = UDim2.fromOffset(12, 10)
	bar.BackgroundTransparency = 0.08
	self.topBar = bar

	-- Levelname
	self.levelLabel = Theme.label(bar, "LevelName", {
		size = UDim2.fromOffset(320, 22),
		position = UDim2.fromOffset(16, 8),
		text = "Level",
		textSize = 17,
		bold = true,
	})

	self.difficultyLabel = Theme.label(bar, "Difficulty", {
		size = UDim2.fromOffset(320, 18),
		position = UDim2.fromOffset(16, 30),
		text = "",
		textSize = 13,
		color = Theme.colors.textDim,
	})

	----------------------------------------------------------------------------
	-- Budgetanzeige in der Mitte
	----------------------------------------------------------------------------

	local budgetBox = Instance.new("Frame")
	budgetBox.Name = "Budget"
	budgetBox.Size = UDim2.fromOffset(230, 40)
	budgetBox.Position = UDim2.new(0.5, -115, 0, 9)
	budgetBox.BackgroundTransparency = 1
	budgetBox.Parent = bar

	self.budgetLabel = Theme.label(budgetBox, "Text", {
		size = UDim2.new(1, 0, 0, 20),
		text = "Budget 0 / 0",
		textSize = 15,
		bold = true,
		align = Enum.TextXAlignment.Center,
	})

	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, 0, 0, 8)
	barBg.Position = UDim2.fromOffset(0, 24)
	barBg.BackgroundColor3 = Theme.colors.panelLight
	barBg.BorderSizePixel = 0
	barBg.Parent = budgetBox
	Theme.corner(barBg, 4)

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Theme.colors.accent
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	Theme.corner(barFill, 4)
	self.budgetFill = barFill

	----------------------------------------------------------------------------
	-- Knoepfe rechts
	----------------------------------------------------------------------------

	local function topButton(name: string, text: string, offsetFromRight: number, width: number, color: Color3?)
		local button = Theme.button(bar, name, {
			size = UDim2.fromOffset(width, 34),
			position = UDim2.new(1, -offsetFromRight, 0, 12),
			text = text,
			textSize = 13,
			color = color or Theme.colors.panelLight,
		})
		button.Selectable = true
		return button
	end

	self.menuButton = topButton("MenuButton", "Menue", 86, 74)
	self.resetButton = topButton("ResetButton", "Zuruecksetzen", 208, 116)
	self.clearButton = topButton("ClearButton", "Abreissen", 302, 88)

	self.menuButton.Activated:Connect(function()
		if self.onMenu then
			self.onMenu()
		end
	end)
	self.resetButton.Activated:Connect(function()
		if self.onReset then
			self.onReset()
		end
	end)
	self.clearButton.Activated:Connect(function()
		if self.onClear then
			self.onClear()
		end
	end)
end

--------------------------------------------------------------------------------
-- 2. Fussleiste mit der Bauteilauswahl
--------------------------------------------------------------------------------

function BuildHud:buildBottomBar()
	local bar = Theme.panel(self.root, "BottomBar")
	bar.Size = UDim2.new(1, -24, 0, 92)
	bar.Position = UDim2.new(0, 12, 1, -102)
	bar.BackgroundTransparency = 0.08
	self.bottomBar = bar

	local x = 14

	-- Ein Knopf je Bauteiltyp
	for _, key in Config.PartOrder do
		local spec = Config.PartTypes[key]

		local button = Theme.button(bar, "Part_" .. key, {
			size = UDim2.fromOffset(132, 64),
			position = UDim2.fromOffset(x, 14),
			text = "",
			color = Theme.colors.panelLight,
		})
		button.Selectable = true

		Theme.label(button, "Icon", {
			size = UDim2.fromOffset(30, 30),
			position = UDim2.fromOffset(10, 8),
			text = spec.icon,
			textSize = 22,
			bold = true,
			color = spec.uiColor,
			align = Enum.TextXAlignment.Center,
		})

		Theme.label(button, "Name", {
			size = UDim2.fromOffset(88, 20),
			position = UDim2.fromOffset(42, 9),
			text = spec.displayName,
			textSize = 15,
			bold = true,
		})

		Theme.label(button, "Cost", {
			size = UDim2.fromOffset(88, 16),
			position = UDim2.fromOffset(42, 28),
			text = string.format("Kosten %d", spec.cost),
			textSize = 12,
			color = Theme.colors.textDim,
		})

		Theme.label(button, "Limits", {
			size = UDim2.fromOffset(112, 14),
			position = UDim2.fromOffset(12, 46),
			text = if spec.maxCompression > 0
				then string.format("Zug %d N · Druck %d N", spec.maxTension, spec.maxCompression)
				else string.format("Zug %d N · kein Druck", spec.maxTension),
			textSize = 10,
			color = Theme.colors.textDim,
		})

		button.Activated:Connect(function()
			if self.onSelectPart then
				self.onSelectPart(key)
			end
		end)

		self.partButtons[key] = button
		x += 140
	end

	-- Abrissmodus
	local removeButton = Theme.button(bar, "RemoveButton", {
		size = UDim2.fromOffset(108, 64),
		position = UDim2.fromOffset(x, 14),
		text = "Abriss",
		textSize = 15,
		color = Theme.colors.panelLight,
	})
	removeButton.Selectable = true
	removeButton.Activated:Connect(function()
		if self.onRemoveMode then
			self.onRemoveMode()
		end
	end)
	self.removeButton = removeButton

	-- Tipp-Knopf
	local hintButton = Theme.button(bar, "HintButton", {
		size = UDim2.fromOffset(120, 64),
		position = UDim2.new(1, -282, 0, 14),
		text = "Tipp",
		textSize = 15,
		color = Theme.colors.panelLight,
	})
	hintButton.Selectable = true
	hintButton.Activated:Connect(function()
		self:toggleHintPanel()
	end)
	self.hintToggleButton = hintButton

	-- Test starten
	local testButton = Theme.button(bar, "TestButton", {
		size = UDim2.fromOffset(150, 64),
		position = UDim2.new(1, -152, 0, 14),
		text = "Test starten",
		textSize = 17,
		color = Theme.colors.success,
		textColor = Color3.fromRGB(12, 32, 18),
	})
	testButton.Selectable = true
	testButton.Activated:Connect(function()
		if self.onTest then
			self.onTest()
		end
	end)
	self.testButton = testButton
end

--------------------------------------------------------------------------------
-- 3. Statuszeile und kurze Meldungen
--------------------------------------------------------------------------------

function BuildHud:buildStatus()
	local status = Theme.panel(self.root, "Status")
	status.Size = UDim2.fromOffset(460, 34)
	status.Position = UDim2.new(0.5, -230, 1, -142)
	status.BackgroundTransparency = 0.15
	status.Visible = false
	self.statusPanel = status

	self.statusLabel = Theme.label(status, "Text", {
		size = UDim2.new(1, -20, 1, 0),
		position = UDim2.fromOffset(10, 0),
		text = "",
		textSize = 14,
		bold = true,
		align = Enum.TextXAlignment.Center,
	})
end

--[[
	Kurze Rueckmeldung, die nach ein paar Sekunden von selbst verschwindet.
	Der Token verhindert, dass eine aeltere Meldung eine neuere wegraeumt.
]]
function BuildHud:showNotice(text: string, color: Color3?)
	self.noticeToken += 1
	local token = self.noticeToken

	self.statusPanel.Visible = true
	self.statusLabel.Text = text
	self.statusLabel.TextColor3 = color or Theme.colors.warning

	task.delay(3.5, function()
		if self.noticeToken == token then
			self:refreshStatus()
		end
	end)
end

-- Zeigt die dauerhafte Warnung an (oder blendet die Zeile aus).
function BuildHud:refreshStatus()
	local state = self.state
	if not state or state.phase ~= "Build" then
		self.statusPanel.Visible = false
		return
	end

	if not state.stable and state.memberCount > 0 then
		self.statusPanel.Visible = true
		self.statusLabel.Text = "Struktur nicht stabil - die rote Markierung zeigt die schwache Stelle"
		self.statusLabel.TextColor3 = Theme.colors.danger
	else
		self.statusPanel.Visible = false
	end
end

--------------------------------------------------------------------------------
-- 4. Anzeige waehrend des Tests
--------------------------------------------------------------------------------

function BuildHud:buildTestPanel()
	local panel = Theme.panel(self.root, "TestPanel")
	panel.Size = UDim2.fromOffset(330, 128)
	panel.Position = UDim2.new(0.5, -165, 0, 78)
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	self.testPanel = panel

	self.testHeadline = Theme.label(panel, "Headline", {
		size = UDim2.new(1, -20, 0, 24),
		position = UDim2.fromOffset(10, 8),
		text = "Belastungstest",
		textSize = 16,
		bold = true,
		align = Enum.TextXAlignment.Center,
	})

	self.testTimeLabel = Theme.label(panel, "Time", {
		size = UDim2.new(1, -20, 0, 18),
		position = UDim2.fromOffset(10, 32),
		text = "",
		textSize = 13,
		color = Theme.colors.textDim,
		align = Enum.TextXAlignment.Center,
	})

	-- Hoechste Auslastung als Balken
	Theme.label(panel, "LoadCaption", {
		size = UDim2.fromOffset(160, 16),
		position = UDim2.fromOffset(12, 54),
		text = "Hoechste Auslastung",
		textSize = 12,
		color = Theme.colors.textDim,
	})

	self.testLoadLabel = Theme.label(panel, "LoadValue", {
		size = UDim2.fromOffset(80, 16),
		position = UDim2.new(1, -92, 0, 54),
		text = "0 %",
		textSize = 12,
		bold = true,
		align = Enum.TextXAlignment.Right,
	})

	local loadBg = Instance.new("Frame")
	loadBg.Name = "LoadBg"
	loadBg.Size = UDim2.new(1, -24, 0, 10)
	loadBg.Position = UDim2.fromOffset(12, 72)
	loadBg.BackgroundColor3 = Theme.colors.panelLight
	loadBg.BorderSizePixel = 0
	loadBg.Parent = panel
	Theme.corner(loadBg, 5)

	local loadFill = Instance.new("Frame")
	loadFill.Name = "LoadFill"
	loadFill.Size = UDim2.fromScale(0, 1)
	loadFill.BackgroundColor3 = Config.UtilisationColors.low
	loadFill.BorderSizePixel = 0
	loadFill.Parent = loadBg
	Theme.corner(loadFill, 5)
	self.testLoadFill = loadFill

	-- Farblegende: erklaert die Einfaerbung der Bauteile
	local legend = Instance.new("Frame")
	legend.Name = "Legend"
	legend.Size = UDim2.new(1, -24, 0, 16)
	legend.Position = UDim2.fromOffset(12, 90)
	legend.BackgroundTransparency = 1
	legend.Parent = panel

	local entries = {
		{ text = "locker", color = Config.UtilisationColors.low },
		{ text = "wird eng", color = Config.UtilisationColors.mid },
		{ text = "am Limit", color = Config.UtilisationColors.high },
	}
	local legendX = 0
	for _, entry in entries do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(10, 10)
		dot.Position = UDim2.fromOffset(legendX, 3)
		dot.BackgroundColor3 = entry.color
		dot.BorderSizePixel = 0
		dot.Parent = legend
		Theme.corner(dot, 5)

		Theme.label(legend, "Text" .. entry.text, {
			size = UDim2.fromOffset(76, 16),
			position = UDim2.fromOffset(legendX + 14, 0),
			text = entry.text,
			textSize = 11,
			color = Theme.colors.textDim,
		})
		legendX += 100
	end
end

--------------------------------------------------------------------------------
-- 5. Ergebnisfenster
--------------------------------------------------------------------------------

function BuildHud:buildResultPanel()
	local panel = Theme.panel(self.root, "ResultPanel")
	panel.Size = UDim2.fromOffset(440, 210)
	panel.Position = UDim2.new(0.5, -220, 0.5, -105)
	panel.BackgroundTransparency = 0.02
	panel.Visible = false
	self.resultPanel = panel

	self.resultTitle = Theme.label(panel, "Title", {
		size = UDim2.new(1, -32, 0, 32),
		position = UDim2.fromOffset(16, 18),
		text = "",
		textSize = 24,
		bold = true,
		align = Enum.TextXAlignment.Center,
	})

	self.resultReason = Theme.label(panel, "Reason", {
		size = UDim2.new(1, -40, 0, 70),
		position = UDim2.fromOffset(20, 56),
		text = "",
		textSize = 14,
		color = Theme.colors.textDim,
		align = Enum.TextXAlignment.Center,
		alignY = Enum.TextYAlignment.Top,
		wrapped = true,
	})

	local retry = Theme.button(panel, "Retry", {
		size = UDim2.fromOffset(180, 42),
		position = UDim2.fromOffset(24, 146),
		text = "Weiter bauen",
		textSize = 15,
		color = Theme.colors.accent,
		textColor = Color3.fromRGB(8, 18, 34),
	})
	retry.Selectable = true
	retry.Activated:Connect(function()
		if self.onRetry then
			self.onRetry()
		end
	end)
	self.retryButton = retry

	local toMenu = Theme.button(panel, "ToMenu", {
		size = UDim2.fromOffset(180, 42),
		position = UDim2.new(1, -204, 0, 146),
		text = "Zur Levelauswahl",
		textSize = 15,
		color = Theme.colors.panelLight,
	})
	toMenu.Selectable = true
	toMenu.Activated:Connect(function()
		if self.onMenu then
			self.onMenu()
		end
	end)
	self.resultMenuButton = toMenu
end

--------------------------------------------------------------------------------
-- Tipp-Fenster
--------------------------------------------------------------------------------

function BuildHud:buildHintPanel()
	local panel = Theme.panel(self.root, "HintPanel")
	panel.Size = UDim2.fromOffset(340, 300)
	panel.Position = UDim2.new(1, -352, 0, 78)
	panel.BackgroundTransparency = 0.04
	panel.Visible = false
	self.hintPanel = panel

	Theme.label(panel, "Title", {
		size = UDim2.new(1, -32, 0, 24),
		position = UDim2.fromOffset(16, 12),
		text = "Tipps",
		textSize = 18,
		bold = true,
	})

	local close = Theme.button(panel, "Close", {
		size = UDim2.fromOffset(28, 28),
		position = UDim2.new(1, -40, 0, 10),
		text = "✕",
		textSize = 14,
		color = Theme.colors.panelLight,
	})
	close.Selectable = true
	close.Activated:Connect(function()
		self:setHintPanelOpen(false)
	end)

	self.hintInfoLabel = Theme.label(panel, "Info", {
		size = UDim2.new(1, -32, 0, 18),
		position = UDim2.fromOffset(16, 36),
		text = "",
		textSize = 12,
		color = Theme.colors.textDim,
	})

	-- Liste der bereits aufgedeckten Tipps
	local list = Instance.new("ScrollingFrame")
	list.Name = "HintList"
	list.Size = UDim2.new(1, -32, 1, -128)
	list.Position = UDim2.fromOffset(16, 58)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Theme.colors.border
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	self.hintList = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Knopf zum Aufdecken des naechsten Tipps
	local reveal = Theme.button(panel, "Reveal", {
		size = UDim2.new(1, -32, 0, 46),
		position = UDim2.new(0, 16, 1, -62),
		text = "Naechsten Tipp anzeigen",
		textSize = 14,
		color = Theme.colors.accent,
		textColor = Color3.fromRGB(8, 18, 34),
	})
	reveal.Selectable = true
	reveal.Activated:Connect(function()
		if self.onHint then
			self.onHint()
		end
	end)
	self.hintRevealButton = reveal
end

function BuildHud:toggleHintPanel()
	self:setHintPanelOpen(not self.hintOpen)
end

function BuildHud:setHintPanelOpen(open: boolean)
	self.hintOpen = open
	self.hintPanel.Visible = open
	if open then
		self:refreshHintPanel()
		if Device.isGamepad() then
			GuiService.SelectedObject = self.hintRevealButton
		end
	end
end

-- Traegt die aufgedeckten Tipps und die Beschriftung des Knopfes ein.
function BuildHud:refreshHintPanel()
	local state = self.state
	if not state then
		return
	end

	-- Vorhandene Eintraege loeschen und neu aufbauen.
	for _, child in self.hintList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local unlocked = state.unlockedHints or {}
	for index, text in unlocked do
		local entry = Instance.new("Frame")
		entry.Name = "Hint" .. index
		entry.LayoutOrder = index
		entry.Size = UDim2.new(1, -8, 0, 0)
		entry.AutomaticSize = Enum.AutomaticSize.Y
		entry.BackgroundColor3 = Theme.colors.panelLight
		entry.BorderSizePixel = 0
		entry.Parent = self.hintList
		Theme.corner(entry, 6)
		Theme.padding(entry, 10)

		local label = Theme.label(entry, "Text", {
			size = UDim2.new(1, 0, 0, 0),
			text = string.format("%d. %s", index, text),
			textSize = 13,
			wrapped = true,
			alignY = Enum.TextYAlignment.Top,
		})
		label.AutomaticSize = Enum.AutomaticSize.Y
	end

	local total = state.hintTotal or 0
	local used = #unlocked
	local free = state.freeHints or 0

	self.hintInfoLabel.Text = string.format("%d von %d aufgedeckt", used, total)

	if used >= total then
		self.hintRevealButton.Text = "Keine weiteren Tipps"
		self.hintRevealButton.Active = false
		Theme.paint(self.hintRevealButton, Theme.colors.panelLight, Theme.colors.textDim)
		return
	end

	self.hintRevealButton.Active = true

	local nextIndex = used + 1
	if nextIndex <= free then
		self.hintRevealButton.Text = "Naechsten Tipp anzeigen (gratis)"
		Theme.paint(self.hintRevealButton, Theme.colors.accent, Color3.fromRGB(8, 18, 34))
	else
		self.hintRevealButton.Text = string.format("Tipp freischalten (%d Robux)", Config.Monetisation.hintPrice)
		Theme.paint(self.hintRevealButton, Theme.colors.robux, Color3.fromRGB(8, 26, 12))
	end
end

--------------------------------------------------------------------------------
-- Zustand vom Server verarbeiten
--------------------------------------------------------------------------------

function BuildHud:update(state)
	self.state = state

	----------------------------------------------------------------------------
	-- Kopfzeile
	----------------------------------------------------------------------------
	self.levelLabel.Text = state.levelName or "Level"

	local info = Config.difficultyInfo(state.difficulty or 1)
	self.difficultyLabel.Text = string.format("%s  %s", Theme.stars(state.difficulty or 1, 5), info.label)
	self.difficultyLabel.TextColor3 = info.color

	local used = state.budgetUsed or 0
	local total = math.max(state.budgetTotal or 1, 1)
	self.budgetLabel.Text = string.format("Budget %d / %d", used, total)

	local fraction = math.clamp(used / total, 0, 1)
	self.budgetFill.Size = UDim2.fromScale(fraction, 1)
	if fraction > 0.95 then
		self.budgetFill.BackgroundColor3 = Theme.colors.danger
	elseif fraction > 0.8 then
		self.budgetFill.BackgroundColor3 = Theme.colors.warning
	else
		self.budgetFill.BackgroundColor3 = Theme.colors.accent
	end

	----------------------------------------------------------------------------
	-- Gesperrte Bauteile ausgrauen
	----------------------------------------------------------------------------
	for key, button in self.partButtons do
		local allowed = true
		if state.allowedParts then
			allowed = table.find(state.allowedParts, key) ~= nil
		end
		button.Active = allowed
		button.AutoButtonColor = allowed
		button.Selectable = allowed
		local nameLabel = button:FindFirstChild("Name")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.TextColor3 = if allowed then Theme.colors.text else Theme.colors.textDim
		end
		if not allowed then
			button.BackgroundColor3 = Theme.colors.background
		end
	end

	----------------------------------------------------------------------------
	-- Phase: was ist gerade sichtbar?
	----------------------------------------------------------------------------
	local building = state.phase == "Build"

	self.bottomBar.Visible = building
	self.testButton.Active = building
	self.clearButton.Visible = building
	self.resetButton.Visible = state.phase ~= "Test"

	self.testPanel.Visible = state.phase == "Test"
	if state.phase == "Test" then
		self:updateTestPanel(state)
	end

	self.resultPanel.Visible = state.phase == "Result" and state.result ~= nil
	if self.resultPanel.Visible then
		self:updateResultPanel(state.result)
	end

	if not building and self.hintOpen then
		self:setHintPanelOpen(false)
	end

	self:refreshStatus()
	if self.hintOpen then
		self:refreshHintPanel()
	end
end

function BuildHud:updateTestPanel(state)
	local progress = state.testProgress
	if not progress then
		return
	end

	if progress.countdown and progress.countdown > 0 then
		self.testHeadline.Text = string.format("Test startet in %.0f ...", math.ceil(progress.countdown))
		self.testTimeLabel.Text = "Die Bruecke traegt jetzt ihr eigenes Gewicht"
	else
		self.testHeadline.Text = "Belastungstest laeuft"
		self.testTimeLabel.Text = string.format(
			"%.1f s von hoechstens %d s",
			progress.elapsed or 0,
			state.timeLimit or 0
		)
	end

	local utilisation = math.clamp(progress.maxUtilisation or 0, 0, 1.5)
	self.testLoadLabel.Text = string.format("%d %%", math.floor(utilisation * 100 + 0.5))
	self.testLoadFill.Size = UDim2.fromScale(math.clamp(utilisation, 0, 1), 1)
	self.testLoadFill.BackgroundColor3 = Config.utilisationColor(utilisation)
end

function BuildHud:updateResultPanel(result)
	if result.success then
		self.resultTitle.Text = "Geschafft!"
		self.resultTitle.TextColor3 = Theme.colors.success
		self.retryButton.Text = "Noch einmal bauen"
	else
		self.resultTitle.Text = "Nicht bestanden"
		self.resultTitle.TextColor3 = Theme.colors.danger
		self.retryButton.Text = "Weiter bauen"
	end
	self.resultReason.Text = result.reason or ""

	if Device.isGamepad() then
		GuiService.SelectedObject = self.retryButton
	end
end

--------------------------------------------------------------------------------
-- Antwort auf eine Tipp-Anfrage
--------------------------------------------------------------------------------

function BuildHud:handleHintResult(payload)
	if payload.status == "ok" then
		self:setHintPanelOpen(true)
		self:refreshHintPanel()
	elseif payload.status == "none" then
		self:showNotice("Fuer dieses Level gibt es keine weiteren Tipps.", Theme.colors.textDim)
	end
	-- "needPurchase" wird in init.client behandelt (dort wird der Kauf geoeffnet).
end

--------------------------------------------------------------------------------
-- Auswahl hervorheben
--------------------------------------------------------------------------------

function BuildHud:setSelected(kind: string)
	self.selected = kind

	for key, button in self.partButtons do
		local active = key == kind
		Theme.paint(button, if active then Theme.colors.accentDark else Theme.colors.panelLight)
	end

	Theme.paint(
		self.removeButton,
		if kind == "Remove" then Theme.colors.danger else Theme.colors.panelLight
	)
end

--------------------------------------------------------------------------------
-- Groessen und Sichtbarkeit
--------------------------------------------------------------------------------

function BuildHud:applyScale()
	self.scale.Scale = Device.uiScale()

	local inset = Device.edgeInset()
	self.topBar.Position = UDim2.fromOffset(inset, inset - 4)
	self.topBar.Size = UDim2.new(1, -inset * 2, 0, 58)
	self.bottomBar.Position = UDim2.new(0, inset, 1, -(102 + inset - 12))
	self.bottomBar.Size = UDim2.new(1, -inset * 2, 0, 92)
end

function BuildHud:show()
	self:applyScale()
	self.gui.Enabled = true
end

function BuildHud:hide()
	self.gui.Enabled = false
	self:setHintPanelOpen(false)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject = nil
	end
end

return BuildHud
