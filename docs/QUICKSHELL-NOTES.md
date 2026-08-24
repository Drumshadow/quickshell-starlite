# Quickshell/QML incompatibilities found by actually running the code

Everything here was discovered on **Quickshell 0.2.1** (`0.2.1^git20260209`, Fedora 44,
Qt 6.11.1) in the headless container. Recorded because most of it is invisible until runtime
and several cost real time.

## Environment corrections to the specs

| Spec said | Reality |
|---|---|
| Install Quickshell from the `errornointernet` COPR | **It is in Fedora proper** (`updates`). No COPR needed. The COPR exists and covers f44 if a newer build is ever wanted |
| Polkit needs Quickshell ≥ 0.3.0 | Fedora 44 ships **0.2.1**, so `Quickshell.Services.Polkit` is **unavailable on the target today**. `docs/quickshell-polkit.md` §1.1 gate: **fails** |

## 1. `qmldir` is authoritative — all or nothing

Adding a `qmldir` to a directory **disables filename auto-discovery**. Only what it lists
exists. Half-listing (singletons only) silently breaks every other type with a misleading
`X is not a type`.

Also: a `module Foo` line turns the directory into a *named module* requiring `import Foo` with
an import path, which is incompatible with directory imports (`import "Icons"`).

**Rule:** for directory imports, no `module` line, and list **every** type.

## 2. The shell root is the entry file's directory

`qs -p dev/shell.qml` makes `dev/` the shell root. Imports **cannot escape it** — `root:/Config`
resolved to `/shell/dev/Config`, and `../Config` failed with
`Ignoring unresolvable import`.

**Rule:** entry points live at the **top of the tree**. `shell.qml`, `dev-shell.qml` and
`gallery.qml` are all at the repo root; everything else is imported downward.

This is why the original `gallery/shell.qml` and `dev/shell.qml` were moved.

## 3. A property named `on` + Uppercase is silently broken

**The most expensive finding here.** QML parses `onFoo` as a signal handler, so:

```qml
readonly property color onSurface: isDark ? inkLight : inkDark   // reads back as #000000
```

`isDark` was correct, `inkLight` was correct, and `onSurface` was black. No warning, no error.
`surfaceVariant` right beside it worked perfectly.

Material Design's token vocabulary (`onSurface`, `onPrimary`, `onAccent`) walks straight into
this. Also caught `onAC` in the power service.

**Renamed:** `onSurface→ink`, `onSurfaceDim→inkDim`, `onAccent→inkOnAccent`,
`onCritical→inkOnCritical`, `onAC→acConnected`.

**Rule:** never begin a property name with `on` followed by a capital. Grep for it:
```bash
grep -rnE "property [a-z]+ on[A-Z]" --include=*.qml .
```

## 4. Custom JS functions returning a *colour* are unreliable in bindings

```qml
function inkOn(bg) { ... return light-or-dark ... }
readonly property color onSurface: inkOn(surface)     // -> #000000
```
…while `Tokens.inkOn(Tokens.surface)` called imperatively returned `#f5f2f0` correctly.

Functions returning **numbers or bools** are fine (`lum()`, `isDark`). Only colour-returning
ones misbehaved, and NaN comparisons inside them fall silently to the wrong branch.

**Rule:** derive **booleans/numbers** with functions; build colours from **Qt built-ins**
(`Qt.tint`, `Qt.rgba`) inline in the binding. Note `Qt.lighter()` is useless on near-black —
`Qt.tint(c, Qt.rgba(1,1,1,a))` is the reliable lighten.

## 5. An array-of-objects binding did not re-evaluate

```qml
readonly property var audit: [ { pair: "...", ratio: contrast(a, b) } ]
```
reported stale ratios. Split into individual `readonly property real` values, which bind
correctly.

## 6. No `;` after an inline nested object

```qml
Column { spacing: 4; Volume { muted: true }; Text { ... } }   // Unexpected token ';'
```
Property assignments may be `;`-separated; object declarations may not.

## 7. Name collisions across imported directories are fatal, not scoped

`Icons/Brightness.qml` and `Services/Brightness.qml` both existing broke resolution of
**unrelated** types in the same import, and a qualified import (`as Sys`) only masked it at
some directory depths.

**Renamed** the service to `Backlight.qml` — which is more accurate anyway.

Also: **`Rotation` collides with QtQuick's built-in `Rotation` transform**, so that singleton
was never reachable. Renamed to `Orientation.qml`.

## 8. `console.log` does not reach stdout

It goes to Quickshell's own log store (`qs log <file>`), which made an early debugging attempt
useless. Rendering values into an on-screen `Text` and screenshotting proved far more effective
for diagnosing binding problems.

## 9. Things that worked exactly as documented

- `PanelWindow`, `FloatingWindow`, `ShellRoot`
- `WlrLayershell.layer` / `.namespace` / `.keyboardFocus`, `mask: Region`
- `QtQuick.Shapes` incl. `PathSvg`, `PathAngleArc`, `Shape.CurveRenderer`
- `Quickshell.env()` — used for the mock preset
- Singletons via `pragma Singleton` + `qmldir`

## 10. Container gotcha (not Quickshell)

Fedora ships `sway` with `cap_sys_nice=ep`. Docker strips file capabilities and the kernel then
refuses to exec the binary at all (`Operation not permitted`). `cp` does not preserve caps, so
the Dockerfile copies sway to a capability-free path — avoiding `--privileged`.
