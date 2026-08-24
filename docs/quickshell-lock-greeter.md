# Lock screen and greeter — implementation spec

Component §1.12 of `~/specs/quickshell-starlite-rice.md`, plus the greeter (not in the source).

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

**This spec un-descopes something.** Parent §3.6 and §6.7 both set the lock screen aside, on
the grounds that the source has nothing worth copying — [11:14]: *"I have a very simple lock
screen in place. I had not gotten around to customizing the lock screen just yet."* So there is
no reference design here; §7 is an original proposal.

Two components, and they are **not** the same risk:

| | Failure mode | Recovery | Verdict |
|---|---|---|---|
| **Lock screen** | locked out of a running session | TTY, or SSH from another machine | Buildable, with §3's guardrails |
| **Greeter** | cannot log in at all | TTY only — **needs the folio attached** | **Do not replace SDDM.** §2 |

---

## 1. Lead finding: the documented crash behaviour

From Quickshell's own `WlSessionLock` documentation:

> "If the WlSessionLock is destroyed or quickshell exits without setting `locked` to false,
> conformant compositors will leave the screen locked and painted with a solid color."

That is a deliberate **security** property of `ext-session-lock-v1` and it is correct
behaviour — a crashed locker must never expose the session. But read what it means here:

> **If `qs` crashes while the screen is locked, the tablet shows a solid colour and is
> inoperable until you reach a TTY. On a tablet, reaching a TTY means attaching the keyboard
> folio.** If the folio is in another room, the device is bricked until you fetch it.

Every other component in this project fails *soft* — a broken launcher is an annoyance, a
broken polkit agent means you cannot administer the machine. **This one fails hard**, and it is
the only component that can render the device unusable while behaving exactly as designed.

That does not make it unbuildable. It makes §3 and §8's recovery plan mandatory rather than
prudent.

---

## 2. The greeter — do not replace SDDM

`Quickshell.Services.Greetd` exists, and a Quickshell greeter over greetd is technically
possible. **Do not do it on this device.**

A broken greeter means you cannot reach a graphical session at all. The recovery path is a TTY,
which on a detachable tablet requires the folio — the exact accessory whose absence this whole
project has been designing around. It is the one failure this device cannot absorb.

### Get the look without the risk
**SDDM themes are QML.** You can write an SDDM theme that matches the island's design language
without replacing SDDM with anything:

- SDDM keeps running, keeps working, and keeps its own fallback behaviour
- A broken *theme* is recoverable by editing `sddm.conf` from a TTY **or** by another user
  account, and SDDM falls back rather than failing to start
- wallust can render the theme's colours from a template, so the greeter tracks the active
  scheme exactly like everything else (theming §5)

Caveat: an SDDM theme runs in **SDDM's own QML runtime**, not Quickshell. It cannot import
`Quickshell.*`, so this is a visual reimplementation sharing the design language and the colour
tokens — not shared code. That is a modest cost for removing the project's only truly
unrecoverable failure mode.

**Everything below concerns the lock screen only.**

---

## 3. Three hazards before you enable this

### 3.1 The OSK on a lock surface — the worst of the three
The lock screen needs a password field. With the folio detached that needs the on-screen
keyboard — **and it is genuinely unclear whether Plasma's OSK functions over a Quickshell
`ext-session-lock` surface**, since the session is locked and plasmashell's own surfaces are
suppressed. KWin handles input-method, so it may work; nobody should assume it.

> **If the OSK does not work here, you cannot unlock the tablet without attaching the keyboard.**
> That is worse than the polkit case (§1.13), which merely blocks administration.

This needs its own probe, extending `~/specs/osk-probe/`: add a `WlSessionLock` mode that locks,
shows a password field, and — crucially — **is dismissible by a timer** so a failed probe does
not lock you out. Test it with the folio attached and an SSH session open, before ever relying
on it.

### 3.2 kscreenlocker will fight you
Plasma's own locker responds to the same trigger (§5). Two lockers racing for
`ext-session-lock` is undefined at best. kscreenlocker must be disabled — `Autolock=false` and
`LockOnResume=false` in `kscreenlockerrc` at minimum, possibly masking its service. **Verify
which is actually needed**, and write down the reversal before applying it.

### 3.3 No second way in means no testing
Do not test a lock screen with no route back. Have **SSH from another machine** working, or the
folio attached with a TTY reachable, every single time. This is the rule that makes §1
survivable.

---

## 4. API

```qml
WlSessionLock {
    id: lock
    // locked : bool  — only one lock may be active at a time
    // secure : bool  — readonly; true once the compositor confirms every screen is covered
    WlSessionLockSurface {
        // one instantiated per screen; single screen here
    }
}
```

Authentication: `Quickshell.Services.Pam` → `PamContext` (auth type only, which is all a
locker needs), with `PamError` and `PamResult`.

Protocol support: **KWin 6.6+** implements `ext-session-lock-v1` (parent §6.2 — note that older
sources claiming Plasma lacks it are stale). Fedora 44 tracks 6.7.x. Confirm the running
version.

> **There is an official Quickshell lockscreen example** in `quickshell-examples/lockscreen/`,
> which uses the PAM module and follows the system colour scheme. **Start from it.** This is the
> one component where copying working reference code is strictly better than writing from
> scratch, because the failure mode is being locked out.

`secure` is not decoration — do not accept a password until it is true, or you may be taking
input while a screen is uncovered.

---

## 5. Trigger — listen to logind, do not build an idle daemon

On Hyprland this would need `hypridle`. Here it does not.

`loginctl lock-session` emits a **`Lock` signal on the logind session object**, and anything
may listen. Both the power menu's Lock tile (power-menu §1) and PowerDevil's idle timeout
raise it. So:

> Listen for `org.freedesktop.login1.Session`'s `Lock` signal and set `locked = true`. Emit
> `Unlock`/`SetIdleHint` appropriately on unlock.

That means **PowerDevil keeps owning the idle policy** — timeouts, lock-on-suspend,
lock-on-resume all stay in Plasma's settings where they already work and are already tuned for
a battery device. Seventh application of the reuse-what-Plasma-provides principle, and it
removes an entire daemon from the dependency list.

---

## 6. Security and privacy

Same non-negotiables as the polkit card (`quickshell-polkit.md` §2), for the same reasons:

- Password never logged, never persisted, never on the clipboard; cleared on every exit path
- `echoMode: TextInput.Password`, and **`Qt.ImhNoPredictiveText | Qt.ImhSensitiveData |
  Qt.ImhHiddenText | Qt.ImhNoAutoUppercase`**
  — the predictive-text hazard is **worse here than in the polkit card**: this is the login
  password, and an OSK that learns it will suggest it in every other application
- **Fail closed**: any PAM error leaves the session locked. There is no error path that unlocks
- Rate-limit attempts; let PAM's own delay stand rather than defeating it
- Do not accept input before `secure` is true (§4)

### Privacy — notifications on the lock screen
The control centre keeps notification history (control-centre §9), and it is tempting to
surface it here.

> **Show a count, never content.** A lock screen displaying notification bodies leaks messages
> to anyone who picks the tablet up — which is the entire population of people the lock screen
> exists to exclude. If content is ever wanted, it is opt-in per app, defaulting to hidden.

---

## 7. Design — an original proposal

No reference exists (§0), so this follows the shell's own language rather than the source's
placeholder.

```
                    23:57
                Sunday, 7 June

              ┌──────────────────┐
              │ ••••••••         │
              └──────────────────┘

     🔋 80%   📶            ▸ IRIS OUT — Kenshi Yonezu
```

- Flat, token-themed (theming §2), works in `e-ink` — same rules as everything else
- Large clock and date, mirroring the `expanded` island's centre zone (island-core §7) so the
  lock screen reads as the same system
- Password field, ≥48 px, centred above the OSK's expected rectangle — bind to
  `Qt.inputMethod.keyboardRectangle` rather than guessing (launcher §6 does the same)
- **Battery and network status** — genuinely useful locked, and reuses two of the four stateful
  icons (icons §4)
- **Media controls when playing** — the one lock-screen affordance a tablet really wants;
  MPRIS is already wired for the island (osd, control-centre)
- Notification **count only** (§6)
- Wallpaper as background, dimmed — the current one, read from Plasma (wallpaper §2)

Portrait must work (parent §3.3). A centred column handles rotation far better than the
island's three-zone row, so this is the easy case.

---

## 8. Build order — and the recovery plan is part of it

0. **Establish a second way in.** SSH from another machine, tested. Not optional.
1. Extend `~/specs/osk-probe/` with the §3.1 timer-dismissed lock probe. **Folio attached.**
   If the OSK does not appear, stop — the rest of this spec is unusable detached.
2. Copy the official example (§4); run it *without* disabling kscreenlocker, triggered manually,
   to see it work at all.
3. PAM unlock path; verify failure leaves you locked and success unlocks.
4. Disable kscreenlocker (§3.2). **Write the reversal down first.** From here on you are relying
   on your own locker.
5. logind `Lock` signal listener (§5); verify the power menu's Lock tile and PowerDevil idle
   both reach it.
6. Design (§7): clock, battery, network, media, notification count.
7. Crash-behaviour drill: **deliberately `kill -9 qs` while locked** and confirm you can recover
   by the route from step 0. Do this on purpose, once, while calm — not by accident later.

Step 7 is the point of the whole ordering. Knowing exactly what a crashed locker looks like, and
having recovered from it once, is what makes §1 an understood risk rather than a lurking one.

---

## 9. Acceptance criteria

- [ ] OSK raises on the lock surface with the folio detached (§3.1) — or the component is abandoned
- [ ] Wrong password leaves the session locked; PAM error leaves it locked; **no path unlocks on error**
- [ ] Input is refused until `secure` is true
- [ ] `kill -9 qs` while locked leaves a locked screen (not an exposed session), and the step-0 route recovers it
- [ ] kscreenlocker does not also engage — no double lock, no race
- [ ] `loginctl lock-session`, the power menu's Lock tile, and PowerDevil's idle timeout all lock
- [ ] Lock on suspend and on resume still behave, with policy still in Plasma's settings (§5)
- [ ] Password not in the journal after an unlock (`grep` it), not on the clipboard
- [ ] After unlocking, the OSK does **not** suggest the login password in another app (§6)
- [ ] Notification **count** shown; no summaries, no bodies
- [ ] Media controls appear only while MPRIS reports playing
- [ ] Legible in `e-ink` and correct in portrait
- [ ] **Greeter unchanged — SDDM still installed and starting the session** (§2)

## 10. Open questions

1. **Does Plasma's OSK work over an `ext-session-lock` surface?** (§3.1) The whole component
   turns on this. Probe before anything else.
2. What exactly must be disabled to stop kscreenlocker responding — config keys, or a masked
   service? (§3.2)
3. Does PowerDevil's lock-on-resume still fire correctly with a third-party locker?
4. Can the SDDM theme's colours be driven from the same wallust run as everything else, or does
   SDDM read its theme config too early in boot? (§2)
5. Should unlocking restore the island to `rest`, or to whatever state preceded the lock?
   `rest` is safer — a launcher query surviving a lock is a small information leak.
6. Fingerprint or PIN — does the StarLite have a reader? If so, `PamContext` may cover it, and a
   PIN keypad would sidestep §3.1 entirely by needing no OSK. **Worth checking early; it could
   demote the biggest hazard in this spec to nothing.**

## 11. APIs confirmed 2026-08-23

`Quickshell.Wayland` → `WlSessionLock` (`locked`, `secure`, default `surface` Component) and
`WlSessionLockSurface`, one per screen, implementing `ext-session-lock-v1`.
`Quickshell.Services.Pam` → `PamContext` (auth only), `PamError`, `PamResult`. Both in v0.2.0.
`Quickshell.Services.Greetd` exists — **deliberately unused**, see §2.
Reference implementation: `quickshell-examples/lockscreen/`.
