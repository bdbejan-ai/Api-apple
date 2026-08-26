--!nocheck
--[[
	Loesbarkeitspruefung fuer BridgeLab - laeuft OHNE Roblox.

	Das Skript baut je Level mehrere Standard-Brueckenformen auf dem freien
	Raster, laesst die Fahrzeuge rechnerisch darueberfahren und meldet Kosten
	und hoechste Auslastung.

	NEU UND WICHTIG: Es liest die echten Leveldaten aus src/Shared/Levels.luau,
	statt eine Kopie zu pflegen. Frueher standen die Zahlen zweimal im Projekt,
	und genau dadurch ist mir schon einmal ein Fehler durchgerutscht.

	Moeglich ist das, weil Levels.luau bewusst ohne Roblox-Typen auskommt:
	Groessen und Farben stehen dort als einfache Tabellen.

	Aufruf (luau von https://github.com/luau-lang/luau/releases):
	    cd tools
	    luau check_levels.luau
]]

local Levels = require("../src/Shared/Levels")
local Terrain = require("../src/Shared/Terrain")
local TrussSolver = require("../src/Shared/TrussSolver")

--------------------------------------------------------------------------------
-- Baustoffe (Spiegel von Materials.luau, ohne die Aussehen-Felder)
--------------------------------------------------------------------------------

local MAT = {
	Road           = { tension = 500,  compression = 500,  cost = 8,  mass = 2.0, maxLen = 10, rigid = true,  drivable = true },
	ReinforcedRoad = { tension = 1000, compression = 1000, cost = 14, mass = 3.0, maxLen = 10, rigid = true,  drivable = true },
	Wood           = { tension = 550,  compression = 550,  cost = 5,  mass = 1.5, maxLen = 12, rigid = true,  drivable = false },
	Steel          = { tension = 1200, compression = 1200, cost = 10, mass = 2.5, maxLen = 16, rigid = true,  drivable = false },
	Rope           = { tension = 300,  compression = 0,    cost = 2,  mass = 0.4, maxLen = 40, rigid = false, drivable = false },
	Cable          = { tension = 800,  compression = 0,    cost = 5,  mass = 0.8, maxLen = 40, rigid = false, drivable = false },
	Hydraulic      = { tension = 900,  compression = 900,  cost = 25, mass = 3.0, maxLen = 14, rigid = true,  drivable = false },
}

local GRID = 2

--------------------------------------------------------------------------------
-- Bauplan zusammenstellen
--------------------------------------------------------------------------------

local Plan = {}
Plan.__index = Plan

local function newPlan(level)
	return setmetatable({
		level = level,
		joints = {}, -- key -> { x, y, fixed }
		order = {}, -- Reihenfolge fuer den Rechner
		members = {}, -- { material, a, b }
		failed = nil, -- Grund, warum der Plan nicht baubar ist
	}, Plan)
end

local function key(x, y)
	return string.format("%d:%d", math.round(x / GRID), math.round(y / GRID))
end

function Plan:joint(x, y)
	x = math.round(x / GRID) * GRID
	y = math.round(y / GRID) * GRID
	local k = key(x, y)

	if not self.joints[k] then
		local anchor = self.level.anchorAt(x, y)
		self.joints[k] = { x = x, y = y, fixed = anchor ~= nil }
		table.insert(self.order, k)
	end

	return k
end

function Plan:add(material, ax, ay, bx, by)
	if self.failed then
		return
	end

	local spec = MAT[material]
	if not spec then
		self.failed = "unbekannter Baustoff " .. material
		return
	end
	if not self.level.allowsMaterial(material) then
		self.failed = material .. " ist in diesem Level gesperrt"
		return
	end

	local a = self:joint(ax, ay)
	local b = self:joint(bx, by)
	local ja, jb = self.joints[a], self.joints[b]

	local length = math.sqrt((jb.x - ja.x) ^ 2 + (jb.y - ja.y) ^ 2)
	if length < 1e-6 then
		return
	end
	if length > spec.maxLen + 0.01 then
		self.failed = string.format("%s zu lang: %.1f von %d Studs", material, length, spec.maxLen)
		return
	end
	if Terrain.segmentBlocked(self.level.terrain, ja.x, ja.y, jb.x, jb.y) then
		self.failed = "Bauteil laeuft durch den Berg"
		return
	end

	table.insert(self.members, { material = material, a = a, b = b, length = length })
end

--[[
	Wie add, aber fuer OPTIONALE Verstrebungen: ist das Bauteil zu lang,
	wird es stillschweigend weggelassen, statt den ganzen Plan zu verwerfen.

	Ohne diese Unterscheidung hat eine einzige zu lange Querstrebe im
	Pfeiler das komplette Level als unloesbar gemeldet - obwohl die Strebe
	fuer die Tragfaehigkeit gar nicht noetig war.
]]
function Plan:tryAdd(material, ax, ay, bx, by)
	local spec = MAT[material]
	if not spec then
		return
	end
	local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	if length > spec.maxLen + 0.01 or length < 1e-6 then
		return
	end
	self:add(material, ax, ay, bx, by)
end

-- Kette aus Bauteilen entlang einer Punktliste
function Plan:chain(material, points)
	for i = 1, #points - 1 do
		self:add(material, points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
	end
end

function Plan:cost()
	local total = 0
	for _, m in self.members do
		total += math.ceil(MAT[m.material].cost * m.length)
	end
	return total
end

--------------------------------------------------------------------------------
-- Rechnen
--------------------------------------------------------------------------------

--[[
	Last eines Fahrzeugs auf die Knoten verteilen. Wie im Spiel wird an drei
	Stellen ueber die Fahrzeuglaenge abgetastet.
]]
local function addVehicleLoad(plan, index, loads, vehicleX, vehicle)
	local share = vehicle.mass / 3
	local halfLength = vehicle.size.X / 2

	for i = 1, 3 do
		local t = (i - 1) / 2
		local sx = vehicleX - halfLength + t * vehicle.size.X

		-- Das befahrbare Bauteil suchen, das an dieser Stelle am hoechsten liegt.
		local bestMember, bestFrac, bestY = nil, 0.5, -math.huge

		for _, m in plan.members do
			if not MAT[m.material].drivable then
				continue
			end
			local ja, jb = plan.joints[m.a], plan.joints[m.b]
			local lo, hi = ja, jb
			if lo.x > hi.x then
				lo, hi = jb, ja
			end
			if hi.x - lo.x < 1e-6 then
				continue
			end
			if sx >= lo.x - 0.01 and sx <= hi.x + 0.01 then
				local f = (sx - lo.x) / (hi.x - lo.x)
				local y = lo.y + (hi.y - lo.y) * f
				if y > bestY then
					bestY = y
					bestMember = m
					-- Anteil bezogen auf die Reihenfolge a -> b
					bestFrac = if ja.x <= jb.x then f else 1 - f
				end
			end
		end

		if bestMember then
			loads[bestMember.a] = (loads[bestMember.a] or 0) + share * (1 - bestFrac)
			loads[bestMember.b] = (loads[bestMember.b] or 0) + share * bestFrac
		end
	end
end

-- placements: Liste von { x, vehicle }
local function evaluate(plan, placements)
	local nodes, map = {}, {}
	for i, k in plan.order do
		local j = plan.joints[k]
		nodes[i] = { x = j.x, y = j.y, fixed = j.fixed }
		map[k] = i
	end

	local sm = {}
	for i, m in plan.members do
		sm[i] = { a = map[m.a], b = map[m.b], tensionOnly = not MAT[m.material].rigid }
	end

	local rawLoads = {}
	for index, p in placements do
		addVehicleLoad(plan, index, rawLoads, p.x, p.vehicle)
	end

	local loads, mag = {}, {}
	local function addLoad(i, down)
		loads[i] = loads[i] or { x = 0, y = 0 }
		loads[i].y -= down
		mag[i] = (mag[i] or 0) + math.abs(down)
	end

	for _, m in plan.members do
		local w = m.length * MAT[m.material].mass
		addLoad(map[m.a], w / 2)
		addLoad(map[m.b], w / 2)
	end
	for k, n in rawLoads do
		if map[k] then
			addLoad(map[k], n)
		end
	end

	local res = TrussSolver.solve(nodes, sm, loads)

	--[[
		Das am staerksten belastete Bauteil wird MIT LAGE gemeldet, nicht nur
		mit Baustoff. "Holz bei 140 Prozent" sagt naemlich nicht, ob der
		Obergurt, eine Diagonale oder die Verstaerkung unter der Fahrbahn
		nachgibt - und davon haengt ab, was am Level zu aendern ist.
	]]
	local worst, worstMat = 0, nil
	for i, m in plan.members do
		local f = res.forces[i] or 0
		local spec = MAT[m.material]
		local limit = if f >= 0 then spec.tension else math.max(spec.compression, 1e-6)
		local u = math.abs(f) / limit
		if u > worst then
			local ja, jb = plan.joints[m.a], plan.joints[m.b]
			worst = u
			worstMat = string.format(
				"%s (%d|%d)-(%d|%d) %s%.0fN",
				m.material, ja.x, ja.y, jb.x, jb.y,
				if f >= 0 then "Zug " else "Druck ", math.abs(f)
			)
		end
	end

	--[[
		Ein Knoten gilt als instabil, wenn eine Restkraft uebrig bleibt, die
		kein Bauteil aufnehmen kann - dort haelt die Konstruktion also gar
		nichts. Der schlimmste solche Knoten wird MIT NAMEN gemeldet: ohne ihn
		steht in der Ausgabe nur "instabil", und man sucht sich tot.
	]]
	local unstable, worstNode, worstResidual = false, nil, 0
	for i, r in res.residuals do
		if r > math.max(1.0, (mag[i] or 0) * 0.05) then
			unstable = true
			if r > worstResidual then
				worstResidual = r
				local n = nodes[i]
				local degree = 0
				for _, m in sm do
					if m.a == i or m.b == i then
						degree += 1
					end
				end
				worstNode = string.format("(%d|%d) %d Teile, Rest %.0fN", n.x, n.y, degree, r)
			end
		end
	end

	return worst, worstMat, unstable, res.solved, worstNode
end

local function driveThrough(plan)
	local level = plan.level
	local worst, worstMat, anyUnstable = 0, nil, false

	local badNode = nil

	local function test(placements)
		local u, mat, unstable, solved, node = evaluate(plan, placements)
		if not solved then
			worst, worstMat, anyUnstable = 999, "RECHNUNG FEHLGESCHLAGEN", true
			return
		end
		if u > worst then
			worst, worstMat = u, mat
		end
		if unstable then
			anyUnstable = true
			badNode = badNode or node
		end
	end

	local from = level.buildArea.minX - 10
	local to = level.buildArea.maxX + 10

	if #level.vehicles == 1 then
		local v = level.vehicles[1]
		for x = from, to, 2 do
			test({ { x = x, vehicle = v } })
		end
	else
		local v1, v2 = level.vehicles[1], level.vehicles[2]
		for x1 = from, to, 4 do
			for x2 = from, to, 4 do
				local p1 = if v1.direction > 0 then x1 else -x1
				local p2 = if v2.direction > 0 then x2 else -x2
				test({ { x = p1, vehicle = v1 }, { x = p2, vehicle = v2 } })
			end
		end
	end

	return worst, worstMat, anyUnstable, badNode
end

--------------------------------------------------------------------------------
-- Bauformen
--------------------------------------------------------------------------------

--[[
	Die beiden Anker, zwischen denen die FAHRBAHN gespannt wird.

	Massgeblich ist die Hoehe, auf der das Fahrzeug LOSFAEHRT und ANKOMMT.
	Je Seite wird der Anker genommen, dessen Hoehe dieser Fahrhoehe am
	naechsten liegt; bei Gleichstand der weiter innen liegende.

	Zwei frueher probierte Regeln sind daran gescheitert:
	  * "der hoechste Anker je Seite" - auf Levels mit Tuermen sind das die
	    TURMSPITZEN, und das Skript spannte die Fahrbahn von Spitze zu Spitze.
	  * "der innerste Anker je Seite" - in der grossen Schlucht sind das die
	    Anker auf der Felsnadel MITTEN in der Schlucht, 38 Studs unter der
	    Fahrbahn. Auch daraus wurde keine sinnvolle Bruecke.

	Die Fahrhoehe ist das einzige Merkmal, das auf allen zwoelf Levels das
	Richtige trifft: die Fahrbahn muss dort anfangen, wo das Fahrzeug steht.
]]
local function deckAnchors(level)
	local first = level.vehicles[1]
	local startY = if first then first.startY else 0
	local finishY = if first then first.finishY else 0

	local left, right = nil, nil
	local leftGap, rightGap = math.huge, math.huge

	for _, a in level.anchors do
		if a.x < 0 then
			local gap = math.abs(a.y - startY)
			if gap < leftGap - 0.01 or (math.abs(gap - leftGap) <= 0.01 and left and a.x > left.x) then
				left, leftGap = a, math.min(gap, leftGap)
			end
		elseif a.x > 0 then
			local gap = math.abs(a.y - finishY)
			if gap < rightGap - 0.01 or (math.abs(gap - rightGap) <= 0.01 and right and a.x < right.x) then
				right, rightGap = a, math.min(gap, rightGap)
			end
		end
	end

	return left, right
end

local function lowAnchors(level)
	local left, right = nil, nil
	for _, a in level.anchors do
		if a.x < 0 and (not left or a.y < left.y) then
			left = a
		end
		if a.x > 0 and (not right or a.y < right.y) then
			right = a
		end
	end
	return left, right
end

-- Punkte gleichmaessig auf der Geraden von A nach B
local function line(ax, ay, bx, by, segments)
	local pts = {}
	for i = 0, segments do
		local t = i / segments
		pts[i + 1] = { ax + (bx - ax) * t, ay + (by - ay) * t }
	end
	return pts
end

--[[
	FACHWERK - eine Funktion fuer alle Spielarten

	Fahrbahn unten, Gurt oben, dazwischen Pfosten und Diagonalen.

	    o----o----o----o----o   Obergurt
	    |\   |\   |   /|   /|
	    | \  | \  |  / |  / |   Pfosten und Diagonalen
	    |  \ |  \ | /  | /  |
	    o----o----o----o----o   Fahrbahn (zugleich Untergurt)
	    ^                   ^
	  Anker               Anker

	options:
	  depth      Bauhoehe
	  panel      Feldbreite
	  reinforce  zweites, starkes Bauteil neben die Fahrbahn legen
	  doubleTop  Obergurt doppelt ausfuehren
	  cross      BEIDE Diagonalen je Feld statt nur einer

	WOZU "cross" DA IST - der haeufigste Bruch ueberhaupt
	Mit nur einer Diagonale je Feld gibt es genau EINEN Weg, auf dem die
	Auflagerkraft vom Anker nach oben ins Fachwerk gelangt: die erste
	Diagonale. Sie traegt damit die gesamte Auflagerkraft allein, und in fast
	allen Fehlversuchen ist genau sie gerissen - erkennbar daran, dass das
	ueberlastete Bauteil immer direkt am Anker sass.

	Mit beiden Diagonalen teilen sich zwei Bauteile diese Kraft. Das kostet
	Material, halbiert aber die groesste Einzelkraft - und darum geht es.
]]
local function trussPlan(level, deckMat, webMat, options)
	local a, b = deckAnchors(level)
	if not a or not b then
		return nil
	end

	local depth = options.depth
	local panel = options.panel

	local plan = newPlan(level)
	local span = b.x - a.x
	local segments = math.max(2, math.round(span / panel))

	local deck = line(a.x, a.y, b.x, b.y, segments)
	plan.deckPoints = deck
	plan:chain(deckMat, deck)
	if options.reinforce then
		-- Zweites Bauteil auf denselben Knoten: die eigentliche Verstaerkung.
		plan:chain(webMat, deck)
	end

	local top = {}
	for i, point in deck do
		top[i] = { point[1], point[2] + depth }
	end
	plan:chain(webMat, top)
	if options.doubleTop then
		plan:chain(webMat, top)
	end

	-- Pfosten
	for i = 1, #deck do
		plan:add(webMat, deck[i][1], deck[i][2], top[i][1], top[i][2])
	end

	-- Diagonalen
	for i = 1, #deck - 1 do
		local rising = i % 2 == 1
		if rising or options.cross then
			plan:add(webMat, deck[i][1], deck[i][2], top[i + 1][1], top[i + 1][2])
		end
		if not rising or options.cross then
			plan:add(webMat, top[i][1], top[i][2], deck[i + 1][1], deck[i + 1][2])
		end
	end

	return plan
end

--[[
	BOGEN
	Ein Druckbogen von den tiefen Ankern zu den tiefen Ankern, darauf
	senkrechte Stuetzen bis zur Fahrbahn.
]]
local function archPlan(level, deckMat, archMat, panel)
	local da, db = deckAnchors(level)
	local la, lb = lowAnchors(level)
	if not da or not db or not la or not lb then
		return nil
	end
	-- Nur sinnvoll, wenn es wirklich TIEFE Anker gibt.
	if la.y > da.y - 12 or lb.y > db.y - 12 then
		return nil
	end

	local plan = newPlan(level)
	local span = db.x - da.x
	local segments = math.max(4, math.round(span / panel))

	plan:chain(deckMat, line(da.x, da.y, db.x, db.y, segments))

	-- Parabelbogen von la nach lb, Scheitel knapp unter der Fahrbahn
	local crown = math.min(da.y, db.y) - 6
	local arch = {}
	for i = 0, segments do
		local t = i / segments
		local x = la.x + (lb.x - la.x) * t
		-- Parabel: 0 an den Enden, 1 in der Mitte
		local shape = 4 * t * (1 - t)
		local baseY = la.y + (lb.y - la.y) * t
		arch[i + 1] = { x, baseY + (crown - baseY) * shape }
	end
	plan:chain(archMat, arch)

	-- Stuetzen vom Bogen hoch zur Fahrbahn
	local deck = line(da.x, da.y, db.x, db.y, segments)
	for i = 2, segments do
		if deck[i][2] - arch[i][2] > 1.5 then
			plan:add(archMat, arch[i][1], arch[i][2], deck[i][1], deck[i][2])
		end
	end

	return plan
end

--[[
	HAENGEBRUECKE
	Ein durchhaengendes Tragseil zwischen zwei HOHEN Ankern, davon
	senkrechte Haenger hinunter zur Fahrbahn.
]]
local function suspensionPlan(level, deckMat, cableMat, hangerMat, panel)
	local da, db = deckAnchors(level)
	if not da or not db then
		return nil
	end

	-- Hohe Anker suchen: deutlich ueber der Fahrbahn
	local ha, hb = nil, nil
	for _, a in level.anchors do
		if a.y > da.y + 8 then
			if a.x < 0 and (not ha or a.y > ha.y) then
				ha = a
			end
			if a.x > 0 and (not hb or a.y > hb.y) then
				hb = a
			end
		end
	end
	if not ha or not hb then
		return nil
	end

	local plan = newPlan(level)
	local span = db.x - da.x
	local segments = math.max(4, math.round(span / panel))

	local deck = line(da.x, da.y, db.x, db.y, segments)
	plan.deckPoints = deck
	plan:chain(deckMat, deck)

	--[[
		AN JEDEM FAHRBAHNKNOTEN EIN HAENGER - das war der Fehler

		Vorher lagen die Seilknoten unabhaengig von den Fahrbahnknoten, und die
		Haenger trafen nur zufaellig zusammen. Ein Fahrbahnknoten ohne Haenger
		haengt aber nur zwischen zwei Fahrbahnstuecken, die BEIDE waagerecht
		laufen - senkrecht haelt ihn dann nichts:

		    o-------o-------o     <- der mittlere Knoten faellt einfach durch
		            |
		         kein Haenger

		Deshalb bekommt das Tragseil jetzt genau ueber jedem Fahrbahnknoten
		einen eigenen Knoten. Dann geht von jedem Fahrbahnknoten ein Haenger
		nach oben, und die Last erreicht das Seil ueberhaupt erst.
	]]
	local lowPoint = math.max(da.y, db.y) + 8
	local cable = {}
	for i, point in deck do
		local x = point[1]
		local t = (x - ha.x) / (hb.x - ha.x)
		local shape = 4 * t * (1 - t)
		local baseY = ha.y + (hb.y - ha.y) * t
		cable[i] = { x, baseY + (lowPoint - baseY) * shape }
	end

	-- Das Seil laeuft von Turmspitze zu Turmspitze ueber alle Zwischenknoten.
	local full = { { ha.x, ha.y } }
	for _, c in cable do
		table.insert(full, c)
	end
	table.insert(full, { hb.x, hb.y })
	plan:chain(cableMat, full)

	-- Haenger: von jedem Fahrbahnknoten senkrecht hinauf ans Seil.
	for i, point in deck do
		local up = cable[i]
		if up[2] - point[2] > 3 then
			plan:add(hangerMat, point[1], point[2], up[1], up[2])
		end
	end

	return plan
end

--[[
	WARUM DIE FAHRBAHN VERSTAERKT WERDEN MUSS

	Die Fahrbahn ist beim Fachwerk gleichzeitig der UNTERGURT. Sie muss also
	die volle Gurtkraft aushalten - und Strasse haelt nur 500 N.

	Die Loesung ist dieselbe wie beim echten Vorbild: NEBEN die Fahrbahn wird
	auf denselben beiden Knoten ein zweites, starkes Bauteil gesetzt. Beide
	teilen sich dann die Gurtkraft.

	    vorher:   o====== Strasse ======o        500 N Grenze
	    nachher:  o====== Strasse ======o        beide zusammen
	              o======= Stahl =======o        1000 N Grenze

	Warum sich die Kraft gleichmaessig teilt: der Rechner sucht unter allen
	Kraftverteilungen, die im Gleichgewicht sind, die mit der kleinsten
	Quadratsumme. Bei zwei gleich langen Bauteilen zwischen denselben Knoten
	ist das genau die Haelfte fuer jedes.

	Der SCHWAECHERE der beiden bestimmt die Grenze: Strasse (500) mit Stahl
	(1200) traegt zusammen 1000 N, nicht 1700. Mit verstaerkter Strasse
	(1000 N) sind es dagegen 2000 N - der doppelte Preis je Stud kauft hier
	also wirklich die doppelte Tragfaehigkeit.

	Gebaut wird das oben in trussPlan ueber options.reinforce.
]]

--[[
	PFEILER - jeden uebrigen Anker mitbenutzen

	Manche Level bieten mehr als die zwei Anker an den Ufern: eine Felsnadel
	mitten in der Schlucht, ein Felsvorsprung unter der Fahrbahn. Wer die
	stehen laesst, muss die ganze Spannweite auf einmal ueberbruecken - und
	genau daran scheitern die grossen Level.

	    ohne Pfeiler        o------------------------------o   100 Studs
	    mit Pfeiler         o--------------o---------------o   2 x 50 Studs

	Weil die Gurtkraft mit der Spannweite waechst, halbiert ein Pfeiler in der
	Mitte sie nicht nur einmal, sondern gleich doppelt: die Spannweite wird
	kuerzer UND die Last verteilt sich auf mehr Auflager.

	Diese Funktion setzt auf einen fertigen Plan noch senkrechte Stuetzen von
	jedem ungenutzten Anker hinauf zur Fahrbahn. Weil ein einzelnes Bauteil
	nur begrenzt lang sein darf, wird die Stuetze aus mehreren Stuecken
	gestapelt, und jedes Zwischenstueck wird schraeg nach beiden Seiten
	abgespannt - eine freistehende Stange knickt sonst weg.
]]
local function addPiers(plan, level, mat, deckA, deckB, deck)
	local spec = MAT[mat]
	if not spec or not deck or #deck < 3 then
		return
	end

	for _, anchor in level.anchors do
		-- Die beiden Fahrbahnanker tragen schon, die brauchen keine Stuetze.
		if anchor == deckA or anchor == deckB then
			continue
		end

		local t = (anchor.x - deckA.x) / (deckB.x - deckA.x)
		if t <= 0.02 or t >= 0.98 then
			continue
		end
		local deckY = deckA.y + (deckB.y - deckA.y) * t
		if deckY - anchor.y < 4 then
			continue
		end

		-- Die drei Fahrbahnknoten ueber dem Anker suchen.
		local nearest, nearestGap = 1, math.huge
		for i, point in deck do
			local gap = math.abs(point[1] - anchor.x)
			if gap < nearestGap then
				nearest, nearestGap = i, gap
			end
		end
		if nearest <= 1 or nearest >= #deck then
			continue
		end

		local targets = { deck[nearest - 1], deck[nearest], deck[nearest + 1] }

		--[[
			DER PFEILER IST EIN TURM MIT MITTELMAST, KEIN DREIECK

			Erster Versuch war ein einfaches Dreieck: zwei Schenkel vom Anker
			hinauf zu den beiden Fahrbahnknoten links und rechts. Das ist
			oben aber 20 Studs breit, und ein Querriegel darf hoechstens 16
			Studs lang sein. Die zu lange Querstrebe hat den ganzen Plan
			ungueltig gemacht - deshalb kam in der grossen Schlucht ueberhaupt
			keine Pfeilerform mehr durch die Pruefung.

			Jetzt laeuft in der Mitte ein senkrechter Mast mit hoch. Jede
			Querstrebe geht nur noch vom Mast zu EINEM Schenkel und ist damit
			halb so lang:

			    o-----o-----o     Fahrbahn
			     \    |    /
			      \---+---/       Querstreben je nur halbe Breite
			       \  |  /
			        \-+-/
			          A           Anker auf dem Felsen
		]]
		local longest = 0
		for _, target in targets do
			longest = math.max(longest, math.sqrt(
				(target[1] - anchor.x) ^ 2 + (target[2] - anchor.y) ^ 2
			))
		end
		local pieces = math.max(1, math.ceil(longest / (spec.maxLen * 0.85)))

		-- Fuer jeden der drei Straenge die Zwischenpunkte ausrechnen.
		local strands = {}
		for index, target in targets do
			local points = {}
			for i = 0, pieces do
				local f = i / pieces
				points[i] = {
					anchor.x + (target[1] - anchor.x) * f,
					anchor.y + (target[2] - anchor.y) * f,
				}
			end
			strands[index] = points
		end

		-- Die drei Straenge nach oben bauen.
		for _, points in strands do
			for i = 1, pieces do
				plan:add(mat, points[i - 1][1], points[i - 1][2], points[i][1], points[i][2])
			end
		end

		-- Querstreben vom Mittelmast zu den beiden Schenkeln.
		local mast = strands[2]
		for _, side in { 1, 3 } do
			local leg = strands[side]
			for i = 1, pieces - 1 do
				plan:tryAdd(mat, mast[i][1], mast[i][2], leg[i][1], leg[i][2])
				-- Eine Diagonale je Feld haelt den Turm gegen Verschieben.
				plan:tryAdd(mat, mast[i - 1][1], mast[i - 1][2], leg[i][1], leg[i][2])
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Durchlauf
--------------------------------------------------------------------------------

local function candidatesFor(level)
	local out = {}

	--[[
		Verworfene Plaene werden MIT GRUND gesammelt. Frueher verschwanden sie
		stumm, und dann stand da nur "keine Standardform baubar" - ohne zu
		sagen, ob der Baustoff gesperrt war, ein Teil zu lang oder die Strecke
		durch den Berg lief. Diese Liste hat die Fehlersuche entschieden.
	]]
	local rejected = {}

	local function try(name, plan)
		if not plan then
			table.insert(rejected, name .. ": Form passt nicht zum Level (Anker fehlen)")
			return
		end
		if plan.failed then
			table.insert(rejected, name .. ": " .. plan.failed)
			return
		end
		if #plan.members == 0 then
			table.insert(rejected, name .. ": leer")
			return
		end
		table.insert(out, { name = name, plan = plan })
	end

	--[[
		Beide Fahrbahnbaustoffe werden durchprobiert. Das ist kein Detail:
		verstaerkt man die Strasse (500 N) mit Stahl, teilen sich beide die
		Kraft, und die Strasse ist bei 500 am Ende - zusammen also 1000 N.
		Nimmt man die verstaerkte Strasse (1000 N), sind es 2000 N. Der
		doppelte Preis je Stud kauft also die doppelte Tragfaehigkeit.
	]]
	local deckMats = {}
	if level.allowsMaterial("Road") then
		table.insert(deckMats, "Road")
	end
	if level.allowsMaterial("ReinforcedRoad") then
		table.insert(deckMats, "ReinforcedRoad")
	end
	local deckMat = deckMats[1]
	local strong = if level.allowsMaterial("Steel") then "Steel" else "Wood"

	--[[
		Jede Fachwerkform wird ZWEIMAL geprueft: einmal frei gespannt und
		einmal auf den zusaetzlichen Ankern abgestuetzt. Nur so zeigt sich,
		ob ein Level die Pfeiler wirklich braucht oder ob es auch ohne geht.
	]]
	local dA, dB = deckAnchors(level)
	local hasSpareAnchors = dA ~= nil and dB ~= nil and #level.anchors > 2

	local function tryBoth(name, builder)
		local plain = builder()
		try(name, plain)
		if hasSpareAnchors then
			local plan = builder()
			if plan and not plan.failed then
				addPiers(plan, level, strong, dA, dB, plan.deckPoints)
			end
			try(name .. " +Pfeiler", plan)
		end
	end

	for _, deckMat in deckMats do
	for _, depth in { 6, 8, 10, 12, 16 } do
		for _, panel in { 6, 8, 10 } do
			for _, cross in { false, true } do
				local suffix = if cross then " X" else ""

				tryBoth(string.format("Fachwerk %s/%s h%d p%d%s", strong, deckMat, depth, panel, suffix), function()
					return trussPlan(level, deckMat, strong, { depth = depth, panel = panel, cross = cross })
				end)
				tryBoth(string.format("Verstaerkt %s/%s h%d p%d%s", strong, deckMat, depth, panel, suffix), function()
					return trussPlan(level, deckMat, strong, {
						depth = depth, panel = panel, cross = cross, reinforce = true,
					})
				end)
				tryBoth(string.format("Verstaerkt %s/%s h%d p%d%s ++", strong, deckMat, depth, panel, suffix), function()
					return trussPlan(level, deckMat, strong, {
						depth = depth, panel = panel, cross = cross, reinforce = true, doubleTop = true,
					})
				end)

				if strong ~= "Wood" and level.allowsMaterial("Wood") then
					try(string.format("Verstaerkt Holz/%s h%d p%d%s", deckMat, depth, panel, suffix),
						trussPlan(level, deckMat, "Wood", {
							depth = depth, panel = panel, cross = cross, reinforce = true,
						}))
				end
			end
		end
	end
	end

	for _, panel in { 8, 10 } do
		try(string.format("Bogen %s p%d", strong, panel), archPlan(level, deckMat, strong, panel))
	end

	local cableMat = if level.allowsMaterial("Cable") then "Cable" else "Rope"
	for _, panel in { 8, 10 } do
		try(
			string.format("Haengebruecke %s p%d", cableMat, panel),
			suspensionPlan(level, deckMat, cableMat, "Rope", panel)
		)
		try(
			string.format("Haengebruecke Holz p%d", panel),
			suspensionPlan(level, deckMat, "Wood", "Rope", panel)
		)
	end

	return out, rejected
end

--------------------------------------------------------------------------------
-- Rastertreue der Leveldaten
--------------------------------------------------------------------------------

--[[
	Jeder Anker MUSS auf einem Rasterpunkt liegen.

	Warum das kein Schoenheitsfehler ist: Knoten werden beim Bauen auf das
	2-Studs-Raster gerundet. Ein Anker bei x = 35 wird dabei zu x = 36 - und
	dort ist kein Anker mehr. Der Knoten gilt dann als frei beweglich, die
	ganze Bruecke haengt an nichts, und der Rechner meldet voellig zu Recht
	"instabil". Von aussen sieht das aus wie ein Fehler in der Statik, ist
	aber schlicht eine ungerade Zahl in den Leveldaten.

	Genau dieser Fehler hat mich im Level "Weit gespannt" lange gekostet,
	deshalb wird er jetzt vor jeder Pruefung abgefangen.
]]
local gridProblems = 0

for _, level in Levels.list do
	local function report(what, x, y)
		print(string.format(
			"   RASTERFEHLER in %s: %s bei (%g|%g) liegt nicht auf dem %d-Studs-Raster",
			level.id, what, x, y, GRID
		))
		gridProblems += 1
	end

	for _, a in level.anchors do
		if a.x % GRID ~= 0 or a.y % GRID ~= 0 then
			report("Anker", a.x, a.y)
		end
	end
	for _, point in level.terrain do
		if point.x % GRID ~= 0 or point.y % GRID ~= 0 then
			report("Gelaendepunkt", point.x, point.y)
		end
	end
end

if gridProblems > 0 then
	print(string.format("\n%d Rasterfehler gefunden - bitte zuerst beheben.\n", gridProblems))
end

print(string.rep("=", 82))
print("BRIDGELAB - LOESBARKEITSPRUEFUNG (freies Bauen)")
print(string.rep("=", 82))

local allSolvable = true

for _, level in Levels.list do
	local span = 0
	local a, b = deckAnchors(level)
	if a and b then
		span = b.x - a.x
	end

	print(string.format(
		"\n%s  %s\n   Budget %d   Spannweite %d   Anker %d   Fahrzeuge %d",
		level.id, level.displayName, level.budget, span, #level.anchors, #level.vehicles
	))

	--[[
		Sprunglevel lassen sich mit Standardformen nicht pruefen: dort gibt es
		gar keine durchgehende Fahrbahn, sondern eine Rampe und eine Luecke.
		Sie werden von Hand entworfen und hier nur vermerkt - sonst meldet das
		Skript einen Fehler, der keiner ist.
	]]
	if level.requiresJump then
		print("   (Sprunglevel - von Hand entworfen, keine Standardform pruefbar)")
		continue
	end

	local list, rejected = candidatesFor(level)
	if #list == 0 then
		print("   !! keine Standardform baubar. Gruende:")
		local seen = {}
		for _, reason in rejected do
			if not seen[reason] then
				seen[reason] = true
				print("      - " .. reason)
			end
		end
	end

	local best, bestOver = nil, nil

	--[[
		Auch der KNAPPESTE Fehlversuch wird ausgegeben. Sonst meldet das Skript
		nur "haelt nicht" und verschweigt, ob es um 5 Prozent oder um 500 ging -
		und genau dieser Unterschied entscheidet, ob ein Level nachjustiert
		oder ganz neu entworfen werden muss.
	]]
	local closest = nil

	local function describe(c, price, worst, mat, unstable, holds, fits, badNode)
		return string.format(
			"   %-28s %4d Teile  Kosten %5d/%5d  max %5.0f%%  %s%s",
			c.name, #c.plan.members, price, level.budget, worst * 100,
			if holds and fits then "LOESUNG" elseif holds then "haelt, zu teuer"
				elseif unstable then "instabil " .. (badNode or "?") else "bricht",
			if mat then " [" .. mat .. "]" else ""
		)
	end

	--[[
		Plaene, die weit ueber dem Budget liegen, werden gar nicht erst
		durchgerechnet. Das Durchfahren ist der mit Abstand teuerste Teil der
		Pruefung, und ein Plan fuer den doppelten Preis ist auch dann keine
		Loesung, wenn er haelt. Ohne diese Abkuerzung lief das Skript in die
		Zeitgrenze, seit es auch Kreuzverbaende durchprobiert.
	]]
	local skipped = 0

	for _, c in list do
		local price = c.plan:cost()
		if price > level.budget * 2 then
			skipped += 1
			continue
		end
		local worst, mat, unstable, badNode = driveThrough(c.plan)
		local holds = worst <= 1.0 and not unstable
		local fits = price <= level.budget

		if holds and fits then
			if not best or price < best.price then
				best = { price = price, name = c.name }
			end
		elseif holds then
			if not bestOver or price < bestOver.price then
				bestOver = { price = price, name = c.name }
			end
		end

		local line = describe(c, price, worst, mat, unstable, holds, fits, badNode)
		if not closest or worst < closest.worst then
			closest = { worst = worst, line = line }
		end

		-- Nur die interessanten Zeilen ausgeben, sonst wird es unlesbar.
		if holds or worst < 1.6 then
			print(line)
		end
	end

	if not best and not bestOver and closest then
		print(closest.line .. "   <- knappester Versuch")
	end
	if skipped > 0 and not best then
		print(string.format("   (%d Formen uebersprungen, weil ueber dem doppelten Budget)", skipped))
	end

	if best then
		print(string.format(
			"   => LOESBAR ueber '%s' fuer %d (%d%% Budget uebrig)",
			best.name, best.price, math.floor((level.budget - best.price) / level.budget * 100)
		))
	elseif bestOver then
		allSolvable = false
		print(string.format(
			"   => NICHT LOESBAR. Billigste haltende Form '%s' kostet %d -> Budget %d empfohlen",
			bestOver.name, bestOver.price, math.ceil(bestOver.price * 1.35 / 100) * 100
		))
	else
		allSolvable = false
		print("   => NICHT LOESBAR. Keine geprueffte Form haelt.")
	end
end

print("\n" .. string.rep("=", 82))
print(if allSolvable then "ALLE LEVEL LOESBAR" else "ACHTUNG: mindestens ein Level ist nicht loesbar")
