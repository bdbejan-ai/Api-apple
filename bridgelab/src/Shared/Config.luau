--[[
	Config
	------
	Zentrale Einstellungen fuer BridgeLab. Wer etwas am Spielgefuehl aendern
	will, aendert es hier - nicht in den Skripten.

	Die Baustoffe stehen NICHT mehr hier, sondern in Materials.luau.
	Die Level stehen in Levels.luau, das Gelaende-Rechnen in Terrain.luau.

	EINHEITEN (wichtig zu verstehen)
	Das Kraeftemodell rechnet in einem VEREINFACHTEN System mit g = 1.
	Eine Masse von 1000 Einheiten erzeugt also genau 1000 N Gewichtskraft.
	Dadurch lassen sich Fahrzeuggewicht und Bauteil-Grenzwerte direkt
	vergleichen.

	Die Roblox-Physik-Engine rechnet parallel dazu mit ihrer echten Schwerkraft.
	Sie ist NUR fuers Aussehen zustaendig (Durchbiegen, Einsturz, Herunterfallen).
	Ob ein Bauteil bricht, entscheidet ausschliesslich der eigene Fachwerk-
	Rechner auf dem Server (siehe TrussSolver.luau).
]]

local Config = {}

-- Vereinfachte Erdbeschleunigung fuer das Kraeftemodell (siehe Kommentar oben).
Config.Gravity = 1

--------------------------------------------------------------------------------
-- Arenen: jeder Spieler baut in seiner eigenen Kopie des Levels
--------------------------------------------------------------------------------

--[[
	Weil jeder Spieler sein eigenes Level waehlen darf, bekommt jeder eine
	eigene Arena. Die Arenen liegen SENKRECHT uebereinander gestapelt: die
	Kamera schaut waagerecht von der Seite, eine Arena daneben oder dahinter
	waere im Bild, eine weit oben oder unten nicht.
]]
Config.Arena = {
	spacingY = 600, -- senkrechter Abstand zwischen zwei Arenen in Studs
	maxCount = 16, -- mehr Spieler passen nicht gleichzeitig ins Spiel
}

--------------------------------------------------------------------------------
-- Bauen
--------------------------------------------------------------------------------

Config.Build = {
	--[[
		Rasterweite in Studs. Jeder Knoten sitzt auf einem Rasterpunkt.
		Feiner waere unuebersichtlich, groeber naehme Gestaltungsfreiheit.
	]]
	gridSize = 2,

	--[[
		Kuerzestes Ziehen, das ueberhaupt als Bauversuch zaehlt (in Studs).
		Ohne diese Schwelle entstuende bei jedem versehentlichen Klick ein
		winziges Bauteil oder eine Fehlermeldung.
	]]
	minDragLength = 1.5,

	--[[
		Hoechstzahl an Bauteilen je Spieler. Schuetzt den Server davor, dass
		jemand tausende Teile setzt und die Kraefteberechnung lahmlegt: der
		Fachwerk-Rechner waechst mit der dritten Potenz der Bauteilzahl.
	]]
	maxMembers = 140,

	--[[
		Groesse der Knotenkugeln.

		Es gibt bewusst KEINE sichtbaren Rasterpunkte in der Welt: ein
		Baubereich von 120 mal 90 Studs hat auf dem 2-Studs-Raster ueber 2700
		Punkte. So viele Parts je Spieler wuerden den Server erdruecken, und zu
		sehen waere ein grauer Nebel. Der Client zeigt stattdessen nur den
		einen Punkt an, auf den gerade gerastert wird.
	]]
	jointSize = 1.1,
}

--------------------------------------------------------------------------------
-- Physik / Simulation
--------------------------------------------------------------------------------

Config.Physics = {
	--[[
		Wie oft pro Sekunde der Fachwerk-Rechner waehrend des Tests die
		Kraefte neu bestimmt.

		Im Baumodus gibt es keine feste Rate: dort sind alle Knoten verankert,
		es bewegt sich nichts. Gerechnet wird nur, wenn sich etwas aendert.
	]]
	solveRateTest = 20,

	-- Glaettung der Kraefte, damit einzelne Rechenspitzen kein Bauteil
	-- zerstoeren. 0 = gar keine Aenderung, 1 = ungeglaettet.
	forceSmoothing = 0.35,

	-- Erst nach dieser Zeit duerfen im Test Bauteile brechen. Verhindert
	-- Zerstoerung durch den Ruck beim Loesen der Verankerung.
	breakGracePeriod = 0.6,

	-- 1 N aus dem Kraeftemodell -> so viel Roblox-Kraft wird als Last auf die
	-- Knoten gedrueckt. Rein optischer Regler: groesser = staerkeres
	-- sichtbares Durchbiegen, aber unruhigere Physik.
	loadForceScale = 15,

	-- Mindestmasse eines Knotens in Roblox-Einheiten (Stabilitaet der Engine).
	minNodeMass = 10,

	-- Ein Knoten gilt als nicht abgestuetzt ("instabil"), wenn die nicht
	-- ausgleichbare Restkraft groesser ist als dieser Wert.
	residualAbsolute = 1.0,
	residualRelative = 0.05,
}

--------------------------------------------------------------------------------
-- Hydraulik
--------------------------------------------------------------------------------

Config.Hydraulics = {
	-- Auf so viel Prozent seiner Baulaenge faehrt ein Zylinder aus.
	extendFactor = 1.5,

	-- Wie lange das Aus- und Einfahren dauert.
	travelSeconds = 1.2,

	-- So viele Phasen gibt es. Mehr braucht kein Level.
	phaseCount = 4,
}

--------------------------------------------------------------------------------
-- Belastungstest
--------------------------------------------------------------------------------

Config.Test = {
	--[[
		Die Fahrgeschwindigkeit stellt der Spieler am Tacho ein - vor dem Test
		und mitten in der Fahrt. Langsam heisst: man sieht genau zu, welches
		Bauteil rot wird. Schnell heisst: es geht zackig, das Fahrzeug schlaegt
		aber haerter auf.
	]]
	minSpeed = 1,
	maxSpeed = 14,
	defaultSpeed = 3.5,
	speedStep = 0.2,

	--[[
		Ab wann gilt ein Bauteil als BEFAHRBAR?
		Nur flach liegende Fahrbahnstuecke traegt das Fahrzeug. Steilere
		Bauteile werden fuer das Fahrzeug durchlaessig - sonst wuerde eine
		Strebe das Auto einfach ausbremsen, und man koennte seine Bruecke
		nicht aussteifen, ohne sich den Weg zu verbauen.
		Der Wert ist |Hoehenunterschied| geteilt durch die Laenge:
		0.55 entspricht etwa 33 Grad Steigung.
	]]
	roadwayMaxRise = 0.55,

	-- Kurze Pause vor dem Losfahren, damit man die Ausgangslage sieht.
	countdownSeconds = 2,

	--[[
		ANZEIGEN IM TEST - GEGEN DAS ZAHLENCHAOS

		Frueher bekam jedes Bauteil eine Tafel. Bei vierzig Teilen war der
		Bildschirm zugepflastert und man sah die Bruecke nicht mehr.

		Jetzt bekommen nur die am staerksten belasteten Teile eine Tafel, und
		auch nur, wenn sie ueberhaupt nennenswert belastet sind. Die FARBE am
		Bauteil bleibt immer sichtbar - sie ist die Hauptinformation, die
		Zahlen sind die Feinheit.
	]]
	maxStressLabels = 8,
	minLabelUtilisation = 0.25,
	labelMaxDistance = 160,

	-- Wie oft pro Sekunde die Zahlen aktualisiert werden. Bewusst niedriger
	-- als die Rechenrate: sonst flackern sie unlesbar.
	labelUpdateRate = 6,

	-- Wie weit die Kamera dem Fahrzeug folgt (0 = gar nicht, 1 = starr dran).
	cameraFollow = 0.55,
}

-- Faerbung nach Auslastung (0 = unbelastet, 1 = am Grenzwert).
Config.UtilisationColors = {
	low = Color3.fromRGB(86, 196, 122), -- gruen: viel Reserve
	mid = Color3.fromRGB(238, 206, 74), -- gelb: wird eng
	high = Color3.fromRGB(226, 72, 60), -- rot: kurz vor dem Bruch
}

--------------------------------------------------------------------------------
-- Schwierigkeitsgrade (nur Anzeige im Level-Menue)
--------------------------------------------------------------------------------

Config.Difficulty = {
	[1] = { label = "Sehr leicht", color = Color3.fromRGB(90, 200, 120) },
	[2] = { label = "Leicht", color = Color3.fromRGB(150, 205, 90) },
	[3] = { label = "Mittel", color = Color3.fromRGB(238, 200, 80) },
	[4] = { label = "Schwer", color = Color3.fromRGB(240, 145, 60) },
	[5] = { label = "Sehr schwer", color = Color3.fromRGB(228, 80, 70) },
}

--------------------------------------------------------------------------------
-- Kamera (Seitenansicht)
--------------------------------------------------------------------------------

Config.Camera = {
	defaultDistance = 120,

	--[[
		Heranzoomen darf man beliebig weit; das Herauszoomen begrenzt die
		Kamera je Level auf genau die Entfernung, bei der das Level das Bild
		ausfuellt - weiter waere nur noch leere Umgebung zu sehen.
	]]
	minDistance = 12,
	maxDistance = 320,
	zoomOutMargin = 1.06,

	zoomStepMouse = 12,
	zoomStepGamepad = 90,

	fieldOfView = 55,
	panMargin = 30,
}

--------------------------------------------------------------------------------
-- Tipps und Robux
--------------------------------------------------------------------------------

--[[
	WICHTIG - HIER MUSST DU SELBST ETWAS EINTRAGEN:

	hintProductId ist die Nummer eines "Developer Product", das du einmalig
	im Roblox-Creator-Dashboard anlegen musst (Anleitung in der README).
	Solange hier 0 steht, funktioniert alles ganz normal - es wird nur kein
	Kauf angeboten, sondern eine Hinweismeldung angezeigt.
]]
Config.Monetisation = {
	hintProductId = 0, -- 0 = noch nicht eingerichtet
	hintPrice = 15, -- nur fuer die Anzeige, der echte Preis steht bei Roblox
}

--------------------------------------------------------------------------------
-- Speicherung (DataStore)
--------------------------------------------------------------------------------

Config.Data = {
	profileStoreName = "BridgeLabProfile_v2",
	receiptStoreName = "BridgeLabReceipts_v1",
	autosaveSeconds = 120,
}

--------------------------------------------------------------------------------
-- Namen der RemoteEvents
--------------------------------------------------------------------------------

Config.RemoteFolderName = "BridgeLabRemotes"
Config.RemoteNames = {
	-- Client -> Server (Wuensche)
	"ClientReady", -- Skript ist geladen, bitte Profil schicken
	"SelectLevel", -- Level starten
	"LeaveLevel", -- zurueck ins Level-Menue
	"PlaceMember", -- Bauteil setzen
	"RemoveMember", -- Bauteil entfernen
	"StartTest", -- Belastungstest starten
	"SetTestSpeed", -- Tacho: Fahrgeschwindigkeit aendern
	"SetPhase", -- Hydraulik: Phase weiterschalten
	"ResetLevel", -- Konstruktion zuruecksetzen
	"RequestHint", -- naechsten Tipp anfordern
	"TutorialFinished", -- Anleitung wurde durchgespielt

	-- Server -> Client (Tatsachen)
	"StateChanged", -- Budget, Phase, Stabilitaet, Testfortschritt
	"ProfileChanged", -- Fortschritt, Tipp-Guthaben, Anleitung gesehen
	"HintResult", -- Antwort auf RequestHint
	"Notice", -- kurze Rueckmeldung ("Budget reicht nicht")
}

--------------------------------------------------------------------------------
-- Hilfsfunktionen
--------------------------------------------------------------------------------

-- Farbe zu einer Auslastung zwischen 0 und 1.
function Config.utilisationColor(utilisation: number): Color3
	local u = math.clamp(utilisation, 0, 1)
	local c = Config.UtilisationColors
	if u < 0.5 then
		return c.low:Lerp(c.mid, u / 0.5)
	end
	return c.mid:Lerp(c.high, (u - 0.5) / 0.5)
end

function Config.difficultyInfo(level: number)
	return Config.Difficulty[math.clamp(level, 1, 5)]
end

-- Eine Weltkoordinate auf den naechsten Rasterpunkt runden.
function Config.snapToGrid(value: number): number
	local g = Config.Build.gridSize
	return math.round(value / g) * g
end

return Config
