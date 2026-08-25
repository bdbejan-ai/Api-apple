# Prompt: Lernprogramm Physik – Einführungsphase NRW (LK-Anspruch)

> Diesen Text komplett in den Chat kopieren. Block 0 vorher anpassen.

---

## 0. Projektparameter (anpassen)

- **Ausgabeform:** eigenständige Web-App, HTML/CSS/JS ohne Build-Schritt, offline lauffähig durch Öffnen der `index.html`
- **Erste Ausbaustufe:** Modul 1 vollständig als Referenz + tragfähiges Gerüst für alle weiteren Module
- **Zielgeräte:** Laptop (Unterricht/Hausaufgabe) und Smartphone (Üben unterwegs) — responsiv
- **Sprache:** durchgehend Deutsch, korrekte physikalische Fachsprache
- **Repository / Branch:** `<hier eintragen>`
- **Nutzung:** Selbstlernen zu Hause, ergänzend zum Unterricht; keine Lehrer-Accounts, keine Serverkomponente

---

## 1. Rolle

Du bist zugleich

1. **Physiklehrkraft der Sekundarstufe II in Nordrhein-Westfalen** mit fachdidaktischer Ausbildung und Erfahrung im Umgang mit typischen Lernhürden der Mechanik, und
2. **erfahrene Softwareentwicklerin bzw. erfahrener Softwareentwickler** für kleine, wartbare Lern-Anwendungen.

Beide Rollen gelten gleichzeitig: fachlich falsche Inhalte in schönem Code sind ein Fehlschlag, und korrekte Inhalte in unbedienbarer Form ebenso.

## 2. Zielgruppe

- Schülerinnen und Schüler der **Einführungsphase (EF)** der gymnasialen Oberstufe in NRW (G9, Jahrgangsstufe 11).
- Sie streben den **Physik-Leistungskurs** in Q1/Q2 an bzw. wollen jetzt schon auf diesem Anspruchsniveau arbeiten. Wichtig: In der EF gibt es noch keine LK-Differenzierung. Das Programm bleibt inhaltlich auf **EF-Niveau nach Kernlehrplan**, hebt aber **Tiefe, Begründungsdichte, Mehrschrittigkeit und mathematische Sauberkeit** auf LK-Vorbereitungsniveau.
- Vorwissen aus der Sekundarstufe I: Kraft, Energie, einfache Bewegungen, Umgang mit Größen und Einheiten — jedoch lückenhaft und oft als Alltagswissen, nicht als Fachwissen.

### Mathematischer Stand (bindend)

**Verfügbar:** Termumformungen, lineare und quadratische Funktionen, Lösen quadratischer Gleichungen, Dreisatz, Prozentrechnung, Satz des Pythagoras, Trigonometrie am rechtwinkligen Dreieck, Beginn der Differenzialrechnung (Ableitung als lokale Änderungsrate).

**Nicht voraussetzen:**
- **Integralrechnung** → Flächen unter *t*-*v*-Diagrammen immer geometrisch (Rechteck, Dreieck, Trapez) erschließen, nie über ein Integralzeichen.
- **Vektorrechnung / analytische Geometrie** → Vektoren rein physikalisch einführen (Betrag + Richtung, Pfeildarstellung, Zerlegung in Komponenten über Sinus und Cosinus). Keine Skalarprodukt-Schreibweise, keine Spaltenvektoren als Voraussetzung.
- Differenzialgleichungen, Logarithmus als Werkzeug, komplexe Zahlen.

Die Ableitung als Werkzeug für die Momentangeschwindigkeit darf verwendet werden, muss aber an der Stelle, an der sie zum ersten Mal auftaucht, **physikalisch neu motiviert und erklärt** werden (Grenzprozess vom Sekanten- zum Tangentensteigungsdreieck). Wo die Ableitung noch nicht sitzt, muss ein rein grafischer Weg (Steigungsdreieck an der Tangente) als gleichwertige Alternative angeboten werden.

### Niveaustufen

Jeder Inhalt erscheint in drei Stufen, klar gekennzeichnet:
- **Basis** — Grundverständnis, kleine Zahlen, ein Rechenschritt, viel Führung
- **Standard** — Klausurniveau der EF, zwei bis drei Schritte, Kontexteinbettung
- **LK-Vertiefung** — Herleitungen, Sonderfälle, Grenzen des Modells, Fehlerbetrachtung, offene Fragestellungen, mehrschrittige Kontextaufgaben

## 3. Fachlicher Rahmen

Grundlage ist das **Inhaltsfeld Mechanik der Einführungsphase** nach dem Kernlehrplan Physik für die gymnasiale Oberstufe in NRW, mit den üblichen Kontexten **Straßenverkehr/Fahrzeugsicherheit, Sport und Weltraum/Raumfahrt**.

Modulplan (Reihenfolge ist der vorgeschlagene Lernpfad):

| # | Modul | Kerninhalte | Leitkontext |
|---|---|---|---|
| M1 | Bewegungen beschreiben | Bezugssystem, Ort/Weg/Strecke/Verschiebung, Zeitpunkt vs. Zeitspanne, Δ-Schreibweise, mittlere und momentane Geschwindigkeit, gleichförmige Bewegung, *t*-*s*- und *t*-*v*-Diagramme | Verkehr |
| M2 | Beschleunigte Bewegung | Beschleunigung als Änderungsrate, gleichmäßig beschleunigte Bewegung, Herleitung von *v*(*t*) und *s*(*t*), freier Fall, Reaktions-, Brems- und Anhalteweg | Verkehr |
| M3 | Zusammengesetzte Bewegungen | Unabhängigkeitsprinzip, Überlagerung, waagerechter Wurf, Bahnkurve; *LK-Vertiefung:* schiefer Wurf, Wurfweite | Sport |
| M4 | Kräfte und Newtonsche Gesetze | Kraft als Vektor, Trägheitssatz, Grundgleichung *F* = *m*·*a*, Wechselwirkungsprinzip, Kräfteaddition und -zerlegung, Freikörperbild, geneigte Ebene, Reibung, Hookesches Gesetz, Gewichtskraft vs. Masse | Verkehr/Sport |
| M5 | Arbeit, Energie, Leistung | Arbeit bei schräger Kraft, Hub-, Beschleunigungs- und Spannarbeit, kinetische/potenzielle/Spannenergie, Energieerhaltung als Bilanz, Dissipation, Leistung, Wirkungsgrad | Sport |
| M6 | Impuls und Stöße | Impuls als vektorielle Größe, Impulserhaltung, elastischer und unelastischer Stoß, Kraftstoß *F*·Δ*t*, Fahrzeugsicherheit (Knautschzone, Gurt, Airbag) | Verkehr |
| M7 | Kreisbewegung | Umlaufdauer und Frequenz, Bahn- und Winkelgeschwindigkeit, Zentripetalbeschleunigung und -kraft, Kurvenfahrt, Bezugssystemfrage bei der „Fliehkraft" | Verkehr/Sport |
| M8 | Gravitation und Satelliten | Newtonsches Gravitationsgesetz, Keplersche Gesetze, Bahn- und Fluchtgeschwindigkeit, geostationäre Bahn, scheinbare Schwerelosigkeit | Weltraum |
| Q | Querschnitt: Messen und Auswerten | Messreihe, Messunsicherheit, signifikante Stellen, Diagramme richtig anlegen, Ausgleichsgerade, Linearisierung, Steigung mit Einheit deuten, Modell vs. Wirklichkeit | alle |

Modul Q ist kein separates Kapitel am Ende, sondern wird **ab M1 in die Module eingewoben** und dort jeweils an einem konkreten Datensatz geübt.

**Wichtig zur Verbindlichkeit:** Diese Gliederung ist eine begründete Rekonstruktion des Inhaltsfelds. Gleiche sie zu Beginn mit dem aktuellen Kernlehrplan (Lehrplannavigator NRW) bzw. dem schulinternen Lehrplan ab, den ich dir ggf. nachreiche. Wo du dir bei einer Kernlehrplan-Zuordnung nicht sicher bist: **kennzeichne die Stelle sichtbar als zu prüfen, statt eine Formulierung zu erfinden.**

## 4. Didaktische Vorgaben

1. **Kompetenzorientierung.** Jede Lerneinheit und jede Aufgabe wird intern den Kompetenzbereichen des Kernlehrplans zugeordnet: Umgang mit Fachwissen (UF), Erkenntnisgewinnung (E), Kommunikation (K), Bewertung (B). Nicht nur UF bedienen — E-Aufgaben (Hypothese, Experimentplanung, Auswertung, Modellgrenzen) und B-Aufgaben (z. B. Tempolimit, Sicherheitsausstattung, Kosten bezahlbarer Raumfahrt) gehören verpflichtend dazu.
2. **Anforderungsbereiche.** Aufgabenserien decken AFB I (Reproduktion), II (Anwendung/Transfer) und III (Reflexion/Problemlösen) ab; das Verhältnis ist grob 3 : 5 : 2 und pro Modul ausgewiesen.
3. **Operatoren.** Nutze ausschließlich die in NRW üblichen Operatoren mit ihrer festgelegten Bedeutung: *nennen, angeben, beschreiben, skizzieren, zeichnen, berechnen, bestimmen, ermitteln, herleiten, erklären, erläutern, begründen, analysieren, auswerten, vergleichen, interpretieren, überprüfen, nachweisen, abschätzen, beurteilen, bewerten, diskutieren, entwickeln.* Der Operator muss zur erwarteten Leistung passen — „erklären" verlangt eine Ursache-Wirkungs-Kette, „begründen" ein Argument aus Fachwissen, „beurteilen" ein Kriterium. Biete an geeigneter Stelle eine kurze Operatoren-Erklärung an, weil die Schülerinnen und Schüler das aus der Sek I noch nicht sicher können.
4. **Kontexte zuerst.** Jedes Modul startet mit einer konkreten Situation oder Frage (Anhalteweg bei Regen, Sprungwurf, Kurvenüberhöhung, ISS-Umlaufzeit), aus der die physikalische Fragestellung entwickelt wird. Kein Einstieg mit einer Formel.
5. **Fehlvorstellungen aktiv angehen.** Behandle mindestens die folgenden explizit — benennen, mit einem Gegenbeispiel oder Experiment erschüttern, korrekt neu fassen, später erneut prüfen:
   - Bewegung braucht eine dauernd wirkende Kraft (aristotelische Vorstellung)
   - Geschwindigkeit und Beschleunigung werden gleichgesetzt („schnell = stark beschleunigt"); ein Körper mit *v* = 0 könne nicht beschleunigt sein
   - schwere Körper fallen schneller als leichte
   - Masse und Gewichtskraft als dasselbe; „im Weltall gibt es keine Schwerkraft"
   - actio und reactio heben sich am selben Körper auf
   - eine nach außen ziehende „Zentrifugalkraft" wirke im Inertialsystem
   - Energie werde „verbraucht"
   - beim Wurf wirke in Bewegungsrichtung eine „Vorwärtskraft" weiter
   - im *t*-*s*-Diagramm werde die Bahnkurve gesehen (Graph-als-Bild-Fehler)
6. **Darstellungswechsel** als durchgehendes Prinzip: Realsituation ↔ Skizze/Freikörperbild ↔ Diagramm ↔ Gleichung ↔ Sprache. Aufgaben, die genau diesen Wechsel verlangen, sind besonders wertvoll.
7. **Vom Experiment her denken.** Wo möglich: ein reales, mit Schulmitteln durchführbares Experiment beschreiben (Aufbau, Messgrößen, Durchführung, Auswertung, Fehlerquellen) — inklusive Varianten mit Handy-Sensor, Videoanalyse und Lichtschranke/Zeitmessung. Interaktive Simulationen ersetzen das Experiment nicht, sie ergänzen es.
8. **Sprachsensibel.** Jeder Fachbegriff wird bei der Einführung definiert; jedes Formelzeichen bekommt Bedeutung *und* Einheit. Alltags- und Fachbedeutung von „Kraft", „Arbeit", „Leistung", „Impuls", „Beschleunigung" werden ausdrücklich gegenübergestellt. Formulierungshilfen für Begründungsaufgaben anbieten („Da …, folgt aus …, dass …").
9. **Portionsgröße.** Eine Lerneinheit ist in 10–15 Minuten bearbeitbar. Lange Fließtexte werden zerlegt; nach spätestens zwei Absätzen kommt eine Handlung (Frage, Schieberegler, Skizze, Rechnung).

## 5. Aufgaben, Lösungen, Feedback

**Aufgabentypen** (gemischt einsetzen):
- Multiple Choice, bei dem **jeder Distraktor einer realen Fehlvorstellung oder einem typischen Rechenfehler entspricht** — keine Fülloptionen
- Rechenaufgaben mit Zahleneingabe, Toleranzbereich und **verpflichtender Einheitenangabe**
- Diagramme zuordnen, fortsetzen oder skizzieren
- Herleitungen in sortierbaren bzw. lückenhaften Schritten
- Abschätzungen mit begründeten Annahmen (Fermi-Aufgaben)
- Auswertung einer Messreihe inklusive Unsicherheit und Modellkritik
- mehrschrittige Kontextaufgaben im Klausurformat mit Teilaufgaben a), b), c) und steigendem AFB

**Zu jeder Aufgabe gehört zwingend:**
- ein **kommentierter Lösungsweg** im Schema *Gegeben – Gesucht – Ansatz mit Begründung – Umstellen – Einsetzen mit Einheiten – Ergebnis – Plausibilitätsprüfung* (Größenordnung, Vorzeichen, Einheit)
- **drei gestufte Hilfen**: (1) Denkanstoß/Rückfrage, (2) passender Ansatz oder Skizze, (3) erster Rechenschritt vorgemacht
- eine **Fehleranalyse**: welcher Denkfehler führt zu welchem falschen Ergebnis
- Metadaten: Modul, Niveaustufe, Kompetenzbereich, AFB, geschätzte Bearbeitungszeit

**Feedback-Regeln:**
- Nie nur „richtig" oder „falsch". Bei falscher Antwort wird der **vermutete Denkfehler benannt** und der Weg zurück gezeigt.
- Häufige Rechenfehler gesondert erkennen: Einheitenfehler (km/h vs. m/s), Faktor 2 bei *s* = ½·*a*·*t*², Vorzeichenfehler bei Verzögerung, Verwechslung von *t*-*s*- und *t*-*v*-Graph, Winkelfunktion falsch herum bei der geneigten Ebene.
- Ton: sachlich, respektvoll, ermutigend, nie herablassend, kein Lob für Trivialitäten.
- Fehler sind Arbeitsmaterial, nicht Versagen — falsch beantwortete Aufgaben kommen gezielt und zeitversetzt zurück (einfache spaced repetition genügt).

**Fortschritt:** kompaktes Kompetenzraster pro Modul („kann ich sicher / mit Hilfe / noch nicht"), Selbsteinschätzung und gemessene Leistung getrennt ausweisen, plus ein Vorschlag „Das solltest du als Nächstes üben".

## 6. Technische Vorgaben

- Umsetzung gemäß Block 0. Ohne abweichende Angabe: **reines HTML/CSS/JavaScript (ES-Module), keine Build-Kette, keine Laufzeit-Abhängigkeit von externen CDNs**; die App muss offline funktionieren.
- **Inhalte strikt vom Code trennen.** Alle Lerneinheiten und Aufgaben liegen als Daten (JSON oder klar strukturierte JS-Module) in einem eigenen Verzeichnis, sodass ich neue Aufgaben **ohne Programmierkenntnisse** ergänzen kann. Das Datenschema wird einmal dokumentiert und mit einem Beispiel erklärt.
- **Formeln** sauber gesetzt (KaTeX lokal eingebunden oder MathML); Formelzeichen kursiv, Einheiten aufrecht, Vektoren mit Pfeil.
- **Diagramme und Skizzen** als SVG oder Canvas, im Programm erzeugt — keine Platzhalterbilder, keine externen Grafiken. Interaktive Elemente (Schieberegler für *v*₀, *a*, Abwurfwinkel, Reibungszahl) mit sofortiger Rückwirkung auf Diagramm und Zahlenwerte.
- **Persistenz** ausschließlich lokal (`localStorage`), kein Konto, kein Tracking, keine Analytics, keine Übertragung personenbezogener Daten. Export und Import des Lernstands als Datei; Löschfunktion vorhanden. DSGVO-tauglich für Schülernutzung.
- **Barrierefreiheit:** vollständige Tastaturbedienung, sichtbarer Fokus, ausreichende Kontraste, sinnvolle Alternativtexte für Grafiken (physikalisch beschreibend, nicht „Diagramm"), Schriftgröße skalierbar.
- **Responsiv**, helles und dunkles Farbschema, ruhige Gestaltung ohne Ablenkung.
- **Tests** für die Aufgaben-Engine: Antwortprüfung, Toleranzen, Einheiten-Normalisierung, Fortschrittslogik. Fachinhalte werden nicht getestet, sondern von mir gegengelesen.
- Code und Kommentare in klarem Stil, Bezeichner deutsch oder englisch — aber einheitlich.

## 7. Physikalische Korrektheit (nicht verhandelbar)

- Deutsche Schreibweise: **Dezimalkomma**, Tausenderpunkt vermeiden, Zahl und Einheit durch Leerzeichen getrennt.
- *g* = 9,81 m/s² (bei Abschätzungen 10 m/s², dann ausdrücklich gesagt). Konstanten mit Wert, Einheit und sinnvoller Genauigkeit.
- **Vor jeder Rechnung mit Vorzeichen wird das Koordinatensystem festgelegt** und die Richtungswahl benannt. Verzögerung ist keine „negative Beschleunigung" ohne diesen Bezug.
- Signifikante Stellen konsistent; kein Ergebnis mit acht Nachkommastellen aus zwei gemessenen Stellen.
- Realistische Zahlenwerte (Bremsverzögerungen, Reibungszahlen, Massen, Bahnradien). Erfundene „Messwerte" sind nur zulässig, wenn sie **als simulierte Messreihe gekennzeichnet** sind und plausibel streuen.
- Idealisierungen immer benennen: Luftwiderstand vernachlässigt, Massenpunkt, reibungsfrei, homogenes Schwerefeld — und in der LK-Vertiefung hinterfragen.
- Modellgrenzen gehören zum Inhalt, nicht in eine Fußnote.
- Keine Quellen, Studien, Lehrplanzitate oder Aufgabenherkünfte erfinden. Wenn du etwas nicht sicher weißt: kennzeichnen und mich fragen.

## 8. Arbeitsweise

1. **Zuerst ein kurzer Plan** (maximal eine Bildschirmseite): Modulliste, Datenmodell einer Lerneinheit und einer Aufgabe, Dateistruktur, offene Fragen. Danach ohne weitere Rückfrage weiterarbeiten, sofern nichts Grundsätzliches offen ist.
2. **Dann Modul 1 vollständig** in Endqualität — Inhalte, Simulation, mindestens 12 Aufgaben über alle drei Niveaustufen, Lösungen, Hilfen, Feedback. Modul 1 ist die Referenz, an der alles Weitere gemessen wird.
3. **Dann Gerüst und Navigation** für M2–M8 mit ehrlich als „noch nicht befüllt" markierten Stellen — keine mit Fülltext getarnten Lücken.
4. Nach jedem Schritt: knapp berichten, was fertig ist, was bewusst offengeblieben ist, und was ich gegenlesen sollte.
5. Offene fachliche oder didaktische Entscheidungen sammelst du und stellst sie gebündelt, statt zu raten.
6. Änderungen committen und auf den in Block 0 genannten Branch pushen. Keinen Pull Request eröffnen, solange ich nicht darum bitte.

## 9. Ausdrücklich unerwünscht

- Textwüsten und Lehrbuchprosa ohne Handlungsaufforderung
- Gamification-Overkill: Konfetti, Punkte-Inflation, Maskottchen, Emojis in Fachtexten
- Aufgaben ohne vollständigen Lösungsweg
- Multiple Choice mit offensichtlich absurden Optionen
- Platzhalterinhalte (`TODO`, Blindtext) statt echter Fachinhalte
- englische Fachbegriffe, wo es einen etablierten deutschen gibt
- Vereinfachungen, die fachlich falsch werden („Zentrifugalkraft zieht den Wagen nach außen", „Energie geht verloren")
- Anbiedernde Ansprache oder Floskeln

## 10. Fertig ist es, wenn …

- [ ] Modul 1 fachlich korrekt, kontextorientiert und in 10–15-Minuten-Portionen bearbeitbar ist
- [ ] alle drei Niveaustufen mit je mindestens vier Aufgaben belegt sind
- [ ] jede Aufgabe Lösungsweg, drei gestufte Hilfen, Fehleranalyse und Metadaten hat
- [ ] mindestens drei benannte Fehlvorstellungen gezielt adressiert werden
- [ ] mindestens eine interaktive Simulation und eine Messreihen-Auswertung enthalten sind
- [ ] UF-, E-, K- und B-Aufgaben jeweils vorkommen
- [ ] die App offline startet, auf dem Handy bedienbar und per Tastatur navigierbar ist
- [ ] Inhalte ohne Code-Änderung ergänzbar und im Datenschema dokumentiert sind
- [ ] der Lernstand lokal gespeichert, exportiert und gelöscht werden kann
- [ ] die Tests der Aufgaben-Engine grün sind

---

**Beginne mit Schritt 1 aus Abschnitt 8.**
