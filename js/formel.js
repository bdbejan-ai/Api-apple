/* formel.js — Mini-Notation für Formeln → HTML
 *
 * Warum kein LaTeX/KaTeX und kein MathML: Die App muss ohne Build-Schritt und
 * ohne CDN direkt aus dem Dateisystem laufen. Diese Notation deckt genau das ab,
 * was in der EF-Mechanik vorkommt, und ist für Nicht-Programmierende schreibbar.
 * Die Regeln stehen in inhalte/SCHEMA.md.
 *
 *   v = s / t          Bruch
 *   s = 1/2 * a * t^2  Hoch- und Tiefstellung, Malpunkt
 *   v_0, v_ges         Index
 *   sqrt(2*a*s)        Wurzel
 *   vec(F)             Vektorpfeil
 *   "m/s"              aufrechte Einheit (nicht kursiv, kein Bruch)
 *   <=  >=  !=  ~=     ≤ ≥ ≠ ≈
 */
window.Physik = window.Physik || {};

Physik.Formel = (function () {
  'use strict';

  var BUCHSTABE = 'A-Za-zÄÖÜäöüßαβγδεζηθϑικλμνξπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΠΡΣΤΥΦΧΨΩ';
  var IDENT = new RegExp('^[' + BUCHSTABE + '][' + BUCHSTABE + '0-9]*');
  var ZAHL = /^\d+(?:[.,]\d+)?/;
  var AUFRECHT = ['sin', 'cos', 'tan', 'max', 'min', 'ges', 'res', 'kin', 'pot', 'rad', 'zp', 'ab', 'an'];

  function schuetzen(t) {
    return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  /* Zerlegt an Trennzeichen, die außerhalb von Klammern und Anführungszeichen stehen. */
  function teilen(quelle, trenner) {
    var teile = [], operatoren = [], tiefe = 0, imText = false, start = 0, i, c;
    for (i = 0; i < quelle.length; i++) {
      c = quelle.charAt(i);
      if (c === '"') { imText = !imText; continue; }
      if (imText) continue;
      if (c === '(') tiefe++;
      else if (c === ')') tiefe--;
      else if (tiefe === 0 && trenner.indexOf(c) >= 0) {
        // führendes Vorzeichen ist kein Trennoperator
        if (i === start && (c === '-' || c === '+')) continue;
        teile.push(quelle.slice(start, i));
        operatoren.push(c);
        start = i + 1;
      }
    }
    teile.push(quelle.slice(start));
    return { teile: teile, operatoren: operatoren };
  }

  function klammernAbziehen(s) {
    s = s.trim();
    if (s.charAt(0) !== '(' || s.charAt(s.length - 1) !== ')') return s;
    var tiefe = 0, i;
    for (i = 0; i < s.length; i++) {
      if (s.charAt(i) === '(') tiefe++;
      else if (s.charAt(i) === ')') {
        tiefe--;
        if (tiefe === 0 && i < s.length - 1) return s; // Klammer schließt vorzeitig
      }
    }
    return s.slice(1, -1);
  }

  function relation(quelle) {
    var z = teilen(quelle, '=≈≤≥≠<>');
    var html = summe(z.teile[0]);
    for (var i = 0; i < z.operatoren.length; i++) {
      html += '<span class="op">' + schuetzen(z.operatoren[i]) + '</span>' + summe(z.teile[i + 1]);
    }
    return html;
  }

  function summe(quelle) {
    var z = teilen(quelle, '+-');
    var html = produkt(z.teile[0]);
    for (var i = 0; i < z.operatoren.length; i++) {
      var zeichen = z.operatoren[i] === '-' ? '−' : '+';
      html += '<span class="op">' + zeichen + '</span>' + produkt(z.teile[i + 1]);
    }
    return html;
  }

  /* Ein Produkt kann einen Bruchstrich enthalten: alles vor dem ersten "/" ist Zähler. */
  function produkt(quelle) {
    var z = teilen(quelle, '/');
    if (z.teile.length === 1) return faktoren(z.teile[0]);
    var html = '<span class="bruch"><span class="zaehler">' + faktoren(z.teile[0]) + '</span>';
    var nenner = z.teile.slice(1).map(faktoren).join('<span class="op-punkt">·</span>');
    return html + '<span class="nenner">' + nenner + '</span></span>';
  }

  function faktoren(quelle) {
    var z = teilen(quelle, '*');
    return z.teile.map(atomkette).join('<span class="op-punkt">·</span>');
  }

  /* Folge von Atomen ohne Operator dazwischen, z. B. "2π" oder "-v_0" */
  function atomkette(quelle) {
    var rest = quelle.trim(), html = '', vorzeichen = '';
    if (rest.charAt(0) === '-') { vorzeichen = '<span class="op">−</span>'; rest = rest.slice(1).trim(); }
    else if (rest.charAt(0) === '+') { vorzeichen = '<span class="op">+</span>'; rest = rest.slice(1).trim(); }
    if (rest === '') return vorzeichen;

    var schutz = 0, vorigeArt = null;
    while (rest.length > 0 && schutz++ < 400) {
      var vorher = rest.length;
      var ergebnis = atom(rest);
      /* Zwischen Zahlenwert und Einheit gehört ein schmales geschütztes Leerzeichen:
         „400 m", nicht „400m". */
      if (ergebnis.art === 'einheit' && vorigeArt !== null) html += '\u202f';
      html += ergebnis.html;
      vorigeArt = ergebnis.art || null;
      rest = ergebnis.rest.trim();
      if (rest.length === vorher) { html += schuetzen(rest); break; } // Notbremse
    }
    return vorzeichen + html;
  }

  function atom(rest) {
    var m, inhalt;

    if (rest.charAt(0) === '"') {                       // "km/h" → aufrecht
      var ende = rest.indexOf('"', 1);
      if (ende < 0) ende = rest.length;
      return {
        html: '<span class="einheit">' + schuetzen(rest.slice(1, ende)) + '</span>',
        rest: rest.slice(ende + 1),
        art: 'einheit'
      };
    }

    if (rest.indexOf('sqrt(') === 0) {
      inhalt = klammerInhalt(rest, 4);
      return {
        html: '√<span class="wurzel">' + relation(inhalt.inhalt) + '</span>',
        rest: inhalt.rest
      };
    }

    if (rest.indexOf('vec(') === 0) {
      inhalt = klammerInhalt(rest, 3);
      return {
        html: '<span class="vektor">' + relation(inhalt.inhalt) + '</span>',
        rest: inhalt.rest
      };
    }

    if (rest.charAt(0) === '(') {
      inhalt = klammerInhalt(rest, 0);
      return { html: '(' + relation(inhalt.inhalt) + ')', rest: inhalt.rest };
    }

    m = rest.match(ZAHL);
    if (m) return anhaengsel('<span class="zahl">' + m[0] + '</span>', rest.slice(m[0].length), 'zahl');

    m = rest.match(IDENT);
    if (m) {
      var name = m[0];
      var kl = AUFRECHT.indexOf(name) >= 0 ? 'einheit' : 'var';
      var html = '';
      if (name.charAt(0) === 'Δ') {                     // Δ aufrecht, Größe kursiv
        html = '<span class="einheit">Δ</span>';
        name = name.slice(1);
        if (name) html += '<span class="var">' + schuetzen(name) + '</span>';
      } else {
        html = '<span class="' + kl + '">' + schuetzen(name) + '</span>';
      }
      return anhaengsel(html, rest.slice(m[0].length), 'groesse');
    }

    return { html: schuetzen(rest.charAt(0)), rest: rest.slice(1) };
  }

  /* Index und Exponent hinter einem Atom einsammeln. */
  function anhaengsel(html, rest, art) {
    var schutz = 0;
    while (schutz++ < 4 && (rest.charAt(0) === '_' || rest.charAt(0) === '^')) {
      var art = rest.charAt(0) === '_' ? 'sub' : 'sup';
      rest = rest.slice(1);
      var wert;
      if (rest.charAt(0) === '(') {
        var k = klammerInhalt(rest, 0);
        wert = relation(k.inhalt);
        rest = k.rest;
      } else {
        var m = rest.match(new RegExp('^-?[' + BUCHSTABE + '0-9]+'));
        if (!m) break;
        wert = schuetzen(m[0].replace(/^-/, '−'));
        rest = rest.slice(m[0].length);
      }
      html += '<' + art + '>' + wert + '</' + art + '>';
    }
    return { html: html, rest: rest, art: art };
  }

  function klammerInhalt(rest, versatz) {
    var tiefe = 0, i;
    for (i = versatz; i < rest.length; i++) {
      if (rest.charAt(i) === '(') tiefe++;
      else if (rest.charAt(i) === ')') {
        tiefe--;
        if (tiefe === 0) return { inhalt: rest.slice(versatz + 1, i), rest: rest.slice(i + 1) };
      }
    }
    return { inhalt: rest.slice(versatz + 1), rest: '' };
  }

  /* ---------- öffentliche Schnittstelle ---------- */

  /* Zweistellige Vergleichszeichen vor dem Zerlegen auf ein Zeichen bringen,
     damit relation() sie als Trenner erkennt. */
  function vorNormieren(quelle) {
    return String(quelle)
      .replace(/<=/g, '\u2264').replace(/>=/g, '\u2265')
      .replace(/!=/g, '\u2260').replace(/~=/g, '\u2248');
  }

  function inline(quelle) {
    return '<span class="formel">' + relation(klammernAbziehen(vorNormieren(quelle))) + '</span>';
  }

  function block(quelle) {
    return '<div class="formel-block">' + inline(quelle) + '</div>';
  }

  /* Ersetzt $...$ in Fließtext durch gesetzte Formeln. */
  function imText(text) {
    var stuecke = String(text).split('$');
    var html = '';
    for (var i = 0; i < stuecke.length; i++) {
      html += (i % 2 === 0) ? stuecke[i] : inline(stuecke[i]);
    }
    return html;
  }

  return { inline: inline, block: block, imText: imText, _teilen: teilen };
})();
