# Physik EF — Mechanik

Ein Lernprogramm zum Inhaltsfeld Mechanik der Einführungsphase (gymnasiale
Oberstufe, Nordrhein-Westfalen). Aufgaben auf drei Niveaustufen, die oberste als
Vorbereitung auf den Physik-Leistungskurs in Q1/Q2.

## Starten

`index.html` im Browser öffnen. Es wird kein Server, kein Build-Schritt und keine
Internetverbindung benötigt; die App läuft vollständig aus dem Dateisystem.

## Was drin ist

**Modul M1 „Bewegungen beschreiben" ist vollständig ausgearbeitet:**

- sieben Lerneinheiten zu je 12–15 Minuten — Bezugssystem, Strecke und
  Verschiebung, mittlere Geschwindigkeit, gleichförmige Bewegung im
  Zeit-Ort-Diagramm, Momentangeschwindigkeit, Zeit-Geschwindigkeit-Diagramm,
  Auswertung einer Messreihe
- 18 Aufgaben über die Stufen Basis, Standard und LK-Vertiefung, darunter eine
  dreiteilige Aufgabe im Klausurformat
- zwei interaktive Simulationen: Bezugssystemwechsel zwischen zwei Fahrzeugen und
  der Grenzübergang von der Sekante zur Tangente
- ein mit Schulmitteln durchführbares Experiment samt Varianten ohne Ausrüstung
- vier ausdrücklich behandelte Fehlvorstellungen

**Die Module M2 bis M8 sind angelegt, aber leer.** Ihre Gliederung und die
Kerninhalte stehen in `inhalte/module.js`; im Programm sind sie als „noch nicht
befüllt" gekennzeichnet. M1 dient als Vorlage.

## Aufbau

```
index.html              Einstieg, lädt alle Skripte in fester Reihenfolge
css/stil.css            Gestaltung, helles und dunkles Farbschema
js/formel.js            Mini-Notation für Formeln → HTML
js/einheiten.js         Zahl-und-Einheit-Eingaben lesen, umrechnen, vergleichen
js/diagramm.js          Diagramme als SVG, im Programm erzeugt
js/simulation.js        interaktive Darstellungen
js/aufgaben.js          Aufgaben darstellen und Antworten prüfen
js/fortschritt.js       Lernstand lokal halten
js/app.js               Navigation und Seitenaufbau
inhalte/                die eigentlichen Lerninhalte als Daten
inhalte/SCHEMA.md       wie Inhalte geschrieben werden — ohne Programmierkenntnisse
tests/test.html         Testseite, im Browser zu öffnen
```

Inhalt und Programm sind getrennt: Neue Lerneinheiten und Aufgaben entstehen
ausschließlich in `inhalte/`, ohne dass am Code etwas geändert werden muss.
Wie das geht, steht in [`inhalte/SCHEMA.md`](inhalte/SCHEMA.md).

## Tests

`tests/test.html` im Browser öffnen. Geprüft werden der Formelsetzer, die
Einheitenerkennung, die Antwortprüfung, die Fortschrittslogik und die
Inhaltsdaten selbst — unter anderem, ob jede Aufgabe einen Lösungsweg, drei
gestufte Hilfen, eine Fehleranalyse und vollständige Metadaten hat und ob die
hinterlegten Falschantworten tatsächlich als falsch gewertet werden.

Stand: **378 Prüfungen, alle bestanden.**

Die Fachinhalte werden nicht automatisch getestet — sie brauchen ein fachliches
Gegenlesen.

## Datenschutz

Der Lernstand liegt ausschließlich im `localStorage` des Browsers. Es gibt kein
Konto, keine Anmeldung, keine Analysewerkzeuge und keine Übertragung an einen
Server. Gespeichert werden nur Aufgabenkennungen, Versuchszahlen und Zeitstempel —
keine Namen, keine Texte, keine Antworten im Wortlaut. Über die Seite „Lernstand"
lässt sich alles als Datei sichern, wieder einlesen und vollständig löschen.

Lässt der Browser das Speichern nicht zu (privates Fenster, gesperrte
Website-Daten), läuft das Programm vollständig weiter; der Lernstand geht dann
beim Schließen des Tabs verloren, worauf die Startseite hinweist.

## Offene Punkte

- **Der Modulplan ist noch nicht gegen den geltenden Kernlehrplan abgeglichen.**
  Die Gliederung des Inhaltsfelds Mechanik ist fachlich begründet aufgebaut; der
  Abgleich mit dem Lehrplannavigator NRW und dem schulinternen Lehrplan steht
  aus. Betroffen sind vor allem Reihenfolge und Schnitt zwischen M6, M7 und M8.
- Die Fachinhalte von M1 sind ungeprüft und sollten vor dem Unterrichtseinsatz
  von einer Lehrkraft gegengelesen werden.
- M2 bis M8 fehlen.
