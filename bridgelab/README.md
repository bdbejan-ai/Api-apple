# BridgeLab

Ein Physik-Baurätsel für Roblox: Du baust aus Balken, Seilen und Stützen eine
Brücke über eine Schlucht. Danach fährt ein 1000 Einheiten schweres Fahrzeug
darüber — in späteren Leveln auch zwei gleichzeitig. Hält die Konstruktion,
hast du gewonnen.

Arbeitstitel — der Name lässt sich jederzeit ändern (siehe [Umbenennen](#umbenennen)).

---

## Inhalt

1. [Was das Spiel kann](#was-das-spiel-kann)
2. [Installation](#installation)
3. [Die manuellen Schritte in Roblox Studio](#die-manuellen-schritte-in-roblox-studio)
4. [Robux-Tipps einrichten](#robux-tipps-einrichten)
5. [Steuerung](#steuerung)
6. [Welche Datei macht was](#welche-datei-macht-was)
7. [Eigene Level bauen](#eigene-level-bauen)
8. [Getroffene Annahmen](#getroffene-annahmen)
9. [Bekannte Grenzen](#bekannte-grenzen)

---

## Was das Spiel kann

| | |
|---|---|
| **Freies Bauen** | Kein Ausmalbild aus vorgegebenen Punkten mehr: du baust frei auf einem 2‑Studs‑Raster. Nur die wenigen **Anker** eines Levels sind fest im Boden — alles dazwischen muss deine Konstruktion selbst tragen |
| **Sieben Baustoffe** | Straße, Verstärkte Straße, Holz, Stahl, Seil, Kabel, Hydraulik. Jeder kostet **je Stud Länge** — ein langer Balken kostet mehr als ein kurzer |
| **Zwölf Level in drei Welten** | Von einem schmalen Graben bis zur 100 Studs weiten Schlucht mit Felsnadel. Jedes ist nachweislich lösbar (siehe „Level prüfen") |
| **Level-Auswahl** | Jede Karte zeichnet die **echte Geländeform** des Levels samt Ankerpunkten. Dazu Schwierigkeit (1–5), Budget, Spannweite und Haken für geschaffte Level |
| **Interaktive Anleitung** | Startet beim allerersten Spielstart automatisch. Man baut wirklich selbst; die Texte passen sich dem Eingabegerät an |
| **Seitenansicht** | Keine Spielfigur. Beliebig nah heranzoomen; herauszoomen nur so weit, bis das Level das Bild füllt |
| **Tacho** | Schieberegler von 1 bis 14 Studs/s. Einstellbar vor dem Test **und mitten in der Fahrt**. Das Zeitlimit passt sich mit an |
| **Belastungsanzeige** | Die **Farbe** am Bauteil zeigt immer die Auslastung. Zahlentafeln bekommen nur die acht am stärksten belasteten Teile — sonst sieht man vor lauter Zahlen die Brücke nicht mehr |
| **Hydraulik** | Zylinder fahren auf Knopfdruck aus und heben, was an ihnen hängt. Damit baut man Klappbrücken |
| **Schiff** | In „Klappbrücke" muss ein Schiff unter der Brücke durch. Steht sie im Weg, ist der Test gescheitert — auch wenn nichts gebrochen ist |
| **Sprung** | In „Der Sprung" gibt es nur **einen** Anker. Das Fahrzeug muss über die Lücke fliegen |
| **Genaues Abreißen** | Das Bauteil unter dem Zeiger wird hervorgehoben, bevor man klickt — auch bei dünnen Seilen und sich kreuzenden Streben |
| **Tipps** | Drei pro Level. Bei Schwierigkeit 1–3 ist der erste gratis, ab Schwierigkeit 4 kostet schon der erste Robux |
| **Fortschritt** | Geschaffte Level, gesehene Anleitung und gekaufte Tipp‑Gutscheine werden dauerhaft gespeichert |
| **Mehrspieler** | Jeder Spieler bekommt seine eigene Arena und kann ein eigenes Level spielen |

---

## Die drei Sätze, die dich durch das ganze Spiel bringen

**1. Dreiecke sind stabil, Vierecke kippen um.**
Das ist der wichtigste Satz im Brückenbau. Ein Viereck aus vier Streben lässt
sich zu einer Raute verschieben, ohne dass eine Strebe länger oder kürzer wird
— es hält also nichts. Ein Dreieck kann das nicht.

**2. Bricht die Straße, leg ein zweites Bauteil daneben.**
Beim Fachwerk ist die Fahrbahn gleichzeitig der Untergurt und trägt die volle
Gurtkraft. Straße hält aber nur 500 N. Setzt du auf **dieselben zwei Punkte**
noch einen Stahlträger, teilen sich beide die Kraft:

```
vorher:   o====== Straße ======o        bei 500 N ist Schluss
nachher:  o====== Straße ======o        zusammen
          o======= Stahl ======o        bis 1000 N
```

Der **schwächere** der beiden bestimmt die Grenze: Straße (500) mit Stahl
(1200) trägt zusammen 1000 N, nicht 1700. Nimmst du die Verstärkte Straße
(1000 N), sind es 2000 N — der doppelte Preis je Stud kauft hier also
wirklich die doppelte Tragfähigkeit.

**3. Ist die Brücke zu weit gespannt, bau sie höher.**
In den Gurten eines Fachwerks steckt ungefähr die Kraft

```
Kraft ≈ Gewicht × Spannweite / (4 × Bauhöhe)
```

Doppelte Bauhöhe heißt also **halbe** Kraft. Deshalb ist ein hohes Fachwerk
fast immer billiger als ein niedriges aus stärkerem Material.

---

---

## Installation

Du brauchst zwei Dinge: **Roblox Studio** (das Programm, in dem das Spiel läuft)
und **Rojo** (ein Werkzeug, das die Code-Dateien von deiner Festplatte in
Studio schiebt). Rojo ist kein Fenster-Programm — es läuft im Terminal.

### Windows

PowerShell öffnen (Windows-Taste → „PowerShell" tippen → Enter):

```powershell
winget install -e --id Rojo.Rojo
```

PowerShell danach **einmal schließen und neu öffnen**, sonst kennt Windows den
Befehl noch nicht. Dann prüfen:

```powershell
rojo --version
```

Es sollte eine Versionsnummer erscheinen, z. B. `Rojo 7.4.4`.

> Falls `winget` unbekannt ist: Windows aktualisieren (winget kommt mit dem
> „App Installer" aus dem Microsoft Store), oder Rojo als fertige `.exe` von
> <https://github.com/rojo-rbx/rojo/releases> herunterladen.

### macOS

```bash
brew install rojo
```

Ohne Homebrew: die Datei für macOS von <https://github.com/rojo-rbx/rojo/releases>
laden und entpacken.

### Das Studio-Plugin installieren

```powershell
rojo plugin install
```

Das legt das Rojo-Plugin automatisch in deinem Studio-Plugin-Ordner ab.
Studio danach neu starten.

---

## Die manuellen Schritte in Roblox Studio

Diese Dinge kann kein Skript für dich tun — das musst du einmalig selbst in der
Studio-Oberfläche anklicken.

### 1. Rojo verbinden

1. Terminal in **diesem Ordner** öffnen (dort, wo `default.project.json` liegt)
   und starten:
   ```
   rojo serve
   ```
   Es erscheint etwa `Rojo server listening on port 34872`.
   **Dieses Fenster offen lassen**, solange du arbeitest.

2. In Studio ein neues Projekt anlegen: **Baseplate**.

3. Den mitgelieferten Part „Baseplate" im **Explorer** anklicken und mit
   `Entf` löschen. BridgeLab baut seine Welt komplett selbst.
   > Explorer nicht sichtbar? Reiter **VIEW → Explorer**.

4. Reiter **PLUGINS → Rojo → Connect**. Adresse `localhost`, Port `34872`.

Wenn es geklappt hat, erscheinen im Explorer sofort:

```
ReplicatedStorage → BridgeLab      (Config, Levels, Remotes, TrussSolver)
ServerScriptService → BridgeLabServer
StarterPlayer → StarterPlayerScripts → BridgeLabClient
```

### 2. DataStore freischalten (für den Fortschritt)

Ohne diesen Schritt läuft das Spiel ganz normal — der Fortschritt ist nach dem
Beenden nur wieder weg, und im Output steht eine Warnung.

**Home → Game Settings → Security → „Enable Studio Access to API Services"**
einschalten. Das Spiel muss dafür einmal veröffentlicht sein
(**File → Publish to Roblox**).

### 3. Testen

`F5` drücken (oder **Home → Play**).

> **Wichtig:** „Play", nicht „Run". Nur „Play" startet auch einen Client, und
> die ganze Oberfläche ist Client-Code.

Beim allerersten Start springt das Spiel direkt in Level 1 und die Anleitung
öffnet sich. Danach landest du immer in der Levelauswahl.

---

## Wenn etwas nicht funktioniert

### Die Oberfläche ist da, aber das Level ist unsichtbar

Fast immer ist **Streaming** schuld. Bei eingeschaltetem `StreamingEnabled`
schickt der Server einem Spieler nur die Umgebung rund um **seine Spielfigur**.
Die gibt es in BridgeLab absichtlich nicht (Seitenansicht) — ohne Bezugspunkt
bekommt der Client deshalb gar keine Welt übertragen. Die Oberfläche liegt in
der PlayerGui und wird immer übertragen, die Brücke fehlt komplett.

**Prüfen:** Explorer → **Workspace** anklicken → im Fenster **Properties** die
Zeile **StreamingEnabled** suchen. Der Haken muss **weg** sein.

Abgeschaltet wird die Einstellung über `default.project.json` — sie kommt also
beim Synchronisieren mit. Der Server kann sie **nicht** selbst abschalten:
Roblox erlaubt das Setzen nur im Bearbeitungsmodus. Er prüft sie beim Start und
schreibt eine Warnung in den Output, wenn der Haken doch gesetzt ist.

### Im Output steht „Arena nicht gefunden"

Gleiche Ursache wie oben — siehe dort.

### Gar nichts passiert, keine Oberfläche

Hast du **Play** gedrückt oder **Run**? Nur „Play" startet auch einen Client,
und die gesamte Oberfläche ist Client-Code.

### Im Output steht eine Warnung zum DataStore

Normal, solange „Enable Studio Access to API Services" aus ist. Das Spiel läuft
trotzdem, der Fortschritt wird nur nicht gespeichert. Siehe
[DataStore freischalten](#2-datastore-freischalten-für-den-fortschritt).

---

## Robux-Tipps einrichten

**Das Spiel funktioniert komplett ohne diesen Schritt.** Solange nichts
eingetragen ist, erscheint statt des Kauffensters die Meldung „Der Tipp-Kauf ist
noch nicht eingerichtet". Gratis-Tipps funktionieren normal.

Wenn du echte Käufe möchtest:

1. Das Spiel veröffentlichen (**File → Publish to Roblox**).
2. Auf <https://create.roblox.com/dashboard/creations> dein Spiel öffnen.
3. **Monetization → Developer Products → Create Developer Product**.
   - Name z. B. „Tipp freischalten"
   - Preis z. B. 15 Robux
4. Die **Product-ID** kopieren (eine lange Zahl).
5. In `src/Shared/Config.luau` eintragen:

```lua
Config.Monetisation = {
    hintProductId = 123456789,  -- <- hier deine Zahl
    hintPrice = 15,             -- nur für die Anzeige im Knopf
}
```

### Wie der Kauf abläuft

Gekauft wird nicht ein bestimmter Tipp, sondern ein **Tipp-Gutschein**. Beim
nächsten kostenpflichtigen Tipp wird ein Gutschein eingelöst. Das ist
absichtlich so: Ein Kauf geht dadurch auch dann nicht verloren, wenn der Spieler
zwischendurch das Level wechselt oder die Verbindung abbricht.

Weil es hier um echtes Geld geht, ist der Beleg-Ablauf in
`src/Server/Monetisation.luau` bewusst streng: Jeder Kaufbeleg wird über
`UpdateAsync` in einem eigenen DataStore vermerkt, bevor gutgeschrieben wird.
So kann derselbe Beleg nicht zweimal gutgeschrieben werden, und ein bezahlter
Kauf geht auch dann nicht verloren, wenn der Server im falschen Moment abstürzt
— Roblox fragt dann später erneut nach.

---

## Steuerung

Das Spiel erkennt selbst, womit gespielt wird, und stellt Texte und
Knopfgrößen darauf ein. Wechselt man mitten im Spiel das Gerät, passt es sich
sofort an.

| | Maus + Tastatur | Touch | Gamepad |
|---|---|---|---|
| **Bauteil ziehen** | linke Maustaste **halten** und ziehen | Finger aufsetzen und ziehen | **A** halten |
| Bauteil setzen | Maustaste loslassen | Finger heben | **A** loslassen |
| Bauteil entfernen | Rechtsklick darauf | Abriss‑Knopf, dann tippen | **B** |
| Ansicht schieben | rechte Maustaste ziehen, oder WASD | **zwei** Finger ziehen | rechter Stick |
| Zoomen | Mausrad | zwei Finger auf-/zuziehen | **LT** / **RT** |
| Zeiger bewegen | Maus | Finger | linker Stick |
| Baustoff 1…7 | Tasten `1`–`7` | Leiste links | Leiste links |
| Abrissmodus | Taste `X` | Knopf „Abriss" | **X** |
| Tempo einstellen | Regler ziehen oder −/+ | Regler ziehen oder −/+ | Regler mit dem Zeiger |
| Hydraulik-Phase | Phasenknöpfe unten | Phasenknöpfe unten | Phasenknöpfe unten |

**Die Phasenknöpfe haben zwei Bedeutungen.** Beim Bauen legen sie fest, zu
welcher Phase der **nächste** Zylinder gehört; im Test lösen sie diese Phase
aus. „Ein" (Phase 0) heißt „alles eingefahren" und gibt es nur im Test. So kann
man etwa beide Brückenhälften in Phase 1 legen und sie mit einem Druck
gemeinsam hochklappen — oder sie auf Phase 1 und 2 verteilen und nacheinander
öffnen.

**Warum wird zum Bauen gezogen und nicht zweimal geklickt?** Beim Ziehen
siehst du die ganze Zeit, was entsteht, und ein Versehen brichst du ab, indem
du zum Anfangspunkt zurückziehst. Ein zu kurzer Zug zählt gar nicht als
Bauversuch — sonst entstünde bei jedem versehentlichen Klick ein Bauteil.

**Warum bei Touch zwei Finger für die Kamera?** Ein Finger wird zum Bauen
gebraucht. Würde ein Finger auch die Kamera schieben, könnte das Spiel nie
sicher unterscheiden, ob jemand bauen oder schauen will.

---

## Welche Datei macht was

```
bridgelab/
├── default.project.json      Rojo-Bauplan: welche Datei landet wo in Studio
├── tools/
│   ├── check_levels.luau     Prüfwerkzeug: sind die Level lösbar?
│   └── check_code.py         findet Namensfehler zwischen den Dateien
└── src/
    ├── Shared/               kennen Server UND Client
    │   ├── Config.luau       Einstellungen: Raster, Physik, Kamera, Preise
    │   ├── Materials.luau    die sieben Baustoffe mit Grenzwerten und Preisen
    │   ├── Terrain.luau      rechnet mit dem Geländeprofil (Höhe, Kollision)
    │   ├── Levels.luau       die zwölf Level als reine Zahlen
    │   ├── Remotes.luau      legt die RemoteEvents an
    │   └── TrussSolver.luau  der Fachwerk-Rechner (reine Mathematik)
    │
    ├── Server/               läuft nur auf dem Server (nicht manipulierbar)
    │   ├── init.server.luau  Hauptskript: prüft alle Wünsche der Clients
    │   ├── Arena.luau        die Spielsitzung EINES Spielers
    │   ├── LevelBuilder.luau baut Gelände, Wasser, Anker, Zierrat
    │   ├── Structure.luau    verwaltet die gesetzten Bauteile
    │   ├── ForceEngine.luau  Bindeglied zum Fachwerk-Rechner
    │   ├── TestRun.luau      Belastungstest, Hydraulik, Schiff, Sprung
    │   ├── PlayerData.luau   Fortschritt speichern (DataStore)
    │   └── Monetisation.luau Robux-Käufe
    │
    └── Client/               läuft beim Spieler (nur Anzeige und Eingabe)
        ├── init.client.luau      verdrahtet alle Teile
        ├── Device.luau           erkennt Maus / Touch / Gamepad
        ├── Theme.luau            Farben und UI-Bausteine
        ├── CameraController.luau die Seitenansicht
        ├── BuildController.luau  Bau-Interaktion für alle drei Geräte
        ├── LevelSelectGui.luau   das Startmenü
        ├── BuildHud.luau         Oberfläche im Spiel
        └── TutorialGui.luau      die interaktive Anleitung
```

### Warum `Levels.luau` von nichts abhängt

`Levels.luau` benutzt bewusst **keine** Roblox-Typen: Größen stehen als
`{ X = 8, Y = 4, Z = 5 }` statt als `Vector3`, Farben als `{ 198, 72, 58 }`
statt als `Color3`. Der Server rechnet das beim Bauen um.

Der Grund: nur so kann das Prüfskript in `tools/` die Datei direkt einlesen und
**die echten Leveldaten** prüfen, statt eine Kopie zu pflegen. Genau so eine
Kopie ist schon einmal auseinandergelaufen, und der Fehler fiel erst im Spiel
auf.

### Die wichtigste Regel im Code

**Der Client schickt nur Wünsche, der Server entscheidet.** Ein manipulierter
Client kann höchstens unsinnige Anfragen stellen — ob ein Bauteil entsteht, ob
ein Tipp freigeschaltet wird und ob der Test bestanden ist, prüft immer der
Server. Jede Zahl, die hereinkommt, wird geprüft, bevor sie benutzt wird.

---

## Eigene Level bauen

In `src/Shared/Levels.luau` einen Eintrag kopieren und die Zahlen ändern.

### Das Gelände ist ein Linienzug

Ein Level beschreibt sein Gelände als Liste von Stützstellen, zwischen denen
geradlinig verbunden wird. Zwei Punkte mit **demselben x** bilden eine
senkrechte Kante — so entstehen Kliffs.

```lua
terrain = {
    { x = -80, y = 30 },   -- linkes Plateau
    { x = -12, y = 30 },
    { x = -12, y =  0 },   -- senkrecht hinunter (gleiches x!)
    { x =  12, y =  0 },   -- Schluchtgrund
    { x =  12, y = 30 },   -- senkrecht hinauf
    { x =  80, y = 30 },   -- rechtes Plateau
},
```

### Anker sind die eigentliche Aufgabe

```lua
anchors = {
    { x = -12, y = 30 },
    { x =  12, y = 30 },
},
```

**Nur hier** kann die Konstruktion Last in den Boden abgeben. Alles dazwischen
muss sie selbst tragen. Wie viele Anker es gibt und wie weit sie auseinander
liegen, entscheidet über die Schwierigkeit weit mehr als das Budget.

Ein zusätzlicher Anker mitten in der Schlucht — auf einer Felsnadel oder einem
Vorsprung — halbiert die Spannweite und **viertelt** damit ungefähr die
Gurtkraft. Genau so werden die großen Level lösbar.

### Drei Regeln, die ein Level sonst unlösbar machen

Alle drei sind mir beim Bauen selbst passiert:

1. **Alle Zahlen müssen gerade sein.** Das Raster ist 2 Studs weit. Ein Anker
   bei `x = 35` wird beim Bauen auf 36 gerundet — und dort ist kein Anker mehr.
   Die Brücke hängt dann an nichts, und der Rechner meldet völlig zu Recht
   „instabil". Das Prüfskript fängt das inzwischen vorab ab.

2. **Die Spannweite muss zum Fahrzeug passen.** Es gilt ungefähr

   ```
   größte Spannweite ≈ 4 × Bauhöhe × Grenzwert / Fahrzeuggewicht
   ```

   Ein Kleinwagen (420 N) über ein Holzfachwerk (550 N) mit 10 Studs Bauhöhe
   schafft also rund 52 Studs. Ein Lastwagen (1600 N) käme dort auf 14.

3. **Nicht zwei schwere Fahrzeuge auf eine freie Spannweite.** Zwei Lastwagen,
   die sich in der Mitte begegnen, ergeben 3200 N an einer Stelle — daran
   scheitert jede Bauform. Entweder leichtere Fahrzeuge nehmen oder einen
   Pfeiler in die Mitte stellen.

### Fahrzeuge

```lua
vehicles = {
    { kind = "Car", fromX = -64, toX = 64, lane = -2.6 },
    { kind = "Car", fromX =  64, toX = -64, lane = 2.6 },
},
```

`kind` ist einer von `MiniCar` (420 N), `Van` (650 N), `Car` (900 N),
`Truck` (1600 N). Bei Gegenverkehr braucht jedes Fahrzeug eine eigene `lane`
(seitlicher Versatz), sonst fahren sie frontal ineinander. Bestanden ist der
Test erst, wenn **alle** angekommen sind.

### Schiff und Sprung

```lua
boat = { fromX = -70, toX = 70, speed = 9, mastHeight = 22, length = 14 },
requiresJump = true,
```

Beim Schiff prüft der Server, ob ein Bauteil in den Durchfahrtsbereich ragt —
dann ist der Test gescheitert, auch wenn nichts gebrochen ist. Die Angaben
werden beim Laden geprüft: ein Tippfehler im Feldnamen bricht sofort mit einer
klaren Meldung ab, statt still einen Ersatzwert zu nehmen.

### Level prüfen, bevor du sie spielst

Im Ordner `tools/` liegt ein Prüfskript. Es liest **die echten Leveldaten** aus
`Levels.luau`, baut mehrere Standard-Brückenformen (Fachwerk, verstärktes
Fachwerk, Kreuzverband, Bogen, Hängebrücke, jeweils mit und ohne Pfeiler),
lässt die Fahrzeuge rechnerisch darüberfahren und meldet Kosten und höchste
Auslastung — ohne dass Roblox laufen muss.

Dafür brauchst du das Luau-Programm von
<https://github.com/luau-lang/luau/releases> (Datei `luau-ubuntu.zip`,
`luau-windows.zip` bzw. `luau-macos.zip`). Dann:

```bash
cd tools
luau check_levels.luau
```

Ausgabe pro Level, zum Beispiel:

```
W1L1  Der erste Graben
   Budget 800   Spannweite 24   Anker 2   Fahrzeuge 1
   Fachwerk Wood/Road h6 p8   17 Teile  Kosten 582/800  max 100%  LOESUNG
   => LOESBAR ueber 'Fachwerk Wood/Road h6 p8' fuer 582 (27% Budget uebrig)
```

Hält keine Form, meldet das Skript den **knappsten Versuch** mit Ort und Kraft
des überlasteten Bauteils — daran sieht man sofort, ob der Obergurt, eine
Diagonale oder die Fahrbahn nachgibt und was am Level zu ändern ist. Hält eine
Form, ist sie aber zu teuer, schlägt es ein passendes Budget vor.

Das Skript liest `Levels.luau` **selbst** aus — du musst neue Level nirgends
doppelt eintragen. (Früher gab es eine Kopie der Zahlen im Prüfskript, und
genau die ist einmal auseinandergelaufen.)

**Alle zwölf mitgelieferten Level sind damit geprüft** und haben zwischen 9 %
und 27 % Budgetreserve gegenüber der günstigsten funktionierenden Lösung.
„Der Sprung" ist von Hand entworfen — dort gibt es keine durchgehende Fahrbahn,
die sich mit Standardformen prüfen ließe.

### Den Code prüfen

Daneben liegt `tools/check_code.py`. Es findet die Fehler, die der Luau-Compiler
**nicht** sieht, weil sie syntaktisch korrekt sind — und die deshalb erst im
laufenden Spiel auffallen würden:

- Aufrufe von Methoden, die es nicht gibt (Tippfehler)
- Felder, die benutzt, aber nie gesetzt werden → `attempt to index nil`
- RemoteEvents, bei denen ein Ende fehlt (nur Sender oder nur Empfänger)
- Rückruf-Felder (`onXyz`), die nie verdrahtet wurden
- Bedienelemente, die die Anleitung hervorheben will, aber nicht existieren
- Ordnernamen, die zwischen LevelBuilder, Server und Client auseinanderlaufen
- Felder, die der Code aus den Leveldaten liest, die es dort aber nicht gibt

```bash
python3 tools/check_code.py
```

Braucht Python 3 (unter Windows aus dem Microsoft Store oder von python.org).
Lohnt sich immer dann, wenn du selbst größere Umbauten gemacht hast.

### Umbenennen

„BridgeLab" steht an vier Stellen: `default.project.json` (`name`), die
Ordnernamen `BridgeLab` / `BridgeLabServer` / `BridgeLabClient` ebendort, die
Überschrift in `LevelSelectGui.luau` und `Config.RemoteFolderName`. Änderst du
die Ordnernamen, müssen die `WaitForChild("BridgeLab")`-Zeilen mitgeändert
werden — am einfachsten mit Suchen-und-Ersetzen über den ganzen `src`-Ordner.

---

## Getroffene Annahmen

Überall dort, wo deine Vorgabe offen war, habe ich die einfachste sinnvolle
Lösung gewählt. Hier die vollständige Liste:

### Physik und Balance

1. **Einheiten mit g = 1.** Eine Masse von 1000 erzeugt genau 1000 N. Dadurch
   lassen sich Fahrzeuggewicht und Bauteilgrenzwerte direkt vergleichen.
2. **Zwei getrennte Physiken.** Die Roblox-Engine ist nur fürs Aussehen
   zuständig (Durchbiegen, Einsturz). Ob ein Bauteil bricht, entscheidet
   ausschließlich der eigene Fachwerk-Rechner auf dem Server.
3. **Gelenkige Stäbe, kein Biegen.** Jedes Bauteil kann nur längs gezogen oder
   gedrückt werden. Deshalb trägt sich eine schnurgerade Fahrbahn nicht selbst —
   genau das ist die Rätselaufgabe.
4. **Kosten je Stud statt Festpreis.** Beim freien Bauen wäre ein Festpreis
   unsinnig — jeder würde nur noch die längsten möglichen Teile setzen, weil
   Länge nichts kostet.
5. **Holz (550 N) ist stärker als Straße (500 N).** Vorher war es mit 400 N
   schwächer, und das war verkehrt herum gedacht: beim Fachwerk ist die
   Fahrbahn der Untergurt und der Obergurt darüber trägt genauso viel. War der
   Tragbaustoff schwächer als die Fahrbahn, riss immer zuerst der Obergurt —
   Holz war damit für seinen eigentlichen Zweck unbrauchbar.
6. **Die Schwierigkeit kommt aus Fahrzeug und Spannweite**, nicht aus
   heimlich angehobenen Grenzwerten. Welt 1 fährt einen Kleinwagen (420 N),
   damit Holzfachwerke dort überhaupt tragen können; das Finale einen
   Lastwagen (1600 N).
7. **Fahrgeschwindigkeit 3,5 statt 8 Studs/s**, damit man die Belastungszahlen
   lesen kann. Die Zeitlimits sind entsprechend großzügig.
8. **Bauteile brechen erst nach 0,6 s Schonfrist**, sonst zerstört der Ruck
   beim Lösen der Verankerung sofort etwas.
9. **Nur flach liegende Fahrbahnstücke sind befahrbar.** Steigt ein Balken stärker als
   etwa 30 Grad, gilt er als Strebe: das Fahrzeug fährt hindurch, statt
   dagegenzustoßen. Sonst könnte man seine Brücke nicht aussteifen, ohne sich
   selbst den Weg zu verbauen. Getragen wird trotzdem voll mit — für die
   Kräfteberechnung ändert sich nichts. Der Schwellwert steht in
   `Config.Test.roadwayMaxRise`.
10. **Tragwerk blockiert nie.** Eine Strebe, die von der Fahrbahn nach oben
    gebaut wird, stünde sonst mitten im Weg.
11. **Die Regularisierung im Fachwerk-Rechner ist 1e-8, nicht 1e-4.** Mit dem
    größeren Wert meldete der Rechner lange, flache Fachwerke als „instabil",
    obwohl jeder Knoten ordentlich ausgesteift war: die Regularisierung
    unterdrückt nicht nur echte Wackelstellen, sondern auch weiche
    Durchbiegungen, und was sie schluckt, taucht als Restkraft wieder auf.
    Eine echte Wackelstelle hat den Eigenwert null und wird auch mit 1e-8
    zuverlässig erkannt.

### Spielaufbau

12. **Eine eigene Arena pro Spieler**, senkrecht gestapelt im Abstand von 600
    Studs. Nötig, weil jeder ein eigenes Level wählen darf.
10. **Keine Spielerfigur.** `CharacterAutoLoads` ist aus, die Kamera ist fest
   auf Seitenansicht gestellt.
11. **Der Bauplan überlebt den Test.** Bricht etwas, bleibt der Plan erhalten —
   „Zurücksetzen" stellt alles wieder her, ohne dass man neu bauen muss.
12. **Höchstens 16 Spieler gleichzeitig** in eigenen Arenen (`Config.Arena`).

### Tempo und Kamera

13. **Der Spieler bestimmt die Fahrgeschwindigkeit**, nicht das Level. Das
    Zeitlimit rechnet sich aus Strecke und Tempo (`Strecke / Tempo × 2 + 15 s`),
    damit langsames Fahren nie bestraft wird.
14. **Herauszoomen ist begrenzt**, und zwar für jedes Level einzeln auf genau
    die Entfernung, bei der es das Bild füllt. Weiter wäre nur leere Umgebung.
    Heranzoomen bleibt unbegrenzt.
15. **Abreißen trifft die Bauteil-Achse, nicht die Oberfläche.** Statt eines
    Strahls wird der kürzeste Abstand zwischen Zeigestrahl und Bauteilachse
    gerechnet. Ein Strahl trifft immer nur das vorderste sichtbare Teil — bei
    dünnen Seilen greift man damit ständig daneben.

### Tipps und Robux

16. **Drei Tipps pro Level**, von allgemein zu konkret. Der dritte nennt die
    Lösung mit Stückzahlen.
17. **Gratis-Regel an den Schwierigkeitsgrad gekoppelt:** Stufe 1–3 bekommt
    einen Gratis-Tipp, Stufe 4–5 keinen. Das setzt deine Vorgabe („bei den
    Anfangsleveln der erste gratis, bei den späteren nicht") in eine Regel um,
    die auch für neue Level automatisch gilt.
18. **Ein einziges Robux-Produkt** für alle Tipps statt eines pro Level.
19. **Jedes Level ist ohne Tipps lösbar.** Das steht auch so in der Anleitung.

### Oberfläche

20. **Ein gemeinsamer „Zeigepunkt"** für alle drei Eingabearten. Deshalb gibt
    es die Trefferlogik nur einmal.
22. **Der Zeigepunkt wird mit der Bauebene geschnitten**, statt den nächsten
    Ankerpunkt zu suchen. Das trifft immer, unabhängig von Kamera und Zoom, und
    kann von nichts verdeckt werden.
23. **Die Oberfläche ist in vier Zonen aufgeteilt** (Kopf, Baustoffleiste
    links, rechte Spalte, Fußleiste), und die Plätze werden an genau einer
    Stelle vergeben. Vorher lagen die Fenster an festen Bildschirmpunkten und
    überlagerten sich auf schmalen Bildschirmen.
24. **Nur die acht am stärksten belasteten Bauteile bekommen eine Zahlentafel.**
    Bei vierzig Teilen war der Bildschirm sonst zugepflastert. Die Farbe am
    Bauteil bleibt immer sichtbar — sie ist die Hauptinformation.
21. **Zwei Finger für die Kamera** auf Touch (Begründung oben).
22. **Die Anleitung startet automatisch beim ersten Mal in Level 1** und ist
    danach über das Menü wieder erreichbar.
23. **Belastungszahlen als BillboardGui am Bauteil** — die überträgt Roblox von
    selbst zum Client, dafür braucht es kein eigenes RemoteEvent.
24. **Deutsche Texte ohne Umlaute im Spiel** (`ue` statt `ü`). Roblox-Schriften
    stellen Umlaute nicht überall zuverlässig dar. In dieser README stehen
    Umlaute normal.

---

## Bekannte Grenzen

Ehrlich gesagt, was noch fehlt oder wacklig ist:

- **Nicht in Roblox getestet.** Ich konnte den Code hier nicht in Studio
  ausführen. Geprüft ist: alle Dateien kompilieren mit dem echten
  Luau-Compiler, die Lösbarkeit aller zwölf Level wurde mit dem echten
  Fachwerk-Rechner nachgerechnet, und `tools/check_code.py` findet
  Namensfehler zwischen den Dateien. Was das *nicht* abdeckt, sind
  Laufzeitfehler, die erst mit echten Roblox-Objekten auftreten — falsch
  platzierte Fenster, eine Kamera, die woanders steht als gedacht, ähnliches.
  Rechne damit, dass beim ersten Start noch Kleinigkeiten zu richten sind, und
  schick mir die Fehlermeldungen aus **VIEW → Output**.
- **Die Baustoffleiste braucht Höhe.** Sieben Baustoffe übereinander brauchen
  rund 450 Pixel. Auf einem sehr flachen Fenster wird die Leiste abgeschnitten;
  sie wird dann gekürzt, statt in die Fußleiste zu ragen.
- **Der Gamepad-Zeiger** ist selbstgebaut (ein Ring, den der linke Stick
  bewegt). Roblox bietet dafür nichts Fertiges, wenn es keine Spielfigur gibt.
- **Das Durchhängen der Seile ist reine Optik.** Ein Seil wird aus fünf
  Teilstücken entlang einer Parabel gezeichnet; für die Kräfteberechnung zählt
  weiterhin nur die gerade Verbindung zwischen den beiden Knoten.
- **Das Wasser ist reine Optik.** Kein Auftrieb, keine Strömung; Bauteile
  dürfen mitten hindurch. Echtes Wasser würde die Kräfteberechnung verfälschen.
- **Bögen und Hängebrücken tragen in diesem Modell nicht.** Beides ist gebaut
  und wird vom Prüfskript mitgetestet, aber beides scheitert an derselben
  Sache: Ein Bogen ist nur für eine **gleichmäßig verteilte** Last die richtige
  Form. Ein Fahrzeug ist eine **Einzellast, die wandert** — steht sie zwischen
  zwei Stützen, will sich der Bogen dort eindrücken und anderswo heben. Echte
  Bogenbrücken haben deshalb einen Versteifungsträger; in einem Modell aus rein
  gelenkigen Stäben reicht auch der nicht. Das Prüfskript meldet das inzwischen
  ausdrücklich (`Bogen  haelt NICHT, bestenfalls 268%`), statt die Bauform
  stillschweigend wegzulassen — deshalb heißt das ehemalige Level „Der Bogen"
  jetzt „Kreuz und quer" und bringt einem den Kreuzverband bei.
- **Das Sprunglevel ist nicht rechnerisch geprüft.** Dort gibt es keine
  durchgehende Fahrbahn, die sich mit Standardformen prüfen ließe — es ist von
  Hand entworfen und braucht echtes Probespielen.
- **Der Fachwerk-Rechner wächst mit der dritten Potenz der Bauteilzahl.**
  Deshalb sind höchstens 140 Bauteile je Spieler erlaubt
  (`Config.Build.maxMembers`). Bei sechzehn Spielern gleichzeitig ist das die
  eigentliche Grenze des Servers.
- **Keine Bestenliste, keine Sterne-Wertung, kein Level-Editor.**
