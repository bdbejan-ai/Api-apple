--[[
	BuildHud
	--------
	Die Oberflaeche waehrend des Spiels.

	DAS LAYOUT IST IN ZONEN AUFGETEILT - UND ZWAR AUS EINEM GRUND
	Vorher lagen die Fenster an festen Bildschirmpunkten: die Testanzeige
	oben mittig, das Tipp-Fenster oben rechts, der Tacho ueber der
	Fussleiste. Auf einem breiten Bildschirm ging das gut. Auf einem Handy
	quer lagen Testanzeige und Tipp-Fenster uebereinander, und der Tacho
	schob sich in die Fussleiste.

	Jetzt gibt es vier Zonen, die sich nicht ueberschneiden koennen:

	    +--------------------------------------------------+
	    |  KOPF   Level, Budget, Menue                     |
	    +------+------------------------------+------------+
	    | LEIS |                              |  SPALTE    |
	    | TE   |                              |  rechts:   |
	    | Bau- |        freie Sicht           |  Test ODER |
	    | stof |        auf die Bruecke       |  Tipps     |
	    | fe   |                              |            |
	    +------+------------------------------+------------+
	    |  FUSS   Phasen, Tempo, Test starten              |
	    +--------------------------------------------------+

	Die Baustoffe stehen jetzt LINKS UNTEREINANDER statt unten nebeneinander.
	Mit drei Bauteilen passte eine Zeile noch; mit sieben Baustoffen waeren
	es ueber 900 Pixel geworden - mehr, als ein Handy quer ueberhaupt hat.

	In der rechten Spalte liegt immer nur EIN Fenster. Oeffnet man die
	Tipps waehrend des Tests, tritt die Testanzeige nach unten zurueck,
	statt sich zu ueberlagern (siehe layoutRightColumn).

	Alle Groessen haengen an einem UIScale, den Device.uiScale() liefert.
	Dadurch ist die Bedienung auf dem Handy automatisch groesser als am PC.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Materials = require(Shared.Materials)
local I18n = require(Shared.I18n)
local Levels = require(Shared.Levels)

local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)

local BuildHud = {}
BuildHud.__index = BuildHud

function BuildHud.new()
	local self = setmetatable({}, BuildHud)

	self.player = Players.LocalPlayer
	self.materialButtons = {}
	self.phaseButtons = {}
	self.selected = "Road"
	self.phase = 0
	self.buildPhase = 1
	self.state = nil
	self.hintOpen = false
	self.noticeToken = 0

	-- Rueckmeldungen nach aussen
	self.onSelectMaterial = nil
	self.onRemoveMode = nil
	self.onTest = nil
	self.onReset = nil
	self.onClear = nil
	self.onMenu = nil
	self.onHint = nil
	self.onRetry = nil
	self.onNextLevel = nil
	self.onSpeedChanged = nil
	self.onPhaseChanged = nil
	self.onBuildPhaseChanged = nil
	self.onBlueprint = nil

	--[[
		Der linke Knopf im Ergebnisfenster hat zwei Bedeutungen: nach einem
		Misserfolg "weiter bauen", nach einem Erfolg "naechstes Level".
	]]
	self.resultPrimaryMode = "retry"
	self.nextLevelId = nil

	-- Am Tacho eingestellte Fahrgeschwindigkeit.
	self.speed = Config.Test.defaultSpeed
	self.draggingSpeed = false
	self.lastSpeedPush = nil
	self.pendingSpeedPush = false

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
	self:buildMaterialRail()
	self:buildBottomBar()
	self:buildSpeedPanel()
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
		text = "",
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
		text = I18n.t("hud.budget", 0, 0),
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

	self.menuButton = topButton("MenuButton", I18n.t("hud.menu"), 86, 74)
	self.resetButton = topButton("ResetButton", I18n.t("hud.reset"), 208, 116)
	self.clearButton = topButton("ClearButton", I18n.t("hud.clear"), 302, 88)

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
-- 2. Baustoffleiste links
--------------------------------------------------------------------------------

--[[
	Ein Knopf je Baustoff, untereinander an der linken Kante.

	Jeder Knopf zeigt drei Dinge, und jedes davon braucht man beim Bauen:
	  * den Namen
	  * den Preis JE STUD - beim freien Bauen kostet Laenge wirklich Geld
	  * die Belastungsgrenzen, damit man Holz und Stahl vergleichen kann

	Ein farbiger Streifen links am Knopf traegt die Farbe des Baustoffs.
	Dieselbe Farbe hat das Bauteil in der Welt - so findet man wieder,
	womit man gerade gebaut hat.
]]
--[[
	KLEINE ZEICHNUNGEN STATT SCHRIFTZEICHEN

	Jeder Baustoff bekommt ein Symbol aus ein paar Rechtecken - ein I-Profil
	fuer Stahl, uebereinanderliegende Bohlen fuer Holz, eine Kette fuer das
	Seil. Buchstaben oder Sonderzeichen waeren einfacher gewesen, sagen aber
	nichts: man muss sie erst lesen und dann uebersetzen. Eine Form erkennt
	man sofort, und sie sieht auch noch aus wie das, was gebaut wird.

	Bilder aus dem Netz gehen nicht - dafuer braeuchte es hochgeladene
	Roblox-Grafiken, und die kann dieses Projekt nicht mitliefern.
]]
local function drawMaterialIcon(parent: Instance, key: string, color: Color3)
	local box = Instance.new("Frame")
	box.Name = "Symbol"
	box.Size = UDim2.fromOffset(22, 22)
	box.Position = UDim2.fromOffset(0, 0)
	box.BackgroundTransparency = 1
	box.Parent = parent

	local function bar(x: number, y: number, w: number, h: number, shade: Color3?, rotation: number?)
		local piece = Instance.new("Frame")
		piece.Name = "Teil"
		piece.Size = UDim2.fromOffset(w, h)
		piece.Position = UDim2.fromOffset(x, y)
		piece.BackgroundColor3 = shade or color
		piece.BorderSizePixel = 0
		piece.Rotation = rotation or 0
		piece.Parent = box
		return piece
	end

	local dark = color:Lerp(Color3.fromRGB(0, 0, 0), 0.45)

	if key == "Road" or key == "ReinforcedRoad" then
		-- Fahrbahnband mit Mittelstrich, bei der verstaerkten ein Untergurt.
		bar(1, 8, 20, 6)
		bar(8, 10, 6, 2, Color3.fromRGB(236, 236, 230))
		if key == "ReinforcedRoad" then
			bar(4, 15, 14, 3, dark)
		end
	elseif key == "Steel" then
		-- I-Profil: zwei Gurte und ein Steg.
		bar(3, 4, 16, 3)
		bar(9, 7, 4, 8)
		bar(3, 15, 16, 3)
	elseif key == "Wood" then
		-- Drei Bohlen mit einem Band quer darueber.
		bar(2, 5, 18, 3)
		bar(2, 10, 18, 3)
		bar(2, 15, 18, 3)
		bar(9, 3, 3, 17, dark)
	elseif key == "Rope" or key == "Cable" then
		--[[
			Ein durchhaengendes Seil, aus drei gedrehten Strichen. Genau so
			sieht es auch in der Welt aus - dort haengt es ebenfalls durch.
		]]
		local width = if key == "Cable" then 3 else 2
		bar(2, 7, 8, width, nil, 26)
		bar(7, 12, 8, width, nil, 0)
		bar(12, 7, 8, width, nil, -26)
	elseif key == "Hydraulic" then
		-- Zylinder und herausfahrende Kolbenstange.
		bar(2, 8, 11, 7)
		bar(13, 10, 7, 3, dark)
		bar(19, 8, 2, 7, dark)
	end

	return box
end

function BuildHud:buildMaterialRail()
	local rail = Theme.panel(self.root, "MaterialRail")
	rail.BackgroundTransparency = 0.08
	self.materialRail = rail

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -16)
	list.Position = UDim2.fromOffset(8, 8)
	list.BackgroundTransparency = 1
	list.Parent = rail

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	self.materialList = list

	for order, key in Materials.order do
		local spec = Materials.get(key)

		local button = Theme.button(list, "Material_" .. key, {
			size = UDim2.new(1, 0, 0, 56),
			text = "",
			color = Theme.colors.panelLight,
		})
		button.LayoutOrder = order
		button.Selectable = true

		-- Farbstreifen in der Farbe des Baustoffs.
		local stripe = Instance.new("Frame")
		stripe.Name = "Stripe"
		stripe.Size = UDim2.new(0, 4, 1, -12)
		stripe.Position = UDim2.fromOffset(6, 6)
		stripe.BackgroundColor3 = spec.uiColor
		stripe.BorderSizePixel = 0
		stripe.Parent = button
		Theme.corner(stripe, 2)

		local icon = drawMaterialIcon(button, key, spec.uiColor)
		icon.Position = UDim2.fromOffset(14, 17)

		Theme.label(button, "Name", {
			size = UDim2.new(1, -46, 0, 18),
			position = UDim2.fromOffset(42, 6),
			text = I18n.t(Materials.nameKey(key)),
			textSize = 14,
			bold = true,
		})

		Theme.label(button, "Cost", {
			size = UDim2.new(1, -46, 0, 14),
			position = UDim2.fromOffset(42, 23),
			text = I18n.t("material.perStud", spec.costPerStud),
			textSize = 11,
			color = Theme.colors.textDim,
		})

		Theme.label(button, "Limits", {
			size = UDim2.new(1, -46, 0, 14),
			position = UDim2.fromOffset(42, 37),
			--[[
				Bei Seilen steht ausdruecklich "kein Druck" statt einer Null.
				Eine 0 liest sich wie ein vergessener Wert; "kein Druck" sagt,
				dass das die Eigenschaft des Baustoffs ist.
			]]
			text = if spec.maxCompression > 0
				then I18n.t("material.limits", spec.maxTension, spec.maxCompression)
				else I18n.t("material.limitsTensionOnly", spec.maxTension),
			textSize = 10,
			color = Theme.colors.textDim,
		})

		button.Activated:Connect(function()
			if self.onSelectMaterial then
				self.onSelectMaterial(key)
			end
		end)

		self.materialButtons[key] = button
	end

	-- Abrissmodus ganz unten, abgesetzt.
	local removeButton = Theme.button(list, "RemoveButton", {
		size = UDim2.new(1, 0, 0, 40),
		text = I18n.t("hud.remove"),
		textSize = 14,
		color = Theme.colors.panelLight,
	})
	removeButton.LayoutOrder = 100
	removeButton.Selectable = true
	removeButton.Activated:Connect(function()
		if self.onRemoveMode then
			self.onRemoveMode()
		end
	end)
	self.removeButton = removeButton
end

--[[
	Baustoffe, die das Level gar nicht anbietet, werden ausgeblendet statt
	nur ausgegraut. Ein gesperrter Knopf, den man trotzdem sieht, laedt zum
	Draufdruecken ein und gibt dann eine Absage - das ist aergerlich, wenn
	es das Level schlicht nicht vorsieht.
]]
function BuildHud:setAvailableMaterials(list)
	for key, button in self.materialButtons do
		button.Visible = list == nil or table.find(list, key) ~= nil
	end
end

--------------------------------------------------------------------------------
-- 3. Fussleiste: Phasen, Tempo, Test
--------------------------------------------------------------------------------

function BuildHud:buildBottomBar()
	local bar = Theme.panel(self.root, "BottomBar")
	bar.BackgroundTransparency = 0.08
	self.bottomBar = bar

	----------------------------------------------------------------------------
	-- Hydraulikphasen links
	----------------------------------------------------------------------------

	--[[
		Die Phasenknoepfe erscheinen nur in Levels mit Hydraulik und haben
		je nach Spielabschnitt ZWEI Bedeutungen:

		  beim Bauen   welcher Phase der naechste Zylinder angehoert
		  im Test      welche Phase gerade geschaltet ist

		Das ist kein Trick, sondern dieselbe Frage aus zwei Richtungen: beim
		Bauen legt man fest, wann ein Zylinder ausfahren soll, im Test loest
		man es aus. Zwei getrennte Bedienelemente dafuer waeren nur doppelt.

		"Ein" (Phase 0) gibt es nur im Test - beim Bauen muss jeder Zylinder
		zu einer echten Phase gehoeren, sonst wuerde er nie ausfahren.
	]]
	local phaseBox = Instance.new("Frame")
	phaseBox.Name = "Phases"
	phaseBox.Size = UDim2.fromOffset(58 * (Config.Hydraulics.phaseCount + 1) + 70, 64)
	phaseBox.Position = UDim2.fromOffset(14, 14)
	phaseBox.BackgroundTransparency = 1
	phaseBox.Visible = false
	phaseBox.Parent = bar
	self.phaseBox = phaseBox

	self.phaseCaption = Theme.label(phaseBox, "Caption", {
		size = UDim2.fromOffset(240, 16),
		position = UDim2.fromOffset(2, 2),
		text = I18n.t("hud.phases"),
		textSize = 12,
		bold = true,
		color = Theme.colors.textDim,
	})

	for phase = 0, Config.Hydraulics.phaseCount do
		local button = Theme.button(phaseBox, "Phase_" .. phase, {
			size = UDim2.fromOffset(52, 38),
			position = UDim2.fromOffset(phase * 58, 22),
			text = if phase == 0 then I18n.t("hud.phaseOff") else tostring(phase),
			textSize = 14,
			color = Theme.colors.panelLight,
		})
		button.Selectable = true
		button.Activated:Connect(function()
			local running = self.state ~= nil and self.state.phase == "Test"
			if running then
				if self.onPhaseChanged then
					self.onPhaseChanged(phase)
				end
			elseif phase > 0 then
				self:setBuildPhase(phase)
			end
		end)
		self.phaseButtons[phase] = button
	end

	----------------------------------------------------------------------------
	-- Knoepfe rechts
	----------------------------------------------------------------------------

	--[[
		VORLAGE - der Einstieg fuer alle, die noch nie eine Bruecke gebaut haben

		Blendet eine blasse Zeichnung eines gewoehnlichen Fachwerks ein. Sie
		baut nichts, sie zeigt nur die Form. Der Knopf steht bewusst links
		neben TIPP: die Vorlage ist gratis und verraet nichts ueber DIESES
		Level, waehrend ein Tipp Robux kosten kann.
	]]
	local blueprintButton = Theme.button(bar, "BlueprintButton", {
		size = UDim2.fromOffset(110, 64),
		position = UDim2.new(1, -388, 0, 14),
		text = I18n.t("hud.blueprint"),
		textSize = 15,
		color = Theme.colors.panelLight,
	})
	blueprintButton.Selectable = true
	blueprintButton.Activated:Connect(function()
		if self.onBlueprint then
			self.onBlueprint()
		end
	end)
	self.blueprintButton = blueprintButton

	local hintButton = Theme.button(bar, "HintButton", {
		size = UDim2.fromOffset(110, 64),
		position = UDim2.new(1, -272, 0, 14),
		text = I18n.t("hud.hint"),
		textSize = 15,
		color = Theme.colors.panelLight,
	})
	hintButton.Selectable = true
	hintButton.Activated:Connect(function()
		self:toggleHintPanel()
	end)
	self.hintToggleButton = hintButton

	local testButton = Theme.button(bar, "TestButton", {
		size = UDim2.fromOffset(150, 64),
		position = UDim2.new(1, -152, 0, 14),
		text = I18n.t("hud.test"),
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

-- Phasenknoepfe ein- und ausblenden und den aktiven hervorheben.
function BuildHud:refreshPhases(state)
	local show = state ~= nil and state.hasHydraulics == true
	self.phaseBox.Visible = show
	if not show then
		return
	end

	local running = state.phase == "Test"
	local active = if running then (state.phaseIndex or 0) else self.buildPhase

	self.phaseCaption.Text = if running
		then I18n.t("hud.phasesTest")
		else I18n.t("hud.phasesBuild")

	for phase, button in self.phaseButtons do
		local isActive = phase == active
		button.BackgroundColor3 = if isActive then Theme.colors.accent else Theme.colors.panelLight
		button.TextColor3 = if isActive then Color3.fromRGB(14, 20, 30) else Theme.colors.text

		-- "Ein" bedeutet "alles eingefahren" und ergibt beim Bauen keinen Sinn.
		local usable = running or phase > 0
		button.AutoButtonColor = usable
		button.TextTransparency = if usable then 0 else 0.5
	end
end

-- Zeigt am Knopf, ob die Vorlage gerade eingeblendet ist.
function BuildHud:setBlueprintActive(active: boolean, available: boolean)
	self.blueprintButton.Visible = available
	Theme.paint(
		self.blueprintButton,
		if active then Theme.colors.accentDark else Theme.colors.panelLight
	)
end

-- Beim Bauen: welcher Phase der naechste Zylinder angehoeren soll.
function BuildHud:setBuildPhase(phase: number)
	self.buildPhase = math.clamp(phase, 1, Config.Hydraulics.phaseCount)
	if self.onBuildPhaseChanged then
		self.onBuildPhaseChanged(self.buildPhase)
	end
	if self.state then
		self:refreshPhases(self.state)
	end
end

--------------------------------------------------------------------------------
-- Tacho: wie schnell faehrt das Fahrzeug?
--------------------------------------------------------------------------------

--[[
	Ein Schieberegler von 1 bis 14 Studs pro Sekunde.

	Er ist absichtlich IMMER sichtbar - vor dem Test und waehrend der Fahrt.
	Langsam fahren heisst: man sieht in Ruhe zu, wo die Belastung hochgeht.
	Schnell fahren heisst: es geht zackig voran, das Fahrzeug schlaegt aber
	haerter auf und bringt die Bruecke staerker ins Schwingen.

	Das Zeitlimit richtet sich nach der gewaehlten Geschwindigkeit. Langsam
	fahren kann also nie dazu fuehren, dass die Zeit abläuft.
]]
function BuildHud:buildSpeedPanel()
	local panel = Theme.panel(self.root, "SpeedPanel")
	panel.Size = UDim2.fromOffset(296, 78)
	panel.BackgroundTransparency = 0.08
	self.speedPanel = panel

	Theme.label(panel, "Caption", {
		size = UDim2.fromOffset(120, 18),
		position = UDim2.fromOffset(14, 9),
		text = I18n.t("hud.speed"),
		textSize = 13,
		bold = true,
		color = Theme.colors.textDim,
	})

	self.speedValueLabel = Theme.label(panel, "Value", {
		size = UDim2.fromOffset(150, 20),
		position = UDim2.new(1, -164, 0, 8),
		text = "",
		textSize = 15,
		bold = true,
		align = Enum.TextXAlignment.Right,
	})

	-- Minus
	local minus = Theme.button(panel, "Minus", {
		size = UDim2.fromOffset(34, 30),
		position = UDim2.fromOffset(14, 34),
		text = "−",
		textSize = 20,
		color = Theme.colors.panelLight,
	})
	minus.Selectable = true
	minus.Activated:Connect(function()
		self:setSpeed(self.speed - Config.Test.speedStep * 5)
		self:pushSpeed()
	end)

	-- Plus
	local plus = Theme.button(panel, "Plus", {
		size = UDim2.fromOffset(34, 30),
		position = UDim2.new(1, -48, 0, 34),
		text = "+",
		textSize = 20,
		color = Theme.colors.panelLight,
	})
	plus.Selectable = true
	plus.Activated:Connect(function()
		self:setSpeed(self.speed + Config.Test.speedStep * 5)
		self:pushSpeed()
	end)

	----------------------------------------------------------------------------
	-- Der Schieberegler selbst
	----------------------------------------------------------------------------

	-- Als TextButton, damit er Klicks und Finger sicher entgegennimmt.
	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Size = UDim2.new(1, -110, 0, 12)
	track.Position = UDim2.fromOffset(56, 43)
	track.BackgroundColor3 = Theme.colors.panelLight
	track.BorderSizePixel = 0
	track.AutoButtonColor = false
	track.Text = ""
	track.Parent = panel
	Theme.corner(track, 6)
	self.speedTrack = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0.25, 1)
	fill.BackgroundColor3 = Theme.colors.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	Theme.corner(fill, 6)
	self.speedFill = fill

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(20, 20)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.25, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(244, 246, 250)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Theme.corner(knob, 10)
	self.speedKnob = knob

	----------------------------------------------------------------------------
	-- Ziehen
	----------------------------------------------------------------------------

	local function setFromPosition(x: number)
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		local fraction = math.clamp((x - left) / width, 0, 1)
		self:setSpeed(Config.Test.minSpeed + fraction * (Config.Test.maxSpeed - Config.Test.minSpeed))
		self:pushSpeed()
	end

	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.draggingSpeed = true
			setFromPosition(input.Position.X)
		end
	end)

	-- Weitergezogen wird auch dann, wenn der Zeiger den Regler verlaesst.
	UserInputService.InputChanged:Connect(function(input)
		if not self.draggingSpeed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setFromPosition(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if self.draggingSpeed then
				self.draggingSpeed = false
				-- Zum Schluss den endgueltigen Wert auf jeden Fall melden.
				if self.pendingSpeedPush then
					self:pushSpeed(true)
				end
			end
		end
	end)

	self:refreshSpeedDisplay()
end

-- Wert uebernehmen und begrenzen. Der Server prueft ihn noch einmal.
function BuildHud:setSpeed(speed: number)
	self.speed = math.clamp(speed, Config.Test.minSpeed, Config.Test.maxSpeed)
	self:refreshSpeedDisplay()
end

--[[
	Den neuen Wert an den Server melden - aber hoechstens etwa fuenfzehnmal
	pro Sekunde. Beim Ziehen liefert die Maus sonst jede Bildwiederholung
	einen Wert, und der Server verwirft die meisten davon ohnehin.

	Der letzte Wert geht immer durch: sonst bliebe am Ende einer Ziehbewegung
	womoeglich ein veralteter Wert stehen.
]]
function BuildHud:pushSpeed(force: boolean?)
	if not self.onSpeedChanged then
		return
	end

	local now = os.clock()
	if not force and self.lastSpeedPush and now - self.lastSpeedPush < 1 / 15 then
		self.pendingSpeedPush = true
		return
	end

	self.lastSpeedPush = now
	self.pendingSpeedPush = false
	self.onSpeedChanged(self.speed)
end

function BuildHud:refreshSpeedDisplay()
	local range = Config.Test.maxSpeed - Config.Test.minSpeed
	local fraction = math.clamp((self.speed - Config.Test.minSpeed) / range, 0, 1)

	self.speedFill.Size = UDim2.fromScale(fraction, 1)
	self.speedKnob.Position = UDim2.fromScale(fraction, 0.5)
	self.speedValueLabel.Text = I18n.t("hud.speedValue", self.speed)

	--[[
		Die Farbe sagt, worauf man sich einlaesst: gemuetlich, zuegig oder
		schnell genug, dass das Aufsetzen wehtut.
	]]
	local color
	if fraction < 0.34 then
		color = Theme.colors.success
	elseif fraction < 0.7 then
		color = Theme.colors.accent
	else
		color = Theme.colors.warning
	end
	self.speedFill.BackgroundColor3 = color
	self.speedValueLabel.TextColor3 = color
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
		self.statusLabel.Text = I18n.t("hud.unstable")
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
		text = I18n.t("hud.testHeadline"),
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
		text = I18n.t("hud.peakLoad"),
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
		{ text = I18n.t("hud.legendLow"), color = Config.UtilisationColors.low },
		{ text = I18n.t("hud.legendMid"), color = Config.UtilisationColors.mid },
		{ text = I18n.t("hud.legendHigh"), color = Config.UtilisationColors.high },
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
		text = I18n.t("result.retry"),
		textSize = 15,
		color = Theme.colors.accent,
		textColor = Color3.fromRGB(8, 18, 34),
	})
	retry.Selectable = true
	retry.Activated:Connect(function()
		if self.resultPrimaryMode == "next" and self.onNextLevel and self.nextLevelId then
			self.onNextLevel(self.nextLevelId)
		elseif self.onRetry then
			self.onRetry()
		end
	end)
	self.retryButton = retry

	local toMenu = Theme.button(panel, "ToMenu", {
		size = UDim2.fromOffset(180, 42),
		position = UDim2.new(1, -204, 0, 146),
		text = I18n.t("hud.toLevelSelect"),
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
		text = I18n.t("hint.title"),
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
		text = I18n.t("hud.nextHint"),
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
	self:layoutRightColumn()
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

	self.hintInfoLabel.Text = I18n.t("hud.hintsRevealed", used, total)

	if used >= total then
		self.hintRevealButton.Text = I18n.t("hud.noMoreHints")
		self.hintRevealButton.Active = false
		Theme.paint(self.hintRevealButton, Theme.colors.panelLight, Theme.colors.textDim)
		return
	end

	self.hintRevealButton.Active = true

	local nextIndex = used + 1
	if nextIndex <= free then
		self.hintRevealButton.Text = I18n.t("hud.nextHintFree")
		Theme.paint(self.hintRevealButton, Theme.colors.accent, Color3.fromRGB(8, 18, 34))
	else
		self.hintRevealButton.Text = I18n.t("hint.buy", Config.Monetisation.hintPrice)
		Theme.paint(self.hintRevealButton, Theme.colors.robux, Color3.fromRGB(8, 26, 12))
	end
end

--------------------------------------------------------------------------------
-- Zustand vom Server verarbeiten
--------------------------------------------------------------------------------

function BuildHud:update(state)
	self.state = state

	-- Welches Level kaeme als naechstes? Fuer den Knopf im Ergebnisfenster.
	self.nextLevelId = nil
	for index, level in Levels.list do
		if level.id == state.levelId then
			local following = Levels.list[index + 1]
			self.nextLevelId = if following then following.id else nil
			break
		end
	end

	----------------------------------------------------------------------------
	-- Kopfzeile
	----------------------------------------------------------------------------
	-- Der Server schickt den Schluessel, uebersetzt wird hier.
	self.levelLabel.Text = I18n.t(state.levelNameKey or "")

	local info = Config.difficultyInfo(state.difficulty or 1)
	local level = state.difficulty or 1
	self.difficultyLabel.Text = string.format("%s  %s", Theme.stars(level, 5), I18n.t("difficulty." .. level))
	self.difficultyLabel.TextColor3 = info.color

	local used = state.budgetUsed or 0
	local total = math.max(state.budgetTotal or 1, 1)
	self.budgetLabel.Text = I18n.t("hud.budget", used, total)

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
	-- Nur die Baustoffe zeigen, die dieses Level anbietet
	----------------------------------------------------------------------------
	self:setAvailableMaterials(state.materials)
	self:refreshPhases(state)

	----------------------------------------------------------------------------
	-- Phase: was ist gerade sichtbar?
	----------------------------------------------------------------------------
	--[[
		Das Tempo kommt vom Server (er hat das letzte Wort). Waehrend man den
		Regler zieht, wird es NICHT ueberschrieben - sonst zappelte der Knopf
		unter dem Finger.
	]]
	if state.testSpeed and not self.draggingSpeed then
		self:setSpeed(state.testSpeed)
	end

	local building = state.phase == "Build"

	-- Vor dem Test einstellen, waehrend des Tests nachregeln - beides erlaubt.
	self.speedPanel.Visible = building or state.phase == "Test"

	self.bottomBar.Visible = building
	self.testButton.Active = building
	self.clearButton.Visible = building
	self.resetButton.Visible = state.phase ~= "Test"

	local wasVisible = self.testPanel.Visible
	self.testPanel.Visible = state.phase == "Test"
	if self.testPanel.Visible ~= wasVisible then
		self:layoutRightColumn()
	end
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
		self.testHeadline.Text = I18n.t("hud.testStartsIn", math.ceil(progress.countdown))
		self.testTimeLabel.Text = I18n.t("hud.ownWeight")
	else
		-- Bei mehreren Fahrzeugen zaehlen wir mit, wie viele schon drueben sind.
		local count = progress.vehicleCount or 1
		if count > 1 then
			self.testHeadline.Text = string.format(
				"Belastungstest - %d von %d angekommen",
				progress.vehiclesDone or 0,
				count
			)
		else
			self.testHeadline.Text = I18n.t("hud.testRunningHeadline")
		end

		self.testTimeLabel.Text = string.format(
			"%.1f s von hoechstens %.0f s  ·  %.1f Studs/s",
			progress.elapsed or 0,
			progress.timeLimit or 0,
			progress.speed or 0
		)
	end

	local utilisation = math.clamp(progress.maxUtilisation or 0, 0, 1.5)
	self.testLoadLabel.Text = string.format("%d %%", math.floor(utilisation * 100 + 0.5))
	self.testLoadFill.Size = UDim2.fromScale(math.clamp(utilisation, 0, 1), 1)
	self.testLoadFill.BackgroundColor3 = Config.utilisationColor(utilisation)
end

function BuildHud:updateResultPanel(result)
	if result.success then
		self.resultTitle.Text = I18n.t("result.success")
		self.resultTitle.TextColor3 = Theme.colors.success

		-- Nach einem Erfolg direkt weiterspielen duerfen, statt erst ins Menue.
		if self.nextLevelId then
			self.resultPrimaryMode = "next"
			self.retryButton.Text = I18n.t("result.nextLevel")
			Theme.paint(self.retryButton, Theme.colors.success, Color3.fromRGB(10, 30, 16))
		else
			self.resultPrimaryMode = "retry"
			self.retryButton.Text = I18n.t("hud.buildAgain")
			Theme.paint(self.retryButton, Theme.colors.accent, Color3.fromRGB(8, 18, 34))
		end
	else
		self.resultTitle.Text = I18n.t("hud.notPassed")
		self.resultTitle.TextColor3 = Theme.colors.danger
		self.resultPrimaryMode = "retry"
		self.retryButton.Text = I18n.t("result.retry")
		Theme.paint(self.retryButton, Theme.colors.accent, Color3.fromRGB(8, 18, 34))
	end
	self.resultReason.Text = I18n.message(result.reason)

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

function BuildHud:setSelected(key: string)
	self.selected = key

	for materialKey, button in self.materialButtons do
		local active = materialKey == key
		Theme.paint(button, if active then Theme.colors.accentDark else Theme.colors.panelLight)
	end

	Theme.paint(
		self.removeButton,
		if key == "Remove" then Theme.colors.danger else Theme.colors.panelLight
	)
end

--------------------------------------------------------------------------------
-- Groessen und Sichtbarkeit
--------------------------------------------------------------------------------

--[[
	DIE ZONEN AUSRECHNEN

	Alle Fenster bekommen ihren Platz an EINER Stelle zugewiesen. Das ist der
	eigentliche Grund, warum sich nichts mehr ueberlagern kann: es gibt keine
	zweite Stelle im Code, die ein Fenster woanders hinschiebt.

	Gerechnet wird in unskalierten Pixeln. Der UIScale darueber vergroessert
	anschliessend alles gemeinsam, deshalb muss hier nichts umgerechnet werden.
]]
function BuildHud:applyScale()
	self.scale.Scale = Device.uiScale()

	local inset = Device.edgeInset()
	local topHeight = 58
	local bottomHeight = 92
	local gap = 10

	-- Die nutzbare Flaeche in unskalierten Pixeln.
	local viewport = workspace.CurrentCamera.ViewportSize / math.max(self.scale.Scale, 0.01)

	local contentTop = inset + topHeight + gap
	local contentBottom = bottomHeight + inset + gap
	local contentHeight = math.max(viewport.Y - contentTop - contentBottom, 120)

	----------------------------------------------------------------------------
	-- Kopf und Fuss ueber die volle Breite
	----------------------------------------------------------------------------

	self.topBar.Position = UDim2.fromOffset(inset, inset)
	self.topBar.Size = UDim2.new(1, -inset * 2, 0, topHeight)

	self.bottomBar.Position = UDim2.new(0, inset, 1, -(bottomHeight + inset))
	self.bottomBar.Size = UDim2.new(1, -inset * 2, 0, bottomHeight)

	----------------------------------------------------------------------------
	-- Baustoffleiste links
	----------------------------------------------------------------------------

	--[[
		Die Leiste ist so hoch wie noetig, aber nie hoeher als der freie
		Bereich. Auf einem flachen Bildschirm wuerde sie sonst unten in die
		Fussleiste hineinragen.
	]]
	local railWidth = 168
	local railHeight = math.min(#Materials.order * 62 + 56, contentHeight)

	self.materialRail.Position = UDim2.fromOffset(inset, contentTop)
	self.materialRail.Size = UDim2.fromOffset(railWidth, railHeight)

	----------------------------------------------------------------------------
	-- Rechte Spalte
	----------------------------------------------------------------------------

	self.rightColumnX = inset
	self.rightColumnTop = contentTop
	self.rightColumnWidth = 336
	self:layoutRightColumn()

	----------------------------------------------------------------------------
	-- Tacho: unten rechts, aber LINKS neben den Knoepfen der Fussleiste
	----------------------------------------------------------------------------

	--[[
		Der Tacho bekommt, was zwischen den Phasenknoepfen und den Knoepfen
		rechts uebrig bleibt - hoechstens 296 Pixel, mindestens 170.

		Feste 296 Pixel gingen auf einem breiten Bildschirm gut auf. Auf einem
		Handy quer, in einem Level MIT Hydraulik, kamen 360 Pixel Phasen, 296
		Tacho und 272 fuer Tipp und Test zusammen - mehr, als das Geraet hat.
		Der Tacho waere unter den Phasenknoepfen gelandet.
	]]
	local buttonsRight = 388
	local phaseCount = Config.Hydraulics.phaseCount + 1
	local phaseWidth = if self.phaseBox.Visible then phaseCount * 58 + 12 else 0
	local free = viewport.X - inset * 2 - phaseWidth - buttonsRight - gap * 2
	local speedWidth = math.clamp(free, 170, 296)

	self.speedPanel.Position = UDim2.new(1, -(speedWidth + buttonsRight + inset + gap), 1, -(bottomHeight + inset - 14))
	self.speedPanel.Size = UDim2.fromOffset(speedWidth, 64)

	--[[
		Wird es trotzdem zu eng, muessen die Phasenknoepfe schrumpfen. Sie
		zeigen nur "Ein" und Ziffern, das vertraegt weniger Breite als der
		Regler, an dem man ziehen koennen muss.
	]]
	if self.phaseBox.Visible then
		local narrow = free < 170
		local step = if narrow then 42 else 58
		local width = if narrow then 38 else 52
		for phase, button in self.phaseButtons do
			button.Position = UDim2.fromOffset(phase * step, 22)
			button.Size = UDim2.fromOffset(width, 38)
		end
		self.phaseBox.Size = UDim2.fromOffset(step * phaseCount + 12, 64)
		self.phaseCaption.Visible = not narrow
	end

	----------------------------------------------------------------------------
	-- Statuszeile mittig ueber der Fussleiste
	----------------------------------------------------------------------------

	self.statusPanel.Position = UDim2.new(0.5, -230, 1, -(bottomHeight + inset + gap + 34))
end

--[[
	Testanzeige und Tipp-Fenster teilen sich die rechte Spalte.

	Es liegt immer nur eines davon oben. Sind beide offen, rueckt die
	Testanzeige unter das Tipp-Fenster - uebereinander liegen sie nie.
]]
function BuildHud:layoutRightColumn()
	local x = self.rightColumnX or 12
	local top = self.rightColumnTop or 80
	local width = self.rightColumnWidth or 336
	local gap = 10

	local y = top

	if self.hintPanel.Visible then
		self.hintPanel.Position = UDim2.new(1, -(width + x), 0, y)
		self.hintPanel.Size = UDim2.fromOffset(width, 268)
		y += 268 + gap
	end

	if self.testPanel.Visible then
		self.testPanel.Position = UDim2.new(1, -(width + x), 0, y)
		self.testPanel.Size = UDim2.fromOffset(width, 118)
	end
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
