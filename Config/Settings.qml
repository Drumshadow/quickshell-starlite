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

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function setBar(v)  { barHeight = clamp(Math.round(v), barMin, barMax) }
    function setFont(v) { fontSize  = clamp(Math.round(v), fontMin, fontMax) }

    // TODO(hardware): persist via FileView — unverified type name, launcher §13 q5.
    // Fallback is a Process write. Load must re-clamp (settings §7).
}
