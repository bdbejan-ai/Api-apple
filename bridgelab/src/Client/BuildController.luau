--[[
	BuildController
	---------------
	Die Bau-Interaktion auf dem Client - fuer Maus, Touch und Gamepad.

	DER TRICK: EIN GEMEINSAMER ZEIGEPUNKT
	Statt fuer jedes Geraet eine eigene Trefferlogik zu schreiben, rechnen
	wir alle Eingaben auf EINEN Punkt auf dem Bildschirm um:

	  Maus    -> die Position des Mauszeigers
	  Touch   -> die Stelle, an der der Finger liegt
	  Gamepad -> ein eigener Zeiger, den der linke Stick bewegt

	Von diesem Punkt aus geht ein Strahl in die Welt. Der Ankerpunkt, der
	diesem Strahl am naechsten liegt, gilt als getroffen. Das ist unabhaengig
	von der Kameraposition und funktioniert auch, wenn ein Bauteil den Punkt
	halb verdeckt.

	ABLAUF BEIM BAUEN
	  1. Bauteiltyp im Menue waehlen.
	  2. Ersten Ankerpunkt waehlen  -> wird gemerkt.
	  3. Zweiten Ankerpunkt waehlen -> Wunsch geht an den Server.
	Der Server entscheidet, ob das Bauteil wirklich entsteht.

	WARUM BEI TOUCH NUR EIN KURZES TIPPEN BAUT
	Ein Finger, der sich bewegt, will meistens etwas anderes. Deshalb gilt
	nur ein kurzes Tippen ohne grosse Bewegung als Auswahl. Ziehen mit zwei
	Fingern gehoert der Kamera (siehe CameraController).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local Device = require(script.Parent.Device)

local BuildController = {}
BuildController.__index = BuildController

-- Wie weit der Zeiger vom Ankerpunkt entfernt sein darf (in Studs, quer zum
-- Sichtstrahl gemessen). Waechst mit der Entfernung mit, damit weit entfernte
-- Punkte nicht unmoeglich zu treffen sind.
local function pickRadius(distance: number, touch: boolean): number
	local base = distance * (if touch then 0.05 else 0.03)
	return math.clamp(base, if touch then 2.5 else 1.5, if touch then 9 else 6)
end

-- Ein kurzes Tippen: hoechstens so lang und mit hoechstens so viel Bewegung.
local TAP_MAX_SECONDS = 0.4
local TAP_MAX_PIXELS = 18

--------------------------------------------------------------------------------

function BuildController.new()
	local self = setmetatable({}, BuildController)

	self.player = Players.LocalPlayer
	self.camera = workspace.CurrentCamera

	self.selectedKind = "Beam"
	self.removeMode = false
	self.firstSnap = nil
	self.firstSnapPosition = nil
	self.phase = "Idle" -- "Idle" (kein Level) | "Build" | "Test" | "Result"
	self.enabled = false

	self.snapFolder = nil
	self.memberFolder = nil

	-- Zeigepunkt auf dem Bildschirm
	self.pointer = Vector2.new(0, 0)
	self.gamepadCursor = Vector2.new(0, 0)
	self.activeTouch = nil
	self.touchStart = nil
	self.touchStartTime = 0

	-- Rueckmeldungen nach aussen (werden von init.client gesetzt)
	self.onPlaceRequest = nil -- (kind, snapA, snapB)
	self.onRemoveRequest = nil -- (memberId)
	self.onSelectionChanged = nil -- (kind oder "Remove")
	self.onFirstSnapChanged = nil -- (snapIndex oder nil)

	self:createMarkers()
	self:createGamepadCursor()
	self:connectInput()

	self.renderConnection = RunService.RenderStepped:Connect(function(dt)
		self:update(dt)
	end)

	return self
end

--------------------------------------------------------------------------------
-- Markierungen in der Welt
--------------------------------------------------------------------------------

function BuildController:createMarkers()
	local function marker(name: string, color: Color3, size: number): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(size, size, size)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = 1
		part.Parent = workspace
		return part
	end

	-- Ankerpunkt unter dem Zeiger
	self.hoverMarker = marker("HoverMarker", Color3.fromRGB(255, 255, 255), 2.4)
	-- Bereits gewaehlter erster Ankerpunkt
	self.startMarker = marker("StartMarker", Color3.fromRGB(120, 220, 255), 2.6)
	-- Stelle, an der die Konstruktion nicht ausgesteift ist
	self.weakMarker = marker("WeakSpotMarker", Color3.fromRGB(255, 90, 70), 3.2)

	-- Vorschaulinie zwischen erstem und anvisiertem Ankerpunkt
	local preview = Instance.new("Part")
	preview.Name = "PlacementPreview"
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanQuery = false
	preview.CanTouch = false
	preview.Material = Enum.Material.Neon
	preview.Transparency = 1
	preview.Size = Vector3.new(0.4, 0.4, 1)
	preview.Parent = workspace
	self.preview = preview
end

--[[
	Der Gamepad-Zeiger ist ein kleines Fadenkreuz auf dem Bildschirm.
	Es gibt beim Gamepad keinen Mauszeiger, also malen wir uns einen.
]]
function BuildController:createGamepadCursor()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BridgeLabCursor"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = self.player:WaitForChild("PlayerGui")

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromOffset(26, 26)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ring.BackgroundTransparency = 0.55
	ring.BorderSizePixel = 0
	ring.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 22, 28)
	stroke.Thickness = 2
	stroke.Parent = ring

	self.cursorGui = gui
	self.cursorRing = ring

	-- In der Bildschirmmitte anfangen.
	local viewport = self.camera.ViewportSize
	self.gamepadCursor = Vector2.new(viewport.X / 2, viewport.Y / 2)
end

--------------------------------------------------------------------------------
-- Arena verbinden
--------------------------------------------------------------------------------

--[[
	Sagt dem Controller, in welcher Arena gebaut wird. Die Ordner kommen vom
	Server; hier merken wir uns nur, wo die Ankerpunkte und Bauteile liegen.
]]
function BuildController:setArena(arenaFolder: Instance?)
	if arenaFolder then
		self.snapFolder = arenaFolder:FindFirstChild("SnapPoints")
		self.memberFolder = arenaFolder:FindFirstChild("Members")
	else
		self.snapFolder = nil
		self.memberFolder = nil
	end

	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Include
	self.raycastParams.FilterDescendantsInstances = if self.memberFolder then { self.memberFolder } else {}

	self:cancelSelection()
end

function BuildController:setEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled then
		self:cancelSelection()
		self:hideMarkers()
	end
	self.cursorGui.Enabled = enabled and Device.isGamepad()
end

function BuildController:hideMarkers()
	self.hoverMarker.Transparency = 1
	self.startMarker.Transparency = 1
	self.preview.Transparency = 1
	self.weakMarker.Transparency = 1
end

--------------------------------------------------------------------------------
-- Zeigepunkt bestimmen
--------------------------------------------------------------------------------

function BuildController:updatePointer(dt: number)
	if Device.isGamepad() then
		-- Linker Stick bewegt den Zeiger.
		local stick = Vector2.zero
		for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if state.KeyCode == Enum.KeyCode.Thumbstick1 then
				stick = Vector2.new(state.Position.X, state.Position.Y)
				break
			end
		end

		if stick.Magnitude > 0.15 then
			local viewport = self.camera.ViewportSize
			local speed = 900 * dt
			self.gamepadCursor = Vector2.new(
				math.clamp(self.gamepadCursor.X + stick.X * speed, 0, viewport.X),
				math.clamp(self.gamepadCursor.Y - stick.Y * speed, 0, viewport.Y)
			)
		end

		self.pointer = self.gamepadCursor
		self.cursorRing.Position = UDim2.fromOffset(self.pointer.X, self.pointer.Y)
	elseif Device.isTouch() then
		-- Bleibt auf der zuletzt beruehrten Stelle stehen.
		-- self.pointer wird in den Touch-Ereignissen gesetzt.
	else
		self.pointer = UserInputService:GetMouseLocation()
	end
end

-- Der Sichtstrahl vom Zeigepunkt in die Welt.
function BuildController:pointerRay(): Ray
	return self.camera:ViewportPointToRay(self.pointer.X, self.pointer.Y)
end

--------------------------------------------------------------------------------
-- Treffer suchen
--------------------------------------------------------------------------------

function BuildController:findSnapUnderPointer(): (number?, Vector3?)
	if not self.snapFolder then
		return nil, nil
	end

	local ray = self:pointerRay()
	local origin = ray.Origin
	local direction = ray.Direction.Unit
	local touch = Device.isTouch()

	local bestIndex, bestPosition = nil, nil
	local bestScore = math.huge

	for _, marker in self.snapFolder:GetChildren() do
		local index = marker:GetAttribute("SnapIndex")
		if not index then
			continue
		end

		local toPoint = (marker :: BasePart).Position - origin
		local along = toPoint:Dot(direction)
		if along < 1 or along > 600 then
			continue
		end

		-- Abstand des Ankerpunkts vom Sichtstrahl.
		local offset = (toPoint - direction * along).Magnitude
		if offset <= pickRadius(along, touch) and offset < bestScore then
			bestScore = offset
			bestIndex = index
			bestPosition = (marker :: BasePart).Position
		end
	end

	return bestIndex, bestPosition
end

function BuildController:findMemberUnderPointer(): number?
	if not self.memberFolder then
		return nil
	end
	local ray = self:pointerRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 600, self.raycastParams)
	if hit and hit.Instance then
		return hit.Instance:GetAttribute("MemberId")
	end
	return nil
end

--------------------------------------------------------------------------------
-- Markierungen und Vorschau nachfuehren
--------------------------------------------------------------------------------

function BuildController:update(dt: number)
	self:updatePointer(dt)

	if not self.enabled or self.phase ~= "Build" then
		self:hideMarkers()
		return
	end

	if self.removeMode then
		-- Im Abrissmodus wird kein Ankerpunkt hervorgehoben.
		self.hoverMarker.Transparency = 1
		self.preview.Transparency = 1
		self.startMarker.Transparency = 1
		return
	end

	local index, position = self:findSnapUnderPointer()

	if index and position then
		self.hoverMarker.Position = position
		self.hoverMarker.Transparency = 0.45
	else
		self.hoverMarker.Transparency = 1
	end

	-- Vorschaulinie zeichnen, sobald der erste Punkt gesetzt ist.
	if self.firstSnap and self.firstSnapPosition then
		self.startMarker.Position = self.firstSnapPosition
		self.startMarker.Transparency = 0.3

		if position and index ~= self.firstSnap then
			local spec = Config.PartTypes[self.selectedKind]
			local delta = position - self.firstSnapPosition
			local length = delta.Magnitude
			local allowed = length >= spec.minLength and length <= spec.maxLength
			if spec.verticalOnly and math.abs(delta.X) > 0.01 then
				allowed = false
			end

			-- Bei senkrechten Bauteilen darf der Hilfsvektor nicht (0,1,0) sein,
			-- sonst liefert CFrame.lookAt kein brauchbares Ergebnis.
			local up = if math.abs(delta.Unit.Y) > 0.999 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)

			self.preview.Size = Vector3.new(0.45, 0.45, length)
			self.preview.CFrame = CFrame.lookAt(self.firstSnapPosition + delta / 2, position, up)
			self.preview.Color = if allowed then Color3.fromRGB(120, 235, 150) else Color3.fromRGB(235, 90, 80)
			self.preview.Transparency = 0.25
		else
			self.preview.Transparency = 1
		end
	else
		self.startMarker.Transparency = 1
		self.preview.Transparency = 1
	end
end

--------------------------------------------------------------------------------
-- Auswahl und Aktionen
--------------------------------------------------------------------------------

function BuildController:cancelSelection()
	local had = self.firstSnap ~= nil
	self.firstSnap = nil
	self.firstSnapPosition = nil
	self.startMarker.Transparency = 1
	self.preview.Transparency = 1
	if had and self.onFirstSnapChanged then
		self.onFirstSnapChanged(nil)
	end
end

-- Ein "Auswaehlen" - egal von welchem Geraet.
function BuildController:primaryAction()
	if not self.enabled or self.phase ~= "Build" then
		return
	end

	if self.removeMode then
		local memberId = self:findMemberUnderPointer()
		if memberId and self.onRemoveRequest then
			self.onRemoveRequest(memberId)
		end
		return
	end

	local index, position = self:findSnapUnderPointer()
	if not index or not position then
		return
	end

	if not self.firstSnap then
		self.firstSnap = index
		self.firstSnapPosition = position
		if self.onFirstSnapChanged then
			self.onFirstSnapChanged(index)
		end
		return
	end

	if index == self.firstSnap then
		-- Denselben Punkt noch einmal gewaehlt: Auswahl verwerfen.
		self:cancelSelection()
		return
	end

	if self.onPlaceRequest then
		self.onPlaceRequest(self.selectedKind, self.firstSnap, index)
	end
	self:cancelSelection()
end

-- Ein "Abbrechen" bzw. "Entfernen" - egal von welchem Geraet.
function BuildController:secondaryAction()
	if not self.enabled or self.phase ~= "Build" then
		return
	end

	-- Steht eine Auswahl offen, wird sie zuerst abgebrochen.
	if self.firstSnap then
		self:cancelSelection()
		return
	end

	local memberId = self:findMemberUnderPointer()
	if memberId and self.onRemoveRequest then
		self.onRemoveRequest(memberId)
	end
end

--------------------------------------------------------------------------------
-- Eingaben
--------------------------------------------------------------------------------

function BuildController:connectInput()
	UserInputService.InputBegan:Connect(function(input, processedByGui)
		if processedByGui or not self.enabled then
			return
		end

		local inputType = input.UserInputType

		if inputType == Enum.UserInputType.MouseButton1 then
			self:primaryAction()
		elseif inputType == Enum.UserInputType.MouseButton2 then
			self:secondaryAction()
		elseif inputType == Enum.UserInputType.Touch then
			-- Erst beim Loslassen entscheiden, ob es ein Tippen war.
			if self.activeTouch == nil then
				self.activeTouch = input
				self.touchStart = Vector2.new(input.Position.X, input.Position.Y)
				self.touchStartTime = os.clock()
			else
				-- Ein zweiter Finger: das ist Kamerabedienung, kein Bauen.
				self.activeTouch = nil
			end
		elseif inputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.ButtonA then
				self:primaryAction()
			elseif input.KeyCode == Enum.KeyCode.ButtonB then
				self:secondaryAction()
			elseif input.KeyCode == Enum.KeyCode.ButtonX then
				self:toggleRemoveMode()
			end
		elseif inputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.One then
				self:selectKind("Beam")
			elseif input.KeyCode == Enum.KeyCode.Two then
				self:selectKind("Cable")
			elseif input.KeyCode == Enum.KeyCode.Three then
				self:selectKind("Pillar")
			elseif input.KeyCode == Enum.KeyCode.Four then
				self:toggleRemoveMode()
			elseif input.KeyCode == Enum.KeyCode.Escape then
				self:cancelSelection()
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and input == self.activeTouch then
			-- Der Finger wandert: Zeiger mitnehmen, damit die Vorschau folgt.
			self.pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processedByGui)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if input ~= self.activeTouch then
			return
		end

		local startPosition = self.touchStart
		self.activeTouch = nil
		self.touchStart = nil

		if processedByGui or not self.enabled or not startPosition then
			return
		end

		local endPosition = Vector2.new(input.Position.X, input.Position.Y)
		local moved = (endPosition - startPosition).Magnitude
		local duration = os.clock() - self.touchStartTime

		-- Nur ein kurzes, ruhiges Tippen zaehlt als Auswahl.
		if duration <= TAP_MAX_SECONDS and moved <= TAP_MAX_PIXELS then
			self.pointer = endPosition
			self:primaryAction()
		end
	end)
end

--------------------------------------------------------------------------------
-- Auswahl von aussen
--------------------------------------------------------------------------------

function BuildController:selectKind(kind: string)
	if not Config.PartTypes[kind] then
		return
	end
	self.selectedKind = kind
	self.removeMode = false
	self:cancelSelection()
	if self.onSelectionChanged then
		self.onSelectionChanged(kind)
	end
end

function BuildController:selectRemoveMode()
	self.removeMode = true
	self:cancelSelection()
	if self.onSelectionChanged then
		self.onSelectionChanged("Remove")
	end
end

function BuildController:toggleRemoveMode()
	if self.removeMode then
		self:selectKind(self.selectedKind)
	else
		self:selectRemoveMode()
	end
end

function BuildController:setPhase(phase: string)
	self.phase = phase
	if phase ~= "Build" then
		self:cancelSelection()
	end
end

-- Zeigt an, an welchem Ankerpunkt die Last nicht abgetragen werden kann.
function BuildController:setUnstableNode(snapIndex: number?)
	if not self.enabled or self.phase ~= "Build" or not snapIndex or not self.snapFolder then
		self.weakMarker.Transparency = 1
		return
	end

	local marker = self.snapFolder:FindFirstChild("Snap_" .. snapIndex)
	if marker then
		self.weakMarker.Position = (marker :: BasePart).Position
		self.weakMarker.Transparency = 0.4
	else
		self.weakMarker.Transparency = 1
	end
end

return BuildController
