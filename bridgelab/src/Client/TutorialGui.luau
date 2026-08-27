--[[
	TutorialGui
	-----------
	Die interaktive Anleitung beim ersten Spielstart.

	WIE SIE AUFGEBAUT IST
	Die Anleitung besteht aus Schritten. Jeder Schritt hat einen Text und eine
	Bedingung, wann er als erledigt gilt:

	  "button"  Der Spieler liest etwas und drueckt auf "Weiter".
	  "event"   Der Spieler muss wirklich etwas TUN. Das Hauptskript meldet
	            das Ereignis ueber notify() hierher, und der Schritt geht
	            von selbst weiter.

	Deshalb ist sie "interaktiv": man liest nicht nur, man baut den ersten
	Balken tatsaechlich selbst.

	GERAETEABHAENGIGKEIT
	Die Texte fragen bei Device.actionText() nach, wie eine Aktion auf dem
	gerade benutzten Geraet heisst. Am PC steht dann "klicke mit der linken
	Maustaste", auf dem Handy "tippe kurz", am Controller "druecke A".
	Wechselt das Geraet mitten im Spiel, wird der Text sofort neu geschrieben.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local I18n = require(Shared.I18n)

local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)

local TutorialGui = {}
TutorialGui.__index = TutorialGui

--------------------------------------------------------------------------------
-- Die Schritte
--------------------------------------------------------------------------------

--[[
	Jeder Schritt:
	  title      Ueberschrift
	  text       Funktion, die den Text liefert (damit er geraeteabhaengig ist)
	  mode       "button" oder "event"
	  event      bei mode = "event": auf welches Ereignis gewartet wird
	  check      optionale Zusatzpruefung fuer das Ereignis
	  highlight  Name des Bedienelements, das hervorgehoben werden soll
	  allowSkip  true = "Ueberspringen"-Knopf anzeigen
]]
--[[
	Die Texte stehen in I18n.luau, hier stehen nur die SCHLUESSEL. Dadurch
	laesst sich die Anleitung uebersetzen, ohne diese Datei anzufassen - und
	die Reihenfolge der Schritte bleibt auf einen Blick lesbar.

	"args" ist eine Funktion, die die Werte fuer die Platzhalter liefert.
	Sie wird erst beim Anzeigen aufgerufen, weil die Bedientexte vom GERAET
	abhaengen und sich mitten im Spiel aendern koennen.
]]
local STEPS = {
	{
		key = "tut.welcome",
		mode = "button",
		allowSkip = true,
	},

	{
		key = "tut.camera",
		args = function()
			return Device.actionText("pan"), Device.actionText("zoom")
		end,
		mode = "event",
		event = "cameraMoved",
		allowSkip = true,
	},

	{
		key = "tut.material",
		mode = "event",
		event = "materialSelected",
		check = function(payload)
			return payload == "Road"
		end,
		highlight = "Material_Road",
	},

	{
		key = "tut.drag",
		args = function()
			return Device.actionText("dragStart")
		end,
		mode = "event",
		event = "dragStarted",
	},

	{
		key = "tut.place",
		mode = "event",
		event = "memberPlaced",
	},

	{
		key = "tut.budget",
		args = function()
			return Device.actionText("remove")
		end,
		mode = "button",
	},

	{
		key = "tut.blueprint",
		mode = "event",
		event = "blueprintShown",
		highlight = "BlueprintButton",
		allowSkip = true,
	},

	{
		key = "tut.hint",
		mode = "button",
		highlight = "HintButton",
	},

	{
		key = "tut.speed",
		mode = "button",
		highlight = "SpeedPanel",
	},

	{
		key = "tut.test",
		mode = "event",
		event = "testStarted",
		highlight = "TestButton",
		allowSkip = true,
	},

	{
		key = "tut.done",
		mode = "button",
	},
}

--------------------------------------------------------------------------------

function TutorialGui.new()
	local self = setmetatable({}, TutorialGui)

	self.player = Players.LocalPlayer
	self.stepIndex = 0
	self.active = false
	self.highlightTarget = nil

	self.onFinished = nil -- wird aufgerufen, wenn die Anleitung durch ist
	self.hud = nil -- wird von aussen gesetzt: zum Hervorheben der Knoepfe

	self:build()

	-- Bei Geraetewechsel den Text neu schreiben.
	Device.changed(function()
		if self.active then
			self:renderStep()
		end
		self:applyScale()
	end)

	return self
end

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

function TutorialGui:build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BridgeLabTutorial"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 20
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

	----------------------------------------------------------------------------
	-- Rahmen, der ein Bedienelement hervorhebt
	----------------------------------------------------------------------------

	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundTransparency = 1
	highlight.BorderSizePixel = 0
	highlight.Visible = false
	highlight.ZIndex = 2
	highlight.Parent = root
	Theme.corner(highlight, 10)

	local highlightStroke = Instance.new("UIStroke")
	highlightStroke.Color = Theme.colors.accent
	highlightStroke.Thickness = 3
	highlightStroke.Parent = highlight
	self.highlight = highlight
	self.highlightStroke = highlightStroke

	----------------------------------------------------------------------------
	-- Das Anleitungsfenster
	----------------------------------------------------------------------------

	local panel = Theme.panel(root, "Panel")
	panel.Size = UDim2.fromOffset(400, 300)
	panel.BackgroundTransparency = 0.02
	panel.ZIndex = 3
	self.panel = panel

	self.stepLabel = Theme.label(panel, "StepNumber", {
		size = UDim2.new(1, -32, 0, 16),
		position = UDim2.fromOffset(18, 14),
		text = "",
		textSize = 12,
		color = Theme.colors.accent,
		bold = true,
	})

	self.titleLabel = Theme.label(panel, "Title", {
		size = UDim2.new(1, -32, 0, 26),
		position = UDim2.fromOffset(18, 32),
		text = "",
		textSize = 20,
		bold = true,
	})

	self.textLabel = Theme.label(panel, "Text", {
		size = UDim2.new(1, -36, 1, -132),
		position = UDim2.fromOffset(18, 62),
		text = "",
		textSize = 14,
		color = Theme.colors.text,
		wrapped = true,
		alignY = Enum.TextYAlignment.Top,
	})

	-- Hinweis, wenn auf eine Aktion gewartet wird
	self.waitLabel = Theme.label(panel, "Wait", {
		size = UDim2.new(1, -36, 0, 18),
		position = UDim2.new(0, 18, 1, -68),
		text = "",
		textSize = 12,
		color = Theme.colors.warning,
		bold = true,
	})

	local nextButton = Theme.button(panel, "Next", {
		size = UDim2.fromOffset(150, 40),
		position = UDim2.new(1, -168, 1, -54),
		text = I18n.t("common.continue"),
		textSize = 15,
		color = Theme.colors.accent,
		textColor = Color3.fromRGB(8, 18, 34),
	})
	nextButton.Selectable = true
	nextButton.Activated:Connect(function()
		self:advance()
	end)
	self.nextButton = nextButton

	local skipButton = Theme.button(panel, "Skip", {
		size = UDim2.fromOffset(140, 40),
		position = UDim2.new(0, 18, 1, -54),
		text = I18n.t("common.skip"),
		textSize = 13,
		color = Theme.colors.panelLight,
		textColor = Theme.colors.textDim,
	})
	skipButton.Selectable = true
	skipButton.Activated:Connect(function()
		self:finish()
	end)
	self.skipButton = skipButton

	----------------------------------------------------------------------------
	-- Den Hervorhebungsrahmen jeden Frame nachfuehren
	----------------------------------------------------------------------------

	self.renderConnection = RunService.RenderStepped:Connect(function()
		self:updateHighlight()
	end)

	self:applyScale()
end

--------------------------------------------------------------------------------
-- Hervorhebung
--------------------------------------------------------------------------------

--[[
	Sucht im HUD nach einem Bedienelement mit dem angegebenen Namen und legt
	einen leuchtenden Rahmen darum. Beide Oberflaechen haben IgnoreGuiInset
	auf false, deshalb passen ihre Koordinaten zusammen.
]]
function TutorialGui:setHighlight(name: string?)
	self.highlightTarget = nil
	self.highlight.Visible = false

	if not name or not self.hud then
		return
	end

	local found = self.hud.root:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		self.highlightTarget = found
	end
end

function TutorialGui:updateHighlight()
	local target = self.highlightTarget
	if not target or not target.Parent or not target.Visible then
		self.highlight.Visible = false
		return
	end

	local rootPosition = self.root.AbsolutePosition
	local padding = 6

	self.highlight.Visible = true
	self.highlight.Position = UDim2.fromOffset(
		target.AbsolutePosition.X - rootPosition.X - padding,
		target.AbsolutePosition.Y - rootPosition.Y - padding
	)
	self.highlight.Size = UDim2.fromOffset(
		target.AbsoluteSize.X + padding * 2,
		target.AbsoluteSize.Y + padding * 2
	)

	-- Der Rahmen pulsiert leicht, damit er auffaellt.
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
	self.highlightStroke.Transparency = 0.15 + pulse * 0.45
end

--------------------------------------------------------------------------------
-- Ablauf
--------------------------------------------------------------------------------

function TutorialGui:start()
	self.active = true
	self.stepIndex = 1
	self.gui.Enabled = true
	self:applyScale()
	self:renderStep()
end

function TutorialGui:stop()
	self.active = false
	self.gui.Enabled = false
	self:setHighlight(nil)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject = nil
	end
end

function TutorialGui:finish()
	if not self.active then
		return
	end
	self:stop()
	if self.onFinished then
		self.onFinished()
	end
end

function TutorialGui:advance()
	if not self.active then
		return
	end
	if self.stepIndex >= #STEPS then
		self:finish()
		return
	end
	self.stepIndex += 1
	self:renderStep()
end

function TutorialGui:currentStep()
	return STEPS[self.stepIndex]
end

function TutorialGui:renderStep()
	local step = self:currentStep()
	if not step then
		return
	end

	self.stepLabel.Text = string.format("Schritt %d von %d", self.stepIndex, #STEPS)
	--[[
		Uebersetzt wird erst hier, beim Anzeigen. Die Werte fuer die
		Platzhalter liefert step.args - sie haengen vom Geraet ab und koennen
		sich mitten im Spiel aendern, wenn jemand von Maus auf Touch wechselt.
	]]
	self.titleLabel.Text = I18n.t(step.key .. ".title")
	if step.args then
		self.textLabel.Text = I18n.t(step.key .. ".text", step.args())
	else
		self.textLabel.Text = I18n.t(step.key .. ".text")
	end

	self:setHighlight(step.highlight)

	if step.mode == "button" then
		self.nextButton.Visible = true
		self.waitLabel.Text = ""
		if self.stepIndex >= #STEPS then
			self.nextButton.Text = I18n.t("tut.start")
		else
			self.nextButton.Text = I18n.t("common.continue")
		end
		if Device.isGamepad() then
			GuiService.SelectedObject = self.nextButton
		end
	else
		-- Auf eine echte Aktion warten: kein Weiter-Knopf.
		self.nextButton.Visible = false
		self.waitLabel.Text = I18n.t("tut.tryIt")
	end

	self.skipButton.Visible = step.allowSkip == true or step.mode == "event"
end

--[[
	Wird vom Hauptskript aufgerufen, wenn der Spieler etwas getan hat.
	Passt das Ereignis zum aktuellen Schritt, geht die Anleitung weiter.
]]
function TutorialGui:notify(event: string, payload: any?)
	if not self.active then
		return
	end
	local step = self:currentStep()
	if not step or step.mode ~= "event" or step.event ~= event then
		return
	end
	if step.check and not step.check(payload) then
		return
	end

	-- Kurz warten, damit der Spieler das Ergebnis seiner Aktion noch sieht.
	task.delay(0.45, function()
		if self.active and self:currentStep() == step then
			self:advance()
		end
	end)
end

function TutorialGui:isActive(): boolean
	return self.active
end

--------------------------------------------------------------------------------
-- Groesse und Lage
--------------------------------------------------------------------------------

function TutorialGui:applyScale()
	local factor = Device.uiScale()
	self.scale.Scale = factor

	--[[
		Die Wurzel wird um den Kehrwert groesser gemacht, weil ein UIScale
		auch die POSITIONEN seiner Kinder mitskaliert. Ohne das laege eine
		Angabe wie "am unteren Bildrand" nicht am Bildrand, sondern bei 70
		Prozent der Hoehe - das Fenster sitzt dann mitten im Bild statt dort,
		wo es hingehoert.
	]]
	self.root.Size = UDim2.fromScale(1 / factor, 1 / factor)

	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local effectiveWidth = viewport.X / math.max(factor, 0.1)
	local effectiveHeight = viewport.Y / math.max(factor, 0.1)

	--[[
		Wohin mit dem Fenster? Es darf die Fussleiste nicht verdecken, denn
		genau dort soll der Spieler ja klicken. Auf breiten Bildschirmen steht
		es deshalb links, auf schmalen oben.
	]]
	if effectiveWidth < 820 then
		self.panel.Size = UDim2.fromOffset(math.min(effectiveWidth - 32, 420), 280)
		self.panel.Position = UDim2.fromOffset(16, 78)
	else
		self.panel.Size = UDim2.fromOffset(400, math.min(320, effectiveHeight - 220))
		self.panel.Position = UDim2.fromOffset(Device.edgeInset(), 84)
	end
end

return TutorialGui
