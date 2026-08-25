/* module.js — Modulübersicht des Inhaltsfelds Mechanik (Einführungsphase).
 *
 * ACHTUNG, VOR DEM UNTERRICHTSEINSATZ PRÜFEN: Die Zuordnung der Schwerpunkte
 * zum Inhaltsfeld ist nach fachlicher Logik aufgebaut und noch nicht gegen den
 * geltenden Kernlehrplan bzw. den schulinternen Lehrplan abgeglichen worden.
 * Betroffen sind vor allem Reihenfolge und Schnitt zwischen M6, M7 und M8.
 */
window.Physik = window.Physik || {};
Physik.Inhalt = Physik.Inhalt || { module: [], lerneinheiten: {}, aufgaben: {} };

Physik.Inhalt.module = [
  {
    id: 'm1', kuerzel: 'M1', titel: 'Bewegungen beschreiben', kontext: 'Straßenverkehr',
    gefuellt: true,
    kurz: 'Bezugssystem, Ort und Weg, mittlere und momentane Geschwindigkeit, gleichförmige Bewegung, ' +
          'Zeit-Ort- und Zeit-Geschwindigkeit-Diagramm.',
    kerninhalte: [
      'Bezugssystem und Ortsangabe auf einer Achse',
      'Strecke, Verschiebung, Zeitpunkt und Zeitspanne in Δ-Schreibweise',
      'mittlere Geschwindigkeit und Einheitenumrechnung',
      'gleichförmige Bewegung im Zeit-Ort-Diagramm',
      'momentane Geschwindigkeit als Tangentensteigung',
      'Fläche im Zeit-Geschwindigkeit-Diagramm',
      'Messreihe aufnehmen und mit Ausgleichsgerade auswerten'
    ]
  },
  {
    id: 'm2', kuerzel: 'M2', titel: 'Beschleunigte Bewegung', kontext: 'Straßenverkehr',
    gefuellt: false,
    kurz: 'Beschleunigung als Änderungsrate, gleichmäßig beschleunigte Bewegung, freier Fall, ' +
          'Reaktions-, Brems- und Anhalteweg.',
    kerninhalte: [
      'Beschleunigung als Änderungsrate der Geschwindigkeit',
      'Herleitung von v(t) und x(t) aus dem Zeit-Geschwindigkeit-Diagramm',
      'freier Fall und Fallbeschleunigung',
      'Reaktionsweg, Bremsweg, Anhalteweg',
      'Vorzeichen bei Verzögerung'
    ]
  },
  {
    id: 'm3', kuerzel: 'M3', titel: 'Zusammengesetzte Bewegungen', kontext: 'Sport',
    gefuellt: false,
    kurz: 'Unabhängigkeitsprinzip, Überlagerung, waagerechter Wurf, Bahnkurve; ' +
          'als Vertiefung der schiefe Wurf.',
    kerninhalte: [
      'Unabhängigkeitsprinzip',
      'Zerlegung in waagerechte und senkrechte Komponente',
      'waagerechter Wurf und Wurfparabel',
      'schiefer Wurf und Wurfweite (Vertiefung)'
    ]
  },
  {
    id: 'm4', kuerzel: 'M4', titel: 'Kräfte und Newtonsche Gesetze', kontext: 'Verkehr und Sport',
    gefuellt: false,
    kurz: 'Kraft als Vektor, Trägheitssatz, Grundgleichung, Wechselwirkungsprinzip, ' +
          'Freikörperbild, geneigte Ebene, Reibung, Hookesches Gesetz.',
    kerninhalte: [
      'Kraft als gerichtete Größe, Kräfteaddition und -zerlegung',
      'Trägheitssatz, Grundgleichung F = m·a, Wechselwirkungsprinzip',
      'Freikörperbild als Arbeitsmittel',
      'geneigte Ebene und Hangabtriebskraft',
      'Reibungskraft, Hookesches Gesetz',
      'Masse und Gewichtskraft unterscheiden'
    ]
  },
  {
    id: 'm5', kuerzel: 'M5', titel: 'Arbeit, Energie, Leistung', kontext: 'Sport',
    gefuellt: false,
    kurz: 'Arbeit bei schräg wirkender Kraft, Energieformen der Mechanik, Energieerhaltung als Bilanz, ' +
          'Dissipation, Leistung und Wirkungsgrad.',
    kerninhalte: [
      'Arbeit als Produkt aus Kraftkomponente und Weg',
      'Hub-, Beschleunigungs- und Spannarbeit',
      'kinetische, potenzielle und Spannenergie',
      'Energieerhaltung als Bilanz über ein System',
      'Dissipation, Leistung, Wirkungsgrad'
    ]
  },
  {
    id: 'm6', kuerzel: 'M6', titel: 'Impuls und Stöße', kontext: 'Fahrzeugsicherheit',
    gefuellt: false,
    kurz: 'Impuls als gerichtete Größe, Impulserhaltung, elastischer und unelastischer Stoß, ' +
          'Kraftstoß und Fahrzeugsicherheit.',
    kerninhalte: [
      'Impuls p = m·v als gerichtete Größe',
      'Impulserhaltung im abgeschlossenen System',
      'elastischer und unelastischer Stoß',
      'Kraftstoß F·Δt und Knautschzone, Gurt, Airbag'
    ]
  },
  {
    id: 'm7', kuerzel: 'M7', titel: 'Kreisbewegung', kontext: 'Verkehr und Sport',
    gefuellt: false,
    kurz: 'Umlaufdauer und Frequenz, Bahn- und Winkelgeschwindigkeit, Zentripetalbeschleunigung ' +
          'und -kraft, Kurvenfahrt, Bezugssystemfrage bei der „Fliehkraft".',
    kerninhalte: [
      'Umlaufdauer, Frequenz, Bahn- und Winkelgeschwindigkeit',
      'Zentripetalbeschleunigung und Zentripetalkraft',
      'Kurvenfahrt und überhöhte Kurve',
      'Trägheitskräfte nur im beschleunigten Bezugssystem'
    ]
  },
  {
    id: 'm8', kuerzel: 'M8', titel: 'Gravitation und Satelliten', kontext: 'Weltraum',
    gefuellt: false,
    kurz: 'Newtonsches Gravitationsgesetz, Keplersche Gesetze, Bahngeschwindigkeit, ' +
          'geostationäre Bahn, scheinbare Schwerelosigkeit.',
    kerninhalte: [
      'Newtonsches Gravitationsgesetz',
      'Keplersche Gesetze',
      'Bahngeschwindigkeit und Umlaufdauer',
      'geostationäre Bahn',
      'scheinbare Schwerelosigkeit als freier Fall'
    ]
  }
];

/* Der Querschnitt „Messen und Auswerten" ist kein eigenes Modul, sondern läuft
   in jedem Modul mit. In M1 steckt er in der Lerneinheit „Eine Messreihe auswerten". */
Physik.Inhalt.querschnitt = {
  titel: 'Messen und Auswerten',
  kurz: 'Messreihe, Messunsicherheit, signifikante Stellen, Diagramme anlegen, Ausgleichsgerade, ' +
        'Steigung mit Einheit deuten, Modell und Wirklichkeit unterscheiden.',
  verteiltAuf: 'läuft in allen Modulen mit'
};

Physik.Inhalt.modulNach = function (id) {
  var treffer = null;
  Physik.Inhalt.module.forEach(function (m) { if (m.id === id) treffer = m; });
  return treffer;
};
