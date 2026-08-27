--[[
	Terrain
	-------
	Das Gelaende eines Levels ist ein Linienzug: eine Liste von Stuetzstellen
	{ x, y }, zwischen denen geradlinig verbunden wird.

	        y
	        |    ____________                    ____________
	        |   /            |                  |
	        |  /             |                  |
	        | /              |__________________|
	        +-------------------------------------------- x
	              Plateau        Schlucht          Plateau

	Zwei aufeinanderfolgende Punkte mit demselben x bilden eine SENKRECHTE
	KANTE - so entstehen Kliffs. Deshalb ist das Gelaende keine gewoehnliche
	Funktion y(x): an einer Kante gibt es zwei Hoehen. heightAt() liefert dort
	immer die OBERE, denn das ist die Oberflaeche, auf der etwas stehen kann.

	Wozu das gebraucht wird:
	  * Die Welt bauen (LevelBuilder)
	  * Pruefen, ob ein Bauteil durch den Berg laufen wuerde (Structure)
	  * Fahrzeuge auf den Boden setzen (TestRun)
]]

local Terrain = {}

--------------------------------------------------------------------------------
-- Hoehe an einer Stelle
--------------------------------------------------------------------------------

--[[
	Gibt die Gelaendeoberflaeche bei x zurueck.
	Ausserhalb des Profils wird die aeusserste Hoehe waagerecht fortgesetzt.
]]
function Terrain.heightAt(profile: { { x: number, y: number } }, x: number): number
	local count = #profile
	if count == 0 then
		return 0
	end
	if count == 1 then
		return profile[1].y
	end

	-- Ausserhalb: flach weiterfuehren.
	if x <= profile[1].x then
		return profile[1].y
	end
	if x >= profile[count].x then
		return profile[count].y
	end

	local best = nil

	for i = 1, count - 1 do
		local a = profile[i]
		local b = profile[i + 1]

		if math.abs(b.x - a.x) < 1e-6 then
			-- Senkrechte Kante: zaehlt nur genau an dieser Stelle.
			if math.abs(x - a.x) < 1e-6 then
				local higher = math.max(a.y, b.y)
				if not best or higher > best then
					best = higher
				end
			end
		else
			local lo, hi = a, b
			if lo.x > hi.x then
				lo, hi = b, a
			end
			if x >= lo.x - 1e-6 and x <= hi.x + 1e-6 then
				local t = (x - lo.x) / (hi.x - lo.x)
				local y = lo.y + (hi.y - lo.y) * t
				if not best or y > best then
					best = y
				end
			end
		end
	end

	return best or profile[1].y
end

--------------------------------------------------------------------------------
-- Steckt ein Punkt im Berg?
--------------------------------------------------------------------------------

function Terrain.isInside(profile, x: number, y: number, tolerance: number?): boolean
	return y < Terrain.heightAt(profile, x) - (tolerance or 0.05)
end

--[[
	Wuerde ein Bauteil von A nach B durch das Gelaende laufen?

	Geprueft wird an mehreren Stellen entlang der Strecke. Die Endpunkte selbst
	werden bewusst mit etwas Nachsicht behandelt: Ankerpunkte liegen genau auf
	der Gelaendekante, und ein Rundungsfehler dort soll nicht dazu fuehren,
	dass gar nichts mehr gebaut werden kann.
]]
function Terrain.segmentBlocked(profile, ax: number, ay: number, bx: number, by: number): boolean
	local steps = math.clamp(math.floor(math.abs(bx - ax) / 1.5) + 4, 6, 48)

	for i = 1, steps - 1 do
		local t = i / steps
		local x = ax + (bx - ax) * t
		local y = ay + (by - ay) * t
		if Terrain.isInside(profile, x, y, 0.35) then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Ausmasse
--------------------------------------------------------------------------------

function Terrain.bounds(profile)
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge

	for _, point in profile do
		minX = math.min(minX, point.x)
		maxX = math.max(maxX, point.x)
		minY = math.min(minY, point.y)
		maxY = math.max(maxY, point.y)
	end

	return { minX = minX, maxX = maxX, minY = minY, maxY = maxY }
end

--------------------------------------------------------------------------------
-- Flaechen fuer den Weltaufbau
--------------------------------------------------------------------------------

--[[
	Zerlegt das Profil in waagerechte Abschnitte, aus denen sich das Gelaende
	als Quader bauen laesst. Jeder Abschnitt bekommt Anfang, Ende und die
	beiden Hoehen - daraus macht der LevelBuilder entweder einen Block (flach)
	oder eine Treppe aus schmalen Blocken (Schraege).
]]
function Terrain.spans(profile)
	local out = {}

	for i = 1, #profile - 1 do
		local a = profile[i]
		local b = profile[i + 1]
		if math.abs(b.x - a.x) > 1e-6 then
			table.insert(out, {
				x1 = math.min(a.x, b.x),
				x2 = math.max(a.x, b.x),
				y1 = if a.x <= b.x then a.y else b.y,
				y2 = if a.x <= b.x then b.y else a.y,
			})
		end
	end

	return out
end

return Terrain
