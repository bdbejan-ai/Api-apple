# BridgeLab

Ein Physik-Baurätsel für Roblox, in Luau geschrieben. Der Spieler baut aus einem
begrenzten Budget eine Konstruktion über eine 40 Studs breite Schlucht. Danach
fährt ein 1000 Einheiten schweres Testfahrzeug hinüber. Hält die Konstruktion,
ist das Level geschafft.

„BridgeLab" ist ein Arbeitstitel und lässt sich jederzeit ändern – der Name
steht nur in `default.project.json` und in den Ordnernamen.

---

## 1. Installation

### 1.1 Rojo installieren

Rojo verbindet die Dateien auf der Festplatte mit Roblox Studio. Es gibt zwei
Wege; **Weg A** ist für Anfänger der einfachere.

**Weg A – Fertige Programmdatei (empfohlen)**

1. <https://github.com/rojo-rbx/rojo/releases> öffnen.
2. Beim neuesten Eintrag die Datei für das eigene Betriebssystem laden
   (`rojo-*-windows-x86_64.zip` bzw. `rojo-*-macos-*.zip`).
3. Entpacken. Es entsteht eine Datei `rojo.exe` (Windows) bzw. `rojo` (macOS).
4. Diese Datei in einen Ordner legen, der im `PATH` liegt – oder einfacher:
   direkt in den Ordner `bridgelab/` kopieren und später mit `.\rojo`
   bzw. `./rojo` aufrufen.

**Weg B – Über Rokit (Versionsverwaltung, praktisch bei mehreren Projekten)**

```bash
# Rokit einmalig installieren: https://github.com/rojo-rbx/rokit
rokit add rojo-rbx/rojo
rokit install
```

Prüfen, ob es geklappt hat:

```bash
rojo --version
```

### 1.2 Rojo-Plugin für Roblox Studio installieren

```bash
rojo plugin install
```

Das legt das Plugin direkt in den Studio-Plugin-Ordner. Falls der Befehl
fehlschlägt, geht es auch von Hand: im Roblox-Creator-Store nach **„Rojo"**
suchen und das offizielle Plugin von `rojo-rbx` installieren.

### 1.3 Server starten

Im Ordner `bridgelab/` (dort, wo `default.project.json` liegt):

```bash
rojo serve
```

In der Konsole erscheint eine Adresse, meist `localhost:34872`. Das Fenster
bleibt offen, solange gearbeitet wird.

---

## 2. Diese Schritte musst du einmalig selbst in Roblox Studio machen

Alles Folgende lässt sich nicht aus Dateien heraus erledigen – es sind
Klickschritte in der Studio-Oberfläche.

1. **Roblox Studio öffnen** und ein neues Projekt anlegen:
   *New* → **Baseplate**.

2. **Baseplate löschen** (optional, aber empfohlen).
   Im *Explorer* unter `Workspace` das Objekt `Baseplate` anklicken und `Entf`
   drücken. BridgeLab baut seine eigene Landschaft.
   Lässt du die Baseplate stehen, ist das kein Fehler – sie liegt bei y = 0 und
   damit unterhalb der Schlucht. Ein herunterfallendes Fahrzeug landet dann
   darauf statt ins Leere zu fallen.

3. **Rojo-Plugin verbinden.**
   Oben im Menüband auf den Reiter **PLUGINS** wechseln → **Rojo** anklicken →
   im aufgehenden Fenster auf **Connect**. Host und Port stehen schon richtig
   drin (`localhost` / `34872`), sofern `rojo serve` läuft.
   Beim ersten Mal fragt Studio nach Erlaubnis für HTTP-Zugriff – **Allow**.

4. **Ergebnis prüfen.** Im *Explorer* müssen jetzt auftauchen:
   - `ReplicatedStorage` → `BridgeLab` (Config, Level1, Remotes, TrussSolver)
   - `ServerScriptService` → `BridgeLabServer`
   - `StarterPlayer` → `StarterPlayerScripts` → `BridgeLabClient`

   Fehlt etwas, war die Verbindung nicht erfolgreich – noch einmal *Connect*.

5. **HTTP-Requests sind nicht nötig**, aber diese Einstellung schon:
   *Home* → *Game Settings* → *Security* → **Allow HTTP Requests** darf aus
   bleiben. BridgeLab braucht kein Internet.

6. **Testen:** Reiter *TEST* → **Play** (oder `F5`).
   Die Spielfigur erscheint auf der linken Plattform, unten erscheint die
   Werkzeugleiste.

7. **Speichern nicht vergessen:** `Strg+S`. Rojo synchronisiert nur Skripte –
   die Studio-Datei (`.rbxl`) musst du selbst sichern.

### Wenn du später weiterarbeitest

Nur noch: `rojo serve` starten → Studio öffnen → Plugin *Connect*. Änderungen an
den `.luau`-Dateien landen sofort in Studio.

---

## 3. Spielen

| Aktion | Bedienung |
|---|---|
| Bauteil wählen | Knopf unten anklicken, oder Taste `1` `2` `3` |
| Entfernen-Modus | Knopf „Entfernen", oder Taste `4` |
| Bauteil setzen | ersten Ankerpunkt anklicken, dann zweiten |
| Auswahl abbrechen | Rechtsklick, oder denselben Punkt noch einmal anklicken |
| Bauteil löschen | Rechtsklick auf das Bauteil |
| Test starten | Knopf „Test starten" |
| Zurücksetzen | Knopf „Zurücksetzen" |

**Farben der Bauteile** zeigen die Auslastung: grün = viel Reserve,
gelb = etwa halb ausgelastet, rot = kurz vor dem Bruch.

**Oben links** steht, ob sich die Konstruktion überhaupt selbst trägt. Steht dort
„Nicht ausgesteift", markiert eine rote Kugel den Ankerpunkt, an dem die Last
nicht abgetragen werden kann. Dort fehlt eine Stütze oder eine Verstrebung.

### Eine Lösung für Level 1

Falls du nicht weiterkommst – diese Konstruktion besteht den Test und kostet
110 von 200 Einheiten:

1. **Fünf Balken** als Fahrbahn, jeweils über zwei Rasterfelder (8 Studs):
   von x = −20 nach −12, −12 nach −4, −4 nach 4, 4 nach 12, 12 nach 20.
2. **Vier Stützen** senkrecht vom Schluchtgrund zu den vier freien
   Fahrbahnknoten bei x = −12, −4, 4 und 12.

Die höchste Auslastung liegt dabei bei 89 % (eine Stütze trägt kurzzeitig
etwa 713 N von 800 N). Es gibt weitere Lösungen – zum Beispiel kürzere
Fahrbahnbalken mit entsprechend mehr Stützen, solange das Budget reicht.

---

## 4. Aufbau des Projekts

```
bridgelab/
  default.project.json         Rojo-Zuordnung Dateien -> Roblox-Instanzen
  src/
    Shared/                    -> ReplicatedStorage.BridgeLab
      Config.luau              Bauteilwerte, Physikregler, Remote-Namen
      Level1.luau              Maße, Ankerpunkte und Fahrzeug für Level 1
      Remotes.luau             RemoteEvents anlegen bzw. finden
      TrussSolver.luau         der Fachwerk-Rechner (reine Mathematik)
    Server/                    -> ServerScriptService.BridgeLabServer
      init.server.luau         Hauptskript: Zustand und RemoteEvents
      LevelBuilder.luau        baut Landschaft, Ankerpunkte, Bruch-Effekt
      Structure.luau           verwaltet Bauplan, Parts und Constraints
      ForceEngine.luau         füttert den Rechner und färbt die Bauteile
      TestRun.luau             Belastungstest mit Fahrzeug
    Client/                    -> StarterPlayerScripts.BridgeLabClient
      init.client.luau         verbindet Oberfläche und Steuerung
      BuildGui.luau            ScreenGui, komplett im Code aufgebaut
      BuildController.luau     Anklicken der Ankerpunkte, Vorschau
```

### Wo ändere ich was?

| Ich möchte … | Datei |
|---|---|
| Kosten oder Grenzwerte eines Bauteils ändern | `Shared/Config.luau` |
| Durchbiegen stärker/schwächer machen | `Config.Physics.loadForceScale` |
| Lücke, Budget, Zeitlimit, Ankerraster ändern | `Shared/Level1.luau` |
| Fahrzeugmasse oder -geschwindigkeit ändern | `Shared/Level1.luau`, `Level1.vehicle` |
| Aussehen der Oberfläche ändern | `Client/BuildGui.luau` |

---

## 5. Wie die Physik funktioniert

Es laufen **zwei getrennte Rechnungen** nebeneinander:

**1. Die Roblox-Physik-Engine** kümmert sich nur um das Aussehen: das
Durchbiegen unter Last, das Einstürzen nach einem Bruch, das Fahrzeug.
Dafür sitzt an jedem benutzten Ankerpunkt eine kleine Kugel („Knoten"), und
zwischen den Knoten hängen die Constraints:

- **Balken und Stützen**: `RodConstraint` – hält den Abstand starr, in beide
  Richtungen.
- **Seile**: `RopeConstraint` – verhindert nur, dass die Knoten weiter
  auseinandergehen.

**2. Ein eigener Fachwerk-Rechner** (`TrussSolver.luau`) entscheidet, ob ein
Bauteil bricht. Das ist nötig, weil Roblox die tatsächlich in einem Constraint
wirkende Kraft nicht ausliest – es gibt schlicht keine solche Eigenschaft.
Der Rechner stellt darum an jedem beweglichen Knoten das Kräftegleichgewicht
auf und löst das entstehende Gleichungssystem als Ausgleichsrechnung
(kleinste Fehlerquadrate).

Wichtige Eigenschaft dieses Modells: Jedes Bauteil ist ein **Stab mit Gelenken
an beiden Enden**. Es kann nur längs gezogen oder gedrückt werden und sich nicht
verbiegen. Deshalb trägt eine schnurgerade Fahrbahn ohne Stützen oder Dreiecke
gar nichts – jeder freie Knoten braucht eine Abstützung. Genau das ist die
eigentliche Rätselaufgabe.

Bleibt an einem Knoten eine Kraft übrig, die sich nicht ausgleichen lässt
(„Restkraft"), ist die Konstruktion dort nicht ausgesteift. Im Baumodus wird
das als Warnung angezeigt, im Test führt es zum Versagen.

**Einheiten:** Das Kräftemodell rechnet mit g = 1. Eine Masse von 1000 Einheiten
erzeugt also 1000 N Gewichtskraft. Dadurch passen die vorgegebenen Grenzwerte
(500 N / 300 N / 800 N) und die Fahrzeugmasse (1000) unmittelbar zusammen: das
Fahrzeug muss von mehreren Bauteilen gemeinsam getragen werden.

---

## 6. Getroffene Annahmen

Alles, was in der Aufgabenstellung offen war, ist hier so entschieden worden –
jeweils zugunsten der einfachsten sinnvollen Lösung.

### Physikmodell

1. **Fachwerk statt Balkenbiegung.** Bauteile werden als Stäbe mit Gelenken an
   beiden Enden gerechnet (nur Normalkraft, keine Biegung). Das ist die
   klassische Vereinfachung im Brückenbau und kommt ohne FEM aus. Folge: eine
   gerade Fahrbahn ohne Abstützung versagt.
2. **Zweidimensional.** Es wird nur in der XY-Ebene gerechnet, die Brücke liegt
   ohnehin flach bei z = 0.
3. **Einheitensystem mit g = 1** (siehe oben). Die Roblox-Schwerkraft
   (196,2 Studs/s²) betrifft nur die Darstellung.
4. **Statisch unbestimmte Konstruktionen** werden über die Lösung mit der
   kleinsten Kraftsumme aufgelöst. Das entspricht der Annahme, dass alle
   Bauteile gleich steif sind.
5. **Kein Knicken.** Ein Balken auf Druck hält genauso viel aus wie auf Zug,
   unabhängig von seiner Länge. Die Aufgabenstellung gibt beide Werte mit
   500 N an, das wurde übernommen.
6. **Kraftglättung.** Die berechnete Kraft wird geglättet (Faktor 0,35), damit
   einzelne Rechenspitzen kein Bauteil zerstören. Erst 0,5 Sekunden nach
   Teststart kann überhaupt etwas brechen.

### Bauteile und Raster

7. **Maximale Spannweiten**: Balken 10 Studs, Seil und Stütze 26 Studs.
   Ohne eine solche Grenze könnte man die Lücke mit einem einzigen Balken
   überbrücken, und das Rätsel wäre keines. Die 10 Studs erlauben Balken über
   ein oder zwei Rasterfelder sowie Diagonalen zur oberen Reihe.
8. **Mindestlänge 3 Studs** für alle Bauteile.
9. **Kosten sind längenunabhängig** (so vorgegeben). Lange Balken sind damit
   günstiger je Stud – das ist bewusst so gelassen.
10. **„Nur vertikal"** bei der Stütze heißt: beide Ankerpunkte haben dieselbe
    X-Koordinate.
11. **Zwei feste Ankerpunkte lassen sich nicht verbinden.** Das würde nur
    Budget kosten und nichts bewirken.
12. **Drei Reihen von Ankerpunkten** statt nur einer entlang der Lücke:
    Fahrbahnhöhe, 8 Studs darüber (für Türme und Abspannungen) und am
    Schluchtgrund (Fußpunkte für Stützen). Mit nur einer Reihe wären
    Dreiecksverbände unmöglich.
13. **Kollision**: Nur Balken und Stützen sind fest; Seile und die Knotenkugeln
    gehen durch. Das Fahrzeug soll nur auf der Fahrbahn aufliegen.

### Testlauf

14. **Das Fahrzeug gleitet, es rollt nicht.** Ein einzelner Block wird jeden
    Frame auf konstante Waagerechtgeschwindigkeit gesetzt; senkrecht wirkt die
    Schwerkraft normal. Ein Fahrzeug mit echten Rädern wäre deutlich mehr
    Aufwand und für den Belastungstest ohne Gewinn.
15. **Geschwindigkeit 8 Studs/s.** Die Strecke von 68 Studs dauert damit rund
    9 Sekunden – gut innerhalb des Zeitlimits von 30 Sekunden.
16. **Jeder Bruch während des Tests bedeutet Misserfolg**, nicht nur ein Bruch
    direkt unter dem Fahrzeug. Die Aufgabenstellung nennt beim Erfolg
    ausdrücklich „ohne dass ein Bauteil bricht".
17. **Die Last wird an drei Stellen abgetastet** (hinten, Mitte, vorne des
    Fahrzeugs) und über die getroffenen Bauteile auf deren Endknoten verteilt.
    So verteilt sich das Gewicht über die Fahrzeuglänge statt an einem Punkt zu
    hängen.
18. **Kippen** zählt ab etwa 45 Grad Neigung als Misserfolg.
19. **Absacken** wird an der Starthöhe des Fahrzeugs gemessen, nicht an der
    Fahrbahnoberkante – der Unterschied beträgt eine halbe Fahrzeughöhe.
20. **Im Baumodus ist die Physik eingefroren.** Alle Knoten sind verankert; der
    Test löst die Bremse. Sonst würde eine halbfertige Konstruktion schon beim
    Bauen einstürzen.
21. **Nach dem Test bleibt der Bauplan erhalten.** „Zurücksetzen" baut auch
    zerbrochene Teile wieder auf, ohne dass man neu anfangen muss.

### Aufbau und Mehrspieler

22. **Ein gemeinsames Level für alle Spieler auf dem Server.** Alle bauen an
    derselben Brücke, jeder darf testen und zurücksetzen. Getrennte Level je
    Spieler wären deutlich mehr Aufwand.
23. **Kein Fortschritt wird gespeichert.** Kein DataStore, keine Punkte.
24. **Die Spielfigur wird beim Test nicht berücksichtigt.** Steht sie auf der
    Brücke, drückt sie in der Roblox-Physik zwar mit, geht aber nicht in die
    Kräfteberechnung ein. Sie startet seitlich neben der Fahrspur.
25. **Die Landschaft entsteht im Code**, nicht als Rojo-Instanzen. So stehen
    alle Maße an einer Stelle (`Level1.luau`) und lassen sich lesen und ändern.
26. **Die Oberfläche wird im Code aufgebaut.** GUI-Instanzen über Rojo würden
    Binärdateien (`.rbxmx`) erfordern, die sich weder lesen noch von Hand
    ändern lassen.
27. **Nur Maus und Tastatur.** Keine Bedienung für Touch oder Gamepad.
28. **Kein Ton.** Der Bruch-Effekt ist ein einfacher Partikelausstoß, wie in der
    Aufgabenstellung als Platzhalter zugelassen.

---

## 7. Weiterbauen

**Level 2 anlegen:** `Shared/Level1.luau` kopieren, Werte anpassen, in
`Server/init.server.luau` in der Zeile `require(Shared.Level1)` das neue Modul
eintragen. Alles andere liest die Maße aus dem Level-Modul.

**Balance ändern:** Alle Zahlen zu Kosten und Grenzwerten stehen in
`Shared/Config.luau` unter `Config.PartTypes`.

**Der Rechner ist getestet.** `TrussSolver.luau` hängt an keiner Roblox-API und
lässt sich mit dem Luau-Kommandozeilenprogramm einzeln ausführen und prüfen
(z. B. gegen die Handrechnung eines einfachen Dreiecks).
