--[[
	Remotes
	-------
	Legt die RemoteEvents an (Server) bzw. wartet auf sie (Client).

	RemoteEvents sind der einzige Weg, wie Client und Server miteinander reden.
	Regel in diesem Projekt: der Client darf nur WUENSCHE schicken
	("bitte setze hier einen Balken"), entschieden wird alles auf dem Server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Remotes = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end

	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
		if not existing then
			existing = Instance.new("Folder")
			existing.Name = Config.RemoteFolderName
			existing.Parent = ReplicatedStorage
		end
		folder = existing :: Folder
	else
		folder = ReplicatedStorage:WaitForChild(Config.RemoteFolderName) :: Folder
	end

	return folder :: Folder
end

-- Muss einmal beim Serverstart aufgerufen werden, bevor Clients zugreifen.
function Remotes.createAll()
	local f = getFolder()
	for _, name in Config.RemoteNames do
		if not f:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = f
		end
	end
end

-- Liefert ein RemoteEvent nach Namen.
function Remotes.get(name: string): RemoteEvent
	local f = getFolder()
	if RunService:IsServer() then
		local remote = f:FindFirstChild(name)
		assert(remote, "RemoteEvent fehlt: " .. name .. " (Remotes.createAll() vergessen?)")
		return remote :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

return Remotes
