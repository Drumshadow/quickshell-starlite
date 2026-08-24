# Quickshell "morphing island" rice — StarLite (Fedora KDE)

**Status:** spec only. Nothing here has been executed or verified — the target hardware
is not in hand. Written 2026-08-23.

**Target:** Star Labs StarLite tablet, **Fedora 44 KDE**, arriving ~w/c 2026-08-30.
Fedora 44 shipped Plasma 6.6 and tracks 6.7.x via updates, which clears the 6.6 threshold
in §6.2 — confirm the running version on arrival.
**Source:** "The Prettiest Quickshell Setup You've Ever Seen" — saneAspect (Zane),
`youtube.com/watch?v=wcm95W876OU`, 15:21. Watched in full 2026-08-23; 123 deduped frames
plus 29 native-resolution frames and a full caption transcript were used to build §1.

---

## 0. The finding that shapes this spec

**There is no config to clone.** The video description carries only two Gumroad links to
a paid course. No dotfiles repo appears in the description, on the channel, or in any of
four sibling videos checked. At **[14:08]** the author says it explicitly:

> "You can build this yourself. *Not by cloning my repo* and then just going and copy and
> pasting stuff. No, that almost never works."

The config is the product being sold ("Hypraccelerator Max", $197 pre-sale → $397). So
this is **not a port**. It is *build this design from scratch*, using the video as a
reference spec. §1 exists to make that possible — it is the design brief, reconstructed
from frames and narration, because there is nothing else to work from.

Corollary: budget this as original QML work, not as a dotfiles drop-in. The install
(§2) is an afternoon. §1 is weeks.

---

## 1. Component inventory (reconstructed from the video)

### 1.0 The core idea
> **Implementation spec: `~/specs/quickshell-island-core.md`** — the foundation all ten other
> component specs assume. Owns the state machine, the preemption matrix and the surface. **Build
> this first.**
One element — a rounded pill anchored top-centre, floating just below the screen edge —
**morphs in place** into every surface on the desktop. It is not a bar plus separate
popup windows; it is a single component that resizes and re-lays-out. Everything is QML
on Quickshell, no C++. All animation is **critically damped springs** — fast, arrives,
stops, no overshoot — deliberately matched to the Hyprland animation config.

### 1.1 Collapsed pill (rest state) — [00:00]
Small black pill, full radius, ~90×22 px at a 30 px bar height, one soft shadow. Contains
**the time only** (`23:45`) in tabular figures. When music plays, small accent-coloured EQ bars
animate beside the time; they disappear on pause.

> **Corrected 2026-08-23.** This previously read "a signal-strength glyph and the time". Frames
> at 00:44 / 00:47 / 00:50 show that glyph at a different height in each — it is animating, so it
> is the EQ bars, not a signal meter. [00:40] agrees: *"At rest, the island is just this
> collapsed pill… the clock."* **There is no status information at rest.** See
> `~/specs/quickshell-status-capsule.md` §0–§1, which asks whether the tablet should break from
> this for battery.

### 1.2 Expanded island (hover) — [01:10], [02:05]
Springs open to ~350×55 px, three zones:
- **Left:** album-art thumbnail, **EQ bars**, track title (`IRIS OUT`) + artist (`Kenshi Yonezu`) — `~/specs/quickshell-media.md`
- **Centre:** large clock `23:47` with date beneath (`Sun, Jun 7`)
- **Right:** status capsule — Wi-Fi glyph + battery with the number *inside* the cell (`80`), iOS-style, accent fill for charge level — `~/specs/quickshell-status-capsule.md`

Click empty space → pins open. Click again → collapses. Click an actual button → performs
that action *without* toggling the pin. Two distinct click behaviours by hit region.

### 1.3 Hand-drawn icon system — [01:45]–[02:20], [12:40]
> **Implementation spec: `~/specs/quickshell-icons.md`** — a shared library every other
> component consumes. Its §1 **answers parent §5 q2**.
**No icon font anywhere. No Nerd Fonts.** Every glyph is a QML vector shape, which is why
they tint to the live accent and stay crisp at any size. They are *stateful*, not static:
- Wi-Fi glyph doubles as a signal meter (fills by strength)
- Battery shows percentage inside the cell; charging adds a bolt and a green tint
- Volume icon shows one wave at low level, two at high, and a speaker-with-X when muted
- Brightness sun's rays lengthen as the level rises

This is the single most distinctive and most labour-intensive part of the design.

### 1.4 OSDs — [02:50] volume, [03:12] brightness
> **Implementation spec: `~/specs/quickshell-osd.md`** — owns the stateful volume/brightness
> icons. Recommended **first** component to build.
Island morphs to a compact meter: icon badge, accent fill bar, percentage right-aligned.
Fill animates between values. Auto-dismisses back to the clock after ~1.5 s, no interaction.

### 1.5 Notifications — [03:31]–[04:16]
> **Implementation spec: `~/specs/quickshell-notifications.md`** — owns the notification
> *service* that the control centre's history list also consumes, and owns the D-Bus gate.
Island morphs to show the notification: app icon (or a themed letter avatar derived from
the app name), summary, body. Hover pauses the auto-dismiss countdown; leaving resumes it;
click dismisses early. Critical notifications get a red accent and a longer timeout.
**Peace mode** (DND) suppresses pop-ups entirely but still logs to the notification centre.

### 1.6 App launcher — `Alt+D` — [04:24]–[05:20]
> **Implementation spec: `~/specs/quickshell-launcher.md`.** Gated on the OSK probe.
Island becomes a search field with a results list. Cursor hidden, fully keyboard-driven,
focus locked on open. Results **reflow** rather than snap: new matches fade in, non-matches
fade out, survivors slide to new positions. Selected row carries a left accent bar and a
lighter row fill; each row is icon + bold name + dim description. The panel height shrinks
to fit the result count. Modes:
- `=` prefix → **calculator**, live results, Enter copies to clipboard
- `:` prefix → **clipboard manager** over clipboard history, Enter pastes
- Escape morphs back to the island

### 1.7 Control centre — `Alt+A` — [06:19]–[08:00]
> **Implementation spec: `~/specs/quickshell-control-center.md`.** Gated on the
> notification-server D-Bus ownership probe in its §0.
Panel ~348×476, header `← Control Center`. Contents top to bottom:
- **Toggle tiles**, variable width, two rows: (Wi-Fi, Audio) then (Bluetooth, Peace, Night Light). Each shows label + current value ("Atlantis 5G", "Off", "On"). Active = accent fill with dark text; inactive = dark tile with an accent circular icon badge.
- **Split tap targets:** tapping the icon badge toggles; tapping the rest of the tile opens that sub-view. Two actions per tile.
- **Sub-views push in with a slide** and the island resizes to fit. Bluetooth sub-view = header with a switch, then device rows with an accent `Connect` action. Audio sub-view = output/input device switching with per-device volume sliders.
- **Sliders:** full-width rounded pills, thick, accent fill, icon badge inside the left end.
- **Media card:** blurred album art as background, output-device label with speaker glyph, title, artist, circular white play/pause, prev/next, progress bar.
- **Notification history** with a `Clear all` accent action.

Night Light drives **hyprsunset**.

### 1.8 Theme switcher — `Alt+T` — [08:00]–[09:15]
> **Implementation spec: `~/specs/quickshell-theming.md`** — defines the token schema every
> other component is written against. Settle §2 before building the second component.
Island becomes a 3-column swatch grid, scrollable, **18 curated palettes**. Each swatch
previews its own background and accent; the active one carries an accent ring. Confirmed
names from the frames:

`anime` · `ariadne` · `catppuccin` · `e-ink` · `everforest` · `gruvbox` ·
`gruvbox-material` · `horizon` · `industrial` · `kanagawa` · `material-you` · `nightfox` ·
`noir` · `nord` · `rose-pine` · `rxyhn` · `tokyo-night` · `vira-palenight`

Selecting one restyles **the entire system live** — shell *and* applications — via
**wallust**. Verified on camera against htop and a file manager. Includes light schemes
(`e-ink`) and the flat design holds up in light mode because nothing is hard-coded: every
fill, shadow and icon tint derives from the active scheme.

### 1.9 Wallpaper picker — `Alt+Shift+T` — [09:20]–[09:50]
> **Implementation spec: `~/specs/quickshell-wallpaper.md`** — needs no wallpaper daemon on
> Plasma, and its §3 answers theming §12 q2 and q6.
Grid of wallpapers, instant switch, active one carries an accent ring, selection persists
across restarts.

### 1.10 Settings — `Alt+,` — [10:00]–[10:40]
> **Implementation spec: `~/specs/quickshell-settings.md`.** Its two sliders are the
> calibration mechanism for this panel — build them early.
Deliberately tiny panel: `Bar height` slider (px, live), `Font size` slider (px, live),
`Theme →` row showing current scheme, `Wallpaper → Choose…` row. That is the whole
settings surface.

### 1.11 Power menu — `Ctrl+Alt+Delete` — [10:50]–[11:12]
> **Implementation spec: `~/specs/quickshell-power-menu.md`.** The only component with no
> OSK dependency — but see its §9 q3: shortcut-only means unreachable folio-detached.
Island becomes a row of 5 tiles: Lock, Suspend, Log Out, Reboot, Power Off — icon above
label. **Destructive actions arm to confirm:** first press turns the tile red and shows
"Confirm", second press fires. Safe actions (Lock, Suspend) fire immediately.

### 1.12 Lock screen — `Ctrl+Alt+L` — [11:14]–[11:40]
> **Implementation spec: `~/specs/quickshell-lock-greeter.md`** — the only component that can
> fail *hard*: a `qs` crash while locked leaves the device inoperable until a TTY. Its §2 also
> covers the greeter: **do not replace SDDM.**
Currently **unstyled by the author's own admission** — large clock, date, plain password
field on a flat dark ground. Treat as a blank slate, not a reference.

### 1.13 Polkit authentication — [11:45]–[12:20]
> **Implementation spec: `~/specs/quickshell-polkit.md`.** Needs Quickshell ≥0.3.0 — a
> hard dependency no other component has. Recommended to build **last**.
The stand-out integration. When anything requests elevated privileges the island becomes
an auth card showing the **real** requested action (`Authentication is needed to run
'/usr/bin/pacman -Syu' as the super user`) and the **action ID**
(`org.freedesktop.policykit.exec`) in small dim text — this is anti-spoofing, and it
matters. Masked password field, `Cancel` + accent `Authenticate`. The password goes only
to the system auth daemon. Escape or click-away cancels; **fail closed**.

### 1.14 Multi-monitor
The island lives on every screen; morphs, OSDs and notifications appear on the focused
monitor. **Not relevant to a single-panel tablet** — descope it.

### 1.15 Design language summary
Flat. No gradients, no glass, no blur on the shell surfaces themselves (blur appears only
inside the media card's album-art background). Deep near-black panels with generous corner
radius, one soft drop shadow, a single accent per theme used for fills/active states, dim
secondary text, tabular figures for clock and percentages. Whitespace-heavy. Restraint is
the aesthetic.

---

## 2. Install path — Fedora KDE

Far easier than on a Debian/Ubuntu base, which is why the target matters.

1. **Hyprland** — in Fedora's own repos (`dnf install hyprland`). Use the
   `solopasha/hyprland` COPR if a newer build or the wider ecosystem (hypridle, hyprlock,
   hyprpaper, **hyprsunset** — needed for §1.7) is wanted.
2. **Quickshell** — not in Fedora proper; use the `errornointernet/quickshell` COPR. This
   avoids a from-source Qt build entirely.
3. **wallust** — required for §1.8 system-wide theming. Cargo or COPR; confirm on arrival.
3a. **Check the COPR's Quickshell version.** `Quickshell.Services.Polkit` (§1.13) needs
   **≥0.3.0**; everything else works on 0.2.x.
3b. **No NetworkManager or brightness module exists in Quickshell** — Wi-Fi and brightness
   go over D-Bus to NetworkManager and `org.kde.Solid.PowerManagement`. See the control
   centre spec §2.
4. **Non-destructive by construction.** Hyprland installs as an *additional* SDDM session
   entry. Plasma stays intact and remains the fallback. On a brand-new tablet that is the
   entire safety story — never leave it with no known-good session.

> Verify each package name against the live repos when the tablet arrives rather than
> trusting this list; COPR ownership changes.

---

## 3. Tablet adaptations — the part that is actually hard

The source design assumes a mouse, a keyboard, and a large landscape display. The StarLite
is none of those by default. Each item below is a genuine redesign, not a config tweak.

### 3.1 Touch has no hover — the touch redesign

The source design's core interaction is *hover to expand*. There is no hover on a
touchscreen, and with the folio detached there is no cursor and no keyboard either. This
section is the replacement interaction model. It is design work to be settled **before**
stage 5, because it changes component structure, not just sizes.

#### 3.1.1 Principle: on a tablet, the island is a shade

The reframe that makes this easy: **a pill at the top edge that expands downward into
controls and notifications is a notification shade.** Every tablet user on earth already
knows swipe-down-from-top. The source reaches that shape by accident, via hover; we should
reach it deliberately, via the gesture people already have.

This is not a compromise. Swipe-to-expand is *better* on touch than hover-to-expand is on
a mouse: it is continuous, interruptible, and reversible mid-gesture. Design toward it
rather than emulating hover.

Consequence: the island's expansion should be **drag-linked**, not a binary toggle. Pull
down a little → the expanded island (§1.2). Keep pulling → the control centre (§1.7).
Release below a threshold → settle open; above → snap back. One gesture replaces both
hover and `Alt+A`.

#### 3.1.2 Reachability — the top-centre problem

On a ~12.5" tablet held in two hands, **top-centre is the single hardest point to reach**.
The entire source design lives there. Do not solve this by moving the island to the bottom
— that discards the design's identity. Solve it by separating input from visuals:

> **Make the summon input region the full width of the top edge (100% × ~20 px, zero
> exclusive zone) while the visual pill stays top-centre.**

You then swipe from whichever top corner your hand is already near, and the island still
renders where the design wants it. This trick — a large invisible input region around a
small visual — recurs throughout §3.1.3 and is the single highest-leverage adaptation in
this document.

#### 3.1.3 Hit targets: decouple input region from visual size

Minimum comfortable touch target is ~9 mm — call it **48 px** at scale 1; treat that as a
floor after Plasma's tablet-mode scaling, not before. The source is drawn for a mouse and
much of it is under half that. Do **not** fix this by inflating the visuals — that would
destroy the restraint that makes the design good. Inflate the *input regions* instead.

| Element | Source visual | Keep visual | Required input region |
|---|---|---|---|
| Collapsed pill (§1.1) | ~90×22 | yes | full top edge × 48 |
| Island buttons (§1.2) | ~24 icons | yes | 48×48 |
| CC toggle tile (§1.7) | ~110×36 | yes | ≥110×48, 8 px gutters |
| CC slider (§1.7) | ~22 tall | yes | 48 tall, full width |
| Launcher row (§1.6) | ~30 tall | **no — raise to 56** | 56, full width |
| Notification close ✕ (§1.5) | ~16 | yes | 48×48 |
| Power tile (§1.11) | ~56×56 | yes | 64×64 |

The launcher row is the one place to change the visual, not just the input region: rows
that tall need the extra height to look deliberate rather than cramped, and it is a list
you scroll and tap rather than scan with a cursor.

#### 3.1.4 Per-behaviour replacements

Every hover-dependent or keyboard-dependent behaviour in §1, with its touch replacement:

| § | Source behaviour | Touch replacement |
|---|---|---|
| 1.2 | Hover expands the island | Swipe down from top edge (drag-linked); tap pill also expands |
| 1.2 | Click empty space pins open / click again collapses | **Dropped.** A swipe-expanded island simply stays open until dismissed |
| 1.2 | Click button acts without toggling pin | **Dropped** with the above — see §3.1.5 |
| — | Collapse | Tap outside, swipe up on the island, or Escape (folio attached) |
| 1.4 | OSD auto-dismiss ~1.5 s | Keep, but raise to ~2.5 s — no hover means no way to hold it open |
| 1.5 | Hover pauses dismiss countdown | Tap once = pin + expand body; tap again = activate; swipe up = dismiss |
| 1.5 | Click dismisses early | Swipe up (tap is reassigned to pin/expand) |
| 1.7 | Icon badge toggles, rest of tile opens subview | **Tap = toggle, long-press = subview.** Add a chevron affordance that is also directly tappable, giving a precise path and a forgiving one |
| 1.7 | Slider drag | Keep drag; **add tap-to-set** anywhere on the track |
| 1.6 | `Alt+D`, cursor hidden, fully keyboard-driven | Swipe up from bottom edge to summon; auto-raise the OSK and focus the field |
| 1.6 | Arrow keys + Enter to pick | Tap a row. Keep keys for when the folio is attached |
| 1.6 | `=` prefix → calculator, `:` prefix → clipboard | Prefixes require the OSK symbol layer. Add **tappable mode chips** (Apps / Calc / Clipboard) across the top of the launcher |
| 1.11 | Destructive tiles arm-to-confirm | Keep unchanged — this is *more* valuable on touch, where mis-taps are common |
| 1.13 | Polkit password field | Must auto-raise the OSK (see §3.1.8) |

#### 3.1.5 What is deliberately lost

State these as decisions, not oversights:

- **§1.2's two-different-click-behaviours detail.** Genuinely clever with a mouse;
  unreproducible without a hover state to distinguish "resting on" from "pressing". Do not
  try to emulate it with tap-vs-long-press on the island itself — that collides with the
  §1.7 long-press idiom and would make the two panels behave inconsistently.
- **Hover highlight as pre-touch feedback.** A mouse tells you what you are about to hit
  *before* you commit. Touch cannot. Compensated for in §3.1.6.
- **Cursor-hidden keyboard purity in the launcher.** It stays available with the folio on,
  but it can no longer be the primary path.

#### 3.1.6 Feedback model — press states become load-bearing

With no hover there is no pre-touch affordance, so **post-touch feedback has to carry the
whole burden** and must be immediate. Distinguish two animation classes and do not conflate
them:

- **State transitions** (morphs, expansions, subview pushes) — critically damped springs,
  exactly as §1.15. Unchanged.
- **Press acknowledgement** — **not** a spring. Target under ~50 ms: an instant fill or
  scale-down on touch-down, released on touch-up. A press that animates in feels laggy no
  matter how well tuned the spring is.

Every interactive element needs a visible pressed state. The source largely does not have
one, because it never needed one. Assume no haptics on this hardware unless proven
otherwise.

Also add a **minimum swipe distance** on both edge gestures so resting a palm near an edge
does not summon the shell mid-app.

#### 3.1.7 Portrait

Ties into §3.3. The control centre is already a narrow vertical panel and survives
rotation as-is. **The expanded island does not** — three horizontal zones (media / clock /
status) will not fit a portrait 3:2 panel. Needs an explicit portrait variant: stack the
zones, or drop the media zone to a second row and keep clock + status on the first. Design
this at the same time as §1.2, not after.

#### 3.1.8 Unknowns to verify on hardware — stage 4, before building

These gate the design and none can be settled without the tablet:

1. **Does Plasma's OSK raise for a Quickshell text field?** Quickshell would need to
   participate in `input-method-v2` / `text-input-v3` as a layer-shell client. If it does
   not, §1.6 (launcher) and §1.13 (polkit) are **unusable folio-detached** — and that is a
   project-level risk, not a detail.
   **The probe is written and ready: `~/specs/osk-probe/` (`run.sh`, decision table in
   `README.md`).** Run it before writing any shell code. It switches `keyboardFocus`
   None/OnDemand/Exclusive at runtime — `PanelWindow.focusable` defaults to *false*, which
   is the most likely way to get a false negative — tests `Qt.inputMethod.show()` as a
   workaround path, and carries an ordinary-window control to separate "layer surfaces
   can't do IM" from "Quickshell can't". Detach the folio first; Plasma may suppress the
   OSK while a physical keyboard is present. Record the outcome back here.
2. Does the OSK overlap or push the island? It appears at the bottom, the island at the
   top, so it should be fine — confirm.
3. Actual physical size of 48 px after tablet-mode scaling. Measure; do not assume.
4. Do edge-swipe input regions on a layer surface conflict with KWin's own edge gestures?

### 3.2 HiDPI on a small panel
High-resolution 3:2 display at ~12". Needs a Hyprland `monitor=,preferred,auto,<scale>`
value **and matching Qt scaling** for Quickshell. Mismatched scale factors are the classic
cause of a Quickshell surface rendering half-size or blurry. Confirm the panel's native
resolution on arrival — do not design fixed pixel sizes before then. §1.10's live bar-height
and font-size sliders become genuinely load-bearing here, not a gimmick.

### 3.3 Rotation
Hyprland has no built-in auto-rotate. Needs `iio-sensor-proxy` plus a rotation script —
**and** the island must survive portrait. A horizontally-laid-out three-zone island
(§1.2) does not fit a portrait 3:2 panel. Plan a portrait variant or lock rotation.

### 3.4 On-screen keyboard
Plasma provides one (new in 6.6) and Tablet Mode raises it — this is no longer something
to build, per §6.4. **But it is still the project's biggest unknown:** it must actually
raise for a *Quickshell* text field, not just for ordinary apps. See §3.1.8 item 1 — test
that before building anything, because §1.6 and §1.13 depend on it entirely.

### 3.5 Battery and thermals
Intel N-series. The source setup advertises "hardware-accelerated" and leans on constant
spring animation. Treat animation duration and any blur pass as an explicit tuning axis
from the start, rather than discovering it as "battery gone by lunch".

### 3.6 Descope for tablet
- §1.14 multi-monitor — irrelevant, drop it
- §1.12 lock screen — the source has nothing worth copying. Now specced separately in
  `~/specs/quickshell-lock-greeter.md`, which proposes an original design and flags the
  crash-lockout hazard. Still optional; KDE's own locker is the safe default.

---

## 4. Staged execution order (when the hardware lands)

> **Superseded in detail by `~/specs/quickshell-build-order.md`**, which sequences all fifteen
> component specs against each other around *usable milestones*. The summary below stands; that
> document is what to actually follow.

Each stage independently revertible.

0. Boot stock Plasma. Confirm the tablet works — touch, rotation, keyboard, battery, Wi-Fi. Record what "working" looks like.
1. Confirm a rollback path exists before touching sessions.
2. Enable COPRs; install Hyprland + Quickshell + hyprsunset + wallust.
3. Add Hyprland as a *separate* SDDM session. Verify Plasma still boots.
4. On stock Plasma, verify touch, rotation, scaling and OSK. **Then run `~/specs/osk-probe/run.sh` (§3.1.8 item 1) — does Plasma's OSK raise for a Quickshell text field on a layer surface?** Everything downstream depends on the answer.
5. Minimal Quickshell surface — the collapsed pill (§1.1) and nothing else. Verify it renders at correct scale.
6. Build outward: island (§1.2) → OSDs (§1.4) → launcher (§1.6) → control centre (§1.7) → theme system (§1.8).
7. Icon system (§1.3) — do this incrementally alongside, it is the long pole.
8. Touch/rotation adaptations (§3) applied per component as each is built, not bolted on at the end.

Stages 5–8 are the real project and each gets its own small spec when reached.
Written so far: `~/specs/quickshell-launcher.md` (§1.6),
`~/specs/quickshell-control-center.md` (§1.7),
`~/specs/quickshell-notifications.md` (§1.5, owns the notification service),
`~/specs/quickshell-polkit.md` (§1.13),
`~/specs/quickshell-osd.md` (§1.4 — build this one first),
`~/specs/quickshell-icons.md` (§1.3 — shared library),
`~/specs/quickshell-theming.md` (§1.8 — the token contract),
`~/specs/quickshell-power-menu.md` (§1.11),
`~/specs/quickshell-settings.md` (§1.10),
`~/specs/quickshell-wallpaper.md` (§1.9).
`~/specs/quickshell-island-core.md` (§1.0–§1.2 — **the foundation; build first**),
`~/specs/quickshell-lock-greeter.md` (§1.12 + greeter — **highest-consequence failure**),
`~/specs/quickshell-media.md` (MPRIS service — four consumers),
`~/specs/quickshell-status-capsule.md` (battery + network; corrects §1.1),
`~/specs/quickshell-system-tray.md` (**not in the source** — closes a regression the port creates).
**All components now have specs.**

---

## 5. Open questions — decide before stage 5

1. **Is this a daily driver or a toy?** Daily-driver raises the bar sharply on the OSK and
   rotation. *(Partly answered by §6: on Plasma both come for free.)*
2. ~~**Build the icon system by hand (§1.3), or accept an icon font for v1?**~~ **ANSWERED —
   `~/specs/quickshell-icons.md` §1. Neither: hand-author the 4 icons that encode a *value*,
   import the ~15 static ones as SVG path data into `PathSvg` so they remain real `Shape`s.
   Same tinting, same crispness, no icon font — roughly a quarter of the work.**
3. ~~**Does the 18-theme system (§1.8) survive scope contact?**~~ **ANSWERED — build the
   derivation for all 18, populate three first** (dark, `e-ink`, saturated accent). The
   contrast audit is per-theme; get it passing small, then scale. See theming §12 q1.
4. ~~**Is Hyprland the right compositor here at all?**~~ **ANSWERED — see §6. No: run
   Quickshell on Plasma/KWin.**

---

## 6. Compositor decision — Plasma/KWin, not Hyprland

Researched 2026-08-23. **Verdict: Plasma Wayland + Quickshell is viable, and is the better
choice for this hardware.** Sources at the end of this section.

### 6.1 Does Quickshell run on KWin at all? — Yes

Quickshell places its surfaces with `wlr-layer-shell-unstable-v1` via `PanelWindow` /
`WlrLayershell`. Quickshell's own docs describe that protocol as "implemented by wlroots
(sway, hyprland, wayfire, etc), Smithay (PopOS Cosmic) and **KWin (KDE Plasma)**; pretty
much all major wayland compositors besides GNOME."

Corroborating and more decisive: KDE tracks *bugs* in KWin's wlr-layer-shell
implementation (bug 503121), which is only possible because the implementation exists.
This is not an aspiration — it ships.

### 6.2 Does the *lock screen* work? — Yes, on 6.6+

Quickshell's session lock needs `ext-session-lock-v1`. Sources conflict here and the
conflict matters, so: the gtk-session-lock docs state Plasma does **not** support it, but
that is **stale**. The Wayland protocol registry lists **KWin 6.6** as an implementer.
Fedora KDE ships Plasma 6.7.x, so this is fine — but confirm the running Plasma version on
arrival rather than assuming.

### 6.3 The decisive point: this design needs *no* compositor IPC

`Quickshell.Hyprland` exists to expose workspaces, monitors, toplevels and dispatcher
commands. **Re-read §1: this design uses none of that.** There is no workspace indicator,
no window list, no window-management surface anywhere in the 15-minute tour. Every
component is backed by a *system* service, all of which are compositor-neutral:

| Component | Backed by |
|---|---|
| Clock, EQ bars, media card (§1.1, §1.2, §1.7) | MPRIS — spec: `~/specs/quickshell-media.md` |
| Volume, audio devices (§1.4, §1.7) | PipeWire |
| Battery, charging (§1.3) | UPower |
| Wi-Fi, Bluetooth (§1.7) | NetworkManager / BlueZ |
| Notifications, peace mode (§1.5) | org.freedesktop.Notifications |
| Auth card (§1.13) | polkit |
| Power menu (§1.11) | logind |
| Launcher (§1.6) | desktop entries |
| Theming (§1.8) | wallust |

The one Hyprland-coupled item was multi-monitor (§1.14), already descoped for a tablet.
**Choosing Hyprland buys this design nothing it uses.**

### 6.4 What Plasma buys — most of §3, for free

This is the real argument. Plasma has a **Tablet Mode** that triggers on folio removal and
raises render scaling, starts auto-rotate and enables touch input — and Plasma 6.6 shipped
a proper on-screen keyboard. The StarLite has exactly that detachable-folio form factor.

That deletes or shrinks most of §3: **§3.2 (HiDPI), §3.3 (rotation) and §3.4 (OSK) stop
being your problem.** On Hyprland all three are hand-rolled — an `iio-sensor-proxy` script,
manual scale factors, and bolting on `wvkbd`, with no orchestration tying them together.
§3.1 (touch has no hover) remains yours either way; it is a design problem, not a
compositor one.

### 6.5 The three real costs

1. **Global shortcuts must be rebound.** Quickshell's `GlobalShortcut` is Hyprland-only and
   deliberately does *not* use the xdg-desktop-portal global-shortcuts protocol. All seven
   keybinds (§1.6–§1.12) instead get bound in KDE System Settings to `qs ipc call …`.
   Functional, but it spawns a process per keypress — watch launcher-open latency, and
   budget a look at it if it feels sluggish.

2. **KWin layer-shell bug 503121 — CONFIRMED and still open.** Unmapping a layer surface
   (null buffer) and remapping it produces **no configure event**; a KWin maintainer's
   comment is "it's not implemented". Sway and Hyprland behave correctly. This is the
   single biggest technical risk, because this design shows and hides surfaces constantly
   (OSDs auto-dismiss after ~1.5 s, notifications appear and vanish, the launcher opens and
   closes).
   **Mitigating it is cheap, and the design already points at the answer:** the island is
   *one persistent surface that morphs*, not many surfaces being created and destroyed. Keep
   a single layer surface mapped for the island's whole lifetime and change its size and
   contents — never unmap it — and the bug is structurally unreachable. Build it that way
   from stage 5 rather than discovering this later. A documented fallback exists anyway
   (reset the layer properties before committing).

3. **Two shells will fight over the same DBus names.** plasmashell already owns
   `org.freedesktop.Notifications`, a polkit agent, volume/brightness OSDs and the panel.
   Each Quickshell component that replaces one needs its Plasma counterpart disabled, or
   you get doubles. Expect this to be fiddly config work, not a blocker.

### 6.6 Recommended configuration

**Full Plasma session, with Quickshell running inside it as an additional layer-shell
client** — *not* a bespoke `kwin_wayland`-only session.

Dropping plasmashell to run "KWin + Quickshell" is technically possible but throws away
the Tablet Mode orchestration in §6.4, which is the entire reason to choose Plasma. Keep
Plasma; remove its panel; disable its services one at a time as Quickshell components come
online.

The sequencing win matters more than the architecture: you can run Quickshell as a plain
status pill on top of a **stock, working, already-touch-capable Plasma tablet** and grow it
component by component. No session surgery on day one, and a known-good desktop underneath
the whole time. On Hyprland you must own scaling, rotation and the OSK before the shell is
usable at all.

### 6.7 Revisions to earlier sections

- **§2** — Hyprland and hyprsunset are no longer required. Quickshell still comes from the
  `errornointernet/quickshell` COPR; wallust still needed. Night light (§1.7) should drive
  KWin's own built-in Night Light instead of hyprsunset.
- **§3.2, §3.3, §3.4** — reduced to "verify Plasma's built-ins behave on this panel", not
  build-it-yourself.
- **§4** — stages 2–4 collapse: no separate session to create, no Hyprland to install, no
  fallback session to protect. Start at stage 5 on stock Plasma.
- **§1.12 lock screen** — now genuinely optional; KDE's own lock screen is there, and
  Quickshell's `WlSessionLock` also works on 6.6+ if you want to style it later.

### 6.8 Sources

- Quickshell WlrLayershell docs — https://quickshell.org/docs/v0.1.0/types/Quickshell.Wayland/WlrLayershell/
- KWin bug 503121, wlr-layer-shell unmap/remap — https://bugs.kde.org/show_bug.cgi?id=503121
- KWin layer-shell gap tracker — https://invent.kde.org/plasma/kwin/-/issues/229
- ext-session-lock-v1 compositor support (KWin 6.6) — https://wayland.app/protocols/ext-session-lock-v1
- Quickshell GlobalShortcut (Hyprland-only) — https://quickshell.org/docs/v0.1.0/types/Quickshell.Hyprland/GlobalShortcut/
- Plasma 6.6 on-screen keyboard — https://alternativeto.net/news/2026/2/kde-plasma-6-6-adds-virtual-keyboard-spectacle-text-recognition-and-improved-accessibility
- Plasma tablet mode on real hardware — https://www.makeuseof.com/i-put-linux-on-a-tablet-and-kde-plasma-handled-everything-i-threw-at-it/
