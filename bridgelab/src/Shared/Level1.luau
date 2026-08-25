--[[
	Level1
	------
	Alle Masse und Ankerpunkte fuer das erste Level.

	Aufbau in Seitenansicht (X nach rechts, Y nach oben, Z = 0):

	        upper  o---o---o---o---o---o---o---o---o---o---o---o---o     y = 48
	                                                                     (Reihe fuer Tuerme, Boegen, Seilaufhaengungen)

	        deck   #---o---o---o---o---o---o---o---o---o---o---o---#     y = 40
	              |###|                  Luecke                  |###|
	              |###|  40 Studs breit, von x = -20 bis x = +20  |###|
	              |###|                                          |###|
	        ground |##| #   #   #   #   #   #   #   #   #   #   #|###|  y = 20
	              +---------------------------------------------------+

	  #  = fester Ankerpunkt (unbeweglich, "am Boden verankert")
	  o  = freier Ankerpunkt (kann sich unter Last bewegen)

	Ankerpunkte liegen alle 4 Studs. Es gibt drei Reihen:
	  "deck"    Hoehe der Fahrbahn        -> hier faehrt das Testfahrzeug
	  "upper"   8 Studs darueber          -> fuer Tuerme und Abspannungen
	  "ground"  am Grund der Schlucht     -> Fusspunkte fuer Stuetzen
]]

local Level1 = {}

Level1.id = "Level1"
Level1.displayName = "Level 1 - Die erste Luecke"

-- Budget in Bau-Einheiten.
Level1.budget = 200

-- Zeitlimit des Belastungstests in Sekunden.
Level1.timeLimit = 30

-- Faellt das Fahrzeug weiter als so viele Studs unter seine Starthoehe,
-- gilt der Test als nicht bestanden.
Level1.maxDropStuds = 10

--------------------------------------------------------------------------------
-- Geometrie
--------------------------------------------------------------------------------

Level1.z = 0 -- Die ganze Bruecke liegt in einer Ebene bei z = 0.

Level1.gapWidth = 40
Level1.gapLeftX = -20
Level1.gapRightX = 20

Level1.deckY = 40 -- Hoehe der Fahrbahn
Level1.upperY = 48 -- obere Ankerreihe
Level1.groundY = 20 -- Grund der Schlucht

Level1.snapSpacing = 4 -- Abstand der Ankerpunkte
Level1.platformLength = 60 -- Laenge der festen Plattformen links und rechts
Level1.platformDepth = 40 -- Tiefe (Z) der Plattformen

--------------------------------------------------------------------------------
-- Testfahrzeug
--------------------------------------------------------------------------------

Level1.vehicle = {
	mass = 1000, -- Masse in Einheiten -> 1000 N Gewichtskraft (g = 1)
	size = Vector3.new(8, 4, 6), -- Laenge (X), Hoehe (Y), Breite (Z)
	speed = 8, -- Studs pro Sekunde, konstant
	startX = -34, -- Startposition auf der linken Plattform
	finishX = 34, -- Ziel auf der rechten Plattform
}

--------------------------------------------------------------------------------
-- Ankerpunkte erzeugen
--------------------------------------------------------------------------------

Level1.snapPoints = {}

local function addSnapPoint(row: string, x: number, y: number, fixed: boolean)
	local list = Level1.snapPoints
	list[#list + 1] = {
		id = #list + 1,
		row = row,
		position = Vector3.new(x, y, Level1.z),
		fixed = fixed,
	}
end

-- Fahrbahnreihe: reicht 4 Studs in die Plattformen hinein.
-- Alles ab |x| >= 20 steht auf festem Boden und ist damit unbeweglich.
for x = -24, 24, Level1.snapSpacing do
	addSnapPoint("deck", x, Level1.deckY, math.abs(x) >= 20)
end

-- Obere Reihe: nur die beiden aeussersten Punkte sind fest.
-- Sie sitzen auf den Pylonen, die auf den Plattformen stehen.
for x = -24, 24, Level1.snapSpacing do
	addSnapPoint("upper", x, Level1.upperY, math.abs(x) >= 24)
end

-- Bodenreihe im Schluchtgrund: alle Punkte fest.
for x = -20, 20, Level1.snapSpacing do
	addSnapPoint("ground", x, Level1.groundY, true)
end

--------------------------------------------------------------------------------
-- Hilfsfunktion
--------------------------------------------------------------------------------

function Level1.getSnapPoint(id: number)
	return Level1.snapPoints[id]
end

return Level1
