--[[
	Remotes
	-------
	Legt die RemoteEvents an (Server) bzw. wartet auf sie (Client).

	RemoteEvents sind der einzige Weg, wie Client und Server miteinander reden.
	Regel in diesem Projekt: der Client darf nur WUENSCHE schicken
	("bitte setze hier einen Balken"), entschieden wird alles auf dem Server.

	WARUM DER CLIENT NICHT EWIG WARTET
	Wenn das Serverskript abstuerzt, entstehen die RemoteEvents nie. Ein
	WaitForChild ohne Zeitlimit wuerde dann fuer immer haengen - der Spieler
	saehe einen leeren Bildschirm und keinerlei Hinweis, was los ist.
	Deshalb kann der Client ein Zeitlimit angeben und bekommt nil zurueck,
	wenn nichts kommt. Das Hauptskript zeigt daraufhin eine Fehlermeldung an.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Remotes = {}

local folder: Folder? = nil

--------------------------------------------------------------------------------
-- Ordner der RemoteEvents
--------------------------------------------------------------------------------

local function getFolder(timeout: number?): Folder?
	if folder and folder.Parent then
		return folder
	end

	if RunService:IsServer() then
		-- Auf dem Server legen wir den Ordner selbst an.
		local existing = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
		if not existing then
			local created = Instance.new("Folder")
			created.Name = Config.RemoteFolderName
			created.Parent = ReplicatedStorage
			existing = created
		end
		folder = existing :: Folder
		return folder
	end

	-- Auf dem Client warten wir darauf, dass der Server ihn geschickt hat.
	local found = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
	if not found then
		found = ReplicatedStorage:WaitForChild(Config.RemoteFolderName, timeout or 10)
	end
	if not found then
		return nil
	end
	folder = found :: Folder
	return folder
end

--------------------------------------------------------------------------------
-- Anlegen und Holen
--------------------------------------------------------------------------------

-- Muss einmal beim Serverstart aufgerufen werden, bevor Clients zugreifen.
function Remotes.createAll()
	local f = getFolder()
	assert(f, "RemoteEvent-Ordner konnte nicht angelegt werden.")
	for _, name in Config.RemoteNames do
		if not f:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = f
		end
	end
end

--[[
	Liefert ein RemoteEvent nach Namen.

	Auf dem Server ist das Ergebnis immer vorhanden - fehlt es, ist das ein
	Programmierfehler und wir brechen laut ab.
	Auf dem Client kann nil herauskommen, wenn der Server nicht antwortet.
]]
function Remotes.get(name: string, timeout: number?): RemoteEvent?
	local f = getFolder(timeout)
	if not f then
		return nil
	end

	if RunService:IsServer() then
		local remote = f:FindFirstChild(name)
		assert(remote, "RemoteEvent fehlt: " .. name .. " (Remotes.createAll() vergessen?)")
		return remote :: RemoteEvent
	end

	local remote = f:FindFirstChild(name)
	if not remote then
		remote = f:WaitForChild(name, timeout or 10)
	end
	return remote :: RemoteEvent?
end

return Remotes
