# Wallpaper picker — implementation spec

Component §1.9 of `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

UI section grounded in frames extracted at native resolution from 09:26–09:46 specifically
for this spec (the original watch pass stopped reading frames at 04:24).

---

## 1. What the source actually does

From the frame at **09:46**:

```
┌──────────────────────────────────────┐
│ Wallpaper                    gruvbox │   ← collection name, dim, top-right
├──────────────────────────────────────┤
│ [ thumb ] [ thumb ] [ thumb ]        │
│ [ ◉thumb ] [ thumb ] [ thumb ]       │   ← active carries an accent ring
│ [ thumb ] [ thumb ] [ thumb ]        │
│ [ thumb… scrolls                     │
└──────────────────────────────────────┘
```

- Same ~348 px island width as every other state
- **3-column grid** of ~16:9 rounded thumbnails, small gutters, scrolling past three rows
- **Active wallpaper carries an accent ring** — source [09:41]: *"The one that I'm currently
  using carries an accent ring, so I know which one is always active"*
- Header shows the **collection name** — `gruvbox` in the frame. Transcript [09:20]: *"If I
  were to go to gruvbox which has a lot more wallpapers"* — so the library is **foldered per
  theme** and this is a collection selector, not just a label
- Applies instantly on tap; **"the pick persists across restarts"** [09:41]

`Alt+Shift+T` opens it; the settings panel's `Wallpaper → Choose…` row reaches the same state
(settings §6, "one state, two entrances").

---

## 2. Backend — `plasma-apply-wallpaperimage`

On Hyprland this component would need `hyprpaper`, `swww` or `mpvpaper`. On this target it
needs **none of them**.

> Plasma owns the wallpaper. Set it with **`plasma-apply-wallpaperimage <path>`** (ships with
> `plasma-workspace`) via `Process`.

Sixth application of the reuse-what-Plasma-provides principle, and the cleanest one yet:

- **Removes a dependency** from parent §2 rather than adding one — no wallpaper daemon at all
- Plasma's own wallpaper settings stay coherent with what the picker did
- **Persistence is free.** Plasma stores the wallpaper itself, so §1's "persists across
  restarts" needs no state of our own — exactly like the theme (theming §9). The picker reads
  the current wallpaper back from Plasma at startup to draw the accent ring.

Avoid the older `org.kde.PlasmaShell.evaluateScript` route; it is a scripting back door, not
an interface.

---

## 3. Coupling with the theme system — keep the directions separate

Theming §12 q6 asked whether wallpaper should change with theme. Two directions exist and
they must not be conflated:

| Direction | Meaning | Verdict |
|---|---|---|
| **theme → wallpaper** | picking a theme switches to that theme's collection | Yes — switch the *collection*, and optionally its default image |
| **wallpaper → theme** | picking an image regenerates the palette from it (`wallust run <image>`) | **Not by default** |

> **Changing your wallpaper must not silently change your colour scheme.** wallust's original
> purpose is palette-from-image, so this is easy to wire up by accident — and then choosing a
> different picture repaints the entire desktop, which is astonishing in the bad sense.

Expose palette-from-image as a **separate, explicit action** (a long-press on a thumbnail, or
a row in settings): *"derive palette from this wallpaper."* That is also almost certainly what
`material-you` is — the one theme that renders dimmed and inert in the source's theme grid
(theming §7). It is a *generated* scheme with nothing to generate from until this action runs.

**This answers theming §12 q2 and q6.** Record the outcome there once confirmed on hardware.

---

## 4. Library layout

```
~/Pictures/wallpapers/
  ├── gruvbox/
  ├── catppuccin/
  ├── nord/
  └── …
```

One folder per theme, matching the source. The header's collection selector cycles or opens a
list of these. Add an **All** view — with eighteen collections, a flat browse is sometimes what
you want.

Scan lazily and cache the file list; do not re-walk the tree on every open.

> **This needs content, not code.** Eighteen curated collections is an asset-gathering task,
> and it is the kind of work that quietly blocks a "finished" component. Populate two or three
> collections early so the picker is testable, and treat filling out the rest as a separate,
> non-blocking chore.

---

## 5. Thumbnails — the actual engineering problem

A grid of wallpapers means decoding many large images on an Intel N-series tablet. This is the
one place this component can genuinely be slow, and it is worth getting right first time.

- **`Image.sourceSize` is mandatory.** Without it, QML decodes each image at full resolution
  and then scales it down — decoding 4K JPEGs to draw 100 px thumbnails. Set `sourceSize` to
  the thumbnail dimensions and the decoder does the work once, small.
- **`asynchronous: true`** so decoding never blocks the UI thread.
- **`GridView`, not a `Repeater`** — only visible delegates instantiate, so a 200-image
  collection costs the same as a 9-image one. Keep `cacheBuffer` modest on this hardware.
- Show a placeholder tile until each image resolves; do not let the grid reflow as images land.

Measure before adding a disk thumbnail cache. If it *is* needed, the freedesktop thumbnail
cache (`~/.cache/thumbnails/`) is already populated for any folder Dolphin has visited — usable
but not dependable, since it only exists if something else created it. A cache of our own keyed
on path+mtime is the reliable version. **Only build it if the measurement says so.**

---

## 6. Aspect ratio and rotation

Wallpapers are typically 16:9. The StarLite panel is **3:2 and rotates** (parent §3.3), so
every image is cropped, and cropped *differently* in portrait than landscape.

- Thumbnails should preview the crop that will actually be shown rather than letterboxing the
  full image, or the grid misleads
- An image that works in landscape can be badly cropped in portrait; there is no general fix
- Plasma's wallpaper fill mode governs the behaviour — confirm it is set sensibly once, rather
  than trying to manage cropping from the shell

---

## 7. Touch and contention

Thumbnails are naturally far above the 48 px floor, so §3.1.3 needs no special handling here —
the only component where that is true.

- **Tap applies immediately** (source: "instant change"). No preview-then-confirm.
- **Long-press** → the §3 palette-derivation action, matching the control centre's
  tap/long-press idiom (control-centre §5).
- Immediate press feedback (<50 ms) on every tile; a wallpaper change takes a moment to land,
  so the tap must acknowledge instantly or it reads as ignored.

Contention is unchanged: `island.state === "wallpaper"`, surface never unmapped (KWin 503121).
Preempts `rest`, preempted by polkit, notifications suppressed, no OSD while open.

---

## 8. Build order

1. Wallpaper state; grid of placeholder tiles; dismiss paths.
2. Directory scan for one collection; `plasma-apply-wallpaperimage` on tap.
3. Thumbnails done properly (§5) — `sourceSize`, async, `GridView`. **Measure here.**
4. Read the current wallpaper back from Plasma; draw the accent ring.
5. Collection selector in the header (§4).
6. Long-press palette derivation (§3) — after the theme system exists.
7. Crop-accurate thumbnails (§6).

Steps 1–4 are a complete, usable picker.

---

## 9. Acceptance criteria

- [ ] Tapping a thumbnail changes the wallpaper immediately
- [ ] The active wallpaper carries the accent ring, including on first open after a restart
- [ ] Wallpaper survives a `qs` restart and a reboot **with no state stored by the shell** (§2)
- [ ] Changing wallpaper does **not** change the colour scheme (§3)
- [ ] Palette derivation is reachable only through the explicit long-press action
- [ ] A 200-image collection scrolls smoothly and does not balloon memory (§5)
- [ ] No full-resolution decode occurs — `sourceSize` set on every thumbnail
- [ ] Grid does not reflow as images finish loading
- [ ] Wallpaper set from Plasma's own settings is reflected in the ring when the picker opens
- [ ] `Alt+Shift+T` and settings' `Wallpaper →` row reach the same state (settings §6)
- [ ] Island never unmaps entering/leaving `"wallpaper"` (503121 regression check)
- [ ] Legible in `e-ink` — check the accent ring against light thumbnails specifically

## 10. Open questions — answered on hardware 2026-09-03

1. Built as a selector: the header chip cycles collections (`all` first).
2. Single panel; untested with a second screen.
3. **Live.** `plasma-apply-wallpaperimage` swaps the desktop immediately, no reload.
4. **Yes** — the picker also writes kscreenlockerrc `[Greeter][Wallpaper][org.kde.image][General]
   Image=` (plain path) so the lock screen follows.
5. Out of scope, as written.

## 11. Dependencies

- `plasma-apply-wallpaperimage` — ships with `plasma-workspace`. **No wallpaper daemon needed**
  (§2), which removes `swww`/`hyprpaper` from parent §2's dependency list.
- `wallust run <image>` for §3's explicit derivation only.
- Quickshell `Process` and `IpcHandler` (confirmed, launcher §14).
- Token schema (theming §2) for the accent ring.
- A populated wallpaper library (§4) — content, not code.
