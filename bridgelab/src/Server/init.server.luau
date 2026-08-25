--[[
	BridgeLabServer (Hauptskript)
	-----------------------------
	Startet das Level, nimmt die Wuensche der Spieler entgegen und haelt den
	Spielzustand.

	SICHERHEIT
	Der Client schickt nur Wuensche. Jede Platzierung wird hier geprueft
	(gibt es den Ankerpunkt, ist die Laenge erlaubt, reicht das Budget).
	Waehrend eines laufenden Tests wird gar nichts angenommen.

	ANNAHME
	Es gibt genau EIN gemeinsames Level fuer alle Spieler auf dem Server.
	Alle bauen an derselben Bruecke. Das ist die einfachste sinnvolle Loesung;
	getrennte Level pro Spieler waeren deutlich mehr Aufwand.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Level1 = require(Shared.Level1)
local Remotes = require(Shared.Remotes)

local LevelBuilder = require(script.LevelBuilder)
local Structure = require(script.Structure)
local ForceEngine = require(script.ForceEngine)
local TestRun = require(script.TestRun)

--------------------------------------------------------------------------------
-- Gemeinsamer Zustand
--------------------------------------------------------------------------------

local ctx = {
	level = Level1,
	folders = nil,
	members = {}, -- der Bauplan
	nextMemberId = 1,
	phase = "Build", -- "Build" | "Test" | "Result"
	stable = true,
	unstableNode = nil, -- Ankerpunkt-Nummer der schwaechsten Stelle
	message = "",
	result = nil, -- { success = boolean, reason = string }
}

Remotes.createAll()
ctx.folders = LevelBuilder.build(Level1)

Structure.init(ctx)
ForceEngine.init(ctx)
TestRun.init(ctx)

local placeMember = Remotes.get("PlaceMember")
local removeMember = Remotes.get("RemoveMember")
local startTest = Remotes.get("StartTest")
local resetLevel = Remotes.get("ResetLevel")
local stateChanged = Remotes.get("StateChanged")
local notice = Remotes.get("Notice")

--------------------------------------------------------------------------------
-- Zustand an die Clients schicken
--------------------------------------------------------------------------------

local function buildState()
	return {
		phase = ctx.phase,
		budgetTotal = ctx.level.budget,
		budgetUsed = Structure.usedBudget(),
		memberCount = #ctx.members,
		stable = ctx.stable,
		unstableNode = ctx.unstableNode,
		message = ctx.message,
		result = ctx.result,
		levelName = ctx.level.displayName,
		timeLimit = ctx.level.timeLimit,
	}
end

local function broadcastState()
	stateChanged:FireAllClients(buildState())
end

--------------------------------------------------------------------------------
-- Kraefte im Baumodus regelmaessig nachrechnen
--------------------------------------------------------------------------------

local buildSolveAccumulator = 0

local function updateBuildAnalysis()
	local result = ForceEngine.evaluate(nil)
	ForceEngine.applyColors()

	local stable = not result.unstable
	if stable ~= ctx.stable or result.worstNodeIndex ~= ctx.unstableNode then
		ctx.stable = stable
		ctx.unstableNode = result.worstNodeIndex
		broadcastState()
	end
end

RunService.Heartbeat:Connect(function(dt)
	if ctx.phase == "Test" then
		return
	end
	buildSolveAccumulator += dt
	local interval = 1 / Config.Physics.solveRateBuild
	if buildSolveAccumulator >= interval then
		buildSolveAccumulator = 0
		updateBuildAnalysis()
	end
end)

--------------------------------------------------------------------------------
-- RemoteEvents
--------------------------------------------------------------------------------

placeMember.OnServerEvent:Connect(function(player, kind, snapA, snapB)
	-- Alles, was vom Client kommt, muss geprueft werden.
	if ctx.phase ~= "Build" then
		notice:FireClient(player, "Waehrend des Tests laesst sich nicht bauen.")
		return
	end
	if type(kind) ~= "string" or type(snapA) ~= "number" or type(snapB) ~= "number" then
		return
	end
	snapA = math.floor(snapA)
	snapB = math.floor(snapB)

	local allowed, reason = Structure.canPlace(kind, snapA, snapB)
	if not allowed then
		notice:FireClient(player, reason)
		return
	end

	Structure.place(kind, snapA, snapB)
	ctx.message = ""
	updateBuildAnalysis()
	broadcastState()
end)

removeMember.OnServerEvent:Connect(function(player, memberId)
	if ctx.phase ~= "Build" then
		notice:FireClient(player, "Waehrend des Tests laesst sich nichts entfernen.")
		return
	end
	if type(memberId) ~= "number" then
		return
	end

	if Structure.remove(math.floor(memberId)) then
		updateBuildAnalysis()
		broadcastState()
	end
end)

startTest.OnServerEvent:Connect(function(player)
	if ctx.phase ~= "Build" then
		return
	end
	if #ctx.members == 0 then
		notice:FireClient(player, "Erst bauen, dann testen.")
		return
	end

	ctx.phase = "Test"
	ctx.result = nil
	ctx.message = "Test laeuft ..."
	broadcastState()

	TestRun.start(function(success, reason)
		ctx.phase = "Result"
		ctx.result = { success = success, reason = reason }
		ctx.message = reason
		broadcastState()
	end)
end)

resetLevel.OnServerEvent:Connect(function()
	if TestRun.isRunning() then
		TestRun.stop()
	end
	Structure.rebuild()
	ctx.phase = "Build"
	ctx.result = nil
	ctx.message = ""
	updateBuildAnalysis()
	broadcastState()
end)

--------------------------------------------------------------------------------
-- Neue Spieler bekommen sofort den aktuellen Zustand
--------------------------------------------------------------------------------

-- Der Client meldet sich ueber dasselbe RemoteEvent, sobald sein Skript laeuft,
-- und bekommt daraufhin den aktuellen Zustand geschickt.
stateChanged.OnServerEvent:Connect(function(player)
	stateChanged:FireClient(player, buildState())
end)

Players.PlayerAdded:Connect(function(player)
	task.delay(1, function()
		if player.Parent then
			stateChanged:FireClient(player, buildState())
		end
	end)
end)

print("[BridgeLab] Server bereit - " .. Level1.displayName)
