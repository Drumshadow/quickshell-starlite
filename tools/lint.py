#!/usr/bin/env python3
"""
Static checks for quickshell-starlite QML.

Every rule here corresponds to something that actually broke this codebase at
runtime (docs/QUICKSHELL-NOTES.md) or to an architectural boundary we have
decided to keep. Three of the nine bugs found by running the shell were
mechanically detectable; this is that grep, made honest.

    tools/lint.py           # check
    tools/lint.py --list    # show the rules

Exit 1 on ERROR, 0 on WARN-only. Needs nothing but Python.
"""
import os, re, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {".git", "out", "docs", "tools"}

# Types QtQuick already defines — a same-named component of ours is shadowed and
# silently unreachable (this is how Services/Rotation.qml was lost).
QTQUICK_BUILTINS = {
    "Rotation", "Scale", "Translate", "Item", "Rectangle", "Text", "Image",
    "Row", "Column", "Grid", "Flow", "Repeater", "Loader", "Timer", "Behavior",
    "Transition", "State", "Component", "Connections", "Binding", "Shape",
    "Animation", "Gradient", "Flickable", "MouseArea", "TextInput", "TextEdit",
}
# Helpers that return a COLOUR: unreliable inside a property binding.
COLOUR_FNS = ("inkOn(", "mix(", "lift(", "sink(")

RULES = [
    ("QS001", "ERROR", "property named `on` + Uppercase (QML parses it as a signal handler)"),
    ("QS002", "ERROR", "`;` after an inline nested object declaration"),
    ("QS003", "ERROR", "qmldir out of sync with the directory, or declares a `module`"),
    ("QS004", "ERROR", "entry point (ShellRoot) outside the repo root"),
    ("QS005", "ERROR", "type name declared in two qmldirs, or shadowing a QtQuick built-in"),
    ("QS006", "ERROR", "unbalanced braces/parens"),
    ("QS007", "WARN",  "colour-returning helper used inside a property binding"),
    ("QS008", "WARN",  "colour literal outside Config/Tokens.qml"),
    ("QS009", "WARN",  "Process / execDetached outside Services/"),
    ("QS010", "WARN",  "Mock referenced outside Services/ and dev/"),
    ("QS011", "WARN",  "hardcoded touch size; use InputMode.touchTarget"),
]

findings = []
def add(code, path, line, msg):
    sev = next(r[1] for r in RULES if r[0] == code)
    findings.append((sev, code, os.path.relpath(path, ROOT), line, msg))

def qml_files():
    for dp, dns, fns in os.walk(ROOT):
        dns[:] = [d for d in dns if d not in SKIP_DIRS and not d.startswith(".")]
        for fn in fns:
            if fn.endswith(".qml"):
                yield os.path.join(dp, fn)

def strip(src):
    """Blank out comments and strings so patterns do not match inside them."""
    src = re.sub(r"//[^\n]*", "", src)
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', src)
    return src

for path in qml_files():
    raw = open(path, encoding="utf-8").read()
    code = strip(raw)
    lines = code.split("\n")
    rawlines = raw.split("\n")

    for i, ln in enumerate(lines, 1):
        # QS001 — the expensive one
        m = re.search(r"\bproperty\s+\w+\s+(on[A-Z]\w*)", ln)
        if m:
            add("QS001", path, i, f"`{m.group(1)}` reads back as a default-constructed value. Rename it.")

        # QS002 — `Foo { ... };`  (property assignments may be ;-separated, objects may not)
        if re.search(r"[A-Z]\w*\s*\{[^{}]*\}\s*;", ln):
            add("QS002", path, i, "remove the `;` after the object, or put children on their own lines")

        # QS007 — colour helper inside a `property color X:` binding
        if re.search(r"property\s+color\s+\w+\s*:", ln) and any(f in ln for f in COLOUR_FNS):
            add("QS007", path, i, "derive a bool/number with a function, then build the colour with Qt.tint/Qt.rgba")

        # QS008 — colour literals outside the token file
        if os.path.basename(path) not in ("Tokens.qml", "Themes.qml"):
            if re.search(r'"#[0-9a-fA-F]{3,8}"', rawlines[i-1]) and "qmldir" not in path:
                add("QS008", path, i, "colours belong in Config/Tokens.qml so every theme works")

        # QS009 — shell-command QML
        if re.search(r"\b(Process|execDetached)\b", ln) and os.sep + "Services" + os.sep not in path:
            add("QS009", path, i, "system access belongs behind a service, not in a UI component")

        # QS010 — service boundary
        if re.search(r"\bMock\.", ln) and (os.sep + "Services" + os.sep) not in path \
           and (os.sep + "dev" + os.sep) not in path and os.path.basename(path) not in ("dev-shell.qml", "slice.qml"):
            add("QS010", path, i, "UI must read a service, never Mock directly")

        # QS011 — device assumptions in generic components
        if re.search(r"\b(width|height|implicitWidth|implicitHeight)\s*:\s*48\b", ln) \
           and (os.sep + "dev" + os.sep) not in path:
            add("QS011", path, i, "use InputMode.touchTarget so the component stays generic")

    # QS004 — entry points must sit at the repo root
    if re.search(r"^\s*ShellRoot\s*\{", code, flags=re.M):
        if os.path.dirname(os.path.abspath(path)) != ROOT:
            add("QS004", path, 1,
                "Quickshell's shell root is the entry file's directory; imports cannot escape it")

    # QS006 — balance
    for o, c in (("{", "}"), ("(", ")"), ("[", "]")):
        d = 0; bad = False
        for ch in code:
            if ch == o: d += 1
            elif ch == c:
                d -= 1
                if d < 0: bad = True; break
        if d or bad:
            add("QS006", path, 1, f"unbalanced {o}{c} (depth {d})")

# QS003 / QS005 — qmldir consistency and global type-name uniqueness
declared = collections.defaultdict(list)   # type name -> [qmldir paths]
for dp, dns, fns in os.walk(ROOT):
    dns[:] = [d for d in dns if d not in SKIP_DIRS and not d.startswith(".")]
    if "qmldir" not in fns:
        continue
    qd = os.path.join(dp, "qmldir")
    body = open(qd, encoding="utf-8").read().splitlines()
    listed = {}
    for i, ln in enumerate(body, 1):
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        if ln.startswith("module "):
            add("QS003", qd, i, "a `module` line breaks directory imports; remove it")
            continue
        parts = ln.split()
        if parts[0] == "singleton":
            parts = parts[1:]
        if len(parts) >= 3:
            listed[parts[0]] = parts[2]
            declared[parts[0]].append(qd)

    on_disk = {f[:-4] for f in fns if f.endswith(".qml")}
    for name, fn in listed.items():
        if not os.path.exists(os.path.join(dp, fn)):
            add("QS003", qd, 1, f"declares {fn}, which does not exist")
    for name in sorted(on_disk - set(listed)):
        add("QS003", qd, 1,
            f"{name}.qml is not listed — a qmldir disables auto-discovery, so it will be "
            f'"not a type"')

for name, where in declared.items():
    if len(where) > 1:
        add("QS005", where[0], 1,
            f"`{name}` also declared in {os.path.relpath(where[1], ROOT)}; "
            "collisions break unrelated types in the same import")
    if name in QTQUICK_BUILTINS:
        add("QS005", where[0], 1, f"`{name}` shadows a QtQuick built-in and will be unreachable")

if "--list" in sys.argv:
    for c, s, d in RULES:
        print(f"  {c}  {s:5s}  {d}")
    sys.exit(0)

errors = [f for f in findings if f[0] == "ERROR"]
warns  = [f for f in findings if f[0] == "WARN"]
for sev, code, path, line, msg in sorted(findings, key=lambda f: (f[0] != "ERROR", f[2], f[3])):
    print(f"{path}:{line}: {sev} {code}: {msg}")
n = len(list(qml_files()))
print(f"\n{n} QML files · {len(errors)} error(s) · {len(warns)} warning(s)")
sys.exit(1 if errors else 0)
