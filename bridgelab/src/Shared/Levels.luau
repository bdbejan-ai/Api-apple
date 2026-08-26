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
	              |###|          ~~~~~ Fluss ~~~~~          |###|
	        ground |##| #   #   #   #   #   #   #   #   #  #|###|   Grund der Schlucht
	              +--------------------------------------------+

	  #  = fester Ankerpunkt (unbeweglich, am Boden verankert)
	  o  = freier Ankerpunkt (kann sich unter Last bewegen)

	DIE REIHEN
	  "deck1", "deck2", ...  Fahrbahnhoehen  -> hier faehrt ein Testfahrzeug
	  "upper"                ganz oben       -> fuer Tuerme und Abspannungen
	  "ground"               Schluchtgrund   -> Fusspunkte fuer Stuetzen

	MEHRERE FAHRBAHNEN, MEHRERE FAHRZEUGE
	Ein Level kann mehr als eine Fahrbahn haben (Feld "decks") und mehr als
	ein Testfahrzeug (Feld "vehicles"). Jedes Fahrzeug faehrt auf einer
	bestimmten Fahrbahn und in eine bestimmte Richtung. Bestanden ist der
	Test erst, wenn ALLE Fahrzeuge ihr Ziel erreicht haben. Damit lassen
	sich Gegenverkehr und Doppelstockbruecken bauen.

	ZWEI FALLEN, DIE EIN LEVEL UNLOESBAR MACHEN
	  * upperY darf hoechstens 10 Studs (Balkenlaenge) ueber der obersten
	    Fahrbahn liegen, sonst kommt man mit keinem Balken hin.
	  * deckY - groundY darf hoechstens 40 Studs (Stuetzenlaenge) betragen,
	    sonst erreicht keine Stuetze den Grund - und dann laesst sich die
	    senkrechte Last nirgendwo abtragen.
	  Pruefen laesst sich das mit tools/check_levels.luau.
]]

local Levels = {}

--------------------------------------------------------------------------------
-- Bauplan eines Levels aus den Eckdaten erzeugen
--------------------------------------------------------------------------------

local function makeLevel(def)
	local level = def

	level.z = 0 -- Die ganze Bruecke liegt in der Ebene z = 0.

	-- Die Luecke liegt immer mittig um x = 0.
	level.gapLeftX = -def.gapWidth / 2
	level.gapRightX = def.gapWidth / 2

	level.snapSpacing = def.snapSpacing or 4
	level.platformLength = def.platformLength or 60
	level.platformDepth = def.platformDepth or 40

	----------------------------------------------------------------------------
	-- Fahrbahnen
	----------------------------------------------------------------------------

	-- Ein Level ohne ausdrueckliche Angabe hat genau eine Fahrbahn.
	level.decks = def.decks or { { y = def.deckY } }
	for index, deck in level.decks do
		deck.index = index
		deck.row = "deck" .. index
		--[[
			Eine Fahrbahn darf ANSTEIGEN: dann liegt die rechte Seite hoeher
			als die linke. Ohne Angabe von rightY ist sie waagerecht.
			Zwischen den beiden Rand-Hoehen wird ueber die Luecke hinweg
			gleichmaessig ueberblendet; ausserhalb der Luecke bleibt es flach,
			denn dort steht ja fester Boden.
		]]
		deck.leftY = deck.y
		deck.rightY = deck.rightY or deck.y
	end

	--[[
		Hoehe einer Fahrbahn an einer bestimmten Stelle.
		Alle anderen Teile fragen hier nach, statt selbst zu rechnen.
	]]
	function level.deckYAt(deckIndex: number, x: number): number
		local deck = level.decks[deckIndex]
		local t = math.clamp((x - level.gapLeftX) / level.gapWidth, 0, 1)
		return deck.leftY + (deck.rightY - deck.leftY) * t
	end

	local topDeck = level.decks[#level.decks]

	-- Die unterste Fahrbahn ist die Hauptfahrbahn (Plattformhoehe).
	level.deckY = level.decks[1].leftY
	level.topDeckY = math.max(topDeck.leftY, topDeck.rightY)

	-- Worauf die Kamera anfangs blickt: bei einer Steigung die Mitte.
	level.cameraDeckY = (level.decks[1].leftY + level.decks[1].rightY) / 2

	--[[
		Die obere Ankerreihe laeuft PARALLEL zur obersten Fahrbahn, in festem
		Abstand darueber. Waere sie waagerecht, waere sie bei einer ansteigenden
		Fahrbahn am tiefen Ende ausser Reichweite eines Balkens.
	]]
	level.upperOffset = def.upperOffset or ((def.upperY or (topDeck.leftY + 8)) - topDeck.leftY)
	level.upperY = level.topDeckY + level.upperOffset

	----------------------------------------------------------------------------
	-- Ankerpunkte erzeugen
	----------------------------------------------------------------------------

	--[[
		Wie weit das Raster in die festen Plattformen hineinreicht.
		Ein Stueck Ueberlappung ist noetig, damit die Fahrbahn ueberhaupt
		irgendwo fest verankert werden kann.
	]]
	local overlap = level.snapSpacing
	local half = level.gapRightX + overlap

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

	-- Je Fahrbahn eine Reihe. Alles ab dem Rand der Luecke steht auf festem Boden.
	for _, deck in level.decks do
		for x = -half, half, level.snapSpacing do
			addSnapPoint(deck.row, x, level.deckYAt(deck.index, x), math.abs(x) >= level.gapRightX)
		end
	end

	-- Obere Reihe, parallel ueber der obersten Fahrbahn. Nur die beiden
	-- aeussersten Punkte sind fest - sie sitzen auf den Pylonen.
	for x = -half, half, level.snapSpacing do
		addSnapPoint(
			"upper",
			x,
			level.deckYAt(topDeck.index, x) + level.upperOffset,
			math.abs(x) >= half - 0.01
		)
	end

	-- Bodenreihe im Schluchtgrund. Alle Punkte sind fest.
	for x = level.gapLeftX, level.gapRightX, level.snapSpacing do
		addSnapPoint("ground", x, level.groundY, true)
	end

	----------------------------------------------------------------------------
	-- Testfahrzeuge
	----------------------------------------------------------------------------

	-- Ohne Angabe faehrt genau ein Fahrzeug auf der ersten Fahrbahn nach rechts.
	local plan = def.vehicles or { { deck = 1, direction = 1 } }
	level.vehicles = {}

	for index, entry in plan do
		local deck = level.decks[entry.deck or 1]
		local direction = entry.direction or 1
		local outsideLeft = level.gapLeftX - 14
		local outsideRight = level.gapRightX + 14

		local startX = if direction > 0 then outsideLeft else outsideRight
		local finishX = if direction > 0 then outsideRight else outsideLeft

		level.vehicles[index] = {
			index = index,
			deckIndex = deck.index,
			deckRow = deck.row,
			-- Hoehe der Fahrbahn dort, wo das Fahrzeug steht bzw. ankommt.
			-- Bei einer ansteigenden Fahrbahn sind das zwei verschiedene Werte.
			deckY = deck.leftY,
			startY = level.deckYAt(deck.index, startX),
			finishY = level.deckYAt(deck.index, finishX),
			direction = direction,
			-- Nach rechts: links starten. Nach links: rechts starten.
			startX = startX,
			finishX = finishX,
			mass = entry.mass or def.vehicle.mass,
			size = entry.size or def.vehicle.size,
			color = entry.color,
			--[[
				Seitlicher Versatz auf der Fahrbahn ("Fahrspur").
				Bei Gegenverkehr MUSS er gesetzt sein: sonst fahren beide
				Fahrzeuge auf derselben Linie frontal ineinander, blockieren
				sich gegenseitig und der Test laeuft ins Zeitlimit.
				Auf die Kraefteberechnung hat der Versatz keinen Einfluss -
				die rechnet ohnehin nur in der Ebene X/Y.
			]]
			laneZ = entry.lane or 0,
		}
	end

	----------------------------------------------------------------------------
	-- Abgeleitete Angaben
	----------------------------------------------------------------------------

	-- Erlaubte Bauteile: nil bedeutet "alle".
	level.allowedParts = def.allowedParts

	-- Fluss im Schluchtgrund? Rein optisch, aendert nichts an der Physik.
	level.river = def.river ~= false and def.groundY >= 4
	level.riverY = def.groundY + 2.5

	--[[
		Wie viele Tipps in diesem Level gratis sind.
		Faustregel im Spiel: leichte Level (Schwierigkeit 1-3) haben einen
		Gratis-Tipp, schwere Level (4-5) kosten schon beim ersten Tipp.
	]]
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

	-- Ausmasse des Levels - die Kamera begrenzt danach ihren Zoom.
	level.bounds = {
		minX = level.gapLeftX - level.platformLength,
		maxX = level.gapRightX + level.platformLength,
		minY = math.max(level.groundY - 12, 0),
		maxY = level.upperY + 12,
	}

	return level
end

--------------------------------------------------------------------------------
-- Die Level
--------------------------------------------------------------------------------

--[[
	ANNAHME zur Fahrgeschwindigkeit: Sie steht NICHT mehr im Level. Der
	Spieler stellt sie im Test selbst am Tacho ein (1 bis 14 Studs pro
	Sekunde). Das Zeitlimit richtet sich automatisch nach der gewaehlten
	Geschwindigkeit, damit langsames Fahren nie bestraft wird.
]]

Levels.list = {
	makeLevel({
		id = "Level1",
		displayName = "Die erste Luecke",
		subtitle = "Lerne die Grundlagen kennen.",
		difficulty = 1,

		budget = 200,
		maxDropStuds = 10,

		gapWidth = 40,
		deckY = 40,
		upperY = 48,
		groundY = 20,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6) },

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
		maxDropStuds = 10,

		gapWidth = 48,
		deckY = 44,
		upperY = 52,
		groundY = 12,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6) },

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
		maxDropStuds = 10,

		gapWidth = 40,
		deckY = 40,
		upperY = 48,
		groundY = 18,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6) },

		hints = {
			"135 Einheiten sind knapp bemessen. Jeder ueberfluessige Balken kostet 10 - plane die ganze Bruecke, bevor du das erste Teil setzt.",
			"Die Fahrbahn mit 8 Studs langen Balken zu spannen kostet 50 statt 100. Das ist der ganze Unterschied zwischen loesbar und nicht loesbar.",
			"Loesung: fuenf Balken zu 8 Studs (50) plus vier Stuetzen (60) sind 110. Viel mehr passt nicht hinein - baue nichts, was du nicht brauchst.",
		},
	}),

	--[[
		Die Kennung (id) hat nichts mit der angezeigten Nummer zu tun - die
		ergibt sich aus der Reihenfolge in dieser Liste. Deshalb laesst sich
		ein Level einschieben, ohne den Fortschritt der anderen zu verlieren.
	]]
	makeLevel({
		id = "LevelRamp",
		displayName = "Steile Rampe",
		subtitle = "Die andere Seite liegt 16 Studs hoeher.",
		difficulty = 3,

		-- Geprueft: die guenstigste tragende Loesung kostet 135.
		budget = 240,
		maxDropStuds = 10,

		gapWidth = 48,
		groundY = 20,

		--[[
			Ansteigende Fahrbahn: links 40, rechts 56. Damit wird jede Stuetze
			weiter rechts laenger und schwerer - und die Balken liegen schraeg,
			sind also laenger als der waagerechte Abstand vermuten laesst.
		]]
		decks = {
			{ y = 40, rightY = 56 },
		},

		-- Die obere Reihe laeuft parallel mit, 8 Studs ueber der Fahrbahn.
		upperOffset = 8,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6) },

		hints = {
			"Die Fahrbahn steigt an. Nach rechts hin wird jede Stuetze laenger - und laengere Stuetzen sind schwerer, ihr Eigengewicht haengt zusaetzlich an der Bruecke.",
			"Ein Balken darf 10 Studs lang sein, SCHRAEG gemessen. Bei dieser Steigung sind 8 Studs waagerecht etwa 8,4 Studs schraeg - das passt noch bequem.",
			"Loesung: sechs Balken ueber je zwei Rasterschritte (60) und fuenf Stuetzen bis zum Grund (75) ergeben 135 von 240.",
		},
	}),

	makeLevel({
		id = "Level4",
		displayName = "Gegenverkehr",
		subtitle = "Zwei Fahrzeuge, aus beiden Richtungen gleichzeitig.",
		difficulty = 4,

		-- Geprueft: die guenstigste tragende Loesung kostet 285.
		budget = 360,
		maxDropStuds = 12,

		gapWidth = 48,
		deckY = 44,
		upperY = 52,
		groundY = 16,

		-- Schmaler als sonst, damit zwei Fahrzeuge nebeneinander passen.
		vehicle = { mass = 1000, size = Vector3.new(8, 4, 3.4) },

		--[[
			Zwei Fahrzeuge fahren aufeinander zu. In der Mitte begegnen sie
			sich - dort liegen dann 2000 N auf wenigen Studs Fahrbahn.

			Jedes bekommt seine eigene Fahrspur (lane), sonst waere die
			Begegnung ein Frontalzusammenstoss statt einer Belastungsprobe.
			Die Fahrbahn ist 8 Studs breit, also zwei Spuren zu je 4.
		]]
		vehicles = {
			{ deck = 1, direction = 1, lane = -2, color = Color3.fromRGB(198, 72, 58) },
			{ deck = 1, direction = -1, lane = 2, color = Color3.fromRGB(64, 118, 206) },
		},

		hints = {
			"Beide Fahrzeuge treffen sich genau in der Mitte. Dort liegt dann die doppelte Last - 2000 N auf wenigen Studs.",
			"Eine Stuetze haelt 800 N. In der Mitte brauchst du deshalb enger stehende Stuetzen als am Rand: dort lieber alle 4 statt alle 8 Studs.",
			"Loesung: Fahrbahn aus zwoelf Balken zu 4 Studs (120) und elf Stuetzen im 4er-Abstand (165) - zusammen 285 von 360. Die weiten 8er-Spannweiten aus den ersten Leveln reichen hier nicht mehr.",
		},
	}),

	makeLevel({
		id = "Level5",
		displayName = "Doppeldecker",
		subtitle = "Zwei Fahrbahnen uebereinander - und beide muessen halten.",
		difficulty = 5,

		-- Geprueft: die guenstigste tragende Loesung kostet 370.
		budget = 480,
		maxDropStuds = 12,

		gapWidth = 32,
		upperY = 64,
		groundY = 20,

		--[[
			Zwei Fahrbahnen im Abstand von 16 Studs. Ein Balken schafft nur
			10 Studs - zwischen den Ebenen kommst du also ausschliesslich mit
			STUETZEN hoch. Genau darin liegt die Aufgabe.
		]]
		decks = {
			{ y = 40 },
			{ y = 56 },
		},

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6) },

		vehicles = {
			{ deck = 1, direction = 1, color = Color3.fromRGB(198, 72, 58) },
			-- Oben faehrt ein leichterer Lieferwagen. Sonst waere die Last auf
			-- den unteren Stuetzen kaum noch zu tragen.
			{ deck = 2, direction = 1, mass = 600, color = Color3.fromRGB(232, 172, 62) },
		},

		hints = {
			"Baue zuerst die UNTERE Fahrbahn ganz normal fertig, mit Stuetzen bis zum Grund. Die obere Ebene setzt darauf auf.",
			"Zwischen den beiden Fahrbahnen liegen 16 Studs. Ein Balken schafft nur 10 - du kommst also nur mit Stuetzen nach oben. Die duerfen auf der unteren Fahrbahn stehen.",
			"Loesung: beide Fahrbahnen im 4er-Raster - je acht Balken (80) und sieben Stuetzen (105) pro Ebene, zusammen 370 von 480. Was oben faehrt, drueckt durch die Stuetzen auf die untere Fahrbahn und von dort weiter zum Grund: der untere Weg traegt also beides.",
		},
	}),

	makeLevel({
		id = "Level6",
		displayName = "Die grosse Schlucht",
		subtitle = "80 Studs. Die Koenigsdisziplin.",
		difficulty = 5,

		budget = 320,
		maxDropStuds = 14,

		gapWidth = 80,
		deckY = 46,
		upperY = 54,
		groundY = 22,

		vehicle = { mass = 1000, size = Vector3.new(8, 4, 6) },

		hints = {
			"80 Studs. Baue zuerst die komplette Fahrbahn von einer Seite zur anderen, und erst danach die Stuetzen. So siehst du sofort, wie viel Budget dir bleibt.",
			"Zehn Balken zu je 8 Studs sind 100 Einheiten. Neun Stuetzen kosten 135. Zusammen 235 von 320.",
			"Die restlichen 85 Einheiten sind deine Reserve. Fahre langsam und sieh zu, wo die Anzeige ueber 80 Prozent klettert - genau dort setzt du eine zusaetzliche Stuetze.",
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
			deckCount = #level.decks,
			vehicleCount = #level.vehicles,
			-- Hoehenunterschied der Fahrbahn: 0 = waagerecht
			slope = level.decks[1].rightY - level.decks[1].leftY,
			hintCount = #level.hints,
			freeHints = level.freeHints,
		}
	end
	return out
end

return Levels
