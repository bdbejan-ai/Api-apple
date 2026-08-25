--[[
	Device
	------
	Erkennt, WOMIT gespielt wird: Maus und Tastatur, Touchscreen oder
	Gamepad. Davon haengen zwei Dinge ab:

	  1. Die Texte der Anleitung ("klicke" / "tippe" / "druecke A").
	  2. Die Groesse der Bedienelemente. Ein Finger braucht deutlich
	     groessere Knoepfe als ein Mauszeiger.

	WICHTIG: Das Eingabegeraet kann sich WAEHREND des Spiels aendern. Auf
	einem Laptop mit Touchscreen etwa, oder wenn jemand mitten im Spiel
	einen Controller anschliesst. Deshalb gibt es changed:Connect(...),
	worueber sich Anleitung und Oberflaeche neu einstellen koennen.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Device = {}

-- Einfaches Signal, damit sich andere Skripte anmelden koennen.
local listeners: { (string) -> () } = {}

Device.kind = "Desktop" -- "Desktop" | "Touch" | "Gamepad"

--------------------------------------------------------------------------------
-- Erkennung
--------------------------------------------------------------------------------

local function detect(): string
	-- Die zuletzt benutzte Eingabeart zaehlt am meisten: sie sagt, womit
	-- der Spieler GERADE arbeitet, nicht nur, was angeschlossen ist.
	local last = UserInputService:GetLastInputType()

	if last == Enum.UserInputType.Touch then
		return "Touch"
	end
	if last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or last == Enum.UserInputType.Gamepad3
		or last == Enum.UserInputType.Gamepad4
	then
		return "Gamepad"
	end
	if last == Enum.UserInputType.Keyboard
		or last == Enum.UserInputType.MouseButton1
		or last == Enum.UserInputType.MouseButton2
		or last == Enum.UserInputType.MouseButton3
		or last == Enum.UserInputType.MouseMovement
		or last == Enum.UserInputType.MouseWheel
	then
		return "Desktop"
	end

	-- Noch keine Eingabe erfolgt: nach vorhandener Hardware raten.
	if GuiService:IsTenFootInterface() then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return "Touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "Desktop"
end

local function setKind(newKind: string)
	if newKind == Device.kind then
		return
	end
	Device.kind = newKind
	for _, listener in listeners do
		task.spawn(listener, newKind)
	end
end

Device.kind = detect()

UserInputService.LastInputTypeChanged:Connect(function()
	setKind(detect())
end)

--------------------------------------------------------------------------------
-- Abfragen
--------------------------------------------------------------------------------

function Device.isTouch(): boolean
	return Device.kind == "Touch"
end

function Device.isGamepad(): boolean
	return Device.kind == "Gamepad"
end

function Device.isDesktop(): boolean
	return Device.kind == "Desktop"
end

-- Wird aufgerufen, wenn sich die Eingabeart aendert.
function Device.changed(listener: (string) -> ())
	table.insert(listeners, listener)
end

--------------------------------------------------------------------------------
-- Groessen
--------------------------------------------------------------------------------

--[[
	Faktor, mit dem die ganze Oberflaeche skaliert wird.
	Grundlage ist die Bildschirmbreite; auf Touchgeraeten kommt ein Zuschlag
	dazu, weil ein Finger ungenauer trifft als ein Mauszeiger.
]]
function Device.uiScale(): number
	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	local height = if camera then camera.ViewportSize.Y else 720

	local scale = math.clamp(width / 1280, 0.7, 1.4)

	-- Auf kleinen, hohen Bildschirmen (Handy hochkant) etwas groesser.
	if height > width then
		scale *= 1.15
	end
	if Device.isTouch() then
		scale *= 1.15
	end
	if Device.isGamepad() then
		-- Fernseher stehen weiter weg.
		scale *= 1.25
	end

	return math.clamp(scale, 0.7, 1.8)
end

-- Sichere Zone: auf Konsolen darf nichts ganz am Bildrand kleben.
function Device.edgeInset(): number
	if Device.isGamepad() then
		return 48
	end
	return 16
end

--------------------------------------------------------------------------------
-- Beschriftung von Tasten, geraeteabhaengig
--------------------------------------------------------------------------------

--[[
	Gibt fuer eine Spielaktion den passenden Text zurueck.
	Damit muss die Anleitung nicht selbst zwischen den Geraeten unterscheiden.
]]
function Device.actionText(action: string): string
	local kind = Device.kind

	local texts = {
		select = {
			Desktop = "klicke mit der linken Maustaste",
			Touch = "tippe kurz",
			Gamepad = "druecke A",
		},
		cancel = {
			Desktop = "klicke mit der rechten Maustaste",
			Touch = "tippe auf den Abbrechen-Knopf",
			Gamepad = "druecke B",
		},
		remove = {
			Desktop = "klicke mit der rechten Maustaste auf ein Bauteil",
			Touch = "waehle den Abriss-Knopf und tippe auf ein Bauteil",
			Gamepad = "druecke X und waehle ein Bauteil",
		},
		pan = {
			Desktop = "halte die rechte Maustaste gedrueckt und ziehe",
			Touch = "ziehe mit ZWEI Fingern",
			Gamepad = "bewege den rechten Stick",
		},
		zoom = {
			Desktop = "drehe am Mausrad",
			Touch = "ziehe zwei Finger auseinander oder zusammen",
			Gamepad = "druecke die Schultertasten LT und RT",
		},
		pointer = {
			Desktop = "der Mauszeiger",
			Touch = "dein Finger",
			Gamepad = "der Zeiger (linker Stick)",
		},
	}

	local entry = texts[action]
	if not entry then
		return ""
	end
	return entry[kind] or entry.Desktop
end

return Device
