--[[
	TrussSolver
	-----------
	Ein kleiner, vereinfachter Fachwerk-Rechner ("Knotenpunktverfahren").

	IDEE IN EINEM SATZ
	An jedem beweglichen Knoten muessen sich alle Kraefte aufheben.
	Aus dieser Bedingung laesst sich ausrechnen, wie stark jedes Bauteil
	gezogen oder gedrueckt wird.

	DAS MODELL UND SEINE GRENZEN (bewusste Vereinfachung, kein FEM)
	* Alles wird zweidimensional gerechnet (X waagerecht, Y senkrecht).
	  Die Bruecke liegt ohnehin in einer Ebene.
	* Jedes Bauteil ist ein Stab mit GELENKEN an beiden Enden. Ein Stab kann
	  darum nur laengs gezogen oder gedrueckt werden - er kann sich nicht
	  verbiegen und keine Querkraft aufnehmen.
	  Folge fuer das Spiel: eine schnurgerade Fahrbahn ohne Stuetzen oder
	  Dreiecke traegt sich nicht selbst. Es braucht Abstuetzung.
	* Seile koennen nur ziehen. Kommt im Ergebnis Druck heraus, wird das Seil
	  als "schlaff" aus der Rechnung genommen und neu gerechnet.

	VORZEICHEN
	  positive Kraft = Zug   (das Bauteil wird auseinandergezogen)
	  negative Kraft = Druck (das Bauteil wird zusammengedrueckt)

	WIE GERECHNET WIRD
	Fuer jeden freien Knoten i gilt in X- und in Y-Richtung:
	    Summe( F_stab * Richtung vom Knoten weg ) + aeussere Last = 0
	Das ergibt ein lineares Gleichungssystem  A * f = b.
	Es hat meist nicht genau so viele Gleichungen wie Unbekannte, deshalb
	loesen wir es als Ausgleichsrechnung (kleinste Fehlerquadrate) ueber die
	sogenannten Normalgleichungen:
	    (A^T * A + lambda * I) * f = A^T * b
	Das kleine lambda haelt die Rechnung auch bei wacklige Geometrie stabil.

	Was uebrig bleibt, also  A * f - b , heisst "Restkraft" (Residuum).
	Ist sie an einem Knoten deutlich groesser als null, dann laesst sich die
	Last dort ueberhaupt nicht abtragen: die Konstruktion ist an dieser Stelle
	nicht ausgesteift. Genau dieses Signal nutzt das Spiel fuer die Warnung
	"Struktur nicht stabil".
]]

local TrussSolver = {}

--[[
	Lambda fuer die Regularisierung (siehe Kommentar oben).

	WARUM DIESE ZAHL SO KLEIN IST - ein teuer bezahlter Wert
	Vorher stand hier 1e-4. Damit meldete der Rechner bei langen, flachen
	Fachwerken "nicht stabil", obwohl jeder Knoten ordentlich ausgesteift war.

	Der Grund: lambda unterdrueckt nicht nur echte Wackelstellen, sondern auch
	WEICHE Verformungen. Ein 70 Studs langes und nur 10 Studs hohes Fachwerk
	biegt sich als Ganzes leicht durch - eine solche weiche Richtung hat einen
	kleinen Eigenwert. Ist lambda in derselben Groessenordnung, schluckt die
	Regularisierung einen Teil der Last, und was sie schluckt, taucht als
	Restkraft wieder auf. Aus einer weichen, aber voellig tragfaehigen Bruecke
	wurde so eine angeblich instabile.

	Eine ECHTE Wackelstelle hat dagegen den Eigenwert null. Dort greift jedes
	lambda, auch ein winziges - die Restkraft bleibt in voller Hoehe stehen und
	wird zuverlaessig erkannt. Kleiner ist hier also in beide Richtungen besser:
	echte Fehler werden weiter gefunden, eingebildete verschwinden.

	Ganz weglassen darf man lambda trotzdem nicht: bei doppelt gesetzten
	Bauteilen auf denselben zwei Knoten ist das Gleichungssystem mehrdeutig,
	und lambda entscheidet diese Mehrdeutigkeit sinnvoll - es teilt die Kraft
	gleichmaessig auf beide auf.
]]
local REGULARISATION = 1e-8

--------------------------------------------------------------------------------
-- Gauss-Elimination mit Spaltenpivotisierung
--------------------------------------------------------------------------------

-- Loest M * x = rhs. M und rhs werden dabei veraendert.
-- Gibt nil zurueck, wenn das System nicht loesbar ist.
local function gaussSolve(M: { { number } }, rhs: { number }, n: number): { number }?
	for col = 1, n do
		-- Groesstes Element in der Spalte suchen und nach oben tauschen.
		local pivotRow = col
		local pivotValue = math.abs(M[col][col])
		for row = col + 1, n do
			local value = math.abs(M[row][col])
			if value > pivotValue then
				pivotRow = row
				pivotValue = value
			end
		end

		if pivotValue < 1e-12 then
			return nil
		end

		if pivotRow ~= col then
			M[col], M[pivotRow] = M[pivotRow], M[col]
			rhs[col], rhs[pivotRow] = rhs[pivotRow], rhs[col]
		end

		-- Alle Zeilen darunter ausraeumen.
		local pivot = M[col][col]
		for row = col + 1, n do
			local factor = M[row][col] / pivot
			if factor ~= 0 then
				local target = M[row]
				local source = M[col]
				for c = col, n do
					target[c] -= factor * source[c]
				end
				rhs[row] -= factor * rhs[col]
			end
		end
	end

	-- Ruecksubstitution von unten nach oben.
	local x = table.create(n, 0)
	for row = n, 1, -1 do
		local sum = rhs[row]
		local line = M[row]
		for c = row + 1, n do
			sum -= line[c] * x[c]
		end
		x[row] = sum / line[row]
	end
	return x
end

--------------------------------------------------------------------------------
-- Hauptfunktion
--------------------------------------------------------------------------------

export type SolverNode = {
	x: number,
	y: number,
	fixed: boolean,
}

export type SolverMember = {
	a: number, -- Index in nodes
	b: number, -- Index in nodes
	tensionOnly: boolean, -- true bei Seilen
}

export type SolverResult = {
	forces: { number }, -- je Stab: positiv = Zug, negativ = Druck
	slack: { boolean }, -- je Stab: true = Seil haengt durch, traegt nichts
	residuals: { number }, -- je Knoten: Betrag der nicht ausgleichbaren Restkraft
	solved: boolean, -- false = Rechnung fehlgeschlagen
}

--[[
	nodes   Liste der Knoten
	members Liste der Staebe
	loads   aeussere Lasten je Knotenindex: { [i] = {x = ..., y = ...} }
	        (y negativ = nach unten)
]]
function TrussSolver.solve(
	nodes: { SolverNode },
	members: { SolverMember },
	loads: { [number]: { x: number, y: number } }
): SolverResult
	local memberCount = #members
	local nodeCount = #nodes

	local result: SolverResult = {
		forces = table.create(memberCount, 0),
		slack = table.create(memberCount, false),
		residuals = table.create(nodeCount, 0),
		solved = true,
	}

	if memberCount == 0 or nodeCount == 0 then
		return result
	end

	-- Zeilennummern vergeben: jeder freie Knoten bekommt zwei Zeilen (X und Y).
	local rowOfNode: { [number]: number } = {}
	local rowCount = 0
	for i, node in nodes do
		if not node.fixed then
			rowOfNode[i] = rowCount + 1
			rowCount += 2
		end
	end

	-- Ohne freie Knoten gibt es nichts zu rechnen: alles haengt direkt am Boden.
	if rowCount == 0 then
		return result
	end

	-- Seile, die durchhaengen, werden in spaeteren Durchlaeufen abgeschaltet.
	local active = table.create(memberCount, true)

	local forces = result.forces
	local residuals = result.residuals

	-- Bis zu fuenf Durchlaeufe: nach jedem Durchlauf werden Seile mit Druck
	-- abgeschaltet und es wird erneut gerechnet.
	for _ = 1, 5 do
		-- ---- Matrix A aufbauen -------------------------------------------------
		local A = table.create(rowCount)
		for row = 1, rowCount do
			A[row] = table.create(memberCount, 0)
		end

		for m, member in members do
			if not active[m] then
				continue
			end
			local a = nodes[member.a]
			local b = nodes[member.b]
			local dx = b.x - a.x
			local dy = b.y - a.y
			local length = math.sqrt(dx * dx + dy * dy)
			if length < 1e-4 then
				continue
			end
			-- Einheitsvektor vom Knoten a zum Knoten b.
			local ux = dx / length
			local uy = dy / length

			-- Zug zieht jeden Knoten zum jeweils anderen Ende hin.
			local rowA = rowOfNode[member.a]
			if rowA then
				A[rowA][m] += ux
				A[rowA + 1][m] += uy
			end
			local rowB = rowOfNode[member.b]
			if rowB then
				A[rowB][m] -= ux
				A[rowB + 1][m] -= uy
			end
		end

		-- ---- rechte Seite b ----------------------------------------------------
		local b = table.create(rowCount, 0)
		for i in nodes do
			local row = rowOfNode[i]
			if row then
				local load = loads[i]
				if load then
					b[row] = -load.x
					b[row + 1] = -load.y
				end
			end
		end

		-- ---- Normalgleichungen aufstellen: M = A^T*A + lambda*I, y = A^T*b -----
		local M = table.create(memberCount)
		for i = 1, memberCount do
			M[i] = table.create(memberCount, 0)
		end
		local y = table.create(memberCount, 0)

		for row = 1, rowCount do
			local line = A[row]
			local rhsValue = b[row]
			for i = 1, memberCount do
				local ai = line[i]
				if ai ~= 0 then
					y[i] += ai * rhsValue
					local mi = M[i]
					for j = i, memberCount do
						local aj = line[j]
						if aj ~= 0 then
							mi[j] += ai * aj
						end
					end
				end
			end
		end

		-- M ist symmetrisch: untere Haelfte aus der oberen spiegeln.
		local maxDiagonal = 0
		for i = 1, memberCount do
			if M[i][i] > maxDiagonal then
				maxDiagonal = M[i][i]
			end
		end
		local lambda = REGULARISATION * math.max(maxDiagonal, 1)
		for i = 1, memberCount do
			M[i][i] += lambda
			for j = 1, i - 1 do
				M[i][j] = M[j][i]
			end
		end

		-- ---- loesen ------------------------------------------------------------
		local solution = gaussSolve(M, y, memberCount)
		if not solution then
			result.solved = false
			return result
		end

		for m = 1, memberCount do
			forces[m] = if active[m] then solution[m] else 0
			if forces[m] ~= forces[m] then -- NaN abfangen
				result.solved = false
				return result
			end
		end

		-- ---- Restkraft je Knoten bestimmen ------------------------------------
		for i = 1, nodeCount do
			residuals[i] = 0
		end
		for i in nodes do
			local row = rowOfNode[i]
			if row then
				local sumX, sumY = 0, 0
				for m = 1, memberCount do
					local f = forces[m]
					if f ~= 0 then
						sumX += A[row][m] * f
						sumY += A[row + 1][m] * f
					end
				end
				local rx = sumX - b[row]
				local ry = sumY - b[row + 1]
				residuals[i] = math.sqrt(rx * rx + ry * ry)
			end
		end

		-- ---- Seile pruefen: ein Seil kann keinen Druck aufnehmen --------------
		local changed = false
		for m, member in members do
			if member.tensionOnly and active[m] and forces[m] < -0.5 then
				active[m] = false
				forces[m] = 0
				result.slack[m] = true
				changed = true
			end
		end

		if not changed then
			break
		end
	end

	return result
end

return TrussSolver
