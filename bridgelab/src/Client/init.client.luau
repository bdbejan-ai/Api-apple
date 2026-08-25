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

local Device = require(script.Device)
local Theme = require(script.Theme)
local CameraController = require(script.CameraController)
local BuildController = require(script.BuildController)
local LevelSelectGui = require(script.LevelSelectGui)
local BuildHud = require(script.BuildHud)
local TutorialGui = require(script.TutorialGui)

local player = Players.LocalPlayer

-- Alle RemoteEvents in eine Tabelle holen: remote.PlaceMember usw.
local remote = {}
for _, name in Config.RemoteNames do
	remote[name] = Remotes.get(name)
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
		if folder and folder:FindFirstChild("SnapPoints") then
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
			hud:showNotice("Die Bauflaeche konnte nicht geladen werden.", Theme.colors.danger)
			return
		end
		app.arenaFolder = folder

		controller:setArena(folder)
		controller:setEnabled(true)
		controller:selectKind("Beam")
		hud:setSelected("Beam")

		camera:setArena(state.originY or 0, state.bounds, state.deckY or 40)
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

hud.onSelectPart = function(kind)
	controller:selectKind(kind)
	hud:setSelected(kind)
	tutorial:notify("partSelected", kind)
end

hud.onRemoveMode = function()
	controller:selectRemoveMode()
	hud:setSelected("Remove")
end

hud.onTest = function()
	remote.StartTest:FireServer()
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

controller.onPlaceRequest = function(kind, snapA, snapB)
	remote.PlaceMember:FireServer(kind, snapA, snapB)
end

controller.onRemoveRequest = function(memberId)
	remote.RemoveMember:FireServer(memberId)
end

controller.onSelectionChanged = function(kind)
	hud:setSelected(kind)
	if kind ~= "Remove" then
		tutorial:notify("partSelected", kind)
	end
end

controller.onFirstSnapChanged = function(snapIndex)
	if snapIndex then
		tutorial:notify("firstSnapChosen", snapIndex)
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

	hud:update(state)
	controller:setPhase(state.phase)
	controller:setUnstableNode(if state.stable then nil else state.unstableNode)

	----------------------------------------------------------------------------
	-- Waehrend des Tests folgt die Kamera dem Fahrzeug
	----------------------------------------------------------------------------
	if state.phase == "Test" then
		if app.arenaFolder then
			local vehicleFolder = app.arenaFolder:FindFirstChild("Vehicle")
			local vehicle = vehicleFolder and vehicleFolder:FindFirstChild("TestVehicle")
			if vehicle and vehicle:IsA("BasePart") then
				camera:follow(vehicle)
			end
		end
		tutorial:notify("testStarted")
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
					tutorial:start()
				end
			end)
		end
	end
end)

remote.Notice.OnClientEvent:Connect(function(text)
	hud:showNotice(text)
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
			hud:showNotice(
				"Der Tipp-Kauf ist noch nicht eingerichtet (siehe README).",
				Theme.colors.warning
			)
			return
		end

		app.pendingHintPurchase = true
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, payload.productId)
		end)
		if not ok then
			app.pendingHintPurchase = false
			hud:showNotice("Der Kauf konnte nicht geoeffnet werden: " .. tostring(err), Theme.colors.danger)
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
