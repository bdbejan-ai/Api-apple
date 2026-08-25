# BridgeLab

Ein Physik-Baurätsel für Roblox: Du baust aus Balken, Seilen und Stützen eine
Brücke über eine Schlucht. Danach fährt ein 1000 Einheiten schweres Fahrzeug
darüber. Hält die Konstruktion, hast du gewonnen.

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
| **Level-Auswahl** | Sechs Level mit angezeigtem Schwierigkeitsgrad (1–5 Punkte), Budget, Lückenbreite und Haken für geschaffte Level |
| **Interaktive Anleitung** | Startet beim allerersten Spielstart automatisch. Neun Schritte, in denen man wirklich selbst baut. Texte passen sich dem Eingabegerät an |
| **Seitenansicht** | Keine Spielfigur. Die Kamera schaut waagerecht auf die Brücke, wie ein Brettspiel von der Seite |
| **Belastungsanzeige** | Über jedem Bauteil steht während des Tests, wie stark es belastet ist — in Prozent und in Newton, dazu ein Farbbalken |
| **Langsamer Test** | Das Fahrzeug fährt mit 3,2 Studs/s (statt vorher 8), mit Countdown davor. Man kann in Ruhe zusehen |
| **Tipps** | Drei Tipps pro Level. In Level 1–3 ist der erste gratis, in Level 4–6 kostet schon der erste Robux |
| **Fortschritt** | Geschaffte Level, gesehene Anleitung und gekaufte Tipp-Gutscheine werden dauerhaft gespeichert |
| **Mehrspieler** | Jeder Spieler bekommt seine eigene Arena und kann ein eigenes Level spielen |

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

Der Server schaltet das beim Start selbst ab, und in `default.project.json`
steht es ebenfalls. Setzt du den Haken in Studio von Hand wieder, ist das Spiel
allerdings wieder blind.

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
| Ankerpunkt wählen | Linksklick | kurz tippen | **A** |
| Abbrechen / entfernen | Rechtsklick | Abriss-Knopf, dann tippen | **B** / **X** |
| Ansicht schieben | rechte Maustaste ziehen, oder WASD | **zwei** Finger ziehen | rechter Stick |
| Zoomen | Mausrad | zwei Finger auf-/zuziehen | **LT** / **RT** |
| Zeiger bewegen | Maus | Finger | linker Stick |
| Bauteil 1/2/3 | Tasten `1` `2` `3` | Knöpfe unten | Knöpfe unten |
| Abrissmodus | Taste `4` | Knopf „Abriss" | **X** |

**Warum bei Touch zwei Finger für die Kamera?** Ein Finger wird zum Bauen
gebraucht. Würde ein Finger auch die Kamera schieben, könnte das Spiel nie
sicher unterscheiden, ob jemand bauen oder schauen will.

---

## Welche Datei macht was

```
bridgelab/
├── default.project.json      Rojo-Bauplan: welche Datei landet wo in Studio
├── tools/
│   └── check_levels.luau     Prüfwerkzeug: sind die Level lösbar?
└── src/
    ├── Shared/               kennen Server UND Client
    │   ├── Config.luau       ALLE Einstellungen: Bauteile, Physik, Preise
    │   ├── Levels.luau       die sechs Level als reine Zahlen
    │   ├── Remotes.luau      legt die RemoteEvents an
    │   └── TrussSolver.luau  der Fachwerk-Rechner (reine Mathematik)
    │
    ├── Server/               läuft nur auf dem Server (nicht manipulierbar)
    │   ├── init.server.luau  Hauptskript: prüft alle Wünsche der Clients
    │   ├── Arena.luau        die Spielsitzung EINES Spielers
    │   ├── LevelBuilder.luau baut Plattformen, Schlucht, Pylone, Ankerpunkte
    │   ├── Structure.luau    verwaltet die gesetzten Bauteile
    │   ├── ForceEngine.luau  Bindeglied zum Fachwerk-Rechner
    │   ├── TestRun.luau      der Belastungstest mit dem Fahrzeug
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

### Die wichtigste Regel im Code

**Der Client schickt nur Wünsche, der Server entscheidet.** Ein manipulierter
Client kann höchstens unsinnige Anfragen stellen — ob ein Bauteil entsteht, ob
ein Tipp freigeschaltet wird und ob der Test bestanden ist, prüft immer der
Server. Jede Zahl, die hereinkommt, wird geprüft, bevor sie benutzt wird.

---

## Eigene Level bauen

In `src/Shared/Levels.luau` einen Eintrag kopieren und die Zahlen ändern. Die
Ankerpunkte entstehen automatisch.

### Zwei Fallen, die ein Level unlösbar machen

Beide sind mir beim Bauen selbst passiert — deshalb stehen sie hier:

1. **Die obere Reihe zu hoch ansetzen.** `upperY - deckY` darf höchstens 10
   Studs betragen (die maximale Balkenlänge). Sonst kommt man mit keinem Balken
   dorthin, und die Reihe ist nutzlos.

2. **Die Schlucht zu tief machen.** `deckY - groundY` darf höchstens 40 Studs
   betragen (die maximale Stützenlänge). Stützen vom Schluchtgrund sind der
   einzige Weg, senkrechte Last wirklich abzutragen. Ist der Grund unerreichbar,
   ist das Level nicht lösbar.

> **Warum ist das so?** Ein Fachwerk zwischen Fahrbahn und oberer Reihe wäre die
> Alternative — aber bei nur 8 Studs Bauhöhe entstehen in den Gurten Kräfte weit
> über 500 N, und der Balken bricht. Eine Hängebrücke funktioniert in diesem
> Modell ebenfalls nicht: Ein gerader Obergurt aus gelenkig gelagerten Stäben
> kann senkrechte Lasten nicht abtragen.

### Level prüfen, bevor du sie spielst

Im Ordner `tools/` liegt ein Prüfskript. Es baut mehrere Standard-Brückenformen,
lässt das Fahrzeug rechnerisch darüberfahren und meldet Kosten und höchste
Auslastung — ohne dass Roblox überhaupt laufen muss.

Dafür brauchst du das Luau-Programm von
<https://github.com/luau-lang/luau/releases> (Datei `luau-ubuntu.zip`,
`luau-windows.zip` bzw. `luau-macos.zip`). Dann:

```bash
cd tools
luau check_levels.luau
```

Ausgabe pro Level, zum Beispiel:

```
Level1   Budget 200   Luecke 40   Fahrbahn y=40  Boden y=20  oben y=48
   Stuetzen (8er Fahrbahn)   Kosten 110/200  max  89%  LOESUNG [Pillar]
   => LOESBAR ueber 'Stuetzen (8er Fahrbahn)' fuer 110 (45% Budget uebrig)
```

Wenn dort `NICHT LOESBAR` steht, schlägt das Skript ein passendes Budget vor.
Trägst du neue Level ein, musst du sie auch in der `LEVELS`-Tabelle **im
Prüfskript** ergänzen — es liest `Levels.luau` nicht selbst aus.

**Alle sechs mitgelieferten Level sind damit geprüft** und haben zwischen 18 %
und 45 % Budgetreserve gegenüber der günstigsten funktionierenden Lösung.

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
   passen die vorgegebenen Grenzwerte (500 / 300 / 800 N) direkt zur
   Fahrzeugmasse: ein einzelnes Bauteil kann das Fahrzeug nie allein tragen.
2. **Zwei getrennte Physiken.** Die Roblox-Engine ist nur fürs Aussehen
   zuständig (Durchbiegen, Einsturz). Ob ein Bauteil bricht, entscheidet
   ausschließlich der eigene Fachwerk-Rechner auf dem Server.
3. **Gelenkige Stäbe, kein Biegen.** Jedes Bauteil kann nur längs gezogen oder
   gedrückt werden. Deshalb trägt sich eine schnurgerade Fahrbahn nicht selbst —
   genau das ist die Rätselaufgabe.
4. **Reichweite geändert.** Seil und Stütze reichen jetzt 40 statt 26 Studs.
   Mit 26 waren vier der sechs Level nachweislich unlösbar.
5. **Fahrgeschwindigkeit 3,2 statt 8 Studs/s**, damit man die Belastungszahlen
   lesen kann. Die Zeitlimits sind entsprechend großzügig.
6. **Bauteile brechen erst nach 0,6 s Schonfrist**, sonst zerstört der Ruck
   beim Lösen der Verankerung sofort etwas.

### Spielaufbau

7. **Eine eigene Arena pro Spieler**, senkrecht gestapelt im Abstand von 500
   Studs. Nötig, weil jeder ein eigenes Level wählen darf.
8. **Keine Spielerfigur.** `CharacterAutoLoads` ist aus, die Kamera ist fest
   auf Seitenansicht gestellt.
9. **Der Bauplan überlebt den Test.** Bricht etwas, bleibt der Plan erhalten —
   „Zurücksetzen" stellt alles wieder her, ohne dass man neu bauen muss.
10. **Höchstens 16 Spieler gleichzeitig** in eigenen Arenen (`Config.Arena`).

### Tipps und Robux

11. **Drei Tipps pro Level**, von allgemein zu konkret. Der dritte nennt die
    Lösung mit Stückzahlen.
12. **Gratis-Regel an den Schwierigkeitsgrad gekoppelt:** Stufe 1–3 bekommt
    einen Gratis-Tipp, Stufe 4–5 keinen. Das setzt deine Vorgabe („bei den
    Anfangsleveln der erste gratis, bei den späteren nicht") in eine Regel um,
    die auch für neue Level automatisch gilt.
13. **Ein einziges Robux-Produkt** für alle Tipps statt eines pro Level.
14. **Jedes Level ist ohne Tipps lösbar.** Das steht auch so in der Anleitung.

### Oberfläche

15. **Ein gemeinsamer „Zeigepunkt"** für alle drei Eingabearten. Deshalb gibt
    es die Trefferlogik nur einmal.
16. **Zwei Finger für die Kamera** auf Touch (Begründung oben).
17. **Die Anleitung startet automatisch beim ersten Mal in Level 1** und ist
    danach über das Menü wieder erreichbar.
18. **Belastungszahlen als BillboardGui am Bauteil** — die überträgt Roblox von
    selbst zum Client, dafür braucht es kein eigenes RemoteEvent.
19. **Deutsche Texte ohne Umlaute im Spiel** (`ue` statt `ü`). Roblox-Schriften
    stellen Umlaute nicht überall zuverlässig dar. In dieser README stehen
    Umlaute normal.

---

## Bekannte Grenzen

Ehrlich gesagt, was noch fehlt oder wacklig ist:

- **Nicht in Roblox getestet.** Ich konnte den Code hier nicht in Studio
  ausführen. Geprüft ist: alle 20 Dateien kompilieren mit dem echten
  Luau-Compiler, und die Lösbarkeit aller Level wurde mit dem echten
  Fachwerk-Rechner nachgerechnet. Was das *nicht* abdeckt, sind Laufzeitfehler,
  die erst mit echten Roblox-Objekten auftreten — falsch platzierte Fenster,
  eine Kamera, die woanders steht als gedacht, ähnliches. Rechne damit, dass
  beim ersten Start noch Kleinigkeiten zu richten sind, und schick mir die
  Fehlermeldungen aus **VIEW → Output**.
- **Die Fußleiste kann auf sehr schmalen Bildschirmen eng werden.** Die Knöpfe
  skalieren mit, aber unter etwa 600 Pixel Breite wird es gedrängt.
- **Der Gamepad-Zeiger** ist selbstgebaut (ein Ring, den der linke Stick
  bewegt). Roblox bietet dafür nichts Fertiges, wenn es keine Spielfigur gibt.
- **Seile hängen nicht durch.** Ein schlaffes Seil wird weiterhin als gerade
  Linie gezeichnet. Echtes Durchhängen bräuchte mehrere Teilstücke pro Seil.
- **`allowedParts` ist eingebaut, aber ungenutzt.** Man kann damit einzelne
  Bauteile pro Level sperren. Ich habe es nicht verwendet, weil jedes Level
  ohne Stützen unlösbar wäre.
- **Keine Bestenliste, keine Sterne-Wertung, kein Level-Editor.**
