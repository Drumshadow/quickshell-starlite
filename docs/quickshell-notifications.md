# Notifications — implementation spec

Component §1.5 of `~/specs/quickshell-starlite-rice.md`.

**This spec owns the notification *service*.** The control centre
(`~/specs/quickshell-control-center.md` §9) is a second *view* onto the same model — build
the server once, here. It also owns the D-Bus gate that the control centre §0 references.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

---

## 0. Gate — claiming `org.freedesktop.Notifications`

Only one process may own the name. **plasmashell already owns it** (parent §6.5). This is
the same gate the control centre §0 describes, and it is tested here because this is the
component that claims the name.

```bash
busctl --user list | grep -i notif          # current owner + PID
# with a minimal Quickshell NotificationServer running:
busctl --user list | grep -i notif          # did ownership move?
notify-send "probe" "who renders this?"
```

| Result | Verdict | Action |
|---|---|---|
| Quickshell takes the name and renders | **Green** | Build as specced. |
| Plasma keeps it; Quickshell idle | **Amber** | Look for a supported way to stop Plasma's notification service without stopping plasmashell. If none, take the fallback. |
| Name held but nothing renders | **Red** | System notifications are silently broken. Revert now. |

**Amber fallback:** abandon this component. Plasma renders its own toasts and keeps its own
history; the island loses §1.5, the control centre loses §9, and Peace mode becomes a proxy
for Plasma's Do Not Disturb. Costs a visible chunk of the design, survivable, and the rest
of the shell is unaffected.

**Before disabling anything, write down how to re-enable it.** A tablet with no
notifications and no record of what you turned off is a bad afternoon.

### The regression nobody anticipates
Taking this name means **you also inherit notification sounds.** Plasma currently plays them
via `hints.sound-name`. If you claim the bus name and ignore that hint, sounds silently stop
system-wide and it will not be obvious why. Decide deliberately: implement, or accept and
record it (§8).

---

## 1. Architecture

One `NotificationServer` (`Quickshell.Services.Notifications`), one model, two views:

| View | Where | Spec |
|---|---|---|
| Toast | island state `"notification"` | this file |
| History list | control centre | control-centre §9 |

Surface rule unchanged from every other component: **the island never unmaps** (KWin bug
503121, parent §6.5). The toast is a state, not a window.

### Surface contention — the rule that falls out of one surface
There is one island, so a notification cannot appear while the launcher or control centre is
open without hijacking the surface the user is actively using.

> **Policy: if `island.state` is anything other than `"rest"`, suppress the toast.** Log to
> history, and show a small unread badge on the island. Never yank the surface out from
> under an open launcher.

This is a direct consequence of the §1.0 one-element conceit and is easy to miss until it
bites mid-demo.

---

## 2. The freedesktop contract

`Notify(app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout)`.

Handle properly, because apps depend on it:

- **`replaces_id`** — must update the existing notification in place, not append. Skip this
  and Spotify track changes and any progress notification become a spam firehose. The single
  most commonly botched part of a homemade server.
- **`expire_timeout`** — `-1` server default, `0` **never expire**, `>0` milliseconds.
  Clamp app-supplied values to a sane floor/ceiling; do not trust them blindly.
- **`CloseNotification(id)`** — must work; apps call it.
- **`NotificationClosed(id, reason)`** — emit with the *correct* reason:
  `1` expired · `2` dismissed by user · `3` closed via `CloseNotification` · `4` undefined.
  Apps branch on this.
- **`ActionInvoked(id, action_key)`** — only if actions are declared (§3).
- **`GetServerInformation`** / **`GetCapabilities`** — see §3.

### Relevant hints
`urgency` (0 low / 1 normal / 2 critical) · `image-data` · `image-path` · `desktop-entry` ·
`category` · `transient` · `resident` · `sound-name` · `suppress-sound`.

---

## 3. Capabilities — declare less, on purpose

`GetCapabilities` is a contract: **what you declare changes what apps send you.**

**v1 declares:** `body`, `icon-static`, `persistence`.
**v1 does NOT declare:** `actions`, `body-markup`, `body-hyperlinks`, `sound`.

Rationale:

- **No `actions`** — apps that check capabilities will omit action buttons, so nothing looks
  broken. Rendering buttons well on touch (≥48 px targets inside an already-dense toast) is
  real work and does not belong in v1. It is the **first thing to add in v2**; some apps send
  actions regardless of capabilities, and those are simply ignored until then.
- **No `body-markup`** — this is the security call, and it is the same one the launcher spec
  makes about `eval()`:

> Notification body text is **untrusted input from any process on the session bus**, rendered
> inside the process that also draws the polkit authentication card (parent §1.13). Render
> with `Text.textFormat: Text.PlainText` in v1. Enabling the spec's HTML subset
> (`<b> <i> <u> <a> <img>`) means accepting attacker-influenced rich text and an image loader
> in that process. If markup is added later, allowlist tags explicitly and never enable
> `<img>` with remote sources.

---

## 4. Urgency and the critical path

Source [03:57]: critical notifications get a red accent and a longer timeout.

| Urgency | Accent | Timeout | Peace mode |
|---|---|---|---|
| 0 low | normal | short (~4 s) | suppressed |
| 1 normal | normal | default (§5) | suppressed |
| 2 critical | **red** | **sticky — no auto-expire** | **bypasses** |

Two deliberate divergences from the source, both defensible:

1. **Critical is sticky, not merely longer.** Convention across notification servers is that
   urgency-2 does not auto-expire. "Longer" still means a genuinely important message can
   scroll past while the tablet is face-down.
2. **Critical bypasses Peace mode.** The source does not say this. A Do Not Disturb that
   swallows a critical notification is a bug, not a feature.

---

## 5. Timing and the countdown

Hover-to-pause (source [03:31]) does not exist on touch (parent §3.1.4). Compensate:

- **Default timeout ~6 s**, up from a typical 5 — you can no longer hold a notification open
  by resting the pointer on it.
- **Tap pins it open indefinitely**, replacing hover-pause.
- **Show a draining progress line** — a thin accent rule along the toast's edge. The source
  does not obviously have one; add it. On touch it is the affordance that teaches the pin:
  seeing time run out is what prompts someone to tap.

---

## 6. Queueing

One surface, one toast at a time. Needed policy:

- **Single slot, FIFO queue.** ~250 ms gap between toasts so consecutive ones read as
  separate events rather than a flicker.
- **Coalesce bursts per app** — three messages from one chat app become one toast with a
  count, not three sequential interruptions.
- **Cap the queue** (~5). Beyond that, drop to history only and badge the island; a backlog
  that takes a minute to drain is worse than no toast.
- Respect `transient` (do not persist to history) and `resident` (do not close on action).

---

## 7. Content and icons

Toast layout, matching the source: app-icon badge · dim app name · bold summary · dim origin
line · body · `✕`.

Icon resolution, in spec priority order:
1. `hints.image-data` (raw pixel struct)
2. `hints.image-path`
3. `app_icon`
4. `hints.desktop-entry` → `DesktopEntries.byId()` → its icon
5. **Themed letter avatar** — first letter of the app name on an accent-derived tint

Step 5 is the **same component the launcher uses for icon-less entries**
(`~/specs/quickshell-launcher.md` §6). One avatar component, two consumers — do not draw it
twice.

Touch interactions (parent §3.1.4): **tap = pin + expand body · tap again = activate default
action · swipe up = dismiss.** `✕` keeps a 48 px input region even at a ~16 px visual.

---

## 8. Peace mode

- Suppresses toasts; **still appends to history** (source [04:16] is explicit).
- Critical bypasses (§4).
- Persist the flag across restarts.
- Exposed as a control-centre tile (control-centre §4) and reflected on the island.
- **Sound:** with `sound` undeclared (§3), nothing plays in v1. Record this as a known
  regression from Plasma's behaviour rather than discovering it later. If it grates, either
  implement `sound-name` via `canberra-gtk-play`/libcanberra or revisit the §0 fallback.

---

## 9. Build order

1. `NotificationServer` with `GetCapabilities`/`GetServerInformation` only. Prove ownership — **run the §0 probe here, before any UI.**
2. Model: add, `replaces_id` update, close, correct `NotificationClosed` reasons. Verify with `notify-send` and `gdbus` before drawing anything.
3. Toast as an island state; plain text, default timeout, `✕`.
4. Surface-contention policy (§1) and the queue (§6).
5. Icon resolution chain (§7), sharing the launcher's letter avatar.
6. Urgency styling and the critical path (§4).
7. Draining progress line, tap-to-pin, swipe-to-dismiss (§5, §7).
8. Peace mode (§8) + control-centre tile.
9. Hand the model to control-centre §9 for the history list.
10. *(v2)* Actions, then reconsider markup and sound.

Steps 1–2 are pure service work with no UI and are the right place to find out this is
viable. Do not draw a toast until `notify-send` round-trips correctly.

---

## 10. Acceptance criteria

- [ ] §0 outcome recorded in this file with the date
- [ ] `notify-send` round-trips: appears, expires, emits `NotificationClosed` reason `1`
- [ ] Dismissing by swipe emits reason `2`; app-side `CloseNotification` emits reason `3`
- [ ] `replaces_id` updates in place — a Spotify track change or a progress bar produces **one** toast, not a stream
- [ ] `expire_timeout: 0` never auto-expires
- [ ] Critical shows red, does not auto-expire, and **appears while Peace mode is on**
- [ ] Non-critical while Peace mode is on: no toast, entry present in history
- [ ] A notification arriving while the launcher is open does **not** steal the surface
- [ ] Burst of 10 notifications does not produce a 10-toast queue drain
- [ ] Body renders as plain text — markup in a body is displayed literally, not interpreted
- [ ] Island never unmaps entering/leaving `"notification"` (503121 regression check)
- [ ] `✕` and the toast body both ≥48 px effective targets with immediate press feedback
- [ ] Legible in `e-ink` light scheme, including the red critical accent

## 11. Open questions

1. **§0 — can plasmashell release the name?** Everything here depends on it.
2. Does `NotificationServer` request the name with replacement semantics, or must Plasma's be stopped first? Affects whether §0 is even testable non-destructively.
3. Notification **sounds** — accept the regression, or implement (§8)?
4. Should history persist across a `qs` restart? Ephemeral is conventional; a list that empties on restart is mildly annoying. Defer; in-memory for v1.
5. Does Plasma still draw its *own* toasts if it keeps the name while Quickshell renders history? That combination would double up — check during §0.
6. Actions on touch: buttons inside the toast, or an expand-to-reveal row? Deferred to v2, but decide before declaring the capability.

## 12. APIs confirmed 2026-08-23

`Quickshell.Services.Notifications` → `NotificationServer`, an implementation of the
freedesktop Desktop Notifications specification, present in v0.2.0.
`DesktopEntries.byId()` for `desktop-entry` hint resolution (see launcher spec §14).

Unverified on hardware: whether `NotificationServer` exposes capability declaration and
close-reason control at the granularity §2–§3 assume. **Check this during build step 1** — if
it does not, §3's declare-less strategy may not be expressible and this spec needs revising.
