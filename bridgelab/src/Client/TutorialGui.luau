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
local STEPS = {
	{
		title = "Willkommen bei BridgeLab",
		text = function()
			return "Du baust eine Bruecke ueber eine Luecke. Danach faehrt ein schweres "
				.. "Fahrzeug darueber. Haelt die Bruecke, hast du gewonnen.\n\n"
				.. "Diese Anleitung fuehrt dich einmal durch alles. Sie dauert etwa eine Minute."
		end,
		mode = "button",
		allowSkip = true,
	},

	{
		title = "Die Ansicht bewegen",
		text = function()
			return "Du siehst die Bruecke von der Seite, wie ein Bild.\n\n"
				.. "Zum Verschieben: "
				.. Device.actionText("pan")
				.. ".\nZum Vergroessern: "
				.. Device.actionText("zoom")
				.. ".\n\nProbier es einmal aus."
		end,
		mode = "event",
		event = "cameraMoved",
		allowSkip = true,
	},

	{
		title = "Ein Bauteil auswaehlen",
		text = function()
			return "Unten stehen deine Bauteile.\n\n"
				.. "Der BALKEN ist das wichtigste: nur auf ihm kann das Fahrzeug fahren. "
				.. "Er kostet 10 Einheiten.\n\nWaehle jetzt den Balken aus."
		end,
		mode = "event",
		event = "partSelected",
		check = function(payload)
			return payload == "Beam"
		end,
		highlight = "Part_Beam",
	},

	{
		title = "Den ersten Punkt setzen",
		text = function()
			return "Die leuchtenden Kugeln sind Ankerpunkte. Zwischen zwei davon entsteht ein Bauteil.\n\n"
				.. "Orange = fest im Boden verankert.\nBlau = beweglich, haengt an deiner Konstruktion.\n\n"
				.. "Fuehre "
				.. Device.actionText("pointer")
				.. " auf einen Ankerpunkt und "
				.. Device.actionText("select")
				.. "."
		end,
		mode = "event",
		event = "firstSnapChosen",
	},

	{
		title = "Den zweiten Punkt setzen",
		text = function()
			return "Gut. Jetzt siehst du eine Vorschaulinie.\n\n"
				.. "Gruen heisst: so darf gebaut werden. Rot heisst: zu lang, zu kurz oder nicht erlaubt.\n\n"
				.. "Waehle einen zweiten Ankerpunkt, dann entsteht das Bauteil."
		end,
		mode = "event",
		event = "memberPlaced",
	},

	{
		title = "Budget und Farben",
		text = function()
			return "Oben siehst du dein Budget. Jedes Bauteil kostet - ist das Budget leer, geht nichts mehr.\n\n"
				.. "Die Bauteile faerben sich nach ihrer Belastung:\n"
				.. "GRUEN = viel Reserve\nGELB = wird eng\nROT = kurz vor dem Bruch\n\n"
				.. "Falsch gebaut? Mit "
				.. Device.actionText("remove")
				.. " kannst du es wieder entfernen. Das Geld bekommst du zurueck."
		end,
		mode = "button",
	},

	{
		title = "Wenn du nicht weiterkommst",
		text = function()
			return "Unten rechts gibt es den Knopf TIPP.\n\n"
				.. "In den leichten Levels ist der erste Tipp gratis, jeder weitere kostet Robux.\n"
				.. "In den schweren Levels kostet schon der erste Tipp Robux.\n\n"
				.. "Du brauchst nie einen Tipp zu kaufen - jedes Level ist auch ohne loesbar."
		end,
		mode = "button",
		highlight = "HintButton",
	},

	{
		title = "Der Belastungstest",
		text = function()
			return "Wenn du fertig bist, druecke TEST STARTEN.\n\n"
				.. "Der Test laeuft absichtlich langsam ab. Ueber jedem Bauteil siehst du dabei, "
				.. "wie stark es gerade belastet ist - in Prozent und in Newton.\n\n"
				.. "Starte jetzt einen Test. Es macht nichts, wenn die Bruecke noch nicht haelt."
		end,
		mode = "event",
		event = "testStarted",
		highlight = "TestButton",
		allowSkip = true,
	},

	{
		title = "Das war alles",
		text = function()
			return "Du kennst jetzt alles Wichtige.\n\n"
				.. "Bricht ein Bauteil, war es ueberlastet - baue an dieser Stelle ein zweites "
				.. "daneben oder stuetze sie ab.\n\n"
				.. "Dreiecke sind stabil, Vierecke kippen um. Das ist der wichtigste Satz "
				.. "im ganzen Brueckenbau.\n\nViel Erfolg!"
		end,
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
		text = "Weiter",
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
		text = "Ueberspringen",
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
	self.titleLabel.Text = step.title
	self.textLabel.Text = step.text()

	self:setHighlight(step.highlight)

	if step.mode == "button" then
		self.nextButton.Visible = true
		self.waitLabel.Text = ""
		if self.stepIndex >= #STEPS then
			self.nextButton.Text = "Los geht's"
		else
			self.nextButton.Text = "Weiter"
		end
		if Device.isGamepad() then
			GuiService.SelectedObject = self.nextButton
		end
	else
		-- Auf eine echte Aktion warten: kein Weiter-Knopf.
		self.nextButton.Visible = false
		self.waitLabel.Text = "▸ Probiere es aus, dann geht es weiter"
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
	self.scale.Scale = Device.uiScale()

	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local effectiveWidth = viewport.X / math.max(self.scale.Scale, 0.1)
	local effectiveHeight = viewport.Y / math.max(self.scale.Scale, 0.1)

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
