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

for m in re.finditer(r'highlight\s*=\s*"([^"]+)"', tutorial):
    name = m.group(1)
    generated = name.startswith("Part_") and '"Part_" .. key' in hud_source
    if f'"{name}"' not in hud_source and not generated:
        note(f'Anleitung hebt "{name}" hervor - im HUD gibt es das nicht')

# --- 6: doppelte Kommentarbloecke ---------------------------------------------

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
