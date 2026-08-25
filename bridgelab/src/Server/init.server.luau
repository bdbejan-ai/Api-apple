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

	In default.project.json steht die Einstellung ebenfalls. Hier wird sie
	zusaetzlich zur Laufzeit gesetzt, damit ein von Hand gesetzter Haken in
	den Studio-Eigenschaften das Spiel nicht wieder unbrauchbar macht.
]]
Workspace.StreamingEnabled = false

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
		remote.Notice:FireClient(player, "Dieses Level gibt es nicht.")
		return
	end

	-- Alte Arena abbauen, bevor eine neue entsteht.
	closeArena(player)

	local slot = takeSlot(player)
	if not slot then
		remote.Notice:FireClient(player, "Gerade sind alle Bauplaetze belegt. Bitte kurz warten.")
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

remote.PlaceMember.OnServerEvent:Connect(function(player, kind, snapA, snapB)
	local arena = arenas[player]
	if not arena then
		return
	end
	-- Alles, was vom Client kommt, muss geprueft werden.
	if type(kind) ~= "string" or type(snapA) ~= "number" or type(snapB) ~= "number" then
		return
	end
	if snapA ~= snapA or snapB ~= snapB then -- NaN abfangen
		return
	end
	if tooFast(player, "PlaceMember", 0.05) then
		return
	end

	local ok, reason = arena:placeMember(kind, math.floor(snapA), math.floor(snapB))
	if not ok and reason ~= "" then
		remote.Notice:FireClient(player, reason)
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
	if not ok and reason ~= "" then
		remote.Notice:FireClient(player, reason)
	end
end)

--------------------------------------------------------------------------------
-- Test und Zuruecksetzen
--------------------------------------------------------------------------------

remote.StartTest.OnServerEvent:Connect(function(player)
	local arena = arenas[player]
	if not arena then
		return
	end
	if tooFast(player, "StartTest", 0.5) then
		return
	end

	local ok, reason = arena:startTest(function(success)
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

	if not ok and reason ~= "" then
		remote.Notice:FireClient(player, reason)
	end
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
