#!/usr/bin/env python3
"""
Statische Pruefung fuer BridgeLab - ohne Roblox.

Der Luau-Compiler findet nur Syntaxfehler. Diese Pruefung sucht die Fehler,
die beim Umbauen typischerweise entstehen und erst im Spiel auffallen wuerden:

  1. Aufrufe von Methoden, die es gar nicht gibt (Tippfehler)
  2. Felder, die benutzt, aber nie gesetzt werden  -> "attempt to index nil"
  3. RemoteEvents, bei denen ein Ende fehlt (nur Sender oder nur Empfaenger)
  4. Rueckruf-Felder (onXyz), die nie verdrahtet wurden
  5. Bedienelemente, die die Anleitung hervorheben will, aber nicht existieren
  6. Versehentlich doppelte Kommentarbloecke (Spur von Suchen-und-Ersetzen)

Aufruf aus dem Projektordner:
    python3 tools/check_code.py
"""

import collections
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Feldname -> Klasse, fuer Aufrufe wie self.structure:foo()
FIELD_CLASS = {
    "structure": "Structure",
    "forceEngine": "ForceEngine",
    "testRun": "TestRun",
    "hud": "BuildHud",
}

problems: list[str] = []


def note(message: str) -> None:
    problems.append(message)


files = sorted(SRC.rglob("*.luau"))
texts = {f: f.read_text(encoding="utf-8") for f in files}

# --- 1 und 2: Methoden und Felder --------------------------------------------

class_methods = collections.defaultdict(set)
file_methods = {}

for f, t in texts.items():
    own = set()
    for m in re.finditer(r"^function\s+([A-Za-z_]\w*)[:.](\w+)", t, re.M):
        class_methods[m.group(1)].add(m.group(2))
        own.add(m.group(2))
    file_methods[f] = own

for f, t in texts.items():
    rel = f.relative_to(ROOT)

    for m in re.finditer(r"\bself:(\w+)\s*\(", t):
        if m.group(1) not in file_methods[f]:
            line = t[: m.start()].count("\n") + 1
            note(f"{rel}:{line}  self:{m.group(1)}() gibt es in dieser Datei nicht")

    for m in re.finditer(r"\bself\.(\w+):(\w+)\s*\(", t):
        cls = FIELD_CLASS.get(m.group(1))
        if cls and m.group(2) not in class_methods[cls]:
            line = t[: m.start()].count("\n") + 1
            note(f"{rel}:{line}  self.{m.group(1)}:{m.group(2)}() -> {cls} kennt das nicht")

    assigned = set(re.findall(r"self\.(\w+)\s*=", t))
    used = set(re.findall(r"self\.(\w+)\b(?!\s*=)", t))
    for name in sorted(used - assigned - file_methods[f]):
        note(f"{rel}  self.{name} wird benutzt, aber nie gesetzt")

# --- 3 und 4: Verdrahtung ------------------------------------------------------

config = (SRC / "Shared" / "Config.luau").read_text(encoding="utf-8")
server = (SRC / "Server" / "init.server.luau").read_text(encoding="utf-8")
client = (SRC / "Client" / "init.client.luau").read_text(encoding="utf-8")

remote_names = re.findall(r'^\t"(\w+)",', config[config.index("Config.RemoteNames"):], re.M)

for name in remote_names:
    server_listens = f"remote.{name}.OnServerEvent" in server
    server_sends = f"remote.{name}:FireClient" in server or f"remote.{name}:FireAllClients" in server
    client_listens = f"remote.{name}.OnClientEvent" in client
    client_sends = f"remote.{name}:FireServer" in client

    if server_listens and not client_sends:
        note(f'RemoteEvent "{name}": Server hoert zu, aber niemand sendet')
    if server_sends and not client_listens:
        note(f'RemoteEvent "{name}": Server sendet, aber niemand hoert zu')
    if not (server_listens or server_sends):
        note(f'RemoteEvent "{name}" wird auf dem Server gar nicht benutzt')

for stem, variable in [("BuildHud", "hud"), ("BuildController", "controller"), ("LevelSelectGui", "levelSelect")]:
    body = (SRC / "Client" / f"{stem}.luau").read_text(encoding="utf-8")
    for m in re.finditer(r"self\.(on[A-Z]\w*)\s*=\s*nil", body):
        if f"{variable}.{m.group(1)} =" not in client:
            note(f"{stem}: Rueckruf {m.group(1)} wird nie verdrahtet")

# --- 5: Hervorhebungen der Anleitung ------------------------------------------

tutorial = (SRC / "Client" / "TutorialGui.luau").read_text(encoding="utf-8")
hud_source = (SRC / "Client" / "BuildHud.luau").read_text(encoding="utf-8")

# Manche Knopfnamen setzt das HUD zur Laufzeit zusammen, etwa
# "Material_" .. key. Nach dem fertigen Namen zu suchen, findet die also nie.
# Deshalb wird zusaetzlich geprueft, ob es ein passendes Namenspraefix gibt -
# sonst meldet die Pruefung dauernd Fehler, die keine sind, und man gewoehnt
# sich an, sie zu ueberlesen.
BUILT_PREFIXES = re.findall(r'"([A-Za-z]+_)"\s*\.\.', hud_source)

for m in re.finditer(r'highlight\s*=\s*"([^"]+)"', tutorial):
    name = m.group(1)
    generated = any(name.startswith(prefix) for prefix in BUILT_PREFIXES)
    if f'"{name}"' not in hud_source and not generated:
        note(f'Anleitung hebt "{name}" hervor - im HUD gibt es das nicht')

# --- 4b: Anzahl der Werte bei RemoteEvents ------------------------------------

# Der Client feuert "PlaceMember" mit sechs Werten, der Server nimmt sechs
# entgegen. Passt das nicht zusammen, kommt beim Server stillschweigend nil an -
# kein Fehler, keine Meldung, es funktioniert nur nicht. Beim Umstellen auf
# Koordinaten und spaeter beim Ergaenzen der Hydraulikphase war das jedes Mal
# eine Stelle, die man leicht vergisst.


def count_arguments(text: str) -> int:
    """Zaehlt die Werte einer Argumentliste, ohne Klammern zu verwechseln."""
    depth, count = 0, (1 if text.strip() else 0)
    for char in text:
        if char in "({[":
            depth += 1
        elif char in ")}]":
            depth -= 1
        elif char == "," and depth == 0:
            count += 1
    return count


sent: dict[str, int] = {}
for path in SRC.rglob("*.luau"):
    text = path.read_text(encoding="utf-8")
    for m in re.finditer(r"remote\.(\w+):FireServer\(([^\n]*)\)", text):
        # Erster Wert ist die Nutzlast, der Spieler kommt beim Server dazu.
        sent[m.group(1)] = max(sent.get(m.group(1), 0), count_arguments(m.group(2)))

server_text = (SRC / "Server" / "init.server.luau").read_text(encoding="utf-8")
for m in re.finditer(r"remote\.(\w+)\.OnServerEvent:Connect\(function\(([^)]*)\)", server_text):
    name, params = m.group(1), m.group(2)
    # "player" ist immer dabei und zaehlt nicht zur Nutzlast.
    taken = max(count_arguments(params) - 1, 0)
    given = sent.get(name)
    if given is not None and given > taken:
        note(
            f'RemoteEvent "{name}": der Client schickt {given} Werte, '
            f"der Server nimmt nur {taken} entgegen"
        )

# --- 5b: Ereignisse der Anleitung ---------------------------------------------

# Ein Schritt der Anleitung wartet auf ein Ereignis. Feuert es niemand, bleibt
# die Anleitung fuer immer stehen - und weil sie beim allerersten Spielstart
# laeuft, kaeme kein neuer Spieler je ins Spiel. Genau das war mit
# "memberPlaced" der Fall, nachdem das Bauen auf Ziehen umgestellt wurde.
awaited = set(re.findall(r'event\s*=\s*"(\w+)"', tutorial))
fired = set()
for path in SRC.rglob("*.luau"):
    fired |= set(re.findall(r'notify\("(\w+)"', path.read_text(encoding="utf-8")))

for event in sorted(awaited - fired):
    note(f'Anleitung wartet auf "{event}", aber niemand meldet es - sie bliebe dort stehen')

# Umgekehrt ist harmlos, aber ein Hinweis auf eine Umbenennung.
for event in sorted(fired - awaited):
    note(f'"{event}" wird gemeldet, aber kein Schritt der Anleitung wartet darauf')

# --- 6: Ordnernamen der Arena -------------------------------------------------

# Der LevelBuilder legt die Ordner an; Server und Client suchen sie darin
# wieder. Verwendet eine Seite einen Namen, den die andere nie anlegt, faellt
# das erst zur Laufzeit auf - und dann als leerer Bildschirm ohne Fehlermeldung.
# Genau so ist mir "Vehicle" gegen "Fahrzeuge" durchgerutscht.
builder = (SRC / "Server" / "LevelBuilder.luau").read_text(encoding="utf-8")

returned = set()
tail = builder[builder.rindex("return {"):] if "return {" in builder else ""
for m in re.finditer(r"^\s*(\w+)\s*=\s*\w+\s*,\s*$", tail, re.M):
    returned.add(m.group(1))

created = set(re.findall(r'folder\("([^"]+)"\)', builder))

for path in SRC.rglob("*.luau"):
    if path.name == "LevelBuilder.luau":
        continue
    text = path.read_text(encoding="utf-8")
    seen = set()
    for m in re.finditer(r"(?:self\.)?folders\.(\w+)", text):
        key = m.group(1)
        if returned and key not in returned and key not in seen:
            seen.add(key)
            note(f'{path.stem}: folders.{key} - den Ordner liefert LevelBuilder nicht')

# Der Client sucht die Ordner ueber ihren Namen in der Welt.
client_text = (SRC / "Client").rglob("*.luau")
for path in client_text:
    text = path.read_text(encoding="utf-8")
    for m in re.finditer(r'FindFirstChild\("(Bauteile|Knoten|Fahrzeuge|Welt|Anker|Effekte|Zierrat|[A-Z]\w*)"\)', text):
        name = m.group(1)
        # Nur Namen pruefen, die aussehen wie Arena-Ordner.
        if name in created or name not in {"Bauteile", "Knoten", "Fahrzeuge", "Welt", "Anker", "Effekte", "Zierrat"}:
            continue
        note(f'{path.stem}: sucht Ordner "{name}", den der LevelBuilder nicht anlegt')

# --- 7: Felder der Leveldaten -------------------------------------------------

# Der Code liest Felder aus den Leveldaten - level.maxDropStuds, boat.mastHeight
# und so weiter. Steht ein Feld unter einem anderen Namen in Levels.luau, faellt
# das erst auf, wenn genau dieses Level gespielt wird. Beim Schiff war es
# "width" gegen "length" und "mastHeight" gegen "height".
#
# Geprueft wird nur "level.<feld>". Ein "boat.<feld>" ist in TestRun das
# LAUFENDE Schiff mit Rumpf und Mast, nicht die Leveldaten - das mitzupruefen
# haette nur Fehlalarm gegeben.
#
# Uebersprungen werden Felder mit Ersatzwert ("level.z or 0"): die sind
# absichtlich freiwillig.
levels_text = (SRC / "Shared" / "Levels.luau").read_text(encoding="utf-8")
level_fields = set(re.findall(r"^\s*(\w+)\s*=", levels_text, re.M))
level_fields |= set(re.findall(r"level\.(\w+)\s*=", levels_text))
level_fields |= set(re.findall(r"function level\.(\w+)", levels_text))

# Nur SERVER-Dateien: dort ist "level" wirklich ein Eintrag aus Levels.luau.
# Der Client bekommt eine eigens zusammengestellte Tabelle mit anderen Feldern
# (etwa der Bauvorlage), und die hier mitzupruefen gaebe nur Fehlalarm.
for path in (SRC / "Server").rglob("*.luau"):
    text = path.read_text(encoding="utf-8")
    seen = set()
    for m in re.finditer(r"\b(?:self\.)?level\.(\w+)", text):
        field = m.group(1)
        if field in seen or field in level_fields:
            continue
        # Ersatzwert direkt dahinter? Dann ist das Feld freiwillig.
        rest = text[m.end():m.end() + 12]
        if rest.lstrip().startswith("or "):
            continue
        seen.add(field)
        note(f'{path.stem}: liest level.{field}, das es in Levels.luau nicht gibt')

# Die Felder des Schiffes gesondert: sie stehen in einer Untertabelle und
# heissen deshalb im Code "spec.<feld>", nicht "level.<feld>".
boat_keys = set()
if "boat = {" in levels_text:
    block = levels_text[levels_text.index("boat = {"):]
    block = block[:block.index("\n\t\t},")]
    boat_keys = set(re.findall(r"^\s*(\w+)\s*=", block, re.M))

testrun = (SRC / "Server" / "TestRun.luau").read_text(encoding="utf-8")
if boat_keys and "function TestRun:spawnBoat" in testrun:
    region = testrun[testrun.index("function TestRun:spawnBoat"):testrun.index("-- Hydraulik")]
    for m in re.finditer(r"\bspec\.(\w+)", region):
        field = m.group(1)
        if field in boat_keys:
            continue
        rest = region[m.end():m.end() + 12]
        if rest.lstrip().startswith("or "):
            continue
        note(f'TestRun: liest vom Schiff das Feld "{field}", das in Levels.luau fehlt')

# --- 7b: Kurzfassung fuers Levelmenue -----------------------------------------

# Die Levelauswahl zeigt nicht das ganze Level, sondern die Kurzfassung aus
# Levels.summaries(). Liest sie ein Feld, das dort nicht drinsteht, bleibt die
# Karte einfach leer oder es kracht - je nachdem, was mit dem nil passiert.
block = levels_text[levels_text.index("function Levels.summaries"):]
block = block[:block.index("\nend")]
provided = set(re.findall(r"^\s*(\w+)\s*=", block, re.M))

select_gui = (SRC / "Client" / "LevelSelectGui.luau").read_text(encoding="utf-8")
for field in sorted(set(re.findall(r"summary\.(\w+)", select_gui))):
    if field not in provided:
        note(f'LevelSelectGui: liest summary.{field}, das Levels.summaries() nicht liefert')

# --- 8: unbenutzte Einstellungen ----------------------------------------------

# Nach einem Umbau bleiben gern Einstellungen stehen, die niemand mehr liest -
# etwa "snapToleranceNear", nachdem das Anpeilen von Ankerpunkten durch
# Rasterrundung ersetzt wurde. Sie sind nicht falsch, aber irrefuehrend: wer
# daran dreht, wundert sich, dass nichts passiert.
config_text = (SRC / "Shared" / "Config.luau").read_text(encoding="utf-8")
other = "\n".join(
    t for f, t in texts.items() if f.name != "Config.luau"
)

for m in re.finditer(r"^\t(\w+)\s*=", config_text, re.M):
    key = m.group(1)
    if key not in other:
        note(f'Config: "{key}" wird nirgends benutzt')

# --- 8a: UIScale auf einer bildschirmfuellenden Wurzel -------------------------

# Ein UIScale skaliert nicht nur Groessen, sondern auch POSITIONEN. Sitzt er
# auf einer Wurzel, die den ganzen Bildschirm fuellt, landet deren rechte Kante
# bei einem Massstab von 0,7 nur noch bei 70 Prozent der Breite - die ganze
# Oberflaeche wird in die linke obere Ecke gequetscht, und die Leisten liegen
# uebereinander. Genau das war in VIER Dateien gleichzeitig falsch.
#
# Richtig ist, die Wurzel vorher um den Kehrwert groesser zu machen. Danach
# gesucht wird hier.
for path in (SRC / "Client").rglob("*.luau"):
    text = path.read_text(encoding="utf-8")
    if 'Instance.new("UIScale")' not in text:
        continue
    if "1 / factor" in text or "1 / math.max(factor" in text:
        continue
    note(
        f"{path.stem}: setzt einen UIScale, rechnet die Wurzel aber nicht gegen "
        "- die Oberflaeche wuerde in die linke obere Ecke rutschen"
    )

# --- 8b: Sprachschluessel -----------------------------------------------------

# Steht im Code ein Schluessel, den I18n nicht kennt, zeigt das Spiel den
# Schluessel selbst an - also "hud.budget" statt "Budget 12 / 800". Das ist
# Absicht (ein leeres Feld faellt niemandem auf), aber es soll natuerlich nie
# vorkommen. Deshalb wird hier verglichen.
i18n_text = (SRC / "Shared" / "I18n.luau").read_text(encoding="utf-8")

defined = {}
for m in re.finditer(r'^add\("([^"]+)",\s*\n?\s*"((?:[^"\\]|\\.)*)",\s*\n?\s*"((?:[^"\\]|\\.)*)"\)',
                     i18n_text, re.M):
    defined[m.group(1)] = (m.group(2), m.group(3))

# Auch die einzeiligen Eintraege einsammeln.
for m in re.finditer(r'^add\("([^"]+)"', i18n_text, re.M):
    defined.setdefault(m.group(1), None)

# Manche Fenster speichern einen BASISSCHLUESSEL und haengen beim Anzeigen
# ".title" bzw. ".text" an (Anleitung, Bauschule). Deren "key = ..." darf man
# nicht direkt nachschlagen - der Basisschluessel selbst steht nie in I18n.
# Erkannt werden solche Dateien daran, dass sie genau das tun.
suffix_files = {}
for path in SRC.rglob("*.luau"):
    text = path.read_text(encoding="utf-8")
    suffixes = set(re.findall(r'(?:key|\.key)\s*\.\.\s*"\.(\w+)"', text))
    if suffixes:
        suffix_files[path] = sorted(suffixes)

used = set()
for path in SRC.rglob("*.luau"):
    if path.name == "I18n.luau" or path in suffix_files:
        continue
    text = path.read_text(encoding="utf-8")
    used |= set(re.findall(r'I18n\.t\("([^"]+)"', text))
    used |= set(re.findall(r'key = "([a-z][\w.]*\.[\w.]+)"', text))

# Bei den Basisschluessel-Dateien stattdessen jede Endung einzeln pruefen.
for path, suffixes in suffix_files.items():
    text = path.read_text(encoding="utf-8")
    used |= set(re.findall(r'I18n\.t\("([^"]+)"', text))
    for base in sorted(set(re.findall(r'key = "([a-z][\w.]*)"', text))):
        for suffix in suffixes:
            if f"{base}.{suffix}" not in defined:
                note(f'{path.stem}: "{base}.{suffix}" fehlt in I18n.luau')

# Schluessel, die zur Laufzeit zusammengesetzt werden ("world." .. name), enden
# im Quelltext auf einem Punkt. Die lassen sich so nicht pruefen.
used = {key for key in used if not key.endswith(".")}

for key in sorted(used - set(defined)):
    note(f'Sprachschluessel "{key}" wird benutzt, steht aber nicht in I18n.luau')

# Jede Welt, die in den Leveldaten vorkommt, braucht einen Namen.
for world in sorted(set(re.findall(r'world = "([^"]+)"', levels_text))):
    if f"world.{world}" not in defined:
        note(f'Welt "{world}" hat keinen Namen in I18n.luau ("world.{world}")')

# Ebenso die fuenf Schwierigkeitsgrade.
for level in range(1, 6):
    if f"difficulty.{level}" not in defined:
        note(f'Schwierigkeitsgrad {level} fehlt in I18n.luau ("difficulty.{level}")')

# Zusammengesetzte Schluessel ("difficulty." .. n) lassen sich nicht so pruefen.
# Deshalb die bekannten Familien einzeln nachsehen.
for level_id in re.findall(r'id = "(\w+)"', levels_text):
    for suffix in ("name", "subtitle"):
        key = f"level.{level_id}.{suffix}"
        if key not in defined:
            note(f'Level {level_id}: "{key}" fehlt in I18n.luau')

# Zu jedem Level so viele Tipptexte wie hintCount.
for m in re.finditer(r'id = "(\w+)"(.*?)hintCount = (\d+)', levels_text, re.S):
    level_id, count = m.group(1), int(m.group(3))
    for index in range(1, count + 1):
        key = f"level.{level_id}.hint{index}"
        if key not in defined:
            note(f'Level {level_id}: Tipp {index} fehlt in I18n.luau ("{key}")')

# Beide Sprachen muessen dieselben Platzhalter haben, sonst stehen die Werte
# in einer Sprache an der falschen Stelle - oder es kracht beim Einsetzen.
for key, pair in defined.items():
    if not pair:
        continue
    de_slots = sorted(re.findall(r"%[-+ #0]*[\d.]*([a-zA-Z%])", pair[0]))
    en_slots = sorted(re.findall(r"%[-+ #0]*[\d.]*([a-zA-Z%])", pair[1]))
    if de_slots != en_slots:
        note(f'Sprachschluessel "{key}": Platzhalter unterscheiden sich (de {de_slots}, en {en_slots})')

# --- 9: unbekannte Namen (luau-analyze) ---------------------------------------

# luau-analyze findet Namen, die nirgends deklariert sind - etwa einen
# Parameter, der beim Umbenennen an einer Stelle stehen geblieben ist. Der
# Compiler sieht das nicht: in Luau ist ein unbekannter Name einfach nil, und
# die Datei uebersetzt sauber. Erst im Spiel faellt auf, dass eine Funktion
# stillschweigend mit nil arbeitet. Genau so ein Fall war hud.onSelectMaterial.
#
# Ist luau-analyze nicht installiert, wird der Schritt einfach uebersprungen -
# die Pruefung soll auch ohne laufen.
import shutil
import subprocess

# Roblox-Typen und -Globale kennt das Werkzeug ausserhalb von Studio nicht.
# Sie zu melden waere reines Rauschen, in dem echte Funde untergehen.
ROBLOX_GLOBALS = {
    "Color3", "Vector3", "Vector2", "Instance", "Enum", "UDim2", "UDim",
    "CFrame", "game", "workspace", "script", "Random", "NumberRange",
    "NumberSequence", "NumberSequenceKeypoint", "ColorSequence",
    "ColorSequenceKeypoint", "PhysicalProperties", "task", "Ray",
    "RaycastParams", "TweenInfo", "DateTime", "BrickColor", "warn", "os",
}

if shutil.which("luau-analyze"):
    result = subprocess.run(
        ["luau-analyze", str(SRC)],
        capture_output=True, text=True,
    )
    for line in (result.stdout + result.stderr).splitlines():
        m = re.search(r"Unknown global '([A-Za-z0-9_]+)'", line)
        if m and m.group(1) not in ROBLOX_GLOBALS:
            where = line.split(":")[0]
            note(f"{where}: unbekannter Name '{m.group(1)}' - Tippfehler oder Umbenennung?")
else:
    print("   (luau-analyze nicht gefunden - Schritt 9 uebersprungen)")

# --- 10: doppelte Kommentarbloecke --------------------------------------------

for f, t in texts.items():
    blocks = [" ".join(b.split()) for b in re.findall(r"--\[\[(.*?)\]\]", t, re.S)]
    for text, count in collections.Counter(b for b in blocks if len(b) > 60).items():
        if count > 1:
            note(f'{f.relative_to(ROOT)}: Kommentarblock steht {count}x drin - "{text[:60]}..."')

# --- Ergebnis -----------------------------------------------------------------

print(f"{len(files)} Dateien, {sum(len(v) for v in file_methods.values())} Methoden, "
      f"{len(remote_names)} RemoteEvents geprueft.\n")

if problems:
    print(f"{len(problems)} Auffaelligkeit(en):")
    for p in problems:
        print("  - " + p)
    sys.exit(1)

print("Nichts gefunden.")
