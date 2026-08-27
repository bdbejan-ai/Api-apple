--[[
	I18n
	----
	Sprachen. Das Spiel spricht Deutsch und Englisch.

	WARUM UEBERHAUPT
	Roblox ist ein weltweites Spiel. Wer aus einem anderen Land kommt, sah
	bisher nur deutsche Texte und konnte nicht einmal die Anleitung lesen -
	das Spiel war fuer ihn schlicht unbenutzbar. Englisch ist die Sprache, mit
	der die allermeisten wenigstens zurechtkommen, deshalb ist sie auch die
	RUECKFALLSPRACHE: fehlt ein Text in der eigenen Sprache, kommt der
	englische, nie ein leeres Feld.

	WIE ES BENUTZT WIRD
	    local I18n = require(Shared.I18n)
	    label.Text = I18n.t("hud.budget", used, total)

	Jeder Text hat einen SCHLUESSEL wie "hud.budget". Im Code steht nur noch
	der Schluessel; die Saetze stehen alle hier in dieser Datei. Wer eine
	dritte Sprache ergaenzen will, braucht nur hier eine Spalte dazuzuschreiben
	und muss keine einzige andere Datei anfassen.

	WIE SERVER UND CLIENT ZUSAMMENARBEITEN
	Der Server kennt die Sprache des Spielers NICHT und soll sie auch nicht
	kennen muessen. Er schickt deshalb keine fertigen Saetze, sondern nur den
	Schluessel und die eingesetzten Werte:

	    { key = "notice.tooLong", args = { "Stahl", 16 } }

	Uebersetzt wird erst beim Spieler. Das hat zwei Vorteile: dieselbe
	Meldung erreicht zwei Spieler in ihren jeweiligen Sprachen, und die
	Sprache laesst sich mitten im Spiel umstellen, ohne dass der Server
	irgendetwas neu schicken muss.

	PLATZHALTER
	Die Texte benutzen string.format, also %s fuer Text und %d fuer ganze
	Zahlen. Die Reihenfolge der Platzhalter muss in allen Sprachen dieselbe
	sein - sonst stehen die Werte an der falschen Stelle.
]]

local I18n = {}

--------------------------------------------------------------------------------
-- Verfuegbare Sprachen
--------------------------------------------------------------------------------

I18n.FALLBACK = "en"

I18n.languages = {
	{ code = "de", name = "Deutsch" },
	{ code = "en", name = "English" },
}

local current = I18n.FALLBACK

--[[
	Sprache setzen. Erlaubt ist ein voller Roblox-Sprachcode wie "de-de" -
	genommen wird davon nur der Teil vor dem Bindestrich.
]]
function I18n.setLanguage(code: string?)
	if type(code) ~= "string" then
		return
	end
	local short = string.lower(string.match(code, "^(%a+)") or "")
	for _, language in I18n.languages do
		if language.code == short then
			current = short
			return
		end
	end
	current = I18n.FALLBACK
end

function I18n.language(): string
	return current
end

--------------------------------------------------------------------------------
-- Nachschlagen
--------------------------------------------------------------------------------

local strings = {}
I18n.strings = strings

--[[
	Text zu einem Schluessel, mit eingesetzten Werten.

	Fehlt der Schluessel ganz, kommt er selbst zurueck. Das ist Absicht: ein
	sichtbares "hud.budget" auf dem Bildschirm faellt sofort auf und laesst
	sich suchen, waehrend ein leeres Feld wie ein Anzeigefehler aussieht und
	unbemerkt bleibt.
]]
function I18n.t(key: string, ...): string
	local entry = strings[key]
	if not entry then
		return key
	end

	local text = entry[current] or entry[I18n.FALLBACK]
	if not text then
		return key
	end

	if select("#", ...) == 0 then
		return text
	end

	--[[
		Ein falscher Platzhalter in einer Uebersetzung wuerde das ganze Spiel
		zum Absturz bringen. Deshalb wird das Einsetzen abgesichert: im
		Fehlerfall gibt es den unformatierten Text statt eines Absturzes.
	]]
	local ok, result = pcall(string.format, text, ...)
	if ok then
		return result
	end
	warn(string.format("[BridgeLab] Platzhalter passen nicht: %s (%s)", key, current))
	return text
end

--[[
	Uebersetzt eine Meldung, die vom Server kam: { key = ..., args = {...} }.
	Kommt ausnahmsweise nur Text, wird der unveraendert durchgereicht.
]]
function I18n.message(payload): string
	if type(payload) == "string" then
		return payload
	end
	if type(payload) ~= "table" or type(payload.key) ~= "string" then
		return ""
	end
	if not payload.args then
		return I18n.t(payload.key)
	end

	--[[
		EINGESETZTE WERTE KOENNEN SELBST SCHLUESSEL SEIN

		"%s ist in diesem Level gesperrt" bekommt einen Baustoffnamen
		eingesetzt - und der ist auch wieder uebersetzbar. Der Server schickt
		deshalb "material.Steel.name" als Wert, nicht "Stahl".

		Hier wird jeder Wert nachgeschlagen: ist er ein bekannter Schluessel,
		wird er uebersetzt, sonst unveraendert eingesetzt. Eine Zahl oder ein
		Spielername ist nie ein Schluessel und geht damit von selbst
		unveraendert durch.
	]]
	local values = {}
	for index, value in payload.args do
		if type(value) == "string" and strings[value] then
			values[index] = I18n.t(value)
		else
			values[index] = value
		end
	end

	return I18n.t(payload.key, table.unpack(values, 1, #payload.args))
end

--------------------------------------------------------------------------------
-- Die Texte
--------------------------------------------------------------------------------

--[[
	Kleiner Helfer, damit die Tabelle darunter lesbar bleibt:
	add("schluessel", "deutsch", "english")
]]
local function add(key: string, de: string, en: string)
	strings[key] = { de = de, en = en }
end

--------------------------------------------------------------------------------
-- Allgemein
--------------------------------------------------------------------------------

add("app.title", "BridgeLab", "BridgeLab")
add("app.subtitle", "Baue eine Bruecke, die haelt.", "Build a bridge that holds.")

add("common.back", "Zurueck", "Back")
add("common.close", "Schliessen", "Close")
add("common.continue", "Weiter", "Continue")
add("common.skip", "Ueberspringen", "Skip")
add("common.studs", "%d Studs", "%d studs")

--------------------------------------------------------------------------------
-- Schwierigkeitsgrade
--------------------------------------------------------------------------------

add("difficulty.1", "Sehr leicht", "Very easy")
add("difficulty.2", "Leicht", "Easy")
add("difficulty.3", "Mittel", "Medium")
add("difficulty.4", "Schwer", "Hard")
add("difficulty.5", "Sehr schwer", "Very hard")

--------------------------------------------------------------------------------
-- Welten
--------------------------------------------------------------------------------

add("world.Grundlagen", "Grundlagen", "Basics")
add("world.Werkstoffe", "Werkstoffe", "Materials")
add("world.Bewegliches", "Bewegliches", "Moving parts")

--------------------------------------------------------------------------------
-- Baustoffe
--------------------------------------------------------------------------------

add("material.Road.name", "Strasse", "Road")
add("material.Road.info", "Befahrbar. Die Fahrbahn muss durchgehend daraus bestehen.",
	"Drivable. The roadway must be continuous.")

add("material.ReinforcedRoad.name", "Verstaerkte Strasse", "Reinforced road")
add("material.ReinforcedRoad.info", "Befahrbar und doppelt so tragfaehig, aber fast doppelt so teuer.",
	"Drivable and twice as strong, but almost twice the price.")

add("material.Wood.name", "Holz", "Wood")
add("material.Wood.info", "Billig und leicht. Der Grundbaustoff fuer Fachwerke.",
	"Cheap and light. The basic material for trusses.")

add("material.Steel.name", "Stahl", "Steel")
add("material.Steel.info", "Sehr tragfaehig und weit spannend. Das Rueckgrat grosser Bruecken.",
	"Very strong and long-spanning. The backbone of big bridges.")

add("material.Rope.name", "Seil", "Rope")
add("material.Rope.info", "Kann nur ziehen, nie druecken. Taugt nur dort, wo Zug herrscht - etwa neben der Fahrbahn.",
	"Can only pull, never push. Only useful where there is tension - for example beside the roadway.")

add("material.Cable.name", "Kabel", "Cable")
add("material.Cable.info", "Stahlseil, zieht fast dreimal so stark wie ein Seil. Neben der Fahrbahn halb so teuer wie Stahl.",
	"Steel cable, pulls almost three times as hard as a rope. Beside the roadway it costs half as much as steel.")

add("material.Hydraulic.name", "Hydraulik", "Hydraulics")
add("material.Hydraulic.info", "Faehrt in seiner Phase aus und hebt dabei alles daran. Teuer.",
	"Extends in its phase and lifts whatever hangs on it. Expensive.")

add("material.perStud", "%d je Stud", "%d per stud")
add("material.limits", "Zug %d · Druck %d", "Tension %d · compression %d")
add("material.limitsTensionOnly", "Zug %d · kein Druck", "Tension %d · no compression")

--------------------------------------------------------------------------------
-- Levelmenue
--------------------------------------------------------------------------------

add("menu.title", "Level waehlen", "Choose a level")
add("menu.levelNumber", "%s · LEVEL %d", "%s · LEVEL %d")
add("menu.budget", "Budget %d", "Budget %d")
add("menu.anchors", "%d Anker", "%d anchors")
add("menu.done", "Geschafft", "Done")
add("menu.locked", "Erst das Level davor schaffen", "Finish the previous level first")
add("menu.progress", "%d von %d Leveln geschafft", "%d of %d levels done")
add("menu.freeHint", "1 Tipp gratis", "1 free hint")
add("menu.paidHints", "Tipps ab Robux", "Hints cost Robux")
add("menu.badge.jump", "Sprung", "Jump")
add("menu.badge.boat", "Schiff", "Ship")
add("menu.badge.boatLong", "Schiff muss durch", "Ship must pass")
add("menu.badge.hydraulics", "Hydraulik", "Hydraulics")
add("menu.badge.vehicles", "%d Fahrzeuge", "%d vehicles")
add("menu.language", "Sprache", "Language")
add("menu.play", "Spielen", "Play")
add("menu.howTo", "Wie baue ich?", "How do I build?")

--------------------------------------------------------------------------------
-- Kopfzeile und Fussleiste im Spiel
--------------------------------------------------------------------------------

add("hud.budget", "Budget %d / %d", "Budget %d / %d")
add("hud.menu", "Menue", "Menu")
add("hud.reset", "Zuruecksetzen", "Reset")
add("hud.clear", "Abreissen", "Clear all")
add("hud.remove", "Abriss", "Remove")
add("hud.hint", "Tipp", "Hint")
add("hud.test", "Test starten", "Start test")
add("hud.testRunning", "Test laeuft ...", "Test running ...")
add("hud.speed", "Tempo", "Speed")
add("hud.speedValue", "%.1f Studs/s", "%.1f studs/s")
add("hud.blueprint", "Vorlage", "Blueprint")

add("hud.phases", "Hydraulik", "Hydraulics")
add("hud.phasesBuild", "Hydraulik - Phase fuer neue Zylinder", "Hydraulics - phase for new cylinders")
add("hud.phasesTest", "Hydraulik - jetzt schalten", "Hydraulics - switch now")
add("hud.phaseOff", "Ein", "In")

--------------------------------------------------------------------------------
-- Testanzeige
--------------------------------------------------------------------------------

add("test.countdown", "Gleich geht es los: %d", "Starting in %d")
add("test.elapsed", "Zeit %.1f s", "Time %.1f s")
add("test.load", "Hoechste Auslastung %d%%", "Peak load %d%%")
add("test.vehicles", "Fahrzeuge %d / %d", "Vehicles %d / %d")
add("test.legendLow", "viel Reserve", "plenty spare")
add("test.legendMid", "wird eng", "getting tight")
add("test.legendHigh", "kurz vor dem Bruch", "about to break")

add("test.slack", "schlaff", "slack")
add("test.slackInfo", "traegt nichts", "carries nothing")
add("test.tension", "Zug %d N", "Tension %d N")
add("test.compression", "Druck %d N", "Compression %d N")

--------------------------------------------------------------------------------
-- Ergebnis
--------------------------------------------------------------------------------

add("result.success", "Geschafft!", "Well done!")
add("result.failure", "Noch nicht", "Not yet")
add("result.retry", "Weiter bauen", "Keep building")
add("result.nextLevel", "Naechstes Level", "Next level")
add("result.toMenu", "Zum Menue", "To the menu")

add("result.allVehicles", "Geschafft! Alle Fahrzeuge sind angekommen.",
	"Well done! Every vehicle made it across.")
add("result.oneVehicle", "Geschafft! Das Fahrzeug hat die andere Seite erreicht.",
	"Well done! The vehicle reached the other side.")
add("result.withBoat", "Geschafft! Fahrzeug und Schiff sind durchgekommen.",
	"Well done! Both the vehicle and the ship got through.")

add("result.broken", "Bauteil gebrochen: %s war ueberlastet.",
	"A part broke: the %s was overloaded.")
add("result.fell", "Fahrzeug %d ist abgestuerzt.", "Vehicle %d fell.")
add("result.tipped", "Fahrzeug %d ist gekippt.", "Vehicle %d tipped over.")
add("result.timeout", "Zeitlimit ueberschritten.", "Out of time.")
add("result.boatBlocked", "Das Schiff kommt nicht durch - die Bruecke steht im Weg.",
	"The ship cannot pass - the bridge is in the way.")

--------------------------------------------------------------------------------
-- Kurze Rueckmeldungen beim Bauen
--------------------------------------------------------------------------------

add("notice.unknownMaterial", "Unbekannter Baustoff.", "Unknown material.")
add("notice.materialLocked", "%s ist in diesem Level gesperrt.", "%s is not available in this level.")
add("notice.tooManyMembers", "Mehr als %d Bauteile gehen nicht.", "You cannot place more than %d parts.")
add("notice.offGrid", "Knoten muessen auf dem Raster liegen.", "Joints must sit on the grid.")
add("notice.samePoint", "Anfang und Ende sind derselbe Punkt.", "Start and end are the same point.")
add("notice.tooShort", "%s ist zu kurz (mindestens %d Studs).", "%s is too short (at least %d studs).")
add("notice.tooLong", "%s ist zu lang (hoechstens %d Studs).", "%s is too long (at most %d studs).")
add("notice.outsideArea", "Ausserhalb des Baubereichs.", "Outside the build area.")
add("notice.throughRock", "Das Bauteil laeuft durch den Felsen.", "That part would run through the rock.")
add("notice.duplicate", "Hier liegt schon %s.", "There is already %s here.")
add("notice.noBudget", "Das Budget reicht nicht (%d noetig, %d uebrig).",
	"Not enough budget (%d needed, %d left).")
add("notice.buildFirst", "Erst bauen, dann testen.", "Build something first, then test.")
add("notice.testRunning", "Der Test laeuft schon.", "The test is already running.")
add("notice.noBuildDuringTest", "Waehrend des Tests laesst sich nicht bauen.",
	"You cannot build while the test is running.")
add("notice.noRemoveDuringTest", "Waehrend des Tests laesst sich nichts entfernen.",
	"You cannot remove anything while the test is running.")
add("notice.phaseOnlyInTest", "Die Hydraulik laesst sich nur waehrend des Tests schalten.",
	"Hydraulics can only be switched during the test.")
add("notice.unknownLevel", "Dieses Level gibt es nicht.", "That level does not exist.")
add("notice.arenaFull", "Gerade sind alle Bauplaetze belegt. Bitte kurz warten.",
	"All build slots are taken right now. Please wait a moment.")
add("notice.slackRope", "Dieses Seil haengt durch - an dieser Stelle muesste es druecken, und das kann ein Seil nicht.",
	"This rope is slack - it would have to push here, and a rope cannot push.")

--------------------------------------------------------------------------------
-- Stabilitaet
--------------------------------------------------------------------------------

add("status.unstable", "Struktur nicht stabil - der rote Punkt zeigt die Stelle.",
	"Structure not stable - the red dot marks the spot.")
add("status.stable", "Struktur steht.", "Structure holds.")

--------------------------------------------------------------------------------
-- Tipps und Robux
--------------------------------------------------------------------------------

add("hint.title", "Tipps", "Hints")
add("hint.none", "Noch kein Tipp freigeschaltet.", "No hint unlocked yet.")
add("hint.free", "Ersten Tipp gratis ansehen", "Show the first hint for free")
add("hint.buy", "Tipp freischalten (%d Robux)", "Unlock a hint (%d Robux)")
add("hint.allShown", "Alle Tipps sind freigeschaltet.", "All hints are unlocked.")
add("hint.notSetUp", "Die Robux-Tipps sind noch nicht eingerichtet.",
	"Robux hints are not set up yet.")
add("hint.solvableWithout", "Jedes Level ist auch ohne Tipps loesbar.",
	"Every level can be solved without hints.")
add("hint.number", "Tipp %d", "Hint %d")


--------------------------------------------------------------------------------
-- Bedienung, je nach Geraet
--------------------------------------------------------------------------------

add("action.select.Desktop", "klicke mit der linken Maustaste", "click the left mouse button")
add("action.select.Touch", "tippe kurz", "tap briefly")
add("action.select.Gamepad", "druecke A", "press A")

add("action.remove.Desktop", "klicke mit der rechten Maustaste auf ein Bauteil",
	"right-click a part")
add("action.remove.Touch", "waehle den Abriss-Knopf und tippe auf ein Bauteil",
	"choose Remove and tap a part")
add("action.remove.Gamepad", "druecke X und waehle ein Bauteil", "press X and pick a part")

add("action.pan.Desktop", "halte die rechte Maustaste gedrueckt und ziehe",
	"hold the right mouse button and drag")
add("action.pan.Touch", "ziehe mit ZWEI Fingern", "drag with TWO fingers")
add("action.pan.Gamepad", "bewege den rechten Stick", "move the right stick")

add("action.zoom.Desktop", "drehe am Mausrad", "scroll the mouse wheel")
add("action.zoom.Touch", "ziehe zwei Finger auseinander oder zusammen", "pinch two fingers")
add("action.zoom.Gamepad", "druecke die Schultertasten LT und RT", "press the LT and RT triggers")

add("action.pointer.Desktop", "der Mauszeiger", "the mouse pointer")
add("action.pointer.Touch", "dein Finger", "your finger")
add("action.pointer.Gamepad", "der Zeiger (linker Stick)", "the pointer (left stick)")

add("action.dragStart.Desktop", "halte die linke Maustaste gedrueckt", "hold the left mouse button")
add("action.dragStart.Touch", "lege einen Finger auf", "put one finger down")
add("action.dragStart.Gamepad", "halte A gedrueckt", "hold A")

add("action.dragEnd.Desktop", "lass die Maustaste los", "release the mouse button")
add("action.dragEnd.Touch", "hebe den Finger", "lift your finger")
add("action.dragEnd.Gamepad", "lass A los", "release A")

--------------------------------------------------------------------------------
-- Anleitung
--------------------------------------------------------------------------------

add("tut.welcome.title", "Willkommen bei BridgeLab", "Welcome to BridgeLab")
add("tut.welcome.text",
	"Du baust eine Bruecke ueber eine Luecke. Danach faehrt ein Fahrzeug darueber. Haelt die Bruecke, hast du gewonnen.\n\nDiese Anleitung fuehrt dich einmal durch alles. Sie dauert etwa eine Minute.",
	"You build a bridge across a gap. Then a vehicle drives over it. If the bridge holds, you win.\n\nThis tutorial walks you through everything once. It takes about a minute.")

add("tut.camera.title", "Die Ansicht bewegen", "Moving the view")
add("tut.camera.text",
	"Du siehst die Bruecke von der Seite, wie ein Bild.\n\nZum Verschieben: %s.\nZum Vergroessern: %s.\n\nProbier es einmal aus.",
	"You see the bridge from the side, like a picture.\n\nTo move it: %s.\nTo zoom: %s.\n\nGive it a try.")

add("tut.material.title", "Einen Baustoff auswaehlen", "Choosing a material")
add("tut.material.text",
	"Links stehen deine Baustoffe.\n\nDie STRASSE ist der wichtigste: nur auf ihr kann das Fahrzeug fahren. Alles andere ist Tragwerk, das die Strasse haelt.\n\nJedes Bauteil kostet nach LAENGE - ein langer Balken kostet mehr als ein kurzer.\n\nWaehle jetzt die Strasse aus.",
	"Your materials are on the left.\n\nROAD is the important one: the vehicle can only drive on road. Everything else is structure that holds the road up.\n\nEvery part is priced by LENGTH - a long beam costs more than a short one.\n\nSelect road now.")

add("tut.drag.title", "Bauen heisst ziehen", "Building means dragging")
add("tut.drag.text",
	"Du baust frei auf einem Raster - nicht zwischen festen Punkten.\n\nGOLDENE Kugeln sind Anker: nur dort gibt deine Bruecke Last an den Boden ab. Alles dazwischen muss sie selbst tragen.\n\n%s an einem Anker und ziehe zur Seite. Die Vorschau folgt mit.",
	"You build freely on a grid - not between fixed points.\n\nGOLDEN discs are anchors: only there does your bridge pass load into the ground. Everything between them it must carry itself.\n\n%s on an anchor and drag sideways. The preview follows.")

add("tut.place.title", "Loslassen setzt das Bauteil", "Releasing places the part")
add("tut.place.text",
	"Waehrend du ziehst, siehst du eine Vorschaulinie.\n\nGRUEN heisst: so darf gebaut werden.\nROT heisst: zu lang, zu kurz, durch den Felsen, oder das Budget reicht nicht.\n\nLass los, wenn die Linie gruen ist - dann entsteht das Bauteil.",
	"While you drag, a preview line follows.\n\nGREEN means: this is allowed.\nRED means: too long, too short, through the rock, or not enough budget.\n\nRelease while the line is green and the part appears.")

add("tut.budget.title", "Budget und Farben", "Budget and colours")
add("tut.budget.text",
	"Oben siehst du dein Budget. Jedes Bauteil kostet - ist das Budget leer, geht nichts mehr.\n\nDie Bauteile faerben sich nach ihrer Belastung:\nGRUEN = viel Reserve\nGELB = wird eng\nROT = kurz vor dem Bruch\n\nFalsch gebaut? Mit %s kannst du es wieder entfernen. Das Geld bekommst du zurueck.",
	"Your budget is shown at the top. Every part costs something - when the budget runs out, you cannot build.\n\nParts change colour with their load:\nGREEN = plenty spare\nYELLOW = getting tight\nRED = about to break\n\nBuilt something wrong? %s to remove it. You get the money back.")

add("tut.blueprint.title", "Die Vorlage", "The blueprint")
add("tut.blueprint.text",
	"Wenn du nicht weisst, wie eine Bruecke ueberhaupt aussieht: druecke VORLAGE.\n\nDann erscheint eine blasse Zeichnung eines Fachwerks, genau passend zu diesem Level. Du kannst sie nachbauen oder nur als Anhaltspunkt nehmen - gebaut wird sie nicht von selbst.\n\nProbier es einmal aus.",
	"If you have no idea what a bridge should look like: press BLUEPRINT.\n\nA faint drawing of a truss appears, fitted to this level. You can copy it or just use it as a guide - it does not build itself.\n\nGive it a try.")

add("tut.hint.title", "Wenn du nicht weiterkommst", "When you get stuck")
add("tut.hint.text",
	"In der Fussleiste gibt es den Knopf TIPP.\n\nIn den leichten Levels ist der erste Tipp gratis, jeder weitere kostet Robux.\nIn den schweren Levels kostet schon der erste Tipp Robux.\n\nDu brauchst nie einen Tipp zu kaufen - jedes Level ist auch ohne loesbar.",
	"There is a HINT button in the bottom bar.\n\nIn the easy levels the first hint is free, every further one costs Robux.\nIn the hard levels even the first hint costs Robux.\n\nYou never have to buy a hint - every level can be solved without them.")

add("tut.speed.title", "Das Tempo bestimmst du", "You set the speed")
add("tut.speed.text",
	"In der Fussleiste sitzt der Tacho. Damit stellst du ein, wie schnell das Fahrzeug faehrt - von 1 bis 14 Studs pro Sekunde.\n\nLANGSAM ist zum Lernen besser: du siehst in Ruhe, welches Bauteil rot wird.\nSCHNELL geht zackiger, das Fahrzeug schlaegt aber haerter auf.\n\nDu darfst ihn auch mitten in der Fahrt noch verstellen. Zeit verlierst du durch langsames Fahren nicht - das Zeitlimit passt sich an.",
	"The speed dial sits in the bottom bar. It sets how fast the vehicle drives - from 1 to 14 studs per second.\n\nSLOW is better for learning: you can watch calmly which part turns red.\nFAST is snappier, but the vehicle lands harder.\n\nYou can change it mid-drive too. Driving slowly costs you nothing - the time limit adjusts.")

add("tut.test.title", "Der Belastungstest", "The load test")
add("tut.test.text",
	"Wenn du fertig bist, druecke TEST STARTEN.\n\nUeber den am staerksten belasteten Bauteilen siehst du dann, wie viel Kraft in ihnen steckt - in Prozent und in Newton. Gruen heisst viel Reserve, rot heisst: es reisst gleich.\n\nStarte jetzt einen Test. Es macht nichts, wenn die Bruecke noch nicht haelt.",
	"When you are ready, press START TEST.\n\nThe most heavily loaded parts show how much force they carry - as a percentage and in newtons. Green means plenty spare, red means it is about to snap.\n\nStart a test now. It does not matter if the bridge does not hold yet.")

add("tut.done.title", "Das war alles", "That was everything")
add("tut.done.text",
	"Du kennst jetzt alles Wichtige. Drei Saetze helfen dir durch das ganze Spiel:\n\nDREIECKE sind stabil, Vierecke kippen um. Das ist der wichtigste Satz im ganzen Brueckenbau.\n\nBricht die STRASSE, lege ein zweites Bauteil daneben - genau auf dieselben beiden Punkte. Beide teilen sich dann die Kraft.\n\nIst die Bruecke zu weit gespannt, baue sie HOEHER. Je hoeher das Fachwerk, desto weniger Kraft steckt in seinen Gurten.\n\nViel Erfolg!",
	"You now know everything important. Three sentences will carry you through the whole game:\n\nTRIANGLES are stable, rectangles collapse. That is the single most important rule in bridge building.\n\nIf the ROAD breaks, put a second part right beside it - on exactly the same two joints. The two then share the force.\n\nIf the bridge spans too far, build it TALLER. The taller the truss, the less force sits in its chords.\n\nGood luck!")


--------------------------------------------------------------------------------
-- Level: Namen, Untertitel und Tipps
--------------------------------------------------------------------------------

--[[
	Die Schluessel entstehen aus der Levelnummer: "level.W1L1.name". Levels.luau
	speichert deshalb gar keinen Text mehr, nur noch, WIE VIELE Tipps es gibt.
	So kann ein Levelname auch nicht versehentlich an zwei Stellen unterschiedlich
	stehen.
]]

add("level.W1L1.name", "Der erste Graben", "The first ditch")
add("level.W1L1.subtitle", "Kurze Luecke, viel Budget. Lerne das Zeichnen.",
	"Short gap, plenty of budget. Learn to draw.")
add("level.W1L1.hint1",
	"Eine gerade Fahrbahn traegt sich nicht selbst. Jeder Knoten, der nur zwei Bauteile in derselben Linie hat, kann keine senkrechte Last aufnehmen.",
	"A straight roadway cannot carry itself. Any joint with only two parts in the same line cannot take a vertical load.")
add("level.W1L1.hint2",
	"Ein Dreieck ist die einzige Form, die sich nicht verziehen laesst. Setze ueber die Fahrbahn einen Obergurt aus Holz und verbinde ihn mit Streben nach unten.",
	"A triangle is the only shape that cannot be distorted. Put a wooden top chord above the roadway and connect it downwards with struts.")
add("level.W1L1.hint3",
	"Loesung: Fahrbahn aus drei Strassenstuecken, darueber ein Dreieck aus Holz von Anker zu Anker mit zwei senkrechten Streben nach unten.",
	"Solution: three road pieces, and above them a wooden triangle from anchor to anchor with two vertical struts going down.")

add("level.W1L2.name", "Dreiecke", "Triangles")
add("level.W1L2.subtitle", "Zu weit fuer eine flache Fahrbahn.", "Too far for a flat roadway.")
add("level.W1L2.hint1",
	"Vierzig Studs sind zu weit fuer ein einzelnes Dreieck. Es braucht eine Kette davon - ein Fachwerk.",
	"Forty studs is too far for a single triangle. You need a chain of them - a truss.")
add("level.W1L2.hint2",
	"Bau die Fahrbahn in Feldern von 8 Studs. Ueber jedem Feldknoten eine senkrechte Strebe nach oben, oben ein durchgehender Gurt, dazwischen Diagonalen.",
	"Build the roadway in 8-stud bays. A vertical post above every joint, a continuous chord along the top, diagonals in between.")
add("level.W1L2.hint3",
	"Reisst der Obergurt, lege ein ZWEITES Holz genau daneben - auf dieselben beiden Knoten. Beide teilen sich dann die Kraft.",
	"If the top chord snaps, put a SECOND piece of wood right beside it - on the same two joints. The two then share the force.")

add("level.W1L3.name", "Zwei Vorspruenge", "Two ledges")
add("level.W1L3.subtitle", "Der Grund ist unerreichbar. Nutze die Vorspruenge.",
	"The canyon floor is out of reach. Use the ledges.")
add("level.W1L3.hint1",
	"Zweiundfuenfzig Studs am Stueck sind zu weit fuer Holz. Sieh dir die beiden Felsvorspruenge unter der Fahrbahn an.",
	"Fifty-two studs in one span is too far for wood. Take a look at the two rock ledges below the roadway.")
add("level.W1L3.hint2",
	"Auf jedem Vorsprung sitzt ein Anker. Von dort laesst sich ein Pfeiler nach oben bauen, der die Fahrbahn abstuetzt.",
	"There is an anchor on each ledge. From there you can build a pier up to support the roadway.")
add("level.W1L3.hint3",
	"Ein Pfeiler aus einer einzelnen Stange knickt seitlich weg. Bau ihn als Dreieck: zwei Schenkel, die sich oben zur Fahrbahn hin oeffnen.",
	"A pier made of a single column buckles sideways. Build it as a triangle: two legs spreading out towards the roadway.")

add("level.W1L4.name", "Sparzwang", "Tight budget")
add("level.W1L4.subtitle", "Derselbe Graben wie im ersten Level, halbes Budget.",
	"The same ditch as level one, half the budget.")
add("level.W1L4.hint1",
	"Der Graben ist derselbe wie im ersten Level - nur das Budget ist knapp. Es geht also nicht ums Koennen, sondern ums Sparen.",
	"The ditch is the same as in level one - only the budget is tight. This is not about skill, it is about thrift.")
add("level.W1L4.hint2",
	"Holz kostet 5 je Stud, Strasse 8. Jedes Stueck Strasse, das du weglaesst, spart bares Geld - aber die Fahrbahn muss durchgehend sein.",
	"Wood costs 5 per stud, road costs 8. Every piece of road you leave out saves real money - but the roadway must stay continuous.")
add("level.W1L4.hint3",
	"Ein flacheres Fachwerk spart Material an den Streben, kostet aber mehr Kraft in den Gurten. Such den Punkt dazwischen - sechs Studs Bauhoehe reichen hier.",
	"A shallower truss saves material on the web, but puts more force in the chords. Find the balance - six studs of depth is enough here.")

add("level.W2L5.name", "Weit gespannt", "Wide span")
add("level.W2L5.subtitle", "Zweiundsiebzig Studs am Stueck. Nur Stahl traegt das.",
	"Seventy-two studs in one go. Only steel can carry that.")
add("level.W2L5.hint1",
	"Holz haelt 550 N, Stahl 1200. Bei dieser Spannweite entstehen in den Gurten weit ueber 550 N - Holz reisst dort sofort.",
	"Wood holds 550 N, steel 1200. At this span the chords see far more than 550 N - wood snaps immediately.")
add("level.W2L5.hint2",
	"Die Kraft im Gurt ist ungefaehr Last mal Spannweite geteilt durch das Vierfache der Bauhoehe. Mehr Bauhoehe ist billiger als mehr Material.",
	"Chord force is roughly load times span divided by four times the depth. More depth is cheaper than more material.")
add("level.W2L5.hint3",
	"Loesung: Fahrbahn aus Strasse mit Stahl daneben verstaerkt, Obergurt doppelt, beide Diagonalen je Feld, Bauhoehe etwa zehn Studs.",
	"Solution: road reinforced with steel alongside, a doubled top chord, both diagonals in every bay, about ten studs deep.")

add("level.W2L6.name", "Steile Kante", "Steep edge")
add("level.W2L6.subtitle", "Die andere Seite liegt zwanzig Studs hoeher.",
	"The far side is twenty studs higher.")
add("level.W2L6.hint1",
	"Die Fahrbahn muss ansteigen. Zu steil darf sie nicht werden - ueber etwa 33 Grad gilt ein Bauteil nicht mehr als befahrbar und das Fahrzeug faellt hindurch.",
	"The roadway has to climb. It must not get too steep - beyond about 33 degrees a part no longer counts as drivable and the vehicle falls through.")
add("level.W2L6.hint2",
	"Zwanzig Studs Hoehenunterschied auf 44 Studs Weite sind knapp 25 Grad. Das geht gerade so, wenn die Steigung gleichmaessig ueber die ganze Luecke verteilt wird.",
	"Twenty studs of rise over 44 studs of span is just under 25 degrees. That works, as long as the slope is spread evenly across the whole gap.")
add("level.W2L6.hint3",
	"Das Tragwerk darf ruhig waagerecht bleiben, auch wenn die Fahrbahn steigt. Ein Fachwerk mit waagerechtem Obergurt und schraeger Fahrbahn ist voellig in Ordnung.",
	"The structure may stay level even though the roadway climbs. A truss with a horizontal top chord and a sloping deck is perfectly fine.")

add("level.W2L7.name", "Doppelte Last", "Double load")
add("level.W2L7.subtitle", "Zwei Autos gleichzeitig, aus beiden Richtungen.",
	"Two cars at once, from both directions.")
add("level.W2L7.hint1",
	"Zwei Autos zu je 900 N treffen sich in der Mitte. Dort liegen dann 1800 N auf wenigen Studs Fahrbahn.",
	"Two cars of 900 N each meet in the middle. That puts 1800 N on a few studs of roadway.")
add("level.W2L7.hint2",
	"Die Felsnadel mitten in der Schlucht traegt zwei Anker. Ein Pfeiler von dort halbiert die Spannweite - und viertelt damit fast die Gurtkraft.",
	"The rock spire in the middle of the gorge carries two anchors. A pier from there halves the span - and nearly quarters the chord force.")
add("level.W2L7.hint3",
	"Loesung: ein Fachwerk ueber die ganze Breite, dazu ein Pfeiler von der Felsnadel hinauf zur Fahrbahnmitte. Fahrbahn aus verstaerkter Strasse.",
	"Solution: a truss across the whole width, plus a pier from the spire up to the middle of the deck. Use reinforced road.")

add("level.W2L8.name", "Kreuz und quer", "Crosswise")
add("level.W2L8.subtitle", "Eine Diagonale je Feld reicht hier nicht mehr.",
	"One diagonal per bay is no longer enough.")
add("level.W2L8.hint1",
	"Ein Fachwerk mit nur EINER Diagonale je Feld hat genau einen Weg, auf dem die Auflagerkraft vom Anker nach oben gelangt. Diese eine Diagonale traegt dann alles allein.",
	"A truss with only ONE diagonal per bay has exactly one path for the support force to travel up from the anchor. That single diagonal then carries everything alone.")
add("level.W2L8.hint2",
	"Setze in JEDES Feld beide Diagonalen - ein liegendes Kreuz. Dann teilen sich zwei Bauteile diese Kraft, und die groesste Einzelkraft halbiert sich.",
	"Put both diagonals in EVERY bay - a lying cross. Then two parts share that force, and the largest single force halves.")
add("level.W2L8.hint3",
	"Loesung: Fahrbahn aus Strasse mit Stahl daneben verstaerkt, doppelter Obergurt, beide Diagonalen je Feld, Bauhoehe acht Studs.",
	"Solution: road reinforced with steel alongside, a doubled top chord, both diagonals per bay, eight studs deep.")

add("level.W3L9.name", "Klappbruecke", "Drawbridge")
add("level.W3L9.subtitle", "Ein Schiff muss durch. Die Bruecke muss aufgehen.",
	"A ship must pass. The bridge has to open.")
add("level.W3L9.hint1",
	"Das Schiff faehrt zuerst. Erst wenn es durch ist, darf die Bruecke wieder zu sein.",
	"The ship goes first. Only once it is through may the bridge close again.")
add("level.W3L9.hint2",
	"Ein Hydraulikzylinder faehrt in seiner Phase auf das Anderthalbfache seiner Baulaenge aus. Damit laesst sich ein Fahrbahnstueck hochklappen.",
	"In its phase a hydraulic cylinder extends to one and a half times its built length. That is enough to tilt a section of roadway upwards.")
add("level.W3L9.hint3",
	"Baue die Fahrbahn in zwei Haelften, die sich in der Mitte treffen. Unter jede Haelfte einen Zylinder. Waehle vor dem Bauen unten die Phase - beide in Phase 1, dann heben sie gemeinsam.",
	"Build the roadway as two halves meeting in the middle. A cylinder under each half. Pick the phase in the bottom bar before you build - both in phase 1 and they lift together.")

add("level.W3L10.name", "Der Sprung", "The jump")
add("level.W3L10.subtitle", "Eine Rampe. Mehr bekommst du nicht.",
	"A ramp. That is all you get.")
add("level.W3L10.hint1",
	"Sieh dir die Bauzone an: sie endet weit vor der anderen Seite. Eine durchgehende Bruecke gibt es hier nicht.",
	"Look at the build area: it ends far short of the other side. There is no continuous bridge here.")
add("level.W3L10.hint2",
	"Bau eine Rampe, die leicht ansteigt, und fahre schnell. Am Tacho lassen sich bis zu 14 Studs pro Sekunde einstellen.",
	"Build a gently rising ramp and drive fast. The speed dial goes up to 14 studs per second.")
add("level.W3L10.hint3",
	"Die Landeseite liegt acht Studs tiefer als der Start. Der Sprung ist also leichter, als er aussieht - aber die Rampe muss das Auto sauber abheben lassen.",
	"The landing side is eight studs lower than the start. The jump is easier than it looks - but the ramp has to let the car take off cleanly.")

add("level.W3L11.name", "Zwei Ebenen", "Two decks")
add("level.W3L11.subtitle", "Unten ein Auto, oben ein Lieferwagen.",
	"A car below, a van above.")
add("level.W3L11.hint1",
	"Die beiden oberen Anker liegen 24 Studs ueber den unteren. Dort gehoert die zweite Fahrbahn hin.",
	"The two upper anchors sit 24 studs above the lower ones. That is where the second deck belongs.")
add("level.W3L11.hint2",
	"Beide Ebenen zugleich zu tragen ist teuer. Guenstiger ist ein gemeinsames Fachwerk, dessen Obergurt zugleich die obere Fahrbahn ist.",
	"Carrying both decks separately is expensive. A single shared truss whose top chord doubles as the upper deck is cheaper.")
add("level.W3L11.hint3",
	"Der Lieferwagen oben wiegt nur 650 N. Die obere Ebene darf deshalb deutlich leichter ausfallen als die untere.",
	"The van above weighs only 650 N. The upper deck can therefore be much lighter than the lower one.")

add("level.W3L12.name", "Die grosse Schlucht", "The great canyon")
add("level.W3L12.subtitle", "Hundert Studs. Alles, was du gelernt hast.",
	"A hundred studs. Everything you have learned.")
add("level.W3L12.hint1",
	"Hundert Studs am Stueck traegt nichts. Die Felsnadel in der Mitte ist deine Rettung - von dort laesst sich ein Mittelpfeiler bauen.",
	"Nothing carries a hundred studs in one span. The rock spire in the middle is your salvation - a central pier can rise from there.")
add("level.W3L12.hint2",
	"Teile die Aufgabe: zwei Spannweiten von je fuenfzig Studs sind viel leichter als eine von hundert - die Gurtkraft faellt dabei auf ein Viertel.",
	"Split the problem: two spans of fifty studs are far easier than one of a hundred - the chord force drops to a quarter.")
add("level.W3L12.hint3",
	"Der Mittelpfeiler traegt beide Haelften. Baue ihn aus Stahl und stelle ihn breit auf beide Anker der Felsnadel, damit er nicht kippt.",
	"The central pier carries both halves. Build it from steel and stand it wide on both anchors of the spire so it cannot topple.")


--------------------------------------------------------------------------------
-- Fehlermeldungen fuer den Notfall
--------------------------------------------------------------------------------

add("error.noArena",
	"Die Bauflaeche konnte nicht geladen werden. Pruefe Workspace.StreamingEnabled.",
	"The build area could not be loaded. Check Workspace.StreamingEnabled.")
add("error.purchaseFailed", "Der Kauf konnte nicht geoeffnet werden: %s",
	"The purchase could not be opened: %s")
add("error.noServer",
	"Der Server antwortet nicht. Schau in Studio unter VIEW auf Output - die erste rote Zeile sagt, woran es liegt.",
	"The server is not responding. In Studio, open VIEW then Output - the first red line says why.")


--------------------------------------------------------------------------------
-- Weitere Texte der Spieloberflaeche
--------------------------------------------------------------------------------

add("hud.testHeadline", "Belastungstest", "Load test")
add("hud.testRunningHeadline", "Belastungstest laeuft", "Load test running")
add("hud.testStartsIn", "Test startet in %.0f ...", "Test starts in %.0f ...")
add("hud.ownWeight", "Die Bruecke traegt jetzt ihr eigenes Gewicht",
	"The bridge is now carrying its own weight")
add("hud.peakLoad", "Hoechste Auslastung", "Peak load")
add("hud.legendLow", "locker", "relaxed")
add("hud.legendMid", "wird eng", "getting tight")
add("hud.legendHigh", "am Limit", "at the limit")
add("hud.unstable", "Struktur nicht stabil - die rote Markierung zeigt die schwache Stelle",
	"Structure not stable - the red marker shows the weak spot")
add("hud.toLevelSelect", "Zur Levelauswahl", "Back to level select")
add("hud.buildAgain", "Noch einmal bauen", "Build it again")
add("hud.notPassed", "Nicht bestanden", "Not passed")
add("hud.hintsRevealed", "%d von %d aufgedeckt", "%d of %d revealed")
add("hud.noMoreHints", "Keine weiteren Tipps", "No more hints")
add("hud.nextHintFree", "Naechsten Tipp anzeigen (gratis)", "Show next hint (free)")
add("hud.nextHint", "Naechsten Tipp anzeigen", "Show next hint")


add("tut.start", "Los geht's", "Let's go")
add("tut.tryIt", "▸ Probiere es aus, dann geht es weiter",
	"▸ Try it out, then we continue")


--------------------------------------------------------------------------------
-- Bauschule
--------------------------------------------------------------------------------

add("school.title", "Bauschule", "Bridge school")
add("school.intro", "Vier Bilder, mit denen sich jedes Level loesen laesst.",
	"Four pictures that will get you through every level.")
add("school.open", "Bauschule", "Bridge school")

add("school.triangles.title", "Dreiecke halten, Vierecke nicht",
	"Triangles hold, rectangles do not")
add("school.triangles.text",
	"Ein Viereck laesst sich zur Raute verschieben, ohne dass ein einziges Bauteil laenger oder kuerzer wird - es haelt also nichts. Ein Dreieck kann das nicht. Deshalb besteht jede Bruecke aus lauter Dreiecken.",
	"A rectangle can be pushed over into a diamond without any part getting longer or shorter - so nothing holds it. A triangle cannot do that. This is why every bridge is made of triangles.")

add("school.truss.title", "So sieht ein Fachwerk aus", "This is what a truss looks like")
add("school.truss.text",
	"Unten die Fahrbahn, oben ein Gurt, dazwischen senkrechte Pfosten und schraege Diagonalen. Die Diagonalen sind das Wichtigste: erst sie machen aus den Vierecken Dreiecke.",
	"The roadway at the bottom, a chord along the top, vertical posts and slanted diagonals in between. The diagonals matter most: they are what turns the rectangles into triangles.")

add("school.doubling.title", "Bricht ein Teil? Ein zweites daneben",
	"A part breaking? Put a second one beside it")
add("school.doubling.text",
	"Zwei Bauteile auf denselben zwei Knoten teilen sich die Kraft - jedes traegt nur noch die Haelfte. Besonders wichtig bei der Fahrbahn: sie ist beim Fachwerk gleichzeitig der Untergurt und haelt allein nur 500 N.",
	"Two parts on the same two joints share the force - each carries only half. This matters most for the roadway: in a truss it doubles as the bottom chord, and on its own it only holds 500 N.")

add("school.depth.title", "Hoeher bauen heisst weniger Kraft",
	"Building taller means less force")
add("school.depth.text",
	"Die Kraft in den Gurten ist ungefaehr Gewicht mal Spannweite geteilt durch das Vierfache der Bauhoehe. Doppelte Bauhoehe heisst also HALBE Kraft. Ein hohes Fachwerk ist fast immer billiger als ein niedriges aus staerkerem Material.",
	"Chord force is roughly weight times span divided by four times the depth. So twice the depth means HALF the force. A tall truss is almost always cheaper than a shallow one built from stronger material.")


--------------------------------------------------------------------------------
-- Was soll ich denn noch dazu bauen?
--------------------------------------------------------------------------------

--[[
	Diese Saetze erscheinen nach einem gescheiterten Test unter der
	Begruendung. Sie sagen als Einziges im ganzen Spiel, was konkret zu TUN
	ist - deshalb sind sie bewusst als Handlungsanweisung formuliert und
	nicht als Erklaerung.
]]

add("advice.title", "Was du tun kannst", "What you can do")

add("advice.roadBroke",
	"Die FAHRBAHN ist gerissen. Sie traegt beim Fachwerk doppelt: als Strasse und als Untergurt. Lege ein zweites Bauteil auf genau dieselben zwei Punkte - Stahl, oder billiger noch ein Kabel, denn der Untergurt steht unter Zug.",
	"The ROADWAY broke. In a truss it does double duty: as road and as bottom chord. Put a second part on exactly the same two joints - steel, or cheaper still a cable, since the bottom chord is in tension.")

add("advice.chordBroke",
	"Der OBERGURT ist gerissen. Zwei Dinge helfen: baue das Fachwerk HOEHER - doppelte Bauhoehe heisst halbe Kraft - oder lege ein zweites Bauteil auf dieselben zwei Punkte.",
	"The TOP CHORD broke. Two things help: build the truss TALLER - twice the depth means half the force - or put a second part on the same two joints.")

add("advice.diagonalBroke",
	"Eine DIAGONALE ist gerissen. Mit nur einer Diagonale je Feld gibt es genau einen Weg fuer die Kraft, und der traegt alles allein. Setze in jedes Feld die ZWEITE Diagonale, so dass ein liegendes Kreuz entsteht.",
	"A DIAGONAL broke. With only one diagonal per bay there is exactly one path for the force, and it carries everything alone. Add the SECOND diagonal in every bay so each forms a lying cross.")

add("advice.postBroke",
	"Ein senkrechter PFOSTEN ist gerissen. Er ist meist zu lang: teile ihn in zwei kuerzere Stuecke und verbinde die Mitte schraeg zur Fahrbahn, damit er nicht seitlich wegknickt.",
	"A vertical POST broke. It is usually too long: split it into two shorter pieces and brace the middle diagonally to the roadway so it cannot buckle sideways.")

add("advice.unstable",
	"Hier ist nichts ausgesteift: an dieser Stelle haengt ein Knoten an nur zwei Bauteilen, die in derselben Linie liegen. So ein Knoten kann keine Last nach unten aufnehmen. Setze eine SCHRAEGE Verbindung dorthin - erst ein Dreieck haelt.",
	"Nothing is braced here: that joint hangs on only two parts lying in the same line. Such a joint cannot take any downward load. Add a DIAGONAL there - only a triangle holds.")

add("advice.fell",
	"Das Fahrzeug ist abgestuerzt. Meist hat die Fahrbahn eine LUECKE, oder ein Stueck ist zu steil - ueber etwa 33 Grad faellt das Fahrzeug hindurch. Fahre die Strecke im Kopf ab: liegt ueberall Strasse, und liegt sie flach genug?",
	"The vehicle fell. Usually the roadway has a GAP, or a piece is too steep - beyond about 33 degrees the vehicle falls straight through. Walk the route in your head: is there road everywhere, and is it flat enough?")

add("advice.tipped",
	"Das Fahrzeug ist gekippt. Meistens liegt das an einer Stufe in der Fahrbahn. Achte darauf, dass benachbarte Fahrbahnstuecke an denselben Knoten haengen und keinen Absatz bilden.",
	"The vehicle tipped over. Usually there is a step in the roadway. Make sure neighbouring road pieces share the same joints and do not form a ledge.")

add("advice.timeout",
	"Die Zeit ist abgelaufen. Stelle am Tacho ein hoeheres Tempo ein - oder pruefe, ob das Fahrzeug irgendwo haengengeblieben ist.",
	"Time ran out. Set a higher speed on the dial - or check whether the vehicle got stuck somewhere.")

add("advice.boatBlocked",
	"Die Bruecke steht dem Schiff im Weg. Baue ein Stueck Fahrbahn auf HYDRAULIK und schalte es in der Fussleiste hoch, bevor das Schiff kommt.",
	"The bridge is in the ship's way. Put a section of roadway on HYDRAULICS and raise it from the bottom bar before the ship arrives.")


add("school.cables.title", "Seile koennen nur ziehen", "Ropes can only pull")
add("school.cables.text",
	"Ein Seil traegt, wenn daran GEZOGEN wird - muesste es druecken, haengt es einfach durch und traegt gar nichts. Deshalb sind Seile oben am Obergurt nutzlos.\n\nWo sie sich lohnen: der UNTERGURT eines Fachwerks steht unter Zug. Ein Kabel neben der Fahrbahn kostet 5 je Stud statt 10 fuer Stahl - halber Preis, gleiche Wirkung.",
	"A rope carries when something PULLS on it - if it would have to push, it simply goes slack and carries nothing. That is why ropes are useless along the top chord.\n\nWhere they pay off: the BOTTOM chord of a truss is in tension. A cable beside the roadway costs 5 per stud instead of 10 for steel - half the price, same effect.")


add("blueprint.shown",
	"Die Vorlage zeigt die GRUNDFORM eines Fachwerks. In den ersten Leveln traegt sie so, spaeter musst du sie verstaerken - doppelte Diagonalen, zweites Bauteil neben der Fahrbahn, mehr Bauhoehe.",
	"The blueprint shows the BASIC shape of a truss. In the first levels it holds as it is; later you will need to reinforce it - double diagonals, a second part beside the roadway, more depth.")
add("blueprint.none", "Fuer dieses Level gibt es keine Vorlage.", "There is no blueprint for this level.")


return I18n
