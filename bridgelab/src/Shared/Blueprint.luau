--[[
	Blueprint
	---------
	Erzeugt zu einem Level die BAUVORLAGE: eine blasse Zeichnung eines
	gewoehnlichen Fachwerks, die im Level eingeblendet werden kann.

	WOZU DAS DA IST
	Wer noch nie eine Bruecke gebaut hat, sieht am Anfang eine Schlucht, zwei
	goldene Punkte und eine leere Werkzeugleiste - und hat keine Vorstellung,
	wie das Ergebnis ueberhaupt aussehen soll. Die Vorlage zeigt die Form:
	unten die Fahrbahn, oben ein Gurt, dazwischen Pfosten und Diagonalen.

	WAS SIE AUSDRUECKLICH NICHT IST
	Sie ist KEINE Loesung. Sie zeigt die uebliche Form in der ueblichen
	Groesse, ohne Verstaerkungen und ohne Ruecksicht aufs Budget. Wer sie
	genau nachbaut, hat eine Bruecke, die in den leichten Levels traegt und in
	den schweren noch verstaerkt werden muss - genau das soll sie auch:
	einen Anfang zeigen, nicht das Denken abnehmen.

	Gebaut wird sie NICHT automatisch. Der Spieler zieht jedes Bauteil selbst;
	die Vorlage liegt nur blass darunter.

	WARUM AUF DEM SERVER GERECHNET
	Der Server kennt Gelaende, Anker und Baustoffe ohnehin. Rechnete der
	Client selbst, muessten dieselben Regeln ein zweites Mal geschrieben
	werden - und die zweite Fassung laeuft irgendwann auseinander.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Terrain = require(Shared.Terrain)
local Materials = require(Shared.Materials)
local Config = require(Shared.Config)

local Blueprint = {}

--------------------------------------------------------------------------------
-- Hilfen
--------------------------------------------------------------------------------

local function snap(value: number): number
	return Config.snapToGrid(value)
end

--[[
	Die beiden Anker, zwischen denen die Fahrbahn liegt.

	Massgeblich ist die Hoehe, auf der das Fahrzeug losfaehrt und ankommt -
	dort muss die Fahrbahn anfangen und enden. Der hoechste oder der innerste
	Anker waere falsch: auf Levels mit Tuermen sind die hoechsten die
	Turmspitzen, und in der grossen Schlucht ist der innerste die Felsnadel
	tief unten in der Mitte.
]]
local function deckAnchors(level)
	local first = level.vehicles[1]
	if not first then
		return nil, nil
	end

	local left, right = nil, nil
	local leftGap, rightGap = math.huge, math.huge

	for _, anchor in level.anchors do
		if anchor.x < 0 then
			local gap = math.abs(anchor.y - first.startY)
			if gap < leftGap then
				left, leftGap = anchor, gap
			end
		elseif anchor.x > 0 then
			local gap = math.abs(anchor.y - first.finishY)
			if gap < rightGap then
				right, rightGap = anchor, gap
			end
		end
	end

	return left, right
end

-- Der staerkste erlaubte starre Baustoff, der keine Fahrbahn ist.
local function webMaterial(level): string?
	for _, key in { "Steel", "Wood" } do
		if level.allowsMaterial(key) then
			return key
		end
	end
	return nil
end

local function deckMaterial(level): string?
	for _, key in { "Road", "ReinforcedRoad" } do
		if level.allowsMaterial(key) then
			return key
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Die Vorlage bauen
--------------------------------------------------------------------------------

--[[
	Rueckgabe: Liste von { ax, ay, bx, by, material }
	Ist fuer dieses Level keine sinnvolle Vorlage moeglich (etwa beim
	Sprunglevel, wo es gar keine durchgehende Fahrbahn gibt), kommt nil.
]]
function Blueprint.forLevel(level)
	--[[
		Beim Sprunglevel gibt es keine Fahrbahn von Ufer zu Ufer - eine
		Fachwerkvorlage waere dort schlicht falsch und wuerde in die Irre
		fuehren. Lieber gar keine Vorlage als eine, die nicht stimmt.
	]]
	if level.requiresJump then
		return nil
	end

	local a, b = deckAnchors(level)
	if not a or not b then
		return nil
	end

	local deckKey = deckMaterial(level)
	local webKey = webMaterial(level)
	if not deckKey or not webKey then
		return nil
	end

	local deckSpec = Materials.get(deckKey)
	local webSpec = Materials.get(webKey)

	local span = b.x - a.x
	if span < 4 then
		return nil
	end

	----------------------------------------------------------------------------
	-- Feldbreite und Bauhoehe waehlen
	----------------------------------------------------------------------------

	--[[
		Die Feldbreite richtet sich nach der laengsten baubaren Fahrbahn: mehr
		Felder als noetig kosten nur Material, weniger sind gar nicht baubar.
	]]
	local segments = math.max(2, math.ceil(span / math.min(deckSpec.maxLength, 8)))
	local panel = span / segments

	--[[
		Die Bauhoehe ist so gross wie moeglich - je hoeher das Fachwerk, desto
		weniger Kraft steckt in seinen Gurten. Begrenzt wird sie durch die
		DIAGONALE: sie ist das laengste Bauteil im ganzen Fachwerk.

		    Diagonale = Wurzel(Feldbreite^2 + Bauhoehe^2) <= erlaubte Laenge

		Aufgeloest nach der Bauhoehe und mit etwas Luft nach unten, damit das
		Runden aufs Raster sie nicht doch noch ueber die Grenze schiebt.
	]]
	local longest = webSpec.maxLength * 0.94
	local maxDepth = math.sqrt(math.max(longest * longest - panel * panel, 1))
	local depth = snap(math.clamp(maxDepth, 4, 14))

	local out = {}

	local function add(ax: number, ay: number, bx: number, by: number, material: string)
		-- Was durch den Felsen liefe, kann auch niemand nachbauen.
		if Terrain.segmentBlocked(level.terrain, ax, ay, bx, by) then
			return
		end

		--[[
			SICHERHEITSNETZ GEGEN EINE UNBAUBARE VORLAGE

			Die Bauhoehe wird oben aus der erlaubten Diagonallaenge
			ausgerechnet. Rundet das Raster ungluecklich, kann ein Bauteil
			trotzdem ein Stueck zu lang werden - und eine Vorlage, die sich
			nicht nachbauen laesst, ist schlimmer als gar keine: der Spieler
			zieht, bekommt "zu lang" und haelt sich fuer zu dumm.

			Solche Stuecke werden weggelassen und einmal gemeldet, damit es
			beim Entwickeln auffaellt statt beim Spieler.
		]]
		local spec = Materials.get(material)
		local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
		if spec and (length > spec.maxLength + 0.01 or length < spec.minLength - 0.01) then
			warn(string.format(
				"[BridgeLab] Vorlage fuer %s: %s waere %.1f Studs (erlaubt %d bis %d) - weggelassen",
				level.id, material, length, spec.minLength, spec.maxLength
			))
			return
		end

		table.insert(out, { ax = ax, ay = ay, bx = bx, by = by, material = material })
	end

	----------------------------------------------------------------------------
	-- Fahrbahn, Obergurt, Pfosten, Diagonalen
	----------------------------------------------------------------------------

	local deck, top = {}, {}
	for i = 0, segments do
		local t = i / segments
		local x = snap(a.x + span * t)
		local y = snap(a.y + (b.y - a.y) * t)
		deck[i + 1] = { x, y }
		top[i + 1] = { x, y + depth }
	end

	for i = 1, segments do
		add(deck[i][1], deck[i][2], deck[i + 1][1], deck[i + 1][2], deckKey)
		add(top[i][1], top[i][2], top[i + 1][1], top[i + 1][2], webKey)
	end

	for i = 1, segments + 1 do
		add(deck[i][1], deck[i][2], top[i][1], top[i][2], webKey)
	end

	-- Eine Diagonale je Feld, abwechselnd - so entstehen lauter Dreiecke.
	for i = 1, segments do
		if i % 2 == 1 then
			add(deck[i][1], deck[i][2], top[i + 1][1], top[i + 1][2], webKey)
		else
			add(top[i][1], top[i][2], deck[i + 1][1], deck[i + 1][2], webKey)
		end
	end

	if #out == 0 then
		return nil
	end
	return out
end

return Blueprint
