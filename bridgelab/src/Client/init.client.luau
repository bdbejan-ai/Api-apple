--[[
	BridgeLabClient (Hauptskript des Clients)
	-----------------------------------------
	Verbindet Oberflaeche (BuildGui) und Bau-Steuerung (BuildController)
	mit den RemoteEvents des Servers.

	Der Client trifft keine Entscheidungen ueber das Spielgeschehen.
	Er zeigt nur an, was der Server meldet, und schickt Wuensche dorthin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local BuildGui = require(script.BuildGui)
local BuildController = require(script.BuildController)

-- Alle RemoteEvents in eine Tabelle holen: remotes.PlaceMember usw.
local remotes = {}
for _, name in Config.RemoteNames do
	remotes[name] = Remotes.get(name)
end

local gui = BuildGui.new()
local controller = BuildController.new(remotes, gui)

--------------------------------------------------------------------------------
-- Knoepfe verbinden
--------------------------------------------------------------------------------

for _, key in Config.PartOrder do
	local button = gui.partButtons[key]
	button.Activated:Connect(function()
		controller:selectKind(key)
	end)
end

gui.removeButton.Activated:Connect(function()
	controller:selectRemoveMode()
end)

gui.testButton.Activated:Connect(function()
	remotes.StartTest:FireServer()
end)

gui.resetButton.Activated:Connect(function()
	remotes.ResetLevel:FireServer()
end)

--------------------------------------------------------------------------------
-- Meldungen vom Server
--------------------------------------------------------------------------------

remotes.StateChanged.OnClientEvent:Connect(function(state)
	gui:update(state)
	controller:setPhase(state.phase)
	controller:setUnstableNode(if state.stable then nil else state.unstableNode)
end)

remotes.Notice.OnClientEvent:Connect(function(text)
	gui:showNotice(text)
end)

-- Startauswahl setzen und den aktuellen Zustand beim Server anfordern.
controller:selectKind("Beam")
remotes.StateChanged:FireServer()
