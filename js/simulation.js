/* simulation.js — interaktive Darstellungen.
 * Ergänzen das Realexperiment, ersetzen es nicht: Beide Simulationen zeigen
 * genau die Zusammenhänge, die am Aufbau selbst schlecht sichtbar sind
 * (Bezugssystemwechsel, Grenzübergang Sekante → Tangente). */
window.Physik = window.Physik || {};

Physik.Simulation = (function () {
  'use strict';

  var D = Physik.Diagramm;

  function ruhigerModus() {
    return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  function regler(id, beschriftung, min, max, schritt, wert, einheit) {
    return '<label for="' + id + '">' + beschriftung + '</label>' +
      '<input type="range" id="' + id + '" min="' + min + '" max="' + max +
      '" step="' + schritt + '" value="' + wert + '">' +
      '<output for="' + id + '" id="' + id + '-aus">' + String(wert).replace('.', ',') +
      ' ' + einheit + '</output>';
  }

  /* ---------------------------------------------------------------
     1) Bezugssystem: zwei Fahrzeuge, drei Beobachterstandpunkte
     --------------------------------------------------------------- */
  function bezugssystem(wurzel) {
    var z = {
      vA: 20, vB: 14, xA0: 0, xB0: 120,
      t: 0, tMax: 12, laeuft: false, bezug: 'strasse'
    };

    wurzel.innerHTML =
      '<div class="karte">' +
        '<div class="regler-feld">' +
          regler('sim-va', 'Geschwindigkeit Auto A', -30, 30, 1, z.vA, 'm/s') +
          regler('sim-vb', 'Geschwindigkeit Auto B', -30, 30, 1, z.vB, 'm/s') +
          regler('sim-xb', 'Startort Auto B', 0, 250, 10, z.xB0, 'm') +
        '</div>' +
        '<fieldset style="border:1px solid var(--rand);border-radius:var(--radius);padding:.5rem .8rem;margin:.9rem 0 0">' +
          '<legend class="klein leise">Ich beobachte von …</legend>' +
          '<label class="klein" style="margin-right:1rem"><input type="radio" name="sim-bezug" value="strasse" checked> der Straße</label>' +
          '<label class="klein" style="margin-right:1rem"><input type="radio" name="sim-bezug" value="A"> Auto A aus</label>' +
          '<label class="klein"><input type="radio" name="sim-bezug" value="B"> Auto B aus</label>' +
        '</fieldset>' +
        '<div class="knopfreihe">' +
          '<button class="knopf haupt" id="sim-start">Start</button>' +
          '<button class="knopf" id="sim-reset">Zurücksetzen</button>' +
          '<span class="klein leise" id="sim-zeit" aria-live="polite" style="align-self:center"></span>' +
        '</div>' +
        '<div id="sim-strasse" class="figur"></div>' +
        '<div id="sim-diagramme"></div>' +
      '</div>';

    var elemente = {
      vA: wurzel.querySelector('#sim-va'), vB: wurzel.querySelector('#sim-vb'),
      xB: wurzel.querySelector('#sim-xb'),
      start: wurzel.querySelector('#sim-start'), reset: wurzel.querySelector('#sim-reset'),
      zeit: wurzel.querySelector('#sim-zeit'),
      strasse: wurzel.querySelector('#sim-strasse'),
      diagramme: wurzel.querySelector('#sim-diagramme')
    };

    function bezugsGeschwindigkeit() {
      return z.bezug === 'A' ? z.vA : z.bezug === 'B' ? z.vB : 0;
    }
    function bezugsOrt(t) {
      return z.bezug === 'A' ? z.xA0 + z.vA * t : z.bezug === 'B' ? z.xB0 + z.vB * t : 0;
    }
    function ort(welches, t) {
      var x = welches === 'A' ? z.xA0 + z.vA * t : z.xB0 + z.vB * t;
      return x - bezugsOrt(t);
    }
    function geschwindigkeit(welches) {
      return (welches === 'A' ? z.vA : z.vB) - bezugsGeschwindigkeit();
    }

    function strasseZeichnen() {
      var xa = ort('A', z.t), xb = ort('B', z.t);
      var alle = [xa, xb, 0];
      var min = Math.min.apply(null, alle) - 40, max = Math.max.apply(null, alle) + 40;
      if (max - min < 200) { var m = (min + max) / 2; min = m - 100; max = m + 100; }

      function px(x) { return 30 + (x - min) / (max - min) * 560; }

      var teile = ['<svg viewBox="0 0 620 120" role="img" aria-label="Straße mit Auto A und Auto B, ' +
        'dargestellt im gewählten Bezugssystem">'];
      teile.push('<rect x="20" y="52" width="580" height="26" fill="currentColor" fill-opacity=".08"/>');
      teile.push('<line x1="20" y1="65" x2="600" y2="65" stroke="currentColor" stroke-opacity=".3" stroke-dasharray="12 10"/>');

      var marken = D.marken(min, max, 6), i;
      for (i = 0; i < marken.length; i++) {
        if (px(marken[i]) < 20 || px(marken[i]) > 600) continue;
        teile.push('<line x1="' + px(marken[i]).toFixed(1) + '" y1="78" x2="' + px(marken[i]).toFixed(1) +
          '" y2="86" stroke="currentColor" stroke-opacity=".45"/>');
        teile.push('<text x="' + px(marken[i]).toFixed(1) + '" y="100" text-anchor="middle" font-size="11" ' +
          'fill="currentColor" fill-opacity=".7">' + Math.round(marken[i]) + '</text>');
      }
      teile.push('<text x="600" y="115" text-anchor="end" font-size="12" fill="currentColor" ' +
        'font-style="italic">x in m</text>');

      function auto(x, farbe, name) {
        var p = px(x);
        return '<g><rect x="' + (p - 17) + '" y="46" width="34" height="16" rx="4" fill="' + farbe + '"/>' +
          '<circle cx="' + (p - 9) + '" cy="63" r="4" fill="' + farbe + '"/>' +
          '<circle cx="' + (p + 9) + '" cy="63" r="4" fill="' + farbe + '"/>' +
          '<text x="' + p + '" y="38" text-anchor="middle" font-size="12.5" fill="currentColor">' + name + '</text></g>';
      }
      teile.push(auto(xa, D.FARBEN[0], 'A'));
      teile.push(auto(xb, D.FARBEN[1], 'B'));

      if (z.bezug !== 'strasse') {
        teile.push('<text x="20" y="20" font-size="12" fill="currentColor" fill-opacity=".75">' +
          'Nullpunkt sitzt in Auto ' + z.bezug + ' — Auto ' + z.bezug + ' steht hier immer still.</text>');
      }
      teile.push('</svg>');
      elemente.strasse.innerHTML = teile.join('');
    }

    function diagrammeZeichnen() {
      var vAs = geschwindigkeit('A'), vBs = geschwindigkeit('B');
      var xA = function (t) { return ort('A', t); };
      var xB = function (t) { return ort('B', t); };

      var werte = [xA(0), xA(z.tMax), xB(0), xB(z.tMax)];
      var yMin = Math.min.apply(null, werte), yMax = Math.max.apply(null, werte);
      var puffer = Math.max(20, (yMax - yMin) * 0.12);
      yMin = Math.min(0, yMin) - puffer; yMax = yMax + puffer;

      var vWerte = [vAs, vBs, 0];
      var vMin = Math.min.apply(null, vWerte) - 5, vMax = Math.max.apply(null, vWerte) + 5;

      var ortsDiagramm = D.figur({
        titel: 'Zeit-Ort-Diagramm beider Autos',
        beschreibung: 'Auto A verläuft als Gerade mit der Steigung ' + vAs.toFixed(1).replace('.', ',') +
          ' Meter pro Sekunde, Auto B mit der Steigung ' + vBs.toFixed(1).replace('.', ',') +
          ' Meter pro Sekunde. Der senkrechte Strich markiert den aktuellen Zeitpunkt.',
        breite: 620, hoehe: 300,
        xBereich: [0, z.tMax], yBereich: [yMin, yMax],
        xTitel: 't in s', yTitel: 'x in m',
        kurven: [
          { punkte: [[0, xA(0)], [z.tMax, xA(z.tMax)]], name: 'Auto A', farbe: D.FARBEN[0] },
          { punkte: [[0, xB(0)], [z.tMax, xB(z.tMax)]], name: 'Auto B', farbe: D.FARBEN[1] }
        ],
        linien: [{ von: [z.t, yMin], bis: [z.t, yMax], gestrichelt: true, deckkraft: 0.5 }],
        unterschrift: 'Zeit-Ort-Diagramm: Die Steigung ist die Geschwindigkeit.'
      });

      var vDiagramm = D.figur({
        titel: 'Zeit-Geschwindigkeit-Diagramm beider Autos',
        beschreibung: 'Beide Geschwindigkeiten sind zeitlich konstant und erscheinen als waagerechte Geraden.',
        breite: 620, hoehe: 220,
        xBereich: [0, z.tMax], yBereich: [vMin, vMax],
        xTitel: 't in s', yTitel: 'v in m/s',
        kurven: [
          { punkte: [[0, vAs], [z.tMax, vAs]], name: 'Auto A', farbe: D.FARBEN[0] },
          { punkte: [[0, vBs], [z.tMax, vBs]], name: 'Auto B', farbe: D.FARBEN[1] }
        ],
        linien: [{ von: [z.t, vMin], bis: [z.t, vMax], gestrichelt: true, deckkraft: 0.5 }],
        unterschrift: 'Zeit-Geschwindigkeit-Diagramm: waagerecht heißt gleichförmig — nicht „in Ruhe".'
      });

      elemente.diagramme.innerHTML = ortsDiagramm + vDiagramm;
    }

    function anzeigen() {
      elemente.zeit.textContent = 't = ' + z.t.toFixed(1).replace('.', ',') + ' s   ·   ' +
        'v(A) = ' + geschwindigkeit('A').toFixed(1).replace('.', ',') + ' m/s   ·   ' +
        'v(B) = ' + geschwindigkeit('B').toFixed(1).replace('.', ',') + ' m/s';
      strasseZeichnen();
      diagrammeZeichnen();
    }

    var letzteZeit = null, anfrage = null;
    function schritt(zeitstempel) {
      if (!z.laeuft) return;
      if (letzteZeit === null) letzteZeit = zeitstempel;
      var dt = Math.min(0.05, (zeitstempel - letzteZeit) / 1000);
      letzteZeit = zeitstempel;
      z.t += dt;
      if (z.t >= z.tMax) { z.t = z.tMax; anhalten(); anzeigen(); return; }
      anzeigen();
      anfrage = window.requestAnimationFrame(schritt);
    }
    function anhalten() {
      z.laeuft = false; letzteZeit = null;
      if (anfrage) window.cancelAnimationFrame(anfrage);
      elemente.start.textContent = 'Start';
    }

    elemente.start.addEventListener('click', function () {
      if (z.laeuft) { anhalten(); return; }
      if (z.t >= z.tMax) z.t = 0;
      z.laeuft = true; elemente.start.textContent = 'Pause';
      anfrage = window.requestAnimationFrame(schritt);
    });
    elemente.reset.addEventListener('click', function () { anhalten(); z.t = 0; anzeigen(); });

    function reglerBinden(el, feld, einheit) {
      el.addEventListener('input', function () {
        z[feld] = parseFloat(el.value);
        wurzel.querySelector('#' + el.id + '-aus').textContent =
          String(z[feld]).replace('.', ',') + ' ' + einheit;
        anzeigen();
      });
    }
    reglerBinden(elemente.vA, 'vA', 'm/s');
    reglerBinden(elemente.vB, 'vB', 'm/s');
    reglerBinden(elemente.xB, 'xB0', 'm');

    Array.prototype.forEach.call(wurzel.querySelectorAll('input[name="sim-bezug"]'), function (r) {
      r.addEventListener('change', function () { z.bezug = r.value; anzeigen(); });
    });

    if (ruhigerModus()) {
      elemente.start.disabled = true;
      elemente.start.title = 'Bewegungsreduzierung ist aktiv — nutze die Regler.';
    }
    anzeigen();
  }

  /* ---------------------------------------------------------------
     2) Sekante → Tangente: von der mittleren zur momentanen Geschwindigkeit
     --------------------------------------------------------------- */
  function sekanteTangente(wurzel) {
    var a = 1.6;                 // m/s², beschleunigende Fahrt
    var t0 = 5;                  // s, betrachteter Zeitpunkt
    var z = { dt: 4 };

    function x(t) { return 0.5 * a * t * t; }

    wurzel.innerHTML =
      '<div class="karte">' +
        '<div class="regler-feld">' +
          regler('sek-dt', 'Zeitspanne Δt', 0.2, 5, 0.2, z.dt, 's') +
        '</div>' +
        '<div id="sek-figur"></div>' +
        '<p class="klein" id="sek-text" aria-live="polite"></p>' +
      '</div>';

    var reglerEl = wurzel.querySelector('#sek-dt');
    var figurEl = wurzel.querySelector('#sek-figur');
    var textEl = wurzel.querySelector('#sek-text');

    function zeichnen() {
      var dt = z.dt;
      var mittel = (x(t0 + dt) - x(t0)) / dt;        // Sekantensteigung
      var momentan = a * t0;                          // Tangentensteigung
      var tEnde = 10;

      figurEl.innerHTML = D.figur({
        titel: 'Zeit-Ort-Diagramm einer beschleunigten Fahrt mit Sekante und Tangente',
        beschreibung: 'Die Kurve ist nach oben gekrümmt. Die Sekante über die Zeitspanne ' +
          dt.toFixed(1).replace('.', ',') + ' Sekunden hat die Steigung ' +
          mittel.toFixed(2).replace('.', ',') + ' Meter pro Sekunde, die Tangente bei 5 Sekunden ' +
          momentan.toFixed(2).replace('.', ',') + ' Meter pro Sekunde.',
        breite: 620, hoehe: 340,
        xBereich: [0, tEnde], yBereich: [0, x(tEnde)],
        xTitel: 't in s', yTitel: 'x in m',
        kurven: [{ punkte: D.bahn(x, 0, tEnde, 80), farbe: D.FARBEN[0], name: 'Fahrt' }],
        linien: [
          { von: [t0 - 2, x(t0) - momentan * 2], bis: [Math.min(tEnde, t0 + 3), x(t0) + momentan * 3],
            farbe: D.FARBEN[2], staerke: 2, deckkraft: 1 },
          { von: [t0, x(t0)], bis: [t0 + dt, x(t0 + dt)], farbe: D.FARBEN[1], staerke: 2, deckkraft: 1 },
          { von: [t0, x(t0)], bis: [t0 + dt, x(t0)], farbe: D.FARBEN[1], gestrichelt: true },
          { von: [t0 + dt, x(t0)], bis: [t0 + dt, x(t0 + dt)], farbe: D.FARBEN[1], gestrichelt: true }
        ],
        beschriftungen: [
          { text: 'Δt', bei: [t0 + dt / 2, x(t0)], dy: 15, anker: 'middle', farbe: D.FARBEN[1] },
          { text: 'Δx', bei: [t0 + dt, (x(t0) + x(t0 + dt)) / 2], dx: 6, farbe: D.FARBEN[1] },
          { text: 'Tangente', bei: [t0 - 2, x(t0) - momentan * 2], dx: 2, dy: -6, farbe: D.FARBEN[2] }
        ],
        unterschrift: 'Je kleiner Δt, desto näher liegt die Sekantensteigung an der Tangentensteigung.'
      });

      textEl.innerHTML = 'Mittlere Geschwindigkeit im Intervall: <b>' +
        mittel.toFixed(2).replace('.', ',') + ' m/s</b> &nbsp;·&nbsp; ' +
        'Momentangeschwindigkeit bei t = 5,0 s: <b>' + momentan.toFixed(2).replace('.', ',') + ' m/s</b>' +
        ' &nbsp;·&nbsp; Unterschied: ' + Math.abs(mittel - momentan).toFixed(2).replace('.', ',') + ' m/s';
    }

    reglerEl.addEventListener('input', function () {
      z.dt = parseFloat(reglerEl.value);
      wurzel.querySelector('#sek-dt-aus').textContent = z.dt.toFixed(1).replace('.', ',') + ' s';
      zeichnen();
    });
    zeichnen();
  }

  var VERZEICHNIS = { bezugssystem: bezugssystem, 'sekante-tangente': sekanteTangente };

  function erzeugen(name, wurzel) {
    var bauen = VERZEICHNIS[name];
    if (!bauen) { wurzel.innerHTML = '<p class="leise">Unbekannte Simulation: ' + name + '</p>'; return; }
    bauen(wurzel);
  }

  return { erzeugen: erzeugen, verfuegbar: Object.keys(VERZEICHNIS) };
})();
