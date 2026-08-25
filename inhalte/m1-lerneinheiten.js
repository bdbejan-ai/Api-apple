/* m1-lerneinheiten.js — Lerneinheiten des Moduls M1 „Bewegungen beschreiben".
 * Aufbau der Bausteine: siehe inhalte/SCHEMA.md
 * Formeln stehen zwischen Dollarzeichen und werden von js/formel.js gesetzt. */
window.Physik = window.Physik || {};
Physik.Inhalt = Physik.Inhalt || { module: [], lerneinheiten: {}, aufgaben: {} };

Physik.Inhalt.lerneinheiten.m1 = [

/* ================================================================= LE 1 */
{
  id: 'm1-le1',
  modul: 'm1',
  titel: 'Wer bewegt sich eigentlich?',
  dauer: 12,
  kompetenzen: ['UF1', 'E6', 'K3'],
  leitfrage: 'Du sitzt im Zug, schaust aus dem Fenster — und plötzlich rollt der Bahnsteig davon. ' +
             'Woher weißt du, ob dein Zug fährt oder der Zug nebenan?',
  bausteine: [
    { typ: 'text', inhalt:
      'Diese Verwirrung am Bahnsteig ist kein Wahrnehmungsfehler. Sie zeigt etwas Grundsätzliches: ' +
      '<b>Ob sich ein Körper bewegt, ist keine Eigenschaft des Körpers.</b> Die Frage ist erst dann ' +
      'beantwortbar, wenn feststeht, worauf man die Bewegung bezieht.' },

    { typ: 'text', inhalt:
      'Genau das leistet ein <b>Bezugssystem</b>: Man wählt einen Körper als ruhend — den Bahnsteig, ' +
      'die Straße, den eigenen Zug — und beschreibt alles andere relativ dazu. Für eine Bewegung ' +
      'entlang einer Geraden genügt dafür eine Achse mit drei Festlegungen:' },

    { typ: 'text', inhalt:
      '<ol><li>ein <b>Nullpunkt</b>, von dem aus gemessen wird,</li>' +
      '<li>eine <b>positive Richtung</b> — nach rechts ist üblich, aber nicht vorgeschrieben,</li>' +
      '<li>ein <b>Maßstab</b> mit Einheit, meist in Metern.</li></ol>' },

    { typ: 'merksatz', inhalt:
      'Der <b>Ort</b> $x$ gibt an, wo sich ein Körper auf dieser Achse befindet. Er kann negativ sein — ' +
      'das heißt nur: auf der anderen Seite des Nullpunkts. Der <b>Zeitpunkt</b> $t$ sagt, wann das gilt. ' +
      'Ein Bewegungsablauf ist die Zuordnung $x(t)$: zu jedem Zeitpunkt ein Ort.' },

    { typ: 'fehlvorstellung',
      behauptung: 'Ein Körper bewegt sich oder er bewegt sich nicht — das steht doch fest.',
      pruefung: 'Du sitzt im ICE bei 250 km/h und legst dein Handy auf den Klapptisch. Bewegt es sich? ' +
                'Für dich liegt es still; du könntest darauf tippen wie zu Hause. Für jemanden an der ' +
                'Bahnstrecke rast es mit 250 km/h vorbei. Beide Aussagen sind richtig — sie beziehen sich ' +
                'auf verschiedene Bezugssysteme.',
      richtig: 'Ruhe und Bewegung sind keine Eigenschaften eines Körpers, sondern Aussagen über das ' +
               'Verhältnis zweier Körper. Ohne Angabe des Bezugssystems ist die Aussage „das Auto fährt ' +
               '30 m/s" unvollständig — gemeint ist fast immer „relativ zur Straße".' },

    { typ: 'simulation', name: 'bezugssystem',
      einleitung: 'Zwei Autos auf derselben Straße. Stelle die Geschwindigkeiten ein und wechsle dann ' +
        'den Beobachterstandpunkt. Achte darauf, was sich in den Diagrammen ändert — und was nicht.',
      beobachte: [
        'Setze beide Autos auf dieselbe Geschwindigkeit und beobachte von Auto A aus: Auto B steht still, ' +
        'obwohl beide relativ zur Straße mit 20 m/s fahren.',
        'Der Wechsel des Bezugssystems verschiebt im Zeit-Ort-Diagramm die Steigungen — die Form der ' +
        'Geraden bleibt aber gerade. Gleichförmig bleibt gleichförmig.',
        'Gib Auto B eine negative Geschwindigkeit. Negativ heißt hier nicht „langsam", sondern ' +
        '„entgegen der gewählten positiven Richtung".'
      ] },

    { typ: 'frage',
      text: 'Ein Radfahrer fährt mit 6 m/s, ein Auto überholt ihn mit 14 m/s (beides relativ zur Straße). ' +
            'Welche Geschwindigkeit hat das Auto im Bezugssystem des Radfahrers?',
      optionen: [
        { text: '8 m/s', richtig: true,
          rueckmeldung: 'Genau: $v = 14 "m/s" - 6 "m/s" = 8 "m/s"$. Im Bezugssystem des Radfahrers ' +
            'entfernt sich das Auto mit 8 m/s.' },
        { text: '20 m/s', richtig: false,
          rueckmeldung: 'Addiert wird nur bei entgegenkommenden Bewegungen. Hier fahren beide in dieselbe ' +
            'Richtung, die Differenz zählt.' },
        { text: '14 m/s, die Geschwindigkeit ändert sich durch den Standpunkt nicht', richtig: false,
          rueckmeldung: 'Doch, genau das tut sie. 14 m/s gilt relativ zur Straße. Der Radfahrer sieht das ' +
            'Auto langsamer davonziehen, weil er selbst mitfährt.' }
      ] },

    { typ: 'sprache', zeilen: [
      { alltag: '„Das Auto steht."', fach: 'Das Auto ruht im Bezugssystem der Straße.' },
      { alltag: '„Die Strecke war 5 Kilometer."', fach: 'Es ist noch offen, ob die zurückgelegte Strecke ' +
        'oder der Abstand zwischen Start und Ziel gemeint ist — das trennen wir in der nächsten Einheit.' },
      { alltag: '„Minus 3 Meter pro Sekunde ist langsamer als 2 Meter pro Sekunde."',
        fach: 'Der Betrag entscheidet über schnell und langsam; das Vorzeichen gibt nur die Richtung an. ' +
        '−3 m/s ist schneller als +2 m/s.' }
    ] }
  ]
},

/* ================================================================= LE 2 */
{
  id: 'm1-le2',
  modul: 'm1',
  titel: 'Strecke, Verschiebung und die Δ-Schreibweise',
  dauer: 12,
  kompetenzen: ['UF1', 'UF2', 'K1'],
  leitfrage: 'Das Navi meldet 8,2 km bis zum Ziel, die Karte zeigt 5,1 km Luftlinie. ' +
             'Welche Zahl ist die richtige — und wofür?',
  bausteine: [
    { typ: 'text', inhalt:
      'Beide Zahlen sind richtig, sie beantworten nur verschiedene Fragen. Deshalb unterscheidet die ' +
      'Physik zwei Größen, die die Alltagssprache in ein Wort zusammenwirft.' },

    { typ: 'text', inhalt:
      '<b>Die zurückgelegte Strecke</b> $s$ ist die Länge des tatsächlich gefahrenen Weges. Sie wird ' +
      'immer aufaddiert und kann nie kleiner werden — der Kilometerzähler zählt bei jeder Kurve weiter. ' +
      '<br><b>Die Verschiebung</b> $Δx$ ist die Änderung des Ortes: wo bin ich am Ende, verglichen mit ' +
      'dem Anfang? Sie hat ein Vorzeichen und sagt nichts über den Weg dorthin.' },

    { typ: 'formel', quelle: 'Δx = x_2 - x_1',
      zeichen: [
        { z: 'Δx', bedeutung: 'Verschiebung, Ortsänderung', einheit: 'm' },
        { z: 'x_1', bedeutung: 'Ort am Anfang des betrachteten Abschnitts', einheit: 'm' },
        { z: 'x_2', bedeutung: 'Ort am Ende des betrachteten Abschnitts', einheit: 'm' }
      ],
      hinweis: 'Das griechische Δ („Delta") ist kein Faktor, mit dem man multipliziert. Es ist eine ' +
        'Anweisung: „nimm die Differenz aus Ende und Anfang". Genauso gilt für die Zeitspanne ' +
        '$Δt = t_2 - t_1$ — immer Ende minus Anfang, nie umgekehrt.' },

    { typ: 'text', inhalt:
      'Der Unterschied wird an einem Extremfall greifbar: Du läufst 400 m um die Aschenbahn und kommst am ' +
      'Start wieder an. Zurückgelegte Strecke: $s = 400 "m"$. Verschiebung: $Δx = 0 "m"$ — du stehst ' +
      'genau dort, wo du losgelaufen bist. Solange eine Bewegung ohne Richtungswechsel abläuft, sind ' +
      'Betrag der Verschiebung und Strecke gleich; sobald umgekehrt wird, laufen sie auseinander.' },

    { typ: 'diagramm', spez: {
        titel: 'Zeit-Ort-Diagramm einer Fahrt mit Umkehr',
        beschreibung: 'Der Ort steigt von 0 auf 60 Meter in 30 Sekunden, bleibt 10 Sekunden konstant ' +
          'und fällt danach in 20 Sekunden auf 20 Meter.',
        breite: 620, hoehe: 300,
        xBereich: [0, 60], yBereich: [0, 70],
        xTitel: 't in s', yTitel: 'x in m',
        kurven: [{ punkte: [[0, 0], [30, 60], [40, 60], [60, 20]], farbe: '#1f5f8b' }],
        unterschrift: 'Zurückgelegte Strecke: 60 m + 0 m + 40 m = 100 m. Verschiebung: Δx = 20 m − 0 m = 20 m.'
      } },

    { typ: 'merksatz', inhalt:
      '<b>Zeitpunkt und Zeitspanne sind ebenfalls zwei Dinge.</b> „Um 14:03 Uhr" ist ein Zeitpunkt $t$, ' +
      '„drei Minuten lang" ist eine Zeitspanne $Δt$. In Formeln der Kinematik steht fast immer die ' +
      'Zeitspanne — auch dann, wenn nur $t$ geschrieben wird, weil die Uhr bei $t_1 = 0$ gestartet wurde.' },

    { typ: 'frage',
      text: 'Ein Aufzug fährt vom 4. Stock (12 m über dem Boden) ins Erdgeschoss (0 m). ' +
            'Wie groß ist die Verschiebung, wenn die positive Richtung nach oben zeigt?',
      optionen: [
        { text: 'Δx = −12 m', richtig: true,
          rueckmeldung: 'Richtig: $Δx = 0 "m" - 12 "m" = -12 "m"$. Das Minuszeichen sagt „abwärts", also ' +
            'entgegen der gewählten positiven Richtung.' },
        { text: 'Δx = 12 m', richtig: false,
          rueckmeldung: 'Der Betrag stimmt, das Vorzeichen nicht. Ende minus Anfang ergibt hier eine ' +
            'negative Zahl, weil die Fahrt entgegen der positiven Richtung verläuft.' },
        { text: 'Δx = 12 m, denn eine Länge kann nicht negativ sein', richtig: false,
          rueckmeldung: 'Die zurückgelegte Strecke ist tatsächlich nie negativ — sie beträgt hier 12 m. ' +
            'Die Verschiebung ist aber eine gerichtete Größe und darf ein Minuszeichen tragen.' }
      ] }
  ]
},

/* ================================================================= LE 3 */
{
  id: 'm1-le3',
  modul: 'm1',
  titel: 'Mittlere Geschwindigkeit — und die Falle beim Mitteln',
  dauer: 15,
  kompetenzen: ['UF1', 'UF2', 'E5', 'K4'],
  leitfrage: 'Hinweg 30 km/h, Rückweg 60 km/h, gleiche Strecke. Wie schnell warst du im Mittel?',
  bausteine: [
    { typ: 'text', inhalt:
      'Die mittlere Geschwindigkeit beantwortet die Frage: Wie schnell hätte man <em>gleichmäßig</em> ' +
      'fahren müssen, um dieselbe Verschiebung in derselben Zeit zu schaffen? Sie ist damit nichts ' +
      'anderes als Ortsänderung geteilt durch Zeitspanne.' },

    { typ: 'formel', quelle: 'v_mittel = Δx / Δt',
      zeichen: [
        { z: 'v_mittel', bedeutung: 'mittlere Geschwindigkeit im betrachteten Abschnitt', einheit: 'm/s' },
        { z: 'Δx', bedeutung: 'Verschiebung im Abschnitt', einheit: 'm' },
        { z: 'Δt', bedeutung: 'dafür benötigte Zeitspanne', einheit: 's' }
      ],
      hinweis: 'Die Einheit folgt zwingend aus der Rechnung: Meter geteilt durch Sekunden ergibt ' +
        'Meter pro Sekunde. Wer die Einheiten mitrechnet, merkt sofort, wenn der Ansatz nicht stimmt.' },

    { typ: 'text', inhalt:
      '<b>Umrechnung zwischen m/s und km/h.</b> Ein Kilometer sind 1000 m, eine Stunde sind 3600 s. ' +
      'Damit gilt $1 "km/h" = 1000 "m" / 3600 "s"$, also der Faktor $1 / 3,6$. Merken lässt sich das an ' +
      'einer Richtungsregel: <b>von km/h nach m/s wird durch 3,6 geteilt</b> (die Zahl wird kleiner), ' +
      '<b>von m/s nach km/h wird mit 3,6 multipliziert</b> (die Zahl wird größer). Wer unsicher ist, ' +
      'prüft am Alltagswert: 100 km/h sind rund 28 m/s — nicht 360.' },

    { typ: 'beispiel', titel: 'Innerorts erlaubte 50 km/h in m/s',
      schritte: [
        { schritt: 'Gegeben', inhalt: '$v = 50 "km/h"$' },
        { schritt: 'Gesucht', inhalt: '$v$ in $"m/s"$' },
        { schritt: 'Ansatz', inhalt: 'Von km/h nach m/s wird durch 3,6 geteilt.' },
        { schritt: 'Einsetzen', inhalt: '$v = 50 / 3,6 "m/s"$' },
        { schritt: 'Ergebnis', inhalt: '$v ≈ 13,9 "m/s"$' },
        { schritt: 'Plausibilität', inhalt: 'Rund 14 Meter in jeder Sekunde — etwa drei Autolängen. ' +
          'Das passt zum Anblick einer innerörtlichen Fahrt.' }
      ] },

    { typ: 'fehlvorstellung',
      behauptung: 'Hinweg 30 km/h, Rückweg 60 km/h — im Mittel also 45 km/h.',
      pruefung: 'Rechne mit einer konkreten Strecke, zum Beispiel 60 km je Richtung. Hinweg: ' +
        '$60 "km" / 30 "km/h" = 2 "h"$. Rückweg: $60 "km" / 60 "km/h" = 1 "h"$. Insgesamt also 120 km ' +
        'in 3 Stunden. Das ergibt $120 / 3 = 40 "km/h"$, nicht 45 km/h.',
      richtig: 'Gemittelt wird nicht über die Geschwindigkeiten, sondern über die Zeit — und im ' +
        'langsamen Abschnitt verbringt man mehr Zeit, er wiegt deshalb schwerer. Die mittlere ' +
        'Geschwindigkeit ist immer <b>Gesamtstrecke durch Gesamtzeit</b>, niemals der Mittelwert der ' +
        'Einzelgeschwindigkeiten. Nur wenn beide Abschnitte gleich lange <em>dauern</em>, fallen beide ' +
        'Rechnungen zusammen.' },

    { typ: 'merksatz', inhalt:
      'Zwei Größen, ein Wort: Die <b>mittlere Geschwindigkeit</b> gilt für einen ganzen Abschnitt, ' +
      'die <b>Momentangeschwindigkeit</b> für einen Zeitpunkt. Der Tacho zeigt die zweite. Welche ' +
      'gemeint ist, muss aus der Aufgabe hervorgehen — bei „für die Strecke brauchte er 2 Stunden" ' +
      'ist es die mittlere.' },

    { typ: 'frage',
      text: 'Ein Zug legt 180 km in 1,5 h zurück. Wie groß ist seine mittlere Geschwindigkeit in m/s?',
      optionen: [
        { text: 'etwa 33 m/s', richtig: true,
          rueckmeldung: '$180 "km" / 1,5 "h" = 120 "km/h"$, und $120 / 3,6 ≈ 33,3 "m/s"$.' },
        { text: 'etwa 120 m/s', richtig: false,
          rueckmeldung: '120 ist der Wert in km/h. Die Umrechnung in m/s fehlt noch — teile durch 3,6.' },
        { text: 'etwa 432 m/s', richtig: false,
          rueckmeldung: 'Hier wurde mit 3,6 multipliziert statt geteilt. Prüfe die Richtung an einem ' +
            'bekannten Wert: 36 km/h sind 10 m/s, die Zahl muss also kleiner werden.' }
      ] }
  ]
},

/* ================================================================= LE 4 */
{
  id: 'm1-le4',
  modul: 'm1',
  titel: 'Gleichförmige Bewegung im Zeit-Ort-Diagramm',
  dauer: 14,
  kompetenzen: ['UF1', 'E5', 'E6', 'K3'],
  leitfrage: 'Was verrät die Steigung einer Geraden im Zeit-Ort-Diagramm — und was verrät sie nicht?',
  bausteine: [
    { typ: 'text', inhalt:
      'Eine Bewegung heißt <b>gleichförmig</b>, wenn die Geschwindigkeit über die ganze Zeit konstant ' +
      'bleibt: in gleichen Zeitspannen gleiche Verschiebungen. Im Zeit-Ort-Diagramm ergibt das eine ' +
      'Gerade — und zwar genau deshalb, weil zu jedem gleich großen Zeitschritt derselbe Ortszuwachs gehört.' },

    { typ: 'formel', quelle: 'x(t) = x_0 + v * t',
      zeichen: [
        { z: 'x(t)', bedeutung: 'Ort zum Zeitpunkt t', einheit: 'm' },
        { z: 'x_0', bedeutung: 'Ort zum Zeitpunkt t = 0 (Startort)', einheit: 'm' },
        { z: 'v', bedeutung: 'konstante Geschwindigkeit', einheit: 'm/s' },
        { z: 't', bedeutung: 'verstrichene Zeit', einheit: 's' }
      ],
      hinweis: 'Das ist dieselbe Struktur wie die lineare Funktion $y = m * x + b$ aus dem ' +
        'Mathematikunterricht — mit einem Unterschied, der zählt: Hier tragen alle Größen Einheiten, ' +
        'und die Steigung ist nicht irgendeine Zahl, sondern eine Geschwindigkeit in m/s.' },

    { typ: 'diagramm', spez: {
        titel: 'Zeit-Ort-Diagramm mit Steigungsdreieck',
        beschreibung: 'Eine Gerade beginnt bei 20 Metern und steigt gleichmäßig auf 140 Meter nach ' +
          '15 Sekunden. Ein eingezeichnetes Steigungsdreieck zeigt eine Zeitspanne von 10 Sekunden ' +
          'und eine Ortsänderung von 80 Metern.',
        breite: 620, hoehe: 320,
        xBereich: [0, 16], yBereich: [0, 160],
        xTitel: 't in s', yTitel: 'x in m',
        kurven: [{ punkte: [[0, 20], [15, 140]], farbe: '#1f5f8b' }],
        linien: [
          { von: [3, 44], bis: [13, 44], farbe: '#9c3229', staerke: 1.8 },
          { von: [13, 44], bis: [13, 124], farbe: '#9c3229', staerke: 1.8 }
        ],
        beschriftungen: [
          { text: 'Δt = 10 s', bei: [8, 44], dy: 16, anker: 'middle', farbe: '#9c3229' },
          { text: 'Δx = 80 m', bei: [13, 84], dx: 8, farbe: '#9c3229' }
        ],
        unterschrift: 'Steigung = Δx / Δt = 80 m / 10 s = 8 m/s. Die Einheit entsteht beim Ablesen mit — ' +
          'sie ist kein Zusatz, den man hinterher anhängt.'
      } },

    { typ: 'text', inhalt:
      'Aus der Geraden lässt sich damit alles ablesen, was die Bewegung ausmacht:' +
      '<ul>' +
      '<li><b>steile Gerade</b> — große Geschwindigkeit;</li>' +
      '<li><b>flache Gerade</b> — kleine Geschwindigkeit;</li>' +
      '<li><b>waagerechte Gerade</b> — der Ort ändert sich nicht, der Körper ruht im gewählten Bezugssystem;</li>' +
      '<li><b>fallende Gerade</b> — negative Geschwindigkeit, also Bewegung entgegen der positiven Richtung;</li>' +
      '<li><b>Schnittpunkt zweier Geraden</b> — beide Körper sind zur selben Zeit am selben Ort: sie treffen sich.</li>' +
      '</ul>' },

    { typ: 'fehlvorstellung',
      behauptung: 'Im Zeit-Ort-Diagramm sehe ich, welchen Weg das Auto genommen hat — bergauf und wieder bergab.',
      pruefung: 'Sieh dir das Diagramm oben an. Auf der senkrechten Achse steht kein „oben", sondern der ' +
        'Ort <em>entlang der Fahrtrichtung</em>. Eine Fahrt auf schnurgerader, ebener Straße erzeugt ' +
        'genau diese ansteigende Gerade. Umgekehrt würde eine Fahrt über einen Hügel und zurück zum ' +
        'Ausgangspunkt im Zeit-Ort-Diagramm als steigende und dann wieder fallende Linie erscheinen — ' +
        'aber eben nicht, weil es bergauf ging, sondern weil sich die Fahrtrichtung umkehrte.',
      richtig: 'Ein Diagramm ist kein Bild der Landschaft. Bevor du eine Kurve deutest, lies immer zuerst ' +
        'die Achsenbeschriftungen: Welche Größe steht wo, in welcher Einheit? Dieser Fehler — das ' +
        'Diagramm als Landkarte zu lesen — ist der häufigste beim Einstieg in die Kinematik.' },

    { typ: 'frage',
      text: 'Zwei Geraden im Zeit-Ort-Diagramm schneiden sich bei t = 12 s. Was bedeutet das?',
      optionen: [
        { text: 'Beide Körper sind zu diesem Zeitpunkt am selben Ort.', richtig: true,
          rueckmeldung: 'Genau — gleicher Zeitpunkt und gleicher Ort, also eine Begegnung oder ein ' +
            'Überholvorgang.' },
        { text: 'Beide Körper haben zu diesem Zeitpunkt dieselbe Geschwindigkeit.', richtig: false,
          rueckmeldung: 'Gleiche Geschwindigkeit hieße gleiche <em>Steigung</em>, also parallele Geraden. ' +
            'Parallelen schneiden sich gerade nicht.' },
        { text: 'Einer der beiden Körper kehrt hier um.', richtig: false,
          rueckmeldung: 'Eine Umkehr wäre ein Hoch- oder Tiefpunkt in <em>einer</em> Kurve, kein ' +
            'Schnittpunkt zweier Kurven.' }
      ] }
  ]
}

];

Physik.Inhalt.lerneinheiten.m1.push(

/* ================================================================= LE 5 */
{
  id: 'm1-le5',
  modul: 'm1',
  titel: 'Von der mittleren zur momentanen Geschwindigkeit',
  dauer: 15,
  kompetenzen: ['UF1', 'UF4', 'E6', 'K3'],
  leitfrage: 'Der Tacho zeigt 72 km/h. Für welche Zeitspanne gilt dieser Wert eigentlich?',
  bausteine: [
    { typ: 'text', inhalt:
      'Für gar keine — jedenfalls für keine, die man hinschreiben könnte. Der Tacho zeigt die ' +
      '<b>Momentangeschwindigkeit</b>: den Wert in genau diesem Augenblick. Die bisherige Definition ' +
      '$v = Δx / Δt$ braucht dagegen eine Zeitspanne. Wie kommt man von der einen zur anderen?' },

    { typ: 'text', inhalt:
      'Die Idee ist ein <b>Grenzübergang</b>. Man berechnet die mittlere Geschwindigkeit über eine ' +
      'Zeitspanne, die den interessierenden Zeitpunkt enthält, und macht diese Zeitspanne immer kleiner. ' +
      'Im Diagramm heißt das: Die <b>Sekante</b> durch zwei Kurvenpunkte kippt allmählich in die ' +
      '<b>Tangente</b> im betrachteten Punkt.' },

    { typ: 'simulation', name: 'sekante-tangente',
      einleitung: 'Die Kurve zeigt eine beschleunigende Fahrt — sie ist gekrümmt, die Geschwindigkeit ' +
        'ändert sich also laufend. Betrachtet wird der Zeitpunkt t = 5,0 s. Verkleinere Δt und beobachte, ' +
        'wie sich die Sekantensteigung verhält.',
      beobachte: [
        'Bei großem Δt liegt die mittlere Geschwindigkeit deutlich über der Momentangeschwindigkeit — ' +
        'die Fahrt wird ja immer schneller, und der spätere, schnellere Teil geht mit in den Mittelwert ein.',
        'Bei Δt = 0,2 s sind beide Werte fast gleich. Der Unterschied verschwindet nicht plötzlich, ' +
        'er wird stetig kleiner.',
        'Δt = 0 lässt sich nicht einstellen — und das ist kein Mangel des Programms: $0 / 0$ ist nicht ' +
        'definiert. Die Momentangeschwindigkeit ist der Wert, dem sich die Sekantensteigungen nähern.'
      ] },

    { typ: 'merksatz', inhalt:
      'Die <b>Momentangeschwindigkeit</b> zum Zeitpunkt $t$ ist die Steigung der Tangente an die ' +
      '$x(t)$-Kurve in diesem Punkt. Bei gleichförmiger Bewegung ist die Kurve eine Gerade — dort ' +
      'stimmen mittlere und momentane Geschwindigkeit an jeder Stelle überein. Nur deshalb konnten ' +
      'wir bisher sorglos $v$ schreiben.' },

    { typ: 'text', inhalt:
      '<b>Zwei Wege zum Zahlenwert.</b> Beide sind zulässig, du brauchst nur einen:' +
      '<ol><li><b>Grafisch:</b> Tangente mit dem Lineal anlegen, ein möglichst <em>großes</em> ' +
      'Steigungsdreieck einzeichnen und $Δx / Δt$ ablesen. Groß deshalb, weil sich Ablesefehler bei ' +
      'einem kleinen Dreieck stark auf das Ergebnis auswirken.</li>' +
      '<li><b>Rechnerisch:</b> Wenn eine Funktionsgleichung $x(t)$ vorliegt, ist die Tangentensteigung ' +
      'genau das, was in Mathematik die <em>Ableitung</em> heißt. Aus $x(t) = 0,8 * t^2$ folgt ' +
      '$v(t) = 1,6 * t$ — die Momentangeschwindigkeit als eigene Funktion der Zeit.</li></ol>' },

    { typ: 'text', inhalt:
      'Falls die Ableitung im Mathematikunterricht noch nicht behandelt wurde: Der grafische Weg reicht ' +
      'in diesem Modul vollständig aus. Die Ableitung ist hier nur ein bequemeres Werkzeug für dieselbe ' +
      'Sache — die Steigung der Tangente.' },

    { typ: 'frage',
      text: 'Ein Radfahrer fährt eine Runde und ist nach 8 Minuten wieder am Start. ' +
            'Wie groß ist seine <em>mittlere</em> Geschwindigkeit für die gesamte Runde?',
      optionen: [
        { text: '0 m/s, weil die Verschiebung null ist.', richtig: true,
          rueckmeldung: 'Richtig, und das wirkt zunächst absurd. Es zeigt, wie eng die Definition ist: ' +
            '$v_mittel = Δx / Δt$ fragt nach der Ortsänderung, nicht nach der Anstrengung. Wer die ' +
            'Fahrleistung beschreiben will, nimmt die zurückgelegte Strecke geteilt durch die Zeit — ' +
            'das ist die mittlere <em>Bahngeschwindigkeit</em>, eine andere Größe.' },
        { text: 'Der Mittelwert aus Höchst- und Mindestgeschwindigkeit.', richtig: false,
          rueckmeldung: 'Das wäre nur bei einer sehr speziellen Fahrt zufällig richtig. Die Definition ' +
            'kennt keine Höchst- und Mindestwerte.' },
        { text: 'Lässt sich ohne Angabe der Streckenlänge nicht berechnen.', richtig: false,
          rueckmeldung: 'Für die mittlere Geschwindigkeit im Sinne der Definition genügt die ' +
            'Verschiebung — und die ist bei einer geschlossenen Runde null, unabhängig von der Länge.' }
      ] }
  ]
},

/* ================================================================= LE 6 */
{
  id: 'm1-le6',
  modul: 'm1',
  titel: 'Das Zeit-Geschwindigkeit-Diagramm und die Fläche darunter',
  dauer: 13,
  kompetenzen: ['UF2', 'UF4', 'E5', 'K3'],
  leitfrage: 'Im Zeit-Geschwindigkeit-Diagramm steht die Geschwindigkeit auf der senkrechten Achse. ' +
             'Wo steckt dann der zurückgelegte Weg?',
  bausteine: [
    { typ: 'text', inhalt:
      'Dieselbe Fahrt lässt sich in zwei Diagrammen darstellen, die sehr verschieden aussehen und ' +
      'trotzdem dasselbe beschreiben. Der Wechsel zwischen beiden ist eine der wichtigsten Fertigkeiten ' +
      'dieses Kapitels — in Klausuren wird sie regelmäßig verlangt.' },

    { typ: 'diagramm', spez: {
        titel: 'Zeit-Geschwindigkeit-Diagramm einer Fahrt in drei Abschnitten',
        beschreibung: 'Die Geschwindigkeit beträgt 12 Meter pro Sekunde für 20 Sekunden, dann null für ' +
          '10 Sekunden, danach 8 Meter pro Sekunde für 15 Sekunden. Die Flächen unter den waagerechten ' +
          'Abschnitten sind farbig hinterlegt.',
        breite: 620, hoehe: 300,
        xBereich: [0, 48], yBereich: [0, 15],
        xTitel: 't in s', yTitel: 'v in m/s',
        kurven: [{ punkte: [[0, 12], [20, 12], [20, 0], [30, 0], [30, 8], [45, 8]], farbe: '#1f5f8b' }],
        flaechen: [
          { punkte: [[0, 12], [20, 12]], farbe: '#1f5f8b' },
          { punkte: [[30, 8], [45, 8]], farbe: '#1f5f8b' }
        ],
        beschriftungen: [
          { text: '240 m', bei: [10, 6], anker: 'middle', farbe: '#1f5f8b' },
          { text: '120 m', bei: [37.5, 4], anker: 'middle', farbe: '#1f5f8b' }
        ],
        unterschrift: 'Erster Abschnitt: 12 m/s · 20 s = 240 m. Dritter Abschnitt: 8 m/s · 15 s = 120 m. ' +
          'Insgesamt 360 m.'
      } },

    { typ: 'text', inhalt:
      'Warum die Fläche? Weil das Rechteck unter einem waagerechten Abschnitt genau die Rechnung ' +
      'abbildet, die man ohnehin machen würde: <em>Höhe mal Breite</em> ist hier ' +
      '<em>Geschwindigkeit mal Zeitspanne</em>. Der Einheitentest bestätigt es: ' +
      '$"m/s" * "s" = "m"$ — heraus kommt eine Länge, also ein Weg.' },

    { typ: 'merksatz', inhalt:
      'Im <b>Zeit-Geschwindigkeit-Diagramm</b> entspricht die Fläche zwischen Kurve und Zeitachse der ' +
      'Verschiebung. Bei zusammengesetzten Verläufen zerlegt man die Fläche in Rechtecke, Dreiecke und ' +
      'Trapeze und addiert. Flächen <em>unterhalb</em> der Zeitachse gehören zu negativen ' +
      'Geschwindigkeiten und werden abgezogen.' },

    { typ: 'text', inhalt:
      '<b>Der Vergleich lohnt sich.</b> Dieselbe Fahrt in beiden Darstellungen:' +
      '<ul>' +
      '<li>Der Stillstand zwischen 20 s und 30 s ist im Zeit-Ort-Diagramm eine <em>waagerechte Gerade</em> ' +
      '(der Ort ändert sich nicht) und im Zeit-Geschwindigkeit-Diagramm eine Linie <em>auf der Zeitachse</em> ' +
      '(die Geschwindigkeit ist null).</li>' +
      '<li>Die konstante Fahrt ist im Zeit-Ort-Diagramm eine <em>schräge</em> Gerade, im ' +
      'Zeit-Geschwindigkeit-Diagramm eine <em>waagerechte</em>. Beides bedeutet gleichförmig.</li>' +
      '</ul>' },

    { typ: 'diagramm', spez: {
        titel: 'Dieselbe Fahrt im Zeit-Ort-Diagramm',
        beschreibung: 'Der Ort steigt zunächst geradlinig auf 240 Meter, bleibt dann 10 Sekunden lang ' +
          'konstant und steigt danach flacher weiter bis 360 Meter.',
        breite: 620, hoehe: 280,
        xBereich: [0, 48], yBereich: [0, 400],
        xTitel: 't in s', yTitel: 'x in m',
        kurven: [{ punkte: [[0, 0], [20, 240], [30, 240], [45, 360]], farbe: '#2c6e49' }],
        unterschrift: 'Zum Vergleich: der Knick bei 20 s und der flachere Anstieg ab 30 s entsprechen ' +
          'genau den Abschnitten im Zeit-Geschwindigkeit-Diagramm.'
      } },

    { typ: 'fehlvorstellung',
      behauptung: 'Eine waagerechte Linie im Diagramm heißt: Der Körper steht still.',
      pruefung: 'Das kommt darauf an, welches Diagramm vorliegt. Im Zeit-Ort-Diagramm stimmt es — der ' +
        'Ort ändert sich nicht. Im Zeit-Geschwindigkeit-Diagramm bedeutet dieselbe waagerechte Linie das ' +
        'Gegenteil: Die Geschwindigkeit ist konstant, der Körper fährt also gleichmäßig weiter. Nur eine ' +
        'waagerechte Linie <em>auf Höhe null</em> heißt dort Stillstand.',
      richtig: 'Die Form allein sagt nichts. Erst die Achsenbeschriftung legt fest, was eine Linie ' +
        'bedeutet. Gewöhne dir an, vor jeder Deutung laut mitzulesen: „senkrecht steht x in Meter" ' +
        'oder „senkrecht steht v in Meter pro Sekunde".' },

    { typ: 'frage',
      text: 'Ein Fahrzeug fährt 10 s lang mit 15 m/s, danach 10 s lang mit 5 m/s. ' +
            'Welche Strecke legt es insgesamt zurück?',
      optionen: [
        { text: '200 m', richtig: true,
          rueckmeldung: 'Zwei Rechtecke: $15 * 10 = 150 "m"$ und $5 * 10 = 50 "m"$, zusammen 200 m.' },
        { text: '100 m', richtig: false,
          rueckmeldung: 'Hier wurde mit der mittleren Geschwindigkeit 10 m/s gerechnet, aber nur die ' +
            'halbe Gesamtzeit verwendet. Die Gesamtzeit beträgt 20 s.' },
        { text: '400 m', richtig: false,
          rueckmeldung: 'Vermutlich wurden beide Geschwindigkeiten mit der <em>Gesamtzeit</em> von 20 s ' +
            'multipliziert. Jede Geschwindigkeit gilt aber nur für ihren eigenen Abschnitt.' }
      ] }
  ]
},

/* ================================================================= LE 7 */
{
  id: 'm1-le7',
  modul: 'm1',
  titel: 'Eine Messreihe auswerten',
  dauer: 15,
  kompetenzen: ['E2', 'E4', 'E5', 'E7', 'K1'],
  leitfrage: 'Fünf Messwerte, fünf leicht verschiedene Geschwindigkeiten. Welche ist die richtige?',
  bausteine: [
    { typ: 'text', inhalt:
      'Keine einzelne — und das ist der Normalfall. Messwerte streuen immer. Der Umgang damit gehört zur ' +
      'Physik genauso wie die Formel, und er wird in Klausuren regelmäßig geprüft.' },

    { typ: 'experiment',
      frage: 'Fährt ein angetriebener Wagen auf der Fahrbahn wirklich gleichförmig?',
      aufbau: 'Fahrbahn mit Maßband, angetriebener Wagen mit konstanter Motordrehzahl, fünf ' +
        'Lichtschranken im Abstand von 20 cm, elektronische Zeitmessung mit gemeinsamem Startsignal.',
      messgroessen: 'Ort x in Metern (fest vorgegeben durch die Schrankenpositionen) und die zugehörige ' +
        'Zeit t in Sekunden.',
      durchfuehrung: 'Wagen mehrfach von derselben Startmarke lösen, damit die Anlaufphase vor der ersten ' +
        'Schranke abgeschlossen ist. Mindestens drei Durchläufe, damit sichtbar wird, wie stark die ' +
        'Werte streuen.',
      auswertung: 'Wertepaare in ein Zeit-Ort-Diagramm eintragen, Ausgleichsgerade anlegen, Steigung mit ' +
        'einem großen Steigungsdreieck bestimmen. Die Steigung ist die gesuchte Geschwindigkeit.',
      fehlerquellen: 'Ansprechverzögerung der Lichtschranken, ungenaue Positionierung der Schranken ' +
        '(±2 mm), schwankende Batteriespannung des Antriebs, Reibung, nicht ganz waagerechte Fahrbahn.',
      varianten: [
        'Ohne Lichtschranken: Video mit dem Handy aufnehmen (möglichst 60 Bilder pro Sekunde, Maßstab ' +
        'im Bild) und bildweise auswerten.',
        'Mit einer Stoppuhr-App und Markierungen am Boden — deutlich ungenauer, dafür ohne Ausrüstung; ' +
        'gut geeignet, um die Reaktionszeit als Fehlerquelle zu diskutieren.',
        'Beschleunigungssensor des Handys mitlaufen lassen und prüfen, ob er während der Fahrt ' +
        'tatsächlich näherungsweise null anzeigt.'
      ] },

    { typ: 'text', inhalt:
      'Ein solcher Durchlauf hat die folgenden Werte geliefert. Es handelt sich um eine ' +
      '<b>simulierte Messreihe</b> mit realistischer Streuung — sie ersetzt nicht das eigene Experiment, ' +
      'sondern macht die Auswertung übbar.' },

    { typ: 'tabelle', spez: {
        beschriftung: 'Simulierte Messreihe: Ort und Zeit eines angetriebenen Wagens',
        spalten: ['Messung', 'x in m', 't in s', 'x/t in m/s'],
        zeilen: [
          ['1', '0,00', '0,00', '—'],
          ['2', '0,20', '0,49', '0,41'],
          ['3', '0,40', '0,94', '0,43'],
          ['4', '0,60', '1,44', '0,42'],
          ['5', '0,80', '1,91', '0,42'],
          ['6', '1,00', '2,37', '0,42']
        ]
      } },

    { typ: 'diagramm', spez: {
        titel: 'Zeit-Ort-Diagramm der Messreihe mit Ausgleichsgerade',
        beschreibung: 'Sechs Messpunkte liegen nahezu auf einer Geraden durch den Ursprung. Die ' +
          'Ausgleichsgerade hat eine Steigung von etwa 0,42 Meter pro Sekunde.',
        breite: 620, hoehe: 320,
        xBereich: [0, 2.6], yBereich: [0, 1.15],
        xTitel: 't in s', yTitel: 'x in m',
        kurven: [
          { punkte: [[0, 0], [0.49, 0.20], [0.94, 0.40], [1.44, 0.60], [1.91, 0.80], [2.37, 1.00]],
            art: 'punkte', farbe: '#1f5f8b', fehlerbalken: 0.012 },
          { punkte: [[0, -0.002], [2.5, 1.052]], farbe: '#9c3229', name: 'Ausgleichsgerade' }
        ],
        unterschrift: 'Die Ausgleichsgerade wird so gelegt, dass die Punkte möglichst gleichmäßig ' +
          'darüber und darunter liegen. Sie muss nicht durch einen einzelnen Messpunkt gehen.'
      } },

    { typ: 'text', inhalt:
      '<b>Die Steigung ablesen.</b> Mit einem großen Steigungsdreieck von $t = 0 "s"$ bis $t = 2,4 "s"$ ' +
      'liest man eine Ortsänderung von rund 1,01 m ab:' },

    { typ: 'formel', quelle: 'v = Δx / Δt = 1,01 "m" / 2,4 "s" ≈ 0,42 "m/s"',
      hinweis: 'Die Einzelwerte der Tabelle liegen zwischen 0,41 m/s und 0,43 m/s. Die Ausgleichsgerade ' +
        'nutzt alle Messpunkte gleichzeitig und ist deshalb belastbarer als jeder Einzelwert.' },

    { typ: 'merksatz', inhalt:
      '<b>Signifikante Stellen.</b> Die Zeiten wurden auf Hundertstelsekunden gemessen, die Streuung der ' +
      'Einzelwerte liegt bei etwa 2 %. Ein Ergebnis von „0,4214 m/s" wäre eine Genauigkeit, die die ' +
      'Messung nicht hergibt. Sinnvoll sind zwei geltende Ziffern: $v ≈ 0,42 "m/s"$. Die Faustregel: ' +
      'Das Ergebnis wird nicht genauer angegeben als der ungenaueste Messwert, der hineingeflossen ist.' },

    { typ: 'text', inhalt:
      '<b>Und was ist mit dem Modell?</b> Dass die Punkte fast exakt auf einer Geraden liegen, ist die ' +
      'eigentliche Antwort auf die Ausgangsfrage: Die Bewegung ist im untersuchten Bereich gleichförmig. ' +
      'Bei genauerem Hinsehen würde man Abweichungen finden — Reibung und nachlassende Batteriespannung ' +
      'wirken sich aus. Ein Modell ist nie „richtig", sondern brauchbar in einem bestimmten Bereich. ' +
      'Diese Einschränkung mit anzugeben, gehört zu einer vollständigen Auswertung.' },

    { typ: 'sprache', zeilen: [
      { alltag: '„Der Versuch ist ungenau."',
        fach: 'Die Messwerte streuen um ±0,01 m/s; das entspricht etwa 2 % des Messwerts.' },
      { alltag: '„Da war ein Messfehler."',
        fach: 'Besser benennen, welcher: eine <em>systematische</em> Abweichung (Lichtschranke löst immer ' +
          'zu spät aus) oder eine <em>zufällige</em> Streuung (Ablesen, Positionierung).' },
      { alltag: '„Die Formel stimmt nicht."',
        fach: 'Das Modell der gleichförmigen Bewegung beschreibt die Messung im untersuchten Bereich ' +
          'gut; außerhalb sind Abweichungen zu erwarten.' }
    ] }
  ]
}

);
