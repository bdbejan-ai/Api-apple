/* m1-aufgaben.js — Aufgaben zu M1 „Bewegungen beschreiben".
 * Jede Aufgabe trägt: Lösungsweg (weg), drei gestufte Hilfen (hilfen),
 * Fehleranalyse (fehleranalyse) und Metadaten (niveau, kompetenz, afb, zeit).
 * Schema: siehe inhalte/SCHEMA.md */
window.Physik = window.Physik || {};
Physik.Inhalt = Physik.Inhalt || { module: [], lerneinheiten: {}, aufgaben: {} };

Physik.Inhalt.aufgaben.m1 = [

/* ------------------------------------------------------------ BASIS */
{
  id: 'm1-a01', modul: 'm1', niveau: 'basis', typ: 'rechnung',
  kompetenz: ['UF2'], afb: 1, zeit: 3,
  operator: 'Berechne',
  kontext: 'Auf Landstraßen sind außerorts 100 km/h erlaubt, auf vielen Strecken gilt Tempo 90.',
  text: 'die Geschwindigkeit 90 km/h in der Einheit m/s.',
  loesung: { wert: 25, einheit: 'm/s', toleranz: 0.02 },
  weg: [
    { schritt: 'Gegeben', inhalt: '$v = 90 "km/h"$' },
    { schritt: 'Gesucht', inhalt: '$v$ in $"m/s"$' },
    { schritt: 'Ansatz', inhalt: 'Ein Kilometer sind 1000 m, eine Stunde 3600 s. Der Umrechnungsfaktor ' +
      'ist damit $1000 / 3600 = 1 / 3,6$. Von km/h nach m/s wird geteilt.' },
    { schritt: 'Einsetzen', inhalt: '$v = 90 / 3,6 "m/s"$' },
    { schritt: 'Ergebnis', inhalt: '$v = 25 "m/s"$' },
    { schritt: 'Plausibilität', inhalt: '25 Meter in jeder Sekunde — bei 90 km/h legt man in einer ' +
      'Sekunde etwa eine halbe Fußballfeldbreite zurück. Der Wert muss kleiner sein als die Zahl in km/h.' }
  ],
  hilfen: [
    'In welcher Einheit ist die Zahl größer — in km/h oder in m/s? Überlege an einem bekannten Wert: ' +
    '36 km/h sind 10 m/s.',
    'Nutze $1 "km/h" = 1 / 3,6 "m/s"$. Von km/h nach m/s wird also durch 3,6 geteilt.',
    'Setze ein: $v = 90 / 3,6 "m/s"$. Rechne den Bruch aus.'
  ],
  fehleranalyse: [
    { wert: 324, einheit: 'm/s', ursache: 'Mit 3,6 multipliziert statt geteilt',
      hinweis: 'Die Richtung stimmt nicht: 324 m/s wären über 1000 km/h. Prüfe am Merkwert ' +
        '$36 "km/h" = 10 "m/s"$ — die Zahl muss <b>kleiner</b> werden.' },
    { wert: 1.5, einheit: 'm/s', ursache: 'Nur durch 60 geteilt',
      hinweis: 'Es müssen zwei Umrechnungen zusammenwirken: Kilometer in Meter <em>und</em> Stunden in ' +
        'Sekunden. Beides zusammen ergibt den Faktor 3,6.' }
  ]
},

{
  id: 'm1-a02', modul: 'm1', niveau: 'basis', typ: 'mc',
  kompetenz: ['UF1'], afb: 1, zeit: 2,
  operator: 'Erkläre',
  text: 'was die Aussage „Das Auto fährt mit 30 m/s" physikalisch vollständig bedeuten müsste.',
  optionen: [
    { text: 'Das Auto bewegt sich mit 30 m/s <em>relativ zur Straße</em>.', richtig: true,
      rueckmeldung: 'Genau. Jede Geschwindigkeitsangabe braucht ein Bezugssystem. Im Alltag ist die ' +
        'Straße gemeint und wird deshalb weggelassen — in der Physik gehört sie dazu.' },
    { text: 'Das Auto bewegt sich mit 30 m/s, das ist eine Eigenschaft des Autos.', richtig: false,
      rueckmeldung: 'Geschwindigkeit ist keine Eigenschaft eines Körpers wie seine Masse. Für einen ' +
        'Beifahrer ruht dasselbe Auto.' },
    { text: 'Das Auto legt in jeder Stunde 30 Meter zurück.', richtig: false,
      rueckmeldung: 'Lies die Einheit genau: Meter pro <em>Sekunde</em>. In einer Stunde wären es ' +
        '108 Kilometer.' },
    { text: 'Das Auto hat einen Tachostand von 30.', richtig: false,
      rueckmeldung: 'Der Tacho zeigt in Deutschland km/h an, nicht m/s — 30 m/s entsprächen dort 108.' }
  ],
  weg: [
    { schritt: 'Frage klären', inhalt: 'Gefragt ist nicht der Zahlenwert, sondern was zu einer ' +
      'vollständigen physikalischen Aussage gehört.' },
    { schritt: 'Fehlende Angabe', inhalt: 'Jede Geschwindigkeit ist eine Aussage über zwei Körper. ' +
      'Ohne Bezugssystem bleibt offen, worauf sich die 30 m/s beziehen.' },
    { schritt: 'Gegenprobe', inhalt: 'Für einen Beifahrer ruht dasselbe Auto — seine Geschwindigkeit ' +
      'relativ zum Beifahrer ist null. Beide Angaben beschreiben dieselbe Situation richtig.' },
    { schritt: 'Vollständige Aussage', inhalt: '„Das Auto bewegt sich mit 30 m/s <b>relativ zur ' +
      'Straße</b>." Im Alltag wird der Zusatz weggelassen, weil er selbstverständlich scheint — in der ' +
      'Physik gehört er dazu.' }
  ],
  hilfen: [
    'Könnte jemand, der dieselbe Situation beobachtet, zu einem anderen Zahlenwert kommen? Wer?',
    'Denk an den Beifahrer im selben Auto. Welche Geschwindigkeit hat das Auto für ihn?',
    'Wenn zwei Beobachter verschiedene Werte nennen und beide recht haben — welche Angabe fehlt dann ' +
    'in der ursprünglichen Aussage?'
  ],
  fehleranalyse: [
    { ursache: 'Geschwindigkeit wird als Eigenschaft des Körpers verstanden',
      hinweis: 'Anders als die Masse ist die Geschwindigkeit keine Eigenschaft eines Körpers, sondern ' +
        'eine Beziehung zwischen zwei Körpern. Sie ändert sich mit dem Bezugssystem, ohne dass am Auto ' +
        'etwas geschieht.' },
    { ursache: 'Einheit überlesen',
      hinweis: 'm/s und km/h unterscheiden sich um den Faktor 3,6. Lies bei jeder Angabe die Einheit ' +
        'mit, bevor du die Größenordnung einschätzt.' }
  ]
},

{
  id: 'm1-a03', modul: 'm1', niveau: 'basis', typ: 'rechnung',
  kompetenz: ['UF2'], afb: 1, zeit: 4,
  operator: 'Berechne',
  kontext: 'Der deutsche Rekord über 400 Meter der Männer liegt bei etwa 44 s. Eine Schülerin läuft ' +
    'die Stadionrunde in 52 s.',
  text: 'die mittlere Geschwindigkeit der Schülerin in m/s.',
  gegeben: '$s = 400 "m"$, $Δt = 52 "s"$',
  loesung: { wert: 7.69, einheit: 'm/s', toleranz: 0.02 },
  weg: [
    { schritt: 'Gegeben', inhalt: '$s = 400 "m"$, $Δt = 52 "s"$' },
    { schritt: 'Gesucht', inhalt: '$v_mittel$ in $"m/s"$' },
    { schritt: 'Ansatz', inhalt: '$v_mittel = s / Δt$ — hier ist nach der Bahngeschwindigkeit gefragt, ' +
      'also nach der zurückgelegten Strecke geteilt durch die Zeit.' },
    { schritt: 'Einsetzen', inhalt: '$v_mittel = 400 "m" / 52 "s"$' },
    { schritt: 'Ergebnis', inhalt: '$v_mittel ≈ 7,7 "m/s"$' },
    { schritt: 'Plausibilität', inhalt: '7,7 m/s sind rund 28 km/h — schnell für eine Schülerin, aber ' +
      'für eine Stadionrunde realistisch. Ein Wert von 0,13 m/s wäre Schrittgeschwindigkeit einer Schnecke.' }
  ],
  nachtrag: 'Beachte: Weil der Lauf auf einer geschlossenen Runde endet, ist die <em>Verschiebung</em> ' +
    'null. Gefragt war hier die Bahngeschwindigkeit über die zurückgelegte Strecke — bei Rundkursen ' +
    'muss man das auseinanderhalten.',
  hilfen: [
    'Welche zwei Größen sind gegeben, und welche Formel verbindet Weg, Zeit und Geschwindigkeit?',
    'Nutze $v = s / Δt$. Setze die Strecke in Metern und die Zeit in Sekunden ein — dann kommt die ' +
    'Einheit m/s von selbst heraus.',
    'Rechne $400 / 52$. Das Ergebnis liegt zwischen 7 und 8.'
  ],
  fehleranalyse: [
    { wert: 0.13, einheit: 'm/s', ursache: 'Bruch umgedreht: Zeit durch Strecke gerechnet',
      hinweis: 'Der Einheitentest hilft: $"s" / "m"$ ergäbe Sekunden pro Meter, nicht Meter pro Sekunde. ' +
        'Schreibe die Einheiten immer mit.' },
    { wert: 27.7, einheit: 'm/s', ursache: 'Ergebnis in km/h berechnet, aber als m/s beschriftet',
      hinweis: '27,7 ist der Wert in km/h. Gefragt war m/s — teile den km/h-Wert durch 3,6.' }
  ]
},

{
  id: 'm1-a04', modul: 'm1', niveau: 'basis', typ: 'mc',
  kompetenz: ['UF1', 'E5'], afb: 1, zeit: 3,
  operator: 'Gib an',
  text: 'was eine <em>waagerechte Gerade</em> im Zeit-Ort-Diagramm über die Bewegung aussagt.',
  optionen: [
    { text: 'Der Körper ruht im gewählten Bezugssystem.', richtig: true,
      rueckmeldung: 'Richtig: Der Ort ändert sich nicht, also ist $Δx = 0$ und damit $v = 0$.' },
    { text: 'Der Körper bewegt sich mit konstanter Geschwindigkeit.', richtig: false,
      rueckmeldung: 'Das gilt für eine waagerechte Gerade im <em>Zeit-Geschwindigkeit</em>-Diagramm. ' +
        'Im Zeit-Ort-Diagramm ist konstante Geschwindigkeit eine <em>schräge</em> Gerade.' },
    { text: 'Der Körper fährt auf ebener Strecke.', richtig: false,
      rueckmeldung: 'Das Diagramm zeigt keine Landschaft. Auf der senkrechten Achse steht der Ort ' +
        'entlang der Fahrtrichtung, nicht die Höhe über dem Boden.' },
    { text: 'Der Körper bewegt sich rückwärts.', richtig: false,
      rueckmeldung: 'Rückwärts wäre eine <em>fallende</em> Gerade, also negative Steigung.' }
  ],
  weg: [
    { schritt: 'Achsen lesen', inhalt: 'Erster Schritt bei jedem Diagramm: Auf der senkrechten Achse ' +
      'steht der <b>Ort</b> $x$ in Metern, auf der waagerechten die Zeit $t$ in Sekunden.' },
    { schritt: 'Verlauf deuten', inhalt: 'Waagerecht heißt: Der Wert auf der senkrechten Achse ändert ' +
      'sich nicht. Der Ort bleibt also gleich, es gilt $Δx = 0$.' },
    { schritt: 'Folgerung', inhalt: 'Aus $v = Δx / Δt$ mit $Δx = 0$ folgt $v = 0$ — der Körper ruht ' +
      'im gewählten Bezugssystem.' },
    { schritt: 'Abgrenzung', inhalt: 'Im Zeit-Geschwindigkeit-Diagramm bedeutet dieselbe waagerechte ' +
      'Linie das Gegenteil: konstante Geschwindigkeit, also gleichförmige Fahrt. Die Form allein ' +
      'entscheidet nie, erst die Achsenbeschriftung.' }
  ],
  hilfen: [
    'Welche Größe steht bei diesem Diagramm auf der senkrechten Achse?',
    'Wenn die Linie waagerecht verläuft: Wie stark ändert sich der Ort in dieser Zeit?',
    'Setze $Δx = 0$ in $v = Δx / Δt$ ein.'
  ],
  fehleranalyse: [
    { ursache: 'Waagerechte Linie als „konstante Geschwindigkeit" gedeutet',
      hinweis: 'Das gilt im Zeit-<em>Geschwindigkeit</em>-Diagramm. Die beiden Diagrammarten sehen ' +
        'ähnlich aus und bedeuten Verschiedenes — deshalb immer zuerst die senkrechte Achse lesen.' },
    { ursache: 'Diagramm als Bild der Strecke gelesen („ebene Straße")',
      hinweis: 'Auf der senkrechten Achse steht der Ort entlang der Fahrtrichtung, nicht die Höhe. ' +
        'Ein Zeit-Ort-Diagramm zeigt keine Landschaft.' }
  ]
},

{
  id: 'm1-a05', modul: 'm1', niveau: 'basis', typ: 'rechnung',
  kompetenz: ['UF2'], afb: 1, zeit: 4,
  operator: 'Bestimme',
  kontext: 'Ein Linienbus fährt zwischen zwei Haltestellen gleichförmig mit 12 m/s. Die Haltestellen ' +
    'liegen 3,6 km auseinander.',
  text: 'die Fahrzeit zwischen den Haltestellen in Minuten.',
  gegeben: '$v = 12 "m/s"$, $s = 3,6 "km"$',
  loesung: { wert: 5, einheit: 'min', toleranz: 0.03 },
  weg: [
    { schritt: 'Gegeben', inhalt: '$v = 12 "m/s"$, $s = 3,6 "km" = 3600 "m"$' },
    { schritt: 'Gesucht', inhalt: '$Δt$ in Minuten' },
    { schritt: 'Ansatz', inhalt: 'Aus $v = s / Δt$ folgt durch Umstellen $Δt = s / v$.' },
    { schritt: 'Umrechnen', inhalt: 'Erst die Einheiten angleichen: $3,6 "km" = 3600 "m"$, damit passt ' +
      'die Länge zur Geschwindigkeit in m/s.' },
    { schritt: 'Einsetzen', inhalt: '$Δt = 3600 "m" / 12 "m/s" = 300 "s"$' },
    { schritt: 'Ergebnis', inhalt: '$Δt = 300 "s" = 5,0 "min"$' },
    { schritt: 'Plausibilität', inhalt: '12 m/s sind rund 43 km/h — für 3,6 km innerorts sind fünf ' +
      'Minuten ein realistischer Wert.' }
  ],
  hilfen: [
    'Passen die Einheiten von Weg und Geschwindigkeit zusammen? Eine Größe steht in Kilometern, die ' +
    'andere in Metern pro Sekunde.',
    'Stelle $v = s / Δt$ nach $Δt$ um und rechne die Strecke vorher in Meter um.',
    '$Δt = 3600 "m" / 12 "m/s"$. Beachte am Ende, dass nach Minuten gefragt ist.'
  ],
  fehleranalyse: [
    { wert: 300, einheit: 'min', ursache: 'Ergebnis in Sekunden, aber als Minuten angegeben',
      hinweis: 'Der Zahlenwert 300 gehört zu Sekunden. Für Minuten noch durch 60 teilen: 5,0 min.' },
    { wert: 0.3, einheit: 's', ursache: 'Ohne Umrechnung von km in m gerechnet',
      hinweis: '$3,6 / 12$ mischt Kilometer mit Metern pro Sekunde. Rechne die Strecke zuerst in Meter um.' },
    { wert: 43200, einheit: 's', ursache: 'Statt zu teilen multipliziert',
      hinweis: 'Prüfe die Einheiten: $"m" * "m/s"$ ergibt keine Zeit. Nur $"m" / ("m/s") = "s"$ passt.' }
  ]
},

/* ------------------------------------------------------------ STANDARD */
{
  id: 'm1-a06', modul: 'm1', niveau: 'standard', typ: 'rechnung',
  kompetenz: ['UF2', 'E5'], afb: 2, zeit: 6,
  operator: 'Ermittle',
  kontext: 'Das Diagramm zeigt die Fahrt eines Radfahrers auf einem geraden Radweg.',
  text: 'die Geschwindigkeit des Radfahrers aus dem Diagramm.',
  abbildung: {
    titel: 'Zeit-Ort-Diagramm einer Radfahrt',
    beschreibung: 'Eine Gerade beginnt bei 20 Metern zum Zeitpunkt null und erreicht nach 10 Sekunden ' +
      '95 Meter.',
    breite: 620, hoehe: 300,
    xBereich: [0, 12], yBereich: [0, 110],
    xTitel: 't in s', yTitel: 'x in m',
    kurven: [{ punkte: [[0, 20], [10, 95]], farbe: '#1f5f8b' }],
    unterschrift: 'Achte auf den Startwert: Die Gerade beginnt nicht im Ursprung.'
  },
  loesung: { wert: 7.5, einheit: 'm/s', toleranz: 0.05 },
  weg: [
    { schritt: 'Ablesen', inhalt: 'Zwei gut ablesbare Punkte wählen: bei $t_1 = 0 "s"$ ist ' +
      '$x_1 = 20 "m"$, bei $t_2 = 10 "s"$ ist $x_2 = 95 "m"$.' },
    { schritt: 'Ansatz', inhalt: 'Die Geschwindigkeit ist die Steigung: $v = Δx / Δt$.' },
    { schritt: 'Einsetzen', inhalt: '$v = (95 "m" - 20 "m") / (10 "s" - 0 "s") = 75 "m" / 10 "s"$' },
    { schritt: 'Ergebnis', inhalt: '$v = 7,5 "m/s"$' },
    { schritt: 'Plausibilität', inhalt: '7,5 m/s sind 27 km/h — ein zügiges, aber übliches Radfahrtempo.' }
  ],
  nachtrag: 'Der Startort $x_0 = 20 "m"$ geht in die Geschwindigkeit <em>nicht</em> ein. Er sagt nur, ' +
    'wo der Radfahrer beim Start der Zeitmessung war — zum Beispiel, weil die Messung erst 20 m nach ' +
    'einer Markierung begann.',
  hilfen: [
    'Die Gerade startet nicht bei null. Spielt das für die Steigung überhaupt eine Rolle?',
    'Die Steigung ist $Δx / Δt$ — die <em>Änderung</em> des Ortes, nicht der abgelesene Ort selbst. ' +
    'Bilde die Differenz aus zwei Punkten.',
    'Bei $t = 0 "s"$ ist $x = 20 "m"$, bei $t = 10 "s"$ ist $x = 95 "m"$. Rechne ' +
    '$(95 - 20) / 10$.'
  ],
  fehleranalyse: [
    { wert: 9.5, einheit: 'm/s', ursache: 'Ort durch Zeit gerechnet, statt die Differenz zu bilden',
      hinweis: '$95 "m" / 10 "s"$ unterstellt, dass die Fahrt bei $x = 0$ begann. Die Gerade startet ' +
        'aber bei 20 m — für die Steigung zählt nur die <b>Änderung</b> $Δx$.' },
    { wert: 11.5, einheit: 'm/s', ursache: 'Startort addiert statt subtrahiert',
      hinweis: 'Es gilt $Δx = x_2 - x_1$, immer Ende minus Anfang.' }
  ]
},

{
  id: 'm1-a07', modul: 'm1', niveau: 'standard', typ: 'rechnung',
  kompetenz: ['UF4', 'E5'], afb: 2, zeit: 7,
  operator: 'Berechne',
  kontext: 'Eine Pendlerin fährt morgens 20 km zur Arbeit und nimmt abends dieselbe Strecke zurück. ' +
    'Morgens ist die Straße frei, sie kommt auf 80 km/h. Abends steht sie im Berufsverkehr und schafft ' +
    'nur 40 km/h.',
  text: 'ihre mittlere Geschwindigkeit für die gesamte Fahrt (Hin- und Rückweg) in km/h.',
  gegeben: 'je Richtung $s = 20 "km"$; $v_hin = 80 "km/h"$, $v_zurueck = 40 "km/h"$',
  loesung: { wert: 53.3, einheit: 'km/h', toleranz: 0.03 },
  weg: [
    { schritt: 'Gesucht', inhalt: '$v_mittel$ für die Gesamtfahrt' },
    { schritt: 'Ansatz', inhalt: 'Die mittlere Geschwindigkeit ist <b>Gesamtstrecke durch Gesamtzeit</b> ' +
      '— nicht der Mittelwert der beiden Geschwindigkeiten. Also müssen zuerst die beiden Fahrzeiten ' +
      'einzeln bestimmt werden.' },
    { schritt: 'Teilzeiten', inhalt: '$Δt_hin = 20 "km" / 80 "km/h" = 0,25 "h"$ und ' +
      '$Δt_zurueck = 20 "km" / 40 "km/h" = 0,50 "h"$' },
    { schritt: 'Summieren', inhalt: 'Gesamtstrecke $s = 40 "km"$, Gesamtzeit $Δt = 0,75 "h"$' },
    { schritt: 'Einsetzen', inhalt: '$v_mittel = 40 "km" / 0,75 "h"$' },
    { schritt: 'Ergebnis', inhalt: '$v_mittel ≈ 53,3 "km/h"$' },
    { schritt: 'Plausibilität', inhalt: 'Das Ergebnis liegt näher bei 40 als bei 80 km/h — richtig so: ' +
      'Im langsamen Abschnitt verbringt sie doppelt so viel Zeit, er wiegt deshalb schwerer.' }
  ],
  hilfen: [
    'Wie lange ist sie morgens unterwegs, wie lange abends? Sind die beiden Zeiten gleich lang?',
    'Berechne beide Fahrzeiten getrennt und addiere sie. Die mittlere Geschwindigkeit ist dann ' +
    'Gesamtstrecke geteilt durch Gesamtzeit.',
    '$Δt_hin = 20 / 80 = 0,25 "h"$, $Δt_zurueck = 20 / 40 = 0,50 "h"$. Nun ' +
    '$v_mittel = 40 "km" / 0,75 "h"$.'
  ],
  fehleranalyse: [
    { wert: 60, einheit: 'km/h', ursache: 'Mittelwert der beiden Geschwindigkeiten gebildet',
      hinweis: 'Das wäre nur richtig, wenn beide Abschnitte gleich lange <em>dauerten</em>. Hier sind ' +
        'die <em>Strecken</em> gleich lang, die Zeiten nicht — der langsame Abschnitt dauert doppelt ' +
        'so lange und zählt deshalb doppelt.' },
    { wert: 26.7, einheit: 'km/h', ursache: 'Nur eine Richtung als Strecke gerechnet',
      hinweis: 'Zur Gesamtzeit von 0,75 h gehört auch die Gesamtstrecke von 40 km, nicht 20 km.' }
  ]
},

{
  id: 'm1-a08', modul: 'm1', niveau: 'standard', typ: 'zuordnung',
  kompetenz: ['E5', 'K3'], afb: 2, zeit: 6,
  operator: 'Ordne zu',
  kontext: 'Vier Bewegungen sollen im Zeit-Ort-Diagramm beschrieben werden.',
  text: 'welcher Verlauf im Zeit-Ort-Diagramm zu welcher Beschreibung gehört.',
  auswahl: [
    'steigende Gerade, flach',
    'steigende Gerade, steil',
    'waagerechte Gerade',
    'fallende Gerade'
  ],
  paare: [
    { frage: 'Ein Fußgänger geht gleichmäßig vorwärts.', loesung: 0,
      rueckmeldung: 'Vorwärts heißt steigend; „langsam" heißt flach. Ein Fußgänger ist deutlich ' +
        'langsamer als ein Radfahrer.' },
    { frage: 'Ein Radfahrer fährt gleichmäßig in dieselbe Richtung.', loesung: 1,
      rueckmeldung: 'Gleiche Richtung, aber größere Geschwindigkeit — also dieselbe Neigung, nur steiler.' },
    { frage: 'Ein Auto steht an der roten Ampel.', loesung: 2,
      rueckmeldung: 'Der Ort ändert sich nicht: waagerecht. Nicht zu verwechseln mit der waagerechten ' +
        'Linie im Zeit-Geschwindigkeit-Diagramm, die gleichförmige Fahrt bedeutet.' },
    { frage: 'Ein Zug fährt zurück in Richtung Startbahnhof.', loesung: 3,
      rueckmeldung: 'Bewegung entgegen der positiven Richtung: Der Ortswert nimmt ab, die Gerade fällt.' }
  ],
  bestaetigung: 'Damit hast du die vier Grundfälle beisammen — steigend, flach oder steil, waagerecht ' +
    'und fallend. Fast jedes Zeit-Ort-Diagramm der EF setzt sich aus diesen Bausteinen zusammen.',
  weg: [
    { schritt: 'Regel', inhalt: 'Die <b>Steigung</b> im Zeit-Ort-Diagramm ist die Geschwindigkeit.' },
    { schritt: 'Richtung', inhalt: 'Steigend heißt Bewegung in die positive Richtung, fallend entgegen ' +
      'der positiven Richtung, waagerecht heißt Ruhe.' },
    { schritt: 'Betrag', inhalt: 'Je steiler die Gerade, desto größer der Betrag der Geschwindigkeit.' }
  ],
  hilfen: [
    'Frage dich bei jeder Beschreibung zuerst: Ändert sich der Ort überhaupt? Und wenn ja, in welche Richtung?',
    'Steigend, waagerecht oder fallend klärt die Richtung. Erst danach entscheidet die Steilheit über ' +
    'schnell oder langsam.',
    'Fußgänger und Radfahrer fahren beide vorwärts — sie unterscheiden sich nur in der Steilheit.'
  ],
  fehleranalyse: [
    { ursache: 'Waagerechte Gerade als „konstante Geschwindigkeit" gedeutet',
      hinweis: 'Das gilt nur im Zeit-Geschwindigkeit-Diagramm. Lies immer zuerst die senkrechte Achse.' }
  ]
},

{
  id: 'm1-a09', modul: 'm1', niveau: 'standard', typ: 'rechnung',
  kompetenz: ['UF2', 'E5'], afb: 2, zeit: 6,
  operator: 'Bestimme',
  kontext: 'Das Zeit-Geschwindigkeit-Diagramm zeigt eine Fahrt mit einem Halt an einer Ampel.',
  text: 'die insgesamt zurückgelegte Strecke.',
  abbildung: {
    titel: 'Zeit-Geschwindigkeit-Diagramm einer Fahrt mit Halt',
    beschreibung: 'Die Geschwindigkeit beträgt 8 Meter pro Sekunde bis 10 Sekunden, ist dann bis ' +
      '15 Sekunden null und beträgt danach bis 25 Sekunden 12 Meter pro Sekunde.',
    breite: 620, hoehe: 300,
    xBereich: [0, 27], yBereich: [0, 15],
    xTitel: 't in s', yTitel: 'v in m/s',
    kurven: [{ punkte: [[0, 8], [10, 8], [10, 0], [15, 0], [15, 12], [25, 12]], farbe: '#1f5f8b' }],
    flaechen: [
      { punkte: [[0, 8], [10, 8]], farbe: '#1f5f8b' },
      { punkte: [[15, 12], [25, 12]], farbe: '#1f5f8b' }
    ],
    unterschrift: 'Die Fläche zwischen Kurve und Zeitachse entspricht der zurückgelegten Strecke.'
  },
  loesung: { wert: 200, einheit: 'm', toleranz: 0.03 },
  weg: [
    { schritt: 'Ansatz', inhalt: 'Im Zeit-Geschwindigkeit-Diagramm entspricht die Fläche unter der ' +
      'Kurve der zurückgelegten Strecke. Der Verlauf besteht aus zwei Rechtecken.' },
    { schritt: 'Erster Abschnitt', inhalt: '$s_1 = 8 "m/s" * 10 "s" = 80 "m"$' },
    { schritt: 'Halt', inhalt: 'Zwischen 10 s und 15 s ist $v = 0$, die Fläche ist null: $s_2 = 0 "m"$.' },
    { schritt: 'Dritter Abschnitt', inhalt: '$s_3 = 12 "m/s" * 10 "s" = 120 "m"$' },
    { schritt: 'Ergebnis', inhalt: '$s = 80 "m" + 0 "m" + 120 "m" = 200 "m"$' },
    { schritt: 'Plausibilität', inhalt: 'Die Einheitenprobe bestätigt den Ansatz: ' +
      '$"m/s" * "s" = "m"$ — heraus kommt eine Länge.' }
  ],
  hilfen: [
    'Auf der senkrechten Achse steht die Geschwindigkeit. Wo im Diagramm steckt dann der Weg?',
    'Die Fläche zwischen Kurve und Zeitachse ist die zurückgelegte Strecke. Zerlege sie in Rechtecke.',
    'Erstes Rechteck: 8 m/s mal 10 s. Drittes Rechteck: 12 m/s mal 10 s (von 15 s bis 25 s).'
  ],
  fehleranalyse: [
    { wert: 500, einheit: 'm', ursache: 'Geschwindigkeiten addiert und mit der Gesamtzeit multipliziert',
      hinweis: '$(8 + 12) * 25$ behandelt beide Geschwindigkeiten so, als hätten sie während der ganzen ' +
        'Fahrt gegolten. Jede gilt aber nur in ihrem eigenen Abschnitt.' },
    { wert: 80, einheit: 'm', ursache: 'Nur der erste Abschnitt berücksichtigt',
      hinweis: 'Nach dem Halt fährt das Fahrzeug weiter — die dritte Teilfläche gehört dazu.' },
    { wert: 240, einheit: 'm', ursache: 'Beim dritten Abschnitt die Zeitspanne 20 s statt 10 s verwendet',
      hinweis: 'Der Abschnitt läuft von 15 s bis 25 s, dauert also $Δt = 10 "s"$. Auf der Zeitachse ' +
        'zählt immer die Differenz, nicht der Endwert.' }
  ]
},

{
  id: 'm1-a10', modul: 'm1', niveau: 'standard', typ: 'rechnung',
  kompetenz: ['UF4'], afb: 2, zeit: 8,
  operator: 'Berechne',
  kontext: 'Auf einer geraden Straße fährt Auto A vom Ort $x = 0$ aus mit 15 m/s in die positive ' +
    'Richtung los. Im selben Augenblick startet Auto B bei $x = 400 "m"$ und fährt mit 10 m/s ' +
    'entgegengesetzt, also auf A zu.',
  text: 'an welchem Ort sich die beiden Fahrzeuge begegnen.',
  gegeben: '$x_A0 = 0 "m"$, $v_A = 15 "m/s"$; $x_B0 = 400 "m"$, $v_B = -10 "m/s"$',
  loesung: { wert: 240, einheit: 'm', toleranz: 0.02 },
  weg: [
    { schritt: 'Ansatz', inhalt: 'Beide Bewegungen sind gleichförmig, also gilt jeweils ' +
      '$x(t) = x_0 + v * t$. Bei der Begegnung sind beide Fahrzeuge zur selben Zeit am selben Ort: ' +
      '$x_A(t) = x_B(t)$.' },
    { schritt: 'Ortsfunktionen', inhalt: '$x_A(t) = 15 * t$ und $x_B(t) = 400 - 10 * t$ ' +
      '(negatives Vorzeichen, weil B entgegen der positiven Richtung fährt)' },
    { schritt: 'Gleichsetzen', inhalt: '$15 * t = 400 - 10 * t$' },
    { schritt: 'Umstellen', inhalt: '$25 * t = 400$, also $t = 16 "s"$' },
    { schritt: 'Ort einsetzen', inhalt: '$x = 15 "m/s" * 16 "s" = 240 "m"$' },
    { schritt: 'Probe', inhalt: 'Für B: $400 "m" - 10 "m/s" * 16 "s" = 240 "m"$ — beide Rechnungen ' +
      'liefern denselben Ort, die Lösung ist stimmig.' },
    { schritt: 'Plausibilität', inhalt: 'A ist schneller und legt deshalb mehr als die Hälfte der ' +
      '400 m zurück. 240 m > 200 m passt.' }
  ],
  hilfen: [
    'Was gilt im Moment der Begegnung für die beiden Ortsangaben — welche Größe ist dann bei beiden gleich?',
    'Stelle für jedes Fahrzeug $x(t) = x_0 + v * t$ auf und setze die beiden Terme gleich. Achte auf ' +
    'das Vorzeichen von $v_B$.',
    'Aus $15 * t = 400 - 10 * t$ folgt $25 * t = 400$. Berechne $t$ und setze es in eine der beiden ' +
    'Ortsfunktionen ein.'
  ],
  fehleranalyse: [
    { wert: 16, einheit: 'm', ursache: 'Die Zeit als Antwort angegeben',
      hinweis: '16 ist der richtige Zeitpunkt in Sekunden. Gefragt war der <em>Ort</em> — setze $t$ ' +
        'noch in eine Ortsfunktion ein.' },
    { wert: 200, einheit: 'm', ursache: 'Mitte der Strecke angenommen',
      hinweis: 'Die Mitte wäre nur bei gleichen Geschwindigkeiten der Treffpunkt. A ist schneller und ' +
        'kommt deshalb weiter als die Hälfte.' },
    { wert: 160, einheit: 'm', ursache: 'Mit der Geschwindigkeit von B statt der von A gerechnet',
      hinweis: 'Setze $t = 16 "s"$ in die Ortsfunktion ein, deren Anfangsort du kennst — und rechne ' +
        'zur Probe beide.' }
  ]
},

{
  id: 'm1-a11', modul: 'm1', niveau: 'standard', typ: 'rechnung',
  kompetenz: ['E4', 'E5', 'E7'], afb: 2, zeit: 8,
  operator: 'Werte aus',
  kontext: 'Ein Wagen fährt auf einer Fahrbahn an fünf Lichtschranken vorbei. Die Messreihe ist ' +
    'simuliert, aber mit realistischer Streuung versehen.',
  text: 'die Messreihe und bestimme die Geschwindigkeit des Wagens. Gib das Ergebnis mit einer ' +
    'sinnvollen Zahl geltender Ziffern an.',
  tabelle: {
    beschriftung: 'Simulierte Messreihe (Ort und Zeit)',
    spalten: ['x in m', 't in s'],
    zeilen: [['0,00', '0,00'], ['0,20', '0,49'], ['0,40', '0,94'],
             ['0,60', '1,44'], ['0,80', '1,91'], ['1,00', '2,37']]
  },
  loesung: { wert: 0.42, einheit: 'm/s', toleranz: 0.05 },
  weg: [
    { schritt: 'Ansatz', inhalt: 'Die Wertepaare in ein Zeit-Ort-Diagramm eintragen. Liegen sie auf ' +
      'einer Geraden, ist die Bewegung gleichförmig und die Steigung ist die Geschwindigkeit.' },
    { schritt: 'Ausgleichsgerade', inhalt: 'Die Gerade so legen, dass die Punkte gleichmäßig darüber ' +
      'und darunter streuen. Sie muss durch keinen einzelnen Messpunkt gehen.' },
    { schritt: 'Steigung ablesen', inhalt: 'Mit einem <b>großen</b> Steigungsdreieck von $t = 0 "s"$ bis ' +
      '$t = 2,4 "s"$: $Δx ≈ 1,01 "m"$.' },
    { schritt: 'Einsetzen', inhalt: '$v = Δx / Δt = 1,01 "m" / 2,4 "s"$' },
    { schritt: 'Ergebnis', inhalt: '$v ≈ 0,42 "m/s"$' },
    { schritt: 'Geltende Ziffern', inhalt: 'Die Einzelwerte $x / t$ liegen zwischen 0,41 m/s und ' +
      '0,43 m/s, streuen also um etwa 2 %. Mehr als zwei geltende Ziffern sind dadurch nicht gedeckt — ' +
      '„0,4214 m/s" wäre eine vorgetäuschte Genauigkeit.' }
  ],
  nachtrag: 'Die Auswertung über die Ausgleichsgerade nutzt <em>alle</em> Messpunkte und ist deshalb ' +
    'belastbarer als ein einzelnes Wertepaar. Zur vollständigen Auswertung gehört außerdem die Aussage, ' +
    'dass die Bewegung im untersuchten Bereich gleichförmig ist — genau das zeigt die Geradenform.',
  hilfen: [
    'Rechne für ein paar Zeilen $x / t$ aus. Sind die Werte gleich, oder gibt es einen Trend?',
    'Trage die Punkte in ein Zeit-Ort-Diagramm ein und lege eine Ausgleichsgerade an. Ihre Steigung ' +
    'ist die gesuchte Geschwindigkeit.',
    'Nimm ein großes Steigungsdreieck über den ganzen Messbereich: rund 1,0 m in 2,4 s.'
  ],
  fehleranalyse: [
    { wert: 2.37, einheit: 'm/s', ursache: 'Zeit durch Weg gerechnet',
      hinweis: 'Der Einheitentest entlarvt es: $"s" / "m"$ ist keine Geschwindigkeit. ' +
        'Es gilt $v = Δx / Δt$.' },
    { ursache: 'Nur ein einzelnes Wertepaar benutzt',
      hinweis: 'Ein einzelnes Wertepaar trägt die volle Messunsicherheit — aus dem zweiten Wertepaar ' +
        'folgte 0,41 m/s, aus dem dritten 0,43 m/s. Diese Werte liegen noch im Toleranzbereich und ' +
        'werden deshalb nicht als falsch gewertet; belastbar ist trotzdem nur die Ausgleichsgerade, ' +
        'weil sie alle Messpunkte zugleich nutzt.' }
  ]
}

];

/* ------------------------------------------------------------ LK-VERTIEFUNG */
Physik.Inhalt.aufgaben.m1.push(

{
  id: 'm1-a12', modul: 'm1', niveau: 'vertiefung', typ: 'mehrfach',
  kompetenz: ['UF4', 'E6'], afb: 3, zeit: 6,
  operator: 'Überprüfe',
  text: 'die folgenden Aussagen über mittlere und momentane Geschwindigkeit. ' +
    'Wähle <em>alle</em> zutreffenden aus.',
  optionen: [
    { text: 'Bei einer gleichförmigen Bewegung stimmen mittlere und momentane Geschwindigkeit ' +
        'zu jedem Zeitpunkt überein.', richtig: true,
      rueckmeldung: 'Zutreffend: Die $x(t)$-Kurve ist eine Gerade, und die Steigung einer Geraden ist ' +
        'überall dieselbe. Deshalb durfte in den ersten Einheiten sorglos $v$ ohne Zusatz geschrieben werden.' },
    { text: 'Die momentane Geschwindigkeit ist die Steigung der Tangente an die $x(t)$-Kurve.',
      richtig: true,
      rueckmeldung: 'Zutreffend — das ist die Definition, zu der der Grenzübergang von der Sekante führt.' },
    { text: 'Die mittlere Geschwindigkeit ist der Mittelwert aus Anfangs- und Endgeschwindigkeit.',
      richtig: false,
      rueckmeldung: 'Nicht zutreffend. Das gilt nur in dem Sonderfall, dass sich die Geschwindigkeit ' +
        'gleichmäßig ändert — dieser Fall kommt erst in M2 vor. Allgemein ist die mittlere ' +
        'Geschwindigkeit $Δx / Δt$.' },
    { text: 'Ist die mittlere Geschwindigkeit über ein Zeitintervall null, so hat sich der Körper ' +
        'in diesem Intervall nicht bewegt.', richtig: false,
      rueckmeldung: 'Nicht zutreffend. Bei einer geschlossenen Runde ist $Δx = 0$ und damit auch ' +
        '$v_mittel = 0$, obwohl der Körper die ganze Zeit unterwegs war.' },
    { text: 'Je kleiner die betrachtete Zeitspanne, desto näher liegt die mittlere an der momentanen ' +
        'Geschwindigkeit.', richtig: true,
      rueckmeldung: 'Zutreffend — genau das ist der Grenzübergang von der Sekante zur Tangente.' }
  ],
  bestaetigung: 'Damit ist der begriffliche Kern des Moduls beisammen: Beide Größen heißen ' +
    '„Geschwindigkeit", meinen aber Verschiedenes — eine Aussage über ein Intervall und eine über ' +
    'einen Zeitpunkt.',
  weg: [
    { schritt: 'Prüfmuster', inhalt: 'Bei Aussagen dieser Art hilft ein Gegenbeispiel: Wenn sich ein ' +
      'einziger Fall finden lässt, in dem die Aussage scheitert, ist sie in dieser Allgemeinheit falsch.' },
    { schritt: 'Gegenbeispiel zu Aussage 3', inhalt: 'Ein Auto fährt 1 h mit 100 km/h und steht dann ' +
      '1 h. Anfangs- und Endgeschwindigkeit sind 100 und 0, der Mittelwert wäre 50 km/h — tatsächlich ' +
      'sind es $100 "km" / 2 "h" = 50 "km/h"$. Hier stimmt es zufällig. Steht das Auto dagegen 3 h, ' +
      'ergibt der Mittelwert weiterhin 50 km/h, die Rechnung aber $100 / 4 = 25 "km/h"$.' },
    { schritt: 'Gegenbeispiel zu Aussage 4', inhalt: 'Die Stadionrunde: $Δx = 0$, obwohl 400 m ' +
      'zurückgelegt wurden.' }
  ],
  hilfen: [
    'Suche zu jeder Aussage ein konkretes Gegenbeispiel. Eine Aussage, die schon an einem Fall ' +
    'scheitert, ist als allgemeine Aussage falsch.',
    'Denk bei Aussage 4 an die Stadionrunde aus Lerneinheit 5.',
    'Aussage 3 beschreibt einen Sonderfall, der eine gleichmäßige Änderung der Geschwindigkeit ' +
    'voraussetzt — die kommt in diesem Modul noch gar nicht vor.'
  ],
  fehleranalyse: [
    { ursache: 'Aussage 4 als richtig angekreuzt',
      hinweis: 'Verwechslung von Verschiebung und zurückgelegter Strecke. Bei einer Rundfahrt ist die ' +
        'Verschiebung null, die Strecke aber nicht.' }
  ]
},

{
  id: 'm1-a13', modul: 'm1', niveau: 'vertiefung', typ: 'frei',
  kompetenz: ['K4', 'E6'], afb: 3, zeit: 8,
  operator: 'Erläutere',
  kontext: 'Ein Mitschüler sagt beim Blick auf ein Zeit-Ort-Diagramm: „Hier ist das Auto den Berg ' +
    'hochgefahren und danach wieder runter."',
  text: 'in eigenen Worten, warum diese Deutung nicht haltbar ist, und gib an, was der Verlauf ' +
    'tatsächlich beschreibt. Formuliere so, dass dein Mitschüler den Fehler selbst erkennt.',
  erwartung: 'Eine vollständige Antwort enthält vier Bausteine:',
  weg: [
    { schritt: 'Achsen benennen', inhalt: 'Auf der senkrechten Achse steht der <b>Ort entlang der ' +
      'Fahrtrichtung</b> in Metern, nicht die Höhe über dem Boden. Das Diagramm ist kein Bild der ' +
      'Landschaft, sondern eine Zuordnung von Zeitpunkten zu Orten.' },
    { schritt: 'Verlauf richtig deuten', inhalt: 'Ein Anstieg bedeutet: Der Ortswert wird größer, das ' +
      'Fahrzeug bewegt sich in die positive Richtung. Ein Abfall bedeutet: Der Ortswert wird kleiner, ' +
      'das Fahrzeug fährt <b>zurück</b> — nicht bergab.' },
    { schritt: 'Gegenbeispiel anbieten', inhalt: 'Dieselbe Kurve entsteht auf einer völlig ebenen, ' +
      'schnurgeraden Straße, wenn ein Auto ein Stück vorwärts fährt und dann zurücksetzt. Umgekehrt ' +
      'erzeugt eine Bergfahrt ohne Richtungswechsel eine stetig <em>steigende</em> Kurve.' },
    { schritt: 'Verallgemeinern', inhalt: 'Merksatz für den Mitschüler: Vor jeder Deutung die ' +
      'Achsenbeschriftungen laut mitlesen. Erst sie legen fest, was die Form der Kurve bedeutet.' }
  ],
  nachtrag: 'Bewerte deine eigene Antwort ehrlich: Hast du <em>begründet</em> (mit Bezug auf die ' +
    'Achsenbeschriftung) oder nur <em>behauptet</em>? Der Operator „erläutern" verlangt eine ' +
    'nachvollziehbare Ursache-Wirkungs-Kette, nicht nur das richtige Stichwort.',
  hilfen: [
    'Was genau steht auf der senkrechten Achse — und was steht dort <em>nicht</em>?',
    'Beschreibe, welche reale Bewegung auf ebener Strecke genau diese Kurve erzeugen würde.',
    'Formuliere zum Schluss eine Regel, die man sich merken kann: Womit fängt das Lesen eines ' +
    'Diagramms immer an?'
  ],
  fehleranalyse: [
    { ursache: 'Nur „das ist falsch" ohne Begründung',
      hinweis: 'Der Operator verlangt eine Erläuterung. Ohne Bezug auf die Achsenbeschriftung fehlt ' +
        'der tragende Teil der Antwort.' },
    { ursache: 'Richtige Deutung, aber ohne Gegenbeispiel',
      hinweis: 'Ein konkretes Gegenbeispiel überzeugt stärker als eine Regel — es zeigt, dass dieselbe ' +
        'Kurve ohne jeden Berg zustande kommt.' }
  ]
},

/* --- Klausurformat: eine Situation, drei aufeinander aufbauende Teilaufgaben --- */
{
  id: 'm1-a14a', modul: 'm1', niveau: 'vertiefung', typ: 'rechnung',
  kompetenz: ['UF2', 'UF4'], afb: 2, zeit: 5,
  operator: 'Berechne',
  kontext: '<b>Klausuraufgabe, Teil a)</b> — Ein Regionalzug von 80 m Länge fährt mit konstant 30 m/s ' +
    'an einem 220 m langen Bahnsteig vorbei, ohne zu halten.',
  text: 'wie lange es dauert, bis der Zug den Bahnsteig vollständig passiert hat. Gemeint ist die ' +
    'Zeitspanne von dem Augenblick, in dem die Zugspitze den Anfang des Bahnsteigs erreicht, bis zu dem ' +
    'Augenblick, in dem das Zugende den Bahnsteig verlässt.',
  gegeben: '$l_Zug = 80 "m"$, $l_Bahnsteig = 220 "m"$, $v = 30 "m/s"$',
  loesung: { wert: 10, einheit: 's', toleranz: 0.02 },
  weg: [
    { schritt: 'Skizze', inhalt: 'Anfangslage: Zugspitze am Bahnsteiganfang. Endlage: Zugende am ' +
      'Bahnsteigende. Betrachtet wird ein fester Punkt des Zuges — am einfachsten die Spitze.' },
    { schritt: 'Überlegung', inhalt: 'Die Spitze muss den gesamten Bahnsteig <em>und</em> zusätzlich ' +
      'die Zuglänge zurücklegen, damit das Zugende den Bahnsteig verlässt.' },
    { schritt: 'Ansatz', inhalt: '$s = l_Bahnsteig + l_Zug$ und $Δt = s / v$' },
    { schritt: 'Einsetzen', inhalt: '$s = 220 "m" + 80 "m" = 300 "m"$, also ' +
      '$Δt = 300 "m" / 30 "m/s"$' },
    { schritt: 'Ergebnis', inhalt: '$Δt = 10 "s"$' },
    { schritt: 'Plausibilität', inhalt: 'In 10 s legt der Zug bei 30 m/s genau 300 m zurück — das ist ' +
      'etwas mehr als die Bahnsteiglänge, wie es sein muss.' }
  ],
  hilfen: [
    'Zeichne zwei Momentaufnahmen: die Anfangs- und die Endlage. Welchen Weg hat die Zugspitze ' +
    'zwischen beiden zurückgelegt?',
    'Der Zug ist erst dann vollständig vorbei, wenn auch sein <em>Ende</em> den Bahnsteig verlassen hat. ' +
    'Der Weg der Spitze ist deshalb länger als der Bahnsteig.',
    '$s = 220 "m" + 80 "m" = 300 "m"$. Nun $Δt = s / v$.'
  ],
  fehleranalyse: [
    { wert: 7.33, einheit: 's', ursache: 'Nur die Bahnsteiglänge verwendet',
      hinweis: 'Nach 220 m hat erst die <em>Spitze</em> das Bahnsteigende erreicht — der Rest des Zuges ' +
        'steht noch am Bahnsteig. Die Zuglänge muss dazu.' },
    { wert: 2.67, einheit: 's', ursache: 'Nur die Zuglänge verwendet',
      hinweis: 'Das ist die Zeit, die der Zug braucht, um an einem <em>einzelnen Punkt</em> ' +
        'vorbeizufahren — genau die Frage aus Teil c).' }
  ]
},

{
  id: 'm1-a14b', modul: 'm1', niveau: 'vertiefung', typ: 'rechnung',
  kompetenz: ['UF4', 'E6'], afb: 2, zeit: 5,
  operator: 'Bestimme',
  kontext: '<b>Klausuraufgabe, Teil b)</b> — Derselbe Zug, weiterhin 30 m/s. Ein Fahrgast geht im ' +
    'Zug mit 1,2 m/s durch den Gang, und zwar entgegen der Fahrtrichtung.',
  text: 'die Geschwindigkeit des Fahrgastes relativ zum Bahnsteig.',
  gegeben: '$v_Zug = 30 "m/s"$, $v_Fahrgast,Zug = 1,2 "m/s"$ entgegen der Fahrtrichtung',
  loesung: { wert: 28.8, einheit: 'm/s', toleranz: 0.02 },
  weg: [
    { schritt: 'Bezugssysteme benennen', inhalt: 'Gegeben ist die Geschwindigkeit des Zuges relativ ' +
      'zum Bahnsteig und die des Fahrgastes relativ zum Zug. Gesucht ist der Fahrgast relativ zum ' +
      'Bahnsteig.' },
    { schritt: 'Richtung festlegen', inhalt: 'Positive Richtung sei die Fahrtrichtung des Zuges. Dann ' +
      'ist $v_Fahrgast,Zug = -1,2 "m/s"$.' },
    { schritt: 'Ansatz', inhalt: 'Geschwindigkeiten relativ zu verschiedenen Bezugssystemen addieren ' +
      'sich: $v_Fahrgast,Bahnsteig = v_Zug + v_Fahrgast,Zug$' },
    { schritt: 'Einsetzen', inhalt: '$v = 30 "m/s" + (-1,2 "m/s")$' },
    { schritt: 'Ergebnis', inhalt: '$v = 28,8 "m/s"$' },
    { schritt: 'Plausibilität', inhalt: 'Der Fahrgast bewegt sich vom Bahnsteig aus gesehen weiterhin ' +
      'in Fahrtrichtung, nur etwas langsamer als der Zug. Ein Wert über 30 m/s wäre ein Vorzeichenfehler.' }
  ],
  hilfen: [
    'Relativ zu welchem Körper ist jede der beiden gegebenen Geschwindigkeiten angegeben?',
    'Lege eine positive Richtung fest. Welches Vorzeichen bekommt die Geschwindigkeit des Fahrgastes ' +
    'im Zug, wenn er entgegen der Fahrtrichtung geht?',
    'Addiere: $30 "m/s" + (-1,2 "m/s")$.'
  ],
  fehleranalyse: [
    { wert: 31.2, einheit: 'm/s', ursache: 'Beträge addiert, Richtung nicht beachtet',
      hinweis: 'Der Fahrgast geht <em>entgegen</em> der Fahrtrichtung, seine Geschwindigkeit ist im ' +
        'gewählten System negativ. Addiert würde nur, wenn er nach vorn ginge.' },
    { wert: 1.2, einheit: 'm/s', ursache: 'Bezugssystem verwechselt',
      hinweis: '1,2 m/s gilt relativ zum Zug. Vom Bahnsteig aus kommt die Zuggeschwindigkeit hinzu.' }
  ]
},

{
  id: 'm1-a14c', modul: 'm1', niveau: 'vertiefung', typ: 'rechnung',
  kompetenz: ['UF4', 'K1'], afb: 3, zeit: 6,
  operator: 'Berechne',
  kontext: '<b>Klausuraufgabe, Teil c)</b> — Eine Person steht an einem festen Punkt des Bahnsteigs ' +
    'und beobachtet den vorbeifahrenden Zug (Länge 80 m, Geschwindigkeit 30 m/s).',
  text: 'wie lange der Zug an dieser Person vorbeifährt, und begründe im Lösungsweg, warum hier eine ' +
    'andere Rechnung nötig ist als in Teil a).',
  gegeben: '$l_Zug = 80 "m"$, $v = 30 "m/s"$',
  loesung: { wert: 2.67, einheit: 's', toleranz: 0.03 },
  weg: [
    { schritt: 'Unterschied zu a)', inhalt: 'In Teil a) war der Bahnsteig ausgedehnt, die Spitze musste ' +
      'Bahnsteig <em>und</em> Zuglänge zurücklegen. Hier ist der Beobachtungsort ein einzelner Punkt ' +
      'ohne Ausdehnung — es zählt nur die Länge des Zuges.' },
    { schritt: 'Ansatz', inhalt: 'Von „Spitze erreicht die Person" bis „Ende passiert die Person" legt ' +
      'der Zug genau seine eigene Länge zurück: $s = l_Zug$.' },
    { schritt: 'Einsetzen', inhalt: '$Δt = 80 "m" / 30 "m/s"$' },
    { schritt: 'Ergebnis', inhalt: '$Δt ≈ 2,7 "s"$' },
    { schritt: 'Plausibilität', inhalt: 'Deutlich kürzer als die 10 s aus Teil a) — der Bahnsteig ist ' +
      'fast dreimal so lang wie der Zug, das Verhältnis passt.' }
  ],
  nachtrag: 'Der eigentliche Lerngewinn dieser Teilaufgabe liegt nicht in der Zahl, sondern in der ' +
    'Frage: <em>Welche Länge legt der betrachtete Punkt tatsächlich zurück?</em> Wer bei solchen ' +
    'Aufgaben zuerst zwei Momentaufnahmen skizziert, macht diesen Fehler nicht mehr.',
  hilfen: [
    'Skizziere wieder Anfangs- und Endlage. Wie lang ist der Beobachtungsort selbst?',
    'Der Beobachtungspunkt hat keine Ausdehnung. Welchen Weg legt die Zugspitze zurück, bis das ' +
    'Zugende ihn erreicht?',
    'Es ist genau die Zuglänge: $Δt = 80 "m" / 30 "m/s"$.'
  ],
  fehleranalyse: [
    { wert: 10, einheit: 's', ursache: 'Ergebnis aus Teil a) übernommen',
      hinweis: 'Die Bahnsteiglänge spielt hier keine Rolle — der Beobachtungsort ist ein Punkt.' },
    { wert: 0.375, einheit: 's', ursache: 'Bruch umgedreht',
      hinweis: 'Einheitentest: $("m/s") / "m"$ ergibt $1/"s"$, keine Zeit. Es gilt $Δt = s / v$.' }
  ]
},

{
  id: 'm1-a15', modul: 'm1', niveau: 'vertiefung', typ: 'rechnung',
  kompetenz: ['E1', 'E5', 'B4'], afb: 3, zeit: 7,
  operator: 'Schätze ab',
  kontext: 'In der Fahrschule gilt die Faustregel „zwei Sekunden Abstand": Der Abstand zum Vordermann ' +
    'soll mindestens so groß sein, dass man zwei Sekunden später an derselben Stelle ist.',
  text: 'welchen Abstand diese Regel bei 100 km/h fordert. Gib den Wert in Metern an.',
  loesung: { wert: 56, einheit: 'm', toleranz: 0.08 },
  weg: [
    { schritt: 'Annahme benennen', inhalt: 'Während der zwei Sekunden fährt das Fahrzeug ' +
      'näherungsweise gleichförmig — bei freier Fahrt eine brauchbare Annahme.' },
    { schritt: 'Einheiten angleichen', inhalt: '$100 "km/h" = 100 / 3,6 "m/s" ≈ 27,8 "m/s"$. ' +
      'Ohne diesen Schritt passen Geschwindigkeit und Zeit nicht zusammen.' },
    { schritt: 'Ansatz', inhalt: '$s = v * Δt$' },
    { schritt: 'Einsetzen', inhalt: '$s = 27,8 "m/s" * 2 "s"$' },
    { schritt: 'Ergebnis', inhalt: '$s ≈ 56 "m"$' },
    { schritt: 'Plausibilität', inhalt: 'Rund 56 m entsprechen etwa 12 Pkw-Längen oder gut drei ' +
      'Leitpfostenabständen (50 m) auf der Autobahn — genau die Größenordnung, die in der Fahrschule ' +
      'genannt wird.' }
  ],
  nachtrag: 'Die verwandte Regel „halber Tacho in Metern" ergäbe hier 50 m und liegt damit dicht ' +
    'daneben. Beide sind Näherungen für dieselbe Sache. Zu einer vollständigen Abschätzung gehört, die ' +
    'Annahmen zu nennen — hier: gleichförmige Fahrt, keine Reaktionszeit berücksichtigt, trockene Fahrbahn.',
  hilfen: [
    'In welcher Einheit steht die Geschwindigkeit, in welcher die Zeit? Passen sie zusammen?',
    'Rechne 100 km/h zuerst in m/s um und nutze dann $s = v * Δt$.',
    '$100 / 3,6 ≈ 27,8 "m/s"$, mal 2 s.'
  ],
  fehleranalyse: [
    { wert: 200, einheit: 'm', ursache: 'Mit 100 km/h gerechnet, ohne in m/s umzurechnen',
      hinweis: '$100 * 2$ vermischt Kilometer pro Stunde mit Sekunden. Erst umrechnen, dann ' +
        'multiplizieren — sonst stimmt die Einheit des Ergebnisses nicht.' },
    { wert: 27.8, einheit: 'm', ursache: 'Nur eine Sekunde gerechnet',
      hinweis: 'Die Regel nennt zwei Sekunden. Multipliziere mit $Δt = 2 "s"$.' },
    { wert: 50, einheit: 'm', ursache: 'Faustregel „halber Tacho" statt der Zwei-Sekunden-Regel',
      hinweis: 'Der Wert ist als Faustregel brauchbar, aber gefragt war die Rechnung zur ' +
        'Zwei-Sekunden-Regel. Beide Ergebnisse liegen dicht beieinander — das ist kein Zufall.' }
  ]
},

{
  id: 'm1-a16', modul: 'm1', niveau: 'vertiefung', typ: 'frei',
  kompetenz: ['B1', 'B2', 'K4'], afb: 3, zeit: 10,
  operator: 'Beurteile',
  kontext: 'Zur Geschwindigkeitsüberwachung gibt es zwei Verfahren. Ein <b>stationäres Messgerät</b> ' +
    '(„Blitzer") misst die Geschwindigkeit an einem Punkt. Die <b>Abschnittskontrolle</b> erfasst ein ' +
    'Fahrzeug am Anfang und am Ende eines mehrere Kilometer langen Abschnitts und berechnet daraus ' +
    'einen Wert.',
  text: 'die beiden Verfahren aus physikalischer Sicht. Gehe darauf ein, welche Größe jeweils gemessen ' +
    'wird und welche Aussage über das Fahrverhalten damit möglich ist — und welche nicht.',
  erwartung: 'Eine vollständige Beurteilung nennt zuerst die gemessenen Größen, leitet daraus die ' +
    'Reichweite der Aussage ab und formuliert erst dann ein Urteil mit einem offengelegten Kriterium:',
  weg: [
    { schritt: 'Physikalische Größe benennen', inhalt: 'Der Blitzer erfasst die <b>Momentangeschwindigkeit</b> ' +
      'an einem Ort und zu einem Zeitpunkt. Die Abschnittskontrolle misst zwei Zeitpunkte über eine ' +
      'bekannte Strecke und berechnet daraus die <b>mittlere Geschwindigkeit</b> $v_mittel = Δx / Δt$.' },
    { schritt: 'Reichweite der Aussage', inhalt: 'Der Blitzer sagt nichts über den Rest der Strecke — ' +
      'wer nur an dieser Stelle bremst, wird nicht erfasst. Die Abschnittskontrolle sagt umgekehrt ' +
      'nichts über einzelne Zeitpunkte: Eine mittlere Geschwindigkeit von 100 km/h ist mit durchgehend ' +
      '100 km/h ebenso vereinbar wie mit einem Wechsel aus 130 km/h und 70 km/h.' },
    { schritt: 'Folgerung', inhalt: 'Eine <em>Überschreitung</em> der mittleren Geschwindigkeit beweist ' +
      'zwingend eine Überschreitung auch der Momentangeschwindigkeit irgendwo im Abschnitt — denn ohne ' +
      'jede Überschreitung könnte der Mittelwert nicht darüber liegen. Der Umkehrschluss gilt nicht: ' +
      'Ein zulässiger Mittelwert schließt eine kurzzeitige Überschreitung nicht aus.' },
    { schritt: 'Urteil mit Kriterium', inhalt: 'Nach dem Kriterium „gleichmäßige Wirkung über die ' +
      'gesamte Strecke" ist die Abschnittskontrolle überlegen, weil sie punktuelles Bremsen wirkungslos ' +
      'macht. Nach dem Kriterium „Nachweis einer konkreten Einzelüberschreitung" ist der Blitzer ' +
      'geeigneter, weil er Ort und Zeitpunkt eindeutig festhält. Welches Kriterium schwerer wiegt, ist ' +
      'keine physikalische, sondern eine verkehrspolitische Entscheidung — sie gehört ausdrücklich als ' +
      'solche benannt.' }
  ],
  nachtrag: 'Prüfe deine eigene Antwort: Hast du ein <em>Kriterium offengelegt</em>, bevor du geurteilt ' +
    'hast? Genau das unterscheidet den Operator „beurteilen" von „beschreiben". Eine Beurteilung ohne ' +
    'genanntes Kriterium ist in der Klausur unvollständig, auch wenn das Urteil selbst nachvollziehbar ist.',
  hilfen: [
    'Welche der beiden Geschwindigkeiten aus diesem Modul — momentan oder mittlere — misst welches Verfahren?',
    'Überlege für die Abschnittskontrolle: Welche Fahrweisen führen zu <em>demselben</em> Messergebnis? ' +
    'Was folgt daraus für die Aussagekraft?',
    'Formuliere zum Schluss zwei verschiedene Kriterien und beurteile die Verfahren jeweils nach beiden. ' +
    'Ein Urteil ohne genanntes Kriterium ist keine Beurteilung.'
  ],
  fehleranalyse: [
    { ursache: 'Nur eine Meinung geäußert („Abschnittskontrolle ist gerechter")',
      hinweis: 'Ohne Bezug auf die gemessene physikalische Größe fehlt die fachliche Grundlage. ' +
        'Beginne mit der Größe, nicht mit dem Urteil.' },
    { ursache: 'Mittlere und momentane Geschwindigkeit gleichgesetzt',
      hinweis: 'Genau ihre Verschiedenheit macht den Unterschied der Verfahren aus. Ein Mittelwert ' +
        'legt den Verlauf nicht fest.' }
  ]
}

);
