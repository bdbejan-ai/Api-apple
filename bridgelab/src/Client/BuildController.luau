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

	WIE AUS DEM ZEIGEPUNKT EIN RASTERPUNKT WIRD
	Frueher wurde der naechstgelegene ANKER gesucht - es gab ja nur eine
	Handvoll erlaubter Punkte. Beim freien Bauen ist jeder Rasterpunkt
	erlaubt, und die Rechnung wird dadurch sogar einfacher und genauer:

	  1. Vom Zeigepunkt geht ein Strahl in die Welt.
	  2. Die Bauebene ist eine senkrechte Ebene bei z = 0 - die Bruecke ist
	     flach, die Kamera schaut von der Seite darauf.
	  3. Der Schnittpunkt von Strahl und Ebene ist der gemeinte Punkt.
	  4. Dieser Punkt wird auf das 2-Studs-Raster gerundet.

	Das trifft immer, unabhaengig von Kameraposition und Zoomstufe, und es
	kann nichts verdecken - anders als bei einem Raycast auf Bauteile.

	ABLAUF BEIM BAUEN: ZIEHEN
	  1. Baustoff in der Leiste waehlen.
	  2. Maustaste druecken und ZIEHEN - die Vorschau folgt mit.
	  3. Loslassen -> der Wunsch geht an den Server.
	Der Server entscheidet, ob das Bauteil wirklich entsteht.

	Warum Ziehen und nicht zweimal Klicken: beim Ziehen sieht man waehrend
	der ganzen Bewegung, was entsteht, und ein Versehen bricht man einfach
	ab, indem man wieder zum Anfangspunkt zurueckzieht. Genau so baut man
	auch im grossen Vorbild.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)
local Materials = require(Shared.Materials)
local Terrain = require(Shared.Terrain)

local Device = require(script.Parent.Device)

local BuildController = {}
BuildController.__index = BuildController

--[[
	Kuerzester Abstand zwischen einem Strahl und einer Strecke.

	Gebraucht wird das beim Abreissen: welches Bauteil liegt unter dem
	Zeiger? Ein Raycast waere ungenau, weil er immer nur das vorderste
	sichtbare Teil trifft - bei duennen Seilen und sich kreuzenden Streben
	trifft man damit staendig das Falsche. Der echte Abstand zur Bauteil-
	ACHSE ist dagegen eindeutig.

	Strahl:  P(s) = origin + s * direction   (s >= 0, direction normiert)
	Strecke: Q(t) = a + t * (b - a)          (t zwischen 0 und 1)
	Gesucht ist das kleinste |P - Q|.
]]
local function rayToSegmentDistance(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3): (number, number)
	local ab = b - a
	local w0 = origin - a

	local bDot = direction:Dot(ab)
	local c = ab:Dot(ab)
	local dd = direction:Dot(w0)
	local e = ab:Dot(w0)

	local denom = c - bDot * bDot

	local t
	if math.abs(denom) < 1e-6 then
		-- Strahl und Strecke sind fast parallel: Anfang der Strecke nehmen.
		t = 0
	else
		t = (e - bDot * dd) / denom
	end
	t = math.clamp(t, 0, 1)

	-- Passenden Punkt auf dem Strahl dazu suchen; hinter die Kamera darf er nicht.
	local s = math.max(bDot * t - dd, 0)

	local onRay = origin + direction * s
	local onSegment = a + ab * t
	return (onRay - onSegment).Magnitude, s
end

--------------------------------------------------------------------------------

function BuildController.new()
	local self = setmetatable({}, BuildController)

	self.player = Players.LocalPlayer
	self.camera = workspace.CurrentCamera

	self.selectedMaterial = "Road"
	-- Welcher Hydraulikphase ein neuer Zylinder angehoert (siehe BuildHud).
	self.buildPhase = 1
	self.removeMode = false
	self.phase = "Idle" -- "Idle" (kein Level) | "Build" | "Test" | "Result"
	self.enabled = false

	self.memberFolder = nil
	self.level = nil -- Baubereich, Anker, Gelaende - kommt vom Server
	self.origin = Vector3.zero
	self.budgetLeft = 0

	-- Zeigepunkt auf dem Bildschirm
	self.pointer = Vector2.new(0, 0)
	self.gamepadCursor = Vector2.new(0, 0)

	-- Ziehen
	self.dragging = false
	self.dragStart = nil -- { x, y } in Levelkoordinaten
	self.activeTouch = nil

	-- Rueckmeldungen nach aussen (werden von init.client gesetzt)
	self.onPlaceRequest = nil -- (material, ax, ay, bx, by, phase)
	self.onRemoveRequest = nil -- (memberId)
	self.onSelectionChanged = nil -- (material oder "Remove")
	self.onDragChanged = nil -- (true/false) - fuer die Anleitung

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

	-- Rasterpunkt unter dem Zeiger
	self.hoverMarker = marker("HoverMarker", Color3.fromRGB(255, 255, 255), 1.7)
	-- Anfangspunkt des laufenden Zuges
	self.startMarker = marker("StartMarker", Color3.fromRGB(120, 220, 255), 2.0)
	-- Stelle, an der die Konstruktion nicht ausgesteift ist
	self.weakMarker = marker("WeakSpotMarker", Color3.fromRGB(255, 90, 70), 3.2)

	--[[
		Hervorhebung des Bauteils, das beim naechsten Klick verschwindet.
		Ohne sie raet man beim Abreissen - gerade wenn sich Streben kreuzen.
	]]
	local highlight = Instance.new("Highlight")
	highlight.Name = "RemoveHighlight"
	highlight.FillColor = Color3.fromRGB(235, 80, 70)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(255, 150, 140)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = nil
	highlight.Parent = workspace
	self.removeHighlight = highlight

	-- Vorschaulinie waehrend des Ziehens
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
-- Level und Arena verbinden
--------------------------------------------------------------------------------

--[[
	Sagt dem Controller, wo gebaut wird und was dort erlaubt ist.

	Der Client bekommt Baubereich, Anker und Gelaende, damit die Vorschau
	sofort gruen oder rot sein kann - ohne auf eine Antwort vom Server zu
	warten. Entschieden wird trotzdem nur auf dem Server; das hier ist
	ausschliesslich Anzeige.
]]
function BuildController:setLevel(info, originY: number)
	self.level = info
	self.origin = Vector3.new(0, originY or 0, 0)
	self:cancelDrag()
end

function BuildController:setArena(arenaFolder: Instance?)
	self.memberFolder = if arenaFolder then arenaFolder:FindFirstChild("Bauteile") else nil
	self:cancelDrag()
end

function BuildController:setBudgetLeft(value: number)
	self.budgetLeft = value or 0
end

function BuildController:setEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled then
		self:cancelDrag()
		self:hideMarkers()
	end
	self.cursorGui.Enabled = enabled and Device.isGamepad()
end

--[[
	Kraeftig rot im Abrissmodus ("das ist gleich weg"), dezent hell sonst
	("hier wuerde ein Rechtsklick hintreffen").
]]
function BuildController:setHighlightStyle(removing: boolean)
	if removing then
		self.removeHighlight.FillColor = Color3.fromRGB(235, 80, 70)
		self.removeHighlight.FillTransparency = 0.55
		self.removeHighlight.OutlineColor = Color3.fromRGB(255, 150, 140)
	else
		self.removeHighlight.FillColor = Color3.fromRGB(210, 225, 255)
		self.removeHighlight.FillTransparency = 0.85
		self.removeHighlight.OutlineColor = Color3.fromRGB(180, 210, 255)
	end
end

function BuildController:hideMarkers()
	self.hoverMarker.Transparency = 1
	self.startMarker.Transparency = 1
	self.preview.Transparency = 1
	self.weakMarker.Transparency = 1
	self.removeHighlight.Adornee = nil
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

--------------------------------------------------------------------------------
-- Vom Bildschirm auf das Raster
--------------------------------------------------------------------------------

--[[
	Schneidet den Sichtstrahl mit der Bauebene und rundet auf das Raster.

	Die Bauebene ist die senkrechte Ebene, in der die ganze Bruecke liegt.
	Rueckgabe: x, y in LEVELKOORDINATEN (also ohne den Arena-Versatz), oder
	nil, wenn der Strahl die Ebene nicht trifft.
]]
function BuildController:snappedPointUnderPointer(): (number?, number?)
	if not self.level then
		return nil, nil
	end

	local ray = self.camera:ViewportPointToRay(self.pointer.X, self.pointer.Y)
	local direction = ray.Direction.Unit
	local planeZ = self.level.z or 0

	--[[
		Blickt die Kamera fast parallel zur Ebene, gibt es keinen brauchbaren
		Schnittpunkt. In der festen Seitenansicht kann das eigentlich nicht
		vorkommen - aber ein Ergebnis von "unendlich weit weg" waere so
		schaedlich, dass die Abfrage stehen bleibt.
	]]
	if math.abs(direction.Z) < 1e-4 then
		return nil, nil
	end

	local t = (planeZ - ray.Origin.Z) / direction.Z
	if t < 0 then
		return nil, nil -- Die Ebene liegt hinter der Kamera.
	end

	local hit = ray.Origin + direction * t
	local x = Config.snapToGrid(hit.X)
	local y = Config.snapToGrid(hit.Y - self.origin.Y)
	return x, y
end

-- Levelkoordinate -> Weltkoordinate
function BuildController:toWorld(x: number, y: number): Vector3
	return self.origin + Vector3.new(x, y, self.level and self.level.z or 0)
end

--[[
	Sucht das Bauteil, dessen Achse dem Zeigestrahl am naechsten liegt.
	Rueckgabe: Nummer des Bauteils und sein Model (fuer die Hervorhebung).
]]
function BuildController:findMemberUnderPointer(): (number?, Instance?)
	if not self.memberFolder then
		return nil, nil
	end

	local ray = self.camera:ViewportPointToRay(self.pointer.X, self.pointer.Y)
	local origin = ray.Origin
	local direction = ray.Direction.Unit
	local touch = Device.isTouch()

	local bestId, bestModel = nil, nil
	local bestDistance = math.huge

	for _, model in self.memberFolder:GetChildren() do
		local id = model:GetAttribute("MemberId")
		local pointA = model:GetAttribute("PointA")
		local pointB = model:GetAttribute("PointB")
		if not id or typeof(pointA) ~= "Vector3" or typeof(pointB) ~= "Vector3" then
			continue
		end

		local distance, along = rayToSegmentDistance(origin, direction, pointA, pointB)
		if along < 1 or along > 600 then
			continue
		end

		-- Der Fangbereich waechst mit der Entfernung mit, damit weit entfernte
		-- Bauteile nicht unmoeglich zu treffen sind.
		local tolerance = math.clamp(along * (if touch then 0.035 else 0.022), if touch then 2 else 1.2, if touch then 7 else 5)
		if distance <= tolerance and distance < bestDistance then
			bestDistance = distance
			bestId = id
			bestModel = model
		end
	end

	return bestId, bestModel
end

--------------------------------------------------------------------------------
-- Darf hier gebaut werden? (nur fuer die Vorschaufarbe)
--------------------------------------------------------------------------------

--[[
	Dieselben Regeln wie in Structure:canPlace auf dem Server, aber ohne die
	Bauteilliste - der Client kennt sie nicht vollstaendig.

	Es geht hier NUR um die Farbe der Vorschau. Der Server prueft alles noch
	einmal und entscheidet allein. Doppelt geprueft wird trotzdem, weil eine
	Vorschau, die erst nach der Antwort vom Server rot wird, zu spaet kommt:
	da hat man schon losgelassen.
]]
function BuildController:previewProblem(ax: number, ay: number, bx: number, by: number): string?
	local level = self.level
	if not level then
		return "Kein Level"
	end

	local spec = Materials.get(self.selectedMaterial)
	if not spec then
		return "Unbekannter Baustoff"
	end

	local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	if length < spec.minLength - 0.01 then
		return string.format("zu kurz (min %d)", spec.minLength)
	end
	if length > spec.maxLength + 0.01 then
		return string.format("zu lang (max %d)", spec.maxLength)
	end

	local area = level.buildArea
	local function insideArea(x: number, y: number): boolean
		-- Anker duerfen ausserhalb liegen: sie sind der Anschluss ans Ufer.
		for _, anchor in level.anchors do
			if math.abs(anchor.x - x) < 0.51 and math.abs(anchor.y - y) < 0.51 then
				return true
			end
		end
		return x >= area.minX - 0.01
			and x <= area.maxX + 0.01
			and y >= area.minY - 0.01
			and y <= area.maxY + 0.01
	end

	if not insideArea(ax, ay) or not insideArea(bx, by) then
		return "ausserhalb des Baubereichs"
	end

	if Terrain.segmentBlocked(level.terrain, ax, ay, bx, by) then
		return "laeuft durch den Felsen"
	end

	if Materials.cost(self.selectedMaterial, length) > self.budgetLeft then
		return "Budget reicht nicht"
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
		-- Im Abrissmodus wird nicht der Rasterpunkt, sondern das Bauteil
		-- hervorgehoben, das beim naechsten Klick verschwindet.
		self.hoverMarker.Transparency = 1
		self.preview.Transparency = 1
		self.startMarker.Transparency = 1

		local _, model = self:findMemberUnderPointer()
		self:setHighlightStyle(true)
		self.removeHighlight.Adornee = model
		return
	end

	local x, y = self:snappedPointUnderPointer()

	--[[
		Ausserhalb des Ziehens wird ein Bauteil dezent markiert: das sagt
		"ein Rechtsklick wuerde das hier treffen". Waehrend des Ziehens
		waere das nur Unruhe im Bild.
	]]
	if not self.dragging then
		local _, model = self:findMemberUnderPointer()
		self:setHighlightStyle(false)
		self.removeHighlight.Adornee = model
	else
		self.removeHighlight.Adornee = nil
	end

	if x and y then
		self.hoverMarker.Position = self:toWorld(x, y)
		self.hoverMarker.Transparency = 0.45
	else
		self.hoverMarker.Transparency = 1
	end

	-- Vorschaulinie waehrend des Ziehens
	if self.dragging and self.dragStart then
		local start = self.dragStart
		local startWorld = self:toWorld(start.x, start.y)
		self.startMarker.Position = startWorld
		self.startMarker.Transparency = 0.3

		if x and y and (x ~= start.x or y ~= start.y) then
			local endWorld = self:toWorld(x, y)
			local delta = endWorld - startWorld
			local length = delta.Magnitude
			local problem = self:previewProblem(start.x, start.y, x, y)

			-- Bei senkrechten Bauteilen darf der Hilfsvektor nicht (0,1,0) sein,
			-- sonst liefert CFrame.lookAt kein brauchbares Ergebnis.
			local up = if math.abs(delta.Unit.Y) > 0.999 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)

			self.preview.Size = Vector3.new(0.5, 0.5, length)
			self.preview.CFrame = CFrame.lookAt(startWorld + delta / 2, endWorld, up)
			self.preview.Color = if problem then Color3.fromRGB(235, 90, 80) else Color3.fromRGB(120, 235, 150)
			self.preview.Transparency = 0.2
			self.previewProblemText = problem
		else
			self.preview.Transparency = 1
			self.previewProblemText = nil
		end
	else
		self.startMarker.Transparency = 1
		self.preview.Transparency = 1
		self.previewProblemText = nil
	end
end

--------------------------------------------------------------------------------
-- Ziehen
--------------------------------------------------------------------------------

function BuildController:beginDrag()
	if not self.enabled or self.phase ~= "Build" or self.removeMode then
		return
	end

	local x, y = self:snappedPointUnderPointer()
	if not x or not y then
		return
	end

	self.dragging = true
	self.dragStart = { x = x, y = y }
	if self.onDragChanged then
		self.onDragChanged(true)
	end
end

function BuildController:endDrag()
	if not self.dragging or not self.dragStart then
		self:cancelDrag()
		return
	end

	local start = self.dragStart
	local x, y = self:snappedPointUnderPointer()
	self:cancelDrag()

	if not x or not y then
		return
	end

	--[[
		Ein sehr kurzer Zug ist kein Bauversuch, sondern ein Klick. Ohne diese
		Schwelle entstuende bei jedem versehentlichen Klick ein winziges
		Bauteil oder eine Fehlermeldung.
	]]
	local length = math.sqrt((x - start.x) ^ 2 + (y - start.y) ^ 2)
	if length < Config.Build.minDragLength then
		return
	end

	if self.onPlaceRequest then
		self.onPlaceRequest(self.selectedMaterial, start.x, start.y, x, y, self.buildPhase)
	end
end

function BuildController:cancelDrag()
	local was = self.dragging
	self.dragging = false
	self.dragStart = nil
	self.preview.Transparency = 1
	self.startMarker.Transparency = 1
	if was and self.onDragChanged then
		self.onDragChanged(false)
	end
end

-- Ein "Entfernen" - egal von welchem Geraet.
function BuildController:removeUnderPointer()
	if not self.enabled or self.phase ~= "Build" then
		return
	end

	-- Laeuft gerade ein Zug, wird der zuerst abgebrochen.
	if self.dragging then
		self:cancelDrag()
		return
	end

	local memberId = self:findMemberUnderPointer()
	if memberId and self.onRemoveRequest then
		self.onRemoveRequest(memberId)
		self.removeHighlight.Adornee = nil
	end
end

--------------------------------------------------------------------------------
-- Eingaben
--------------------------------------------------------------------------------

function BuildController:connectInput()
	--[[
		Alle drei Geraete bedienen dasselbe Ziehen:
		  Maus    linke Taste halten
		  Touch   einen Finger aufsetzen und ziehen
		  Gamepad A gedrueckt halten

		Bei Touch zaehlt nur der ERSTE Finger. Kommt ein zweiter dazu, ist
		das Kamerabedienung (siehe CameraController), und der laufende Zug
		wird abgebrochen - sonst entstuende beim Zoomen aus Versehen ein
		Bauteil.
	]]
	UserInputService.InputBegan:Connect(function(input, processedByGui)
		if processedByGui or not self.enabled then
			return
		end

		local inputType = input.UserInputType

		if inputType == Enum.UserInputType.MouseButton1 then
			if self.removeMode then
				self:removeUnderPointer()
			else
				self:beginDrag()
			end
		elseif inputType == Enum.UserInputType.MouseButton2 then
			self:removeUnderPointer()
		elseif inputType == Enum.UserInputType.Touch then
			if self.activeTouch == nil then
				self.activeTouch = input
				self.pointer = Vector2.new(input.Position.X, input.Position.Y)
				if self.removeMode then
					self:removeUnderPointer()
				else
					self:beginDrag()
				end
			else
				-- Zweiter Finger: das gehoert der Kamera.
				self.activeTouch = nil
				self:cancelDrag()
			end
		elseif inputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.ButtonA then
				if self.removeMode then
					self:removeUnderPointer()
				else
					self:beginDrag()
				end
			elseif input.KeyCode == Enum.KeyCode.ButtonB then
				self:removeUnderPointer()
			elseif input.KeyCode == Enum.KeyCode.ButtonX then
				self:toggleRemoveMode()
			end
		elseif inputType == Enum.UserInputType.Keyboard then
			local index = table.find({
				Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
				Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
				Enum.KeyCode.Seven,
			}, input.KeyCode)
			if index and Materials.order[index] then
				self:selectMaterial(Materials.order[index])
			elseif input.KeyCode == Enum.KeyCode.X then
				self:toggleRemoveMode()
			elseif input.KeyCode == Enum.KeyCode.Escape then
				self:cancelDrag()
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
		local inputType = input.UserInputType

		if inputType == Enum.UserInputType.MouseButton1 then
			if self.dragging then
				self:endDrag()
			end
		elseif inputType == Enum.UserInputType.Touch then
			if input == self.activeTouch then
				self.activeTouch = nil
				self.pointer = Vector2.new(input.Position.X, input.Position.Y)
				if self.dragging then
					if processedByGui then
						self:cancelDrag()
					else
						self:endDrag()
					end
				end
			end
		elseif inputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.ButtonA and self.dragging then
				self:endDrag()
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Auswahl von aussen
--------------------------------------------------------------------------------

function BuildController:selectMaterial(key: string)
	if not Materials.exists(key) then
		return
	end
	-- Baustoffe, die das Level gar nicht anbietet, gibt es hier nicht.
	if self.level and self.level.materials and not table.find(self.level.materials, key) then
		return
	end

	self.selectedMaterial = key
	self.removeMode = false
	self:cancelDrag()
	if self.onSelectionChanged then
		self.onSelectionChanged(key)
	end
end

function BuildController:selectRemoveMode()
	self.removeMode = true
	self:cancelDrag()
	if self.onSelectionChanged then
		self.onSelectionChanged("Remove")
	end
end

function BuildController:toggleRemoveMode()
	if self.removeMode then
		self:selectMaterial(self.selectedMaterial)
	else
		self:selectRemoveMode()
	end
end

-- Phase fuer neue Hydraulikzylinder (vom HUD gesetzt).
function BuildController:setBuildPhase(phase: number)
	self.buildPhase = math.clamp(math.round(phase), 1, Config.Hydraulics.phaseCount)
end

function BuildController:setPhase(phase: string)
	self.phase = phase
	if phase ~= "Build" then
		self:cancelDrag()
	end
end

--[[
	Zeigt an, an welchem Knoten die Last nicht abgetragen werden kann.
	Der Schluessel hat die Form "gx:gy" - das sind Rasterschritte, keine Studs.
]]
function BuildController:setUnstableJoint(key: string?)
	if not self.enabled or self.phase ~= "Build" or not key or not self.level then
		self.weakMarker.Transparency = 1
		return
	end

	local gx, gy = string.match(key, "^(-?%d+):(-?%d+)$")
	if not gx or not gy then
		self.weakMarker.Transparency = 1
		return
	end

	local grid = Config.Build.gridSize
	self.weakMarker.Position = self:toWorld(tonumber(gx) * grid, tonumber(gy) * grid)
	self.weakMarker.Transparency = 0.4
end

return BuildController
