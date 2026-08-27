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
		mass = 420,
		size = { X = 6, Y = 3.2, Z = 4.4 },
		color = { 226, 108, 92 },
	},
	Car = {
		key = "Car",
		mass = 900,
		size = { X = 8, Y = 4, Z = 5 },
		color = { 198, 72, 58 },
	},
	Van = {
		key = "Van",
		mass = 650,
		size = { X = 7, Y = 3.6, Z = 4.6 },
		color = { 232, 172, 62 },
	},
	Truck = {
		key = "Truck",
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

	--[[
		WAS DIE KAMERA ZEIGEN SOLL - NICHT DAS GANZE GELAENDE

		Die Kamera darf nur so weit herauszoomen, bis das Level das Bild
		fuellt. Frueher stand hier die volle Breite des GELAENDEPROFILS - und
		das reicht weit ueber die Bruecke hinaus: in der grossen Schlucht von
		-130 bis +130, also 260 Studs, waehrend gebaut wird nur zwischen -60
		und +60. Herausgezoomt waere die Bruecke ein Strich in der Mitte
		gewesen, links und rechts nichts als leeres Plateau.

		Massgeblich ist deshalb der Baubereich samt Ankern, dazu ein Rand als
		Zugabe. Waagerecht wird auf das Gelaende begrenzt: darueber hinaus
		gibt es nichts mehr zu sehen.
	]]
	local t = level.terrainBounds
	local margin = 20

	local minX, maxX = def.buildArea.minX, def.buildArea.maxX
	local minY, maxY = def.buildArea.minY, def.buildArea.maxY

	for _, anchor in def.anchors do
		minX = math.min(minX, anchor.x)
		maxX = math.max(maxX, anchor.x)
		minY = math.min(minY, anchor.y)
		maxY = math.max(maxY, anchor.y)
	end

	if def.waterY then
		minY = math.min(minY, def.waterY)
	end

	--[[
		Bei Sprunglevels muss auch die LANDESEITE ins Bild.

		Sonst endet die Sicht dort, wo der Baubereich endet - und der endet
		beim Sprung mitten in der Luft. Der Spieler soll aber genau das
		abschaetzen koennen: wie weit ist es hinueber und wie tief liegt die
		andere Seite. Bei allen anderen Levels bleibt die Fahrstrecke draussen,
		sie fuehrt nur ueber flaches Plateau und wuerde das Bild unnoetig
		weiten.
	]]
	if def.requiresJump then
		-- Nur das ZIEL, nicht der Anlauf: der fuehrt ueber flaches Plateau
		-- und wuerde das Bild ohne Gewinn weiter machen.
		for _, vehicle in def.vehicles do
			minX = math.min(minX, vehicle.toX)
			maxX = math.max(maxX, vehicle.toX)
		end
	end

	level.bounds = {
		minX = math.max(minX - margin, t.minX),
		maxX = math.min(maxX + margin, t.maxX),
		minY = minY - 12,
		maxY = maxY + 12,
	}

	-- Worauf die Kamera anfangs blickt.
	level.focusY = (def.buildArea.minY + def.buildArea.maxY) / 2

	----------------------------------------------------------------------------
	-- Texte: nur Schluessel, keine Saetze
	----------------------------------------------------------------------------

	--[[
		Namen, Untertitel und Tipps stehen NICHT hier, sondern in I18n.luau -
		einmal auf Deutsch und einmal auf Englisch. Hier entstehen nur die
		Schluessel, und zwar aus der Levelnummer.

		Warum abgeleitet statt hingeschrieben: ein Schluessel, den man tippt,
		kann sich vertippen und zeigt dann im Spiel seinen eigenen Namen an.
		Abgeleitet kann das nicht passieren. Und in den Leveldaten steht nur
		noch, WIE VIELE Tipps es gibt - die Saetze dazu stehen an genau einer
		Stelle.
	]]
	level.nameKey = "level." .. def.id .. ".name"
	level.subtitleKey = "level." .. def.id .. ".subtitle"

	level.hints = {}
	for index = 1, (def.hintCount or 0) do
		level.hints[index] = string.format("level.%s.hint%d", def.id, index)
	end

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

		hintCount = 3,
	}),

	makeLevel({
		id = "W1L2",
		world = "Grundlagen",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W1L3",
		world = "Grundlagen",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W1L4",
		world = "Grundlagen",
		difficulty = 3,
		budget = 700,
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

		hintCount = 3,
	}),

	--------------------------------------------------------------------------
	-- Welt 2: Werkstoffe
	--------------------------------------------------------------------------

	makeLevel({
		id = "W2L5",
		world = "Werkstoffe",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W2L6",
		world = "Werkstoffe",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W2L7",
		world = "Werkstoffe",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W2L8",
		world = "Werkstoffe",
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

		hintCount = 3,
	}),

	--------------------------------------------------------------------------
	-- Welt 3: Bewegliche Teile
	--------------------------------------------------------------------------

	makeLevel({
		id = "W3L9",
		world = "Bewegliches",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W3L10",
		world = "Bewegliches",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W3L11",
		world = "Bewegliches",
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

		hintCount = 3,
	}),

	makeLevel({
		id = "W3L12",
		world = "Bewegliches",
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

		hintCount = 3,
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
			nameKey = level.nameKey,
			subtitleKey = level.subtitleKey,
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
