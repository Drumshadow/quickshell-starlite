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
tools/lint.py                            # static checks, no container needed
docker build -t quickshell-starlite-dev -f tools/dev/Dockerfile tools/dev
tools/dev/run-mock.sh                    # mocked shell + interactive control panel
tools/dev/run-headless.sh gallery.qml    # icons + live contrast audit
QS_PRESET=tablet tools/dev/run-mock.sh   # tablet posture
```

## What is here

| Path | State |
|---|---|
| `Services/*.qml` | **The system boundary.** 14 services; real backends for audio, power, media, network, apps, tray — all degrading honestly when a daemon is absent |
| `Services/InputMode.qml` | Derives touch target, density, OSK need, gesture policy from form factor. Generic components read this, never a device assumption |
| `Config/Tokens.qml` | Semantic tokens + luminance-aware derivation. `Themes.qml` holds six palettes; adding one is four colours |
| `Island/` | One never-unmapped layer surface morphing between rest, expanded, osd, launcher, control, theme, wallpaper, settings, power |
| `Components/` | Tile, SliderRow — shared, form-factor aware |
| `gallery.qml` | Every icon, state and size + live contrast audit |
| `dev-shell.qml`, `slice.qml`, `dev/` | Mock harness: interactive panel and CLI control |
| `tools/lint.py` | 11 static checks, each from a bug that actually bit |
| `tools/dev/` | Fedora 44 container, headless compositor, screenshot + 21-assertion slice test |

## Not built yet
Notifications (gated on whether plasmashell releases the bus name — untestable
off-hardware), lock screen (highest consequence; needs a tested second way in),
polkit (unblocked but last by choice). Launcher is minimal — no diffed-ListModel
reflow, mode chips or frecency yet.

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
