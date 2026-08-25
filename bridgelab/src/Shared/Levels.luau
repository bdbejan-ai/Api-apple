--[[
	Levels
	------
	Alle Level des Spiels an einer Stelle.

	Jedes Level beschreibt nur ZAHLEN - keine Bauteile, keine Instanzen.
	Aus diesen Zahlen erzeugt makeLevel() automatisch das Raster der
	Ankerpunkte. Wer ein neues Level bauen will, kopiert einfach einen
	Eintrag aus der Liste unten und aendert die Werte.

	AUFBAU EINES LEVELS IN DER SEITENANSICHT
	(X nach rechts, Y nach oben, Z ist immer 0 - alles liegt in einer Ebene)

	        upper  o---o---o---o---o---o---o---o---o---o---o        obere Reihe
	                                                                (Tuerme, Abspannungen)

	        deck   #---o---o---o---o---o---o---o---o---o---#        Fahrbahnhoehe
	              |###|                Luecke               |###|   (hier faehrt das Fahrzeug)
	              |###|                                     |###|
	        ground |##| #   #   #   #   #   #   #   #   #  #|###|   Grund der Schlucht
	              +--------------------------------------------+

	  #  = fester Ankerpunkt (unbeweglich, am Boden verankert)
	  o  = freier Ankerpunkt (kann sich unter Last bewegen)

	DIE DREI REIHEN
	  "deck"    Hoehe der Fahrbahn     -> hier faehrt das Testfahrzeug
	  "upper"   darueber               -> fuer Tuerme, Boegen, Abspannungen
	  "ground"  am Grund der Schlucht  -> Fusspunkte fuer Stuetzen
]]

local Levels = {}

--------------------------------------------------------------------------------
-- Bauplan eines Levels aus den Eckdaten erzeugen
--------------------------------------------------------------------------------

--[[
	Erwartet eine Tabelle mit den Eckdaten und ergaenzt daraus alles Uebrige,
	vor allem die Liste der Ankerpunkte.
]]
local function makeLevel(def)
	local level = def

	level.z = 0 -- Die ganze Bruecke liegt in der Ebene z = 0.

	-- Die Luecke liegt immer mittig um x = 0.
	level.gapLeftX = -def.gapWidth / 2
	level.gapRightX = def.gapWidth / 2

	level.snapSpacing = def.snapSpacing or 4
	level.platformLength = def.platformLength or 60
	level.platformDepth = def.platformDepth or 40

	--[[
		Wie weit das Raster in die festen Plattformen hineinreicht.
		Ein Stueck Ueberlappung ist noetig, damit die Fahrbahn ueberhaupt
		irgendwo fest verankert werden kann.
	]]
	local overlap = level.snapSpacing
	local deckHalf = level.gapRightX + overlap
	local upperHalf = level.gapRightX + overlap

	----------------------------------------------------------------------------
	-- Ankerpunkte erzeugen
	----------------------------------------------------------------------------

	level.snapPoints = {}

	local function addSnapPoint(row: string, x: number, y: number, fixed: boolean)
		local list = level.snapPoints
		list[#list + 1] = {
			id = #list + 1,
			row = row,
			position = Vector3.new(x, y, level.z),
			fixed = fixed,
		}
	end

	-- Fahrbahnreihe. Alles ab dem Rand der Luecke steht auf festem Boden.
	for x = -deckHalf, deckHalf, level.snapSpacing do
		addSnapPoint("deck", x, level.deckY, math.abs(x) >= level.gapRightX)
	end

	-- Obere Reihe. Nur die beiden aeussersten Punkte sind fest - sie sitzen
	-- auf den Pylonen, die auf den Plattformen stehen.
	for x = -upperHalf, upperHalf, level.snapSpacing do
		addSnapPoint("upper", x, level.upperY, math.abs(x) >= upperHalf - 0.01)
	end

	-- Bodenreihe im Schluchtgrund. Alle Punkte sind fest.
	for x = level.gapLeftX, level.gapRightX, level.snapSpacing do
		addSnapPoint("ground", x, level.groundY, true)
	end

	----------------------------------------------------------------------------
	-- Fahrzeug: Start und Ziel ergeben sich aus der Plattformlaenge
	----------------------------------------------------------------------------

	level.vehicle.startX = level.gapLeftX - 14
	level.vehicle.finishX = level.gapRightX + 14

	----------------------------------------------------------------------------
	-- Abgeleitete Angaben
	----------------------------------------------------------------------------

	-- Erlaubte Bauteile: nil bedeutet "alle".
	level.allowedParts = def.allowedParts

	-- Wie viele Tipps in diesem Level gratis sind.
	-- Faustregel im Spiel: leichte Level (Schwierigkeit 1-3) haben einen
	-- Gratis-Tipp, schwere Level (4-5) kosten schon beim ersten Tipp.
	level.freeHints = def.freeHints or (if def.difficulty <= 3 then 1 else 0)

	-- Erlaubt ein Bauteil? Praktisch fuer Server UND Oberflaeche.
	function level.allowsPart(kind: string): boolean
		if not level.allowedParts then
			return true
		end
		return table.find(level.allowedParts, kind) ~= nil
	end

	function level.getSnapPoint(id: number)
		return level.snapPoints[id]
	end

	-- Waagerechte Mitte und Ausdehnung - die Kamera braucht das.
	level.bounds = {
		minX = level.gapLeftX - level.platformLength,
		maxX = level.gapRightX + level.platformLength,
		minY = 0,
		maxY = level.upperY + 10,
	}

	return level
end

--------------------------------------------------------------------------------
-- Die Level
--------------------------------------------------------------------------------

--[[
	ANNAHME zur Fahrgeschwindigkeit: Alle Level fahren mit 3.2 Studs pro
	Sekunde. Das ist bewusst langsam (frueher waren es 8), damit man beim
	Test in Ruhe verfolgen kann, welches Bauteil sich wie stark belastet.
	Die Zeitlimits sind entsprechend grosszuegig gesetzt.
]]

Levels.list = {
	makeLevel({
		id = "Level1",
		displayName = "Die erste Luecke",
		subtitle = "Lerne die Grundlagen kennen.",
		difficulty = 1,

		budget = 200,
		timeLimit = 60,
		maxDropStuds = 10,

		gapWidth = 40,
		deckY = 40,
		upperY = 48,
		groundY = 20,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6), speed = 3.2 },

		hints = {
			"Eine gerade Fahrbahn traegt sich nicht selbst. Jeder Fahrbahnknoten, der frei in der Luft haengt, braucht Abstuetzung von unten - sonst kann die Last nirgendwo hin.",
			"Ein Balken darf bis zu 10 Studs lang sein. Du kannst also einen Ankerpunkt ueberspringen und gleich 8 Studs weit spannen. Das halbiert die Zahl der Balken und damit die Kosten.",
			"Loesung: fuenf Balken zu je 8 Studs bilden die Fahrbahn (50 Einheiten). Darunter vier Stuetzen bis zum Schluchtgrund (60 Einheiten). Zusammen 110 von 200.",
		},
	}),

	makeLevel({
		id = "Level2",
		displayName = "Tiefer Graben",
		subtitle = "Der Boden liegt weiter unten - die Stuetzen werden lang.",
		difficulty = 2,

		budget = 240,
		timeLimit = 70,
		maxDropStuds = 10,

		gapWidth = 48,
		deckY = 44,
		upperY = 52,
		groundY = 12,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6), speed = 3.2 },

		hints = {
			"Bis zum Grund sind es 32 Studs. Eine Stuetze schafft hoechstens 40 - es reicht also gerade, aber die Stuetzen werden schwer und ziehen mit ihrem Eigengewicht an der Fahrbahn.",
			"Spare bei der Fahrbahn, nicht bei den Stuetzen. Mit 8 Studs langen Balken brauchst du sechs statt zwoelf Stueck.",
			"Loesung: sechs Balken zu 8 Studs (60) und fuenf Stuetzen (75) ergeben 135 von 240. Der Rest ist Reserve fuer eine zusaetzliche Stuetze dort, wo es im Test eng wird.",
		},
	}),

	makeLevel({
		id = "Level3",
		displayName = "Schmales Budget",
		subtitle = "Gleiche Luecke wie in Level 1, deutlich weniger Geld.",
		difficulty = 3,

		budget = 135,
		timeLimit = 60,
		maxDropStuds = 10,

		gapWidth = 40,
		deckY = 40,
		upperY = 48,
		groundY = 18,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6), speed = 3.2 },

		hints = {
			"135 Einheiten sind knapp bemessen. Jeder ueberfluessige Balken kostet 10 - plane die ganze Bruecke, bevor du das erste Teil setzt.",
			"Die Fahrbahn mit 8 Studs langen Balken zu spannen kostet 50 statt 100. Das ist der ganze Unterschied zwischen loesbar und nicht loesbar.",
			"Loesung: fuenf Balken zu 8 Studs (50) plus vier Stuetzen (60) sind 110. Viel mehr passt nicht hinein - baue nichts, was du nicht brauchst.",
		},
	}),

	makeLevel({
		id = "Level4",
		displayName = "Weite Spannung",
		subtitle = "64 Studs Luecke. Ab hier kostet jeder Tipp Robux.",
		difficulty = 4,

		budget = 260,
		timeLimit = 90,
		maxDropStuds = 12,

		gapWidth = 64,
		deckY = 44,
		upperY = 52,
		groundY = 20,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6), speed = 3.2 },

		hints = {
			"64 Studs sind viel, aber das Prinzip bleibt genau dasselbe: eine durchgehende Fahrbahn aus Balken, darunter Stuetzen bis zum Grund.",
			"Acht Balken zu je 8 Studs ergeben die Fahrbahn (80). Darunter passen sieben Stuetzen (105).",
			"Achte im Test auf die Zahlen ueber den Stuetzen. Sie halten 800 N. Steht das Fahrzeug genau ueber einer, wird es eng - eine zweite Stuetze gleich daneben teilt die Last auf.",
		},
	}),

	makeLevel({
		id = "Level5",
		displayName = "Hohe Pfeiler",
		subtitle = "38 Studs bis zum Grund - fast die Grenze einer Stuetze.",
		difficulty = 4,

		budget = 230,
		timeLimit = 70,
		maxDropStuds = 12,

		gapWidth = 48,
		deckY = 44,
		upperY = 52,
		groundY = 6,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6), speed = 3.2 },

		hints = {
			"Eine Stuetze reicht hoechstens 40 Studs weit. Hier sind es 38 - es geht also, aber knapp.",
			"Lange Stuetzen sind schwer: 3 Masse je Stud, also ueber 100 N Eigengewicht pro Stueck. Dieses Gewicht haengt zusaetzlich an deiner Fahrbahn. Je weniger Stuetzen, desto leichter die Bruecke.",
			"Loesung: sechs Balken zu 8 Studs (60) und fuenf lange Stuetzen (75) ergeben 135 von 230.",
		},
	}),

	makeLevel({
		id = "Level6",
		displayName = "Die grosse Schlucht",
		subtitle = "80 Studs. Die Koenigsdisziplin.",
		difficulty = 5,

		budget = 320,
		timeLimit = 110,
		maxDropStuds = 14,

		gapWidth = 80,
		deckY = 46,
		upperY = 54,
		groundY = 22,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6), speed = 3.2 },

		hints = {
			"80 Studs. Baue zuerst die komplette Fahrbahn von einer Seite zur anderen, und erst danach die Stuetzen. So siehst du sofort, wie viel Budget dir bleibt.",
			"Zehn Balken zu je 8 Studs sind 100 Einheiten. Neun Stuetzen kosten 135. Zusammen 235 von 320.",
			"Die restlichen 85 Einheiten sind deine Reserve. Starte einen Test und sieh zu, wo die Anzeige ueber 80 Prozent klettert - genau dort setzt du eine zusaetzliche Stuetze.",
		},
	}),
}

--------------------------------------------------------------------------------
-- Zugriff
--------------------------------------------------------------------------------

-- Nachschlagetabelle nach Level-Kennung.
Levels.byId = {}
for _, level in Levels.list do
	Levels.byId[level.id] = level
end

function Levels.get(id: string)
	return Levels.byId[id]
end

-- Kurzfassung fuer das Level-Menue (ohne die schweren Ankerpunkt-Listen).
function Levels.summaries()
	local out = {}
	for index, level in Levels.list do
		out[index] = {
			id = level.id,
			order = index,
			displayName = level.displayName,
			subtitle = level.subtitle,
			difficulty = level.difficulty,
			budget = level.budget,
			gapWidth = level.gapWidth,
			hintCount = #level.hints,
			freeHints = level.freeHints,
		}
	end
	return out
end

return Levels
