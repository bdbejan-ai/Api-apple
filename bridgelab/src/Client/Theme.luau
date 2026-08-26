--[[
	Theme
	-----
	Farben, Schriften und kleine Bausteine fuer die Oberflaeche.

	Warum eine eigene Datei? Damit alle Fenster gleich aussehen und man eine
	Farbe nur an EINER Stelle aendern muss. Die Funktionen hier erzeugen
	fertige Bedienelemente, damit in den GUI-Dateien nicht ueberall dieselben
	zehn Zeilen stehen.
]]

local Theme = {}

--------------------------------------------------------------------------------
-- Farben
--------------------------------------------------------------------------------

Theme.colors = {
	background = Color3.fromRGB(18, 20, 26),
	panel = Color3.fromRGB(30, 33, 42),
	panelLight = Color3.fromRGB(42, 46, 58),
	border = Color3.fromRGB(58, 63, 78),

	text = Color3.fromRGB(238, 240, 246),
	textDim = Color3.fromRGB(158, 165, 182),

	accent = Color3.fromRGB(86, 156, 248),
	accentDark = Color3.fromRGB(52, 108, 190),

	success = Color3.fromRGB(78, 196, 118),
	warning = Color3.fromRGB(238, 186, 68),
	danger = Color3.fromRGB(226, 82, 70),
	robux = Color3.fromRGB(126, 206, 130),
}

--[[
	JEDE WELT HAT IHRE EIGENE FARBE

	Im Menue lagen vorher zwoelf gleich aussehende Karten untereinander. Mit
	einer Farbe je Welt sieht man auf einen Blick, wo ein neuer Abschnitt
	anfaengt - und die Liste wirkt nicht mehr wie eine Tabelle.

	Die Farben sind bewusst gedaempft: sie sollen die Karten gliedern, nicht
	mit der Schwierigkeitsanzeige um Aufmerksamkeit streiten.
]]
Theme.worldColors = {
	Grundlagen = Color3.fromRGB(96, 164, 226),
	Werkstoffe = Color3.fromRGB(216, 158, 84),
	Bewegliches = Color3.fromRGB(158, 132, 220),
}

function Theme.worldColor(world: string?): Color3
	return (world and Theme.worldColors[world]) or Theme.colors.accent
end

Theme.font = Enum.Font.Gotham
Theme.fontBold = Enum.Font.GothamBold

--------------------------------------------------------------------------------
-- Bausteine
--------------------------------------------------------------------------------

-- Abgerundete Ecken an ein Element haengen.
function Theme.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

-- Duenner Rahmen.
function Theme.stroke(parent: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.colors.border
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- Innenabstand auf allen Seiten.
function Theme.padding(parent: Instance, amount: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = parent
	return padding
end

--[[
	Ein Fenster / eine Karte.
	Rueckgabe: das Frame.
]]
--[[
	Ein Fenster / eine Karte.

	WARUM EIN VERLAUF UND KEIN SCHLAGSCHATTEN
	Flache, einfarbige Kaesten wirken wie ausgeschnittenes Papier. Ueblich
	waere ein Schlagschatten - den gibt es in Roblox aber nicht, und die
	ueblichen Nachbauten brauchen ein zusaetzliches Element HINTER dem
	Fenster. Das geht nur, wenn man die Zeichenreihenfolge der ganzen
	Oberflaeche auf "Global" umstellt, und das wuerde jede bestehende
	Ueberlagerung durcheinanderbringen.

	Ein senkrechter Verlauf und eine helle Kante oben erzeugen dieselbe Tiefe,
	brauchen aber nichts dahinter - sie sind Kinder des Fensters und wandern
	mit, wenn es verschoben wird.
]]
function Theme.panel(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 10)
	Theme.stroke(frame)

	local gradient = Instance.new("UIGradient")
	gradient.Name = "Tiefe"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(206, 210, 222)),
	})
	gradient.Parent = frame

	-- Helle Kante ganz oben: laesst das Fenster leicht gewoelbt wirken.
	local highlight = Instance.new("Frame")
	highlight.Name = "Kante"
	highlight.Size = UDim2.new(1, -20, 0, 1)
	highlight.Position = UDim2.fromOffset(10, 1)
	highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	highlight.BackgroundTransparency = 0.86
	highlight.BorderSizePixel = 0
	highlight.Parent = frame

	return frame
end

--[[
	Ein Textfeld.
	options: { size, position, text, textSize, bold, color, align }
]]
function Theme.label(parent: Instance, name: string, options): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = options.size or UDim2.fromScale(1, 1)
	label.Position = options.position or UDim2.fromOffset(0, 0)
	label.Font = if options.bold then Theme.fontBold else Theme.font
	label.TextSize = options.textSize or 15
	label.TextColor3 = options.color or Theme.colors.text
	label.Text = options.text or ""
	label.TextXAlignment = options.align or Enum.TextXAlignment.Left
	label.TextYAlignment = options.alignY or Enum.TextYAlignment.Center
	label.TextWrapped = options.wrapped == true
	label.RichText = options.richText == true
	label.Parent = parent
	return label
end

--[[
	Ein Knopf.
	options: { size, position, text, color, textColor, textSize, bold }
]]
function Theme.button(parent: Instance, name: string, options): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = options.size or UDim2.fromOffset(120, 40)
	button.Position = options.position or UDim2.fromOffset(0, 0)
	button.BackgroundColor3 = options.color or Theme.colors.panelLight
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = if options.bold ~= false then Theme.fontBold else Theme.font
	button.TextSize = options.textSize or 15
	button.TextColor3 = options.textColor or Theme.colors.text
	button.Text = options.text or ""
	button.Parent = parent
	Theme.corner(button, options.radius or 8)
	return button
end

--------------------------------------------------------------------------------
-- Kleine Helfer
--------------------------------------------------------------------------------

-- Setzt Farbe und Textfarbe eines Knopfes auf einmal.
function Theme.paint(button: TextButton, background: Color3, textColor: Color3?)
	button.BackgroundColor3 = background
	if textColor then
		button.TextColor3 = textColor
	end
end

-- Sterne fuer die Schwierigkeit, z. B. 3 von 5.
function Theme.stars(count: number, maximum: number): string
	count = math.clamp(count, 0, maximum)
	return string.rep("●", count) .. string.rep("○", maximum - count)
end

return Theme
