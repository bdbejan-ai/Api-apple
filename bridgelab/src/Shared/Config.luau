--[[
	Config
	------
	Zentrale Einstellungen fuer BridgeLab. Wer etwas am Spielgefuehl aendern
	will, aendert es hier - nicht in den Skripten.

	EINHEITEN (wichtig zu verstehen)
	Das Kraeftemodell rechnet in einem VEREINFACHTEN System mit g = 1.
	Eine Masse von 1000 Einheiten erzeugt also genau 1000 N Gewichtskraft.
	Dadurch passen die Bauteil-Grenzwerte (500 N / 300 N / 800 N) und die
	Fahrzeugmasse (1000) direkt zueinander: ein einzelnes Bauteil kann das
	Fahrzeug nie allein tragen, es braucht immer mehrere.

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
	ANNAHME: Weil jeder Spieler sein eigenes Level waehlen darf, bekommt jeder
	eine eigene Arena. Die Arenen liegen SENKRECHT uebereinander gestapelt.
	Warum senkrecht und nicht nebeneinander? Die Kamera schaut waagerecht von
	der Seite - eine Arena daneben oder dahinter waere im Bild, eine Arena
	weit oben oder unten nicht.
]]
Config.Arena = {
	spacingY = 500, -- senkrechter Abstand zwischen zwei Arenen in Studs
	maxCount = 16, -- mehr Spieler als das passen nicht gleichzeitig ins Spiel
}

--------------------------------------------------------------------------------
-- Bauteile
--------------------------------------------------------------------------------

--[[
	Bedeutung der Felder:
	  cost           Kosten in Budget-Einheiten (unabhaengig von der Laenge)
	  maxTension     maximale Zugkraft in N, darueber bricht das Bauteil
	  maxCompression maximale Druckkraft in N (0 = kann keinen Druck aufnehmen)
	  massPerStud    Masse je Stud Laenge -> Eigengewicht des Bauteils
	  minLength      kuerzeste erlaubte Spannweite in Studs
	  maxLength      laengste erlaubte Spannweite in Studs
	  rigid          true  -> starre Verbindung (RodConstraint)
	                 false -> nur Zug (RopeConstraint)
	  verticalOnly   true  -> darf nur senkrecht gebaut werden
	  drivable       true  -> das Testfahrzeug kann darauf fahren (Kollision an)

	Die "visual"-Felder steuern nur das Aussehen und haben keinen Einfluss
	auf die Physik oder die Kraefteberechnung.
]]
Config.PartTypes = {
	Beam = {
		key = "Beam",
		displayName = "Balken",
		shortName = "Balken",
		description = "Starr, traegt Zug und Druck. Nur hierauf kann das Fahrzeug fahren.",
		icon = "▬",
		cost = 10,
		maxTension = 500,
		maxCompression = 500,
		massPerStud = 2,
		minLength = 3,
		maxLength = 10,
		rigid = true,
		verticalOnly = false,
		drivable = true,

		-- Aussehen
		color = Color3.fromRGB(176, 182, 194), -- Stahl
		material = Enum.Material.Metal,
		accentColor = Color3.fromRGB(58, 60, 66), -- dunkle Fahrbahndecke
		accentMaterial = Enum.Material.Asphalt,
		thickness = 0.9, -- Hoehe des Traegers
		width = 8, -- Breite quer zur Fahrtrichtung (Fahrbahnbreite)
		uiColor = Color3.fromRGB(150, 165, 190),
	},

	Cable = {
		key = "Cable",
		displayName = "Seil",
		shortName = "Seil",
		description = "Nimmt nur Zug auf, keinen Druck. Billig, aber schwach.",
		icon = "╱",
		cost = 5,
		maxTension = 300,
		maxCompression = 0,
		massPerStud = 0.5,
		minLength = 3,
		-- Reichweite: muss gross genug sein, um von der oberen Reihe bis zur
		-- Fahrbahn und in tiefe Schluchten zu reichen.
		maxLength = 40,
		rigid = false,
		verticalOnly = false,
		drivable = false,

		color = Color3.fromRGB(72, 68, 62),
		material = Enum.Material.Fabric,
		accentColor = Color3.fromRGB(126, 118, 104), -- Endklemmen
		accentMaterial = Enum.Material.Metal,
		thickness = 0.35,
		width = 0.35,
		uiColor = Color3.fromRGB(190, 170, 120),
	},

	Pillar = {
		key = "Pillar",
		displayName = "Stuetze",
		shortName = "Stuetze",
		description = "Nur senkrecht. Traegt sehr viel, verbindet Boden und Bruecke.",
		icon = "│",
		cost = 15,
		maxTension = 800,
		maxCompression = 800,
		massPerStud = 3,
		minLength = 3,
		--[[
			WICHTIG FUER DIE LOESBARKEIT: Stuetzen vom Schluchtgrund sind der
			einzige Weg, senkrechte Last wirklich abzutragen. Ist diese Zahl
			kleiner als die tiefste Schlucht, wird das Level unloesbar.
			Der tiefste Graben im Spiel misst 38 Studs (Level 5).
		]]
		maxLength = 40,
		rigid = true,
		verticalOnly = true,
		drivable = false,

		color = Color3.fromRGB(168, 160, 148),
		material = Enum.Material.Concrete,
		accentColor = Color3.fromRGB(120, 112, 100), -- Sockel und Kopf
		accentMaterial = Enum.Material.Concrete,
		thickness = 1.5,
		width = 1.5,
		uiColor = Color3.fromRGB(170, 160, 145),
	},
}

-- Reihenfolge der Knoepfe im Baumenue.
Config.PartOrder = { "Beam", "Cable", "Pillar" }

--------------------------------------------------------------------------------
-- Physik / Simulation
--------------------------------------------------------------------------------

Config.Physics = {
	--[[
		Wie oft pro Sekunde der Fachwerk-Rechner waehrend des Tests die
		Kraefte neu bestimmt.

		Im Baumodus gibt es keine feste Rate: dort sind alle Knoten verankert,
		es bewegt sich also nichts. Gerechnet wird nur, wenn ein Bauteil
		dazukommt oder verschwindet.
	]]
	solveRateTest = 20,

	-- Glaettung der Kraefte, damit einzelne Rechenspitzen kein Bauteil zerstoeren.
	-- 0 = gar keine Aenderung, 1 = ungeglaettet.
	forceSmoothing = 0.35,

	-- Erst nach dieser Zeit (Sekunden) duerfen im Test Bauteile brechen.
	-- Verhindert Zerstoerung durch den kurzen Ruck beim Loesen der Verankerung.
	breakGracePeriod = 0.6,

	-- Umrechnung: 1 N aus dem Kraeftemodell -> so viel Roblox-Kraft wird als
	-- Fahrzeuglast auf die Knoten gedrueckt. Rein optischer Regler:
	-- groesser = staerkeres sichtbares Durchbiegen, aber unruhigere Physik.
	loadForceScale = 15,

	-- Mindestmasse eines Knotens in Roblox-Einheiten (Stabilitaet der Engine).
	minNodeMass = 10,

	-- Ein Knoten gilt als nicht abgestuetzt ("instabil"), wenn die nicht
	-- ausgleichbare Restkraft groesser ist als dieser Wert.
	residualAbsolute = 1.0,
	residualRelative = 0.05,

	-- Groesse der Knotenkugeln.
	nodeSize = 1.5,
}

--------------------------------------------------------------------------------
-- Belastungstest
--------------------------------------------------------------------------------

Config.Test = {
	--[[
		Die Fahrgeschwindigkeit stellt der Spieler selbst ein - am Tacho
		unten in der Oberflaeche, auch noch waehrend der Fahrt.
		Langsam heisst: man sieht genau zu, welches Bauteil wie stark
		belastet wird. Schnell heisst: es geht zackig, aber das Fahrzeug
		schlaegt haerter auf und bringt die Bruecke staerker ins Schwingen.
	]]
	minSpeed = 1,
	maxSpeed = 14,
	defaultSpeed = 3.2,
	speedStep = 0.2,

	--[[
		Ab wann gilt ein Balken als BEFAHRBAR?
		Nur flach liegende Balken sind Fahrbahn. Alles Steilere ist Tragwerk
		und wird fuer das Fahrzeug durchlaessig gemacht - sonst wuerde eine
		senkrechte Strebe das Auto einfach ausbremsen.
		Der Wert ist |Hoehenunterschied| geteilt durch die Laenge:
		0.5 entspricht etwa 30 Grad Steigung.
	]]
	roadwayMaxRise = 0.5,

	-- Kurze Pause vor dem Losfahren, damit man die Ausgangslage sieht.
	countdownSeconds = 2,

	-- Belastungsanzeige ueber jedem Bauteil ein-/ausschalten.
	showStressLabels = true,

	-- Wie oft pro Sekunde die Zahlen an den Bauteilen aktualisiert werden.
	-- Bewusst niedriger als die Rechenrate: sonst flackern die Zahlen.
	labelUpdateRate = 8,

	-- Ab dieser Auslastung wird die Anzeige als Warnung hervorgehoben.
	warnUtilisation = 0.75,

	-- Wie weit die Kamera dem Fahrzeug folgt (0 = gar nicht, 1 = starr dran).
	cameraFollow = 0.55,
}

-- Faerbung der Bauteile nach Auslastung (0 = unbelastet, 1 = am Grenzwert).
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
	-- Abstand der Kamera zur Bruecken-Ebene in Studs.
	defaultDistance = 110,

	--[[
		Heranzoomen darf man so weit man will - bis dicht an ein einzelnes
		Bauteil heran.
		Herauszoomen dagegen nur so weit, bis das Level das Bild ausfuellt.
		Weiter waere sinnlos: man saehe nur noch leere Umgebung. Die obere
		Grenze berechnet die Kamera fuer jedes Level selbst aus dessen
		Ausmassen (siehe CameraController:setArena); die Zahl hier ist nur
		die Notbremse, falls keine Levelmasse vorliegen.
	]]
	minDistance = 12,
	maxDistance = 260,

	-- Wie viel Rand ueber die Levelgrenzen hinaus beim weitesten Zoom.
	zoomOutMargin = 1.06,

	-- Wie schnell das Mausrad bzw. die Trigger zoomen.
	zoomStepMouse = 12,
	zoomStepGamepad = 90, -- pro Sekunde bei voll gedruecktem Trigger

	fieldOfView = 55,

	-- Wie weit man ueber den Rand des Levels hinausschieben darf.
	panMargin = 30,
}

--------------------------------------------------------------------------------
-- Tipps und Robux
--------------------------------------------------------------------------------

--[[
	WICHTIG - HIER MUSST DU SELBST ETWAS EINTRAGEN:

	hintProductId ist die Nummer eines "Developer Product", das du einmalig
	im Roblox-Creator-Dashboard anlegen musst (Anleitung steht in der README).
	Solange hier 0 steht, funktioniert alles ganz normal - es wird nur kein
	Kauf angeboten, sondern eine Hinweismeldung angezeigt. Du kannst das Spiel
	also komplett testen, ohne vorher etwas einzurichten.
]]
Config.Monetisation = {
	hintProductId = 0, -- 0 = noch nicht eingerichtet
	hintPrice = 15, -- nur fuer die Anzeige im Knopf, der echte Preis steht bei Roblox
}

--------------------------------------------------------------------------------
-- Speicherung (DataStore)
--------------------------------------------------------------------------------

Config.Data = {
	profileStoreName = "BridgeLabProfile_v1",
	receiptStoreName = "BridgeLabReceipts_v1",

	-- Wie oft der Fortschritt eines Spielers automatisch gesichert wird.
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

-- Gibt die Farbe zu einer Auslastung zwischen 0 und 1 zurueck.
function Config.utilisationColor(utilisation: number): Color3
	local u = math.clamp(utilisation, 0, 1)
	local c = Config.UtilisationColors
	if u < 0.5 then
		return c.low:Lerp(c.mid, u / 0.5)
	end
	return c.mid:Lerp(c.high, (u - 0.5) / 0.5)
end

-- Beschriftung und Farbe zu einer Schwierigkeitsstufe.
function Config.difficultyInfo(level: number)
	return Config.Difficulty[math.clamp(level, 1, 5)]
end

return Config
