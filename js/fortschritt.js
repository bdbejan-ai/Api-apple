/* fortschritt.js — Lernstand lokal halten.
 * Es werden ausschließlich Aufgaben-Kennungen und Zeitstempel gespeichert,
 * keine Namen, keine Texte, keine Übertragung an irgendeinen Server.
 * Fällt localStorage aus (privater Modus, gesperrte Website-Daten), läuft
 * die App im Sitzungsspeicher weiter, statt eine Fehlermeldung zu werfen. */
window.Physik = window.Physik || {};

Physik.Fortschritt = (function () {
  'use strict';

  var SCHLUESSEL = 'physik-ef-mechanik-v1';
  var TAG = 24 * 60 * 60 * 1000;
  var ersatzSpeicher = null;          // greift, wenn localStorage nicht nutzbar ist
  var speicherWarnung = false;

  function leer() {
    return { version: 1, einheiten: {}, aufgaben: {}, selbst: {}, begonnen: Date.now() };
  }

  function laden() {
    if (ersatzSpeicher) return ersatzSpeicher;
    try {
      var roh = window.localStorage.getItem(SCHLUESSEL);
      if (!roh) return leer();
      var daten = JSON.parse(roh);
      if (!daten || daten.version !== 1) return leer();
      daten.einheiten = daten.einheiten || {};
      daten.aufgaben = daten.aufgaben || {};
      daten.selbst = daten.selbst || {};
      return daten;
    } catch (fehler) {
      ersatzSpeicher = leer();
      speicherWarnung = true;
      return ersatzSpeicher;
    }
  }

  function speichern(daten) {
    if (ersatzSpeicher) { ersatzSpeicher = daten; return; }
    try {
      window.localStorage.setItem(SCHLUESSEL, JSON.stringify(daten));
    } catch (fehler) {
      ersatzSpeicher = daten;
      speicherWarnung = true;
    }
  }

  function speicherFehlt() { return speicherWarnung; }

  /* ---------------- Lerneinheiten ---------------- */

  function einheitGelesen(id) {
    var d = laden();
    d.einheiten[id] = { gelesen: true, zuletzt: Date.now() };
    speichern(d);
  }

  function istGelesen(id) {
    var d = laden();
    return !!(d.einheiten[id] && d.einheiten[id].gelesen);
  }

  /* ---------------- Aufgaben ---------------- */

  /* Wiedervorlage: Fehler kommen schnell zurück, sicher Gelöstes selten.
     Bewusst einfach gehalten — es geht um Wiederholung, nicht um ein Punktesystem. */
  function abstandTage(eintrag) {
    if (!eintrag.richtig) return 1;
    if (eintrag.fehlversuche > 0) return 3;
    return 10;
  }

  function ergebnisMerken(id, richtig) {
    if (richtig === null) return;                 // freie Aufgaben werten sich selbst
    var d = laden();
    var e = d.aufgaben[id] || { versuche: 0, fehlversuche: 0, richtig: false };
    e.versuche++;
    if (richtig) e.richtig = true; else e.fehlversuche++;
    e.zuletzt = Date.now();
    e.wiedervorlage = Date.now() + abstandTage(e) * TAG;
    d.aufgaben[id] = e;
    speichern(d);
  }

  function aufgabenStand(id) {
    var d = laden();
    return d.aufgaben[id] || null;
  }

  function faellig(aufgabenIds) {
    var d = laden(), jetzt = Date.now();
    return aufgabenIds.filter(function (id) {
      var e = d.aufgaben[id];
      if (!e) return false;                        // noch nie bearbeitet → keine Wiedervorlage
      return e.wiedervorlage && e.wiedervorlage <= jetzt;
    });
  }

  function nieBearbeitet(aufgabenIds) {
    var d = laden();
    return aufgabenIds.filter(function (id) { return !d.aufgaben[id]; });
  }

  /* ---------------- Auswertung ---------------- */

  function modulStand(aufgabenIds) {
    var d = laden(), geloest = 0, versucht = 0, mitFehler = 0;
    aufgabenIds.forEach(function (id) {
      var e = d.aufgaben[id];
      if (!e) return;
      versucht++;
      if (e.richtig) geloest++;
      if (e.fehlversuche > 0) mitFehler++;
    });
    var gesamt = aufgabenIds.length;
    var quote = gesamt ? geloest / gesamt : 0;
    var stand = 'offen';
    if (quote >= 0.8 && mitFehler <= geloest * 0.34) stand = 'sicher';
    else if (versucht > 0) stand = 'hilfe';
    return { gesamt: gesamt, versucht: versucht, geloest: geloest, mitFehler: mitFehler, quote: quote, stand: stand };
  }

  function selbstSetzen(modulId, wert) {
    var d = laden();
    d.selbst[modulId] = wert;
    speichern(d);
  }

  function selbstLesen(modulId) {
    return laden().selbst[modulId] || null;
  }

  /* ---------------- Daten in der Hand der Nutzenden ---------------- */

  function exportieren() {
    return JSON.stringify(laden(), null, 2);
  }

  function importieren(text) {
    var daten = JSON.parse(text);
    if (!daten || daten.version !== 1) throw new Error('Unpassendes Format oder falsche Version.');
    daten.einheiten = daten.einheiten || {};
    daten.aufgaben = daten.aufgaben || {};
    daten.selbst = daten.selbst || {};
    speichern(daten);
    return daten;
  }

  function loeschen() {
    ersatzSpeicher = null;
    try { window.localStorage.removeItem(SCHLUESSEL); } catch (fehler) { /* egal */ }
  }

  return {
    einheitGelesen: einheitGelesen,
    istGelesen: istGelesen,
    ergebnisMerken: ergebnisMerken,
    aufgabenStand: aufgabenStand,
    faellig: faellig,
    nieBearbeitet: nieBearbeitet,
    modulStand: modulStand,
    selbstSetzen: selbstSetzen,
    selbstLesen: selbstLesen,
    exportieren: exportieren,
    importieren: importieren,
    loeschen: loeschen,
    speicherFehlt: speicherFehlt,
    _abstandTage: abstandTage,
    _leer: leer
  };
})();
