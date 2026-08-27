--[[
	Diagnosis
	---------
	Sagt nach einem gescheiterten Test, WORAN es gelegen hat.

	WOZU DAS DA IST
	"Bauteil gebrochen" allein hilft niemandem weiter. Man sieht einen
	Truemmerhaufen und weiss nicht, ob man knapp daneben lag oder voellig
	falsch gebaut hat - und ob man nachbessern oder neu anfangen soll.

	Dieses Modul beantwortet drei Fragen, und zwar aus Zahlen, die der Server
	ohnehin schon hat:

	  WAS ist gebrochen?     Baustoff und Rolle im Fachwerk (Fahrbahn,
	                         Obergurt, Diagonale, Pfosten)
	  WIE KNAPP war es?      "1350 N - erlaubt sind 1200, also 13 Prozent
	                         zu viel". Bei 13 Prozent reicht ein zweites
	                         Bauteil, bei 300 Prozent muss die Form anders
	                         werden. Das ist der wichtigste Unterschied.
	  WAS FAELLT AUF?        Beobachtungen ueber die ganze Bruecke: keine
	                         einzige Diagonale, sehr flach gebaut, Budget
	                         noch halb voll.

	WARUM EIN EIGENES MODUL
	TestRun soll den Test fahren, nicht den Spieler beraten. Und diese
	Regeln wird man oefter anfassen als den Testablauf - beim Zusehen faellt
	einem immer wieder ein neuer Hinweis ein.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Materials = require(Shared.Materials)

local Diagnosis = {}

--------------------------------------------------------------------------------
-- Rolle eines Bauteils im Fachwerk
--------------------------------------------------------------------------------

--[[
	Bestimmt aus der RICHTUNG, welche Aufgabe ein Bauteil hat. Nicht aus dem
	Baustoff - ein Spieler darf jedes Material ueberall einsetzen, und genau
	deshalb sagt der Baustoff nichts ueber die Rolle.

	    fast waagerecht + befahrbar -> Fahrbahn
	    fast waagerecht             -> Gurt
	    fast senkrecht              -> Pfosten
	    dazwischen                  -> Diagonale
]]
function Diagnosis.roleOf(member): string
	local dx = member.bx - member.ax
	local dy = member.by - member.ay
	local length = math.max(math.sqrt(dx * dx + dy * dy), 1e-4)

	local rise = math.abs(dy) / length
	local run = math.abs(dx) / length
	local spec = Materials.get(member.material)

	if rise < 0.3 then
		if spec and spec.drivable then
			return "road"
		end
		return "chord"
	elseif run < 0.3 then
		return "post"
	end
	return "diagonal"
end

-- Zu jeder Rolle der passende Rat und der Name der Rolle.
local ADVICE_FOR_ROLE = {
	road = "advice.roadBroke",
	chord = "advice.chordBroke",
	post = "advice.postBroke",
	diagonal = "advice.diagonalBroke",
}

function Diagnosis.adviceFor(member): string
	return ADVICE_FOR_ROLE[Diagnosis.roleOf(member)] or "advice.chordBroke"
end

--------------------------------------------------------------------------------
-- Der Steckbrief des Bruchs
--------------------------------------------------------------------------------

--[[
	Alles, was der Client zum Anzeigen braucht. Die Zahlen werden hier schon
	gerundet: der Client soll nur noch darstellen, nicht rechnen.

	overload ist die Ueberlastung in Prozent ueber dem Grenzwert - also 13
	bei 1350 N von 1200 erlaubten. Genau diese Zahl entscheidet, ob ein
	zweites Bauteil reicht oder die ganze Form falsch ist.
]]
function Diagnosis.describeBreak(member, reasonKey: string?)
	local spec = Materials.get(member.material)
	local force = math.abs(member.force)
	local limit = Materials.limitFor(member.material, member.force)

	return {
		reason = reasonKey or "failure.overloaded",
		materialKey = Materials.nameKey(member.material),
		roleKey = "role." .. Diagnosis.roleOf(member),
		advice = Diagnosis.adviceFor(member),

		force = math.floor(force + 0.5),
		limit = math.floor(limit + 0.5),
		overload = math.max(math.floor((force / math.max(limit, 1e-6) - 1) * 100 + 0.5), 0),

		-- Wo es passiert ist, in Levelkoordinaten.
		x = (member.ax + member.bx) / 2,
		y = (member.ay + member.by) / 2,

		length = math.floor(member.length * 10 + 0.5) / 10,
		maxLength = if spec then spec.maxLength else 0,
	}
end

--------------------------------------------------------------------------------
-- Beobachtungen ueber die ganze Bruecke
--------------------------------------------------------------------------------

--[[
	Kleine Hinweise, die sich aus dem Bauplan als Ganzem ergeben - nicht aus
	dem einen gebrochenen Teil. Sie treffen oft genau den Anfaengerfehler:

	  keine einzige Diagonale   die haeufigste Ursache ueberhaupt
	  nirgends verdoppelt       die zweithaeufigste
	  sehr flach gebaut         Bauhoehe ist der billigste Hebel
	  Budget kaum genutzt       Verstaerken kostet dann ja nichts

	Hoechstens ZWEI davon werden gezeigt. Fuenf Hinweise auf einmal liest
	niemand, und der wichtigste ginge darin unter.
]]
function Diagnosis.observations(structure, level, failure)
	local members = structure.members
	if #members == 0 then
		return {}
	end

	----------------------------------------------------------------------------
	-- Zaehlen, was da ist
	----------------------------------------------------------------------------

	local diagonals = 0
	local pairs_ = {}
	local doubled = 0
	local deckSum, deckCount = 0, 0
	local highest = -math.huge

	for _, member in members do
		local role = Diagnosis.roleOf(member)
		if role == "diagonal" then
			diagonals += 1
		end
		if role == "road" then
			deckSum += (member.ay + member.by) / 2
			deckCount += 1
		end

		highest = math.max(highest, member.ay, member.by)

		--[[
			Zwei Bauteile auf denselben zwei Knoten - egal in welcher
			Reihenfolge die Enden stehen. Deshalb wird der Schluessel aus den
			beiden Knotennamen SORTIERT gebaut.
		]]
		local a, b = member.keyA, member.keyB
		if a > b then
			a, b = b, a
		end
		local key = a .. "|" .. b
		if pairs_[key] then
			doubled += 1
		end
		pairs_[key] = true
	end

	local out = {}

	----------------------------------------------------------------------------
	-- In der Reihenfolge ihrer Wichtigkeit
	----------------------------------------------------------------------------

	if diagonals == 0 then
		table.insert(out, "tip.noDiagonals")
	end

	if doubled == 0 and failure and failure.overload and failure.overload <= 60 then
		--[[
			Nur bei knapper Ueberlastung vorschlagen. Wer um 300 Prozent
			darueber liegt, dem hilft ein zweites Bauteil nicht - da ist die
			Form falsch, und dieser Hinweis waere eine Sackgasse.
		]]
		table.insert(out, "tip.noDoubling")
	end

	if deckCount > 0 then
		local deckY = deckSum / deckCount
		local depth = highest - deckY
		if depth < 6 then
			table.insert(out, "tip.tooFlat")
		end
	end

	local left = level.budget - structure:usedBudget()
	if left > level.budget * 0.3 then
		table.insert(out, "tip.budgetLeft")
	end

	--[[
		Ein Bauteil an seiner Laengengrenze ist besonders anfaellig: es hat
		die groesste Hebelwirkung und traegt am wenigsten. Das faellt beim
		Bauen nicht auf, weil es ja erlaubt war.
	]]
	--[[
		Nicht jeder Misserfolg hat ein gebrochenes Bauteil: ein abgestuerztes
		Fahrzeug oder ein Zeitlimit liefert einen Steckbrief ohne Laengen.
		Deshalb wird hier auf beide Werte geprueft, nicht nur auf failure.
	]]
	if failure and failure.maxLength and failure.length and failure.maxLength > 0
		and failure.length >= failure.maxLength - 0.6
	then
		table.insert(out, "tip.atMaxLength")
	end

	-- Hoechstens zwei zeigen.
	while #out > 2 do
		table.remove(out)
	end
	return out
end

return Diagnosis
