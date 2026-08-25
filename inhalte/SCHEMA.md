# Datenschema der Inhalte

Alle Lerninhalte stehen in diesem Verzeichnis als reine Daten. Wer Aufgaben oder
Lerneinheiten ergänzen will, braucht **keine Programmierkenntnisse** — es genügt,
die Muster unten zu kopieren und den Text zu ersetzen.

Die Dateien sind `.js`-Dateien statt `.json`, weil die App ohne Server direkt aus
dem Dateisystem laufen soll. Ein Browser darf beim Öffnen über `file://` keine
JSON-Dateien nachladen, ein `<script>` dagegen schon. Praktisch ändert das nur die
erste und letzte Zeile der Datei; dazwischen wird ganz normale Objektschreibweise
verwendet.

**Drei Regeln, die immer gelten:**

1. Texte stehen in einfachen Anführungszeichen: `'so'`. Kommt im Text selbst ein
   Apostroph vor, wird er verdoppelt geschrieben (`\'`) — einfacher ist es, das
   deutsche Anführungszeichen `„…"` zu benutzen.
2. Lange Texte werden mit `+` über mehrere Zeilen verteilt (siehe Beispiele).
3. Nach jedem Eintrag steht ein Komma, nach dem letzten in einer Liste keins.

---

## Formelnotation

Formeln stehen im Fließtext zwischen Dollarzeichen (`$v = s / t$`) oder als eigener
Baustein. Gesetzt werden sie von `js/formel.js`.

| Schreibweise | Ergebnis | Anmerkung |
|---|---|---|
| `v` | *v* | einzelne Buchstaben werden kursiv gesetzt |
| `v_0`, `v_ges` | *v*₀, *v*<sub>ges</sub> | Index |
| `t^2` | *t*² | Exponent |
| `s / t` | Bruch | alles vor dem `/` wird zum Zähler |
| `a * b` | *a* · *b* | Malpunkt |
| `"m/s"` | m/s | Anführungszeichen = **Einheit**, wird aufrecht gesetzt und nicht als Bruch gelesen |
| `Δx` | Δ*x* | Δ wird aufrecht, die Größe kursiv gesetzt |
| `sqrt(2*a*s)` | √(2·a·s) | Wurzel |
| `vec(F)` | F mit Pfeil | Vektorpfeil |
| `<=` `>=` `!=` `~=` | ≤ ≥ ≠ ≈ | Vergleichszeichen |

**Wichtig:** Einheiten immer in Anführungszeichen setzen. `50 km/h` würde sonst als
Bruch *km* durch *h* gesetzt; `50 "km/h"` ergibt korrekt 50 km/h mit schmalem
Abstand zwischen Zahlenwert und Einheit.

---

## Eine Lerneinheit

```js
{
  id: 'm2-le1',              // eindeutig, Muster: modul-le nummer
  modul: 'm2',
  titel: 'Wenn die Geschwindigkeit sich ändert',
  dauer: 12,                 // Minuten, sinnvoll zwischen 8 und 20
  kompetenzen: ['UF1', 'E5'],
  leitfrage: 'Eine Frage aus dem Kontext, die die Einheit eröffnet.',
  bausteine: [ /* siehe unten */ ]
}
```

### Bausteine

Die Bausteine werden in der angegebenen Reihenfolge dargestellt. Nach spätestens
zwei Textbausteinen sollte etwas zum Tun kommen — eine Zwischenfrage, eine
Simulation, ein Diagramm.

```js
{ typ: 'text', inhalt: 'Fließtext, HTML wie <b>fett</b> ist erlaubt, $v = s / t$ auch.' }

{ typ: 'merksatz', inhalt: 'Der Kernsatz der Einheit.' }

{ typ: 'formel',
  quelle: 'a = Δv / Δt',
  zeichen: [                                    // optional, aber empfohlen
    { z: 'a',  bedeutung: 'Beschleunigung', einheit: 'm/s²' },
    { z: 'Δv', bedeutung: 'Geschwindigkeitsänderung', einheit: 'm/s' }
  ],
  hinweis: 'Erklärender Satz unter der Formel.' }

{ typ: 'beispiel', titel: 'Vorgerechnetes Beispiel',
  schritte: [ { schritt: 'Gegeben', inhalt: '...' }, { schritt: 'Ergebnis', inhalt: '...' } ] }

{ typ: 'fehlvorstellung',
  behauptung: 'Der falsche Satz, wie Lernende ihn wirklich sagen.',
  pruefung:   'Ein Gegenbeispiel oder Experiment, das ihn erschüttert.',
  richtig:    'Die korrekte Fassung mit Begründung.' }

{ typ: 'experiment',
  frage: 'Untersuchungsfrage', aufbau: '...', messgroessen: '...',
  durchfuehrung: '...', auswertung: '...', fehlerquellen: '...',
  varianten: ['Was tun, wenn die Ausrüstung fehlt.'] }

{ typ: 'sprache',
  zeilen: [ { alltag: '„So sagt man."', fach: 'So ist es gemeint.' } ] }

{ typ: 'frage',                                  // Zwischenfrage, sofortige Rückmeldung
  text: 'Frage im Text.',
  optionen: [
    { text: 'richtige Antwort', richtig: true,  rueckmeldung: 'Warum sie stimmt.' },
    { text: 'typischer Fehler', richtig: false, rueckmeldung: 'Welcher Denkfehler dahintersteckt.' }
  ] }

{ typ: 'diagramm', spez: { /* siehe „Diagramme" */ } }

{ typ: 'tabelle', spez: { beschriftung: '...', spalten: ['x in m', 't in s'],
                          zeilen: [['0,20', '0,49']] } }

{ typ: 'simulation', name: 'bezugssystem',       // Namen: siehe js/simulation.js
  einleitung: 'Was man einstellen soll.',
  beobachte: ['Worauf zu achten ist.'] }
```

---

## Eine Aufgabe

Pflichtfelder sind `id`, `niveau`, `typ`, `kompetenz`, `afb`, `zeit`, `operator`,
`text`, `weg`, `hilfen` (genau drei) und `fehleranalyse`. Die Tests in `tests/`
prüfen das nach — eine Aufgabe ohne Lösungsweg oder ohne drei Hilfen lässt die
Testseite rot werden.

```js
{
  id: 'm2-a01',
  modul: 'm2',
  niveau: 'standard',          // basis | standard | vertiefung
  typ: 'rechnung',             // rechnung | mc | mehrfach | zuordnung | frei
  kompetenz: ['UF2', 'E5'],    // UF, E, K, B mit Ziffer
  afb: 2,                      // 1, 2 oder 3
  zeit: 6,                     // Minuten
  operator: 'Berechne',        // aus der Operatorenliste, passend zur Leistung
  kontext: 'Die Situation, aus der die Frage entsteht.',
  text: 'die eigentliche Aufgabenstellung.',
  gegeben: '$v = 12 "m/s"$',   // optional
  abbildung: { /* Diagramm-Spezifikation */ },   // optional
  tabelle:   { /* Tabellen-Spezifikation */ },   // optional

  loesung: { wert: 25, einheit: 'm/s', toleranz: 0.02 },   // nur bei typ 'rechnung'

  weg: [                       // mindestens drei Schritte
    { schritt: 'Gegeben',        inhalt: '...' },
    { schritt: 'Ansatz',         inhalt: '...' },
    { schritt: 'Ergebnis',       inhalt: '...' },
    { schritt: 'Plausibilität',  inhalt: 'Größenordnung, Vorzeichen, Einheit prüfen.' }
  ],
  nachtrag: 'Optionaler Hinweis nach dem Rechenweg.',

  hilfen: [                    // genau drei, in dieser Reihenfolge
    'Denkanstoß — eine Rückfrage, keine Lösung.',
    'Ansatz — welche Formel, welche Skizze.',
    'Erster Rechenschritt, vorgemacht.'
  ],

  fehleranalyse: [
    { wert: 324, einheit: 'm/s',
      ursache: 'Mit 3,6 multipliziert statt geteilt',
      hinweis: 'Wie man es merkt und richtig macht.' },
    { ursache: 'Fehler ohne festen Zahlenwert',   // wert weglassen
      hinweis: 'Erscheint dann nur in der Fehlerliste, wird nicht automatisch erkannt.' }
  ]
}
```

**Zur `toleranz`:** relativer Wert, `0.02` heißt ±2 %. Sie muss zum Kontext passen —
bei einer Ablesung aus dem Diagramm eher 0,05, bei einer exakten Umrechnung 0,02.

**Zu `fehleranalyse` mit `wert`:** Trägt ein Eintrag einen Zahlenwert, erkennt das
Programm genau diese falsche Antwort und nennt den Denkfehler beim Namen. Der Wert
muss außerhalb der Toleranz der richtigen Lösung liegen — sonst schlägt der Test
„Fehlerwert gilt nicht als richtig" fehl.

### Die übrigen Aufgabentypen

```js
typ: 'mc'          // genau eine richtige Option
optionen: [ { text: '...', richtig: true, rueckmeldung: '...' }, ... ]

typ: 'mehrfach'    // mehrere richtige Optionen
optionen: [ { text: '...', richtig: true, rueckmeldung: '...' }, ... ]

typ: 'zuordnung'
auswahl: ['Möglichkeit A', 'Möglichkeit B'],
paare: [ { frage: '...', loesung: 0, rueckmeldung: '...' } ]   // loesung = Position in auswahl

typ: 'frei'        // keine automatische Bewertung, nur Erwartungshorizont
erwartung: 'Einleitung zum Erwartungshorizont.'
// die Bausteine des Erwartungshorizonts stehen wie üblich in weg[]
```

**Bei jeder Option gilt:** Jeder Distraktor entspricht einer realen Fehlvorstellung
oder einem typischen Rechenfehler, und jede Option hat eine `rueckmeldung`, die den
Denkfehler benennt. Fülloptionen sind nicht vorgesehen — die Tests verlangen zu
jeder Option eine Rückmeldung.

---

## Diagramme

```js
{
  titel: 'Kurzer Titel',                    // für Vorlesegeräte
  beschreibung: 'Was zu sehen ist, physikalisch beschrieben — nicht „ein Diagramm".',
  breite: 620, hoehe: 300,
  xBereich: [0, 12], yBereich: [0, 110],
  xTitel: 't in s', yTitel: 'x in m',        // immer Größe und Einheit
  kurven: [
    { punkte: [[0, 20], [10, 95]], farbe: '#1f5f8b', name: 'Auto A' },
    { punkte: [[0, 0], [1, 2]], art: 'punkte', fehlerbalken: 0.012 }
  ],
  flaechen:        [ { punkte: [[0, 8], [10, 8]] } ],           // Fläche bis zur Zeitachse
  linien:          [ { von: [3, 44], bis: [13, 44], gestrichelt: true } ],
  beschriftungen:  [ { text: 'Δt = 10 s', bei: [8, 44], dy: 16, anker: 'middle' } ],
  unterschrift: 'Bildunterschrift unter dem Diagramm.'
}
```

Die `beschreibung` ist der Alternativtext. Sie soll das Gleiche vermitteln wie das
Bild — also den Verlauf und die Zahlenwerte nennen, nicht nur die Diagrammart.

---

## Ein neues Modul befüllen

1. In `inhalte/module.js` beim betreffenden Modul `gefuellt: false` auf `true` setzen.
2. Zwei Dateien anlegen, zum Beispiel `inhalte/m2-lerneinheiten.js` und
   `inhalte/m2-aufgaben.js`. Als Vorlage die entsprechenden M1-Dateien kopieren —
   Kopf und Fuß bleiben, nur `m1` durch `m2` ersetzen.
3. Beide Dateien in `index.html` und in `tests/test.html` als `<script>` eintragen,
   **vor** `js/app.js` beziehungsweise vor `tests.js`.
4. `tests/test.html` im Browser öffnen. Erst wenn alles grün ist, ist das Modul fertig.
