# Settings — implementation spec

Component §1.10 of `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

---

## 1. Four rows, and the restraint is deliberate

The entire settings surface, read from the frame at 10:05:

```
Settings
  Bar height                              30 px
  ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  Font size                               16 px
  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░
  ─────────────────────────────────────────────
  Theme                             gruvbox  →
  Wallpaper                         Choose…  →
```

A shell with eighteen palettes and a hand-drawn icon system exposes **exactly two numbers**.
That is a statement, not an oversight, and it is worth defending.

> **Rule for anything proposed later:** a setting earns a row only if it (a) cannot be derived
> from the active theme, and (b) is something you would plausibly change more than once.
> Everything failing that test is a constant in the source, where it belongs. Left
> undefended, this panel becomes twenty rows and the design loses its nerve.

---

## 2. Why these two sliders matter more here than in the source

On the source's fixed desktop these are close to toys — he demos setting the bar to 51 px for
the camera and puts it back. On the StarLite they are **the calibration mechanism**.

Parent §3.2: the panel is HiDPI with fractional scaling from Plasma's tablet mode, and you
will not know the right bar height or font size until the hardware is in your hands. Being
able to dial both live, on the device, without editing QML and restarting, is how you find
them. Same two controls, different job.

---

## 3. Two touch problems the morph architecture creates

Both are consequences of the island being one surface, and neither exists on the source's
setup. They are the reason this component is not trivial.

### 3.1 You cannot see the thing you are configuring
The bar *is* the settings panel. While settings is open the collapsed pill does not exist to
look at — which is exactly why the source says *"you won't be able to see immediately, but if
I close out, there you go."* On a keyboard-driven desktop, close-and-reopen is cheap. On a
tablet it is a fiddly loop.

> **Fix: a live preview swatch inside the panel.** Render a miniature of the collapsed pill —
> at the chosen bar height and font size, with real clock text — directly in the settings
> surface. Cheap, and it turns a close-reopen-squint loop into direct manipulation.

### 3.2 Changing font size reflows the control under your finger
If font size applies live to *everything*, then dragging the font-size slider resizes the
settings panel containing that slider, and the handle moves out from under the finger
mid-drag.

> **Fix: the settings panel renders at a fixed size, immune to its own font-size setting.**
> Everything else in the shell applies live. The control stays put, and §3.1's preview swatch
> shows the effect. This is the only surface in the shell allowed to opt out of the setting.

---

## 4. Ranges and clamping — the safety net instead of a reset button

| Setting | Min | Default | Max |
|---|---|---|---|
| Bar height | 24 px | 30 px | 64 px |
| Font size | 10 px | 16 px | 28 px |

Confirm these against the real panel and scale factor; the numbers matter less than the fact
that bounds exist.

> **Clamping is why there is no "Reset to defaults" row.** If font size cannot go below 10 px,
> you can never render the UI unreadable, so you never need an escape hatch — and on a tablet
> with no keyboard, a UI you have made unreadable is genuinely unrecoverable. Bounds are a
> better answer than undo, and they cost a row less.

**Bar height must not shrink the touch target.** Parent §3.1.3 requires ≥48 px of input region
for the collapsed pill regardless of its visual height, delivered by the full-top-edge input
strip (parent §3.1.2). So the input region is **independent of this setting** — setting the
bar to 24 px must not produce a 24 px tap target.

---

## 5. Live application

Everything applies **live**, on drag, with no confirm step — except §3.2's exemption.

Font size is the shell's de-facto UI scale: icon sizes derive from it (icons §6, "nothing may
assume 24 px"), so one control scales the interface coherently rather than leaving glyphs
stranded at a fixed size next to grown text. Derive icon size from font size (roughly ×1.5)
rather than exposing a second slider.

Debounce persistence (§7), not rendering — the UI tracks the drag at full rate; the file is
written once the drag settles.

---

## 6. Navigation rows — one state, two entrances

`Theme →` and `Wallpaper →` do not contain settings. They **transition to the theme switcher
(§1.8) and wallpaper picker (§1.9)** — the same states reachable directly via `Alt+T` and
`Alt+Shift+T`.

Implement the transition once and invoke it from both places, exactly as the launcher's mode
chips and typed prefixes converge on one state (launcher §7). Two entrances, one
implementation, no drift.

The `Theme` row displays the **current** scheme name (`gruvbox` in the frame), read from the
active tokens (theming §9) — not from a setting stored here.

Use the sub-view slide with coupled height animation from control-centre §6. Do not rebuild it.

---

## 7. Persistence

Only two values live here. Theme and wallpaper are **not** stored — wallust already persists
the theme by having written its files (theming §9), and storing a second copy invites drift.

- `settings.json` in the Quickshell config directory, holding `barHeight` and `fontSize`
- **Atomic write**: temp file plus rename, so a crash mid-write cannot corrupt it
- Missing, truncated or out-of-range values fall back to the defaults in §4 and are re-clamped
  on load — same fallback discipline as theming §1

---

## 8. Contention

Nothing new. `island.state === "settings"`, surface never unmapped (KWin 503121). Preempts
`rest`; preempted by polkit (polkit §5); notifications suppressed while open (notifications
§1); no OSD while open (osd §3).

Summoned by `Alt+,` → `qs ipc call settings open` (no `GlobalShortcut` on KWin, parent §6.5).
Touch entry point: the **control-centre footer row** (island-core §9.1, control-centre §4.1).
A shortcut-only settings panel would be unreachable folio-detached — which matters more here
than elsewhere, since §2's whole argument is that these sliders are how you calibrate the shell
to the panel while holding it.

---

## 9. Build order

1. Settings state; four static rows; dismiss on Escape / tap outside.
2. Font size slider, live, with the §3.2 fixed-size exemption for this panel.
3. Bar height slider + §3.1 preview swatch.
4. Clamping and persistence (§4, §7).
5. Navigation rows wired to the existing theme/wallpaper states (§6).
6. Touch entry point (§8).

Steps 2–3 are worth doing early in the overall project — as soon as the island renders at all
— because they are how you calibrate the shell to the panel, and every subsequent component
gets designed against the values you land on.

---

## 10. Acceptance criteria

- [ ] Both sliders have ≥48 px input regions and tap-to-set (control-centre §7 component reused)
- [ ] Font size applies live to the island, control centre and icons — but **not** to the settings panel itself
- [ ] Dragging the font-size slider does not move the slider handle under the finger
- [ ] Preview swatch reflects bar height and font size live (§3.1)
- [ ] Setting bar height to its 24 px minimum leaves the collapsed pill's tap target ≥48 px
- [ ] Values outside range are impossible via the UI and are re-clamped on load
- [ ] Settings survive a `qs` restart; a hand-corrupted `settings.json` falls back to defaults without crashing
- [ ] `Theme →` shows the current scheme name and opens the same state as `Alt+T`
- [ ] Icon sizes scale with font size; no glyph is left at a fixed 24 px
- [ ] Reachable folio-detached, without a keyboard (§8)
- [ ] Island never unmaps entering/leaving `"settings"` (503121 regression check)
- [ ] Legible in `e-ink`

## 11. Open questions

1. Are §4's ranges right for this panel? Cannot be answered before the hardware — expect to
   revise once tablet-mode scaling is known.
2. Should font size be literal pixels (source's wording) or a unitless scale factor? Pixels
   match the source and are more legible in the UI; a scale factor composes better with
   Plasma's own fractional scaling. Decide at build step 2.
3. Does bar height need separate portrait and landscape values? Rotation (parent §3.3) changes
   the available height considerably. Probably not; revisit if it grates.
4. ~~Where exactly does the touch entry point live?~~ **ANSWERED —
   `quickshell-island-core.md` §9.1: the control-centre footer row.**

## 12. Dependencies

Slider component (control-centre §7), sub-view slide (control-centre §6), token schema
(theming §2), icon sizing (icons §6). `IpcHandler` confirmed (launcher §14). File persistence
via `FileView` — **unverified**, same open item as launcher §13 q5; a `Process` write is the
fallback.
