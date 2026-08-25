/* einheiten.js — Zahl-und-Einheit-Eingaben lesen, umrechnen, vergleichen.
 *
 * Trägt die Einheitenpflicht aus dem Aufgabenteil: Eine Zahl ohne Einheit ist
 * keine physikalische Antwort. Zusätzlich wird der häufigste Fehler der EF
 * erkannt — richtig gerechnet, aber in der falschen Einheit angegeben.
 */
window.Physik = window.Physik || {};

Physik.Einheiten = (function () {
  'use strict';

  /* faktor: wie viele SI-Basiseinheiten ist eine Einheit wert */
  var TABELLE = {
    // Länge
    'm':      { faktor: 1,        groesse: 'Länge',            basis: 'm' },
    'km':     { faktor: 1000,     groesse: 'Länge',            basis: 'm' },
    'dm':     { faktor: 0.1,      groesse: 'Länge',            basis: 'm' },
    'cm':     { faktor: 0.01,     groesse: 'Länge',            basis: 'm' },
    'mm':     { faktor: 0.001,    groesse: 'Länge',            basis: 'm' },
    // Zeit
    's':      { faktor: 1,        groesse: 'Zeit',             basis: 's' },
    'ms':     { faktor: 0.001,    groesse: 'Zeit',             basis: 's' },
    'min':    { faktor: 60,       groesse: 'Zeit',             basis: 's' },
    'h':      { faktor: 3600,     groesse: 'Zeit',             basis: 's' },
    'd':      { faktor: 86400,    groesse: 'Zeit',             basis: 's' },
    // Geschwindigkeit
    'm/s':    { faktor: 1,        groesse: 'Geschwindigkeit',  basis: 'm/s' },
    'km/h':   { faktor: 1 / 3.6,  groesse: 'Geschwindigkeit',  basis: 'm/s' },
    'cm/s':   { faktor: 0.01,     groesse: 'Geschwindigkeit',  basis: 'm/s' },
    'km/s':   { faktor: 1000,     groesse: 'Geschwindigkeit',  basis: 'm/s' },
    'm/min':  { faktor: 1 / 60,   groesse: 'Geschwindigkeit',  basis: 'm/s' },
    // Beschleunigung
    'm/s^2':  { faktor: 1,        groesse: 'Beschleunigung',   basis: 'm/s^2' },
    'cm/s^2': { faktor: 0.01,     groesse: 'Beschleunigung',   basis: 'm/s^2' },
    // Masse
    'kg':     { faktor: 1,        groesse: 'Masse',            basis: 'kg' },
    'g':      { faktor: 0.001,    groesse: 'Masse',            basis: 'kg' },
    'mg':     { faktor: 0.000001, groesse: 'Masse',            basis: 'kg' },
    't':      { faktor: 1000,     groesse: 'Masse',            basis: 'kg' },
    // Kraft
    'N':      { faktor: 1,        groesse: 'Kraft',            basis: 'N' },
    'kN':     { faktor: 1000,     groesse: 'Kraft',            basis: 'N' },
    'mN':     { faktor: 0.001,    groesse: 'Kraft',            basis: 'N' },
    // Energie und Arbeit
    'J':      { faktor: 1,        groesse: 'Energie',          basis: 'J' },
    'kJ':     { faktor: 1000,     groesse: 'Energie',          basis: 'J' },
    'MJ':     { faktor: 1000000,  groesse: 'Energie',          basis: 'J' },
    'Nm':     { faktor: 1,        groesse: 'Energie',          basis: 'J' },
    'Ws':     { faktor: 1,        groesse: 'Energie',          basis: 'J' },
    'kWh':    { faktor: 3600000,  groesse: 'Energie',          basis: 'J' },
    // Leistung
    'W':      { faktor: 1,        groesse: 'Leistung',         basis: 'W' },
    'kW':     { faktor: 1000,     groesse: 'Leistung',         basis: 'W' },
    'MW':     { faktor: 1000000,  groesse: 'Leistung',         basis: 'W' },
    // Impuls
    'kg*m/s': { faktor: 1,        groesse: 'Impuls',           basis: 'kg*m/s' },
    'Ns':     { faktor: 1,        groesse: 'Impuls',           basis: 'kg*m/s' },
    // Sonstiges
    'Hz':     { faktor: 1,        groesse: 'Frequenz',         basis: 'Hz' },
    '1/s':    { faktor: 1,        groesse: 'Frequenz',         basis: 'Hz' },
    '°':      { faktor: 1,        groesse: 'Winkel',           basis: '°' },
    '%':      { faktor: 0.01,     groesse: 'Verhältnis',       basis: '1' },
    '':       { faktor: 1,        groesse: 'Verhältnis',       basis: '1' }
  };

  /* Schreibweisen, die Lernende benutzen, auf die Tabellenform bringen. */
  function normschreibweise(roh) {
    var e = String(roh).trim();
    e = e.replace(/\s+/g, '');
    e = e.replace(/²/g, '^2').replace(/³/g, '^3');
    e = e.replace(/·/g, '*').replace(/×/g, '*').replace(/•/g, '*');
    e = e.replace(/÷/g, '/');
    e = e.replace(/^m\/sek$/i, 'm/s');
    e = e.replace(/^km\/std$/i, 'km/h').replace(/^kmh$/i, 'km/h').replace(/^kph$/i, 'km/h');
    e = e.replace(/^ms\^-1$/, 'm/s').replace(/^ms\^-2$/, 'm/s^2');
    e = e.replace(/^m\*s\^-1$/, 'm/s').replace(/^m\*s\^-2$/, 'm/s^2');
    e = e.replace(/^sec$/i, 's').replace(/^sek$/i, 's');
    e = e.replace(/^Std$/i, 'h').replace(/^Stunde[n]?$/i, 'h');
    e = e.replace(/^Meter$/i, 'm').replace(/^Sekunde[n]?$/i, 's');
    e = e.replace(/^Newton$/i, 'N').replace(/^Joule$/i, 'J').replace(/^Watt$/i, 'W');
    e = e.replace(/^m\/s\/s$/, 'm/s^2');
    e = e.replace(/^kgm\/s$/, 'kg*m/s');
    return e;
  }

  function kennt(einheit) {
    return Object.prototype.hasOwnProperty.call(TABELLE, normschreibweise(einheit));
  }

  /* "13,9 m/s" → { zahl: 13.9, einheit: "m/s" } ; null wenn unlesbar */
  function zerlegen(eingabe) {
    if (eingabe === null || eingabe === undefined) return null;
    var text = String(eingabe).trim();
    if (text === '') return null;
    text = text.replace(/ /g, ' ');

    var m = text.match(/^([+-]?\s*\d+(?:[.,]\d+)?(?:\s*[eE]\s*[+-]?\d+)?)\s*(.*)$/);
    if (!m) return null;

    var zahltext = m[1].replace(/\s+/g, '').replace(',', '.');
    var zahl = parseFloat(zahltext);
    if (!isFinite(zahl)) return null;

    var rest = m[2].trim();
    return { zahl: zahl, einheit: normschreibweise(rest), einheitRoh: rest };
  }

  /* Wert in SI-Basiseinheit; null wenn die Einheit unbekannt ist. */
  function nachBasis(zahl, einheit) {
    var e = TABELLE[normschreibweise(einheit)];
    if (!e) return null;
    return { wert: zahl * e.faktor, basis: e.basis, groesse: e.groesse };
  }

  function vonBasis(basiswert, zieleinheit) {
    var e = TABELLE[normschreibweise(zieleinheit)];
    if (!e) return null;
    return basiswert / e.faktor;
  }

  /* Andere gebräuchliche Einheiten derselben Größe — für die Verwechslungsprüfung. */
  function geschwister(basis) {
    var liste = [];
    for (var name in TABELLE) {
      if (!Object.prototype.hasOwnProperty.call(TABELLE, name)) continue;
      if (name === '') continue;
      if (TABELLE[name].basis === basis) liste.push(name);
    }
    return liste;
  }

  function nahe(a, b, toleranz) {
    if (!isFinite(a) || !isFinite(b)) return false;
    var schranke = Math.abs(b) * toleranz;
    if (Math.abs(b) < 1e-9) schranke = Math.max(schranke, toleranz);
    return Math.abs(a - b) <= schranke + 1e-12;
  }

  /* Kernfunktion: Eingabe gegen Sollwert prüfen.
     Ergebnis: { status, ... } mit status aus
     richtig | zahl_falsch | einheit_fehlt | einheit_falsch | einheit_verwechselt | unlesbar */
  function pruefen(eingabe, sollZahl, sollEinheit, toleranz) {
    toleranz = (typeof toleranz === 'number') ? toleranz : 0.02;

    var teil = zerlegen(eingabe);
    if (!teil) return { status: 'unlesbar' };

    var soll = nachBasis(sollZahl, sollEinheit);
    if (!soll) return { status: 'unlesbar', hinweis: 'Sollwert-Einheit unbekannt: ' + sollEinheit };

    /* keine Einheit angegeben */
    if (teil.einheit === '' && normschreibweise(sollEinheit) !== '') {
      var passtOhne = nahe(teil.zahl, sollZahl, toleranz);
      return { status: 'einheit_fehlt', zahlStimmt: passtOhne, sollEinheit: sollEinheit };
    }

    var ist = nachBasis(teil.zahl, teil.einheit);
    if (!ist) return { status: 'einheit_unbekannt', eingegeben: teil.einheitRoh };

    if (ist.groesse !== soll.groesse) {
      return {
        status: 'einheit_falsch',
        eingegebeneGroesse: ist.groesse,
        erwarteteGroesse: soll.groesse,
        sollEinheit: sollEinheit
      };
    }

    if (nahe(ist.wert, soll.wert, toleranz)) {
      return { status: 'richtig', wert: ist.wert };
    }

    /* Richtig gerechnet, aber in einer anderen Einheit beschriftet? */
    var kandidaten = geschwister(soll.basis), i, alt;
    for (i = 0; i < kandidaten.length; i++) {
      if (normschreibweise(kandidaten[i]) === teil.einheit) continue;
      alt = vonBasis(soll.wert, kandidaten[i]);
      if (nahe(teil.zahl, alt, toleranz)) {
        return {
          status: 'einheit_verwechselt',
          zahlPasstZu: kandidaten[i],
          angegeben: teil.einheitRoh || teil.einheit,
          sollEinheit: sollEinheit
        };
      }
    }

    return { status: 'zahl_falsch', wert: ist.wert, sollBasis: soll.wert, eingegeben: teil.zahl };
  }

  /* Zahl deutsch formatieren, mit sinnvoller Stellenzahl. */
  function formatieren(wert, stellen) {
    if (!isFinite(wert)) return '—';
    if (typeof stellen !== 'number') {
      var betrag = Math.abs(wert);
      stellen = betrag >= 100 ? 0 : betrag >= 10 ? 1 : betrag >= 1 ? 2 : 3;
    }
    return wert.toFixed(stellen).replace('.', ',');
  }

  return {
    zerlegen: zerlegen,
    nachBasis: nachBasis,
    vonBasis: vonBasis,
    pruefen: pruefen,
    kennt: kennt,
    nahe: nahe,
    formatieren: formatieren,
    normschreibweise: normschreibweise,
    _tabelle: TABELLE
  };
})();
