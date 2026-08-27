--[[
	BridgeLabServer (Hauptskript)
	-----------------------------
	Haelt alles zusammen: Spieler anmelden, Arenen vergeben, Wuensche der
	Clients pruefen und ausfuehren, Fortschritt speichern.

	SICHERHEIT - DIE GRUNDREGEL DIESES PROJEKTS
	Der Client schickt nur WUENSCHE ("bitte setze hier einen Balken").
	Entschieden wird alles hier. Jede Zahl, die hereinkommt, wird geprueft:
	Gibt es den Ankerpunkt? Ist die Laenge erlaubt? Reicht das Budget?
	Waehrend eines laufenden Tests wird gar nichts angenommen.

	KEINE SPIELERFIGUR
	Das Spiel wird von der Seite betrachtet, wie ein Brettspiel. Es gibt
	deshalb keine Spielfigur - CharacterAutoLoads wird abgeschaltet und die
	Kamera uebernimmt der Client (siehe CameraController.luau).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)

local Arena = require(script.Arena)
local PlayerData = require(script.PlayerData)
local Monetisation = require(script.Monetisation)

--------------------------------------------------------------------------------
-- Grundeinstellungen
--------------------------------------------------------------------------------

-- Keine Spielerfigur: das Spiel laeuft in der Seitenansicht.
Players.CharacterAutoLoads = false

--[[
	STREAMING MUSS AUS BLEIBEN - SONST SIEHT MAN GAR NICHTS.

	Bei eingeschaltetem Streaming schickt der Server einem Spieler nur die
	Umgebung rund um SEINE SPIELFIGUR. Genau die gibt es hier aber nicht,
	weil das Spiel von der Seite gespielt wird. Ohne Bezugspunkt bekommt der
	Client dann ueberhaupt nichts von der Welt zu sehen: die Oberflaeche ist
	da (sie liegt in der PlayerGui), die Bruecke fehlt komplett.

	ACHTUNG: StreamingEnabled laesst sich NICHT aus einem Skript heraus
	aendern. Roblox erlaubt das nur im Bearbeitungsmodus. Ein Schreibversuch
	an dieser Stelle wuerde das ganze Serverskript sofort abbrechen - und dann
	entstuenden nicht einmal die RemoteEvents.

	Deshalb wird hier nur GELESEN und im Zweifel gewarnt. Abgeschaltet wird
	die Einstellung in default.project.json.
]]
if Workspace.StreamingEnabled then
	warn(
		"[BridgeLab] Workspace.StreamingEnabled ist EINGESCHALTET. "
			.. "Das Spiel hat keine Spielerfigur, deshalb bekommt der Client damit keine Welt "
			.. "uebertragen - die Oberflaeche erscheint, das Level bleibt unsichtbar. "
			.. "Bitte in Studio unter Workspace den Haken bei StreamingEnabled entfernen."
	)
end

--------------------------------------------------------------------------------
-- Die Standardwelt von Roblox wegraeumen
--------------------------------------------------------------------------------

--[[
	Ein neues Roblox-Projekt bringt eine graue Grundplatte und eine
	Spawn-Plattform mit. BridgeLab baut seine Welt vollstaendig selbst, und
	dann stehen die beiden nur im Bild: die Grundplatte liegt genau im
	Ursprung, also dort, wo auch die erste Arena steht, und man sieht sie
	unter und neben der Bruecke.

	Beim Blick ins Menue faellt es am meisten auf - dort schaut die Kamera in
	eine Welt, in der es sonst nichts gibt, und man sieht die Spawn-Plattform
	mit verschwommenem Zeug drumherum.

	Weggeraeumt wird NUR, was Roblox von sich aus anlegt, und nur direkt
	unterhalb von Workspace. Alles andere koennte jemand absichtlich
	hinzugefuegt haben.
]]
local function clearDefaultWorld()
	for _, item in Workspace:GetChildren() do
		local isDefaultGround = item:IsA("BasePart") and (item.Name == "Baseplate" or item.Name == "Base")
		local isSpawn = item:IsA("SpawnLocation")
		if isDefaultGround or isSpawn then
			item:Destroy()
		end
	end
end

clearDefaultWorld()

--[[
	Der Himmel bekommt einen freundlichen Grundton und keinen Nebel. Ohne das
	verliert sich die Bruecke bei weit herausgezoomter Kamera im Dunst - was
	besonders in der grossen Schlucht stoert, wo man ohnehin weit weg ist.
]]
Lighting.Ambient = Color3.fromRGB(88, 92, 104)
Lighting.OutdoorAmbient = Color3.fromRGB(112, 120, 138)
Lighting.Brightness = 2.4
Lighting.FogEnd = 100000
Lighting.ClockTime = 14
Lighting.GeographicLatitude = 20

Remotes.createAll()

local worldRoot = Workspace:FindFirstChild("BridgeLab")
if worldRoot then
	worldRoot:Destroy()
end
worldRoot = Instance.new("Folder")
worldRoot.Name = "BridgeLab"
worldRoot.Parent = Workspace

local arenasFolder = Instance.new("Folder")
arenasFolder.Name = "Arenas"
arenasFolder.Parent = worldRoot

--------------------------------------------------------------------------------
-- RemoteEvents holen
--------------------------------------------------------------------------------

local remote = {}
for _, name in Config.RemoteNames do
	remote[name] = Remotes.get(name)
end

--------------------------------------------------------------------------------
-- Arenen verwalten
--------------------------------------------------------------------------------

local arenas: { [Player]: any } = {}
local slotOwner: { [number]: Player } = {}

-- Freien Stapelplatz suchen. nil = alle belegt.
local function takeSlot(player: Player): number?
	for index = 0, Config.Arena.maxCount - 1 do
		if not slotOwner[index] then
			slotOwner[index] = player
			return index
		end
	end
	return nil
end

local function releaseSlot(index: number)
	slotOwner[index] = nil
end

local function sendState(arena)
	if arena.player.Parent then
		remote.StateChanged:FireClient(arena.player, arena:buildState())
	end
end

local function sendProfile(player: Player)
	if player.Parent then
		remote.ProfileChanged:FireClient(player, PlayerData.toClient(player))
	end
end

local function closeArena(player: Player)
	local arena = arenas[player]
	if not arena then
		return
	end
	releaseSlot(arena.slotIndex)
	arena:destroy()
	arenas[player] = nil
end

--------------------------------------------------------------------------------
-- Schutz vor zu schnellen Anfragen
--------------------------------------------------------------------------------

--[[
	Ein veraenderter Client koennte ein RemoteEvent hunderte Male pro Sekunde
	abfeuern. Diese kleine Sperre laesst pro Aktion nur einen Aufruf im
	angegebenen Abstand durch.
]]
local lastCall: { [Player]: { [string]: number } } = {}

local function tooFast(player: Player, action: string, minimumGap: number): boolean
	local entry = lastCall[player]
	if not entry then
		entry = {}
		lastCall[player] = entry
	end
	local now = os.clock()
	if entry[action] and now - entry[action] < minimumGap then
		return true
	end
	entry[action] = now
	return false
end

--------------------------------------------------------------------------------
-- Spieler kommen und gehen
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- Das Laden blockiert kurz, deshalb in einem eigenen Task.
	task.spawn(function()
		PlayerData.load(player)
		sendProfile(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Spieler, die schon da waren, als das Skript startete (passiert in Studio).
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	closeArena(player)
	lastCall[player] = nil
	-- Das Speichern selbst erledigt PlayerData.
end)

--------------------------------------------------------------------------------
-- Level starten und verlassen
--------------------------------------------------------------------------------

remote.ClientReady.OnServerEvent:Connect(function(player)
	sendProfile(player)
	local arena = arenas[player]
	if arena then
		sendState(arena)
	end
end)

remote.SelectLevel.OnServerEvent:Connect(function(player, levelId)
	if type(levelId) ~= "string" then
		return
	end
	if tooFast(player, "SelectLevel", 0.5) then
		return
	end

	local level = Levels.get(levelId)
	if not level then
		remote.Notice:FireClient(player, { key = "notice.unknownLevel" })
		return
	end

	-- Alte Arena abbauen, bevor eine neue entsteht.
	closeArena(player)

	local slot = takeSlot(player)
	if not slot then
		remote.Notice:FireClient(player, { key = "notice.arenaFull" })
		return
	end

	local arena = Arena.new(player, level, slot, arenasFolder)
	arena.onStateChanged = sendState
	arenas[player] = arena

	-- Bereits gekaufte oder freigeschaltete Tipps wieder anzeigen.
	local used = PlayerData.hintsUsed(player, level.id)
	local unlocked = {}
	for index = 1, math.min(used, #level.hints) do
		unlocked[index] = level.hints[index]
	end
	arena:setUnlockedHints(unlocked)

	sendState(arena)
end)

remote.LeaveLevel.OnServerEvent:Connect(function(player)
	if tooFast(player, "LeaveLevel", 0.3) then
		return
	end
	closeArena(player)
	-- Der Client weiss selbst, dass er zurueck ins Menue geht; wir schicken
	-- nur das aktuelle Profil, damit der Fortschritt frisch ist.
	sendProfile(player)
end)

--------------------------------------------------------------------------------
-- Bauen
--------------------------------------------------------------------------------

--[[
	Der Client schickt jetzt KOORDINATEN statt Ankernummern - beim freien
	Bauen gibt es keine feste Nummernliste mehr.

	Damit kommen vier Zahlen vom Client, und jede davon muss geprueft werden:
	Zahl, nicht NaN, nicht unendlich, und auf dem Raster. Ein veraenderter
	Client koennte sonst Knoten an beliebigen Stellen erzeugen - etwa mitten
	im Fels oder weit ausserhalb des Levels. Die eigentliche Entscheidung
	faellt danach in Structure:canPlace.
]]
remote.PlaceMember.OnServerEvent:Connect(function(player, material, ax, ay, bx, by, phase)
	local arena = arenas[player]
	if not arena then
		return
	end
	if type(material) ~= "string" then
		return
	end

	local coordinates = { ax, ay, bx, by }
	for _, value in coordinates do
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			return
		end
		if math.abs(value) > 10000 then
			return
		end
	end

	if tooFast(player, "PlaceMember", 0.05) then
		return
	end

	-- Auf das Raster runden, statt krumme Werte abzulehnen: winzige
	-- Rundungsfehler aus der Bildschirmrechnung sollen kein Bauen verhindern.
	local grid = Config.Build.gridSize
	local function snap(value: number): number
		return math.round(value / grid) * grid
	end

	--[[
		Die Phase gilt nur fuer Hydraulikzylinder und wird auf den erlaubten
		Bereich gestutzt. Fehlt sie oder ist sie Unsinn, wird Phase 1 genommen -
		das ist die Phase, in der ohnehin die meisten Zylinder liegen.
	]]
	local wantedPhase = 1
	if type(phase) == "number" and phase == phase then
		wantedPhase = math.clamp(math.round(phase), 1, Config.Hydraulics.phaseCount)
	end

	local ok, reason, hint =
		arena:placeMember(material, snap(ax), snap(ay), snap(bx), snap(by), wantedPhase)
	if not ok and reason then
		remote.Notice:FireClient(player, reason)
	elseif ok and hint then
		-- Gebaut ja, aber es bringt so nichts: kurz Bescheid sagen.
		remote.Notice:FireClient(player, hint)
	end
end)

remote.RemoveMember.OnServerEvent:Connect(function(player, memberId)
	local arena = arenas[player]
	if not arena then
		return
	end
	if type(memberId) ~= "number" or memberId ~= memberId then
		return
	end
	if tooFast(player, "RemoveMember", 0.05) then
		return
	end

	local ok, reason = arena:removeMember(math.floor(memberId))
	if not ok and reason then
		remote.Notice:FireClient(player, reason)
	end
end)

--------------------------------------------------------------------------------
-- Hydraulik
--------------------------------------------------------------------------------

--[[
	Der Spieler schaltet die Zylinder waehrend des Tests weiter. Der Server
	begrenzt die Phase selbst - ein veraenderter Client soll nicht auf eine
	Phase schalten koennen, die es gar nicht gibt.
]]
remote.SetPhase.OnServerEvent:Connect(function(player, phase)
	local arena = arenas[player]
	if not arena then
		return
	end
	if type(phase) ~= "number" or phase ~= phase then
		return
	end
	if tooFast(player, "SetPhase", 0.15) then
		return
	end

	local ok, reason = arena:setPhase(phase)
	if not ok and reason then
		remote.Notice:FireClient(player, reason)
	end
end)

--------------------------------------------------------------------------------
-- Test und Zuruecksetzen
--------------------------------------------------------------------------------

remote.StartTest.OnServerEvent:Connect(function(player, speed)
	local arena = arenas[player]
	if not arena then
		return
	end
	if tooFast(player, "StartTest", 0.5) then
		return
	end

	-- Die Geschwindigkeit kommt vom Client und wird deshalb geprueft.
	-- Arena:startTest begrenzt sie zusaetzlich auf den erlaubten Bereich.
	if type(speed) ~= "number" or speed ~= speed then
		speed = Config.Test.defaultSpeed
	end

	local ok, reason = arena:startTest(speed, function(success)
		if not success then
			return
		end
		-- Level geschafft: Fortschritt merken und sofort sichern.
		PlayerData.markLevelComplete(player, arena.level.id)
		task.spawn(function()
			PlayerData.save(player)
			sendProfile(player)
		end)
	end)

	if not ok and reason then
		remote.Notice:FireClient(player, reason)
	end
end)

--[[
	Tacho: der Spieler verstellt die Fahrgeschwindigkeit. Das darf er auch
	mitten im Test - deshalb ist die Sperre hier sehr kurz, sonst haekelte
	der Regler beim Ziehen.
]]
remote.SetTestSpeed.OnServerEvent:Connect(function(player, speed)
	local arena = arenas[player]
	if not arena then
		return
	end
	if type(speed) ~= "number" or speed ~= speed then
		return
	end
	if tooFast(player, "SetTestSpeed", 0.05) then
		return
	end
	arena:setTestSpeed(speed)
end)

remote.ResetLevel.OnServerEvent:Connect(function(player, clearEverything)
	local arena = arenas[player]
	if not arena then
		return
	end
	if tooFast(player, "ResetLevel", 0.3) then
		return
	end

	if clearEverything == true then
		arena:clearBuild()
	else
		arena:reset()
	end
end)

--------------------------------------------------------------------------------
-- Tipps
--------------------------------------------------------------------------------

--[[
	Regel aus der Spielidee:
	  leichte Level (Schwierigkeit 1-3): der ERSTE Tipp ist gratis,
	                                     jeder weitere kostet Robux
	  schwere Level (Schwierigkeit 4-5): schon der erste Tipp kostet Robux

	Wie viele Tipps gratis sind, steht als "freeHints" in jedem Level.
	Bezahlt wird nicht pro Tipp, sondern mit Tipp-Gutscheinen, die man kauft
	(siehe Monetisation.luau).
]]

local function grantHint(player: Player, arena, index: number)
	local level = arena.level
	local text = level.hints[index]

	PlayerData.setHintsUsed(player, level.id, index)
	arena:addUnlockedHint(text)

	remote.HintResult:FireClient(player, {
		status = "ok",
		index = index,
		total = #level.hints,
		text = text,
	})

	sendProfile(player)
	arena:notify()
end

remote.RequestHint.OnServerEvent:Connect(function(player)
	local arena = arenas[player]
	if not arena then
		return
	end
	if tooFast(player, "RequestHint", 0.6) then
		return
	end

	local level = arena.level
	local nextIndex = PlayerData.hintsUsed(player, level.id) + 1

	if nextIndex > #level.hints then
		remote.HintResult:FireClient(player, {
			status = "none",
			total = #level.hints,
		})
		return
	end

	-- 1) Noch ein Gratis-Tipp uebrig?
	if nextIndex <= level.freeHints then
		grantHint(player, arena, nextIndex)
		return
	end

	-- 2) Noch ein gekaufter Gutschein uebrig?
	if PlayerData.hintCredits(player) > 0 then
		PlayerData.addHintCredits(player, -1)
		-- Gutscheine sind bezahlte Ware: sofort sichern, nicht auf das
		-- automatische Speichern warten.
		task.spawn(function()
			PlayerData.save(player)
		end)
		grantHint(player, arena, nextIndex)
		return
	end

	-- 3) Sonst muss gekauft werden.
	remote.HintResult:FireClient(player, {
		status = "needPurchase",
		index = nextIndex,
		total = #level.hints,
		productId = Config.Monetisation.hintProductId,
		price = Config.Monetisation.hintPrice,
		configured = Monetisation.isConfigured(),
	})
end)

-- Nach einem erfolgreichen Kauf: dem Client Bescheid geben.
Monetisation.onCreditGranted = function(player: Player)
	sendProfile(player)
	remote.Notice:FireClient(player, "Danke! Du hast einen Tipp-Gutschein erhalten.")
end

--------------------------------------------------------------------------------
-- Anleitung
--------------------------------------------------------------------------------

remote.TutorialFinished.OnServerEvent:Connect(function(player)
	if tooFast(player, "TutorialFinished", 1) then
		return
	end
	PlayerData.setTutorialDone(player, true)
	task.spawn(function()
		PlayerData.save(player)
		sendProfile(player)
	end)
end)

--------------------------------------------------------------------------------
-- Takt: alle Arenen im Baumodus nachrechnen lassen
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
	for _, arena in arenas do
		arena:tick(dt)
	end
end)

print(string.format("[BridgeLab] Server bereit - %d Level geladen.", #Levels.list))
