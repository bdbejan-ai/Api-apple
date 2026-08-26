--!nocheck
--[[
	Loesbarkeitspruefung fuer BridgeLab - laeuft OHNE Roblox.

	Das Skript baut mehrere Standard-Brueckenformen, laesst die Testfahrzeuge
	rechnerisch darueberfahren und meldet Kosten und hoechste Auslastung.
	So laesst sich vor dem Spielen feststellen, ob ein Level ueberhaupt
	loesbar ist und ob das Budget passt.

	Aufruf (luau von https://github.com/luau-lang/luau/releases):
	    cd tools
	    luau check_levels.luau

	ACHTUNG: Das Skript liest Levels.luau NICHT aus. Neue Level muessen unten
	in der LEVELS-Tabelle mit denselben Zahlen eingetragen werden.
]]

local TrussSolver = require("../src/Shared/TrussSolver")

local SPECS = {
	Beam   = { cost = 10, maxTension = 500, maxCompression = 500, massPerStud = 2,   minLength = 3, maxLength = 10, rigid = true,  drivable = true },
	Cable  = { cost = 5,  maxTension = 300, maxCompression = 0,   massPerStud = 0.5, minLength = 3, maxLength = 40, rigid = false, drivable = false },
	Pillar = { cost = 15, maxTension = 800, maxCompression = 800, massPerStud = 3,   minLength = 3, maxLength = 40, rigid = true,  drivable = false },
}

--[[
	decks    Liste der Fahrbahnhoehen, von unten nach oben
	vehicles Liste der Testfahrzeuge: deck = Nummer der Fahrbahn,
	         dir = 1 nach rechts, -1 nach links
]]
local LEVELS = {
	{ id = "Level1 Die erste Luecke", budget = 200, gap = 40, decks = { 40 }, upperY = 48, groundY = 20,
	  vehicles = { { deck = 1, dir = 1 } } },

	{ id = "Level2 Tiefer Graben",    budget = 240, gap = 48, decks = { 44 }, upperY = 52, groundY = 12,
	  vehicles = { { deck = 1, dir = 1 } } },

	{ id = "Level3 Schmales Budget",  budget = 135, gap = 40, decks = { 40 }, upperY = 48, groundY = 18,
	  vehicles = { { deck = 1, dir = 1 } } },

	{ id = "Level4 Gegenverkehr",     budget = 360, gap = 48, decks = { 44 }, upperY = 52, groundY = 16,
	  vehicles = { { deck = 1, dir = 1 }, { deck = 1, dir = -1 } } },

	{ id = "Level5 Doppeldecker",     budget = 480, gap = 32, decks = { 40, 56 }, upperY = 64, groundY = 20,
	  vehicles = { { deck = 1, dir = 1 }, { deck = 2, dir = 1, mass = 600 } } },

	{ id = "Level6 Grosse Schlucht",  budget = 320, gap = 80, decks = { 46 }, upperY = 54, groundY = 22,
	  vehicles = { { deck = 1, dir = 1 } } },
}

local VEHICLE_MASS = 1000
local VEHICLE_LENGTH = 8
local SPACING = 4

--------------------------------------------------------------------------------
-- Ankerpunkte wie in Levels.luau
--------------------------------------------------------------------------------

local function buildSnaps(L)
	local snaps = {}
	local right = L.gap / 2
	local left = -right
	local half = right + SPACING

	local function add(row, x, y, fixed)
		snaps[#snaps + 1] = { id = #snaps + 1, row = row, x = x, y = y, fixed = fixed }
	end

	for index, deckY in L.decks do
		for x = -half, half, SPACING do
			add("deck" .. index, x, deckY, math.abs(x) >= right)
		end
	end
	for x = -half, half, SPACING do
		add("upper", x, L.upperY, math.abs(x) >= half - 0.01)
	end
	for x = left, right, SPACING do
		add("ground", x, L.groundY, true)
	end

	return snaps, left, right
end

local function findSnap(snaps, row, x)
	for _, s in snaps do
		if s.row == row and math.abs(s.x - x) < 0.01 then
			return s.id
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Bauformen
--------------------------------------------------------------------------------

local function addDeck(members, snaps, left, right, span, row)
	local x = left
	while x < right - 0.01 do
		local nextX = math.min(x + span, right)
		local a, b = findSnap(snaps, row, x), findSnap(snaps, row, nextX)
		if not a or not b then return false end
		if nextX - x > SPECS.Beam.maxLength + 0.01 then return false end
		members[#members + 1] = { kind = "Beam", a = a, b = b }
		x = nextX
	end
	return true
end

-- Senkrechte Stuetzen zwischen zwei Reihen
local function addPillars(members, snaps, xs, fromRow, toRow, height)
	if height > SPECS.Pillar.maxLength + 0.01 then return false end
	for _, x in xs do
		local a, b = findSnap(snaps, fromRow, x), findSnap(snaps, toRow, x)
		if not a or not b then return false end
		members[#members + 1] = { kind = "Pillar", a = a, b = b }
	end
	return true
end

local function pillarXs(left, right, step)
	local xs = {}
	for x = left + step, right - step, step do
		xs[#xs + 1] = x
	end
	return xs
end

--------------------------------------------------------------------------------
-- Auswerten
--------------------------------------------------------------------------------

local function cost(members)
	local total = 0
	for _, m in members do total += SPECS[m.kind].cost end
	return total
end

-- Last EINES Fahrzeugs auf die Knoten seiner Fahrbahn verteilen
local function addVehicleLoads(loads, members, snaps, vehicleX, deckY, mass)
	local share = (mass or VEHICLE_MASS) / 3
	for i = 1, 3 do
		local t = (i - 1) / 2
		local sx = vehicleX - VEHICLE_LENGTH / 2 + t * VEHICLE_LENGTH
		for _, m in members do
			if SPECS[m.kind].drivable then
				local sa, sb = snaps[m.a], snaps[m.b]
				if math.abs(sa.y - deckY) < 0.01 and math.abs(sb.y - deckY) < 0.01 then
					local lo, hi = math.min(sa.x, sb.x), math.max(sa.x, sb.x)
					if sx >= lo - 0.01 and sx <= hi + 0.01 and hi > lo then
						local frac = math.max(0, math.min(1, (sx - sa.x) / (sb.x - sa.x)))
						loads[m.a] = (loads[m.a] or 0) + share * (1 - frac)
						loads[m.b] = (loads[m.b] or 0) + share * frac
						break
					end
				end
			end
		end
	end
end

-- placements: Liste von { x = ..., deckY = ... }
local function evaluate(members, snaps, placements)
	local used = {}
	for _, m in members do used[m.a] = true; used[m.b] = true end

	local nodes, map = {}, {}
	for id = 1, #snaps do
		if used[id] then
			local s = snaps[id]
			nodes[#nodes + 1] = { x = s.x, y = s.y, fixed = s.fixed }
			map[id] = #nodes
		end
	end

	local sm = {}
	for _, m in members do
		sm[#sm + 1] = { a = map[m.a], b = map[m.b], tensionOnly = not SPECS[m.kind].rigid }
	end

	local rawLoads = {}
	for _, p in placements do
		addVehicleLoads(rawLoads, members, snaps, p.x, p.deckY, p.mass)
	end

	local loads, mag = {}, {}
	local function addLoad(i, down)
		loads[i] = loads[i] or { x = 0, y = 0 }
		loads[i].y -= down
		mag[i] = (mag[i] or 0) + math.abs(down)
	end

	-- Eigengewicht
	for _, m in members do
		local sa, sb = snaps[m.a], snaps[m.b]
		local len = math.sqrt((sb.x - sa.x) ^ 2 + (sb.y - sa.y) ^ 2)
		local w = len * SPECS[m.kind].massPerStud
		addLoad(map[m.a], w / 2)
		addLoad(map[m.b], w / 2)
	end
	-- Fahrzeuge
	for id, n in rawLoads do
		if map[id] then addLoad(map[id], n) end
	end

	local res = TrussSolver.solve(nodes, sm, loads)

	local worst, worstKind = 0, nil
	for i, m in members do
		local f = res.forces[i] or 0
		local limit = f >= 0 and SPECS[m.kind].maxTension or math.max(SPECS[m.kind].maxCompression, 1e-6)
		local u = math.abs(f) / limit
		if u > worst then worst, worstKind = u, m.kind end
	end

	local unstable = false
	for i, r in res.residuals do
		if r > math.max(1.0, (mag[i] or 0) * 0.05) then unstable = true end
	end

	return worst, worstKind, unstable, res.solved
end

--------------------------------------------------------------------------------
-- Alle Fahrzeugstellungen durchprobieren
--------------------------------------------------------------------------------

local function driveThrough(members, snaps, L, left, right)
	local worst, worstKind, anyUnstable = 0, nil, false

	local function test(placements)
		local u, kind, unstable, solved = evaluate(members, snaps, placements)
		if not solved then
			worst, worstKind, anyUnstable = 999, "RECHNUNG FEHLGESCHLAGEN", true
			return
		end
		if u > worst then worst, worstKind = u, kind end
		if unstable then anyUnstable = true end
	end

	local from, to = left - 8, right + 8

	if #L.vehicles == 1 then
		local v = L.vehicles[1]
		local deckY = L.decks[v.deck]
		for x = from, to, 1 do
			test({ { x = x, deckY = deckY, mass = v.mass } })
		end
	else
		--[[
			Zwei Fahrzeuge: alle Kombinationen ihrer Positionen durchgehen.
			Schrittweite 3 statt 1, sonst dauert es zu lange - fuer die Frage
			"haelt das ueberhaupt" ist das fein genug.
		]]
		local d1 = L.decks[L.vehicles[1].deck]
		local d2 = L.decks[L.vehicles[2].deck]
		for x1 = from, to, 3 do
			for x2 = from, to, 3 do
				-- Richtung -1 faehrt von rechts nach links.
				local p1 = if L.vehicles[1].dir > 0 then x1 else -x1
				local p2 = if L.vehicles[2].dir > 0 then x2 else -x2
				test({
					{ x = p1, deckY = d1, mass = L.vehicles[1].mass },
					{ x = p2, deckY = d2, mass = L.vehicles[2].mass },
				})
			end
		end
	end

	return worst, worstKind, anyUnstable
end

--------------------------------------------------------------------------------
-- Durchlauf
--------------------------------------------------------------------------------

print(string.rep("=", 78))
print("BRIDGELAB - LOESBARKEITSPRUEFUNG")
print(string.rep("=", 78))

local allSolvable = true

for _, L in LEVELS do
	local snaps, left, right = buildSnaps(L)
	local deckList = ""
	for _, y in L.decks do deckList ..= tostring(y) .. " " end

	print(string.format("\n%s\n   Budget %d  Luecke %d  Fahrbahnen: %s Boden %d  oben %d  Fahrzeuge %d",
		L.id, L.budget, L.gap, deckList, L.groundY, L.upperY, #L.vehicles))

	local candidates = {}

	for _, span in { 4, 8 } do
		--[[
			Grundform: jede Fahrbahn aus Balken, darunter Stuetzen.
			Die unterste Fahrbahn stuetzt sich auf den Schluchtgrund,
			jede weitere auf die Fahrbahn darunter.
		]]
		local m = {}
		local ok = true
		local xs = pillarXs(left, right, span)

		for index, deckY in L.decks do
			if not addDeck(m, snaps, left, right, span, "deck" .. index) then ok = false break end
			local fromRow = if index == 1 then "ground" else "deck" .. (index - 1)
			local fromY = if index == 1 then L.groundY else L.decks[index - 1]
			if not addPillars(m, snaps, xs, fromRow, "deck" .. index, deckY - fromY) then ok = false break end
		end

		if ok then
			candidates[#candidates + 1] =
				{ name = string.format("Stuetzen, %der Raster", span), members = m }
		end
	end

	-- Zusatzform: 8er Fahrbahn, aber Stuetzen alle 4 Studs (mehr Tragkraft)
	do
		local m = {}
		local ok = true
		for index, deckY in L.decks do
			if not addDeck(m, snaps, left, right, 8, "deck" .. index) then ok = false break end
			local fromRow = if index == 1 then "ground" else "deck" .. (index - 1)
			local fromY = if index == 1 then L.groundY else L.decks[index - 1]
			-- Stuetzen nur dort, wo die 8er-Fahrbahn auch Knoten hat
			if not addPillars(m, snaps, pillarXs(left, right, 8), fromRow, "deck" .. index, deckY - fromY) then
				ok = false
				break
			end
		end
		-- zusaetzliche Stuetzen in der Mitte
		if ok then
			for index, deckY in L.decks do
				local fromRow = if index == 1 then "ground" else "deck" .. (index - 1)
				addPillars(m, snaps, { -4, 4 }, fromRow, "deck" .. index, deckY - (if index == 1 then L.groundY else L.decks[index - 1]))
			end
			candidates[#candidates + 1] = { name = "8er Fahrbahn + Mittelstuetzen", members = m }
		end
	end

	local cheapest = nil
	for _, c in candidates do
		local price = cost(c.members)
		local worst, kind, unstable = driveThrough(c.members, snaps, L, left, right)
		local holds = worst <= 1.0 and not unstable
		local fits = price <= L.budget

		local verdict
		if holds and fits then
			verdict = "LOESUNG"
			-- Eine echte Loesung ersticht immer einen Eintrag, der nur "haelt,
			-- aber zu teuer" war.
			if not cheapest or cheapest.overBudget or price < cheapest.price then
				cheapest = { price = price, name = c.name }
			end
		elseif holds then
			verdict = "haelt, zu teuer"
			if not cheapest then cheapest = { price = price, name = c.name, overBudget = true } end
		elseif fits then
			verdict = if unstable then "bezahlbar, instabil" else "bezahlbar, bricht"
		else
			verdict = "zu teuer, haelt nicht"
		end

		print(string.format("   %-32s Kosten %3d/%3d  max %5.0f%%  %s%s",
			c.name, price, L.budget, worst * 100, verdict, kind and (" [" .. kind .. "]") or ""))
	end

	if cheapest and not cheapest.overBudget then
		print(string.format("   => LOESBAR ueber '%s' fuer %d (%d%% Budget uebrig)",
			cheapest.name, cheapest.price, math.floor((L.budget - cheapest.price) / L.budget * 100)))
	elseif cheapest then
		allSolvable = false
		print(string.format("   => NICHT LOESBAR. Billigste haltende Form kostet %d -> Budget %d empfohlen",
			cheapest.price, math.ceil(cheapest.price * 1.4 / 10) * 10))
	else
		allSolvable = false
		print("   => NICHT LOESBAR. Keine geprueffte Form haelt.")
	end
end

print("\n" .. string.rep("=", 78))
print(if allSolvable then "ALLE LEVEL LOESBAR" else "ACHTUNG: mindestens ein Level ist nicht loesbar")
