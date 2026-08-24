# Power menu — implementation spec

Component §1.11 of `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

The smallest component in the set — five buttons in a row. Two things make it worth a spec
anyway: **which D-Bus interface you call decides whether unsaved work survives** (§1), and the
arm-to-confirm mechanism has a hole on touch that it does not have with a mouse (§2).

Source [10:40]–[11:14]:

> "Control alt delete… The island morphs into a row of tiles. Lock, suspend, log out, reboot,
> and power off. And the destructive actions, they arm to confirm… first press on reboot turns
> the tile red and then says confirm. Second press actually fires it. But the safe stuff, like
> lock and suspend, they fire immediately."

---

## 1. The five actions — call the graceful interface

| Tile | Use | Not |
|---|---|---|
| **Lock** | `loginctl lock-session` (or logind `Session.Lock`) → Plasma's locker | — |
| **Suspend** | logind `Suspend(false)` / `systemctl suspend` | — |
| **Log Out** | `org.kde.Shutdown` → `logout()` | ~~`loginctl terminate-session`~~ |
| **Reboot** | `org.kde.Shutdown` → `logoutAndReboot()` | ~~`systemctl reboot`~~ |
| **Power Off** | `org.kde.Shutdown` → `logoutAndShutdown()` | ~~`systemctl poweroff`~~ |

> **This is the decision that matters in this spec.** `systemctl poweroff` and
> `loginctl terminate-session` are *hard* — they do not run Plasma's application-save
> handshake and they do not negotiate **systemd-logind inhibitor locks** (the mechanism an app
> uses to say "file transfer in progress, don't shut down"). Calling them means a tap on Power
> Off can discard an unsaved document with no warning.
>
> `org.kde.Shutdown` does the handshake, honours inhibitors, and is already running. Fifth
> appearance of the reuse-what-Plasma-provides principle (after Klipper, Solid, KWin Night
> Light and the Plasma colour scheme), and here the cost of ignoring it is data loss rather
> than inconsistency.

Lock deliberately invokes **Plasma's** lock screen — the Quickshell lock screen is descoped
(parent §1.12, §6.7), so there is nothing of ours to call.

Verify on hardware that `org.kde.Shutdown`'s methods act **directly** rather than raising
Plasma's own confirmation dialog — the island is doing the confirming (§2), and two
confirmation UIs stacked is worse than either alone. Historically the prompting variant is
`org.kde.LogoutPrompt` and `org.kde.Shutdown` is direct; confirm with `qdbus`.

---

## 2. Arm-to-confirm

| Tile | Behaviour |
|---|---|
| Lock, Suspend | fire **immediately** on first press |
| Log Out, Reboot, Power Off | **arm** on first press — tile turns `critical`, label becomes "Confirm" — fire on second |

### The touch hole the source does not have

> **A fast double-tap arms and fires in ~200 ms, defeating the entire mechanism.** With a
> mouse this barely happens; on a touchscreen, double-taps are a normal accident — a stutter
> tap, a bounced finger, a glove.
>
> **Fix: a minimum arm duration.** Ignore the confirming press for ~400 ms after arming. The
> tile is visibly red and says "Confirm" during that window, so it never feels unresponsive —
> it just cannot be fired by a gesture too fast to be deliberate.

This is the single most important line in the spec, and it exists only because the target is a
tablet.

### The rest of the state machine — none of which the source specifies

- **Armed state times out after ~3 s** and reverts. An armed Power Off tile left indefinitely
  on a tablet you set down is a mis-tap waiting to happen.
- **Only one tile armed at a time** — arming another disarms the first.
- **Tapping anywhere else, or dismissing, disarms.**
- A disarm is instant and silent; no animation that could be mistaken for firing.

### Default selection
Keyboard focus starts on **Lock** — the safest action, and what the source's frame shows
highlighted. A stray Enter should lock the tablet, never shut it down. Treat this as a rule,
not an accident of ordering.

---

## 3. Contention

Nothing new here, which is a good sign the rule set from the other specs is complete. The
power menu is `island.state === "power"`, surface never unmapped (KWin 503121, parent §6.5),
and it behaves exactly like the launcher and control centre:

| Event while power menu is open | Result |
|---|---|
| Notification arrives | suppressed, logged (notifications §1) |
| Volume / brightness changes | value updates, **no OSD** (osd §3) |
| Polkit request arrives | **preempts**; power menu restored after (polkit §5) |

---

## 4. UI

Horizontal row of five tiles in a single rounded container, top-centre — the island morphing
wider and shorter rather than taller.

```
┌───────────────────────────────────────────────┐
│  [🔒]   [🌙]    [↪]     [↻]      [⏻]         │
│  Lock  Suspend Log Out Reboot  Power Off      │
└───────────────────────────────────────────────┘
```

- Icon above, label below; tiles ~64×64 (parent §3.1.3's power-tile figure)
- Selected/focused tile carries an `accent` fill
- Armed tile: `critical` fill, label swaps to "Confirm"
- All colours from tokens (theming §2) — `critical` is the token the armed state needs, and
  this is its main consumer alongside critical notifications
- Icons from the shared library (icons §3): padlock, moon, log-out arrow, circular arrow,
  power symbol — all static, so all imported via `PathSvg`

Five tiles across a ~345 px island at 64 px each is tight; let the island widen for this state
rather than shrinking the tiles below the touch floor.

---

## 5. Input

| | Touch (folio off) | Keyboard (folio on) |
|---|---|---|
| Summon | **hardware power button**, or the control-centre footer (island-core §9.1) | `Ctrl+Alt+Delete` → `qs ipc call island toggle power` |
| Move | — | `←` / `→` |
| Activate | tap | `Enter` (twice for destructive) |
| Dismiss | tap outside / swipe up | `Escape` |

`Ctrl+Alt+Delete` is bound in KDE System Settings, since `GlobalShortcut` is Hyprland-only
(parent §6.5). **Check whether Plasma already binds that combination** to its own logout
screen and unbind it first, or the two will race (§9 q1).

Every tile needs an immediate press state (<50 ms, not a spring — parent §3.1.6).

---

## 6. Edge cases

- **Dismiss before locking.** Return the island to `rest` as part of the Lock action so the
  menu is not sitting open behind the lock screen, ready to receive a tap on unlock.
- **Dismiss on suspend.** After resume the island must be at `rest`, not showing a stale
  armed tile from before the machine went to sleep.
- **Inhibited shutdown.** If an inhibitor blocks the action, `org.kde.Shutdown` handles the
  negotiation — but make sure the island does not sit in a fired-but-nothing-happened state.
  Return to `rest` and let Plasma surface the reason.
- **Folio detached** — this component needs no text entry, so unlike the launcher and polkit
  card it is fully usable with no on-screen keyboard. It is the one component with no OSK
  dependency at all.

---

## 7. Build order

1. Island enters/exits `"power"`; five static tiles; dismiss paths.
2. Lock and Suspend wired (safe actions, immediately reversible — Lock especially, since you
   just unlock again).
3. Arm-to-confirm state machine including the **400 ms floor** and 3 s timeout (§2). Test with
   a harmless stand-in action before wiring anything destructive.
4. Log Out, Reboot, Power Off via `org.kde.Shutdown`.
5. Keyboard navigation, default-focus-on-Lock.
6. Icons from the shared library once icons §3 lands.

> Do **not** wire step 4 before step 3 is verified. Testing a power menu means actually firing
> it, and a broken confirm gate discovered by rebooting mid-work is an avoidable afternoon.

---

## 8. Acceptance criteria

- [ ] Lock and Suspend fire on a single press
- [ ] Log Out, Reboot, Power Off require two presses; first shows `critical` fill + "Confirm"
- [ ] **A rapid double-tap on a destructive tile does not fire it** (§2's 400 ms floor)
- [ ] Armed state reverts after ~3 s untouched
- [ ] Arming a second destructive tile disarms the first
- [ ] Keyboard focus starts on Lock; a stray Enter locks, never shuts down
- [ ] Power Off with an unsaved document prompts to save — proves `org.kde.Shutdown`, not `systemctl poweroff`
- [ ] A logind inhibitor blocks or negotiates rather than being silently overridden
- [ ] `Ctrl+Alt+Delete` opens this and **not** Plasma's own logout screen
- [ ] Island returns to `rest` on lock and across a suspend/resume cycle
- [ ] Fully operable folio-detached with no on-screen keyboard
- [ ] Hardware power button opens this menu; Plasma's own power-button action does not also fire
- [ ] Island never unmaps entering/leaving `"power"` (503121 regression check)
- [ ] Legible in `e-ink`, including the `critical` armed state on a light surface

## 9. Open questions

1. Does Plasma bind `Ctrl+Alt+Delete` by default on Fedora 44 KDE? If so, unbind before
   claiming it (§5).
2. Do `org.kde.Shutdown`'s methods prompt, or act directly? Confirm with `qdbus` (§1).
3. ~~Should the power menu be reachable from the control centre as well as a shortcut?~~
   **ANSWERED — `quickshell-island-core.md` §9.1.** Two touch paths: the **hardware power
   button** (`XF86PowerOff` bound to `qs ipc call island toggle power`, with Plasma's own
   button action set to *Do nothing* so it does not consume the key), plus a **control-centre
   footer button**. Redundant on purpose — this is the entry point whose absence strands you.
   A long press remains a firmware-level hard power off regardless.
4. Hibernate — absent from the source. Add only if the tablet's suspend proves unreliable.
5. "Restart to firmware setup" — occasionally handy on a device with coreboot. Optional.

## 10. APIs and dependencies

- `org.freedesktop.login1` — `Session.Lock`, `Suspend` (systemd, present).
- `org.kde.Shutdown` — `logout()`, `logoutAndReboot()`, `logoutAndShutdown()`. Ships with
  Plasma. **Method names unverified** — confirm with `qdbus org.kde.Shutdown /Shutdown`.
- Quickshell `IpcHandler` and `Process` (both confirmed, launcher §14).
- Shared icon library (icons §3), `critical` token (theming §2).
