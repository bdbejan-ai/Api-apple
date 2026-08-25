/* tests.js — Prüfungen der Aufgaben-Engine und der Inhaltsdaten.
 * Läuft ohne Werkzeugkette: tests/test.html im Browser öffnen. */
(function () {
  'use strict';

  var P = window.Physik;
  var ergebnisse = [];

  function pruefe(name, bedingung, zusatz) {
    ergebnisse.push({ name: name, ok: !!bedingung, zusatz: zusatz || '' });
  }
  function gleich(name, ist, soll) {
    pruefe(name, ist === soll, 'erwartet ' + JSON.stringify(soll) + ', bekommen ' + JSON.stringify(ist));
  }
  function nahe(name, ist, soll, schranke) {
    var ok = typeof ist === 'number' && Math.abs(ist - soll) <= (schranke || 1e-6);
    pruefe(name, ok, 'erwartet ≈' + soll + ', bekommen ' + ist);
  }
  function enthaelt(name, text, teil) {
    pruefe(name, String(text).indexOf(teil) >= 0, 'suchte „' + teil + '" in ' + text);
  }

  /* ================================ Formel ================================ */
  var F = P.Formel;

  enthaelt('Formel: Variable wird kursiv gesetzt', F.inline('v'), 'class="var"');
  enthaelt('Formel: Bruch erzeugt Zähler', F.inline('v = s / t'), 'class="zaehler"');
  enthaelt('Formel: Bruch erzeugt Nenner', F.inline('v = s / t'), 'class="nenner"');
  enthaelt('Formel: Malzeichen wird zum Malpunkt', F.inline('a * b'), '·');
  enthaelt('Formel: Exponent wird hochgestellt', F.inline('t^2'), '<sup>2</sup>');
  enthaelt('Formel: Index wird tiefgestellt', F.inline('v_0'), '<sub>0</sub>');
  enthaelt('Formel: Einheit in Anführungszeichen bleibt aufrecht',
    F.inline('50 "km/h"'), 'class="einheit">km/h');
  enthaelt('Formel: Delta wird aufrecht gesetzt', F.inline('Δx'), 'class="einheit">Δ');
  enthaelt('Formel: Delta trennt die Größe ab', F.inline('Δx'), 'class="var">x');
  enthaelt('Formel: Wurzel erzeugt Überstrich', F.inline('sqrt(2*a*s)'), 'class="wurzel"');
  enthaelt('Formel: Vektorpfeil', F.inline('vec(F)'), 'class="vektor"');
  enthaelt('Formel: Kleinergleich wird ersetzt', F.inline('a <= b'), '≤');
  enthaelt('Formel: Minus wird zum Minuszeichen', F.inline('a - b'), '−');
  pruefe('Formel: Zahl mit Dezimalkomma bleibt zusammen',
    F.inline('9,81').indexOf('9,81') >= 0, F.inline('9,81'));
  pruefe('Formel: keine offenen Tags bei verschachteltem Bruch',
    F.inline('v = (a + b) / (c - d)').indexOf('undefined') < 0);
  enthaelt('Formel: Dollarzeichen im Fließtext werden gesetzt',
    F.imText('Es gilt $v = s / t$ immer.'), 'class="formel"');
  gleich('Formel: Text ohne Dollarzeichen bleibt unverändert',
    F.imText('Nur Text.'), 'Nur Text.');

  /* ================================ Einheiten ================================ */
  var E = P.Einheiten;

  var z1 = E.zerlegen('13,9 m/s');
  nahe('Einheiten: Dezimalkomma wird gelesen', z1.zahl, 13.9);
  gleich('Einheiten: Einheit wird abgetrennt', z1.einheit, 'm/s');
  gleich('Einheiten: Punkt als Trennzeichen erlaubt', E.zerlegen('13.9 m/s').einheit, 'm/s');
  nahe('Einheiten: Zahl mit Punkt', E.zerlegen('13.9 m/s').zahl, 13.9);
  gleich('Einheiten: Leerzeichen ist optional', E.zerlegen('50km/h').einheit, 'km/h');
  gleich('Einheiten: hochgestellte Zwei wird normiert', E.normschreibweise('m/s²'), 'm/s^2');
  gleich('Einheiten: kmh wird als km/h gelesen', E.normschreibweise('kmh'), 'km/h');
  gleich('Einheiten: fehlende Einheit ergibt leeren String', E.zerlegen('42').einheit, '');
  pruefe('Einheiten: leere Eingabe ist unlesbar', E.zerlegen('') === null);
  pruefe('Einheiten: reiner Text ist unlesbar', E.zerlegen('keine Ahnung') === null);
  nahe('Einheiten: negative Zahl', E.zerlegen('-10 m/s').zahl, -10);

  nahe('Einheiten: km/h nach m/s', E.nachBasis(90, 'km/h').wert, 25, 1e-9);
  nahe('Einheiten: min nach s', E.nachBasis(5, 'min').wert, 300, 1e-9);
  nahe('Einheiten: km nach m', E.nachBasis(3.6, 'km').wert, 3600, 1e-9);
  gleich('Einheiten: Größenart wird erkannt', E.nachBasis(1, 'km/h').groesse, 'Geschwindigkeit');

  gleich('Prüfen: richtige Antwort', E.pruefen('25 m/s', 25, 'm/s').status, 'richtig');
  gleich('Prüfen: gleiche Größe in anderer Einheit ist richtig',
    E.pruefen('90 km/h', 25, 'm/s').status, 'richtig');
  gleich('Prüfen: Einheit fehlt', E.pruefen('25', 25, 'm/s').status, 'einheit_fehlt');
  pruefe('Prüfen: fehlende Einheit meldet richtige Zahl',
    E.pruefen('25', 25, 'm/s').zahlStimmt === true);
  gleich('Prüfen: falsche Größenart', E.pruefen('25 m', 25, 'm/s').status, 'einheit_falsch');
  gleich('Prüfen: verwechselte Einheit wird erkannt',
    E.pruefen('90 m/s', 25, 'm/s').status, 'einheit_verwechselt');
  gleich('Prüfen: verwechselte Einheit nennt die passende',
    E.pruefen('90 m/s', 25, 'm/s').zahlPasstZu, 'km/h');
  gleich('Prüfen: falscher Zahlenwert', E.pruefen('30 m/s', 25, 'm/s').status, 'zahl_falsch');
  gleich('Prüfen: unlesbare Eingabe', E.pruefen('weiß nicht', 25, 'm/s').status, 'unlesbar');
  gleich('Prüfen: unbekannte Einheit', E.pruefen('25 furlong', 25, 'm/s').status, 'einheit_unbekannt');
  gleich('Prüfen: Toleranz greift', E.pruefen('7,69 m/s', 7.6923, 'm/s', 0.02).status, 'richtig');
  gleich('Prüfen: außerhalb der Toleranz', E.pruefen('8,5 m/s', 7.6923, 'm/s', 0.02).status, 'zahl_falsch');

  gleich('Formatieren: deutsches Komma', E.formatieren(13.888, 1), '13,9');
  gleich('Formatieren: große Zahl ohne Nachkommastellen', E.formatieren(240), '240');

  /* ================================ Diagramm ================================ */
  var D = P.Diagramm;
  var ag = D.ausgleichsgerade([[0, 0], [0.49, 0.20], [0.94, 0.40], [1.44, 0.60], [1.91, 0.80], [2.37, 1.00]]);
  nahe('Diagramm: Ausgleichsgerade trifft die Messreihe', ag.steigung, 0.4214, 0.002);
  nahe('Diagramm: Achsenabschnitt nahe null', ag.achsenabschnitt, 0, 0.01);
  nahe('Diagramm: Schrittweite ist eine runde Zahl', D.schrittweite(100, 5), 20, 1e-9);
  pruefe('Diagramm: Markenliste beginnt im Bereich', D.marken(0, 10, 5)[0] === 0);
  enthaelt('Diagramm: SVG trägt eine Beschreibung',
    D.zeichnen({ xBereich: [0, 1], yBereich: [0, 1], beschreibung: 'Testkurve', kurven: [] }), 'Testkurve');
  enthaelt('Diagramm: SVG ist als Bild ausgezeichnet',
    D.zeichnen({ xBereich: [0, 1], yBereich: [0, 1], kurven: [] }), 'role="img"');

  /* ================================ Aufgaben-Engine ================================ */
  var A = P.Aufgaben;

  var rechenAufgabe = {
    typ: 'rechnung', loesung: { wert: 25, einheit: 'm/s', toleranz: 0.02 },
    fehleranalyse: [{ wert: 324, einheit: 'm/s', ursache: 'Mit 3,6 multipliziert', hinweis: 'Teile stattdessen.' }]
  };
  pruefe('Engine: richtige Rechnung wird angenommen', A.pruefen(rechenAufgabe, '25 m/s').richtig === true);
  pruefe('Engine: Einheitenfehler gilt nicht als richtig', A.pruefen(rechenAufgabe, '25').richtig === false);
  gleich('Engine: fehlende Einheit wird als teilweise gewertet',
    A.pruefen(rechenAufgabe, '25').art, 'teilweise');
  enthaelt('Engine: bekannter Denkfehler wird benannt',
    A.pruefen(rechenAufgabe, '324 m/s').text, 'Mit 3,6 multipliziert');
  enthaelt('Engine: verwechselte Einheit wird erklärt',
    A.pruefen(rechenAufgabe, '90 m/s').text, 'km/h');

  var mcAufgabe = {
    typ: 'mc',
    optionen: [{ text: 'a', richtig: true, rueckmeldung: 'stimmt' },
               { text: 'b', richtig: false, rueckmeldung: 'stimmt nicht' }]
  };
  pruefe('Engine: richtige Auswahl', A.pruefen(mcAufgabe, 0).richtig === true);
  pruefe('Engine: falsche Auswahl', A.pruefen(mcAufgabe, 1).richtig === false);
  enthaelt('Engine: Rückmeldung der gewählten Option erscheint', A.pruefen(mcAufgabe, 1).text, 'stimmt nicht');
  gleich('Engine: keine Auswahl wird nicht als falsch gewertet', A.pruefen(mcAufgabe, null).art, 'teilweise');

  var mehrfach = {
    typ: 'mehrfach',
    optionen: [{ text: 'a', richtig: true }, { text: 'b', richtig: false }, { text: 'c', richtig: true }]
  };
  pruefe('Engine: alle richtigen gewählt', A.pruefen(mehrfach, [0, 2]).richtig === true);
  gleich('Engine: eine fehlt → teilweise', A.pruefen(mehrfach, [0]).art, 'teilweise');
  pruefe('Engine: falsche dabei → falsch', A.pruefen(mehrfach, [0, 1, 2]).richtig === false);

  var zuordnung = {
    typ: 'zuordnung', auswahl: ['x', 'y'],
    paare: [{ frage: 'f1', loesung: 0 }, { frage: 'f2', loesung: 1 }]
  };
  pruefe('Engine: Zuordnung vollständig richtig', A.pruefen(zuordnung, { 0: 0, 1: 1 }).richtig === true);
  gleich('Engine: Zuordnung halb richtig', A.pruefen(zuordnung, { 0: 0, 1: 0 }).art, 'teilweise');

  pruefe('Engine: freie Aufgabe wertet sich nicht selbst',
    A.pruefen({ typ: 'frei' }, null).richtig === null);

  /* ================================ Fortschritt ================================ */
  var FS = P.Fortschritt;
  FS.loeschen();
  gleich('Fortschritt: Wiedervorlage nach Fehler beträgt einen Tag',
    FS._abstandTage({ richtig: false, fehlversuche: 1 }), 1);
  gleich('Fortschritt: nach Fehler doch gelöst → drei Tage',
    FS._abstandTage({ richtig: true, fehlversuche: 1 }), 3);
  gleich('Fortschritt: auf Anhieb gelöst → zehn Tage',
    FS._abstandTage({ richtig: true, fehlversuche: 0 }), 10);

  FS.ergebnisMerken('test-a1', true);
  FS.ergebnisMerken('test-a2', false);
  gleich('Fortschritt: Ergebnis wird gemerkt', FS.aufgabenStand('test-a1').richtig, true);
  gleich('Fortschritt: Fehlversuch wird gezählt', FS.aufgabenStand('test-a2').fehlversuche, 1);
  var stand = FS.modulStand(['test-a1', 'test-a2', 'test-a3']);
  gleich('Fortschritt: gelöste Aufgaben werden gezählt', stand.geloest, 1);
  gleich('Fortschritt: unbearbeitete zählen zur Gesamtzahl', stand.gesamt, 3);
  gleich('Fortschritt: nie bearbeitete werden gefunden',
    FS.nieBearbeitet(['test-a1', 'test-a3']).length, 1);
  pruefe('Fortschritt: Export ist gültiges JSON',
    (function () { try { JSON.parse(FS.exportieren()); return true; } catch (f) { return false; } })());
  FS.loeschen();
  gleich('Fortschritt: Löschen entfernt alles', FS.aufgabenStand('test-a1'), null);

  /* ================================ Inhalte ================================ */
  var I = P.Inhalt;
  var STUFEN = ['basis', 'standard', 'vertiefung'];
  var alleAufgaben = I.aufgaben.m1 || [];
  var alleEinheiten = I.lerneinheiten.m1 || [];

  pruefe('Inhalt: M1 hat Lerneinheiten', alleEinheiten.length >= 5, alleEinheiten.length + ' Einheiten');
  pruefe('Inhalt: M1 hat mindestens zwölf Aufgaben', alleAufgaben.length >= 12,
    alleAufgaben.length + ' Aufgaben');

  STUFEN.forEach(function (stufe) {
    var n = alleAufgaben.filter(function (a) { return a.niveau === stufe; }).length;
    pruefe('Inhalt: mindestens vier Aufgaben auf Stufe ' + stufe, n >= 4, n + ' gefunden');
  });

  ['UF', 'E', 'K', 'B'].forEach(function (bereich) {
    var vorhanden = alleAufgaben.some(function (a) {
      return (a.kompetenz || []).some(function (k) { return k.replace(/[0-9]/g, '') === bereich; });
    });
    pruefe('Inhalt: Kompetenzbereich ' + bereich + ' kommt vor', vorhanden);
  });

  var kennungen = {};
  alleAufgaben.forEach(function (a) {
    pruefe('Inhalt: ' + a.id + ' hat eine eindeutige Kennung', !kennungen[a.id]);
    kennungen[a.id] = true;
    pruefe('Inhalt: ' + a.id + ' hat einen Operator', !!a.operator);
    pruefe('Inhalt: ' + a.id + ' hat einen Anforderungsbereich', a.afb >= 1 && a.afb <= 3);
    pruefe('Inhalt: ' + a.id + ' hat eine Niveaustufe', STUFEN.indexOf(a.niveau) >= 0);
    pruefe('Inhalt: ' + a.id + ' hat Kompetenzangaben', (a.kompetenz || []).length > 0);
    pruefe('Inhalt: ' + a.id + ' hat einen Lösungsweg', (a.weg || []).length >= 3);
    pruefe('Inhalt: ' + a.id + ' hat drei gestufte Hilfen', (a.hilfen || []).length === 3,
      (a.hilfen || []).length + ' Hilfen');
    pruefe('Inhalt: ' + a.id + ' hat eine Fehleranalyse', (a.fehleranalyse || []).length >= 1);
    pruefe('Inhalt: ' + a.id + ' hat eine Zeitangabe', typeof a.zeit === 'number' && a.zeit > 0);

    if (a.typ === 'rechnung') {
      pruefe('Inhalt: ' + a.id + ' hat einen Lösungswert', typeof a.loesung.wert === 'number');
      pruefe('Inhalt: ' + a.id + ' nutzt eine bekannte Einheit', E.kennt(a.loesung.einheit),
        a.loesung.einheit);
      pruefe('Inhalt: ' + a.id + ' — eigene Lösung besteht die Prüfung',
        A.pruefen(a, E.formatieren(a.loesung.wert, 4) + ' ' + a.loesung.einheit).richtig === true);
      (a.fehleranalyse || []).forEach(function (f) {
        if (typeof f.wert !== 'number') return;
        pruefe('Inhalt: ' + a.id + ' — Fehlerwert ' + f.wert + ' gilt nicht als richtig',
          A.pruefen(a, f.wert + ' ' + (f.einheit || a.loesung.einheit)).richtig === false);
      });
    }
    if (a.typ === 'mc' || a.typ === 'mehrfach') {
      var richtige = a.optionen.filter(function (o) { return o.richtig; }).length;
      pruefe('Inhalt: ' + a.id + ' hat mindestens eine richtige Option', richtige >= 1);
      if (a.typ === 'mc') pruefe('Inhalt: ' + a.id + ' hat genau eine richtige Option', richtige === 1);
      a.optionen.forEach(function (o, i) {
        pruefe('Inhalt: ' + a.id + ' Option ' + (i + 1) + ' hat eine Rückmeldung', !!o.rueckmeldung);
      });
    }
  });

  alleEinheiten.forEach(function (le) {
    pruefe('Inhalt: ' + le.id + ' hat eine Leitfrage', !!le.leitfrage);
    pruefe('Inhalt: ' + le.id + ' hat eine Dauer zwischen 8 und 20 min',
      le.dauer >= 8 && le.dauer <= 20, le.dauer + ' min');
    pruefe('Inhalt: ' + le.id + ' hat Bausteine', (le.bausteine || []).length >= 3);
    pruefe('Inhalt: ' + le.id + ' hat Kompetenzangaben', (le.kompetenzen || []).length > 0);
  });

  var fehlvorstellungen = 0, simulationen = 0, experimente = 0;
  alleEinheiten.forEach(function (le) {
    le.bausteine.forEach(function (b) {
      if (b.typ === 'fehlvorstellung') fehlvorstellungen++;
      if (b.typ === 'simulation') simulationen++;
      if (b.typ === 'experiment') experimente++;
    });
  });
  pruefe('Inhalt: mindestens drei Fehlvorstellungen werden behandelt', fehlvorstellungen >= 3,
    fehlvorstellungen + ' gefunden');
  pruefe('Inhalt: mindestens eine Simulation ist eingebunden', simulationen >= 1);
  pruefe('Inhalt: mindestens ein Experiment ist beschrieben', experimente >= 1);
  alleEinheiten.forEach(function (le) {
    le.bausteine.forEach(function (b) {
      if (b.typ !== 'simulation') return;
      pruefe('Inhalt: Simulation „' + b.name + '" ist vorhanden',
        P.Simulation.verfuegbar.indexOf(b.name) >= 0);
    });
  });

  I.module.forEach(function (m) {
    pruefe('Inhalt: Modul ' + m.kuerzel + ' hat Kerninhalte', (m.kerninhalte || []).length >= 3);
    pruefe('Inhalt: Modul ' + m.kuerzel + ' ist als gefüllt oder leer gekennzeichnet',
      typeof m.gefuellt === 'boolean');
  });

  /* ================================ Ausgabe ================================ */
  window.TESTERGEBNIS = ergebnisse;
  var fehler = ergebnisse.filter(function (e) { return !e.ok; });

  var ziel = document.getElementById('ausgabe');
  if (ziel) {
    ziel.innerHTML =
      '<p id="zusammenfassung" class="' + (fehler.length ? 'rot' : 'gruen') + '">' +
      (ergebnisse.length - fehler.length) + ' von ' + ergebnisse.length + ' Prüfungen bestanden' +
      (fehler.length ? ' — ' + fehler.length + ' FEHLGESCHLAGEN' : ' — alles grün') + '</p>' +
      '<ul>' + ergebnisse.map(function (e) {
        return '<li class="' + (e.ok ? 'gruen' : 'rot') + '">' + (e.ok ? '✓' : '✗') + ' ' +
          e.name + (e.ok ? '' : ' <span class="zusatz">(' + e.zusatz + ')</span>') + '</li>';
      }).join('') + '</ul>';
  }
})();
