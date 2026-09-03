pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// settings §4/§7: two numbers, clamped so the UI can never be made unreadable,
// atomically persisted. Theme + wallpaper are NOT stored here (theming §9).
QtObject {
    id: root
    readonly property int barMin: 24
    readonly property int barMax: 64
    readonly property int fontMin: 10
    readonly property int fontMax: 28

    property int barHeight: 30
    property int fontSize:  16

    // Share of the screen height the on-screen keyboard covers when it is up.
    // Plasma Keyboard does not report Qt.inputMethod.keyboardRectangle on this
    // stack (OSK probe, 2026-09-03: 0x0 with the keyboard drawn), so the launcher
    // sizes against this instead when oskNeeded. Measured on the StarLite in
    // landscape 2026-09-03: keyboard top at 948 of 1440 px = 0.34. Calibration
    // slider later.
    property real oskFraction: 0.35

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function setBar(v)  { barHeight = clamp(Math.round(v), barMin, barMax) }
    function setFont(v) { fontSize  = clamp(Math.round(v), fontMin, fontMax) }

    // TODO(hardware): persist via FileView — unverified type name, launcher §13 q5.
    // Fallback is a Process write. Load must re-clamp (settings §7).
}
