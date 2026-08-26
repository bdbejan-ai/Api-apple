--[[
	BridgeLabClient (Hauptskript des Clients)
	-----------------------------------------
	Verbindet alle Teile der Spieleroberflaeche miteinander:

	  LevelSelectGui   das Startmenue mit der Levelauswahl
	  BuildHud         die Oberflaeche waehrend des Spiels
	  TutorialGui      die interaktive Anleitung
	  CameraController die feste Seitenansicht
	  BuildController  die Bau-Interaktion fuer Maus, Touch und Gamepad

	GRUNDREGEL
	Der Client trifft keine Entscheidungen ueber das Spielgeschehen. Er zeigt
	nur an, was der Server meldet, und schickt Wuensche dorthin. Ob ein
	Bauteil entsteht, ob ein Tipp freigeschaltet wird, ob der Test bestanden
	ist - das entscheidet ausschliesslich der Server.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local I18n = require(Shared.I18n)

local Device = require(script.Device)
local Theme = require(script.Theme)
local CameraController = require(script.CameraController)
local BuildController = require(script.BuildController)
local LevelSelectGui = require(script.LevelSelectGui)
local BuildHud = require(script.BuildHud)
local TutorialGui = require(script.TutorialGui)

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Sprache bestimmen
--------------------------------------------------------------------------------

--[[
	Roblox sagt uns, welche Sprache der Spieler eingestellt hat - etwa "de-de"
	oder "pt-br". Kennen wir sie, wird sie genommen; sonst Englisch, weil damit
	die meisten wenigstens zurechtkommen.

	Das passiert ganz am Anfang, VOR dem Aufbau der Fenster: die bauen ihre
	Beschriftungen beim Erzeugen ein, und was einmal drinsteht, wird nicht
	nachtraeglich uebersetzt.
]]
local function detectLanguage()
	--[[
		Zwei Quellen, weil sie nicht immer dasselbe sagen: LocaleId ist die
		Spracheinstellung des KONTOS, RobloxLocaleId die der App. Die des
		Kontos passt besser zu dem, was der Spieler lesen moechte.

		Beides in pcall, weil beides je nach Roblox-Version fehlen kann - und
		eine fehlende Sprachangabe darf das Spiel nicht am Starten hindern.
	]]
	local ok, locale = pcall(function()
		return player.LocaleId
	end)
	if ok and type(locale) == "string" and locale ~= "" then
		I18n.setLanguage(locale)
		return
	end

	local okService, serviceLocale = pcall(function()
		return game:GetService("LocalizationService").RobloxLocaleId
	end)
	if okService then
		I18n.setLanguage(serviceLocale)
	end
end

detectLanguage()
print(string.format("[BridgeLab] Sprache: %s", I18n.language()))

--------------------------------------------------------------------------------
-- Notfallmeldung, falls der Server nicht antwortet
--------------------------------------------------------------------------------

--[[
	Zeigt einen gut sichtbaren Hinweis auf dem Bildschirm. Wird nur gebraucht,
	wenn etwas so grundlegend schiefgeht, dass das Spiel gar nicht erst
	starten kann - ohne das saehe der Spieler nur einen leeren Bildschirm und
	wuesste nicht, woran es liegt.
]]
local function showStartupError(headline: string, detail: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BridgeLabStartupError"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(560, 190)
	panel.Position = UDim2.new(0.5, -280, 0.5, -95)
	panel.BackgroundColor3 = Theme.colors.panel
	panel.BorderSizePixel = 0
	panel.Parent = gui
	Theme.corner(panel, 10)
	Theme.stroke(panel, Theme.colors.danger, 2)

	Theme.label(panel, "Headline", {
		size = UDim2.new(1, -40, 0, 30),
		position = UDim2.fromOffset(20, 20),
		text = headline,
		textSize = 20,
		bold = true,
		color = Theme.colors.danger,
	})

	Theme.label(panel, "Detail", {
		size = UDim2.new(1, -40, 1, -70),
		position = UDim2.fromOffset(20, 56),
		text = detail,
		textSize = 14,
		color = Theme.colors.text,
		wrapped = true,
		alignY = Enum.TextYAlignment.Top,
	})
end

--------------------------------------------------------------------------------
-- Alle RemoteEvents holen: remote.PlaceMember usw.
--------------------------------------------------------------------------------

local remote = {}
local missingRemote = nil

for _, name in Config.RemoteNames do
	local event = Remotes.get(name, 10)
	if not event then
		missingRemote = name
		break
	end
	remote[name] = event
end

if missingRemote then
	--[[
		Kommt praktisch nur vor, wenn das SERVERSKRIPT abgestuerzt ist. Dann
		wurden die RemoteEvents nie angelegt. Die Ursache steht dann als roter
		Fehler im Output-Fenster - und zwar die ERSTE rote Zeile, nicht diese.
	]]
	warn("[BridgeLab] RemoteEvent '" .. missingRemote .. "' kam nicht an. Laeuft das Serverskript?")
	showStartupError(
		"Der Server antwortet nicht",
		"BridgeLab konnte nicht starten: das RemoteEvent '"
			.. missingRemote
			.. "' ist nicht angekommen.\n\n"
			.. "Das heisst fast immer, dass das Serverskript einen Fehler hatte. "
			.. "Oeffne in Studio VIEW -> Output und sieh dir die ERSTE rote Zeile an - "
			.. "dort steht die eigentliche Ursache."
	)
	return
end

--------------------------------------------------------------------------------
-- Zustand des Clients
--------------------------------------------------------------------------------

local app = {
	screen = "Menu", -- "Menu" | "Playing"
	profile = nil,
	state = nil,
	arenaFolder = nil,
	pendingHintPurchase = false,
	tutorialOffered = false,
}

--------------------------------------------------------------------------------
-- Bausteine anlegen
--------------------------------------------------------------------------------

local camera = CameraController.new()
local controller = BuildController.new()
local levelSelect = LevelSelectGui.new()
local hud = BuildHud.new()
local tutorial = TutorialGui.new()

-- Die Anleitung darf Knoepfe im HUD hervorheben.
tutorial.hud = hud

--------------------------------------------------------------------------------
-- Die eigene Arena in der Welt finden
--------------------------------------------------------------------------------

--[[
	Der Server baut fuer jeden Spieler einen eigenen Ordner. Er traegt als
	Attribut die UserId seines Besitzers - danach suchen wir. Ueber den Namen
	zu gehen waere unsicher, denn Namen koennen sich aehneln.

	Die Welt wird vom Server zum Client uebertragen, das dauert einen Moment.
	Deshalb versuchen wir es mehrmals.
]]
local function findArenaFolder(): Instance?
	local root = workspace:FindFirstChild("BridgeLab")
	if not root then
		return nil
	end
	local arenas = root:FindFirstChild("Arenas")
	if not arenas then
		return nil
	end
	for _, folder in arenas:GetChildren() do
		if folder:GetAttribute("OwnerUserId") == player.UserId then
			return folder
		end
	end
	return nil
end

local function waitForArenaFolder(): Instance?
	for _ = 1, 60 do
		local folder = findArenaFolder()
		-- "Bauteile" ist der Ordner, den der LevelBuilder zuletzt anlegt:
		-- ist er da, ist die Arena vollstaendig uebertragen.
		if folder and folder:FindFirstChild("Bauteile") then
			return folder
		end
		task.wait(0.1)
	end
	return nil
end

--------------------------------------------------------------------------------
-- Zwischen Menue und Spiel umschalten
--------------------------------------------------------------------------------

local function showMenu()
	app.screen = "Menu"
	app.arenaFolder = nil

	hud:hide()
	tutorial:stop()
	controller:setEnabled(false)
	controller:setArena(nil)
	camera:setMenuView()

	levelSelect:setProfile(app.profile)
	levelSelect:show()
end

local function enterLevel(state)
	app.screen = "Playing"
	levelSelect:hide()
	hud:show()

	-- Auf die Welt warten, bevor gebaut werden darf.
	task.spawn(function()
		local folder = waitForArenaFolder()
		if not folder then
			--[[
				Haeufigste Ursache: Workspace.StreamingEnabled ist eingeschaltet.
				Ohne Spielerfigur hat der Client keinen Bezugspunkt und bekommt
				gar keine Welt uebertragen. Der Server schaltet Streaming beim
				Start ab; wurde es danach von Hand wieder gesetzt, landet man
				hier.
			]]
			warn("[BridgeLab] Arena nicht gefunden. Ist Workspace.StreamingEnabled aus?")
			hud:showNotice(I18n.t("error.noArena"), Theme.colors.danger)
			return
		end
		app.arenaFolder = folder
		print(string.format("[BridgeLab] Arena '%s' geladen.", folder.Name))

		--[[
			Der Controller braucht die Levelangaben, um die Vorschau selbst
			pruefen zu koennen - sonst wuerde sie erst gruen oder rot, wenn
			die Antwort vom Server da ist, und das ist nach dem Loslassen.
		]]
		--[[
			Die Gelaendedaten kommen nur im ERSTEN Bericht nach dem Levelstart
			mit (siehe Arena:buildState). Genau diesen Bericht hat enterLevel
			in der Hand, deshalb passt das zusammen.
		]]
		local info = state.levelInfo or {}
		controller:setLevel({
			buildArea = info.buildArea,
			anchors = info.anchors,
			terrain = info.terrain,
			materials = state.materials,
			blueprint = info.blueprint,
			z = info.z or 0,
		}, state.originY or 0)
		controller:setArena(folder)
		controller:setEnabled(true)

		-- Mit dem ersten Baustoff anfangen, den dieses Level ueberhaupt anbietet.
		local first = (state.materials and state.materials[1]) or "Road"
		controller:selectMaterial(first)
		hud:setSelected(first)

		camera:setArena(state.originY or 0, state.bounds, state.deckY or 40)
		-- Bei Levels ohne Vorlage (dem Sprunglevel) verschwindet der Knopf.
		hud:setBlueprintActive(false, controller:hasBlueprint())
	end)
end

--------------------------------------------------------------------------------
-- Level starten
--------------------------------------------------------------------------------

local function startLevel(levelId: string)
	remote.SelectLevel:FireServer(levelId)
end

levelSelect.onLevelChosen = function(levelId)
	startLevel(levelId)
end

levelSelect.onTutorialRequested = function()
	-- Die Anleitung braucht ein echtes Level zum Ueben.
	app.tutorialOffered = false
	startLevel("Level1")
end

--------------------------------------------------------------------------------
-- Knoepfe des HUD
--------------------------------------------------------------------------------

--[[
	Nur weitergeben, nicht selbst anzeigen: selectMaterial meldet die Auswahl
	ueber onSelectionChanged zurueck, und DORT werden Leiste und Anleitung
	benachrichtigt. Wer es hier zusaetzlich taete, haette zwei Stellen, die
	dasselbe tun - und genau dabei ist mir hier ein Fehler unterlaufen: nach
	dem Umbenennen des Parameters stand hier noch der alte Name, war also nil.
]]
hud.onSelectMaterial = function(key)
	controller:selectMaterial(key)
end

hud.onRemoveMode = function()
	controller:selectRemoveMode()
	hud:setSelected("Remove")
end

hud.onTest = function()
	-- Das am Tacho eingestellte Tempo geht mit; der Server prueft es.
	remote.StartTest:FireServer(hud.speed)
end

hud.onSpeedChanged = function(speed)
	remote.SetTestSpeed:FireServer(speed)
end

--[[
	Vorlage ein- und ausblenden. Sie ist reine Anzeige auf dem Client - der
	Server erfaehrt davon nichts, weil sich am Spielstand nichts aendert.
]]
hud.onBlueprint = function()
	local visible = controller:toggleBlueprint()
	hud:setBlueprintActive(visible, controller:hasBlueprint())
	if visible then
		tutorial:notify("blueprintShown")
	end
end

hud.onPhaseChanged = function(phase)
	remote.SetPhase:FireServer(phase)
end

-- Beim Bauen bestimmen dieselben Knoepfe, zu welcher Phase ein neuer
-- Zylinder gehoert. Das bleibt auf dem Client - der Server bekommt die
-- Phase erst mit dem fertigen Bauwunsch.
hud.onBuildPhaseChanged = function(phase)
	controller:setBuildPhase(phase)
end

hud.onReset = function()
	remote.ResetLevel:FireServer(false)
end

hud.onClear = function()
	remote.ResetLevel:FireServer(true)
end

hud.onRetry = function()
	remote.ResetLevel:FireServer(false)
end

hud.onNextLevel = function(levelId)
	startLevel(levelId)
end

hud.onMenu = function()
	remote.LeaveLevel:FireServer()
	showMenu()
end

hud.onHint = function()
	remote.RequestHint:FireServer()
end

--------------------------------------------------------------------------------
-- Bau-Steuerung
--------------------------------------------------------------------------------

controller.onPlaceRequest = function(material, ax, ay, bx, by, phase)
	remote.PlaceMember:FireServer(material, ax, ay, bx, by, phase)
end

controller.onRemoveRequest = function(memberId)
	remote.RemoveMember:FireServer(memberId)
end

controller.onSelectionChanged = function(key)
	hud:setSelected(key)
	if key ~= "Remove" then
		tutorial:notify("materialSelected", key)
	end
end

-- Die Anleitung will wissen, wann zum ersten Mal gezogen wird.
controller.onDragChanged = function(active)
	if active then
		tutorial:notify("dragStarted")
	end
end

--------------------------------------------------------------------------------
-- Anleitung
--------------------------------------------------------------------------------

tutorial.onFinished = function()
	remote.TutorialFinished:FireServer()
end

--[[
	Die Anleitung will wissen, ob der Spieler die Kamera schon einmal bewegt
	hat. Der CameraController merkt sich das in hasPanned / hasZoomed; wir
	sehen waehrend der Anleitung regelmaessig nach.
]]
task.spawn(function()
	while true do
		task.wait(0.2)
		if tutorial:isActive() and (camera.hasPanned or camera.hasZoomed) then
			tutorial:notify("cameraMoved")
		end
	end
end)

--------------------------------------------------------------------------------
-- Meldungen vom Server
--------------------------------------------------------------------------------

remote.ProfileChanged.OnClientEvent:Connect(function(profile)
	app.profile = profile
	levelSelect:setProfile(profile)

	--[[
		Beim allerersten Spielstart geht es sofort in Level 1, und die
		Anleitung startet automatisch. Wer sie schon gesehen hat, landet
		wie gewohnt im Menue.
	]]
	if not app.tutorialOffered then
		app.tutorialOffered = true
		if not profile.tutorialDone then
			startLevel("Level1")
			return
		end
		showMenu()
	end

	-- Ein Kauf ist durchgegangen: den angefragten Tipp jetzt holen.
	if app.pendingHintPurchase and (profile.hintCredits or 0) > 0 then
		app.pendingHintPurchase = false
		remote.RequestHint:FireServer()
	end
end)

remote.StateChanged.OnClientEvent:Connect(function(state)
	local previous = app.state
	app.state = state

	-- Neues Level betreten?
	if app.screen ~= "Playing" or (previous and previous.levelId ~= state.levelId) then
		enterLevel(state)
	end

	--[[
		Hat der Server gerade ein Bauteil angenommen?

		Der Client weiss das nicht von selbst: er schickt nur einen WUNSCH,
		und ob daraus ein Bauteil wird, entscheidet der Server. Sichtbar wird
		es allein daran, dass die Bauteilzahl im naechsten Bericht groesser
		ist. Die Anleitung wartet auf genau dieses Ereignis - ohne das blieb
		sie beim Schritt "Loslassen setzt das Bauteil" fuer immer stehen.
	]]
	if previous and previous.levelId == state.levelId then
		if (state.memberCount or 0) > (previous.memberCount or 0) then
			tutorial:notify("memberPlaced")
		end
	end

	hud:update(state)
	controller:setPhase(state.phase)
	controller:setUnstableJoint(if state.stable then nil else state.unstableJoint)
	-- Damit die Vorschau rot wird, sobald das Budget nicht mehr reicht.
	controller:setBudgetLeft((state.budgetTotal or 0) - (state.budgetUsed or 0))

	----------------------------------------------------------------------------
	-- Waehrend des Tests folgt die Kamera dem Fahrzeug
	----------------------------------------------------------------------------
	if state.phase == "Test" then
		if app.arenaFolder then
			--[[
				Die Fahrzeuge heissen "TestVehicle_1", "TestVehicle_2" und so
				weiter. Die Kamera folgt dem ERSTEN - bei Gegenverkehr kaeme
				sie sonst nicht hinterher, und in der Mitte, wo sich beide
				begegnen, sind ohnehin beide im Bild.
			]]
			local vehicleFolder = app.arenaFolder:FindFirstChild("Fahrzeuge")
			local vehicle = vehicleFolder and vehicleFolder:FindFirstChild("TestVehicle_1")
			if vehicle and vehicle:IsA("BasePart") then
				camera:follow(vehicle)
			end
		end
		tutorial:notify("testStarted")
	elseif previous and previous.phase == "Test" then
		--[[
			Der Test ist gerade zu Ende gegangen - egal ob geschafft oder
			nicht. Die Kamera stand zuletzt beim Fahrzeug, oft halb in der
			Schlucht und herangezoomt. Von der eigenen Bruecke, die man als
			Naechstes verbessern will, saehe man dort nichts.
		]]
		camera:follow(nil)
		camera:returnToOverview()
	else
		camera:follow(nil)
	end

	----------------------------------------------------------------------------
	-- Die Anleitung starten, sobald das erste Level wirklich steht
	----------------------------------------------------------------------------
	if app.profile and not app.profile.tutorialDone and not tutorial:isActive() then
		if state.phase == "Build" and state.levelId == "Level1" then
			task.delay(0.6, function()
				if not tutorial:isActive() and app.screen == "Playing" then
					--[[
						Zuruecksetzen, bevor die Anleitung startet: sonst gilt
						der Schritt "Ansicht bewegen" sofort als erledigt, wenn
						der Spieler vorher schon einmal gescrollt hat.
					]]
					camera.hasPanned = false
					camera.hasZoomed = false
					tutorial:start()
				end
			end)
		end
	end
end)

--[[
	Der Server schickt keinen fertigen Satz, sondern einen Schluessel mit
	Werten. Uebersetzt wird hier - beim Spieler, in dessen Sprache.
]]
remote.Notice.OnClientEvent:Connect(function(payload)
	hud:showNotice(I18n.message(payload))
end)

--------------------------------------------------------------------------------
-- Tipps und Robux
--------------------------------------------------------------------------------

remote.HintResult.OnClientEvent:Connect(function(payload)
	if payload.status == "needPurchase" then
		if not payload.configured then
			--[[
				Der Entwickler hat die Produkt-Nummer noch nicht eingetragen
				(Config.Monetisation.hintProductId). Damit sich das Spiel
				trotzdem testen laesst, sagen wir das einfach.
			]]
			hud:showNotice(I18n.t("hint.notSetUp"), Theme.colors.warning)
			return
		end

		app.pendingHintPurchase = true
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, payload.productId)
		end)
		if not ok then
			app.pendingHintPurchase = false
			hud:showNotice(I18n.t("error.purchaseFailed", tostring(err)), Theme.colors.danger)
		end
		return
	end

	hud:handleHintResult(payload)
end)

-- Wenn der Kauf abgebrochen wurde, nicht weiter darauf warten.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
	if userId ~= player.UserId or productId ~= Config.Monetisation.hintProductId then
		return
	end
	if not wasPurchased then
		app.pendingHintPurchase = false
	end
end)

--------------------------------------------------------------------------------
-- Los geht's
--------------------------------------------------------------------------------

-- Beim Geraetewechsel den Gamepad-Zeiger passend ein- oder ausblenden.
Device.changed(function()
	controller:setEnabled(app.screen == "Playing" and app.arenaFolder ~= nil)
end)

-- Bis das Profil da ist, zeigen wir das Menue. Der Server schickt es gleich.
levelSelect:show()

remote.ClientReady:FireServer()
