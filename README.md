# Quickshell StarLite rice — implementation

Scaffold for the shell specced in `~/specs/quickshell-*.md`.
**Start at `~/specs/quickshell-build-order.md`.**

> **None of this has ever been run.** It was written without the target hardware and
> without a Qt toolchain on the authoring machine, so it is checked for structure and
> brace balance only. Expect to fix API details against the installed Quickshell version
> (`qs --version`). The *architecture* is the valuable part; syntax is cheap to repair.

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
| `gallery/shell.qml` | icons §9, theming §8 | Build this second — contrast audit + every icon, state and size |

## Not yet written
Everything from build-order Phase 4 on: launcher, control centre, notifications, OSD
component, media service, tray, power menu, wallpaper, theme switcher, polkit, lock screen.
Each has a spec with its own build order.

## First moves on hardware
1. `~/specs/day-one-check.sh` — read-only verification, **§2.1 first**
2. `qs -p ~/quickshell-starlite/gallery/shell.qml` — does the icon library render, and is it crisp at the real scale?
3. `qs -p ~/quickshell-starlite/shell.qml` — does the island appear, and **is the desktop beneath still clickable everywhere except the pill?** (island-core §2.3 — verify the mask before adding content)

## Known placeholders
- `Icons/Paths.qml` — 24×24 path data is **placeholder**. Replace with Lucide (ISC) or
  Phosphor (MIT) and record the licence (icons §1, §12 q2)
- `Config/Tokens.qml` raw inputs are hardcoded; wallust replaces them (theming §1)
- `Island/Island.qml` loader only handles `rest` and `expanded`
