/* diagramm.js — Diagramme als SVG, im Programm erzeugt (keine Bilddateien).
 * Achsen tragen immer Größe und Einheit, weil das Ablesen der Steigung mit
 * Einheit in der EF geübt werden muss. */
window.Physik = window.Physik || {};

Physik.Diagramm = (function () {
  'use strict';

  var FARBEN = ['#1f5f8b', '#9c3229', '#2c6e49', '#7d5ba6', '#8a5a12'];

  function schuetzen(t) {
    return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function zahl(w) {
    var g = Math.abs(w);
    var s = g >= 100 ? w.toFixed(0) : g >= 10 ? w.toFixed(1) : g >= 1 ? w.toFixed(1) : w.toFixed(2);
    s = s.replace(/,?0+$/, function (m) { return m.indexOf(',') === 0 ? '' : m; });
    return s.replace('.', ',').replace(/,$/, '');
  }

  /* Schrittweite 1 / 2 / 5 mal Zehnerpotenz, damit die Achse ablesbar bleibt. */
  function schrittweite(spanne, wunschAnzahl) {
    var roh = spanne / (wunschAnzahl || 6);
    var potenz = Math.pow(10, Math.floor(Math.log(roh) / Math.LN10));
    var rest = roh / potenz;
    var faktor = rest >= 5 ? 5 : rest >= 2 ? 2 : 1;
    return faktor * potenz;
  }

  function marken(min, max, wunschAnzahl) {
    var schritt = schrittweite(max - min, wunschAnzahl);
    var liste = [], w = Math.ceil(min / schritt) * schritt, schutz = 0;
    while (w <= max + schritt * 1e-6 && schutz++ < 200) {
      liste.push(Math.abs(w) < schritt * 1e-9 ? 0 : w);
      w += schritt;
    }
    return liste;
  }

  /* Hauptfunktion. spez siehe inhalte/SCHEMA.md */
  function zeichnen(spez) {
    var breite = spez.breite || 620;
    var hoehe = spez.hoehe || 380;
    /* oben bleibt Platz für den Achsentitel, damit er nicht in die oberste
       Skalenbeschriftung läuft. */
    var rand = { links: 68, rechts: 18, oben: 34, unten: 52 };
    var innenB = breite - rand.links - rand.rechts;
    var innenH = hoehe - rand.oben - rand.unten;

    var xMin = spez.xBereich[0], xMax = spez.xBereich[1];
    var yMin = spez.yBereich[0], yMax = spez.yBereich[1];

    function px(x) { return rand.links + (x - xMin) / (xMax - xMin) * innenB; }
    function py(y) { return rand.oben + innenH - (y - yMin) / (yMax - yMin) * innenH; }

    var teile = [];
    var titelId = 'dg-t-' + Math.random().toString(36).slice(2, 8);
    var beschrId = 'dg-b-' + Math.random().toString(36).slice(2, 8);

    teile.push('<svg viewBox="0 0 ' + breite + ' ' + hoehe + '" role="img" ' +
      'aria-labelledby="' + titelId + ' ' + beschrId + '" class="diagramm">');
    teile.push('<title id="' + titelId + '">' + schuetzen(spez.titel || 'Diagramm') + '</title>');
    teile.push('<desc id="' + beschrId + '">' + schuetzen(spez.beschreibung ||
      'Diagramm ohne weitere Beschreibung') + '</desc>');

    /* Gitter */
    var xm = marken(xMin, xMax, spez.xMarken || 6);
    var ym = marken(yMin, yMax, spez.yMarken || 5);
    var i;
    if (spez.gitter !== false) {
      for (i = 0; i < xm.length; i++) {
        teile.push('<line x1="' + px(xm[i]).toFixed(1) + '" y1="' + rand.oben +
          '" x2="' + px(xm[i]).toFixed(1) + '" y2="' + (rand.oben + innenH) +
          '" stroke="currentColor" stroke-opacity=".13"/>');
      }
      for (i = 0; i < ym.length; i++) {
        teile.push('<line x1="' + rand.links + '" y1="' + py(ym[i]).toFixed(1) +
          '" x2="' + (rand.links + innenB) + '" y2="' + py(ym[i]).toFixed(1) +
          '" stroke="currentColor" stroke-opacity=".13"/>');
      }
    }

    /* Flächen unter der Kurve (Weg im t-v-Diagramm) */
    (spez.flaechen || []).forEach(function (f) {
      var d = 'M ' + px(f.punkte[0][0]) + ' ' + py(0);
      f.punkte.forEach(function (p) { d += ' L ' + px(p[0]).toFixed(1) + ' ' + py(p[1]).toFixed(1); });
      d += ' L ' + px(f.punkte[f.punkte.length - 1][0]).toFixed(1) + ' ' + py(0) + ' Z';
      teile.push('<path d="' + d + '" fill="' + (f.farbe || FARBEN[0]) + '" fill-opacity="' +
        (f.deckkraft || 0.16) + '"/>');
    });

    /* Achsen */
    teile.push('<line x1="' + rand.links + '" y1="' + py(Math.max(yMin, Math.min(yMax, 0))).toFixed(1) +
      '" x2="' + (rand.links + innenB) + '" y2="' + py(Math.max(yMin, Math.min(yMax, 0))).toFixed(1) +
      '" stroke="currentColor" stroke-width="1.4"/>');
    teile.push('<line x1="' + rand.links + '" y1="' + rand.oben +
      '" x2="' + rand.links + '" y2="' + (rand.oben + innenH) +
      '" stroke="currentColor" stroke-width="1.4"/>');

    for (i = 0; i < xm.length; i++) {
      teile.push('<text x="' + px(xm[i]).toFixed(1) + '" y="' + (rand.oben + innenH + 17) +
        '" text-anchor="middle" font-size="12" fill="currentColor" fill-opacity=".75">' +
        zahl(xm[i]) + '</text>');
    }
    for (i = 0; i < ym.length; i++) {
      teile.push('<text x="' + (rand.links - 8) + '" y="' + (py(ym[i]) + 4).toFixed(1) +
        '" text-anchor="end" font-size="12" fill="currentColor" fill-opacity=".75">' +
        zahl(ym[i]) + '</text>');
    }

    teile.push('<text x="' + (rand.links + innenB) + '" y="' + (hoehe - 14) +
      '" text-anchor="end" font-size="13" fill="currentColor" font-style="italic">' +
      schuetzen(spez.xTitel || '') + '</text>');
    teile.push('<text x="6" y="16" font-size="13" fill="currentColor" font-style="italic">' +
      schuetzen(spez.yTitel || '') + '</text>');

    /* Kurven */
    (spez.kurven || []).forEach(function (k, nr) {
      var farbe = k.farbe || FARBEN[nr % FARBEN.length];
      if (k.art === 'punkte') {
        k.punkte.forEach(function (p) {
          teile.push('<circle cx="' + px(p[0]).toFixed(1) + '" cy="' + py(p[1]).toFixed(1) +
            '" r="3.4" fill="' + farbe + '"/>');
          if (k.fehlerbalken) {
            teile.push('<line x1="' + px(p[0]).toFixed(1) + '" y1="' + py(p[1] - k.fehlerbalken).toFixed(1) +
              '" x2="' + px(p[0]).toFixed(1) + '" y2="' + py(p[1] + k.fehlerbalken).toFixed(1) +
              '" stroke="' + farbe + '" stroke-width="1.2"/>');
          }
        });
      } else {
        var d = k.punkte.map(function (p, j) {
          return (j === 0 ? 'M ' : 'L ') + px(p[0]).toFixed(1) + ' ' + py(p[1]).toFixed(1);
        }).join(' ');
        teile.push('<path d="' + d + '" fill="none" stroke="' + farbe + '" stroke-width="2.2" ' +
          (k.gestrichelt ? 'stroke-dasharray="6 4" ' : '') + 'stroke-linejoin="round"/>');
      }
    });

    /* Hilfslinien, z. B. Steigungsdreieck */
    (spez.linien || []).forEach(function (l) {
      teile.push('<line x1="' + px(l.von[0]).toFixed(1) + '" y1="' + py(l.von[1]).toFixed(1) +
        '" x2="' + px(l.bis[0]).toFixed(1) + '" y2="' + py(l.bis[1]).toFixed(1) +
        '" stroke="' + (l.farbe || 'currentColor') + '" stroke-width="' + (l.staerke || 1.4) + '" ' +
        (l.gestrichelt ? 'stroke-dasharray="5 4" ' : '') + 'stroke-opacity="' + (l.deckkraft || 0.85) + '"/>');
    });

    (spez.beschriftungen || []).forEach(function (b) {
      teile.push('<text x="' + px(b.bei[0]).toFixed(1) + '" y="' + py(b.bei[1]).toFixed(1) +
        '" font-size="12.5" fill="' + (b.farbe || 'currentColor') + '" text-anchor="' +
        (b.anker || 'start') + '" dx="' + (b.dx || 0) + '" dy="' + (b.dy || 0) + '">' +
        schuetzen(b.text) + '</text>');
    });

    /* Legende */
    var mitNamen = (spez.kurven || []).filter(function (k) { return k.name; });
    if (mitNamen.length) {
      var lx = rand.links + 10, ly = rand.oben + 14;
      mitNamen.forEach(function (k, nr) {
        var farbe = k.farbe || FARBEN[(spez.kurven.indexOf(k)) % FARBEN.length];
        teile.push('<line x1="' + lx + '" y1="' + (ly + nr * 17) + '" x2="' + (lx + 20) +
          '" y2="' + (ly + nr * 17) + '" stroke="' + farbe + '" stroke-width="2.4"/>');
        teile.push('<text x="' + (lx + 26) + '" y="' + (ly + nr * 17 + 4) +
          '" font-size="12.5" fill="currentColor">' + schuetzen(k.name) + '</text>');
      });
    }

    teile.push('</svg>');
    return teile.join('');
  }

  /* Als Abbildung mit Bildunterschrift */
  function figur(spez) {
    return '<figure class="figur">' + zeichnen(spez) +
      (spez.unterschrift ? '<figcaption>' + schuetzen(spez.unterschrift) + '</figcaption>' : '') +
      '</figure>';
  }

  /* Ausgleichsgerade nach der Methode der kleinsten Quadrate. */
  function ausgleichsgerade(punkte) {
    var n = punkte.length, sx = 0, sy = 0, sxx = 0, sxy = 0, i;
    for (i = 0; i < n; i++) {
      sx += punkte[i][0]; sy += punkte[i][1];
      sxx += punkte[i][0] * punkte[i][0];
      sxy += punkte[i][0] * punkte[i][1];
    }
    var nenner = n * sxx - sx * sx;
    if (Math.abs(nenner) < 1e-12) return null;
    var steigung = (n * sxy - sx * sy) / nenner;
    var achsenabschnitt = (sy - steigung * sx) / n;
    return { steigung: steigung, achsenabschnitt: achsenabschnitt };
  }

  function bahn(fn, von, bis, schritte) {
    var punkte = [], i, n = schritte || 60;
    for (i = 0; i <= n; i++) {
      var x = von + (bis - von) * i / n;
      punkte.push([x, fn(x)]);
    }
    return punkte;
  }

  return {
    zeichnen: zeichnen,
    figur: figur,
    ausgleichsgerade: ausgleichsgerade,
    bahn: bahn,
    marken: marken,
    schrittweite: schrittweite,
    FARBEN: FARBEN
  };
})();
