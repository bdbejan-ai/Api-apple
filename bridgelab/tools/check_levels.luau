--!nocheck
-- Prueft ausserhalb von Roblox, ob die Level loesbar sind.
-- Baut mehrere Standard-Brueckenformen, laesst das Fahrzeug darueberfahren
-- und meldet Kosten und hoechste Auslastung.

local TrussSolver = require("../src/Shared/TrussSolver")

local SPECS = {
	Beam   = { cost = 10, maxTension = 500, maxCompression = 500, massPerStud = 2,   minLength = 3, maxLength = 10, rigid = true,  vertical = false, drivable = true },
	Cable  = { cost = 5,  maxTension = 300, maxCompression = 0,   massPerStud = 0.5, minLength = 3, maxLength = 40, rigid = false, vertical = false, drivable = false },
	Pillar = { cost = 15, maxTension = 800, maxCompression = 800, massPerStud = 3,   minLength = 3, maxLength = 40, rigid = true,  vertical = true,  drivable = false },
}

-- Wichtig: upperY - deckY muss <= Beam.maxLength (10) sein, sonst laesst sich
-- die obere Reihe ueberhaupt nicht mit Balken erreichen.
local LEVELS = {
	{ id = "Level1", budget = 200, gap = 40, deckY = 40, upperY = 48, groundY = 20, spacing = 4 },
	{ id = "Level2", budget = 240, gap = 48, deckY = 44, upperY = 52, groundY = 12, spacing = 4 },
	{ id = "Level3", budget = 135, gap = 40, deckY = 40, upperY = 48, groundY = 18, spacing = 4 },
	{ id = "Level4", budget = 260, gap = 64, deckY = 44, upperY = 52, groundY = 20, spacing = 4 },
	{ id = "Level5", budget = 230, gap = 48, deckY = 44, upperY = 52, groundY = 6,  spacing = 4 },
	{ id = "Level6", budget = 320, gap = 80, deckY = 46, upperY = 54, groundY = 22, spacing = 4 },
}

local VEHICLE_MASS = 1000
local VEHICLE_LENGTH = 8

--------------------------------------------------------------------------------
-- Ankerpunkte wie in Levels.luau
--------------------------------------------------------------------------------

local function buildSnaps(L)
	local snaps = {}
	local right = L.gap / 2
	local left = -right
	local overlap = L.spacing
	local deckHalf = right + overlap
	local upperHalf = right + overlap

	local function add(row, x, y, fixed)
		snaps[#snaps + 1] = { id = #snaps + 1, row = row, x = x, y = y, fixed = fixed }
	end

	for x = -deckHalf, deckHalf, L.spacing do
		add("deck", x, L.deckY, math.abs(x) >= right)
	end
	for x = -upperHalf, upperHalf, L.spacing do
		add("upper", x, L.upperY, math.abs(x) >= upperHalf - 0.01)
	end
	for x = left, right, L.spacing do
		add("ground", x, L.groundY, true)
	end
	return snaps, left, right, deckHalf, upperHalf
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

-- Fahrbahn aus Balken mit gegebener Spannweite
local function addDeck(members, snaps, left, right, span)
	local x = left
	while x < right - 0.01 do
		local nextX = math.min(x + span, right)
		local a = findSnap(snaps, "deck", x)
		local b = findSnap(snaps, "deck", nextX)
		if not a or not b then return false end
		if nextX - x > SPECS.Beam.maxLength + 0.01 then return false end
		members[#members + 1] = { kind = "Beam", a = a, b = b }
		x = nextX
	end
	return true
end

-- Stuetzen vom Schluchtgrund unter jeden benutzten Fahrbahnknoten
local function addPillars(members, snaps, L, xs)
	for _, x in xs do
		local top = findSnap(snaps, "deck", x)
		local bottom = findSnap(snaps, "ground", x)
		if not top or not bottom then return false end
		local length = L.deckY - L.groundY
		if length > SPECS.Pillar.maxLength + 0.01 then return false end
		members[#members + 1] = { kind = "Pillar", a = bottom, b = top }
	end
	return true
end

-- Fachwerk zwischen Fahrbahn und oberer Reihe (Vertikalen + Diagonalen)
local function addTruss(members, snaps, L, left, right, span)
	local height = L.upperY - L.deckY
	if height > SPECS.Beam.maxLength + 0.01 then return false end
	local diagonal = math.sqrt(span * span + height * height)
	if diagonal > SPECS.Beam.maxLength + 0.01 then return false end

	-- Obergurt
	local x = left
	while x < right - 0.01 do
		local a = findSnap(snaps, "upper", x)
		local b = findSnap(snaps, "upper", x + span)
		if not a or not b then return false end
		members[#members + 1] = { kind = "Beam", a = a, b = b }
		x += span
	end

	-- Vertikalen
	x = left
	while x <= right + 0.01 do
		local a = findSnap(snaps, "deck", x)
		local b = findSnap(snaps, "upper", x)
		if a and b then
			members[#members + 1] = { kind = "Beam", a = a, b = b }
		end
		x += span
	end

	-- Diagonalen, abwechselnd
	x = left
	local flip = false
	while x < right - 0.01 do
		local a, b
		if flip then
			a = findSnap(snaps, "deck", x)
			b = findSnap(snaps, "upper", x + span)
		else
			a = findSnap(snaps, "upper", x)
			b = findSnap(snaps, "deck", x + span)
		end
		if a and b then
			members[#members + 1] = { kind = "Beam", a = a, b = b }
		end
		flip = not flip
		x += span
	end
	return true
end

-- Haengebruecke: Obergurt aus Balken, Seile nach unten zur Fahrbahn
local function addSuspension(members, snaps, L, left, right, span)
	local x = left - span
	while x < right + span - 0.01 do
		local a = findSnap(snaps, "upper", x)
		local b = findSnap(snaps, "upper", x + span)
		if a and b then
			members[#members + 1] = { kind = "Beam", a = a, b = b }
		end
		x += span
	end

	local drop = L.upperY - L.deckY
	if drop > SPECS.Cable.maxLength + 0.01 or drop < SPECS.Cable.minLength then return false end

	x = left + span
	while x < right - 0.01 do
		local a = findSnap(snaps, "upper", x)
		local b = findSnap(snaps, "deck", x)
		if a and b then
			members[#members + 1] = { kind = "Cable", a = a, b = b }
		end
		x += span
	end
	return true
end

--------------------------------------------------------------------------------
-- Auswerten
--------------------------------------------------------------------------------

local function cost(members)
	local total = 0
	for _, m in members do total += SPECS[m.kind].cost end
	return total
end

-- Fahrzeuglast auf die Knoten verteilen (wie TestRun: 3 Abtastpunkte)
local function vehicleLoads(members, snaps, vehicleX, deckY)
	local loads = {}
	local share = VEHICLE_MASS / 3
	for i = 1, 3 do
		local t = (i - 1) / 2
		local sx = vehicleX - VEHICLE_LENGTH / 2 + t * VEHICLE_LENGTH
		-- Fahrbahnbauteil finden, das diese Stelle ueberdeckt
		for _, m in members do
			if SPECS[m.kind].drivable then
				local sa, sb = snaps[m.a], snaps[m.b]
				if math.abs(sa.y - deckY) < 0.01 and math.abs(sb.y - deckY) < 0.01 then
					local lo, hi = math.min(sa.x, sb.x), math.max(sa.x, sb.x)
					if sx >= lo - 0.01 and sx <= hi + 0.01 and hi > lo then
						local frac = (sx - sa.x) / (sb.x - sa.x)
						frac = math.max(0, math.min(1, frac))
						loads[m.a] = (loads[m.a] or 0) + share * (1 - frac)
						loads[m.b] = (loads[m.b] or 0) + share * frac
						break
					end
				end
			end
		end
	end
	return loads
end

local function evaluate(members, snaps, vehicleX, deckY)
	-- Knoten sammeln
	local used, order = {}, {}
	for _, m in members do used[m.a] = true; used[m.b] = true end
	local nodes, map = {}, {}
	for id = 1, #snaps do
		if used[id] then
			local s = snaps[id]
			nodes[#nodes + 1] = { x = s.x, y = s.y, fixed = s.fixed }
			map[id] = #nodes
			order[#nodes] = id
		end
	end

	local sm = {}
	for _, m in members do
		sm[#sm + 1] = { a = map[m.a], b = map[m.b], tensionOnly = not SPECS[m.kind].rigid }
	end

	local loads, mag = {}, {}
	local function addLoad(i, down)
		loads[i] = loads[i] or { x = 0, y = 0 }
		loads[i].y -= down
		mag[i] = (mag[i] or 0) + math.abs(down)
	end

	for _, m in members do
		local sa, sb = snaps[m.a], snaps[m.b]
		local len = math.sqrt((sb.x - sa.x) ^ 2 + (sb.y - sa.y) ^ 2)
		local w = len * SPECS[m.kind].massPerStud
		addLoad(map[m.a], w / 2)
		addLoad(map[m.b], w / 2)
	end

	if vehicleX then
		for id, n in vehicleLoads(members, snaps, vehicleX, deckY) do
			if map[id] then addLoad(map[id], n) end
		end
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
		local tol = math.max(1.0, (mag[i] or 0) * 0.05)
		if r > tol then unstable = true end
	end

	return worst, worstKind, unstable, res.solved
end

-- Fahrzeug ueber die ganze Bruecke schicken
local function driveThrough(members, snaps, L, left, right)
	local worst, worstKind, anyUnstable = 0, nil, false
	local x = left
	while x <= right do
		local u, kind, unstable, solved = evaluate(members, snaps, x, L.deckY)
		if not solved then return 999, "RECHNUNG FEHLGESCHLAGEN", true end
		if u > worst then worst, worstKind = u, kind end
		if unstable then anyUnstable = true end
		x += 1
	end
	return worst, worstKind, anyUnstable
end

--------------------------------------------------------------------------------
-- Durchlauf
--------------------------------------------------------------------------------

print(string.rep("=", 78))
print("BRIDGELAB - LOESBARKEITSPRUEFUNG")
print(string.rep("=", 78))

for _, L in LEVELS do
	local snaps, left, right = buildSnaps(L)
	print(string.format("\n%s   Budget %d   Luecke %d   Fahrbahn y=%d  Boden y=%d  oben y=%d",
		L.id, L.budget, L.gap, L.deckY, L.groundY, L.upperY))
	print(string.format("   Stuetzenlaenge Boden->Fahrbahn: %d Studs (max %d)  Hoehe Fahrbahn->oben: %d",
		L.deckY - L.groundY, SPECS.Pillar.maxLength, L.upperY - L.deckY))

	local candidates = {}

	for _, span in { 4, 8 } do
		-- Stuetzen vom Boden
		if not L.noPillar and (L.deckY - L.groundY) <= SPECS.Pillar.maxLength then
			local m = {}
			if addDeck(m, snaps, left, right, span) then
				local xs = {}
				for x = left + span, right - span, span do xs[#xs + 1] = x end
				if addPillars(m, snaps, L, xs) then
					candidates[#candidates + 1] =
						{ name = string.format("Stuetzen (%der Fahrbahn)", span), members = m }
				end
			end
		end

		-- Fachwerk Fahrbahn <-> obere Reihe
		do
			local m = {}
			if addDeck(m, snaps, left, right, span) and addTruss(m, snaps, L, left, right, span) then
				candidates[#candidates + 1] =
					{ name = string.format("Fachwerk (%der Felder)", span), members = m }
			end
		end

		-- Haengebruecke
		do
			local m = {}
			if addDeck(m, snaps, left, right, span) and addSuspension(m, snaps, L, left, right, span) then
				candidates[#candidates + 1] =
					{ name = string.format("Haengebruecke (%der Felder)", span), members = m }
			end
		end
	end

	if #candidates == 0 then
		print("   !! keine Standardform ueberhaupt baubar")
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
			if not cheapest or price < cheapest.price then
				cheapest = { price = price, name = c.name }
			end
		elseif holds then
			verdict = "haelt, zu teuer"
			if not cheapest or (cheapest.overBudget and price < cheapest.price) then
				cheapest = { price = price, name = c.name, overBudget = true }
			end
		elseif fits then
			verdict = if unstable then "bezahlbar, instabil" else "bezahlbar, bricht"
		else
			verdict = "zu teuer, haelt nicht"
		end

		print(string.format("   %-30s Kosten %3d/%3d  max %5.0f%%  %s%s",
			c.name, price, L.budget, worst * 100, verdict, kind and (" [" .. kind .. "]") or ""))
	end

	if cheapest and not cheapest.overBudget then
		local headroom = math.floor((L.budget - cheapest.price) / L.budget * 100)
		print(string.format("   => LOESBAR ueber '%s' fuer %d (%d%% Budget uebrig)",
			cheapest.name, cheapest.price, headroom))
	elseif cheapest then
		-- Eine haltende Form gibt es, sie passt nur nicht ins Budget.
		local suggestion = math.ceil(cheapest.price * 1.5 / 10) * 10
		print(string.format("   => NICHT LOESBAR. Billigste haltende Form '%s' kostet %d -> Budget %d empfohlen",
			cheapest.name, cheapest.price, suggestion))
	else
		print("   => NICHT LOESBAR. Keine geprueffte Form haelt ueberhaupt.")
	end
end

print("\n" .. string.rep("=", 78))
