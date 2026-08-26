--[[
	CameraController
	----------------
	Die Seitenansicht. Es gibt in diesem Spiel keine Spielfigur - die Kamera
	haengt frei im Raum und schaut waagerecht auf die Bruecke, wie bei einem
	Brettspiel von der Seite.

	SO SCHAUT DIE KAMERA
	Die ganze Bruecke liegt in der Ebene z = 0. Die Kamera steht davor bei
	einem positiven z und blickt in Richtung -z. Dadurch sieht man X nach
	rechts und Y nach oben - genau die Ansicht, in der auch der Fachwerk-
	Rechner arbeitet.

	BEDIENUNG (je nach Geraet)
	  Maus:     rechte oder mittlere Taste gedrueckt halten und ziehen,
	            Mausrad zum Zoomen
	  Touch:    mit ZWEI Fingern ziehen, zum Zoomen zwei Finger auf- oder
	            zusammenziehen
	  Gamepad:  rechter Stick schiebt, LT und RT zoomen

	Warum bei Touch zwei Finger? Ein Finger wird zum Bauen gebraucht. Wuerde
	ein Finger auch die Kamera schieben, koennte das Spiel nie sicher
	unterscheiden, ob jemand bauen oder schauen will.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local Device = require(script.Parent.Device)

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new()
	local self = setmetatable({}, CameraController)

	self.camera = workspace.CurrentCamera
	self.camera.CameraType = Enum.CameraType.Scriptable
	self.camera.FieldOfView = Config.Camera.fieldOfView

	-- Punkt, auf den die Kamera blickt.
	self.focus = Vector3.new(0, 40, 0)
	self.distance = Config.Camera.defaultDistance

	--[[
		Zoomgrenzen. Heranzoomen darf man beliebig weit; das Herauszoomen
		begrenzt setArena() auf genau die Entfernung, bei der das Level das
		Bild ausfuellt - weiter waere nur noch leere Umgebung zu sehen.
	]]
	self.minDistance = Config.Camera.minDistance
	self.maxDistance = Config.Camera.maxDistance

	-- Grenzen, ueber die nicht hinausgeschoben werden darf.
	self.bounds = nil
	self.originY = 0

	-- Zustand des Ziehens
	self.dragging = false
	self.lastDragPosition = nil
	self.touchPoints = {} -- [inputObject] = letzte Position
	self.lastPinchDistance = nil

	-- Wenn gesetzt, folgt die Kamera diesem Part (das Testfahrzeug).
	self.followPart = nil

	self:connectInput()

	self.renderConnection = RunService.RenderStepped:Connect(function(dt)
		self:update(dt)
	end)

	return self
end

--------------------------------------------------------------------------------
-- Arena einstellen
--------------------------------------------------------------------------------

--[[
	Wird aufgerufen, sobald der Spieler ein Level betritt. Die Kamera springt
	dann auf dessen Arena und passt den Zoom so an, dass die ganze Luecke
	ins Bild passt.
]]
function CameraController:setArena(originY: number, bounds, deckY: number)
	self.originY = originY
	self.bounds = bounds

	local centerX = (bounds.minX + bounds.maxX) / 2
	self.focus = Vector3.new(centerX, originY + deckY, 0)

	--[[
		Aus dem Oeffnungswinkel laesst sich ausrechnen, wie weit die Kamera
		weg sein muss, damit eine bestimmte Breite bzw. Hoehe genau ins Bild
		passt. Beides wird gebraucht: bei einem breiten Level begrenzt die
		Breite, bei einem hohen die Hoehe.
	]]
	local viewport = self.camera.ViewportSize
	local aspect = math.max(viewport.X / math.max(viewport.Y, 1), 0.5)
	local halfFov = math.rad(Config.Camera.fieldOfView / 2)

	local function distanceToFit(width: number, height: number): number
		local forWidth = (width / 2) / (math.tan(halfFov) * aspect)
		local forHeight = (height / 2) / math.tan(halfFov)
		return math.max(forWidth, forHeight)
	end

	local levelWidth = bounds.maxX - bounds.minX
	local levelHeight = bounds.maxY - bounds.minY

	-- Weiteste erlaubte Sicht: das ganze Level plus ein kleiner Rand.
	self.maxDistance = distanceToFit(levelWidth, levelHeight) * Config.Camera.zoomOutMargin
	self.minDistance = Config.Camera.minDistance
	if self.maxDistance < self.minDistance then
		self.maxDistance = self.minDistance
	end

	-- Startansicht: die Bruecke fuellt etwa zwei Drittel des Bildes.
	self.distance = math.clamp(
		distanceToFit(levelWidth * 0.62, levelHeight * 0.62),
		self.minDistance,
		self.maxDistance
	)
	self.followPart = nil
end

-- Ansicht fuer das Hauptmenue: neutral, ohne Arena.
function CameraController:setMenuView()
	self.bounds = nil
	self.followPart = nil
	self.focus = Vector3.new(0, 40, 0)
	self.distance = Config.Camera.defaultDistance

	-- Ohne Level gibt es nichts, woran sich der Zoom ausrichten koennte:
	-- hier gelten wieder die weiten Standardgrenzen aus der Config.
	self.minDistance = Config.Camera.minDistance
	self.maxDistance = Config.Camera.maxDistance
end

-- Waehrend des Tests der Kamera sagen, welchem Part sie folgen soll.
function CameraController:follow(part: BasePart?)
	self.followPart = part
end

--------------------------------------------------------------------------------
-- Schieben und Zoomen
--------------------------------------------------------------------------------

function CameraController:pan(deltaX: number, deltaY: number)
	-- Wie viele Studs entspricht ein Bildschirmpixel? Haengt vom Zoom ab.
	local viewport = self.camera.ViewportSize
	local halfFov = math.rad(Config.Camera.fieldOfView / 2)
	local worldPerPixel = (2 * self.distance * math.tan(halfFov)) / math.max(viewport.Y, 1)

	self.focus += Vector3.new(-deltaX * worldPerPixel, deltaY * worldPerPixel, 0)
	-- Von Hand geschoben heisst: nicht mehr automatisch folgen.
	self.followPart = nil
	self.hasPanned = true
	self:clampFocus()
end

function CameraController:zoom(amount: number)
	-- Die Grenzen stellt setArena() je Level ein: beliebig nah heran,
	-- aber nur so weit heraus, bis das Level das Bild ausfuellt.
	self.distance = math.clamp(self.distance + amount, self.minDistance, self.maxDistance)
	self.hasZoomed = true
end

-- Haelt den Blickpunkt in der Naehe des Levels.
function CameraController:clampFocus()
	local bounds = self.bounds
	if not bounds then
		return
	end
	local margin = Config.Camera.panMargin
	self.focus = Vector3.new(
		math.clamp(self.focus.X, bounds.minX - margin, bounds.maxX + margin),
		math.clamp(self.focus.Y, self.originY + bounds.minY - margin, self.originY + bounds.maxY + margin),
		0
	)
end

--------------------------------------------------------------------------------
-- Eingaben
--------------------------------------------------------------------------------

function CameraController:connectInput()
	----------------------------------------------------------------------------
	-- Maus: rechte oder mittlere Taste zieht, Mausrad zoomt
	----------------------------------------------------------------------------

	UserInputService.InputBegan:Connect(function(input, processedByGui)
		if processedByGui then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
		then
			self.dragging = true
			self.lastDragPosition = input.Position
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self.touchPoints[input] = input.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input, processedByGui)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if not processedByGui then
				self:zoom(-input.Position.Z * Config.Camera.zoomStepMouse)
			end
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if self.dragging and self.lastDragPosition then
				local delta = input.Position - self.lastDragPosition
				self.lastDragPosition = input.Position
				self:pan(delta.X, delta.Y)
			end
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			if self.touchPoints[input] == nil then
				return
			end
			self:handleTouchMove(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
		then
			self.dragging = false
			self.lastDragPosition = nil
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self.touchPoints[input] = nil
			-- Sobald ein Finger weg ist, faengt das Zoomen neu an.
			self.lastPinchDistance = nil
		end
	end)
end

--[[
	Touch mit zwei Fingern: der Mittelpunkt zwischen beiden Fingern schiebt
	die Kamera, der Abstand zwischen ihnen zoomt.
]]
function CameraController:handleTouchMove(input)
	local previous = self.touchPoints[input]
	self.touchPoints[input] = input.Position

	-- Alle aktuell aufliegenden Finger sammeln.
	local points = {}
	for _, position in self.touchPoints do
		table.insert(points, position)
	end

	if #points < 2 then
		-- Ein einzelner Finger baut, er schiebt nicht.
		return
	end

	-- Schieben nach der Bewegung des ausloesenden Fingers, aber nur halb so
	-- stark: sonst waere die Bewegung doppelt so schnell wie erwartet, weil
	-- beide Finger Ereignisse liefern.
	local delta = input.Position - previous
	self:pan(delta.X * 0.5, delta.Y * 0.5)

	-- Zoomen nach dem Abstand der ersten beiden Finger.
	local pinchDistance = (Vector2.new(points[1].X, points[1].Y) - Vector2.new(points[2].X, points[2].Y)).Magnitude
	if self.lastPinchDistance then
		local change = pinchDistance - self.lastPinchDistance
		self:zoom(-change * 0.4)
	end
	self.lastPinchDistance = pinchDistance
end

--------------------------------------------------------------------------------
-- Jeden Frame
--------------------------------------------------------------------------------

function CameraController:update(dt: number)
	--[[
		Roblox kann die aktive Kamera jederzeit durch eine neue ersetzen.
		Haetten wir uns die Kamera nur beim Start gemerkt, wuerden wir danach
		ein totes Objekt bewegen - das Bild bliebe stehen. Deshalb jedes Bild
		kurz nachsehen, ob es noch dieselbe ist.
	]]
	local current = workspace.CurrentCamera
	if current and current ~= self.camera then
		self.camera = current
		self.camera.FieldOfView = Config.Camera.fieldOfView
	end
	if not self.camera then
		return
	end

	----------------------------------------------------------------------------
	-- Gamepad: rechter Stick schiebt, Trigger zoomen
	----------------------------------------------------------------------------
	if Device.isGamepad() then
		local rightStick = self:gamepadAxis(Enum.KeyCode.Thumbstick2)
		if rightStick.Magnitude > 0.15 then
			-- Der Stick liefert Werte von -1 bis 1; daraus machen wir eine
			-- Geschwindigkeit in Pixeln pro Sekunde.
			self:pan(-rightStick.X * 600 * dt, rightStick.Y * 600 * dt)
		end

		local zoomIn = self:gamepadTrigger(Enum.KeyCode.ButtonR2)
		local zoomOut = self:gamepadTrigger(Enum.KeyCode.ButtonL2)
		local zoomAmount = (zoomOut - zoomIn) * Config.Camera.zoomStepGamepad * dt
		if math.abs(zoomAmount) > 0.01 then
			self:zoom(zoomAmount)
		end
	end

	----------------------------------------------------------------------------
	-- Tastatur: Pfeiltasten und WASD schieben ebenfalls
	----------------------------------------------------------------------------
	if Device.isDesktop() and not UserInputService:GetFocusedTextBox() then
		local move = Vector2.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			move += Vector2.new(1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			move += Vector2.new(-1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			move += Vector2.new(0, 1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			move += Vector2.new(0, -1)
		end
		if move.Magnitude > 0 then
			self:pan(move.X * 700 * dt, move.Y * 700 * dt)
		end
	end

	----------------------------------------------------------------------------
	-- Dem Fahrzeug folgen
	----------------------------------------------------------------------------
	if self.followPart and self.followPart.Parent then
		local target = Vector3.new(self.followPart.Position.X, self.focus.Y, 0)
		local strength = math.clamp(Config.Test.cameraFollow * dt * 4, 0, 1)
		self.focus = self.focus:Lerp(target, strength)
		self:clampFocus()
	end

	----------------------------------------------------------------------------
	-- Kamera setzen
	----------------------------------------------------------------------------
	-- Roblox' eigenes Kamera-Skript kann den Typ zurueckstellen. Deshalb
	-- setzen wir ihn jedes Bild neu, sonst springt die Ansicht gelegentlich.
	if self.camera.CameraType ~= Enum.CameraType.Scriptable then
		self.camera.CameraType = Enum.CameraType.Scriptable
	end

	local eye = self.focus + Vector3.new(0, 0, self.distance)
	self.camera.CFrame = CFrame.lookAt(eye, self.focus)
end

--------------------------------------------------------------------------------
-- Gamepad-Hilfen
--------------------------------------------------------------------------------

function CameraController:gamepadAxis(keyCode: Enum.KeyCode): Vector2
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == keyCode then
			return Vector2.new(state.Position.X, state.Position.Y)
		end
	end
	return Vector2.zero
end

function CameraController:gamepadTrigger(keyCode: Enum.KeyCode): number
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == keyCode then
			return state.Position.Z
		end
	end
	return 0
end

return CameraController
