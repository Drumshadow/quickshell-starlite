# Quickshell StarLite rice — implementation

Scaffold for the shell specced in `~/specs/quickshell-*.md`.
**Start at `~/specs/quickshell-build-order.md`.**

> **This now runs.** The gallery and the mocked dev shell render under real Quickshell
> **0.2.1** (Fedora 44, Qt 6.11.1) in a headless container — see `docs/RUNNING.md`.
> Every QML/API incompatibility found while getting there is recorded in
> `docs/QUICKSHELL-NOTES.md`.
>
> Still unrun against **real hardware**: every `Services/*.qml` real backend is a stub. Mock
> mode is what works today.

## Quick start

```bash
docker build -t quickshell-starlite-dev -f tools/dev/Dockerfile tools/dev
tools/dev/run-mock.sh                    # mocked shell + interactive control panel
tools/dev/run-headless.sh gallery.qml    # icons + live contrast audit
QS_PRESET=tablet tools/dev/run-mock.sh   # tablet posture
```

## What is here

| Path | Spec | State |
|---|---|---|
| `Config/Tokens.qml` | theming §2–§3 | **The contract.** Semantic tokens + luminance-aware derivation. Settle before anything else |
| `Config/Settings.qml` | settings §4, §7 | Two clamped numbers. Persistence is a TODO (`FileView` unverified) |
| `Island/IslandState.qml` | island-core §1, §3 | State machine + the canonical preemption matrix |
| `Island/Island.qml` | island-core §2 | The surface, the mask, the morph. `visible` is never false |
| `Island/RestContent.qml` | island-core §6 | Clock + EQ bars. **No status glyph** (corrected 2026-08-23) |
| `Island/ExpandedContent.qml` | island-core §7 | Three zones + status capsule + grabber |
| `Icons/` | icons §4 | The four stateful glyphs, hand-authored; `Glyph`+`Paths` for the static set |
| `gallery.qml` | icons §9, theming §8 | **Runs.** Contrast audit + every icon, state and size |
| `Services/*.qml` | service layer | **The system boundary.** UI reads these; they read real backends or `Mock` |
| `dev-shell.qml`, `dev/MockPanel.qml` | — | **Runs.** Mocked shell with interactive controls |
| `tools/dev/` | — | Fedora 44 container + headless compositor + screenshot harness |

## Not yet written
Everything from build-order Phase 4 on: launcher, control centre, notifications, OSD
component, media service, tray, power menu, wallpaper, theme switcher, polkit, lock screen.
Each has a spec with its own build order.

## Architecture

```
UI components  ──reads──>  Services/*.qml  ──>  real backend  (D-Bus / native Quickshell)
                                          └──>  Services/Mock.qml   (when Env.mock)
```

UI never queries the system, never runs a command, and never learns whether it is talking to
hardware or a simulation. `Services/InputMode.qml` derives touch-target size, density, OSK need
and gesture policy from form-factor inputs, so **generic components carry no device
assumptions** — they read `InputMode.touchTarget`, not `48`.

## First moves on hardware
1. `~/specs/day-one-check.sh` — read-only verification, **§2.1 first**
2. `qs -p ~/quickshell-starlite/gallery/shell.qml` — does the icon library render, and is it crisp at the real scale?
3. `qs -p ~/quickshell-starlite/shell.qml` — does the island appear, and **is the desktop beneath still clickable everywhere except the pill?** (island-core §2.3 — verify the mask before adding content)

## Known placeholders
- `Icons/Paths.qml` — 24×24 path data is **placeholder**. Replace with Lucide (ISC) or
  Phosphor (MIT) and record the licence (icons §1, §12 q2)
- `Config/Tokens.qml` raw inputs are hardcoded; wallust replaces them (theming §1)
- `Island/Island.qml` loader only handles `rest` and `expanded`
