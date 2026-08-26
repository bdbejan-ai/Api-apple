--[[
	Levels
	------
	Zwoelf Level in drei Welten.

	AUFBAU EINES LEVELS
	Ein Level beschreibt ein GELAENDEPROFIL - eine Liste von Stuetzstellen,
	zwischen denen geradlinig verbunden wird (siehe Terrain.luau). Dazu:

	  anchors    feste Punkte, an denen gebaut werden darf. NUR hier kann eine
	             Konstruktion Last in den Boden abgeben.
	  buildArea  Rechteck, in dem freie Knoten liegen duerfen
	  materials  welche Baustoffe erlaubt sind
	  vehicles   was hinueber muss
	  budget     wie viel ausgegeben werden darf

	DIE WICHTIGSTE REGEL DES SPIELS
	Man kann NICHT irgendwo auf den Boden stuetzen. Nur an den vorgegebenen
	Ankerpunkten. Alles dazwischen muss die Konstruktion selbst tragen.
	Genau daraus entsteht die Aufgabe: ein Fachwerk, ein Bogen oder eine
	Haengebruecke zu finden, die mit wenigen Ankern auskommt.

	KOORDINATEN
	x nach rechts, y nach oben, alles in Studs. Das Raster ist 2 Studs weit,
	deshalb sollten alle Zahlen gerade sein.
]]

--[[
	Diese Datei haengt ABSICHTLICH von nichts ab - weder von Roblox-Diensten
	noch von anderen Modulen. Nur so kann das Pruefskript in tools/ sie direkt
	einlesen und die echten Leveldaten pruefen, statt eine Kopie zu pflegen.
	Genau so eine Kopie hat mir schon einmal einen Fehler eingebracht.

	Das Rechnen mit dem Gelaende erledigt Terrain.luau. Wer die Gelaendehoehe
	braucht, ruft Terrain.heightAt(level.terrain, x) auf.
]]

local Levels = {}

--------------------------------------------------------------------------------
-- Fahrzeugarten
--------------------------------------------------------------------------------

--[[
	WARUM DIE MASSEN GENAU SO GEWAEHLT SIND

	Ein Fachwerk ueber die Spannweite L mit der Bauhoehe h bekommt in seinen
	Gurten ungefaehr die Kraft  W * L / (4 * h).  Daraus laesst sich fuer jedes
	Fahrzeug ausrechnen, wie weit es ueberhaupt getragen werden kann:

	    L(max) = 4 * h * Grenzwert / W

	Welt 1 kennt nur Holz (400 N). Mit h = 8 traegt ein einzelner Holzgurt
	also  4 * 8 * 400 / W  Studs. Bei den frueheren 1000 N waeren das 12,8
	Studs gewesen - kuerzer als der kleinste Graben im Spiel. Deshalb ist
	JEDES Fachwerk in Welt 1 gerissen, und "Stuetzen bis zum Boden" war die
	einzige Bauform, die je funktioniert hat.

	Mit dem Kleinwagen (420 N) sind es rund 30 Studs. Die Spannweiten in
	Welt 1 liegen darunter - die Level sind loesbar, ohne dass ein Baustoff
	dafuer kuenstlich stark gemacht werden musste.

	Die Schwierigkeit kommt also aus dem FAHRZEUG und der SPANNWEITE, nicht
	aus heimlich angehobenen Grenzwerten.

	size ist eine schlichte Tabelle mit X/Y/Z und color eine Liste mit drei
	Zahlen von 0 bis 255 - absichtlich KEIN Vector3 und kein Color3, damit
	diese Datei ohne Roblox auskommt und das Pruefskript sie lesen kann.
	Der Server macht daraus echte Roblox-Werte (siehe TestRun.luau).
]]

Levels.vehicleKinds = {
	MiniCar = {
		key = "MiniCar",
		displayName = "Kleinwagen",
		mass = 420,
		size = { X = 6, Y = 3.2, Z = 4.4 },
		color = { 226, 108, 92 },
	},
	Car = {
		key = "Car",
		displayName = "Auto",
		mass = 900,
		size = { X = 8, Y = 4, Z = 5 },
		color = { 198, 72, 58 },
	},
	Van = {
		key = "Van",
		displayName = "Lieferwagen",
		mass = 650,
		size = { X = 7, Y = 3.6, Z = 4.6 },
		color = { 232, 172, 62 },
	},
	Truck = {
		key = "Truck",
		displayName = "Lastwagen",
		mass = 1600,
		size = { X = 12, Y = 5, Z = 5 },
		color = { 64, 118, 206 },
	},
}

--------------------------------------------------------------------------------
-- Ein Level aus seinen Eckdaten zusammensetzen
--------------------------------------------------------------------------------

local function makeLevel(def)
	local level = def

	level.z = 0
	level.roadWidth = def.roadWidth or 8

	----------------------------------------------------------------------------
	-- Gelaende: nur die Ausmasse, das Rechnen macht Terrain.luau
	----------------------------------------------------------------------------

	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	for _, point in def.terrain do
		minX = math.min(minX, point.x)
		maxX = math.max(maxX, point.x)
		minY = math.min(minY, point.y)
		maxY = math.max(maxY, point.y)
	end
	level.terrainBounds = { minX = minX, maxX = maxX, minY = minY, maxY = maxY }

	----------------------------------------------------------------------------
	-- Ankerpunkte
	----------------------------------------------------------------------------

	-- Jeder Anker bekommt eine Nummer; der Client findet ihn darueber wieder.
	for index, anchor in level.anchors do
		anchor.index = index
	end

	function level.anchorAt(x: number, y: number)
		for _, anchor in level.anchors do
			if math.abs(anchor.x - x) < 0.51 and math.abs(anchor.y - y) < 0.51 then
				return anchor
			end
		end
		return nil
	end

	----------------------------------------------------------------------------
	-- Erlaubte Baustoffe
	----------------------------------------------------------------------------

	function level.allowsMaterial(key: string): boolean
		return table.find(level.materials, key) ~= nil
	end

	----------------------------------------------------------------------------
	-- Fahrzeuge
	----------------------------------------------------------------------------

	--[[
		Kleine Ausgabe der Gelaendehoehe, nur fuer die Startpositionen der
		Fahrzeuge. Dieselbe Rechnung wie Terrain.heightAt, aber hier vor Ort,
		damit diese Datei ohne Abhaengigkeiten bleibt.
	]]
	local function groundAt(x: number): number
		local points = def.terrain
		if x <= points[1].x then
			return points[1].y
		end
		if x >= points[#points].x then
			return points[#points].y
		end
		local best = points[1].y
		for i = 1, #points - 1 do
			local p, q = points[i], points[i + 1]
			if math.abs(q.x - p.x) > 1e-6 then
				local lo, hi = p, q
				if lo.x > hi.x then
					lo, hi = q, p
				end
				if x >= lo.x and x <= hi.x then
					local y = lo.y + (hi.y - lo.y) * ((x - lo.x) / (hi.x - lo.x))
					if y > best then
						best = y
					end
				end
			end
		end
		return best
	end

	for index, vehicle in level.vehicles do
		local kind = Levels.vehicleKinds[vehicle.kind or "Car"]

		vehicle.index = index
		vehicle.kindKey = kind.key
		vehicle.displayName = kind.displayName
		vehicle.mass = vehicle.mass or kind.mass
		vehicle.size = vehicle.size or kind.size
		vehicle.color = vehicle.color or kind.color
		vehicle.laneZ = vehicle.lane or 0
		vehicle.direction = if vehicle.toX >= vehicle.fromX then 1 else -1

		-- Auf dem Boden absetzen, wo es losfaehrt.
		vehicle.startY = groundAt(vehicle.fromX)
		vehicle.finishY = groundAt(vehicle.toX)
	end

	----------------------------------------------------------------------------
	-- Ausmasse fuer die Kamera
	----------------------------------------------------------------------------

	local t = level.terrainBounds
	level.bounds = {
		minX = t.minX,
		maxX = t.maxX,
		minY = math.min(t.minY, def.buildArea.minY) - 8,
		maxY = math.max(t.maxY, def.buildArea.maxY) + 8,
	}

	-- Worauf die Kamera anfangs blickt.
	level.focusY = (def.buildArea.minY + def.buildArea.maxY) / 2

	level.freeHints = def.freeHints or (if def.difficulty <= 3 then 1 else 0)

	----------------------------------------------------------------------------
	-- Schiff: Angaben pruefen
	----------------------------------------------------------------------------

	--[[
		WARUM HIER GEPRUEFT WIRD, STATT ERSATZWERTE ZU NEHMEN

		Der Code las die Schiffsangaben mit Ersatzwerten - boat.length or 18.
		Als das Feld im Level "width" hiess und im Code "length", fiel das
		nirgends auf: es wurde einfach der Ersatzwert genommen. Das Schiff war
		dann 18 statt 14 Studs lang, und die Bruecke stiess es an, obwohl der
		Spieler alles richtig gemacht hatte.

		Ein Ersatzwert ist gut gegen FEHLENDE Angaben, aber schlecht gegen
		FALSCH BENANNTE: er verwandelt einen Tippfehler in stilles Fehlverhalten.
		Deshalb wird hier beim Laden geprueft und notfalls laut geschimpft -
		einmal beim Start, statt stundenlanger Suche im laufenden Spiel.
	]]
	if def.boat then
		local required = { "fromX", "toX", "speed", "mastHeight", "length" }
		for _, key in required do
			if type(def.boat[key]) ~= "number" then
				error(string.format(
					"Level %s: das Schiff braucht die Angabe '%s' als Zahl.",
					def.id, key
				), 0)
			end
		end

		local known = {
			fromX = true, toX = true, speed = true, mastHeight = true,
			length = true, clearance = true, startDelay = true,
		}
		for key in def.boat do
			if not known[key] then
				error(string.format(
					"Level %s: das Schiff kennt die Angabe '%s' nicht. Tippfehler?",
					def.id, key
				), 0)
			end
		end
	end

	return level
end

--------------------------------------------------------------------------------
-- Welt 1: Grundlagen
--------------------------------------------------------------------------------

local BASIC = { "Road", "Wood", "Rope" }
local ADVANCED = { "Road", "ReinforcedRoad", "Wood", "Steel", "Rope", "Cable" }
local ALL = { "Road", "ReinforcedRoad", "Wood", "Steel", "Rope", "Cable", "Hydraulic" }

Levels.list = {
	makeLevel({
		id = "W1L1",
		world = "Grundlagen",
		displayName = "Der erste Graben",
		subtitle = "Kurze Luecke, viel Budget. Lerne das Zeichnen.",
		difficulty = 1,
		budget = 800,
		maxDropStuds = 14,

		terrain = {
			{ x = -80, y = 30 },
			{ x = -12, y = 30 },
			{ x = -12, y = 0 },
			{ x = 12, y = 0 },
			{ x = 12, y = 30 },
			{ x = 80, y = 30 },
		},
		waterY = 8,
		buildArea = { minX = -22, maxX = 22, minY = 4, maxY = 62 },
		anchors = {
			{ x = -12, y = 30 },
			{ x = 12, y = 30 },
		},
		materials = BASIC,
		vehicles = { { kind = "MiniCar", fromX = -50, toX = 50 } },

		hints = {
			"Eine gerade Fahrbahn traegt sich nicht selbst. Jeder Knoten, der nur zwei Bauteile in derselben Linie hat, kann keine senkrechte Last aufnehmen.",
			"Ein Dreieck ist die einzige Form, die sich nicht verziehen laesst. Setze ueber die Fahrbahn einen Obergurt aus Holz und verbinde ihn mit Streben nach unten.",
			"Loesung: Fahrbahn aus drei Strassenstuecken, darueber ein Dreieck aus Holz von Anker zu Anker mit zwei senkrechten Streben nach unten.",
		},
	}),

	makeLevel({
		id = "W1L2",
		world = "Grundlagen",
		displayName = "Dreiecke",
		subtitle = "Zu weit fuer eine flache Fahrbahn.",
		difficulty = 2,
		budget = 1900,
		maxDropStuds = 14,

		terrain = {
			{ x = -90, y = 32 },
			{ x = -20, y = 32 },
			{ x = -20, y = 0 },
			{ x = 20, y = 0 },
			{ x = 20, y = 32 },
			{ x = 90, y = 32 },
		},
		waterY = 10,
		buildArea = { minX = -30, maxX = 30, minY = 4, maxY = 66 },
		anchors = {
			{ x = -20, y = 32 },
			{ x = 20, y = 32 },
		},
		materials = BASIC,
		vehicles = { { kind = "MiniCar", fromX = -60, toX = 60 } },

		hints = {
			"Vierzig Studs sind zu weit fuer ein einzelnes Dreieck. Es braucht eine Kette davon - ein Fachwerk.",
			"Bau die Fahrbahn in Feldern von 8 Studs. Ueber jedem Feldknoten eine senkrechte Strebe nach oben, oben ein durchgehender Gurt, dazwischen Diagonalen.",
			"Je hoeher das Fachwerk, desto geringer die Kraft in den Gurten. Zehn bis zwoelf Studs Bauhoehe sind ein guter Wert.",
		},
	}),

	makeLevel({
		id = "W1L3",
		world = "Grundlagen",
		displayName = "Haengepartie",
		subtitle = "Der Grund ist unerreichbar. Von oben abhaengen.",
		difficulty = 3,
		budget = 2900,
		maxDropStuds = 16,

		terrain = {
			{ x = -90, y = 58 },
			{ x = -26, y = 58 },
			{ x = -26, y = 42 },
			{ x = -18, y = 42 },
			{ x = -18, y = -24 },
			{ x = 18, y = -24 },
			{ x = 18, y = 42 },
			{ x = 26, y = 42 },
			{ x = 26, y = 58 },
			{ x = 90, y = 58 },
		},
		waterY = -14,
		buildArea = { minX = -30, maxX = 30, minY = 34, maxY = 84 },
		anchors = {
			{ x = -18, y = 42 },
			{ x = 18, y = 42 },
			{ x = -26, y = 58 },
			{ x = 26, y = 58 },
		},
		materials = BASIC,
		vehicles = { { kind = "MiniCar", fromX = -60, toX = 60 } },

		hints = {
			"Die beiden hohen Anker auf den Felsschultern sind der Schluessel. Von dort laesst sich die Fahrbahn abhaengen.",
			"Seile koennen nur ziehen. Sie muessen deshalb immer von OBEN nach unten laufen, nie waagerecht und nie von unten.",
			"Loesung: eine Kette aus Holz zwischen den beiden hohen Ankern als Tragseil, davon Seile senkrecht hinunter zur Fahrbahn.",
		},
	}),

	makeLevel({
		id = "W1L4",
		world = "Grundlagen",
		displayName = "Sparzwang",
		subtitle = "Dieselbe Luecke wie Level 2, halbes Budget.",
		difficulty = 3,
		budget = 640,
		maxDropStuds = 14,

		terrain = {
			{ x = -80, y = 30 },
			{ x = -12, y = 30 },
			{ x = -12, y = 0 },
			{ x = 12, y = 0 },
			{ x = 12, y = 30 },
			{ x = 80, y = 30 },
		},
		waterY = 10,
		buildArea = { minX = -22, maxX = 22, minY = 4, maxY = 62 },
		anchors = {
			{ x = -12, y = 30 },
			{ x = 12, y = 30 },
		},
		materials = BASIC,
		vehicles = { { kind = "MiniCar", fromX = -60, toX = 60 } },

		hints = {
			"Hier faehrt nur ein leichter Lieferwagen. Die Bruecke darf also duenner sein als in Level 2.",
			"Holz kostet 4 je Stud, Strasse 8. Baue nur so viel Fahrbahn wie noetig und den Rest aus Holz.",
			"Ein flacheres Fachwerk spart Material an den Streben, kostet aber mehr Kraft in den Gurten. Such den Punkt dazwischen.",
		},
	}),

	--------------------------------------------------------------------------
	-- Welt 2: Werkstoffe
	--------------------------------------------------------------------------

	makeLevel({
		id = "W2L5",
		world = "Werkstoffe",
		displayName = "Weit gespannt",
		subtitle = "Siebzig Studs am Stueck. Nur Stahl traegt das.",
		difficulty = 3,
		budget = 8200,
		maxDropStuds = 16,

		terrain = {
			{ x = -110, y = 36 },
			{ x = -36, y = 36 },
			{ x = -36, y = 0 },
			{ x = 36, y = 0 },
			{ x = 36, y = 36 },
			{ x = 110, y = 36 },
		},
		waterY = 12,
		buildArea = { minX = -44, maxX = 44, minY = 4, maxY = 76 },
		anchors = {
			{ x = -36, y = 36 },
			{ x = 36, y = 36 },
		},
		materials = ADVANCED,
		vehicles = { { kind = "Van", fromX = -70, toX = 70 } },

		hints = {
			"Holz haelt 400 N, Stahl 1200. Bei dieser Spannweite entstehen in den Gurten weit ueber 400 N - Holz reisst dort sofort.",
			"Die Kraft im Gurt ist ungefaehr Last mal Spannweite geteilt durch das Vierfache der Bauhoehe. Mehr Bauhoehe ist billiger als mehr Material.",
			"Loesung: Fahrbahn aus Strasse, Ober- und Untergurt sowie Diagonalen aus Stahl, Bauhoehe etwa 14 Studs.",
		},
	}),

	makeLevel({
		id = "W2L6",
		world = "Werkstoffe",
		displayName = "Steile Kante",
		subtitle = "Die andere Seite liegt zwanzig Studs hoeher.",
		difficulty = 4,
		budget = 4900,
		maxDropStuds = 16,

		terrain = {
			{ x = -100, y = 28 },
			{ x = -22, y = 28 },
			{ x = -22, y = 0 },
			{ x = 22, y = 0 },
			{ x = 22, y = 48 },
			{ x = 100, y = 48 },
		},
		waterY = 10,
		buildArea = { minX = -32, maxX = 32, minY = 4, maxY = 82 },
		anchors = {
			{ x = -22, y = 28 },
			{ x = 22, y = 48 },
		},
		materials = ADVANCED,
		vehicles = { { kind = "Car", fromX = -60, toX = 60 } },

		hints = {
			"Die Fahrbahn muss ansteigen. Zu steil darf sie nicht werden - ueber etwa 33 Grad gilt ein Bauteil nicht mehr als befahrbar und das Fahrzeug faellt hindurch.",
			"Zwanzig Studs Hoehenunterschied auf 44 Studs Weite sind knapp 25 Grad. Das geht gerade so, wenn die Steigung gleichmaessig ueber die ganze Luecke verteilt wird.",
			"Das Tragwerk darf ruhig waagerecht bleiben, auch wenn die Fahrbahn steigt. Ein Fachwerk mit waagerechtem Obergurt und schraeger Fahrbahn ist voellig in Ordnung.",
		},
	}),

	makeLevel({
		id = "W2L7",
		world = "Werkstoffe",
		displayName = "Doppelte Last",
		subtitle = "Zwei Lastwagen gleichzeitig, aus beiden Richtungen.",
		difficulty = 4,
		budget = 6000,
		maxDropStuds = 16,

		terrain = {
			{ x = -100, y = 34 },
			{ x = -26, y = 34 },
			{ x = -26, y = 0 },
			{ x = -6, y = 0 },
			{ x = -6, y = 14 },
			{ x = 6, y = 14 },
			{ x = 6, y = 0 },
			{ x = 26, y = 0 },
			{ x = 26, y = 34 },
			{ x = 100, y = 34 },
		},
		waterY = 10,
		buildArea = { minX = -36, maxX = 36, minY = 4, maxY = 74 },
		anchors = {
			{ x = -26, y = 34 },
			{ x = 26, y = 34 },
			-- Die Felsnadel mitten in der Schlucht: ohne sie ist die doppelte
			-- Last rechnerisch nicht zu tragen, mit ihr wird es eine Uebung
			-- im Pfeilerbau.
			{ x = -6, y = 14 },
			{ x = 6, y = 14 },
		},
		materials = ADVANCED,
		roadWidth = 10,
		vehicles = {
			{ kind = "Car", fromX = -64, toX = 64, lane = -2.6 },
			{ kind = "Car", fromX = 64, toX = -64, lane = 2.6 },
		},

		hints = {
			"Zwei Lastwagen zu je 1700 N treffen sich in der Mitte. Dort liegen dann 3400 N auf wenigen Studs Fahrbahn.",
			"Normale Strasse haelt 500 N. Im mittleren Bereich reicht das nicht - dort gehoert verstaerkte Strasse hin.",
			"Verstaerke nur die Mitte. Verstaerkte Strasse kostet fast das Doppelte; an den Raendern waere sie verschwendet.",
		},
	}),

	makeLevel({
		id = "W2L8",
		world = "Werkstoffe",
		displayName = "Der Bogen",
		subtitle = "Anker tief unten an den Felswaenden.",
		difficulty = 4,
		budget = 5200,
		maxDropStuds = 18,

		terrain = {
			{ x = -100, y = 40 },
			{ x = -26, y = 40 },
			{ x = -26, y = 6 },
			{ x = -20, y = 4 },
			{ x = 20, y = 4 },
			{ x = 26, y = 6 },
			{ x = 26, y = 40 },
			{ x = 100, y = 40 },
		},
		waterY = 8,
		buildArea = { minX = -34, maxX = 34, minY = 2, maxY = 66 },
		anchors = {
			{ x = -26, y = 40 },
			{ x = 26, y = 40 },
			-- Tief unten am Fuss der Felswand: Grundlage fuer einen Bogen.
			{ x = -26, y = 8 },
			{ x = 26, y = 8 },
		},
		materials = ADVANCED,
		vehicles = { { kind = "Car", fromX = -64, toX = 64 } },

		hints = {
			"Die beiden tiefen Anker am Fuss der Felswand sind kein Zufall. Von dort laesst sich ein Bogen aufspannen.",
			"Ein Bogen traegt durch DRUCK. Er braucht also Stahl oder Holz, kein Seil - ein Seil wuerde sofort durchhaengen.",
			"Loesung: ein Bogen aus Stahl von Anker zu Anker unten, darauf senkrechte Stuetzen nach oben zur Fahrbahn. Der Bogen nimmt fast die ganze Last auf.",
		},
	}),

	--------------------------------------------------------------------------
	-- Welt 3: Bewegliche Teile
	--------------------------------------------------------------------------

	makeLevel({
		id = "W3L9",
		world = "Bewegliches",
		displayName = "Klappbruecke",
		subtitle = "Ein Schiff muss durch. Die Bruecke muss aufgehen.",
		difficulty = 5,
		budget = 3000,
		maxDropStuds = 16,

		terrain = {
			{ x = -100, y = 26 },
			{ x = -24, y = 26 },
			{ x = -24, y = -10 },
			{ x = 24, y = -10 },
			{ x = 24, y = 26 },
			{ x = 100, y = 26 },
		},
		waterY = 4,
		buildArea = { minX = -34, maxX = 34, minY = 6, maxY = 70 },
		anchors = {
			{ x = -24, y = 26 },
			{ x = 24, y = 26 },
		},
		materials = ALL,
		vehicles = { { kind = "Car", fromX = -60, toX = 60 } },

		--[[
			Das Schiff faehrt in der Mitte durch und braucht freie Hoehe.
			Steht dort noch Bruecke, ist der Test verloren. Also muss sie sich
			mit Hydraulik oeffnen, bevor das Fahrzeug faehrt.
		]]
		boat = {
			fromX = -70,
			toX = 70,
			speed = 9,
			mastHeight = 22, -- so hoch muss der Durchgang frei sein
			length = 14, -- Laenge des Rumpfes in Fahrtrichtung
			clearance = 1, -- Sicherheitsabstand rundherum
			startDelay = 1.5, -- so lange wartet das Schiff nach dem Start
		},

		hints = {
			"Das Schiff faehrt zuerst. Erst wenn es durch ist, darf die Bruecke wieder zu sein.",
			"Ein Hydraulikzylinder faehrt in seiner Phase auf das Anderthalbfache seiner Baulaenge aus. Damit laesst sich ein Fahrbahnstueck hochklappen.",
			"Baue die Fahrbahn in zwei Haelften, die sich in der Mitte treffen. Unter jeder Haelfte ein Zylinder in Phase 1 - der hebt sie an, wenn das Schiff kommt.",
		},
	}),

	makeLevel({
		id = "W3L10",
		world = "Bewegliches",
		displayName = "Der Sprung",
		subtitle = "Eine Rampe. Mehr bekommst du nicht.",
		difficulty = 5,
		budget = 1800,
		maxDropStuds = 40,

		terrain = {
			{ x = -100, y = 30 },
			{ x = -30, y = 30 },
			{ x = -30, y = -14 },
			{ x = 34, y = -14 },
			{ x = 34, y = 22 },
			{ x = 100, y = 22 },
		},
		waterY = -6,
		buildArea = { minX = -40, maxX = 10, minY = 24, maxY = 66 },
		anchors = {
			{ x = -30, y = 30 },
		},
		materials = ADVANCED,
		vehicles = { { kind = "Car", fromX = -70, toX = 60 } },

		--[[
			Die Bauzone endet bei x = 10 - eine durchgehende Bruecke ist
			also unmoeglich. Das Fahrzeug muss springen. Der Landeplatz
			liegt tiefer, das hilft.
		]]
		requiresJump = true,

		hints = {
			"Sieh dir die Bauzone an: sie endet weit vor der anderen Seite. Eine durchgehende Bruecke gibt es hier nicht.",
			"Bau eine Rampe, die leicht ansteigt, und fahre schnell. Am Tacho lassen sich bis zu 14 Studs pro Sekunde einstellen.",
			"Die Landeseite liegt acht Studs tiefer als der Start. Der Sprung ist also leichter, als er aussieht - aber die Rampe muss das Auto sauber abheben lassen.",
		},
	}),

	makeLevel({
		id = "W3L11",
		world = "Bewegliches",
		displayName = "Zwei Ebenen",
		subtitle = "Unten ein Lastwagen, oben ein Lieferwagen.",
		difficulty = 5,
		budget = 4800,
		maxDropStuds = 16,

		terrain = {
			{ x = -100, y = 24 },
			{ x = -22, y = 24 },
			{ x = -22, y = -8 },
			{ x = 22, y = -8 },
			{ x = 22, y = 24 },
			{ x = 100, y = 24 },
		},
		waterY = 4,
		buildArea = { minX = -32, maxX = 32, minY = 2, maxY = 78 },
		anchors = {
			{ x = -22, y = 24 },
			{ x = 22, y = 24 },
			-- Zweite Ebene: Anker auf Felsvorspruengen weiter oben.
			{ x = -26, y = 48 },
			{ x = 26, y = 48 },
		},
		materials = ADVANCED,
		vehicles = {
			{ kind = "Car", fromX = -60, toX = 60 },
			{ kind = "Van", fromX = -60, toX = 60, lane = 0 },
		},

		hints = {
			"Die beiden oberen Anker liegen 24 Studs ueber den unteren. Dort gehoert die zweite Fahrbahn hin.",
			"Beide Ebenen zugleich zu tragen ist teuer. Guenstiger ist ein gemeinsames Fachwerk, dessen Obergurt zugleich die obere Fahrbahn ist.",
			"Der Lieferwagen oben wiegt nur 650 N. Die obere Ebene darf deshalb deutlich leichter ausfallen als die untere.",
		},
	}),

	makeLevel({
		id = "W3L12",
		world = "Bewegliches",
		displayName = "Die grosse Schlucht",
		subtitle = "Hundert Studs. Alles, was du gelernt hast.",
		difficulty = 5,
		budget = 13000,
		maxDropStuds = 20,

		terrain = {
			{ x = -130, y = 44 },
			{ x = -50, y = 44 },
			{ x = -50, y = -20 },
			{ x = -10, y = -20 },
			{ x = -10, y = 6 },
			{ x = 10, y = 6 },
			{ x = 10, y = -20 },
			{ x = 50, y = -20 },
			{ x = 50, y = 44 },
			{ x = 130, y = 44 },
		},
		waterY = -8,
		buildArea = { minX = -60, maxX = 60, minY = 4, maxY = 92 },
		anchors = {
			{ x = -50, y = 44 },
			{ x = 50, y = 44 },
			-- Eine Felsnadel in der Mitte, gerade breit genug fuer Auflager.
			{ x = -10, y = 6 },
			{ x = 10, y = 6 },
		},
		materials = ALL,
		vehicles = { { kind = "Truck", fromX = -90, toX = 90 } },

		hints = {
			"Hundert Studs am Stueck traegt nichts. Die Felsnadel in der Mitte ist deine Rettung - von dort laesst sich ein Mittelpfeiler bauen.",
			"Teile die Aufgabe: zwei Spannweiten von je fuenfzig Studs sind viel leichter als eine von hundert. Und fuenfzig Studs kennst du schon aus Level 5.",
			"Der Mittelpfeiler traegt beide Haelften. Baue ihn aus Stahl und stelle ihn breit auf beide Anker der Felsnadel, damit er nicht kippt.",
		},
	}),
}

--------------------------------------------------------------------------------
-- Zugriff
--------------------------------------------------------------------------------

Levels.byId = {}
for _, level in Levels.list do
	Levels.byId[level.id] = level
end

function Levels.get(id: string)
	return Levels.byId[id]
end

-- Kurzfassung fuer das Level-Menue (ohne die schweren Datenmengen).
function Levels.summaries()
	local out = {}
	for index, level in Levels.list do
		local span = level.buildArea.maxX - level.buildArea.minX
		out[index] = {
			id = level.id,
			order = index,
			world = level.world,
			displayName = level.displayName,
			subtitle = level.subtitle,
			difficulty = level.difficulty,
			budget = level.budget,
			span = span,
			anchorCount = #level.anchors,
			materialCount = #level.materials,
			vehicleCount = #level.vehicles,
			hasBoat = level.boat ~= nil,
			requiresJump = level.requiresJump == true,
			hasHydraulics = table.find(level.materials, "Hydraulic") ~= nil,
			hintCount = #level.hints,
			freeHints = level.freeHints,

			--[[
				Das Gelaendeprofil kommt mit ins Menue. Es ist nur eine
				Handvoll Punkte, und damit kann die Vorschaukarte die
				ECHTE Form des Levels zeichnen statt eines Symbolbilds.
				Genau daran erkennt man die Level im Menue wieder.
			]]
			terrain = level.terrain,
			waterY = level.waterY,
			anchors = level.anchors,
			bounds = level.terrainBounds,
		}
	end
	return out
end

return Levels
