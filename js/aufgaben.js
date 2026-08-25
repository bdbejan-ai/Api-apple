/* aufgaben.js — Aufgaben darstellen und Antworten prüfen.
 * pruefen() ist bewusst frei von DOM-Zugriffen, damit die Logik in tests/ läuft. */
window.Physik = window.Physik || {};

Physik.Aufgaben = (function () {
  'use strict';

  var E = Physik.Einheiten;
  var F = Physik.Formel;

  var NIVEAU_NAME = { basis: 'Basis', standard: 'Standard', vertiefung: 'LK-Vertiefung' };
  var KOMPETENZ_NAME = {
    UF: 'Umgang mit Fachwissen', E: 'Erkenntnisgewinnung',
    K: 'Kommunikation', B: 'Bewertung'
  };

  function schuetzen(t) {
    return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  /* ---------------------------------------------------------------
     Prüflogik
     --------------------------------------------------------------- */

  function pruefeRechnung(aufgabe, eingabe) {
    var soll = aufgabe.loesung;
    var ergebnis = E.pruefen(eingabe, soll.wert, soll.einheit, soll.toleranz);

    if (ergebnis.status === 'richtig') {
      return { richtig: true, art: 'richtig', titel: 'Richtig.',
        text: aufgabe.bestaetigung || 'Zahlenwert und Einheit passen.' };
    }

    if (ergebnis.status === 'unlesbar') {
      return { richtig: false, art: 'teilweise', titel: 'Das konnte ich nicht lesen.',
        text: 'Gib Zahl und Einheit an, zum Beispiel <span class="formel">' +
          E.formatieren(soll.wert) + ' ' + schuetzen(soll.einheit) + '</span>. ' +
          'Als Dezimaltrennzeichen ist das Komma erlaubt.' };
    }

    if (ergebnis.status === 'einheit_fehlt') {
      return {
        richtig: false, art: ergebnis.zahlStimmt ? 'teilweise' : 'falsch',
        titel: ergebnis.zahlStimmt ? 'Zahl richtig, Einheit fehlt.' : 'Die Einheit fehlt.',
        text: ergebnis.zahlStimmt
          ? 'Eine physikalische Größe ist Zahlenwert <em>mal</em> Einheit. Ohne Einheit ist die Antwort unvollständig — ergänze sie.'
          : 'Ohne Einheit lässt sich nicht prüfen, was du gerechnet hast. Ergänze die Einheit und sieh dir den Zahlenwert noch einmal an.'
      };
    }

    if (ergebnis.status === 'einheit_unbekannt') {
      return { richtig: false, art: 'teilweise', titel: 'Diese Einheit kenne ich nicht.',
        text: 'Du hast „' + schuetzen(ergebnis.eingegeben) + '" geschrieben. Übliche Schreibweisen sind ' +
          'm, km, s, min, h, m/s, km/h, m/s², kg, N, J, W.' };
    }

    if (ergebnis.status === 'einheit_verwechselt') {
      return { richtig: false, art: 'teilweise',
        titel: 'Der Zahlenwert passt — aber nicht zu dieser Einheit.',
        text: 'Dein Zahlenwert gehört zu <b>' + schuetzen(ergebnis.zahlPasstZu) + '</b>, angegeben hast du ' +
          '<b>' + schuetzen(ergebnis.angegeben) + '</b>. Das ist der häufigste Fehler in diesem Kapitel: ' +
          'Rechnung und Beschriftung gehören zu verschiedenen Einheiten. Rechne den Wert um.' };
    }

    if (ergebnis.status === 'einheit_falsch') {
      return { richtig: false, art: 'falsch',
        titel: 'Das ist die falsche Größenart.',
        text: 'Du hast eine Größe der Art <b>' + schuetzen(ergebnis.eingegebeneGroesse) + '</b> angegeben, ' +
          'gesucht ist aber <b>' + schuetzen(ergebnis.erwarteteGroesse) + '</b> in ' +
          schuetzen(ergebnis.sollEinheit) + '. Prüfe deinen Ansatz: Welche Größen hast du miteinander verrechnet?' };
    }

    /* Zahl falsch: Passt sie zu einem bekannten Denkfehler? */
    var teil = E.zerlegen(eingabe);
    var treffer = null;
    (aufgabe.fehleranalyse || []).forEach(function (f) {
      if (treffer || typeof f.wert !== 'number') return;
      var basisFalsch = E.nachBasis(f.wert, f.einheit || soll.einheit);
      var basisEingabe = teil ? E.nachBasis(teil.zahl, teil.einheit || soll.einheit) : null;
      if (basisFalsch && basisEingabe && E.nahe(basisEingabe.wert, basisFalsch.wert, f.toleranz || 0.03)) {
        treffer = f;
      }
    });

    if (treffer) {
      return { richtig: false, art: 'falsch', titel: 'Nicht richtig — und ich sehe, woran es liegt.',
        text: '<b>' + schuetzen(treffer.ursache) + '</b><br>' + F.imText(treffer.hinweis) };
    }

    return { richtig: false, art: 'falsch', titel: 'Noch nicht richtig.',
      text: 'Nutze die gestufte Hilfe: Sie fragt zuerst nach, gibt dann den Ansatz und zeigt zuletzt den ersten Rechenschritt.' };
  }

  function pruefeAuswahl(aufgabe, index) {
    if (typeof index !== 'number' || !aufgabe.optionen[index]) {
      return { richtig: false, art: 'teilweise', titel: 'Bitte wähle eine Antwort.', text: '' };
    }
    var option = aufgabe.optionen[index];
    if (option.richtig) {
      return { richtig: true, art: 'richtig', titel: 'Richtig.',
        text: F.imText(option.rueckmeldung || aufgabe.bestaetigung || '') };
    }
    return { richtig: false, art: 'falsch', titel: 'Nicht richtig.',
      text: F.imText(option.rueckmeldung || 'Sieh dir die Hilfen an und versuche es noch einmal.') };
  }

  function pruefeMehrfach(aufgabe, indizes) {
    var gewaehlt = (indizes || []).slice().sort();
    var soll = [];
    aufgabe.optionen.forEach(function (o, i) { if (o.richtig) soll.push(i); });

    var fehlend = soll.filter(function (i) { return gewaehlt.indexOf(i) < 0; });
    var zuviel = gewaehlt.filter(function (i) { return soll.indexOf(i) < 0; });

    if (!gewaehlt.length) {
      return { richtig: false, art: 'teilweise', titel: 'Bitte wähle mindestens eine Antwort.', text: '' };
    }
    if (!fehlend.length && !zuviel.length) {
      return { richtig: true, art: 'richtig', titel: 'Richtig — alle zutreffenden Aussagen erkannt.',
        text: F.imText(aufgabe.bestaetigung || '') };
    }
    var texte = [];
    zuviel.forEach(function (i) {
      texte.push('Nicht zutreffend: ' + F.imText(aufgabe.optionen[i].rueckmeldung || aufgabe.optionen[i].text));
    });
    if (fehlend.length) texte.push('Es fehlt noch mindestens eine zutreffende Aussage.');
    return {
      richtig: false,
      art: (!zuviel.length && fehlend.length) ? 'teilweise' : 'falsch',
      titel: (!zuviel.length && fehlend.length) ? 'Teilweise richtig.' : 'Nicht richtig.',
      text: texte.join('<br>')
    };
  }

  function pruefeReihenfolge(aufgabe, reihenfolge) {
    var soll = aufgabe.schritte.map(function (_, i) { return i; });
    var gleich = reihenfolge && reihenfolge.length === soll.length &&
      reihenfolge.every(function (w, i) { return w === soll[i]; });
    if (gleich) {
      return { richtig: true, art: 'richtig', titel: 'Richtig sortiert.',
        text: F.imText(aufgabe.bestaetigung || 'Die Herleitung ist logisch geschlossen.') };
    }
    var ersteAbweichung = -1, i;
    for (i = 0; i < soll.length; i++) {
      if (!reihenfolge || reihenfolge[i] !== soll[i]) { ersteAbweichung = i; break; }
    }
    return { richtig: false, art: 'falsch', titel: 'Die Reihenfolge stimmt noch nicht.',
      text: 'Ab Position ' + (ersteAbweichung + 1) + ' passt es nicht mehr. Frage dich bei jedem Schritt: ' +
        'Welche Größe ist hier schon bekannt, welche wird erst eingeführt?' };
  }

  function pruefeZuordnung(aufgabe, zuordnung) {
    var richtig = 0, gesamt = aufgabe.paare.length, rueck = [];
    aufgabe.paare.forEach(function (paar, i) {
      var gewaehlt = zuordnung ? zuordnung[i] : undefined;
      if (gewaehlt === paar.loesung) richtig++;
      else if (gewaehlt !== undefined && gewaehlt !== null) {
        rueck.push('<b>' + schuetzen(paar.frage) + ':</b> ' + F.imText(paar.rueckmeldung || ''));
      }
    });
    if (richtig === gesamt) {
      return { richtig: true, art: 'richtig', titel: 'Alle Zuordnungen richtig.',
        text: F.imText(aufgabe.bestaetigung || '') };
    }
    return { richtig: false, art: richtig > 0 ? 'teilweise' : 'falsch',
      titel: richtig + ' von ' + gesamt + ' richtig zugeordnet.',
      text: rueck.join('<br>') };
  }

  function pruefen(aufgabe, antwort) {
    switch (aufgabe.typ) {
      case 'rechnung':    return pruefeRechnung(aufgabe, antwort);
      case 'mc':          return pruefeAuswahl(aufgabe, antwort);
      case 'mehrfach':    return pruefeMehrfach(aufgabe, antwort);
      case 'reihenfolge': return pruefeReihenfolge(aufgabe, antwort);
      case 'zuordnung':   return pruefeZuordnung(aufgabe, antwort);
      case 'frei':        return { richtig: null, art: 'teilweise', titel: 'Vergleiche selbst.',
                                   text: 'Lies den Erwartungshorizont und schätze ehrlich ein, was dir gefehlt hat.' };
      default:            return { richtig: false, art: 'falsch', titel: 'Unbekannter Aufgabentyp.', text: '' };
    }
  }

  /* ---------------------------------------------------------------
     Darstellung
     --------------------------------------------------------------- */

  function marken(aufgabe) {
    var m = ['<span class="marke-klein">' + NIVEAU_NAME[aufgabe.niveau] + '</span>'];
    (aufgabe.kompetenz || []).forEach(function (k) {
      var bereich = k.replace(/[0-9]/g, '');
      m.push('<span class="marke-klein" title="' + (KOMPETENZ_NAME[bereich] || '') + '">' + k + '</span>');
    });
    m.push('<span class="marke-klein" title="Anforderungsbereich">AFB ' +
      ['', 'I', 'II', 'III'][aufgabe.afb] + '</span>');
    if (aufgabe.zeit) m.push('<span class="marke-klein">' + aufgabe.zeit + ' min</span>');
    return '<span class="marken">' + m.join('') + '</span>';
  }

  function rechenweg(aufgabe) {
    if (!aufgabe.weg || !aufgabe.weg.length) return '';
    var zeilen = aufgabe.weg.map(function (s) {
      return '<li><span class="schritt-name">' + schuetzen(s.schritt) + '</span>' +
        F.imText(s.inhalt) + '</li>';
    }).join('');
    return '<ol class="rechenweg">' + zeilen + '</ol>';
  }

  function fehlerliste(aufgabe) {
    if (!aufgabe.fehleranalyse || !aufgabe.fehleranalyse.length) return '';
    var zeilen = aufgabe.fehleranalyse.map(function (f) {
      var wert = (typeof f.wert === 'number')
        ? '<b>' + E.formatieren(f.wert) + ' ' + schuetzen(f.einheit || (aufgabe.loesung && aufgabe.loesung.einheit) || '') + '</b> — '
        : '';
      return '<li>' + wert + schuetzen(f.ursache) + '. ' + F.imText(f.hinweis) + '</li>';
    }).join('');
    return '<p class="klein leise" style="margin-bottom:0"><b>Typische Fehler bei dieser Aufgabe</b></p>' +
      '<ul class="fehlerliste">' + zeilen + '</ul>';
  }

  function hilfen(aufgabe) {
    if (!aufgabe.hilfen || !aufgabe.hilfen.length) return '';
    return aufgabe.hilfen.map(function (h, i) {
      return '<details class="hilfe"><summary>Hilfe ' + (i + 1) + ' von ' + aufgabe.hilfen.length +
        ' — ' + ['Denkanstoß', 'Ansatz', 'Erster Rechenschritt'][i] + '</summary><div>' +
        F.imText(h) + '</div></details>';
    }).join('');
  }

  function loesungsblock(aufgabe) {
    var inhalt = '';
    if (aufgabe.loesung && typeof aufgabe.loesung.wert === 'number') {
      inhalt += '<p><b>Ergebnis: ' + E.formatieren(aufgabe.loesung.wert, aufgabe.loesung.stellen) +
        ' ' + schuetzen(aufgabe.loesung.einheit) + '</b></p>';
    }
    if (aufgabe.erwartung) inhalt += '<p>' + F.imText(aufgabe.erwartung) + '</p>';
    inhalt += rechenweg(aufgabe);
    if (aufgabe.nachtrag) inhalt += '<p class="klein">' + F.imText(aufgabe.nachtrag) + '</p>';
    inhalt += fehlerliste(aufgabe);
    return '<details class="loesung"><summary>Lösungsweg anzeigen</summary><div>' + inhalt + '</div></details>';
  }

  function koerper(aufgabe) {
    var h = '';
    if (aufgabe.kontext) h += '<p class="kontext">' + F.imText(aufgabe.kontext) + '</p>';
    h += '<p><span class="operator">' + schuetzen(aufgabe.operator) + '</span> ' + F.imText(aufgabe.text) + '</p>';
    if (aufgabe.gegeben) {
      h += '<p class="klein leise">Gegeben: ' + F.imText(aufgabe.gegeben) + '</p>';
    }
    if (aufgabe.abbildung) h += Physik.Diagramm.figur(aufgabe.abbildung);
    if (aufgabe.tabelle) h += tabelle(aufgabe.tabelle);
    return h;
  }

  function tabelle(spez) {
    var kopf = spez.spalten.map(function (s) { return '<th scope="col">' + schuetzen(s) + '</th>'; }).join('');
    var zeilen = spez.zeilen.map(function (z) {
      return '<tr>' + z.map(function (w) { return '<td>' + schuetzen(w) + '</td>'; }).join('') + '</tr>';
    }).join('');
    return '<div class="tabellen-rahmen"><table class="messwerte">' +
      (spez.beschriftung ? '<caption class="klein leise" style="text-align:left;padding-bottom:.3rem">' +
        schuetzen(spez.beschriftung) + '</caption>' : '') +
      '<thead><tr>' + kopf + '</tr></thead><tbody>' + zeilen + '</tbody></table></div>';
  }

  /* Baut die Aufgabe als DOM-Element inklusive Ereignisbehandlung. */
  function rendern(aufgabe, nummer, beiErgebnis) {
    var el = document.createElement('section');
    el.className = 'karte aufgabe niveau-' + aufgabe.niveau;
    el.id = 'aufgabe-' + aufgabe.id;

    var eingabeHtml = '';
    if (aufgabe.typ === 'rechnung') {
      eingabeHtml = '<div class="antwortfeld">' +
        '<label class="nur-lesegeraet" for="ein-' + aufgabe.id + '">Antwort mit Einheit</label>' +
        '<input type="text" id="ein-' + aufgabe.id + '" inputmode="decimal" placeholder="Zahl und Einheit, z. B. 13,9 m/s" autocomplete="off">' +
        '<button class="knopf haupt" data-rolle="pruefen">Prüfen</button></div>';
    } else if (aufgabe.typ === 'mc' || aufgabe.typ === 'mehrfach') {
      var art = aufgabe.typ === 'mc' ? 'radio' : 'checkbox';
      eingabeHtml = '<ul class="optionen">' + aufgabe.optionen.map(function (o, i) {
        return '<li data-nr="' + i + '"><label><input type="' + art + '" name="opt-' + aufgabe.id +
          '" value="' + i + '"><span>' + F.imText(o.text) + '</span></label></li>';
      }).join('') + '</ul><div class="knopfreihe"><button class="knopf haupt" data-rolle="pruefen">Prüfen</button></div>';
    } else if (aufgabe.typ === 'zuordnung') {
      eingabeHtml = '<div>' + aufgabe.paare.map(function (p, i) {
        return '<div class="antwortfeld"><span style="flex:1 1 12rem">' + F.imText(p.frage) + '</span>' +
          '<label class="nur-lesegeraet" for="zu-' + aufgabe.id + '-' + i + '">Zuordnung wählen</label>' +
          '<select id="zu-' + aufgabe.id + '-' + i + '" data-paar="' + i + '">' +
          '<option value="">bitte wählen</option>' +
          aufgabe.auswahl.map(function (a, j) {
            return '<option value="' + j + '">' + schuetzen(a) + '</option>';
          }).join('') + '</select></div>';
      }).join('') + '<div class="knopfreihe"><button class="knopf haupt" data-rolle="pruefen">Prüfen</button></div></div>';
    } else if (aufgabe.typ === 'frei') {
      eingabeHtml = '<div class="knopfreihe"><button class="knopf" data-rolle="pruefen">Erwartungshorizont zeigen</button></div>';
    }

    el.innerHTML =
      '<div class="aufgabe-kopf"><span class="nummer">Aufgabe ' + nummer + '</span>' + marken(aufgabe) + '</div>' +
      koerper(aufgabe) +
      eingabeHtml +
      '<div class="rueckmeldung-platz" aria-live="polite"></div>' +
      hilfen(aufgabe) +
      loesungsblock(aufgabe);

    var platz = el.querySelector('.rueckmeldung-platz');
    var knopf = el.querySelector('[data-rolle="pruefen"]');

    function antwortLesen() {
      if (aufgabe.typ === 'rechnung') return el.querySelector('input[type="text"]').value;
      if (aufgabe.typ === 'mc') {
        var gewaehlt = el.querySelector('input:checked');
        return gewaehlt ? parseInt(gewaehlt.value, 10) : null;
      }
      if (aufgabe.typ === 'mehrfach') {
        return Array.prototype.map.call(el.querySelectorAll('input:checked'), function (i) {
          return parseInt(i.value, 10);
        });
      }
      if (aufgabe.typ === 'zuordnung') {
        var z = {};
        Array.prototype.forEach.call(el.querySelectorAll('select'), function (s) {
          if (s.value !== '') z[parseInt(s.dataset.paar, 10)] = parseInt(s.value, 10);
        });
        return z;
      }
      return null;
    }

    function auswerten() {
      var ergebnis = pruefen(aufgabe, antwortLesen());
      platz.innerHTML = '<div class="rueckmeldung ' + ergebnis.art + '"><b>' +
        schuetzen(ergebnis.titel) + '</b>' + (ergebnis.text || '') + '</div>';

      if (aufgabe.typ === 'mc' || aufgabe.typ === 'mehrfach') {
        Array.prototype.forEach.call(el.querySelectorAll('.optionen li'), function (li) {
          var nr = parseInt(li.dataset.nr, 10);
          var eingabe = li.querySelector('input');
          li.classList.remove('war-richtig', 'war-falsch');
          if (eingabe.checked) {
            li.classList.add(aufgabe.optionen[nr].richtig ? 'war-richtig' : 'war-falsch');
          }
        });
      }
      if (ergebnis.richtig === true || aufgabe.typ === 'frei') {
        el.querySelector('details.loesung').open = true;
      }
      if (typeof beiErgebnis === 'function') beiErgebnis(aufgabe, ergebnis);
    }

    if (knopf) knopf.addEventListener('click', auswerten);
    var textfeld = el.querySelector('input[type="text"]');
    if (textfeld) {
      textfeld.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') { e.preventDefault(); auswerten(); }
      });
    }
    return el;
  }

  return {
    pruefen: pruefen,
    rendern: rendern,
    tabelle: tabelle,
    NIVEAU_NAME: NIVEAU_NAME,
    KOMPETENZ_NAME: KOMPETENZ_NAME
  };
})();
