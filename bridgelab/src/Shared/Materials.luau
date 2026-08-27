--[[
	Materials
	---------
	Die sieben Baustoffe. Ersetzt die frueheren "PartTypes" aus der Config.

	DER WICHTIGE UNTERSCHIED ZU FRUEHER: KOSTEN JE STUD
	Frueher kostete ein Bauteil einen Festpreis, egal wie lang es war. Beim
	freien Bauen waere das unsinnig - jeder wuerde einfach moeglichst lange
	Teile setzen, weil Laenge nichts kostet. Jetzt kostet jedes Bauteil
	costPerStud * Laenge. Das Budget steuert damit wirklich, wie viel
	Material verbaut werden darf.

	BEDEUTUNG DER FELDER
	  maxTension      groesste Zugkraft in N, darueber reisst es
	  maxCompression  groesste Druckkraft in N (0 = kann gar keinen Druck)
	  costPerStud     Kosten je Stud Laenge
	  massPerStud     Eigengewicht je Stud
	  minLength       kuerzeste baubare Laenge
	  maxLength       laengste baubare Laenge
	  rigid           true  -> starr, traegt Zug UND Druck
	                  false -> nur Zug (Seil, Kabel)
	  drivable        true  -> Fahrzeuge fahren darauf
	  hydraulic       true  -> faehrt in seiner Phase aus und wieder ein

	WARUM HOLZ STAERKER IST ALS STRASSE
	Holz stand frueher bei 400 N und damit UNTER der Strasse (500 N). Das war
	verkehrt herum gedacht: beim Fachwerk ist die Fahrbahn gleichzeitig der
	Untergurt, und der Obergurt darueber traegt genauso viel. Ist der
	Tragbaustoff schwaecher als die Fahrbahn, reisst immer zuerst der Obergurt
	- und Holz war damit fuer das, wofuer es eigentlich da ist, unbrauchbar.

	Mit 550 N ist Holz jetzt der guenstige Grundbaustoff fuer Fachwerke, und
	die Strasse bleibt das schwache Glied, das man mit einem zweiten Bauteil
	daneben verstaerken muss. Der Preis steigt dafuer von 4 auf 5 je Stud.

	WARUM STAHL SO STARK IST
	Ein Fachwerk ueber die Spannweite L mit der Bauhoehe h bekommt in seinen
	Gurten ungefaehr die Kraft W*L/(4*h). Bei einem 1000-N-Fahrzeug, 50 Studs
	Spannweite und 12 Studs Bauhoehe sind das rund 1040 N. Mit den frueheren
	500 N waere jedes Fachwerk sofort gerissen - deshalb war "Stuetzen bis zum
	Boden" bisher die einzige Bauform, die funktionierte. Mit 1200 N sind
	Fachwerke, Boegen und Haengebruecken erstmals wirklich baubar.
]]

local Materials = {}

Materials.list = {
	--------------------------------------------------------------------------
	-- Befahrbar
	--------------------------------------------------------------------------

	Road = {
		key = "Road",
		maxTension = 500,
		maxCompression = 500,
		costPerStud = 8,
		massPerStud = 2,
		minLength = 2,
		maxLength = 10,
		rigid = true,
		drivable = true,
		hydraulic = false,

		color = Color3.fromRGB(74, 78, 86),
		accentColor = Color3.fromRGB(168, 174, 186),
		material = Enum.Material.Asphalt,
		accentMaterial = Enum.Material.Metal,
		thickness = 0.9,
		width = 8,
		uiColor = Color3.fromRGB(126, 134, 148),
	},

	ReinforcedRoad = {
		key = "ReinforcedRoad",
		maxTension = 1000,
		maxCompression = 1000,
		costPerStud = 14,
		massPerStud = 3,
		minLength = 2,
		maxLength = 10,
		rigid = true,
		drivable = true,
		hydraulic = false,

		color = Color3.fromRGB(66, 70, 78),
		accentColor = Color3.fromRGB(214, 168, 74),
		material = Enum.Material.Asphalt,
		accentMaterial = Enum.Material.Metal,
		thickness = 1.2,
		width = 8,
		uiColor = Color3.fromRGB(214, 168, 74),
	},

	--------------------------------------------------------------------------
	-- Tragwerk, starr
	--------------------------------------------------------------------------

	Wood = {
		key = "Wood",
		maxTension = 550,
		maxCompression = 550,
		costPerStud = 5,
		massPerStud = 1.5,
		minLength = 2,
		maxLength = 12,
		rigid = true,
		drivable = false,
		hydraulic = false,

		color = Color3.fromRGB(152, 106, 62),
		accentColor = Color3.fromRGB(96, 92, 88),
		material = Enum.Material.WoodPlanks,
		accentMaterial = Enum.Material.Metal,
		thickness = 0.7,
		width = 0.8,
		uiColor = Color3.fromRGB(178, 128, 74),
	},

	Steel = {
		key = "Steel",
		maxTension = 1200,
		maxCompression = 1200,
		costPerStud = 10,
		massPerStud = 2.5,
		minLength = 2,
		maxLength = 16,
		rigid = true,
		drivable = false,
		hydraulic = false,

		color = Color3.fromRGB(158, 166, 178),
		accentColor = Color3.fromRGB(96, 104, 116),
		material = Enum.Material.Metal,
		accentMaterial = Enum.Material.Metal,
		thickness = 0.9,
		width = 0.9,
		uiColor = Color3.fromRGB(168, 178, 194),
	},

	--------------------------------------------------------------------------
	-- Tragwerk, nur Zug
	--------------------------------------------------------------------------

	Rope = {
		key = "Rope",
		maxTension = 300,
		maxCompression = 0,
		costPerStud = 2,
		massPerStud = 0.4,
		minLength = 3,
		maxLength = 40,
		rigid = false,
		drivable = false,
		hydraulic = false,

		color = Color3.fromRGB(126, 108, 78),
		accentColor = Color3.fromRGB(92, 88, 82),
		material = Enum.Material.Fabric,
		accentMaterial = Enum.Material.Metal,
		thickness = 0.3,
		width = 0.3,
		uiColor = Color3.fromRGB(186, 158, 112),
	},

	Cable = {
		key = "Cable",
		maxTension = 800,
		maxCompression = 0,
		costPerStud = 5,
		massPerStud = 0.8,
		minLength = 3,
		maxLength = 40,
		rigid = false,
		drivable = false,
		hydraulic = false,

		color = Color3.fromRGB(132, 140, 150),
		accentColor = Color3.fromRGB(78, 84, 92),
		material = Enum.Material.Metal,
		accentMaterial = Enum.Material.Metal,
		thickness = 0.45,
		width = 0.45,
		uiColor = Color3.fromRGB(150, 160, 174),
	},

	--------------------------------------------------------------------------
	-- Beweglich
	--------------------------------------------------------------------------

	Hydraulic = {
		key = "Hydraulic",
		maxTension = 900,
		maxCompression = 900,
		costPerStud = 25,
		massPerStud = 3,
		minLength = 3,
		maxLength = 14,
		rigid = true,
		drivable = false,
		hydraulic = true,

		color = Color3.fromRGB(198, 130, 44),
		accentColor = Color3.fromRGB(196, 202, 212),
		material = Enum.Material.Metal,
		accentMaterial = Enum.Material.Metal,
		thickness = 1.1,
		width = 1.1,
		uiColor = Color3.fromRGB(214, 148, 56),
	},
}

-- Reihenfolge in der Materialleiste, von einfach nach fortgeschritten.
Materials.order = {
	"Road",
	"ReinforcedRoad",
	"Wood",
	"Steel",
	"Rope",
	"Cable",
	"Hydraulic",
}

--------------------------------------------------------------------------------
-- Zugriff
--------------------------------------------------------------------------------

--[[
	Name und Beschreibung stehen nicht hier, sondern in I18n.luau - einmal
	auf Deutsch und einmal auf Englisch. Hier entstehen nur die Schluessel.

	Der Server braucht die Sprache des Spielers damit gar nicht zu kennen: er
	schickt "material.Steel.name", und uebersetzt wird erst beim Spieler.
]]
function Materials.nameKey(key: string): string
	return "material." .. key .. ".name"
end

function Materials.infoKey(key: string): string
	return "material." .. key .. ".info"
end

function Materials.get(key: string)
	return Materials.list[key]
end

function Materials.exists(key: string): boolean
	return Materials.list[key] ~= nil
end

-- Kosten eines Bauteils dieser Laenge. Immer aufgerundet, damit im Budget
-- keine krummen Bruchteile stehen.
function Materials.cost(key: string, length: number): number
	local spec = Materials.list[key]
	if not spec then
		return math.huge
	end
	return math.ceil(spec.costPerStud * length)
end

-- Grenzwert je nach Belastungsrichtung. Positiv = Zug, negativ = Druck.
function Materials.limitFor(key: string, force: number): number
	local spec = Materials.list[key]
	if not spec then
		return 1
	end
	if force >= 0 then
		return spec.maxTension
	end
	-- Seile und Kabel haben Grenzwert 0 fuer Druck. Damit die Division nicht
	-- durch null geht, nehmen wir eine winzige Zahl - jede Druckkraft ist
	-- dann sofort ueber dem Limit, und genau so soll es sein.
	return math.max(spec.maxCompression, 1e-6)
end

return Materials
