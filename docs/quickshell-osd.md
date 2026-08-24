# On-screen displays (volume / brightness) — implementation spec

Component §1.4 of `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Plasma/KWin (parent §6), Quickshell/QML.

The smallest interactive-feeling component in the design and a good **first** one to build:
it exercises the island's morph, the shared icon system and a live service binding, with no
text entry, no D-Bus name to claim and no security surface.

**Shares with other components:**
- The stateful volume/brightness icons are used by the control centre's sliders
  (`~/specs/quickshell-control-center.md` §7). **This spec owns their state machines** (§6);
  the control centre consumes them. Draw them once.
- Backends are the same ones the control centre uses (§4).

---

## 1. The conflict — Plasma draws these too

Deferred here from control-centre §13 q2. KWin handles the hardware volume/brightness keys
and **plasmashell already renders its own OSD** for them. Build this without addressing that
and every volume press produces two on-screen displays.

Lower stakes than the notification gate — this is duplication, not lost function, and
nothing breaks if you get it wrong. Try, in order:

```bash
# 1. plasmashell's OSD toggle — verify the group/key on hardware, this is unconfirmed
kwriteconfig6 --file plasmashellrc --group OSD --key Enabled false
# then restart plasmashell, or log out/in
# revert: same command with `true`, or --delete the key
```

If no supported switch exists, the fallback is honest and cheap: **do not build this
component.** Plasma's OSD already works; the loss is purely that it does not look like the
island. Nothing else in the shell depends on §1.4. Decide before step 4 of §10.

> Note the asymmetry worth remembering across these specs: notifications are gated on a name
> you may not be able to take; polkit on a unit that stops cleanly; **OSDs on a config key
> that may not exist.** Three different kinds of coexistence problem with plasmashell.

---

## 2. Architecture — event-driven, not keypress-driven

One `PanelWindow`, mapped for the session, never unmapped (KWin 503121, parent §6.5). The
OSD is `island.state === "osd"`.

> **The important decision: bind to the *service*, not to the key.**
>
> The naive build binds a global shortcut to "raise volume, then show OSD". That breaks for
> every other source of change — the control-centre slider, `pavucontrol`, an app adjusting
> its own stream, power management auto-dimming, the ambient light sensor.
>
> Instead, watch `Pipewire.defaultAudioSink`'s volume and mute, and Solid's brightness
> signal, and show the OSD **whenever the value changes, whatever changed it.** The OSD then
> works for sources you never explicitly wired up, including ones added later.

`keyboardFocus` stays `None` — the OSD is display-only (§9).

---

## 3. Contention — the third rule

Same one island, and each component answers this differently. The full set, worth keeping
side by side:

| Component | On surface conflict |
|---|---|
| Notifications | **Never** preempt — suppress and log to history |
| Polkit | **Always** preempt — restore prior state after |
| **OSD** | **Preempt `rest` and `notification` — never a panel** |

The reason is concrete: if the control centre is open and you are **dragging its volume
slider**, morphing the island into an OSD would destroy the panel your finger is on. The
slider is already the feedback; a second indicator is worse than none.

So: if a **user panel** is open, update the underlying value and draw no OSD. This covers the
launcher (adjusting volume mid-search must not eat the query) and the auth card (never
interrupt authentication).

> **Refined by `quickshell-island-core.md` §3.1.** An earlier draft said "only from `rest`",
> which would let a passive notification toast block the OSD. It should not: pressing volume-up
> is a direct response to a user action and outranks an unsolicited toast, which returns to
> history. The canonical matrix lives in the island-core spec.

---

## 4. Backends

| OSD | Source | Native? |
|---|---|---|
| Volume | `Quickshell.Services.Pipewire` — `defaultAudioSink`, its volume and mute | ✅ native |
| Brightness | `org.kde.Solid.PowerManagement` over D-Bus — its brightness-changed signal | ❌ D-Bus |

Brightness deliberately reuses Plasma's service rather than `brightnessctl`, for the reason
given in control-centre §2: Plasma's own state, its power profile and your display stay in
agreement. Confirm the exact interface and signal names on hardware with `qdbus`/`busctl`.

---

## 5. Visual

From the source frames (volume @ 02:55, brightness @ 03:15): a **compact pill**, narrower
than the expanded island and much narrower than the control centre — icon at the left, accent
fill bar across the middle, percentage right-aligned in dim text.

```
┌──────────────────────────────────────┐
│ 🔊  ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░    51%   │
└──────────────────────────────────────┘
```

- Same corner radius, shadow and surface colour as the collapsed pill — it must read as the
  *same object* changing shape, not a different widget appearing
- Fill uses the active accent; **muted dims the bar** (source is explicit)
- Percentage in tabular figures so the pill does not jitter as digits change
- Width is fixed — do not size to content, or the pill visibly breathes while dragging

---

## 6. The stateful icons — owned here

Parent §1.3's rule: hand-drawn QML vector shapes, no icon font, tinted from the active
accent. These two are **stateful** — they encode the value, not just the category — which is
the detail that makes the design feel considered:

**Volume**
| State | Glyph |
|---|---|
| muted | speaker with ✕ (and the bar dims) |
| 0 < v ≤ ~50% | speaker with **one** wave |
| v > ~50% | speaker with **two** waves |

**Brightness** — a sun whose rays lengthen/brighten continuously with level. Continuous, not
stepped: drive ray length from the value directly.

Both must animate *between* states rather than snapping, and both are consumed by the
control-centre sliders (§7 there). Build them as standalone components taking a
`value`/`muted` input, with no knowledge of the OSD.

Mute is a **separate state from volume 0** — do not infer one from the other.

---

## 7. Timing and animation

- **Auto-dismiss ~2.5 s**, raised from the source's ~1.5 s (parent §3.1.4) — on a tablet you
  are less likely to be looking at the top edge at the moment of change.
- **The timer resets on every value change.** Holding a volume key keeps the OSD up and
  refreshing; dismissal is 2.5 s after the *last* change, not the first.
- Fill animates on a critically damped spring (parent §1.15) with a **short** time constant —
  it must track rapid repeats responsively, not lag behind a held key.
- Dismissal "melts back into the clock" — morph the same surface back to `rest`, never fade
  a separate window out.

---

## 8. Edge cases — the suppression list

The bug that makes an event-driven OSD feel broken is showing up when nothing happened.
Suppress on all of:

- **Shell startup / initial property binding.** Binding to a volume property fires an initial
  change; do not treat it as user action. Arm the OSD only after the first value settles.
- **`Pipewire.ready` transitioning** — same reason.
- **Default sink change** (headphones plugged in, Bluetooth connecting). The value changes
  because the *device* changed, not because anyone asked. Re-baseline silently.
- **Resume from suspend**, where brightness and sink may both re-initialise.
- **Session locked** — the island sits below the lock surface and would be invisible anyway;
  do not run the timer. Feedback while locked belongs to the lock-screen component.

Volume above 100%: Pipewire permits over-amplification. Show the real number rather than
clamping, and tint the bar distinctly past 100% — it is clipping territory and worth seeing.

---

## 9. Deliberately display-only

Tempting on touch to make the bar draggable. **Do not, in v1.** It auto-dismisses after
2.5 s, so it is a control that vanishes while you reach for it — a bad affordance, and
undiscoverable besides. The control centre already has a real slider with a 48 px input
region (control-centre §7); that is the interactive path.

Possible v2: allow a drag that begins on a visible OSD to adjust, pausing dismissal while
held. Only worth it if the tablet turns out to lack hardware volume keys (§12 q1).

---

## 10. Build order

1. Island enters/exits `"osd"`; static placeholder pill; morph and auto-dismiss timing (§7).
2. Volume binding to Pipewire — value + mute. Verify it reacts to `pavucontrol`, not just to keys.
3. The suppression list (§8). **Before** wiring brightness — get one source completely right.
4. Decide the Plasma-OSD conflict (§1). Duplication is obvious the moment step 2 works.
5. Stateful volume icon (§6).
6. Brightness via Solid D-Bus + sun icon.
7. Hand both icons to control-centre §7.

Steps 1–3 make a complete, useful volume OSD. This is the recommended **first** component
of the whole shell — smallest surface, no gate that can lose data, and it proves the morph
architecture end to end.

---

## 11. Acceptance criteria

- [ ] Island never unmaps entering/leaving `"osd"` (503121 regression check)
- [ ] OSD appears for a volume change made in `pavucontrol` — proves §2's service binding
- [ ] OSD appears for the control centre's own slider only when the CC is **closed** (§3)
- [ ] Dragging the CC volume slider produces **no** OSD and does not disturb the panel
- [ ] Holding a volume key keeps the OSD up; it dismisses 2.5 s after the last change
- [ ] Mute shows speaker-✕ **and** dims the bar; unmuting at volume 0 still shows muted-vs-zero correctly
- [ ] Icon changes wave count across the threshold, animated not snapped
- [ ] **No OSD on shell start, on plugging in headphones, or on resume from suspend** (§8)
- [ ] Volume >100% displays the real figure with a distinct bar tint
- [ ] Percentage does not cause the pill to change width
- [ ] Plasma's own OSD either disabled or consciously accepted, recorded here with the date
- [ ] Legible in `e-ink` light scheme, including the dimmed muted state

## 12. Open questions

1. **Does the StarLite tablet body have hardware volume keys**, or only the folio? If
   folio-only, the OSD has much less value detached and §9's v2 drag becomes worth revisiting.
2. Is `plasmashellrc [OSD] Enabled` real on Plasma 6, or has it moved? (§1)
3. Does Solid's brightness signal fire for **automatic** dimming (idle, ambient light)? If so,
   auto-dim would pop an OSD unprompted — add it to §8's suppression list.
4. Does KWin's own OSD for keyboard-layout / touchpad-toggle share the same config switch, and
   do you want those suppressed too?
5. Ambient light sensor on this hardware — if present and driving brightness, q3 becomes
   important rather than theoretical.

## 13. APIs confirmed 2026-08-23

`Quickshell.Services.Pipewire` — `nodes`, `defaultAudioSink`, `defaultAudioSource`, `ready`
(present in v0.2.0).

Unverified: exact Pipewire volume/mute property paths on the sink node; the
`org.kde.Solid.PowerManagement` brightness interface and signal names; the plasmashell OSD
config key (§12 q2).
