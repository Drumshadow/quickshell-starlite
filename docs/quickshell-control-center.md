# Control centre — implementation spec

Component §1.7 of `~/specs/quickshell-starlite-rice.md`. Self-contained: buildable without
touching the launcher, OSDs or lock screen.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

The largest single component in the design — five toggle tiles with sub-views, two sliders,
a media card and the notification history. Build it last of the interactive surfaces; it
reuses pieces from every other component.

---

## 0. Gate — the D-Bus ownership probe

The launcher was gated on the OSK. **This one is gated on notification-server ownership**,
and the risk is comparable.

> **The gate and the service are owned by `~/specs/quickshell-notifications.md`** — that spec
> builds the `NotificationServer`; this one renders a second view onto its model. Run the
> probe once, there. The summary below is kept so this spec reads standalone.

Only one process may own `org.freedesktop.Notifications` on the session bus. **plasmashell
already owns it.** §10 of this spec (notification history) and parent §1.5 (toast popups)
both need Quickshell's `NotificationServer` to own it instead. Whether plasmashell will
release it is **unknown and must be tested before building §10**:

```bash
busctl --user list | grep -i notif          # who owns it now, and its PID
# then, with a minimal Quickshell NotificationServer running:
busctl --user list | grep -i notif          # did the owner change?
notify-send "probe" "who displays this?"    # Plasma's toast, or yours?
```

Three outcomes:

| Result | Verdict | Action |
|---|---|---|
| Quickshell takes the name, `notify-send` renders in your shell | **Green** | Build §10 as specced. |
| Plasma keeps it; Quickshell errors or sits idle | **Amber** | Find a supported way to stop Plasma's notification service *without* stopping plasmashell. If none exists, take Amber-fallback below. |
| Name is taken but nothing renders anywhere | **Red — worst case** | You have silently broken all system notifications. Revert immediately. |

> **Amber fallback:** drop §10 entirely. Let Plasma own notifications and render its own
> toasts; the control centre ships without the notification list and Peace mode becomes a
> passthrough to Plasma's Do Not Disturb. This costs a real chunk of the design, but it is
> survivable and it keeps the system honest. Decide this **before** building §10, not after.

**Rollback:** whatever you disable to free the name, write down how to re-enable it before
you disable it. A tablet with no notifications and no memory of why is a bad afternoon.

---

## 1. Architecture: another island state

Same rule as the launcher (`~/specs/quickshell-launcher.md` §1) and for the same two
reasons — the design conceit and KWin bug 503121. **One `PanelWindow`, mapped for the whole
session.** The control centre is `island.state === "control"`.

Entry paths:
- **Drag-linked (parent §3.1.1):** continue the top-edge shade pull past the expanded-island
  threshold and it becomes the control centre. This is the primary touch path and the reason
  the shade metaphor was chosen.
- `Alt+A` → `qs ipc call island control` (folio attached; no `GlobalShortcut` on KWin).

`keyboardFocus` stays `None` — the control centre is pointer/touch driven and needs no text
entry. That also avoids the Exclusive-grab question entirely here.

---

## 2. Service backing — what is native and what is not

The decisive research result for this component:

| Tile / element | Backend | Native? |
|---|---|---|
| Audio tile, volume slider, audio sub-view | `Quickshell.Services.Pipewire` — `nodes`, `defaultAudioSink`, `defaultAudioSource`, `ready` | ✅ native |
| Bluetooth tile + sub-view | `Quickshell.Bluetooth` (BlueZ) — top-level module, not under `Services` | ✅ native |
| Media card | `Quickshell.Services.Mpris` | ✅ native |
| Notification list | `Quickshell.Services.Notifications` → `NotificationServer` | ✅ native (but see §0) |
| Battery in the status pill | `Quickshell.Services.UPower` | ✅ native |
| **Wi-Fi tile + sub-view** | `Quickshell.Networking` | ✅ native *(corrected 2026-08-24 — an earlier draft said no module existed)* |
| **Brightness slider** | Not UPower; no native module | ❌ D-Bus |
| **Night Light tile** | KWin's own (replaces hyprsunset, parent §6.7) | ❌ D-Bus |

### The three non-native ones — reuse Plasma, don't add daemons

This is the same principle that chose Klipper over `cliphist` in the launcher spec, and it
applies three more times here:

- **Brightness → `org.kde.Solid.PowerManagement`** over D-Bus, not `brightnessctl`. Plasma's
  own brightness service keeps Plasma's state in sync, so its OSD, its power profile and
  your slider never disagree.
- **Night Light → `org.kde.KWin.NightLight`** over D-Bus. Already installed, already
  scheduled, already colour-managed.
- **Wi-Fi → NetworkManager.** No Quickshell module, so either D-Bus to
  `org.freedesktop.NetworkManager` or `nmcli` via `Process`. **Prefer D-Bus**: `nmcli`
  polling for signal strength on a battery-powered tablet is a process spawn per refresh.
  Use `nmcli` only for the initial spike, then port.

Confirm every interface name on hardware with `qdbus`/`busctl` before writing against it.

---

## 3. Surface and layout

Panel ~348 wide (source proportion), top-centre, top-anchored, `exclusiveZone: 0`.
Vertical order, matching the source exactly:

```
┌──────────────────────────────┐
│ ←  Control Center            │  header, 48
├──────────────────────────────┤
│ [Wi-Fi     ] [Audio        ] │  tile grid, 3 cols with span
│ [Bluetooth] [Peace] [Night ] │
├──────────────────────────────┤
│ 🔊 ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░ │  volume slider
│ ☀  ▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░ │  brightness slider
├──────────────────────────────┤
│ [ media card, blurred art  ] │
├──────────────────────────────┤
│ Notifications      Clear all │
│ [ notification            ✕] │
│ [ notification            ✕] │
├──────────────────────────────┤
│  ⬤  ⬤  ⬤  ⬤                 │  tray row (optional — see below)
├──────────────────────────────┤
│  🎨      🖼️       ⚙️       ⏻  │  footer, 56 — navigation, NOT toggles
└──────────────────────────────┘
```

The **tray row** is specced separately in `~/specs/quickshell-system-tray.md`. It is not part of
the source design — it exists because removing Plasma's panel removes the system tray. Collapses
to nothing when empty, so it costs nothing until it is built.

**The footer row (§4.1) is how the shell is reachable without a keyboard** — decided in
`quickshell-island-core.md` §9.1. It is not optional.

Height must respect `Qt.inputMethod.keyboardRectangle` the same way the launcher does — the
OSK should never be up here, but Peace/other flows might raise it, so bind rather than
assume. Scroll the notification list, never the whole panel.

---

## 4. Tile grid

**A 3-column grid where tiles declare a span.** Reading the source frames back: Wi-Fi spans
1, Audio spans 2, and Bluetooth/Peace/Night Light span 1 each — 324 px inner width ÷ 3
columns + 8 px gutters matches the observed geometry. Model it that way rather than
hardcoding two bespoke rows; it makes adding a sixth tile trivial.

### 4.1 The footer row — navigation, deliberately not tiles

Four icon-only buttons across the bottom: **Theme · Wallpaper · Settings · Power**. They
transition to those island states (island-core §9.1 mechanism 2).

> **They are not part of the tile grid, and that is the point.** Toggles and navigation behave
> differently, so they must look different. A tile that toggles and a tile that navigates are
> indistinguishable in a shared grid, and this panel already carries a tap-vs-long-press
> distinction (§5) that must not be overloaded further.

Icon-only, in a visually separated strip — the Android quick-settings and GNOME idiom, so it
arrives already learned. At ~324 px inner width, four buttons are ~81 px each, well past the
48 px floor. Single tap, no long-press, no arm-to-confirm (the power *menu* does its own
confirming — power-menu §2).

### 4.2 Tile grid

Tile: **56 px tall** (source ~38; raised to clear the 48 px touch floor per parent §3.1.3),
circular ~26 px icon badge, bold label, dim value line beneath (`"Atlantis 5G"`, `"Off"`,
`"On"`).

| State | Fill | Text | Badge |
|---|---|---|---|
| active | accent | dark-on-accent | inset, dark |
| inactive | dark surface | light | accent circle |

---

## 5. Tile interaction — the split target, redesigned

The source splits the tile: tapping the icon badge toggles, tapping the rest opens the
sub-view. On touch that is a ~26 px target inside a 110 px tile — a mis-tap generator
(parent §3.1.4). Replace with:

- **Tap anywhere on the tile → toggle.**
- **Long-press → sub-view.** The Android quick-settings idiom, already learned.
- **Plus a chevron** at the tile's trailing edge, itself a ≥48 px target, that also opens the
  sub-view — a precise path for people who do not guess long-press, and the discoverability
  affordance that long-press alone lacks.

Long-press needs a visible progress cue (a ring or fill sweep) so it never feels like a
dropped tap. Press feedback is immediate, <50 ms, not a spring (parent §3.1.6).

Tiles with no meaningful sub-view (Peace) get no chevron and no long-press.

---

## 6. Sub-views and the slide

Sub-views **push in horizontally while the panel height animates to the new content** — the
source's "the island resizes as it transitions". Those two animations must be driven from
one source of truth or they visibly desync.

Hand-roll it rather than using `StackView`: a container with two slots and an animated
x-offset, with `panelHeight` bound to the incoming view's `implicitHeight`. Both on the §1.15
critically-damped spring. `StackView` makes the coupled height animation awkward — that
coupling is the whole effect.

Header becomes `← <Tile name>`, back arrow ≥48 px, plus swipe-right-to-go-back.

| Sub-view | Contents |
|---|---|
| **Bluetooth** | Header toggle switch; device rows with an accent `Connect`/`Disconnect` action. Source shows paired-device rows only — **pairing is unimplemented in the source too** and is genuinely more work; descope for v1. |
| **Audio** | Output and input device lists with per-device volume sliders. Pipewire `nodes` filtered by direction. |
| **Wi-Fi** | Network list, signal strength, connect. Needs a password field → **raises the OSK → depends on the OSK probe** exactly like the launcher. Build after the launcher proves the pattern. |

---

## 7. Sliders

Source: full-width rounded pills, ~22 px tall, accent fill, icon badge inset at the left end,
"thick, rounded, very satisfying to drag".

- Keep the 22 px visual. Give a **48 px input region** (parent §3.1.3).
- **Add tap-to-set** anywhere on the track — drag alone is fussy on touch.
- Volume: Pipewire `defaultAudioSink`. Brightness: `org.kde.Solid.PowerManagement`.
- Debounce writes (~50 ms) so a drag does not spam D-Bus.
- The icon is stateful, per parent §1.3: speaker gains a second wave at high volume and
  becomes speaker-with-X at mute; the sun's rays lengthen with level. Shared with the OSD
  component (§1.4) — **one icon component, two consumers.** Do not draw them twice.

---

## 8. Media card

`Quickshell.Services.Mpris`. Blurred album art as background with a dark scrim, output-device
label with speaker glyph, title, artist, circular light play/pause on the right, prev/next,
thin progress bar.

> **Blur, Qt 6:** use `MultiEffect` from `QtQuick.Effects` (`blurEnabled: true`).
> `QtGraphicalEffects` is gone in Qt 6, and `Qt5Compat.GraphicalEffects` is a packaging trap —
> Quickshell users hit "module Qt5Compat.GraphicalEffects is not installed" precisely here.
> This is the **only** blur in the shell; every other surface is flat (parent §1.15).

Blur is a per-frame GPU cost on an Intel N-series part. Render it once to a cached layer on
art change, not continuously — parent §3.5.

---

## 9. Notification list

**Gated on §0.** One `NotificationServer` feeds both this history list and the §1.5 toasts —
one service, two views. **The service is built in `~/specs/quickshell-notifications.md`;
this section consumes its model and adds no D-Bus code of its own.**

Row: circular app-icon badge, dim app name, bold summary, dim origin line, body text, ✕ with a
48 px input region. `Clear all` in the header row.

Touch interactions per parent §3.1.4: tap = pin/expand body, swipe up = dismiss. Critical
notifications keep the red accent.

**Peace mode** suppresses toasts but still appends to this list. If §0 lands Amber, Peace
becomes a proxy for Plasma's Do Not Disturb instead.

---

## 10. Theming

No hardcoded colours — everything resolves from the active scheme (parent §1.8) so all 18
palettes and light `e-ink` work with no control-centre-specific changes. Verify the
active/inactive tile contrast in `e-ink` specifically: accent-fill-with-dark-text is the
pattern most likely to break in a light scheme.

---

## 11. Build order

1. Island enters/exits `"control"` state; panel height animates. Static placeholder content.
1b. **Footer row (§4.1)** wired to the four states. Do this early — until it exists, half the
   shell is unreachable folio-detached and cannot be tested on the actual target.
2. Tile grid with span layout; tap-to-toggle only, wired to **Pipewire and Bluetooth first** (both native, no D-Bus guesswork).
3. Long-press + chevron + press feedback (§5).
4. Sub-view push with coupled height animation (§6) — Bluetooth first.
5. Sliders (§7), sharing the stateful icon component with the OSDs.
6. Brightness and Night Light via D-Bus; Wi-Fi tile read-only (status display, no connect).
7. Media card (§8).
8. **Run the §0 probe.** Then notifications, or take the Amber fallback.
9. Wi-Fi sub-view with connect (needs the OSK pattern proven by the launcher).
10. Audio sub-view.

Steps 1–5 are a genuinely useful control centre. Stop and use it before continuing.

---

## 12. Acceptance criteria

- [ ] Island never unmaps entering or leaving `"control"` (503121 regression check)
- [ ] Drag-linked entry from the shade gesture is continuous and reversible mid-drag
- [ ] Every tile, chevron, slider and ✕ has ≥48 px effective target and immediate press feedback
- [ ] Long-press shows progress and never reads as a dropped tap
- [ ] Sub-view slide and panel resize stay visually locked together
- [ ] Toggles reflect external change — flip Bluetooth in Plasma's own applet, tile updates
- [ ] Brightness slider and Plasma's brightness OSD never disagree
- [ ] Media card survives the player closing and reopening
- [ ] Blur uses `MultiEffect`, is cached per art change, and no `Qt5Compat` import exists
- [ ] `e-ink` light scheme legible in both tile states
- [ ] Footer row reaches theme, wallpaper, settings and power; visually distinct from toggle tiles at a glance
- [ ] §0 outcome recorded in this file with the date

## 13. Open questions

1. **Can plasmashell release `org.freedesktop.Notifications` without being killed?** (§0 — the gate.)
2. Plasma also draws its own **volume/brightness OSDs**, which will double up with parent §1.4. Can they be disabled independently of plasmashell? Same class of problem as §0, lower stakes — visual duplication, not lost function.
3. `Quickshell.Services.Polkit` appears in newer docs than `Quickshell.Bluetooth` — confirm both exist in the packaged version (`qs --version`) before relying on them. Relevant to parent §1.13.
4. Pairing in the Bluetooth sub-view — descoped for v1; revisit if the tablet gains peripherals.
5. Does `Quickshell.Bluetooth` expose enough to replace the Plasma applet, or is it status-only?

## 14. APIs confirmed 2026-08-23

Modules present in v0.2.0: `Quickshell`, `Quickshell.Bluetooth`, `Quickshell.DBusMenu`,
`Quickshell.Io`, `Quickshell.Wayland`, `Quickshell.Widgets`, `Quickshell.Services.{Greetd,
Mpris, Notifications, Pam, Pipewire, SystemTray, UPower}`. `Quickshell.Services.Polkit`
listed in newer docs.
Pipewire exposes `nodes`, `links`, `linkGroups`, `defaultAudioSink`, `defaultAudioSource`,
`ready`. `NotificationServer` implements the freedesktop Desktop Notifications spec.

**No NetworkManager module and no brightness module exist** — §2 covers both.
