pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Services" as Sys

// settings §4/§7: two numbers (plus the OSK fraction), clamped so the UI can
// never be made unreadable, persisted atomically to
// ~/.config/quickshell-starlite/settings.json. Theme + wallpaper are NOT stored
// here (theming §9, wallpaper §2 -- wallust and Plasma persist those).
// Load re-clamps, so a hand-edited or corrupt file cannot produce a 2 px font.
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
    // landscape 2026-09-03: keyboard top at 948 of 1440 px = 0.34.
    property real oskFraction: 0.35

    readonly property string path: Quickshell.env("HOME") + "/.config/quickshell-starlite/settings.json"
    property bool loaded: false

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function setBar(v)  { barHeight = clamp(Math.round(v), barMin, barMax); _save() }
    function setFont(v) { fontSize  = clamp(Math.round(v), fontMin, fontMax); _save() }
    function setOsk(v)  { oskFraction = clamp(v, 0.2, 0.6); _save() }

    property var _file: FileView {
        path: root.path
        atomicWrites: true
        onLoaded: root._load()
        onLoadFailed: function (err) { root.loaded = true }     // no file yet: defaults stand
        JsonAdapter {
            id: st
            property int barHeight: 30
            property int fontSize: 16
            property real oskFraction: 0.35
        }
    }
    function _load() {
        if (Sys.Env.mock) return
        barHeight   = clamp(Math.round(st.barHeight), barMin, barMax)
        fontSize    = clamp(Math.round(st.fontSize), fontMin, fontMax)
        oskFraction = clamp(st.oskFraction, 0.2, 0.6)
        loaded = true
    }
    function _save() {
        if (Sys.Env.mock) return
        st.barHeight = barHeight; st.fontSize = fontSize; st.oskFraction = oskFraction
        _file.writeAdapter()
    }
}
