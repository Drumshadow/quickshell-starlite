# Polkit authentication agent — implementation spec

Component §1.13 of `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

---

## 0. Read this before building

> This is the highest-risk, lowest-functional-reward component in the project. It handles
> passwords, it is the mechanism by which you administer the machine, and a subtle fault is
> not obviously visible — unlike a broken launcher, a broken auth agent can look fine and
> still be wrong. Plasma already ships a working, audited agent.
>
> **Recommendation: build this last, and only once everything else is in daily use.** Keep
> `polkit-kde` installed and one command away throughout. The source calls this "the one
> that genuinely surprises people" — it is a showpiece, and showpieces are the right thing
> to defer on a device you depend on.

That said, it is genuinely buildable and Quickshell supports it properly. The rest of this
spec assumes you have decided to do it.

---

## 1. Three gates

### 1.1 ~~Version gate~~ — RESOLVED 2026-08-24: the module is present
Verified on the target image: `Quickshell.Services.Polkit` **is present and imports cleanly**
in Fedora's `quickshell-0.2.1^git20260209`, which is a git snapshot carrying modules the
tagged-0.2.x docs omit. **This gate is closed — polkit is not version-blocked.**

The rest of this spec's caution stands unchanged: it is still an auth agent, still only one per
session, and still the component whose failure stops you administering the machine.

### 1.2 Agent registration — only one agent per session
Polkit permits a single registered agent per subject. Plasma registers
`polkit-kde-authentication-agent-1`.

**Good news, and a real contrast with the notification gate:** on Plasma 6 this runs as its
own systemd user unit, so it stops independently *without* touching plasmashell —
```bash
systemctl --user status plasma-polkit-agent.service    # confirm the unit name first
systemctl --user stop plasma-polkit-agent.service
# revert:  systemctl --user start plasma-polkit-agent.service
```
Unlike `org.freedesktop.Notifications` (which plasmashell owns and may not release), this
gate is clean and reversible in one command. Verify the unit name on hardware.

Check registration succeeded via `PolkitAgent.isRegistered` — **do not assume**. An agent
that silently failed to register means every privilege prompt fails with no UI at all.

### 1.3 OSK — and here it matters more than anywhere else
The card contains a password field. With the folio detached and no on-screen keyboard, you
**cannot authenticate at all** — no updates, no installs, no system settings. That is a
worse outcome than a broken launcher.

> **Do not stop `plasma-polkit-agent.service` until the OSK probe is green *and* you have
> confirmed your own card's field raises the keyboard.** Order matters: prove the
> replacement works before removing the thing it replaces.

---

## 2. Security requirements — non-negotiable

These are not style preferences. Violating any of them is a credential-handling defect.

- **Never log the password.** No `console.log` of the field, of the flow, or of anything
  derived from either. Not even during debugging — a debug line survives into a commit.
- **Never persist it.** Clear the field immediately after `submit()`, on cancel, on timeout,
  on close, and on session lock. Do not hold it in a property that outlives the flow.
- **Never place it on the clipboard**, and never offer a reveal-password toggle that writes
  anywhere but the widget.
- **Field configuration:**
  ```qml
  echoMode: TextInput.Password
  inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText
                  | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
  ```
  `Qt.ImhNoPredictiveText` is the tablet-specific one and it is not optional: **without it a
  predictive on-screen keyboard can learn the password into its dictionary**, where it will
  later be suggested in other applications. This failure mode does not exist on the source's
  keyboard-driven desktop and is easy to miss when porting.
- **Fail closed.** Escape, tap-outside, timeout and error all call `flow.cancel()`. There is
  no path that leaves a flow ambiguous or assumes success.
- **Exclusive keyboard focus** while the card is up (§5) — keystrokes must not reach the
  application behind it.

---

## 3. API

```qml
PolkitAgent {
    id: agent
    // path defaults to "/org/quickshell/Polkit"
    // isRegistered : bool  — verify this, see §1.2
    // isActive     : bool  — a request is in flight
    // flow         : AuthFlow | null
}
```

`AuthFlow` exposes: `message` · `actionId` · `iconName` · `identities` · `cookie` ·
`submit(password)` · `cancel()`.

These map one-to-one onto the source's card, which is a good sign the design was built
against the same surface:

| AuthFlow field | Card element (frame @ 11:55) |
|---|---|
| `message` | "Authentication is needed to run `/usr/bin/pacman -Syu` as the super user" |
| `actionId` | the small dim line — `org.freedesktop.policykit.exec` |
| `identities` | who will authenticate (§4) |
| `submit()` / `cancel()` | `Authenticate` / `Cancel` |

**`identities` must be handled.** It is a list — commonly one entry, but where root and the
user are both permitted it has two. Ignoring it and submitting against the wrong identity
produces an authentication failure with no explanation. If `identities.length > 1`, show a
picker; otherwise show the single identity as static text so the user knows *who* they are
authenticating as.

---

## 4. Card layout

From the source frame, top to bottom:

```
🔒  Authentication Required
Authentication is needed to run `/usr/bin/pacman -Syu` as the super user
org.freedesktop.policykit.exec                      ← dim, small, verbatim
┌────────────────────────────────────────────────┐
│ Password:                                      │
└────────────────────────────────────────────────┘
                              [ Cancel ] [ Authenticate ]
```

- Lock glyph + "Authentication Required" header
- `message` rendered **verbatim** — never reformat, re-wrap creatively, or truncate; wrap it
- `actionId` beneath in dim small text
- Identity line (§3)
- Masked field (§2)
- `Cancel` (neutral) and `Authenticate` (accent), both ≥48 px, `Authenticate` disabled while
  the field is empty
- On failure: inline error, field cleared, focus retained, retry permitted. Polkit allows
  limited retries — surface the attempt failing rather than silently re-prompting.

### Anti-spoofing
Showing the `actionId` verbatim is the anti-spoofing measure and the source is right to do
it. Be honest about its limit: **any application can draw a window that looks like this
card.** What a user can actually verify is that the action ID matches what they just tried to
do. So: render it always, never hide it behind a disclosure, and never abbreviate it. Do not
add decoration that makes the card easier to imitate convincingly than the real one.

---

## 5. Surface behaviour — polkit preempts

Same one-island architecture; the surface never unmaps (KWin 503121, parent §6.5). The card
is `island.state === "auth"`.

**The contention rule inverts relative to notifications**, and the contrast is the point:

| Component | Rule |
|---|---|
| Notifications (`quickshell-notifications.md` §1) | **Never** steal the surface — suppress and log |
| **Polkit** | **Always preempt** — restore the previous state afterwards |

A polkit request is a synchronous blocking call; the requesting process is stalled waiting.
Suppressing or queueing it hangs that process. So it wins, unconditionally.

Preserve and restore whatever the island was doing — including a launcher query in progress,
which should come back intact after the prompt resolves.

`WlrLayershell.keyboardFocus` → `Exclusive` for the duration (§2), back to `None` after.

**On session lock:** cancel the flow and clear the field. Do not leave a password sitting in
a widget behind a lock screen.

---

## 6. Timeout

Polkit does not mandate a client timeout. Add one: cancel and clear after ~90 s with no
input, so an unattended prompt does not sit indefinitely holding exclusive keyboard focus on
a tablet that someone else may pick up.

---

## 7. Build order

1. `PolkitAgent` with **no UI**. Log `isRegistered` only. Confirm registration succeeds while
   `plasma-polkit-agent.service` is stopped, and that stopping/starting that unit is clean.
2. Card UI with the field **inert** — render `message`, `actionId`, `identities` from a real
   flow triggered by `pkexec true`. Verify text is verbatim and correct. Do not wire `submit`.
3. Confirm the field raises the OSK, folio detached (§1.3). **Stop here if it does not.**
4. Wire `submit()` / `cancel()`. Test success, failure, retry, cancel, and Escape.
5. Preemption and state restore (§5).
6. Timeout (§6), session-lock cancel, error display.
7. Only now consider masking `plasma-polkit-agent.service` permanently — and keep the unmask
   command in this file.

Steps 1–3 are non-destructive and reversible. The commitment point is step 7.

---

## 8. Acceptance criteria

- [ ] `qs --version` ≥ 0.3.0 confirmed and recorded here
- [ ] `PolkitAgent.isRegistered` verified true, not assumed
- [ ] `pkexec true` produces the card; `message` and `actionId` render **verbatim**
- [ ] Correct password authenticates; the calling command proceeds
- [ ] Wrong password shows an inline error, clears the field, and allows retry
- [ ] Escape, tap-outside and timeout all cancel — the calling process receives a failure, never a hang
- [ ] Field raises the OSK folio-detached, and the OSK does not obscure the buttons
- [ ] Predictive text is off — after authenticating, the password is **not** suggested by the keyboard in another app
- [ ] Password appears in no log, no file, no clipboard (`grep` the journal after a test auth)
- [ ] A prompt arriving while the launcher is open preempts it, and the launcher query is restored afterwards
- [ ] Session lock during a prompt cancels the flow and clears the field
- [ ] `systemctl --user start plasma-polkit-agent.service` restores the old agent cleanly — **tested, not assumed**
- [ ] Island never unmaps entering/leaving `"auth"` (503121 regression check)
- [ ] Legible in the `e-ink` light scheme

## 9. Open questions

1. Confirm the Plasma polkit unit name on Fedora 44 (`plasma-polkit-agent.service`?).
2. Does `AuthFlow` surface retry count / remaining attempts, or must failures be inferred?
3. Does it expose the requesting **subject** (calling process / PID)? Showing "requested by
   *konsole*" would strengthen §4's anti-spoofing beyond the action ID alone.
4. Does stopping Plasma's agent affect anything else in the session (SDDM, kded modules)?
5. Behaviour if `qs` dies mid-flow — does polkitd time out cleanly, or is the caller stuck?
   Test deliberately before step 7.

## 10. APIs confirmed 2026-08-23

`Quickshell.Services.Polkit` → `PolkitAgent` with `isRegistered`, `path` (default
`/org/quickshell/Polkit`), `isActive`, `flow`. `AuthFlow` with `message`, `actionId`,
`iconName`, `identities`, `cookie`, `submit(password)`, `cancel()`.

**Present in v0.3.0 and master; absent from v0.2.0** — see §1.1.
Unverified: retry/attempt reporting, subject exposure (§9 items 2–3).
