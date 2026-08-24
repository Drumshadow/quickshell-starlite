# Island core — implementation spec

Components §1.0, §1.1 and §1.2 of `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

**This is the foundation the other ten specs assume.** Each of them says "island state X",
"the surface never unmaps", "preempts rest" — this file is where those mean something. It was
written last deliberately, so it could be shaped by what all ten consumers actually need.

Where it disagrees with a component spec, **this file wins** and the component spec should be
amended. One such conflict is resolved in §3.

Source [00:40]:
> "The whole thing is built around one idea, a single morphing island that becomes the
> interface for every single component of my desktop."

---

## 1. The state machine

Eleven states, one enum, owned here:

| State | Owner spec | Kind |
|---|---|---|
| `rest` | this file §6 | base |
| `expanded` | this file §7 | user panel |
| `osd` | `quickshell-osd.md` | transient |
| `notification` | `quickshell-notifications.md` | transient |
| `launcher` | `quickshell-launcher.md` | user panel |
| `control` | `quickshell-control-center.md` | user panel |
| `theme` | `quickshell-theming.md` | user panel |
| `wallpaper` | `quickshell-wallpaper.md` | user panel |
| `settings` | `quickshell-settings.md` | user panel |
| `power` | `quickshell-power-menu.md` | user panel |
| `auth` | `quickshell-polkit.md` | blocking |

A component owns its *content*. It does not own when it appears — §3 does.

---

## 2. Surface architecture

**The entire shell is two layer surfaces. Neither is ever unmapped.**

### 2.1 The island surface
```qml
PanelWindow {
    anchors { top: true; left: true; right: true }   // full width, always
    WlrLayershell.namespace: "island"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: 0                                  // floats, reserves nothing
    mask: Region { /* §2.3 */ }
}
```

Anchoring **full width** rather than sizing to the island is deliberate and does three jobs at
once:

1. The surface geometry barely changes, so KWin sees a stable surface (§2.2)
2. It provides the full-top-edge input strip that parent §3.1.2 needs for reachability
3. The island can be re-centred or re-sized freely without renegotiating anchors

The island itself is drawn **centred within** that surface. Surface width is constant; only the
drawn island's width and height change per state.

### 2.2 Never unmap — the rule everything else inherits
KWin bug 503121: unmapping a layer surface and remapping it sends **no configure event**
(parent §6.5). It is confirmed, still open, and a maintainer's comment is "it's not
implemented".

> **Therefore: `visible` is `true` for the life of the session. There is no code path anywhere
> in the shell that sets it false.** State changes alter geometry, content and mask — never
> mapping.

This single rule is why the design's "one element that morphs" conceit and the compositor's
limitation point the same way, and it is repeated in all ten component specs for a reason.

### 2.3 The mask is what makes a full-width surface tolerable
A full-width, tall surface would otherwise swallow every click on the desktop beneath.
`mask` (on the base window type, nestable) restricts the clickable region:

```qml
mask: Region {
    Region { item: islandRect }       // the drawn island, whatever size it is now
    Region { item: topEdgeStrip }     // full width × ~20px, the shade gesture
}
```

Everything outside those passes through. **The mask must be recomputed on every state
change**, or an expanded control centre leaves a 476 px dead zone across the desktop after it
collapses. This is the most likely source of "my desktop stopped responding at the top" bugs.

### 2.4 The second surface
A separate, permanently-mapped, transparent strip anchored **bottom**, full width, ~24 px,
`exclusiveZone: 0`, `keyboardFocus: None` — the launcher's summon gesture (launcher §2). It
never changes and exists only to catch an upward drag.

Two surfaces. That is the whole shell.

---

## 3. Preemption — the canonical matrix

Each component spec states its own rule. Reconciled, they form a **total ordering**, derived
from one principle:

> **A direct response to something the user just did outranks something unsolicited. A
> blocking request outranks everything.**

| Priority | State(s) | Preempts | Preempted by |
|---|---|---|---|
| 3 | `auth` | everything | nothing |
| 2 | user panels — `expanded` `launcher` `control` `theme` `wallpaper` `settings` `power` | everything below | `auth` |
| 1 | `osd` | `notification`, `rest` | panels, `auth` |
| 0 | `notification` | `rest` | everything above |
| — | `rest` | — | everything |

Rules that fall out of it:

- **`auth` preempts and restores.** The preempted state resumes afterwards, including a
  launcher query in progress (polkit §5).
- **User panels are mutually exclusive.** Entering one leaves the other; there is no stack.
- **A transient never interrupts a panel.** Changing volume with the control centre open
  updates the value and draws no OSD — because you are probably dragging that panel's own
  slider (osd §3).
- **Unsolicited never interrupts anything.** A notification arriving during a launcher search
  is logged and badged, never shown (notifications §1).

### 3.1 Conflict resolved: OSD vs. notification
`quickshell-osd.md` §3 says the OSD preempts "only from `rest`", which read strictly means an
active notification toast blocks it. **That is wrong**, and the matrix above corrects it:
pressing volume-up is a direct response to a user action, while the toast is unsolicited, so
the OSD wins and the notification returns to history.

*Amend osd §3 to say "preempts `rest` and `notification`, never a panel."* Recorded here
because reconciling the component specs is this file's job.

---

## 4. Per-state properties

`keyboardFocus` is not constant — it flips with state, which is legal on a mapped surface and
requires no remap (launcher §1):

| State | `keyboardFocus` | Auto-dismiss |
|---|---|---|
| `rest` | `None` | — |
| `expanded` | `None` | on tap-outside |
| `osd` | `None` | ~2.5 s after last change |
| `notification` | `None` | ~6 s, or pinned |
| `launcher` | **`Exclusive`** | — |
| `auth` | **`Exclusive`** | ~90 s timeout |
| `control` `theme` `wallpaper` `settings` `power` | `None` | — |

Only two states take the keyboard, and both take it exclusively because both accept a
password or a search query that must not leak to the window behind.

---

## 5. The morph

"Morph" is a precise thing, not a hand-wave:

1. **Geometry** — the drawn island's width and height animate on the §1.15 critically damped
   spring. No bounce, no overshoot.
2. **Content** — outgoing content cross-fades out, incoming fades in, on a shorter curve than
   the geometry so the box is settling as the content arrives.
3. **Mask** — recomputed to the new geometry (§2.3), snapped not animated.

Both animations run from **one driver**, so geometry and content never desync. This is the
same coupling requirement the control centre's sub-view slide has (control-centre §6), and it
is the single most visible thing to get wrong.

**Never** cross-fade two whole island copies over each other — it doubles overdraw and reads
as a dissolve rather than a morph.

---

## 6. `rest` — the collapsed pill

From the frames at 00:00–00:50: black pill, full radius, ~90 × 22 at a 30 px bar height, one
soft shadow, containing **the time in tabular figures and nothing else**.

> **Corrected 2026-08-23.** An earlier draft said the pill carried a signal-strength glyph.
> Frames at 00:44 / 00:47 / 00:50 show that glyph at different bar heights in each — it is
> animating, so it is the **EQ bars**, not a signal meter. [00:40] agrees: *"At rest, the island
> is just this collapsed pill… the clock."* **There is no status information at rest.** See
> `~/specs/quickshell-status-capsule.md` §0–§1, which also asks whether the tablet should break
> from this for battery.

- Time from a clock ticking **on the minute boundary**, not every 60 s from start — otherwise
  it drifts and updates at the wrong moment
- Tabular figures so the pill does not jitter
- Height derives from the bar-height setting (settings §4), but the **input region stays ≥48 px
  regardless** (settings §4, parent §3.1.3)

### The EQ bars, and the only idle animation in the shell
Source [00:40]: small accent EQ bars animate beside the time while music plays, and disappear
on pause.

> **This is the only thing in the shell that animates continuously at rest**, which makes it
> the only idle battery cost (parent §3.5). Gate it strictly on MPRIS reporting *playing* —
> not on a player merely existing — and stop the animation, not just hide it, on pause.

---

## 7. `expanded` — three zones

From the frame at 02:05, ~350 × 55:

| Zone | Content |
|---|---|
| Left | album art thumbnail, signal glyph, track title, artist |
| Centre | large clock, date beneath |
| Right | status capsule — Wi-Fi + battery (`~/specs/quickshell-status-capsule.md`) |

Entered by tap on the pill, or by the shade drag (§8). Icons from the shared library
(icons §3); battery and Wi-Fi are two of the four stateful ones.

**Carries a grabber** — a small chevron that opens `control` on tap (§9.1 mechanism 3). It is
what makes the shell reachable without knowing the drag gesture, so it is not optional
decoration.

**Portrait does not fit.** Three horizontal zones on a portrait 3:2 panel need an explicit
variant — stack the zones, or drop media to a second row (parent §3.1.7). Design it alongside
this state, not after.

### What is deliberately dropped
The source's click-empty-space-to-pin versus click-a-button behaviour (parent §3.1.5). It
needs a hover state to distinguish resting from pressing, which touch does not have. A
shade-expanded island simply stays open until dismissed.

---

## 8. The shade gesture

Parent §3.1.1's reframe: on a tablet this is a notification shade, and it should be
**drag-linked**, not a toggle.

- Drag down from the top-edge strip (§2.3) — anywhere along the full width
- Past threshold 1 → `expanded`; keep pulling past threshold 2 → `control`
- Release below a threshold settles open; above it snaps back
- **Follows the finger the whole way** and is reversible mid-drag — that is what makes it
  better than hover, and a toggle animation would throw it away
- Minimum drag distance so a resting palm never summons it (parent §3.1.6)

Dismiss: swipe up, tap outside, or Escape.

---

## 9. IPC — one target, canonical

Component specs variously wrote `qs ipc call launcher toggle`, `qs ipc call island control`,
`qs ipc call theme open`. **Superseded — one target:**

```qml
IpcHandler {
    target: "island"
    function open(state: string): void
    function toggle(state: string): void
    function close(): void
}
```

KDE global shortcuts (parent §6.5 — `GlobalShortcut` is Hyprland-only) then bind:

| Shortcut | Command |
|---|---|
| `Alt+D` | `qs ipc call island toggle launcher` |
| `Alt+A` | `qs ipc call island toggle control` |
| `Alt+T` | `qs ipc call island toggle theme` |
| `Alt+Shift+T` | `qs ipc call island toggle wallpaper` |
| `Alt+,` | `qs ipc call island toggle settings` |
| `Ctrl+Alt+Del` | `qs ipc call island toggle power` |
| `Ctrl+Alt+L` | `loginctl lock-session` (not the island) |

`toggle` on the current state closes it. An unknown state name is a no-op, not a crash.

### 9.1 Touch entry points — DECIDED 2026-08-23

**Every shortcut above is unreachable folio-detached.** `launcher` and `control` have touch
gestures; `theme`, `wallpaper`, `settings` and `power` had none. This was drifting as three
separate open questions (power-menu §9 q3, settings §11 q4, and §13 q5 here). Settled once:

> **Principle: the entire shell must be operable by tapping alone. Gestures are the fast path,
> never the only path. A gesture nobody has taught you is not an entry point.**

Three mechanisms, in order of how a person actually reaches for them:

#### 1. Power → the hardware power button
Bind `XF86PowerOff` as a KDE custom shortcut to `qs ipc call island toggle power`, and set
Plasma's own button action (System Settings → Power Management → Button events) to **Do
nothing**, so it does not consume the key first.

This is what every phone and tablet has trained the user to expect, and it costs no screen
space. **The safety floor is unchanged:** a long press is a firmware-level hard power off
regardless of what the shell is doing, so a dead `qs` cannot strand the machine.

*Assumes the tablet body exposes a power button — near-universal, but confirm on arrival. If
it does not, mechanism 2 already covers it.*

#### 2. Theme / Wallpaper / Settings / Power → a footer row in the control centre
**Not more tiles in the toggle grid.** Toggles and navigation behave differently, so they must
look different; a tile that toggles and a tile that navigates are indistinguishable in a shared
grid, and the control centre already carries a tap-vs-long-press distinction
(control-centre §5) that does not need further overloading.

A **footer strip of four icon-only buttons** across the bottom of the control centre. At
~348 px inner width that is ~87 px each — comfortably past the 48 px floor. It is the Android
quick-settings and GNOME idiom, so it arrives already learned.

Power appears here *as well as* on the hardware button. Redundancy is correct for the one
entry point whose absence strands you.

#### 3. A grabber on the expanded island → the all-tap chain
The shade drag reaches `control`, but **a drag is not discoverable**. Add a small chevron or
grabber to the expanded island that opens `control` on tap.

That completes a chain requiring no gesture knowledge at any step:

```
visible pill → tap → expanded → tap grabber → control → footer → theme / wallpaper / settings / power
```

The pill is on screen permanently, so the chain has a visible starting point. This is what
makes the principle above true rather than aspirational.

### 9.2 Resulting reachability

| State | Touch path | Keyboard |
|---|---|---|
| `rest` | always present | — |
| `expanded` | tap pill · shade drag ① | — |
| `control` | shade drag ② · grabber tap | `Alt+A` |
| `launcher` | swipe up from bottom edge | `Alt+D` |
| `theme` | control → footer · settings row | `Alt+T` |
| `wallpaper` | control → footer · settings row | `Alt+Shift+T` |
| `settings` | control → footer | `Alt+,` |
| `power` | **hardware power button** · control → footer | `Ctrl+Alt+Del` |
| `osd` `notification` `auth` | automatic — never summoned | — |

**Unchanged by this decision:** every keyboard shortcut stays exactly as in §9, and settings
keeps its own `Theme →` / `Wallpaper →` rows (settings §6) — one state, two entrances, as
everywhere else.

### 9.3 Amendments this requires

- `quickshell-control-center.md` — add the footer row (§3 layout, §4 grid); it is **not** part
  of the tile grid. Closes its §13 open items about entry points.
- `quickshell-power-menu.md` §9 q3 — **answered**: hardware power button, plus the footer.
- `quickshell-settings.md` §11 q4 — **answered**: control-centre footer.
- This file §7 — the `expanded` state gains the grabber affordance.

---

## 10. Startup, restore and failure

- On start: `rest`, immediately. Never flash a panel.
- Read theme tokens before first paint, or the island appears unstyled for a frame
  (theming §1's fallback palette covers the unreadable-file case)
- If `qs` dies, the surface goes with it — Plasma keeps running, so the desktop stays usable.
  This is a real advantage of the §6.6 keep-plasmashell decision.
- Nothing persists across restart except what the OS already stores: theme via wallust,
  wallpaper via Plasma, two numbers in `settings.json`

---

## 11. Build order

**This component is first. Nothing else can start.**

1. Surface (§2.1), full width, `rest` state with a hardcoded pill. Verify it renders.
2. **Mask (§2.3)** — verify the desktop beneath is clickable everywhere except the pill. Doing
   this now means never debugging a dead zone later.
3. State machine + morph (§1, §5) with two dummy states. Verify no unmap on transition.
4. Preemption matrix (§3) with dummy states — including `auth` preempt-and-restore.
5. Token binding (theming §2) so everything drawn is themed from the start.
6. `rest` content: clock, signal glyph, EQ bars gated on playback (§6).
7. IPC handler (§9) + KDE shortcut bindings.
8. Shade gesture (§8).
9. `expanded` (§7), including the portrait variant.

Steps 1–4 are the architecture. Get them right and every component afterwards is content;
get them wrong and every component inherits the problem.

---

## 12. Acceptance criteria

- [ ] `visible` is never set false anywhere in the codebase — `grep` proves it
- [ ] Rapid cycling through all eleven states 100× shows no missing configure events, no lost surface (503121)
- [ ] Desktop beneath is clickable everywhere except the island and the top strip, **in every state** (§2.3)
- [ ] Collapsing the control centre leaves no dead zone
- [ ] Shade drag follows the finger and is reversible mid-drag
- [ ] `auth` preempts a launcher with a half-typed query, and the query is intact afterwards
- [ ] Volume change with control centre open produces no OSD; with a notification showing, it does (§3.1)
- [ ] A notification during a launcher search is logged, not shown
- [ ] `keyboardFocus` is `Exclusive` only in `launcher` and `auth`
- [ ] Clock updates on the minute boundary; EQ bars animate only while MPRIS reports playing, and stop on pause
- [ ] Every island state reachable with no keyboard (§9.2) — walk the full all-tap chain with the folio physically detached
- [ ] Hardware power button opens the island power menu, and Plasma's own button action does not also fire
- [ ] Long-pressing the hardware power button still hard-powers-off with `qs` killed
- [ ] Island renders themed on first paint — no unstyled frame
- [ ] Killing `qs` leaves a usable Plasma desktop
- [ ] Geometry and content never visibly desync during a morph
- [ ] `e-ink` legible in every state

## 13. Open questions

1. Should the island surface's *height* be constant (tallest state) with the mask doing all the
   work, or animate with the drawn island? Constant is simpler and safer for 503121; animating
   is tidier. **Test both at step 3** — this is the one architectural choice left open.
2. Threshold distances for the two-stage shade drag — needs the real panel.
3. Does KWin's own top-edge behaviour conflict with the shade strip? (parent §3.1.8 item 4)
4. Portrait `expanded` layout — stack, or drop media to row two? (§7)
5. ~~Where do the four unreachable states get touch entry points?~~ **ANSWERED — §9.1.**

## 14. APIs confirmed 2026-08-23

`PanelWindow` — `anchors`, `exclusiveZone`, `exclusionMode`, `margins`, `focusable`,
`aboveWindows`. `mask: Region` on the base window type; `Region` takes `item`, nests, and
supports `intersection` (Xor inverts). `WlrLayershell` — `layer`, `namespace`, `keyboardFocus`
(`WlrKeyboardFocus.None|OnDemand|Exclusive`). `IpcHandler` — `target` + typed functions,
driven by `qs ipc call`. All present in v0.2.0.
