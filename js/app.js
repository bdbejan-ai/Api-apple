/* app.js — Navigation, Seitenaufbau, Verknüpfung von Inhalt und Fortschritt. */
(function () {
  'use strict';

  var P = window.Physik;
  var F = P.Formel, D = P.Diagramm, A = P.Aufgaben, FS = P.Fortschritt, I = P.Inhalt;

  var haupt = document.getElementById('hauptbereich');
  var leiste = document.getElementById('seitenleiste');

  function schuetzen(t) {
    return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function einheitenVon(modulId) { return I.lerneinheiten[modulId] || []; }
  function aufgabenVon(modulId) { return I.aufgaben[modulId] || []; }

  /* ---------------------------------------------------------------
     Bausteine einer Lerneinheit
     --------------------------------------------------------------- */

  function zeichenliste(zeichen) {
    if (!zeichen || !zeichen.length) return '';
    return '<ul class="zeichenliste">' + zeichen.map(function (z) {
      return '<li><span class="zeichen">' + F.inline(z.z) + '</span>' +
        '<span>' + schuetzen(z.bedeutung) + '</span>' +
        '<span class="einheit">' + (z.einheit ? 'in ' + schuetzen(z.einheit) : '') + '</span></li>';
    }).join('') + '</ul>';
  }

  function bausteinHtml(b, nr) {
    switch (b.typ) {
      case 'text':
        return '<p>' + F.imText(b.inhalt) + '</p>';

      case 'merksatz':
        return '<div class="merksatz"><span class="etikett">Merksatz</span>' +
          F.imText(b.inhalt) + '</div>';

      case 'formel':
        return '<div class="karte">' + F.block(b.quelle) + zeichenliste(b.zeichen) +
          (b.hinweis ? '<p class="klein">' + F.imText(b.hinweis) + '</p>' : '') + '</div>';

      case 'beispiel':
        return '<div class="karte"><h3>' + schuetzen(b.titel) + '</h3>' +
          '<ol class="rechenweg">' + b.schritte.map(function (s) {
            return '<li><span class="schritt-name">' + schuetzen(s.schritt) + '</span>' +
              F.imText(s.inhalt) + '</li>';
          }).join('') + '</ol></div>';

      case 'fehlvorstellung':
        return '<div class="karte fehlvorstellung">' +
          '<span class="etikett klein leise"><b>Häufige Fehlvorstellung</b></span>' +
          '<p class="behauptung">„' + F.imText(b.behauptung) + '"</p>' +
          '<p class="stufe"><b>Prüfen wir das.</b> ' + F.imText(b.pruefung) + '</p>' +
          '<p class="stufe"><b>Richtig ist.</b> ' + F.imText(b.richtig) + '</p></div>';

      case 'experiment':
        return '<div class="karte experiment"><h3>Experiment</h3>' +
          '<p><b>Untersuchungsfrage:</b> ' + F.imText(b.frage) + '</p><dl>' +
          '<dt>Aufbau</dt><dd>' + F.imText(b.aufbau) + '</dd>' +
          '<dt>Messgrößen</dt><dd>' + F.imText(b.messgroessen) + '</dd>' +
          '<dt>Durchführung</dt><dd>' + F.imText(b.durchfuehrung) + '</dd>' +
          '<dt>Auswertung</dt><dd>' + F.imText(b.auswertung) + '</dd>' +
          '<dt>Fehlerquellen</dt><dd>' + F.imText(b.fehlerquellen) + '</dd>' +
          (b.varianten ? '<dt>Wenn die Ausrüstung fehlt</dt><dd><ul>' +
            b.varianten.map(function (v) { return '<li>' + F.imText(v) + '</li>'; }).join('') +
            '</ul></dd>' : '') + '</dl></div>';

      case 'sprache':
        return '<div class="karte sprachkasten"><h3>Alltagssprache und Fachsprache</h3>' +
          '<table><thead><tr><th scope="col">gesagt wird</th><th scope="col">gemeint ist</th></tr></thead><tbody>' +
          b.zeilen.map(function (z) {
            return '<tr><td>' + F.imText(z.alltag) + '</td><td>' + F.imText(z.fach) + '</td></tr>';
          }).join('') + '</tbody></table></div>';

      case 'diagramm':
        return D.figur(b.spez);

      case 'tabelle':
        return A.tabelle(b.spez);

      case 'simulation':
        return '<div class="simulation-block">' +
          (b.einleitung ? '<p>' + F.imText(b.einleitung) + '</p>' : '') +
          '<div data-simulation="' + schuetzen(b.name) + '"></div>' +
          (b.beobachte ? '<div class="karte"><p class="klein leise" style="margin-top:0">' +
            '<b>Worauf du achten solltest</b></p><ul class="klein">' +
            b.beobachte.map(function (x) { return '<li>' + F.imText(x) + '</li>'; }).join('') +
            '</ul></div>' : '') + '</div>';

      case 'frage':
        return '<div data-frage="' + nr + '"></div>';

      default:
        return '<p class="leise">Unbekannter Baustein: ' + schuetzen(b.typ) + '</p>';
    }
  }

  /* Sofortfragen innerhalb einer Lerneinheit — leichtgewichtiger als eine Aufgabe. */
  function frageElement(baustein) {
    var el = document.createElement('div');
    el.className = 'karte';
    el.innerHTML = '<p><b>Zwischenfrage</b> ' + F.imText(baustein.text) + '</p>' +
      '<ul class="optionen">' + baustein.optionen.map(function (o, i) {
        return '<li data-nr="' + i + '"><label><input type="radio" name="zf-' +
          Math.random().toString(36).slice(2, 8) + '" value="' + i + '"><span>' +
          F.imText(o.text) + '</span></label></li>';
      }).join('') + '</ul><div class="rueckmeldung-platz" aria-live="polite"></div>';

    el.addEventListener('change', function (e) {
      if (e.target.type !== 'radio') return;
      var nr = parseInt(e.target.value, 10);
      var option = baustein.optionen[nr];
      el.querySelector('.rueckmeldung-platz').innerHTML =
        '<div class="rueckmeldung ' + (option.richtig ? 'richtig' : 'falsch') + '"><b>' +
        (option.richtig ? 'Richtig.' : 'Noch nicht.') + '</b>' +
        F.imText(option.rueckmeldung || '') + '</div>';
      Array.prototype.forEach.call(el.querySelectorAll('.optionen li'), function (li) {
        var k = parseInt(li.dataset.nr, 10);
        li.classList.remove('war-richtig', 'war-falsch');
        if (li.querySelector('input').checked) {
          li.classList.add(baustein.optionen[k].richtig ? 'war-richtig' : 'war-falsch');
        }
      });
    });
    return el;
  }

  /* ---------------------------------------------------------------
     Seiten
     --------------------------------------------------------------- */

  function zeigeStart() {
    var m1 = I.modulNach('m1');
    var alleAufgaben = aufgabenVon('m1').map(function (a) { return a.id; });
    var stand = FS.modulStand(alleAufgaben);
    var faellige = FS.faellig(alleAufgaben);

    var html = '<h1>Mechanik der Einführungsphase</h1>' +
      '<p class="vorspann">Ein Lernprogramm für den Physikunterricht der EF in Nordrhein-Westfalen — ' +
      'mit Aufgaben auf drei Niveaustufen bis hinauf zur Vorbereitung auf den Leistungskurs.</p>';

    if (FS.speicherFehlt()) {
      html += '<div class="karte" style="border-color:var(--hinweis)"><p style="margin:0"><b>Hinweis:</b> ' +
        'Dein Browser lässt das dauerhafte Speichern gerade nicht zu (privates Fenster oder gesperrte ' +
        'Website-Daten). Das Programm funktioniert vollständig, dein Lernstand geht aber beim Schließen ' +
        'des Tabs verloren.</p></div>';
    }

    html += '<h2>So arbeitest du damit</h2>' +
      '<p>Jedes Modul besteht aus Lerneinheiten von etwa zehn bis fünfzehn Minuten und einem ' +
      'Aufgabenteil. Die Aufgaben sind mit <b>Basis</b>, <b>Standard</b> und <b>LK-Vertiefung</b> ' +
      'gekennzeichnet. Zu jeder Aufgabe gibt es drei gestufte Hilfen und einen vollständigen ' +
      'Lösungsweg — beides ist zum Benutzen da, nicht zum Aufheben für später.</p>';

    if (stand.versucht > 0) {
      html += '<div class="karte empfehlung"><h3 style="margin-top:0">Weiter geht es hier</h3>' +
        '<p>Du hast in ' + m1.titel + ' bisher <b>' + stand.geloest + ' von ' + stand.gesamt +
        '</b> Aufgaben gelöst.' +
        (faellige.length ? ' <b>' + faellige.length + '</b> Aufgabe' + (faellige.length === 1 ? '' : 'n') +
          ' steht zur Wiederholung an.' : '') + '</p>' +
        '<div class="knopfreihe"><a class="knopf haupt" href="#/aufgaben/m1">Zu den Aufgaben</a>' +
        '<a class="knopf" href="#/fortschritt">Lernstand ansehen</a></div></div>';
    }

    html += '<h2>Module</h2><ul class="einheit-liste">';
    I.module.forEach(function (m) {
      html += '<li><a href="#/modul/' + m.id + '"><span class="kuerzel leise">' + m.kuerzel + '</span>' +
        '<span><b>' + schuetzen(m.titel) + '</b><br><span class="klein leise">' +
        schuetzen(m.kurz) + '</span></span>' +
        (m.gefuellt ? '' : '<span class="leer-marke">noch nicht befüllt</span>') + '</a></li>';
    });
    html += '</ul>';

    html += '<div class="karte"><h3 style="margin-top:0">Querschnitt: ' +
      schuetzen(I.querschnitt.titel) + '</h3><p class="klein">' + schuetzen(I.querschnitt.kurz) +
      '</p><p class="klein leise" style="margin-bottom:0">Kein eigenes Modul — der Querschnitt ' +
      schuetzen(I.querschnitt.verteiltAuf) + '. In M1 steckt er in der Lerneinheit ' +
      '„Eine Messreihe auswerten".</p></div>';

    haupt.innerHTML = html;
  }

  function zeigeModul(id) {
    var m = I.modulNach(id);
    if (!m) return zeigeFehler('Dieses Modul gibt es nicht.');

    var einheiten = einheitenVon(id);
    var aufgaben = aufgabenVon(id);

    var html = '<p class="brotkrumen"><a href="#/">Übersicht</a> › ' + m.kuerzel + '</p>' +
      '<h1>' + schuetzen(m.titel) + '</h1>' +
      '<p class="vorspann">' + schuetzen(m.kurz) + '<br><span class="klein">Leitkontext: ' +
      schuetzen(m.kontext) + '</span></p>';

    if (!m.gefuellt) {
      html += '<div class="karte platzhalter"><p><b>Dieses Modul ist noch nicht befüllt.</b></p>' +
        '<p class="klein">Die Gliederung steht, Lerneinheiten und Aufgaben fehlen. ' +
        'Was hier entstehen soll:</p><ul class="klein" style="text-align:left;display:inline-block">' +
        m.kerninhalte.map(function (k) { return '<li>' + schuetzen(k) + '</li>'; }).join('') +
        '</ul></div>' +
        '<p class="klein leise">Vollständig ausgearbeitet ist bisher ' +
        '<a href="#/modul/m1">M1 — Bewegungen beschreiben</a>. Es dient als Vorlage für die ' +
        'übrigen Module.</p>';
      haupt.innerHTML = html;
      return;
    }

    html += '<h2>Lerneinheiten</h2><ul class="einheit-liste">';
    einheiten.forEach(function (le, i) {
      html += '<li><a href="#/einheit/' + le.id + '">' +
        '<span class="kuerzel leise">' + (i + 1) + '</span>' +
        '<span>' + schuetzen(le.titel) + '</span>' +
        (FS.istGelesen(le.id) ? '<span class="haken" title="bearbeitet">✓</span>' : '') +
        '<span class="dauer">' + le.dauer + ' min</span></a></li>';
    });
    html += '</ul>';

    var stand = FS.modulStand(aufgaben.map(function (a) { return a.id; }));
    html += '<h2>Aufgaben</h2><p>' + aufgaben.length + ' Aufgaben auf drei Niveaustufen. ' +
      'Bearbeitet: <b>' + stand.geloest + '</b> richtig gelöst.</p>' +
      '<div class="knopfreihe"><a class="knopf haupt" href="#/aufgaben/' + id + '">Aufgaben öffnen</a></div>';

    html += '<h2>Was du am Ende können sollst</h2><ul>' +
      m.kerninhalte.map(function (k) { return '<li>' + schuetzen(k) + '</li>'; }).join('') + '</ul>';

    haupt.innerHTML = html;
  }

  function zeigeEinheit(id) {
    var modulId = id.split('-')[0];
    var liste = einheitenVon(modulId);
    var nr = -1, le = null;
    liste.forEach(function (x, i) { if (x.id === id) { le = x; nr = i; } });
    if (!le) return zeigeFehler('Diese Lerneinheit gibt es nicht.');

    var m = I.modulNach(modulId);
    var html = '<p class="brotkrumen"><a href="#/">Übersicht</a> › ' +
      '<a href="#/modul/' + modulId + '">' + m.kuerzel + '</a> › Lerneinheit ' + (nr + 1) + '</p>' +
      '<h1>' + schuetzen(le.titel) + '</h1>' +
      '<p class="vorspann">' + F.imText(le.leitfrage) + '</p>';

    haupt.innerHTML = html;

    le.bausteine.forEach(function (b, i) {
      if (b.typ === 'frage') {
        haupt.appendChild(frageElement(b));
        return;
      }
      var huelle = document.createElement('div');
      huelle.innerHTML = bausteinHtml(b, i);
      while (huelle.firstChild) haupt.appendChild(huelle.firstChild);
    });

    Array.prototype.forEach.call(haupt.querySelectorAll('[data-simulation]'), function (ziel) {
      P.Simulation.erzeugen(ziel.dataset.simulation, ziel);
    });

    var fuss = document.createElement('div');
    fuss.className = 'blaettern';
    fuss.innerHTML =
      (nr > 0 ? '<a class="knopf" href="#/einheit/' + liste[nr - 1].id + '">← ' +
        schuetzen(liste[nr - 1].titel) + '</a>' : '<span></span>') +
      (nr < liste.length - 1 ? '<a class="knopf haupt" href="#/einheit/' + liste[nr + 1].id + '">' +
        schuetzen(liste[nr + 1].titel) + ' →</a>'
        : '<a class="knopf haupt" href="#/aufgaben/' + modulId + '">Zu den Aufgaben →</a>');
    haupt.appendChild(fuss);

    FS.einheitGelesen(le.id);
  }

  function zeigeAufgaben(modulId) {
    var m = I.modulNach(modulId);
    var aufgaben = aufgabenVon(modulId);
    if (!m || !aufgaben.length) return zeigeFehler('Für dieses Modul gibt es noch keine Aufgaben.');

    var ids = aufgaben.map(function (a) { return a.id; });
    var faellige = FS.faellig(ids);

    haupt.innerHTML = '<p class="brotkrumen"><a href="#/">Übersicht</a> › ' +
      '<a href="#/modul/' + modulId + '">' + m.kuerzel + '</a> › Aufgaben</p>' +
      '<h1>Aufgaben — ' + schuetzen(m.titel) + '</h1>' +
      '<p class="vorspann">Zu jeder Aufgabe gehören drei gestufte Hilfen und ein vollständiger ' +
      'Lösungsweg. Nutze sie, bevor du eine Aufgabe überspringst.</p>' +
      (faellige.length ? '<div class="karte empfehlung"><p style="margin:0"><b>Zur Wiederholung: </b>' +
        faellige.length + ' Aufgabe' + (faellige.length === 1 ? '' : 'n') +
        ' liegt zur Wiedervorlage an — sie ' + (faellige.length === 1 ? 'ist' : 'sind') +
        ' unten mit einem Punkt gekennzeichnet.</p></div>' : '');

    ['basis', 'standard', 'vertiefung'].forEach(function (niveau) {
      var teil = aufgaben.filter(function (a) { return a.niveau === niveau; });
      if (!teil.length) return;
      var h2 = document.createElement('h2');
      h2.textContent = A.NIVEAU_NAME[niveau] + ' (' + teil.length + ')';
      haupt.appendChild(h2);

      teil.forEach(function (aufgabe) {
        var nummer = aufgaben.indexOf(aufgabe) + 1;
        var el = A.rendern(aufgabe, nummer, function (a, ergebnis) {
          FS.ergebnisMerken(a.id, ergebnis.richtig);
        });
        if (faellige.indexOf(aufgabe.id) >= 0) {
          el.querySelector('.nummer').insertAdjacentHTML('afterend',
            '<span class="marke-klein" title="steht zur Wiederholung an">● Wiederholung</span>');
        }
        var stand = FS.aufgabenStand(aufgabe.id);
        if (stand && stand.richtig) {
          el.querySelector('.nummer').insertAdjacentHTML('afterend',
            '<span class="marke-klein" style="color:var(--richtig)">✓ gelöst</span>');
        }
        haupt.appendChild(el);
      });
    });
  }

  function zeigeFortschritt() {
    var html = '<p class="brotkrumen"><a href="#/">Übersicht</a> › Lernstand</p><h1>Dein Lernstand</h1>' +
      '<p class="vorspann">Alles steht ausschließlich in diesem Browser. Es gibt kein Konto, keine ' +
      'Anmeldung und keine Übertragung an einen Server.</p>';

    html += '<h2>Kompetenzraster</h2><div class="tabellen-rahmen"><table class="raster"><thead><tr>' +
      '<th scope="col">Modul</th><th scope="col">gelöst</th><th scope="col">Stand</th>' +
      '<th scope="col">Selbsteinschätzung</th></tr></thead><tbody>';

    I.module.forEach(function (m) {
      var ids = aufgabenVon(m.id).map(function (a) { return a.id; });
      var stand = FS.modulStand(ids);
      var text = { sicher: 'kann ich sicher', hilfe: 'geht mit Hilfe', offen: 'noch nicht begonnen' }[stand.stand];
      var klasse = { sicher: 'stand-sicher', hilfe: 'stand-hilfe', offen: 'stand-offen' }[stand.stand];
      var selbst = FS.selbstLesen(m.id) || '';
      html += '<tr><td><b>' + m.kuerzel + '</b> ' + schuetzen(m.titel) +
        (m.gefuellt ? '' : ' <span class="leer-marke">leer</span>') + '</td>' +
        '<td>' + (ids.length ? stand.geloest + ' / ' + stand.gesamt : '—') +
        '<div class="balken"><i style="width:' + Math.round(stand.quote * 100) + '%"></i></div></td>' +
        '<td class="stand ' + klasse + '">' + text + '</td>' +
        '<td><label class="nur-lesegeraet" for="selbst-' + m.id + '">Selbsteinschätzung ' +
        schuetzen(m.titel) + '</label>' +
        '<select id="selbst-' + m.id + '" data-modul="' + m.id + '"' + (ids.length ? '' : ' disabled') + '>' +
        ['', 'sicher', 'mit Hilfe', 'noch nicht'].map(function (w) {
          return '<option value="' + w + '"' + (selbst === w ? ' selected' : '') + '>' +
            (w || 'bitte wählen') + '</option>';
        }).join('') + '</select></td></tr>';
    });
    html += '</tbody></table></div>' +
      '<p class="klein leise">Die Spalte „Stand" wird gemessen, die Spalte „Selbsteinschätzung" ' +
      'trägst du selbst ein. Beide getrennt zu betrachten ist Absicht: Wo sie auseinanderfallen, ' +
      'lohnt sich ein zweiter Blick.</p>';

    var alle = [];
    I.module.forEach(function (m) { alle = alle.concat(aufgabenVon(m.id).map(function (a) { return a.id; })); });
    var faellige = FS.faellig(alle), offen = FS.nieBearbeitet(alle);

    html += '<h2>Das solltest du als Nächstes üben</h2><div class="karte empfehlung"><ul style="margin:0">';
    if (faellige.length) {
      html += '<li><b>' + faellige.length + ' Aufgabe' + (faellige.length === 1 ? '' : 'n') +
        '</b> zur Wiederholung — falsch beantwortete Aufgaben kommen nach einem Tag zurück, ' +
        'sicher gelöste erst nach zehn.</li>';
    }
    if (offen.length) {
      html += '<li><b>' + offen.length + '</b> noch nie bearbeitete Aufgaben.</li>';
    }
    if (!faellige.length && !offen.length) {
      html += '<li>Im Moment steht nichts an. Alle vorhandenen Aufgaben sind bearbeitet.</li>';
    }
    html += '</ul></div>';

    html += '<h2>Deine Daten</h2><div class="karte">' +
      '<p class="klein">Gespeichert werden nur Aufgabenkennungen, Versuchszahlen und Zeitstempel — ' +
      'keine Namen, keine Texte, keine Antworten im Wortlaut.</p>' +
      '<div class="knopfreihe">' +
      '<button class="knopf" id="fs-export">Lernstand als Datei sichern</button>' +
      '<button class="knopf" id="fs-import">Lernstand aus Datei laden</button>' +
      '<button class="knopf" id="fs-loeschen">Alles löschen</button>' +
      '<input type="file" id="fs-datei" accept="application/json,.json" hidden>' +
      '</div><p class="klein leise" id="fs-meldung" aria-live="polite" style="margin-bottom:0"></p></div>';

    haupt.innerHTML = html;

    Array.prototype.forEach.call(haupt.querySelectorAll('select[data-modul]'), function (s) {
      s.addEventListener('change', function () { FS.selbstSetzen(s.dataset.modul, s.value); });
    });

    var meldung = document.getElementById('fs-meldung');

    document.getElementById('fs-export').addEventListener('click', function () {
      var blob = new Blob([FS.exportieren()], { type: 'application/json' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = 'physik-ef-lernstand.json';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
      meldung.textContent = 'Datei wurde erzeugt.';
    });

    document.getElementById('fs-import').addEventListener('click', function () {
      document.getElementById('fs-datei').click();
    });

    document.getElementById('fs-datei').addEventListener('change', function (e) {
      var datei = e.target.files && e.target.files[0];
      if (!datei) return;
      var leser = new FileReader();
      leser.onload = function () {
        try {
          FS.importieren(String(leser.result));
          meldung.textContent = 'Lernstand geladen.';
          zeigeFortschritt();
        } catch (fehler) {
          meldung.textContent = 'Die Datei konnte nicht gelesen werden: ' + fehler.message;
        }
      };
      leser.readAsText(datei);
    });

    document.getElementById('fs-loeschen').addEventListener('click', function () {
      if (!window.confirm('Wirklich den gesamten Lernstand löschen? Das lässt sich nicht rückgängig machen.')) return;
      FS.loeschen();
      zeigeFortschritt();
    });
  }

  function zeigeFehler(text) {
    haupt.innerHTML = '<h1>Nicht gefunden</h1><p>' + schuetzen(text) + '</p>' +
      '<div class="knopfreihe"><a class="knopf haupt" href="#/">Zur Übersicht</a></div>';
  }

  /* ---------------------------------------------------------------
     Navigation und Rahmen
     --------------------------------------------------------------- */

  function leisteAufbauen() {
    var html = '<p class="nav-titel">Module</p>';
    I.module.forEach(function (m) {
      html += '<a class="nav-modul' + (m.gefuellt ? '' : ' leer') + '" href="#/modul/' + m.id + '">' +
        '<span class="kuerzel">' + m.kuerzel + '</span><span>' + schuetzen(m.titel) + '</span>' +
        (m.gefuellt ? '' : '<span class="leer-marke">leer</span>') + '</a>';
    });
    html += '<p class="nav-titel">Mehr</p>' +
      '<a class="nav-modul" href="#/fortschritt"><span class="kuerzel">✓</span><span>Lernstand</span></a>';
    leiste.innerHTML = html;
  }

  function leisteMarkieren(pfad) {
    Array.prototype.forEach.call(leiste.querySelectorAll('.nav-modul'), function (a) {
      var passt = a.getAttribute('href') === '#' + pfad ||
        (pfad.indexOf('/einheit/') === 0 && a.getAttribute('href') === '#/modul/' + pfad.split('/')[2].split('-')[0]) ||
        (pfad.indexOf('/aufgaben/') === 0 && a.getAttribute('href') === '#/modul/' + pfad.split('/')[2]);
      if (passt) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
  }

  function leiten() {
    var pfad = window.location.hash.replace(/^#/, '') || '/';
    var teile = pfad.split('/').filter(function (x) { return x !== ''; });

    if (teile.length === 0) zeigeStart();
    else if (teile[0] === 'modul') zeigeModul(teile[1]);
    else if (teile[0] === 'einheit') zeigeEinheit(teile[1]);
    else if (teile[0] === 'aufgaben') zeigeAufgaben(teile[1]);
    else if (teile[0] === 'fortschritt') zeigeFortschritt();
    else zeigeFehler('Diese Adresse kenne ich nicht.');

    leisteMarkieren(pfad);
    leiste.classList.remove('offen');
    document.getElementById('menue-schalter').setAttribute('aria-expanded', 'false');
    /* focus() würde das Element in den sichtbaren Bereich scrollen und dabei die
       Brotkrumen unter die feste Kopfzeile schieben — deshalb ohne Scrollen. */
    haupt.focus({ preventScroll: true });
    window.scrollTo(0, 0);
  }

  function themaAnwenden(thema) {
    document.documentElement.setAttribute('data-thema', thema);
    document.getElementById('thema-symbol').textContent = thema === 'dunkel' ? '☀' : '☾';
    try { window.localStorage.setItem('physik-ef-thema', thema); } catch (f) { /* egal */ }
  }

  function themaLaden() {
    var gespeichert = null;
    try { gespeichert = window.localStorage.getItem('physik-ef-thema'); } catch (f) { /* egal */ }
    if (gespeichert) return gespeichert;
    return (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches)
      ? 'dunkel' : 'hell';
  }

  function starten() {
    leisteAufbauen();
    themaAnwenden(themaLaden());

    document.getElementById('thema-schalter').addEventListener('click', function () {
      themaAnwenden(document.documentElement.getAttribute('data-thema') === 'dunkel' ? 'hell' : 'dunkel');
    });

    document.getElementById('menue-schalter').addEventListener('click', function () {
      var offen = leiste.classList.toggle('offen');
      this.setAttribute('aria-expanded', offen ? 'true' : 'false');
    });

    window.addEventListener('hashchange', leiten);
    leiten();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', starten);
  else starten();
})();
