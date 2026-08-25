--[[
	Config
	------
	Zentrale Einstellungen fuer BridgeLab.

	Wichtige Grundannahme zu den Einheiten:
	Das Kraeftemodell rechnet in einem VEREINFACHTEN Einheitensystem mit g = 1.
	Das heisst: eine Masse von 1000 Einheiten erzeugt eine Gewichtskraft von 1000 N.
	Dadurch passen die vorgegebenen Bauteil-Grenzwerte (500 N / 300 N / 800 N)
	und die Fahrzeugmasse (1000) direkt zueinander: das Fahrzeug muss von
	mindestens zwei bis drei Bauteilen gemeinsam getragen werden.

	Die Roblox-Physik-Engine rechnet parallel dazu mit ihrer echten Schwerkraft.
	Sie ist nur fuer das Aussehen zustaendig (Durchbiegen, Einsturz, Herunterfallen).
	Ueber welche Kraefte ein Bauteil bricht, entscheidet ausschliesslich der
	eigene Fachwerk-Rechner (siehe TrussSolver.luau) auf dem Server.
]]

local Config = {}

-- Vereinfachte Erdbeschleunigung fuer das Kraeftemodell (siehe Kommentar oben).
Config.Gravity = 1

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
]]
Config.PartTypes = {
	Beam = {
		key = "Beam",
		displayName = "Balken",
		description = "Starr, traegt Zug und Druck. Bildet die Fahrbahn.",
		cost = 10,
		maxTension = 500,
		maxCompression = 500,
		massPerStud = 2,
		minLength = 3,
		maxLength = 10,
		rigid = true,
		verticalOnly = false,
		drivable = true,
		baseColor = Color3.fromRGB(198, 198, 205),
		material = Enum.Material.Metal,
		thickness = 0.8, -- Hoehe des Bauteils
		width = 8, -- Breite quer zur Fahrtrichtung (Fahrbahnbreite)
	},

	Cable = {
		key = "Cable",
		displayName = "Seil",
		description = "Nimmt nur Zug auf, kein Druck. Billig, aber schwach.",
		cost = 5,
		maxTension = 300,
		maxCompression = 0,
		massPerStud = 0.5,
		minLength = 3,
		maxLength = 26,
		rigid = false,
		verticalOnly = false,
		drivable = false,
		baseColor = Color3.fromRGB(60, 58, 55),
		material = Enum.Material.Fabric,
		thickness = 0.3,
		width = 0.3,
	},

	Pillar = {
		key = "Pillar",
		displayName = "Stuetze",
		description = "Nur senkrecht. Verbindet den Boden mit der Konstruktion.",
		cost = 15,
		maxTension = 800,
		maxCompression = 800,
		massPerStud = 3,
		minLength = 3,
		maxLength = 26,
		rigid = true,
		verticalOnly = true,
		drivable = false,
		baseColor = Color3.fromRGB(126, 116, 104),
		material = Enum.Material.Concrete,
		thickness = 1.4,
		width = 1.4,
	},
}

-- Reihenfolge der Knoepfe im Baumenue.
Config.PartOrder = { "Beam", "Cable", "Pillar" }

--------------------------------------------------------------------------------
-- Physik / Simulation
--------------------------------------------------------------------------------

Config.Physics = {
	-- Wie oft pro Sekunde der Fachwerk-Rechner die Kraefte neu bestimmt.
	solveRateTest = 20,
	solveRateBuild = 4,

	-- Glaettung der Kraefte, damit einzelne Rechenspitzen kein Bauteil zerstoeren.
	-- 0 = gar keine Aenderung, 1 = ungeglaettet.
	forceSmoothing = 0.35,

	-- Erst nach dieser Zeit (Sekunden) duerfen im Test Bauteile brechen.
	-- Verhindert Zerstoerung durch den kurzen Ruck beim Loesen der Verankerung.
	breakGracePeriod = 0.5,

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
	nodeSize = 1.4,
}

-- Faerbung der Bauteile nach Auslastung (0 = unbelastet, 1 = am Grenzwert).
Config.UtilisationColors = {
	low = Color3.fromRGB(90, 200, 120),
	mid = Color3.fromRGB(235, 205, 70),
	high = Color3.fromRGB(225, 70, 60),
}

--------------------------------------------------------------------------------
-- Namen der RemoteEvents
--------------------------------------------------------------------------------

Config.RemoteFolderName = "BridgeLabRemotes"
Config.RemoteNames = {
	"PlaceMember", -- Client -> Server: Bauteil setzen
	"RemoveMember", -- Client -> Server: Bauteil entfernen
	"StartTest", -- Client -> Server: Belastungstest starten
	"ResetLevel", -- Client -> Server: alles zuruecksetzen
	"StateChanged", -- Server -> Clients: Budget, Phase, Stabilitaet
	"Notice", -- Server -> ein Client: kurze Rueckmeldung ("Budget reicht nicht")
}

--------------------------------------------------------------------------------
-- Hilfsfunktion
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

return Config
