# Umbau zum Brückenbau-Spiel im Poly-Bridge-Stil

**Arbeitsauftrag an mich selbst.** Dieses Dokument ist die Vorgabe für den
nächsten großen Umbau. Es steht im Projekt, damit später nachvollziehbar ist,
warum etwas so gebaut wurde — und damit du widersprechen kannst, bevor ich
anfange.

Stand: BridgeLab hat 7 Level, ein festes Ankerpunkt-Raster aus drei Reihen,
drei Bauteiltypen und rund 9 200 Zeilen Code.

---

## 1. Ziel und Abgrenzung

### Was gebaut wird

Ein Brückenbau-Rätselspiel mit den **Spielmechaniken** von Poly Bridge:
freies Bauen auf einem Raster, mehrere Materialien mit unterschiedlichen
Eigenschaften, Hydraulikzylinder mit Phasensteuerung, Belastungstest mit
sichtbarer Spannung, Level mit vorgegebenem Budget.

### Was ausdrücklich NICHT gebaut wird

Kein Klon von Marke, Grafik oder Leveln.

- **Kein** Name, Logo, Schriftzug oder Farbschema von Poly Bridge
- **Keine** nachgebauten Original-Level
- **Keine** kopierten Modelle, Texturen, Klänge oder Musik

Spielmechaniken sind nicht urheberrechtlich geschützt — konkrete Gestaltung,
Level und Assets schon. Ein Spiel mit fremdem Namen und fremder Optik auf
Roblox zu veröffentlichen führt zu einer Meldung und Sperrung. Ein Spiel mit
demselben Prinzip, aber eigener Gestaltung, ist unproblematisch.

Der Arbeitstitel bleibt vorerst **BridgeLab**.

---

## 2. Was bleibt, was fällt weg

### Bleibt unverändert

| Baustein | Warum er trägt |
|---|---|
| `TrussSolver.luau` | Rechnet mit Knoten und Stäben, nicht mit Ankerpunkten. Freies Bauen ändert nur, wo Knoten liegen |
| Kraftmodell (g = 1, N-Grenzwerte) | Funktioniert und ist geprüft |
| Bruchlogik, Schonfrist, Kräfteglättung | Unverändert |
| Arena-Konzept (eine Kopie je Spieler) | Unverändert |
| Server entscheidet, Client wünscht | Grundregel bleibt |
| Tacho, Fortschritt, Tipps, Robux | Unverändert |
| `tools/check_levels.luau`, `tools/check_code.py` | Werden angepasst, nicht ersetzt |

### Fällt weg oder wird ersetzt

| Bisher | Neu |
|---|---|
| Drei feste Ankerreihen (`deck`, `upper`, `ground`) | Freies Raster: Knoten überall in der Bauzone |
| Ankerpunkt-Nummern als Bauteil-Enden | Knoten-IDs, die beim Bauen entstehen |
| Kosten pro Bauteil (10 / 5 / 15) | **Kosten pro Stud Länge** |
| 3 Bauteiltypen | 7 Materialien |
| Klick auf Punkt A, Klick auf Punkt B | Ziehen von A nach B |
| Level = Lückenbreite + drei Höhen | Level = Geländeprofil + Anker + Bauzone |

**Kosten pro Stud ist zwingend.** Bei freiem Bauen mit Festpreis je Bauteil
würde jeder einfach möglichst lange Bauteile setzen — die Länge wäre gratis.

---

## 3. Kernmechaniken

Nach Wichtigkeit sortiert. P1 muss, P2 sollte, P3 wenn Zeit bleibt.

### P1 — Freies Bauen auf dem Raster

Das ist **die** Mechanik, die den Unterschied ausmacht.

- Rasterweite **2 Studs**, sichtbar als feines Punktmuster in der Bauzone
- Bauteil entsteht durch **Ziehen** von einem Punkt zum anderen
- Knoten entstehen automatisch an den Enden; endet ein Zug auf einem
  vorhandenen Knoten, wird dieser benutzt
- **Ankerpunkte** sind fest im Gelände verankert (unbeweglich) und optisch
  klar unterscheidbar
- Bauzone begrenzt, wo gebaut werden darf (Rechteck je Level)
- Beim Ziehen: laufende Anzeige von Länge und Kosten, Vorschau grün/rot

**Gerätebedienung**
- Maus: linke Taste gedrückt halten und ziehen
- Touch: mit einem Finger ziehen (Kamera weiterhin zwei Finger)
- Gamepad: A gedrückt halten, Zeiger mit dem linken Stick bewegen

### P1 — Materialien

Sieben Typen. Werte sind Startwerte und werden mit dem Prüfskript nachjustiert.

| Material | Zug (N) | Druck (N) | Kosten/Stud | Masse/Stud | max. Länge | befahrbar |
|---|---|---|---|---|---|---|
| **Straße** | 500 | 500 | 8 | 2,0 | 10 | ja |
| **Verstärkte Straße** | 1000 | 1000 | 14 | 3,0 | 10 | ja |
| **Holz** | 400 | 400 | 4 | 1,5 | 12 | nein |
| **Stahl** | 1200 | 1200 | 10 | 2,5 | 16 | nein |
| **Seil** | 300 | 0 | 2 | 0,4 | 40 | nein |
| **Kabel** | 800 | 0 | 5 | 0,8 | 40 | nein |
| **Hydraulik** | 900 | 900 | 25 | 3,0 | 14 | nein |

**Wichtig:** Stahl mit 1200 N löst das größte Balanceproblem des jetzigen
Spiels. Bisher war die einzige tragfähige Bauform „Stützen bis zum Grund",
weil ein Fachwerk mit 500-N-Balken bei realistischen Spannweiten reißt. Mit
Stahl werden Fachwerke, Bögen und Hängebrücken erstmals wirklich baubar —
und damit wird jedes Level zu einer eigenen Aufgabe statt zur gleichen mit
anderen Zahlen.

### P1 — Belastungstest ohne Anzeigen-Chaos

Das aktuelle Problem: Schriftfelder über jedem Bauteil, Testfenster, Tacho und
Fußleiste überlagern sich.

Regeln:
- Während des Tests wird die **Bauleiste komplett ausgeblendet**
- Spannungszahlen erscheinen **nur** für Bauteile über 25 % Auslastung,
  höchstens die **acht** am stärksten belasteten gleichzeitig
- Schriftfelder verkleinern sich mit der Kameraentfernung und verschwinden
  jenseits von 160 Studs ganz
- Farbe am Bauteil bleibt immer sichtbar — sie ist die Hauptinformation
- Eine einzige schmale Leiste oben zeigt Zeit, Tempo, höchste Auslastung
  und Fahrzeuge-am-Ziel

### P2 — Hydraulik und Phasen

Die Mechanik hinter Zugbrücken.

- Ein Hydraulikzylinder hat **zwei Längen**: eingefahren und ausgefahren
- Jeder Zylinder gehört zu einer **Phase** (1 bis 4)
- Im Test schaltet der Spieler die Phasen weiter (Knopf oder Zeitplan)
- Die Zylinder der aktiven Phase fahren in ein bis zwei Sekunden aus, die
  anderen zurück
- Für den Rechner ist ein Zylinder ein starrer Stab seiner **aktuellen** Länge

Damit werden möglich: Zugbrücken, ausfahrbare Rampen, Klappbrücken für ein
Boot, das unten durchfährt.

### P2 — Ziele über „einmal rüberfahren" hinaus

- **Mehrere Fahrzeuge** (gibt es schon)
- **Boot-Durchfahrt**: ein Boot muss unter der Brücke durch, also muss sie
  sich öffnen — zwingt zur Hydraulik
- **Sprung**: eine Rampe, über die das Fahrzeug eine Lücke überspringt
- **Kontrollpunkte**: das Fahrzeug muss unterwegs bestimmte Stellen berühren

### P3 — Kür

- Wiederholung der letzten Fahrt in Zeitlupe
- Sandkasten ohne Budget
- Federn als achtes Material
- Eigene Level bauen und teilen

---

## 4. Level-Aufbau

### Aufbau eines Levels

Statt „Lückenbreite plus drei Höhen" beschreibt ein Level ein **Geländeprofil**:

```lua
{
    id = "W1L3",
    name = "Der schmale Grat",
    budget = 900,

    -- Gelände als Liste von Stützstellen (x, Höhe). Dazwischen wird
    -- geradlinig verbunden. Höhe 0 = Wasser/Abgrund.
    terrain = {
        { x = -80, y = 40 }, { x = -30, y = 40 },   -- linkes Plateau
        { x = -30, y = 0 },  { x = 20, y = 0 },     -- Schlucht
        { x = 20, y = 52 },  { x = 80, y = 52 },    -- rechtes Plateau, höher
    },

    waterY = 12,          -- Wasserspiegel, nur Optik
    buildArea = { minX = -34, maxX = 24, minY = 8, maxY = 78 },

    anchors = {           -- feste Punkte, an denen gebaut werden darf
        { x = -30, y = 40 }, { x = -34, y = 40 },
        { x = 20, y = 52 },  { x = 24, y = 52 },
    },

    materials = { "Road", "Wood", "Steel", "Rope" },   -- erlaubt

    vehicles = {
        { kind = "Car", from = -60, to = 60, deckY = "auto" },
    },
}
```

### Gestaltungsregeln für Level

Diese Regeln halte ich beim Entwerfen ein:

1. **Jedes Level hat einen Gedanken.** Nicht „dasselbe, nur breiter", sondern
   eine neue Frage: höhere Gegenseite, kein Grund zum Abstützen, Boot muss
   durch, zwei Fahrzeuge gleichzeitig, Budget knapp.
2. **Wenig Anker.** Zwei bis sechs. Je weniger, desto mehr muss die
   Konstruktion selbst tragen.
3. **Das Budget entscheidet über die Bauform.** Ein knappes Budget zwingt zu
   Holz und Seil, ein großzügiges erlaubt Stahl.
4. **Lösbar mit mindestens zwei verschiedenen Bauformen.** Wird mit dem
   Prüfskript nachgewiesen.
5. **Budgetreserve 20 bis 40 %** gegenüber der günstigsten tragenden Lösung.
   Weniger frustriert, mehr langweilt.

### Levelplan: 3 Welten, 12 Level

**Welt 1 — Grundlagen** (Straße, Holz, Seil)

| # | Name | Gedanke |
|---|---|---|
| 1 | Der erste Graben | Kurze Lücke, viel Budget. Freies Bauen lernen |
| 2 | Dreiecke | Zu lang für eine gerade Fahrbahn. Fachwerk nötig |
| 3 | Hängepartie | Tiefer Abgrund, kein Grund erreichbar. Seile von oben |
| 4 | Sparzwang | Level 2 mit halbem Budget |

**Welt 2 — Werkstoffe** (dazu Stahl, Kabel, verstärkte Straße)

| # | Name | Gedanke |
|---|---|---|
| 5 | Weit gespannt | 70 Studs am Stück. Nur Stahl trägt das |
| 6 | Steile Kante | Gegenseite 20 Studs höher, Fahrbahn muss steigen |
| 7 | Doppelte Last | Zwei schwere Lastwagen gleichzeitig |
| 8 | Der Bogen | Anker nur unten. Ein Druckbogen ist die günstigste Lösung |

**Welt 3 — Bewegliche Teile** (dazu Hydraulik)

| # | Name | Gedanke |
|---|---|---|
| 9 | Klappbrücke | Ein Boot muss durch. Erste Hydraulik |
| 10 | Der Sprung | Rampe bauen, Fahrzeug springt über die Lücke |
| 11 | Gegenverkehr | Zwei Fahrzeuge, zwei Spuren, enge Mitte |
| 12 | Die große Schlucht | Alles zusammen, 100 Studs, knappes Budget |

---

## 5. Oberfläche

Die drei Beanstandungen von dir, konkret gelöst.

### Nichts steht sich mehr im Weg

Feste Zonen, die sich nie überschneiden:

```
┌──────────────────────────────────────────────────────────┐
│ Kopfzeile: Level · Budget-Balken · Menü · Zurücksetzen    │  56 px
├────┬─────────────────────────────────────────────────────┤
│ M  │                                                     │
│ a  │                                                     │
│ t  │              Spielfeld (frei)                       │
│ e  │                                                     │
│ r  │                                                     │
│ i  │                                                     │
│ a  ├─────────────────────────────────────────────────────┤
│ l  │ Phasen 1-4 (nur bei Hydraulik)   Tacho   TEST ▶     │  72 px
└────┴─────────────────────────────────────────────────────┘
 72px
```

- **Materialleiste links senkrecht**, als Symbolspalte mit Kosten/Stud.
  Sie nimmt keine Breite vom Spielfeld weg, die man zum Bauen braucht.
- **Fußleiste** enthält nur noch Phasen, Tacho und den Test-Knopf.
- Alle Zonen werden aus **einer** Layout-Funktion positioniert, die die
  Bildschirmgröße kennt. Kein Element bekommt mehr eigene Zahlen.
- Auf schmalen Bildschirmen (Handy hochkant) wandert die Materialleiste nach
  unten und die Fußleiste wird zweizeilig.

### Schöner

- Halbtransparente dunkle Flächen mit weichem Schlagschatten statt flacher
  Kästen
- Ein durchgehendes Raster von 4 px für alle Abstände
- Materialsymbole als kleine Zeichnungen (I-Träger, Balken, Seil), nicht als
  Textzeichen
- Sanftes Ein- und Ausblenden beim Moduswechsel

### Test-Anzeigen

Siehe P1 oben: Bauleiste weg, höchstens acht Zahlen, entfernungsabhängige
Größe, eine schmale Kopfleiste für alles Übrige.

---

## 6. Bauteile realistischer

Jedes Material bekommt ein eigenes Profil aus mehreren Teilen:

| Material | Aufbau |
|---|---|
| **Straße** | Asphaltband, seitliche Bordsteine, darunter ein Blechträger |
| **Verstärkte Straße** | wie Straße, zusätzlich sichtbarer Fachwerkuntergurt |
| **Holz** | Zwei Bohlen nebeneinander, Maserung durch leicht verschiedene Brauntöne, Stahlplatte an jedem Ende |
| **Stahl** | **Echtes I-Profil**: Ober- und Untergurt plus dünner Steg, dazu Knotenbleche |
| **Seil** | Dünner Strang mit **Durchhang** — drei Teilstücke statt einer geraden Linie |
| **Kabel** | Wie Seil, dicker, metallisch glänzend |
| **Hydraulik** | Zylinder plus Kolbenstange, die beim Ausfahren sichtbar herausfährt |

**Knoten** werden zu kleinen Stahl-Knotenblechen mit Bolzen statt der jetzigen
Kugeln.

Der **Durchhang bei Seilen** ist der auffälligste Gewinn: ein schlaffes Seil
sieht dann auch schlaff aus, statt schnurgerade in der Luft zu stehen.

---

## 7. Technischer Umbauplan

| Datei | Änderung | Aufwand |
|---|---|---|
| `Shared/Materials.luau` | **neu** — ersetzt `Config.PartTypes` | mittel |
| `Shared/Levels.luau` | **Neuschrift** — Geländeprofil statt Reihen | groß |
| `Shared/Terrain.luau` | **neu** — Höhe an Stelle x, Kollisionsprüfung | klein |
| `Shared/Config.luau` | Raster, Bauzone, Phasen, Anzeigegrenzen | klein |
| `Server/Structure.luau` | Knoten dynamisch statt nach Ankerindex | groß |
| `Server/LevelBuilder.luau` | Gelände aus Profil bauen, Wasser, Anker | groß |
| `Server/TestRun.luau` | Phasenschaltung, Boot, Sprungprüfung | mittel |
| `Server/ForceEngine.luau` | Hydraulik-Länge berücksichtigen | klein |
| `Client/BuildController.luau` | Ziehen statt zweimal klicken, Rasterfang | groß |
| `Client/BuildHud.luau` | **Neuschrift** — Zonen-Layout, Materialspalte | groß |
| `Client/StressView.luau` | **neu** — Auswahl und Größe der Zahlen | mittel |
| `tools/check_levels.luau` | Freies Bauen, neue Materialien | mittel |

**Reihenfolge der Umsetzung** (jede Stufe ist für sich spielbar):

1. **Oberfläche und Optik** — deine drei Punkte. Ohne Mechanikänderung,
   deshalb risikoarm und sofort sichtbar.
2. **Materialien und Kosten pro Stud** — bestehende Level bleiben lauffähig,
   Werte werden neu geprüft.
3. **Freies Bauen** — der große Schnitt. Danach sind die alten Level ungültig.
4. **Neue Level** mit Geländeprofil, 12 Stück, alle geprüft.
5. **Hydraulik und Phasen.**
6. **Boot, Sprung, Kontrollpunkte.**

---

## 8. Wie geprüft wird

Ohne Roblox-Laufzeit bleibt Prüfen die einzige Absicherung.

- `tools/check_code.py` nach **jeder** Änderung
- `luau-compile` über alle Dateien nach jeder Änderung
- `tools/check_levels.luau` wird erweitert: es baut je Level mehrere
  Standardformen (Fachwerk, Bogen, Hängebrücke, Stützen) **auf dem freien
  Raster** und weist nach, dass mindestens zwei davon halten und ins Budget
  passen
- Neu: eine Prüfung, dass jedes Level mit den **erlaubten** Materialien
  lösbar ist — nicht mit gesperrten

---

## 9. Was ich entschieden habe, ohne zu fragen

1. **Rasterweite 2 Studs.** Feiner wird unübersichtlich, gröber nimmt
   Gestaltungsfreiheit.
2. **Kosten pro Stud.** Ohne das ist freies Bauen nicht sinnvoll begrenzbar.
3. **Stahl bei 1200 N.** Damit werden Fachwerke tragfähig — das ist die
   Kernkorrektur am bisherigen Balanceproblem.
4. **Vier Phasen.** Mehr braucht kein Level, das ich plane.
5. **Alte Level werden ersetzt, nicht portiert.** Sie sind auf das
   Drei-Reihen-Raster zugeschnitten; eine Umsetzung wäre mehr Arbeit als
   neue, bessere Level.
6. **Der Fortschritt geht dabei verloren**, weil die Level-Kennungen neu sind.
   Bei einem noch nicht veröffentlichten Spiel ist das verschmerzbar.

---

## 10. Was du entscheiden solltest

- **Reihenfolge**: Soll ich wirklich mit der Oberfläche anfangen (Stufe 1),
  oder ist dir das freie Bauen wichtiger?
- **Umfang**: 12 Level sind viel Arbeit. Reichen dir für den Anfang 6?
- **Hydraulik**: Das ist die aufwendigste Einzelmechanik. Soll sie rein?
- **Name**: Bleibt es bei BridgeLab?

Wenn du nichts sagst, arbeite ich die Reihenfolge aus Abschnitt 7 von oben
nach unten ab.
