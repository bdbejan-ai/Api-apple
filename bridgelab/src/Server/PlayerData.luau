--[[
	PlayerData
	----------
	Speichert den Fortschritt eines Spielers dauerhaft:
	  - ob er die Anleitung schon gesehen hat
	  - welche Level er geschafft hat
	  - wie viele Tipps er pro Level schon aufgedeckt hat
	  - wie viele gekaufte Tipp-Gutscheine er noch hat

	WICHTIG FUER DAS TESTEN IN STUDIO
	DataStores funktionieren in Roblox Studio nur, wenn du in den
	Spieleinstellungen "Enable Studio Access to API Services" eingeschaltet
	hast (steht in der README). Ist das nicht der Fall, laeuft das Spiel
	trotzdem - der Fortschritt wird dann nur nicht gespeichert und ist beim
	naechsten Start wieder weg. Das Spiel bricht deswegen nicht ab.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local PlayerData = {}

-- Profile der gerade anwesenden Spieler: [Player] = Profil
local profiles: { [Player]: any } = {}

-- Sobald ein DataStore-Zugriff scheitert, merken wir uns das und probieren es
-- nicht bei jedem Speichern erneut (spart Fehlermeldungen im Output).
local storeAvailable = true

local profileStore = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.profileStoreName)
	end)
	if ok then
		profileStore = result
	else
		storeAvailable = false
		warn("[BridgeLab] DataStore nicht verfuegbar - Fortschritt wird nicht gespeichert.")
	end
end

--------------------------------------------------------------------------------
-- Standardprofil
--------------------------------------------------------------------------------

local function newProfile()
	return {
		tutorialDone = false,
		completed = {}, -- [levelId] = true
		hintsUsed = {}, -- [levelId] = Anzahl bereits aufgedeckter Tipps
		hintCredits = 0, -- gekaufte, noch nicht eingeloeste Tipps
		version = 1,
	}
end

-- Sorgt dafuer, dass ein geladenes Profil alle erwarteten Felder hat.
-- Wichtig, wenn spaeter neue Felder dazukommen.
local function normalise(data)
	local profile = newProfile()
	if type(data) ~= "table" then
		return profile
	end
	profile.tutorialDone = data.tutorialDone == true
	profile.hintCredits = tonumber(data.hintCredits) or 0
	if type(data.completed) == "table" then
		for levelId, value in data.completed do
			if type(levelId) == "string" and value then
				profile.completed[levelId] = true
			end
		end
	end
	if type(data.hintsUsed) == "table" then
		for levelId, count in data.hintsUsed do
			if type(levelId) == "string" and tonumber(count) then
				profile.hintsUsed[levelId] = math.max(0, math.floor(tonumber(count) :: number))
			end
		end
	end
	return profile
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

--------------------------------------------------------------------------------
-- Laden und Speichern
--------------------------------------------------------------------------------

-- Laedt das Profil. Blockiert kurz - immer aus einem eigenen Task aufrufen.
function PlayerData.load(player: Player)
	if profiles[player] then
		return profiles[player]
	end

	local profile = newProfile()

	if storeAvailable and profileStore then
		local ok, result = pcall(function()
			return profileStore:GetAsync(keyFor(player))
		end)
		if ok then
			profile = normalise(result)
		else
			warn("[BridgeLab] Profil konnte nicht geladen werden: " .. tostring(result))
		end
	end

	-- Der Spieler koennte in der Zwischenzeit das Spiel verlassen haben.
	if not player.Parent then
		return profile
	end

	profiles[player] = profile
	return profile
end

function PlayerData.get(player: Player)
	return profiles[player]
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	if not profile or not storeAvailable or not profileStore then
		return
	end

	local ok, err = pcall(function()
		profileStore:SetAsync(keyFor(player), profile)
	end)
	if not ok then
		warn("[BridgeLab] Profil konnte nicht gespeichert werden: " .. tostring(err))
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	profiles[player] = nil
end

--------------------------------------------------------------------------------
-- Aenderungen
--------------------------------------------------------------------------------

function PlayerData.setTutorialDone(player: Player, done: boolean)
	local profile = profiles[player]
	if profile then
		profile.tutorialDone = done
	end
end

function PlayerData.markLevelComplete(player: Player, levelId: string)
	local profile = profiles[player]
	if profile then
		profile.completed[levelId] = true
	end
end

function PlayerData.hintsUsed(player: Player, levelId: string): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	return profile.hintsUsed[levelId] or 0
end

function PlayerData.setHintsUsed(player: Player, levelId: string, count: number)
	local profile = profiles[player]
	if profile then
		profile.hintsUsed[levelId] = count
	end
end

function PlayerData.addHintCredits(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.hintCredits = math.max(0, profile.hintCredits + amount)
	end
end

function PlayerData.hintCredits(player: Player): number
	local profile = profiles[player]
	return if profile then profile.hintCredits else 0
end

--------------------------------------------------------------------------------
-- Fassung fuer den Client
--------------------------------------------------------------------------------

-- Der Client bekommt nur, was er zum Anzeigen braucht.
function PlayerData.toClient(player: Player)
	local profile = profiles[player]
	if not profile then
		return {
			tutorialDone = false,
			completed = {},
			hintsUsed = {},
			hintCredits = 0,
			storeAvailable = storeAvailable,
		}
	end
	return {
		tutorialDone = profile.tutorialDone,
		completed = profile.completed,
		hintsUsed = profile.hintsUsed,
		hintCredits = profile.hintCredits,
		storeAvailable = storeAvailable,
	}
end

function PlayerData.isStoreAvailable(): boolean
	return storeAvailable
end

--------------------------------------------------------------------------------
-- Automatisches Sichern
--------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(Config.Data.autosaveSeconds)
		for player in profiles do
			if player.Parent then
				PlayerData.save(player)
			end
		end
	end
end)

-- Beim Herunterfahren des Servers alles sichern. Ohne das gehen die letzten
-- Minuten Fortschritt verloren.
game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	for player in profiles do
		PlayerData.save(player)
	end
	task.wait(1)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

return PlayerData
