# Status capsule — implementation spec

The right-hand zone of the `expanded` island (§1.2) and the question of what, if anything,
appears at `rest` (§1.1) — `~/specs/quickshell-starlite-rice.md`.

**Status:** spec only, unbuilt. Written 2026-08-23, no hardware.
**Target:** StarLite tablet, Fedora 44 KDE, Quickshell/QML.

---

## 0. A correction to the parent and island-core

Earlier notes described the collapsed pill as containing "a signal-strength glyph and the time".
**That was wrong.** Frames extracted at 00:44, 00:47 and 00:50 show the glyph beside the clock at
**different bar heights in each frame** — it is animating. Combined with [00:40]:

> "At rest, the island is just this collapsed pill below the top edge, **the clock**… and when
> music's playing these little accent EQ bars, they are dancing next to the time. If I were to
> pause the music, they disappear."

So that glyph is the **EQ bars** (media §5), not a signal meter.

> **At rest there is no status information at all.** Just the time, plus EQ bars while something
> plays. Battery and network appear only once the island is expanded.

`quickshell-island-core.md` §6 has been amended. This matters because it changes what §1 has to
decide.

---

## 1. Should the tablet break from this?

On the source's desktop, showing nothing but a clock at rest is elegant restraint. On this
device it deserves a second look, because **removing Plasma's panel (parent §6.6) removes the
only other place battery is displayed.** Checking charge would mean a deliberate tap or drag
every time.

**Recommendation: show battery at rest only when it is worth interrupting for.**

| Condition | At rest |
|---|---|
| Battery > 25%, discharging | clock only — as the source |
| Battery ≤ 25% | battery glyph + percentage appears |
| Charging / charge state changed | battery glyph, briefly, then fades |

This keeps the restraint at the times it costs nothing and surfaces the information exactly
when it matters. A permanent battery indicator is the obvious alternative and is defensible on a
tablet — **decide on hardware**, once you know how often you actually reach for it (§11 q1).

Whatever is chosen, the pill's tap target stays ≥48 px regardless of its visual width
(island-core §6, settings §4).

---

## 2. The capsule, as built

From the frames at 02:05 and 02:12: the `expanded` island's right zone is a **distinct rounded
container** — its own surface tint, inset within the island — holding two glyphs:

```
┌──────────────────────────────────────────────────────────┐
│ [art] ıl  IRIS OUT      23:47       ┌──────────────┐     │
│           Kenshi Yonezu Sun, Jun 7  │  📶    [80]  │     │
│                                     └──────────────┘     │
└──────────────────────────────────────────────────────────┘
   left zone (media §8)    centre        status capsule
```

- **Wi-Fi glyph** doubling as a signal meter
- **Battery** with the percentage rendered *inside* the cell

That is all. It is a container, not a bar — it does not grow with more indicators, and §6 is
about keeping it that way.

---

## 3. Data sources

| Element | Backend | Native? |
|---|---|---|
| Battery | `Quickshell.Services.UPower` | ✅ native |
| Wi-Fi | `Quickshell.Networking` | ✅ native *(corrected 2026-08-24)* |

Both glyphs come from the shared icon library and are two of its four **stateful** icons
(`quickshell-icons.md` §4) — the ones that encode a value and therefore had to be hand-authored.
This spec owns their *data*; the icon spec owns their *geometry*.

---

## 4. Battery — and the charge-cap trap

States to handle: discharging · charging · **plugged in at a charge cap** · full · low ·
critical · no battery.

> **The trap this hardware will hit.** The source's device sits pinned at 80% [12:44]: *"it
> basically just stays stuck at 80%, which is good for the battery life."* Many laptops and
> tablets expose a charge threshold, and the StarLite plausibly does.
>
> Two consequences:
> 1. **Do not treat 100% as the only "full".** The fill maths must not imply the battery is
>    broken because it never reaches the end of the cell.
> 2. **Do not animate a charging bolt forever.** Plugged in *and at the cap* is not charging.
>    UPower distinguishes these states — read the state, do not infer it from
>    `percentage < 100 && onAC`.

Charging shows the bolt with a `success` tint (theming §2). Low and critical shift the fill to
`critical`. The percentage-inside-the-cell legibility problem — digits flipping colour at the
fill boundary — is solved in `quickshell-icons.md` §4 and not re-litigated here.

UPower also exposes **time-to-empty / time-to-full**, which is genuinely useful on a tablet and
which the source does not show. Not in the capsule (no room); a candidate for the control centre.

---

## 5. Wi-Fi — quantise before you render

The glyph fills by signal strength, so it needs `Strength` from NetworkManager's active access
point. Two things matter:

- **Quantise to the four bars before binding.** NetworkManager emits strength changes
  constantly as the figure wobbles by a few percent; binding the raw value re-renders and
  re-animates a `Shape` for changes nobody can see. Map to buckets, and only animate when the
  *bucket* changes.
- **A disconnected state distinct from "connected, zero bars"** — they mean different things and
  the icon spec requires both (icons §4).

Wired and no-network states also need glyphs, even if this device is unlikely to see Ethernet.

---

## 6. Deliberate omissions — and one real gap

Not in the capsule, on purpose: Bluetooth, volume (that is the OSD), CPU/RAM/temperature — this
design contains **no system monitor at all** — and notification count.

Resist adding to the capsule. It is two glyphs in a small container; a third makes it a status
bar, and the whole design exists to not be one. The control centre is where additional status
belongs.

### The gap: there is no system tray
`Quickshell.Services.SystemTray` exists; **this design uses nothing from it.** On the source's
setup that is a choice. Here it is a consequence worth stating plainly:

> **Removing Plasma's panel removes the system tray, and nothing in this design replaces it.**
> Applications that "close to tray" — chat clients, sync agents, VPN clients — will have nowhere
> to go and may become unreachable once their window is closed.

That is a functional regression from stock Plasma, not a cosmetic one. Options, in order of
preference:

1. **A tray section in the control centre.** Off the critical path, has room, keeps the capsule
   clean. **Specced: `~/specs/quickshell-system-tray.md`** — and unlike notifications or polkit
   it needs no gate, because StatusNotifierItem allows multiple *hosts*.
2. Keep a thin Plasma panel on another edge purely for the tray — ugly, but zero work.
3. Accept it, and only run applications that do not need a tray.

**Decide before daily-driving** (§11 q3). It is the kind of thing that is invisible for a week
and then blocks something. Option 1 is now written up in full.

---

## 7. Update cadence

- **Signal-driven throughout.** UPower and NetworkManager both emit D-Bus property changes;
  never poll either.
- **Quantise Wi-Fi strength** (§5) so the underlying churn does not reach the renderer.
- The capsule is only drawn in `expanded`, so **animate transitions only while visible** —
  keeping subscriptions alive is cheap, re-animating a hidden `Shape` is not.
- Battery percentage changes slowly; there is no case for a timer anywhere in this component.

---

## 8. Consumer contract

```
battery.percentage   : int
battery.state        : Discharging | Charging | AtCap | Full | Low | Critical | None
battery.timeToEmpty  : int | null        → control centre, not the capsule
network.type         : Wifi | Wired | None
network.strength     : 0-4  (quantised, §5)
network.ssid         : string
```

Consumers bind to this shape; the icon components take `value`/`state` and know nothing about
UPower or NetworkManager (icons §6).

---

## 9. Build order

1. UPower battery → percentage and state, logged only.
2. Battery glyph in the `expanded` capsule, including the cap and charging states (§4).
3. NetworkManager over D-Bus → strength, quantised (§5). Wi-Fi glyph.
4. Disconnected and no-battery edge states.
5. The §1 rest-state decision, once you have used the tablet enough to know.
6. Tray decision (§6) — separately, and only if daily-driving.

Steps 1–2 pair naturally with `quickshell-icons.md` step 5, which builds the battery glyph.

---

## 10. Acceptance criteria

- [ ] At rest, the pill shows the clock only — plus EQ bars while playing, and nothing else (§0)
- [ ] Battery reaching a charge cap shows **neither** a permanent charging bolt **nor** a fill implying a fault (§4)
- [ ] Unplugging at the cap transitions cleanly to discharging
- [ ] Wi-Fi glyph animates only when the **bucket** changes, not on every strength signal (§5)
- [ ] Disconnected renders distinctly from connected-at-zero-bars
- [ ] No battery present (if ever run on a desktop) degrades to no glyph, not a zero reading
- [ ] Nothing in this component polls; no timers exist (§7)
- [ ] Capsule still contains exactly two glyphs (§6)
- [ ] Legible in `e-ink`, including the `critical` low-battery fill on a light surface
- [ ] Tray decision recorded in §11 q3 with a date

## 11. Open questions

1. **Permanent battery at rest, or the §1 threshold behaviour?** Decide after a week on the
   hardware. The threshold version is the recommendation; a tablet may argue otherwise.
2. Does the StarLite expose a charge threshold, and does UPower report it distinguishably from
   "charging"? (§4) Check early — it changes the state machine, not just the display.
3. **System tray — which of §6's three options?** Blocks daily-driving, not building.
4. Is there an ambient light sensor worth surfacing? Only if it drives auto-brightness
   surprisingly (osd §12 q5).
5. Should tapping the capsule open the control centre? It is a natural target and currently
   inert. Cheap, and it adds a second touch path to `control`.

## 12. APIs

`Quickshell.Services.UPower` (v0.2.0, confirmed) — battery and power statistics.
`Quickshell.Services.SystemTray` and `Quickshell.DBusMenu` (v0.2.0, confirmed) — **unused
today**; relevant only to §6 option 1.
NetworkManager over `org.freedesktop.NetworkManager` — **no Quickshell module exists**; confirm
interface and signal names on hardware.
Glyph geometry: `quickshell-icons.md` §4.
