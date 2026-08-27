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
local I18n = require(Shared.I18n)

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
	self.onSchool = nil
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

	--[[
		DER HINTERGRUND WIRD NIE MITSKALIERT

		Hier lag ein Fehler: der UIScale hing frueher am Hintergrund selbst.
		Auf einem Fenster schmaler als 1280 Pixel liefert Device.uiScale()
		einen Wert unter 1 - und damit schrumpfte die Hintergrundflaeche auf
		bis zu 70 Prozent. Rundherum sah man dann die 3D-Welt mit der
		Spawn-Stelle und verschwommenem Zeug drumherum.

		Der Hintergrund fuellt jetzt IMMER den ganzen Bildschirm. Skaliert
		wird nur der Inhalt darin - und dessen Groesse wird gegengerechnet
		(siehe applyScale), damit er nach dem Skalieren wieder genau passt.
	]]
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

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.Parent = backdrop
	self.content = content

	local scale = Instance.new("UIScale")
	scale.Parent = content
	self.scale = scale

	----------------------------------------------------------------------------
	-- Kopfzeile
	----------------------------------------------------------------------------

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 112)
	header.BackgroundTransparency = 1
	header.Parent = content
	self.header = header

	local title = Theme.label(header, "Title", {
		size = UDim2.new(1, -48, 0, 46),
		position = UDim2.fromOffset(28, 22),
		text = I18n.t("app.title"),
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
		text = I18n.t("app.subtitle"),
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
	--[[
		Die Bauschule steht NEBEN der Anleitung, nicht darin. Beide erklaeren
		etwas anderes: die Anleitung die Bedienung, die Bauschule die Statik.
		Wer schon bedienen kann, aber nicht weiterkommt, braucht genau das
		zweite - und muesste sonst die ganze Anleitung noch einmal ansehen.
	]]
	local schoolButton = Theme.button(header, "SchoolButton", {
		size = UDim2.fromOffset(150, 34),
		position = UDim2.new(1, -324, 0, 26),
		text = I18n.t("school.open"),
		textSize = 13,
		color = Theme.colors.panelLight,
	})
	schoolButton.Selectable = true
	schoolButton.Activated:Connect(function()
		if self.onSchool then
			self.onSchool()
		end
	end)
	self.schoolButton = schoolButton

	local tutorialButton = Theme.button(header, "TutorialButton", {
		size = UDim2.fromOffset(210, 38),
		position = UDim2.new(1, -238, 0, 62),
		text = I18n.t("menu.howTo"),
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
	list.Parent = content
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
	box.Position = UDim2.fromOffset(16, 14)
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

	local profile = summary.terrain
	local bounds = summary.bounds
	if not profile or not bounds then
		return box
	end

	----------------------------------------------------------------------------
	-- Massstab
	----------------------------------------------------------------------------

	--[[
		Das Level wird so in die Karte gelegt, dass es waagerecht ganz
		hineinpasst. Senkrecht wird derselbe Massstab verwendet, aber
		gedeckelt: eine tiefe Schlucht wuerde die Karte sonst so weit
		zusammenstauchen, dass man von der Landschaft nichts mehr erkennt.
	]]
	local levelWidth = math.max(bounds.maxX - bounds.minX, 1)
	local levelHeight = math.max(bounds.maxY - bounds.minY, 1)

	local scaleX = 1 / levelWidth
	local scaleY = math.min(1 / levelHeight, scaleX * 1.6)

	-- Wo liegt die Oberkante des Bildes in Levelkoordinaten?
	local topY = bounds.maxY + 8

	local function toBoxY(y: number): number
		return (topY - y) * scaleY
	end

	----------------------------------------------------------------------------
	-- Gelaende als Silhouette
	----------------------------------------------------------------------------

	--[[
		Das Profil wird in senkrechte Streifen zerlegt. Jeder Streifen reicht
		von der Gelaendehoehe an dieser Stelle bis zum unteren Bildrand.
		Aus vierzig schmalen Streifen wird eine erstaunlich saubere Silhouette
		- und die stimmt mit dem echten Level ueberein, weil sie aus denselben
		Daten kommt wie die Welt selbst.
	]]
	local STRIPES = 44

	local function heightAt(x: number): number
		local best = profile[1].y
		for i = 1, #profile - 1 do
			local a, b = profile[i], profile[i + 1]
			if math.abs(b.x - a.x) > 1e-6 then
				local lo, hi = a, b
				if lo.x > hi.x then
					lo, hi = b, a
				end
				if x >= lo.x and x <= hi.x then
					local y = lo.y + (hi.y - lo.y) * ((x - lo.x) / (hi.x - lo.x))
					if y > best then
						best = y
					end
				end
			end
		end
		if x <= profile[1].x then
			return profile[1].y
		end
		if x >= profile[#profile].x then
			return profile[#profile].y
		end
		return best
	end

	-- Wasser zuerst, damit das Gelaende davor liegt.
	if summary.waterY then
		local water = Instance.new("Frame")
		water.Name = "Wasser"
		water.Size = UDim2.new(1, 0, 1, 0)
		water.Position = UDim2.fromScale(0, toBoxY(summary.waterY))
		water.BackgroundColor3 = Color3.fromRGB(56, 116, 152)
		water.BorderSizePixel = 0
		water.ZIndex = 2
		water.Parent = box
	end

	for i = 0, STRIPES - 1 do
		local x = bounds.minX + levelWidth * ((i + 0.5) / STRIPES)
		local top = toBoxY(heightAt(x))

		local rock = Instance.new("Frame")
		rock.Name = "Fels"
		-- Etwas Ueberlappung, damit zwischen den Streifen keine Fugen stehen.
		rock.Size = UDim2.new(1 / STRIPES + 0.004, 0, 1, 0)
		rock.Position = UDim2.new(i / STRIPES, 0, top, 0)
		rock.BackgroundColor3 = Color3.fromRGB(92, 90, 86)
		rock.BorderSizePixel = 0
		rock.ZIndex = 3
		rock.Parent = box

		local grass = Instance.new("Frame")
		grass.Name = "Gras"
		grass.Size = UDim2.new(1, 0, 0, 3)
		grass.BackgroundColor3 = Color3.fromRGB(104, 138, 84)
		grass.BorderSizePixel = 0
		grass.ZIndex = 4
		grass.Parent = rock
	end

	----------------------------------------------------------------------------
	-- Anker als goldene Punkte
	----------------------------------------------------------------------------

	--[[
		Die Anker sind die eigentliche Aufgabe eines Levels: je weniger und je
		weiter auseinander, desto schwerer. Deshalb stehen sie auch schon auf
		der Karte - man sieht der Vorschau damit an, worum es gehen wird.
	]]
	for _, anchor in summary.anchors do
		local dot = Instance.new("Frame")
		dot.Name = "Anker"
		dot.Size = UDim2.fromOffset(4, 4)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale((anchor.x - bounds.minX) * scaleX, toBoxY(anchor.y))
		dot.BackgroundColor3 = Color3.fromRGB(228, 178, 76)
		dot.BorderSizePixel = 0
		dot.ZIndex = 6
		dot.Parent = box
		Theme.corner(dot, 2)
	end

	----------------------------------------------------------------------------
	-- Besondere Kennzeichen
	----------------------------------------------------------------------------

	local badge = nil
	if summary.requiresJump then
		badge = "Sprung"
	elseif summary.hasBoat then
		badge = "Schiff"
	elseif summary.vehicleCount > 1 then
		badge = tostring(summary.vehicleCount) .. " Fahrzeuge"
	end

	if badge then
		local tag = Instance.new("TextLabel")
		tag.Name = "Kennzeichen"
		tag.Size = UDim2.new(1, -8, 0, 12)
		tag.Position = UDim2.fromOffset(4, 4)
		tag.BackgroundTransparency = 1
		tag.Font = Enum.Font.GothamBold
		tag.TextSize = 10
		tag.TextColor3 = Color3.fromRGB(236, 226, 200)
		tag.TextXAlignment = Enum.TextXAlignment.Right
		tag.Text = badge
		tag.ZIndex = 7
		tag.Parent = box
	end

	return box
end


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

	--[[
		Ein farbiger Streifen am linken Rand in der Farbe der Welt. Zwoelf
		gleich aussehende Karten untereinander lasen sich wie eine Tabelle;
		mit dem Streifen sieht man sofort, wo eine neue Welt anfaengt.
	]]
	local worldColor = Theme.worldColor(summary.world)

	local band = Instance.new("Frame")
	band.Name = "Weltstreifen"
	band.Size = UDim2.new(0, 5, 1, -20)
	band.Position = UDim2.fromOffset(4, 10)
	band.BackgroundColor3 = worldColor
	band.BorderSizePixel = 0
	band.Parent = card
	Theme.corner(band, 3)

	createPreview(card, summary)

	-- Welt und Nummer, klein ueber dem Namen
	Theme.label(card, "Number", {
		size = UDim2.new(1, -160, 0, 14),
		position = UDim2.fromOffset(142, 16),
		text = I18n.t("menu.levelNumber", string.upper(I18n.t("world." .. (summary.world or ""))), summary.order),
		textSize = 11,
		bold = true,
		color = worldColor,
	})

	Theme.label(card, "Name", {
		size = UDim2.new(1, -160, 0, 26),
		position = UDim2.fromOffset(142, 30),
		text = I18n.t(summary.nameKey),
		textSize = 20,
		bold = true,
	})

	Theme.label(card, "Subtitle", {
		size = UDim2.new(1, -166, 0, 32),
		position = UDim2.fromOffset(142, 55),
		text = I18n.t(summary.subtitleKey),
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
		text = I18n.t("difficulty." .. math.clamp(summary.difficulty, 1, 5)),
		textSize = 11,
		bold = true,
		color = info.color,
		align = Enum.TextXAlignment.Right,
	})

	----------------------------------------------------------------------------
	-- Eckdaten als Felder unten
	----------------------------------------------------------------------------

	local x = 142
	chip(card, "Budget", I18n.t("menu.budget", summary.budget), x, Theme.colors.text)
	x += 92
	chip(card, "Span", I18n.t("common.studs", summary.span), x, Theme.colors.text)
	x += 78

	--[[
		Die Zahl der Anker sagt mehr ueber die Schwierigkeit als jede andere
		Angabe: mit zwei Ankern muss die ganze Spannweite frei getragen
		werden, mit vieren gibt es Pfeiler oder Vorspruenge zum Abstuetzen.
	]]
	chip(card, "Anchors", I18n.t("menu.anchors", summary.anchorCount), x, Theme.colors.text)
	x += 76

	-- Besonderheiten deutlich hervorheben
	if summary.requiresJump then
		chip(card, "Jump", I18n.t("menu.badge.jump"), x, Theme.colors.warning)
		x += 72
	elseif summary.hasBoat then
		chip(card, "Boat", I18n.t("menu.badge.boatLong"), x, Theme.colors.warning)
		x += 116
	elseif summary.hasHydraulics then
		chip(card, "Hydraulics", I18n.t("menu.badge.hydraulics"), x, Theme.colors.warning)
		x += 84
	elseif summary.vehicleCount > 1 then
		chip(card, "Traffic", I18n.t("menu.badge.vehicles", summary.vehicleCount), x, Theme.colors.warning)
		x += 100
	end

	if summary.freeHints > 0 then
		chip(card, "Hints", I18n.t("menu.freeHint"), x, Theme.colors.textDim)
	else
		chip(card, "Hints", I18n.t("menu.paidHints"), x, Theme.colors.robux)
	end

	----------------------------------------------------------------------------
	-- Haken auf der Vorschau, wenn geschafft
	----------------------------------------------------------------------------

	--[[
		Der Haken sitzt ueber der Vorschau statt in der Zeile mit den Feldern.
		Dort waere er bei langen Beschriftungen frueher oder spaeter im Weg -
		die Karte ist auf schmalen Bildschirmen nicht sehr breit.
	]]
	local done = Instance.new("Frame")
	done.Name = "Done"
	done.Size = UDim2.fromOffset(116, 24)
	done.Position = UDim2.fromOffset(14, 68)
	done.BackgroundColor3 = Theme.colors.success
	done.BorderSizePixel = 0
	done.Visible = false
	done.ZIndex = 3
	done.Parent = card
	Theme.corner(done, 6)

	Theme.label(done, "Text", {
		size = UDim2.fromScale(1, 1),
		text = "✓ " .. I18n.t("menu.done"),
		textSize = 13,
		bold = true,
		color = Color3.fromRGB(10, 34, 18),
		align = Enum.TextXAlignment.Center,
	}).ZIndex = 4

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
	local factor = Device.uiScale()
	self.scale.Scale = factor

	--[[
		Der Inhalt wird um den Kehrwert groesser gemacht, bevor er skaliert
		wird. Nach dem Skalieren fuellt er damit wieder genau den Bildschirm.

		Ohne diese Gegenrechnung endete der Inhalt bei einem Massstab von 0,7
		nach 70 Prozent der Breite, und rechts sowie unten klaffte eine Luecke.
	]]
	self.content.Size = UDim2.fromScale(1 / factor, 1 / factor)

	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	local effectiveWidth = width / math.max(factor, 0.1)

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
