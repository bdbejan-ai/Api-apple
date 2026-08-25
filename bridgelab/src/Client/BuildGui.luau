--[[
	BuildGui
	--------
	Baut die Benutzeroberflaeche komplett im Code auf.

	Warum im Code und nicht als fertige GUI-Instanzen?
	Rojo kann zwar auch GUI-Objekte synchronisieren, dafuer braeuchte es aber
	Binaerdateien (.rbxmx), die sich nicht lesen und nicht von Hand aendern
	lassen. Im Code ist alles nachvollziehbar und aenderbar.

	Die Oberflaeche ist bewusst schlicht: Budget oben links, Bauteilauswahl
	unten, Meldungen in der Mitte.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local BuildGui = {}
BuildGui.__index = BuildGui

local COLOR_PANEL = Color3.fromRGB(28, 30, 36)
local COLOR_TEXT = Color3.fromRGB(235, 238, 245)
local COLOR_MUTED = Color3.fromRGB(160, 168, 182)
local COLOR_ACCENT = Color3.fromRGB(80, 150, 235)
local COLOR_GOOD = Color3.fromRGB(80, 190, 120)
local COLOR_BAD = Color3.fromRGB(225, 80, 70)
local COLOR_WARN = Color3.fromRGB(235, 180, 60)

local FONT = Enum.Font.GothamMedium

local function makeLabel(parent: Instance, size: UDim2, position: UDim2, text: string, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextColor3 = COLOR_TEXT
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makePanel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = COLOR_PANEL
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	return frame
end

local function makeButton(parent: Instance, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 118, 1, -16)
	button.BackgroundColor3 = Color3.fromRGB(52, 56, 66)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = FONT
	button.Text = text
	button.TextColor3 = COLOR_TEXT
	button.TextSize = 14
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

--------------------------------------------------------------------------------

function BuildGui.new()
	local self = setmetatable({}, BuildGui)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BridgeLabGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	self.screenGui = screenGui
	self.partButtons = {}

	----------------------------------------------------------------------------
	-- Kopfzeile: Level, Budget, Stabilitaet
	----------------------------------------------------------------------------

	local header = makePanel(screenGui, UDim2.new(0, 300, 0, 104), UDim2.new(0, 16, 0, 16), Vector2.zero)

	self.levelLabel = makeLabel(header, UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8), "BridgeLab", 16)
	self.levelLabel.TextColor3 = COLOR_ACCENT

	self.budgetLabel = makeLabel(header, UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 30), "Budget: 0 / 0", 20)

	self.budgetBarBack = Instance.new("Frame")
	self.budgetBarBack.Size = UDim2.new(1, -24, 0, 6)
	self.budgetBarBack.Position = UDim2.new(0, 12, 0, 58)
	self.budgetBarBack.BackgroundColor3 = Color3.fromRGB(60, 64, 74)
	self.budgetBarBack.BorderSizePixel = 0
	self.budgetBarBack.Parent = header

	self.budgetBarFill = Instance.new("Frame")
	self.budgetBarFill.Size = UDim2.new(0, 0, 1, 0)
	self.budgetBarFill.BackgroundColor3 = COLOR_ACCENT
	self.budgetBarFill.BorderSizePixel = 0
	self.budgetBarFill.Parent = self.budgetBarBack

	self.stabilityLabel = makeLabel(header, UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 72), "", 14)
	self.stabilityLabel.TextColor3 = COLOR_MUTED

	----------------------------------------------------------------------------
	-- Meldung in der Bildmitte
	----------------------------------------------------------------------------

	self.messageLabel = Instance.new("TextLabel")
	self.messageLabel.Size = UDim2.new(0, 560, 0, 40)
	self.messageLabel.Position = UDim2.new(0.5, 0, 0, 130)
	self.messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	self.messageLabel.BackgroundTransparency = 1
	self.messageLabel.Font = Enum.Font.GothamBold
	self.messageLabel.Text = ""
	self.messageLabel.TextColor3 = COLOR_TEXT
	self.messageLabel.TextSize = 20
	self.messageLabel.TextStrokeTransparency = 0.5
	self.messageLabel.Parent = screenGui

	----------------------------------------------------------------------------
	-- Werkzeugleiste unten
	----------------------------------------------------------------------------

	local toolbar = makePanel(
		screenGui,
		UDim2.new(0, 780, 0, 64),
		UDim2.new(0.5, 0, 1, -20),
		Vector2.new(0.5, 1)
	)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = toolbar

	-- Ein Knopf je Bauteiltyp.
	for _, key in Config.PartOrder do
		local spec = Config.PartTypes[key]
		local button = makeButton(toolbar, string.format("%s\n%d Einheiten", spec.displayName, spec.cost))
		self.partButtons[key] = button
	end

	-- Entfernen-Modus
	self.removeButton = makeButton(toolbar, "Entfernen\n(Rechtsklick)")
	self.partButtons.Remove = self.removeButton

	-- Trenner
	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(0, 2, 0, 34)
	spacer.BackgroundColor3 = Color3.fromRGB(80, 86, 98)
	spacer.BorderSizePixel = 0
	spacer.Parent = toolbar

	self.testButton = makeButton(toolbar, "Test starten")
	self.testButton.BackgroundColor3 = Color3.fromRGB(45, 110, 70)

	self.resetButton = makeButton(toolbar, "Zuruecksetzen")
	self.resetButton.BackgroundColor3 = Color3.fromRGB(96, 60, 56)

	----------------------------------------------------------------------------
	-- Hinweiszeile
	----------------------------------------------------------------------------

	self.hintLabel = Instance.new("TextLabel")
	self.hintLabel.Size = UDim2.new(0, 780, 0, 18)
	self.hintLabel.Position = UDim2.new(0.5, 0, 1, -90)
	self.hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	self.hintLabel.BackgroundTransparency = 1
	self.hintLabel.Font = FONT
	self.hintLabel.Text = "Bauteil waehlen, dann zwei Ankerpunkte anklicken. Rechtsklick entfernt ein Bauteil."
	self.hintLabel.TextColor3 = COLOR_MUTED
	self.hintLabel.TextSize = 13
	self.hintLabel.TextStrokeTransparency = 0.7
	self.hintLabel.Parent = screenGui

	----------------------------------------------------------------------------
	-- Kurzmeldungen (z. B. "Budget reicht nicht")
	----------------------------------------------------------------------------

	self.noticeLabel = Instance.new("TextLabel")
	self.noticeLabel.Size = UDim2.new(0, 560, 0, 24)
	self.noticeLabel.Position = UDim2.new(0.5, 0, 1, -114)
	self.noticeLabel.AnchorPoint = Vector2.new(0.5, 1)
	self.noticeLabel.BackgroundTransparency = 1
	self.noticeLabel.Font = FONT
	self.noticeLabel.Text = ""
	self.noticeLabel.TextColor3 = COLOR_WARN
	self.noticeLabel.TextSize = 15
	self.noticeLabel.TextStrokeTransparency = 0.6
	self.noticeLabel.Parent = screenGui

	self.noticeToken = 0

	return self
end

--------------------------------------------------------------------------------
-- Anzeige aktualisieren
--------------------------------------------------------------------------------

function BuildGui:setSelected(selection: string)
	for key, button in self.partButtons do
		local isSelected = key == selection
		button.BackgroundColor3 = if isSelected then COLOR_ACCENT else Color3.fromRGB(52, 56, 66)
	end
end

function BuildGui:showNotice(text: string)
	self.noticeToken += 1
	local token = self.noticeToken
	self.noticeLabel.Text = text
	task.delay(3, function()
		if self.noticeToken == token then
			self.noticeLabel.Text = ""
		end
	end)
end

function BuildGui:update(state)
	self.levelLabel.Text = state.levelName or "BridgeLab"

	local used = state.budgetUsed or 0
	local total = state.budgetTotal or 0
	self.budgetLabel.Text = string.format("Budget: %d / %d", used, total)

	local fraction = if total > 0 then math.clamp(used / total, 0, 1) else 0
	self.budgetBarFill.Size = UDim2.new(fraction, 0, 1, 0)
	self.budgetBarFill.BackgroundColor3 = if fraction > 0.95 then COLOR_BAD else COLOR_ACCENT

	-- Stabilitaetshinweis
	if state.memberCount and state.memberCount > 0 then
		if state.stable then
			self.stabilityLabel.Text = "Struktur traegt sich selbst."
			self.stabilityLabel.TextColor3 = COLOR_GOOD
		else
			self.stabilityLabel.Text = "Nicht ausgesteift (rote Markierung)"
			self.stabilityLabel.TextColor3 = COLOR_WARN
		end
	else
		self.stabilityLabel.Text = "Noch nichts gebaut."
		self.stabilityLabel.TextColor3 = COLOR_MUTED
	end

	-- Meldung / Ergebnis
	if state.result then
		self.messageLabel.Text = state.result.reason or ""
		self.messageLabel.TextColor3 = if state.result.success then COLOR_GOOD else COLOR_BAD
	elseif state.phase == "Test" then
		self.messageLabel.Text = "Belastungstest laeuft ..."
		self.messageLabel.TextColor3 = COLOR_TEXT
	else
		self.messageLabel.Text = ""
	end

	-- Knoepfe sperren, solange der Test laeuft
	local building = state.phase == "Build"
	for _, button in self.partButtons do
		button.Active = building
		button.AutoButtonColor = building
		button.TextTransparency = if building then 0 else 0.5
	end
	self.testButton.Active = building
	self.testButton.TextTransparency = if building then 0 else 0.5

	if state.phase == "Build" then
		self.hintLabel.Text =
			"Bauteil waehlen, dann zwei Ankerpunkte anklicken. Rechtsklick entfernt ein Bauteil."
	elseif state.phase == "Test" then
		self.hintLabel.Text = string.format("Zeitlimit: %d Sekunden", state.timeLimit or 30)
	else
		self.hintLabel.Text = "Mit 'Zuruecksetzen' geht es zurueck in den Baumodus."
	end
end

return BuildGui
