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

	----------------------------------------------------------------------------
	-- Bauhoehe so waehlen, dass WIRKLICH jedes Teil hineinpasst
	----------------------------------------------------------------------------

	--[[
		HIER LAG EIN SCHWERER FEHLER

		Frueher wurde die Bauhoehe aus der DURCHSCHNITTLICHEN Feldbreite
		ausgerechnet. Die Knoten werden aber aufs 2-Studs-Raster gerundet, und
		dabei wird ein Feld breiter als der Durchschnitt: bei 52 Studs auf 7
		Felder sind es im Mittel 7,4 Studs, nach dem Runden aber abwechselnd 6
		und 8.

		Die Diagonale ueber dem breitesten Feld wurde damit 16,1 Studs lang -
		einen Zehntel zu viel fuer Stahl. Sie fiel weg, und mit ihr vier
		weitere. Uebrig blieb ein Fachwerk mit Luecken, das gar nicht stehen
		KANN: es hatte weniger Bauteile als Gleichungen.

		Wer diese Vorlage sorgfaeltig nachbaute, bekam eine Bruecke, die
		zusammenfiel - und konnte nicht wissen, warum. Genau das soll eine
		Vorlage nie tun.

		Deshalb werden die Knoten jetzt ZUERST gerundet, dann die breiteste
		Luecke gesucht, und erst daraus die Bauhoehe bestimmt.
	]]
	local deck, top = {}, {}
	for i = 0, segments do
		local t = i / segments
		deck[i + 1] = {
			snap(a.x + span * t),
			snap(a.y + (b.y - a.y) * t),
		}
	end

	--[[
		DIE BAUHOEHE WIRD DURCHPROBIERT, NICHT AUSGERECHNET

		Bei waagerechter Fahrbahn ist die Diagonale Wurzel(Feld^2 + Hoehe^2).
		Bei SCHRAEGER Fahrbahn stimmt das nicht mehr: dort laeuft die Diagonale
		von einem Fahrbahnknoten zum Obergurtknoten des NAECHSTEN Feldes, und
		dessen Hoehenunterschied ist Feldsteigung PLUS Bauhoehe.

		Im Level "Steile Kante" wurde die Diagonale dadurch 17,9 Studs lang
		statt der gerechneten 16 - und fiel weg. Eine Formel, die nur den
		einen Fall trifft, ist hier also schlechter als schlichtes Ausprobieren.

		Deshalb wird von der groessten Bauhoehe abwaerts jede Stufe geprueft,
		und genommen wird die erste, bei der WIRKLICH jedes Bauteil hineinpasst.
		Das sind hoechstens sechs Versuche und laeuft einmal beim Levelstart.
	]]
	local grid = Config.Build.gridSize
	local depth = nil

	local function everythingFits(candidate: number): boolean
		for i = 1, segments do
			local dx = deck[i + 1][1] - deck[i][1]
			local dy = deck[i + 1][2] - deck[i][2]

			-- Fahrbahn und Obergurt laufen parallel, sind also gleich lang.
			local chord = math.sqrt(dx * dx + dy * dy)
			if chord > deckSpec.maxLength + 0.01 or chord > webSpec.maxLength + 0.01 then
				return false
			end

			-- Beide Richtungen der Diagonale koennen vorkommen.
			local up = math.sqrt(dx * dx + (dy + candidate) ^ 2)
			local down = math.sqrt(dx * dx + (dy - candidate) ^ 2)
			if math.max(up, down) > webSpec.maxLength + 0.01 then
				return false
			end
		end

		-- Die senkrechten Pfosten sind genau so lang wie die Bauhoehe.
		return candidate <= webSpec.maxLength + 0.01 and candidate >= webSpec.minLength - 0.01
	end

	for candidate = 14, 4, -grid do
		if everythingFits(candidate) then
			depth = candidate
			break
		end
	end

	-- Passt keine einzige Bauhoehe, gibt es hier keine sinnvolle Vorlage.
	if not depth then
		return nil
	end

	for i = 1, segments + 1 do
		top[i] = { deck[i][1], deck[i][2] + depth }
	end

	local out = {}
	local dropped = false

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
		--[[
			Ein weggelassenes Teil macht die ganze Vorlage wertlos: ein
			Fachwerk mit Luecke steht nicht. Die Bauhoehe ist oben so gewaehlt,
			dass das nicht mehr vorkommen KANN - passiert es doch, ist das ein
			Fehler im Programm und keine Kleinigkeit.
		]]
		local spec = Materials.get(material)
		local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
		if spec and (length > spec.maxLength + 0.01 or length < spec.minLength - 0.01) then
			warn(string.format(
				"[BridgeLab] FEHLER in der Vorlage fuer %s: %s waere %.1f Studs "
					.. "(erlaubt %d bis %d). Die Vorlage ist damit unvollstaendig.",
				level.id, material, length, spec.minLength, spec.maxLength
			))
			dropped = true
			return
		end

		table.insert(out, { ax = ax, ay = ay, bx = bx, by = by, material = material })
	end

	----------------------------------------------------------------------------
	-- Fahrbahn, Obergurt, Pfosten, Diagonalen
	----------------------------------------------------------------------------

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

	--[[
		Lieber gar keine Vorlage als eine unvollstaendige. Eine Vorlage mit
		Luecken faellt beim Nachbauen zusammen, und der Spieler sucht den
		Fehler bei sich.
	]]
	if #out == 0 or dropped then
		return nil
	end
	return out
end

return Blueprint
