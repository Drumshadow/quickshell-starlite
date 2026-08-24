# Icon system — implementation spec

Component §1.3 of `~/specs/quickshell-starlite-rice.md`. A shared component library, not a
screen — every other spec consumes it.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Quickshell/QML.

This is the design's signature. It is also, per parent §5 q2, the single largest cost in the
project. §1 exists to make it much smaller without losing the signature.

The source is emphatic and repeats it twice — [01:45] and [12:40]:

> "Every single glyph here is hand-drawn. There's no icon font. No nerd font… They're vector
> shapes that I drew, which means that they tint to whatever accent color is active and stay
> perfectly crisp at any size."

---

## 1. The v1 decision — answers parent §5 q2

**Split the set by whether an icon encodes a *value*.**

| | Count | Approach |
|---|---|---|
| **Stateful** — geometry driven by a live value | 4 | Hand-authored `ShapePath` |
| **Static** — a fixed symbol | ~15 | SVG path data from a licensed set, fed into `PathSvg` |

The four stateful icons **cannot** come from an icon font or a static SVG, because their
whole point is that they encode a continuous quantity. They are also precisely the ones the
video shows off. Those get hand-authored.

The other fifteen — lock, power, reboot, log-out, chevrons, ✕, media transport — gain nothing
from being hand-drawn. Nobody can tell a hand-drawn padlock from a Lucide padlock.

> **`PathSvg` is what makes this a synthesis rather than a compromise.** `QtQuick.Shapes`
> accepts an SVG path string directly inside a `ShapePath`. So imported glyphs are still real
> `Shape`s — same tinting, same animation, same crispness, same renderer as the hand-drawn
> ones. You are importing *geometry*, not a font and not a raster.
>
> The design's stated identity holds literally: there is no icon font anywhere.

**Net effect: author 4 icons instead of 19, keep the entire visual signature, and cut the
largest single cost in the project by roughly three-quarters.**

**Source set: Lucide (ISC) — decided 2026-08-23.** Chosen over Phosphor for three reasons:
ISC is the simplest permissive licence of the two; its stroke language is **2 px on a 24×24
grid**, which is the most common convention and the one the scaffold is written against; and
its coverage of the §3 inventory is complete. Ship the ISC notice alongside the config.

**Nominal grid: 24×24 — decided.** It matches Lucide natively, so imported paths need no
rescaling, and physical size is handled separately by `Tokens.iconSize` deriving from the
font-size setting (§6).

---

## 2. Technology

`import QtQuick.Shapes` — `Shape` + `ShapePath`, with `PathLine`, `PathArc`, `PathCubic`,
`PathSvg`. Set `preferredRendererType: Shape.CurveRenderer` (Qt 6.6+) for clean antialiasing
without multisampling.

Why not the alternatives:

| Approach | Why not |
|---|---|
| Icon font (`Text` + glyph) | Cannot encode a value; hinting fights fractional scaling; the thing the design rejects |
| `Canvas` | Imperative, CPU-repainted, no property animation or binding |
| `Image` + SVG file | Rasterised at a fixed size; per-property tinting and animation unavailable |
| **`Shape` + `ShapePath`** | **Bindable, animatable, resolution-independent, GPU-rendered** |

Bindability is the whole argument: `strokeColor`, `fillColor`, `strokeWidth` and path
geometry are all QML properties, so an icon is a function of `(value, theme)` rather than an
asset that has to be regenerated.

---

## 3. Inventory

| Icon | Kind | Consumed by |
|---|---|---|
| **Volume** — mute / 1 wave / 2 waves | stateful | OSD §6, control-centre §7 |
| **Brightness** — sun, rays scale with level | stateful | OSD §6, control-centre §7 |
| **Wi-Fi** — signal meter, fills by strength | stateful | island status, control-centre tile |
| **Battery** — % inside the cell, charging bolt | stateful | island status pill |
| Bluetooth (on/off/connected) | near-static | control-centre tile |
| Night light (moon) | binary | control-centre tile |
| Peace / DND | binary | control-centre tile, island |
| Lock, Suspend, Log Out, Reboot, Power Off | static | power menu §1.11 |
| Padlock | static | polkit card §1.13 |
| Search (magnifier) | static | launcher §6 |
| Play / Pause / Prev / Next | static | media card, island |
| Back chevron, ✕ | static | everywhere |
| Speaker (small, output label) | static | control-centre media card |

Plus the **themed letter avatar** — not an icon but the shared fallback when an app has no
resolvable icon. Owned by notifications §7, consumed by the launcher §6. Listed here so it is
not built a third time.

---

## 4. The four stateful icons

### Volume
| State | Geometry |
|---|---|
| muted | speaker + ✕ (bar also dims — OSD §6) |
| 0 < v ≤ ~50% | speaker + **one** wave |
| v > ~50% | speaker + **two** waves |

Mute is a **separate input from volume 0**; never infer one from the other. Waves
cross-fade rather than pop.

### Brightness
A sun whose rays lengthen and brighten **continuously** with level — not stepped. Draw a
fixed set of 8 rays and animate their `scale` and `opacity` from the value (§8); do not
regenerate path geometry per frame.

### Wi-Fi
Concentric arcs acting as a signal meter. Draw all arcs once; drive each arc's colour and
opacity from the strength bucket. Needs an explicit **disconnected** state distinct from
"connected, 0 bars".

### Battery — the interesting one
Rounded-rect cell + terminal nub, accent fill proportional to charge, **percentage rendered
inside the cell**, charging bolt with a green tint when plugged in.

> **The legibility problem:** at 80% the number sits over the fill; at 20% it sits over the
> empty background. A single text colour is wrong in one of those cases.
>
> **Solution — draw the number twice.** Once in the on-empty colour, and again in the on-fill
> colour with that copy clipped to the fill rectangle. As the fill sweeps across, each digit
> flips colour exactly at the boundary. This is how the iOS look is achieved and it is a few
> lines of QML, not a shader.

States: normal · charging (bolt + green) · low · critical. Note the source's device sits at
an 80% charge cap [12:44] — do not treat 80% as "full" in the fill maths.

---

## 5. Consistency rules

What makes a set look designed rather than assembled:

- **One stroke width** — e.g. 1.5 or 2 logical px on a 24×24 nominal grid
- **One cap and join style** — round or butt, chosen once
- **One viewbox and optical padding** — 24×24 with consistent ~2 px inset
- **One weight language** — do not mix filled and stroked glyphs in the same row
- Optical, not mathematical, centring — a triangle centred by bounding box looks off-centre

> **Ordering matters: pick the SVG set *first*, then match the four hand-drawn icons to its
> stroke weight and cap style.** Doing it the other way round means redrawing four icons to
> match fifteen, instead of matching four to fifteen.

---

## 6. Theming

Every colour is a token from the active scheme (parent §1.8) — **no literals anywhere**. An
icon is a function of `(value, theme)`.

Each icon component takes: `value` and/or `state`, `size`, and colour tokens. It knows
nothing about the island, the OSD, or which panel is showing it.

Size scales with the §1.10 font-size setting, so nothing may assume 24 px.

Check contrast in the **`e-ink` light scheme** specifically — accent-on-light is where a
stroke weight tuned on a dark background usually disappears.

---

## 7. Crispness at fractional scale

"Stay perfectly crisp at any size" is harder on this hardware than on the source's desktop:
the StarLite is HiDPI and Plasma's tablet mode applies **fractional** scaling, so strokes can
land on half-pixels and blur.

- Prefer even stroke widths at the nominal size
- Keep the nominal grid and inset consistent so scaling is uniform
- `Shape.CurveRenderer` handles antialiasing better than the legacy geometry renderer
- KWin's pixel-grid alignment work helps, but do not rely on it — **check on the real panel at
  the real scale factor**, which is exactly what the gallery (§9) is for

---

## 8. Performance

`Shape` re-tesselates when **path geometry** changes. On an Intel N-series part that matters
(parent §3.5).

> **Rule: animate transforms and colour, not path data.**
> Rays, arcs and waves should be fixed geometry whose `scale`, `opacity` and colour animate.
> Regenerating a `ShapePath` every frame during a volume drag is the expensive way to do a
> cheap thing.

Battery and Wi-Fi update on service events, not on a timer. Nothing here should run an
animation while idle.

---

## 9. The gallery — build this second

A standalone Quickshell config that renders **every icon, at every state, at three sizes, in
every theme**, on one scrollable surface.

It costs an hour and pays for itself immediately:
- The only practical way to check §5 consistency — inconsistencies are invisible one icon at a
  time and obvious in a grid
- The §7 crispness check at the real scale factor on the real panel
- The `e-ink` contrast check (§6)
- A regression check when the theme system changes

Run it as a `FloatingWindow` so it does not fight the island for layer space.

---

## 10. Build order

1. Pick the SVG source set; record the licence (§1).
2. **Gallery harness** (§9) with two or three imported static icons. Everything after this is
   verified visually as it lands.
3. Static set via `PathSvg` — lock, power group, chevrons, ✕, media transport, search.
4. **Volume** and **Brightness** (stateful) → hand to OSD §6, which is the first component
   being built.
5. **Battery**, including the two-copy clipped number (§4).
6. **Wi-Fi** signal meter.
7. Bluetooth / night light / peace binaries.
8. Contrast and crispness pass across all themes in the gallery.

Steps 1–4 unblock the OSD, which is the recommended first component of the whole shell.

---

## 11. Acceptance criteria

- [ ] No icon font is imported anywhere in the shell; no `Text`-with-glyph icons
- [ ] Every icon is a `Shape`; imported geometry arrives via `PathSvg`, not `Image`
- [ ] Every colour resolves from a theme token — `grep` finds no colour literals in the icon library
- [ ] Switching theme retints every icon with no reload
- [ ] Battery number stays legible at 10%, 50% and 90% — digits flip colour at the fill boundary
- [ ] Battery charging shows the bolt and green tint; 80% cap is not treated as full
- [ ] Volume icon distinguishes muted from volume-0
- [ ] Brightness rays vary **continuously**, not in visible steps
- [ ] Wi-Fi has a disconnected state distinct from 0 bars
- [ ] Icons crisp at the tablet's real fractional scale factor, verified in the gallery on the panel
- [ ] All icons legible in `e-ink` light scheme
- [ ] No path geometry is regenerated per frame during a volume or brightness drag (§8)
- [ ] Source set licence recorded here, and its notice included if required

## 12. Open questions

1. ~~Lucide or Phosphor?~~ **DECIDED — Lucide (ISC), 2 px on 24×24. See §1.**
2. Does the chosen licence require an attribution notice shipped with the config? ISC and MIT
   generally do — record where it lives.
3. ~~Nominal grid?~~ **DECIDED — 24×24, matching Lucide. See §1.**
4. Is `Shape.CurveRenderer` available and default-able in the packaged Qt version?
5. Are any stateful icons wanted that the source does not have — mic mute, an airplane-mode
   state, storage? Only add on demand.
6. Should the themed letter avatar (notifications §7) live in this library instead? Probably
   yes on the second consumer; leave it where it is until then.

## 13. APIs

`QtQuick.Shapes` — `Shape`, `ShapePath`, `PathLine`, `PathArc`, `PathCubic`, `PathSvg`,
`Shape.CurveRenderer`. Standard Qt 6, not Quickshell-specific, so no Quickshell version
dependency here (unlike polkit §1.1).

Verify on hardware: `PathSvg` availability in the packaged Qt, and `CurveRenderer` support
(§12 q4).
