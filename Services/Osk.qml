pragma Singleton
import QtQuick
import Quickshell.Io

// On-screen keyboard control. Callers never learn that this is KWin.
//
// Why this exists: on the StarLite (Plasma 6.7.4 + Plasma Keyboard) a TAP on a
// text field raises the keyboard, but neither programmatic focus nor
// Qt.inputMethod.show() does -- the launcher opens programmatically, so it would
// open keyboard-less. KWin exposes the keyboard on the session bus
// (org.kde.kwin.VirtualKeyboard at /VirtualKeyboard): forceActivate() shows it,
// and the writable `active` property hides it. Both verified 2026-09-03.
// Mock mode does nothing; a box with no KWin degrades to no-ops.
QtObject {
    id: root
    readonly property string _svc: "org.kde.KWin"
    readonly property string _path: "/VirtualKeyboard"
    readonly property string _iface: "org.kde.kwin.VirtualKeyboard"

    property var _show: Process {
        command: ["busctl", "--user", "call", root._svc, root._path, root._iface, "forceActivate"]
        stdout: StdioCollector {}
    }
    property var _hide: Process {
        command: ["busctl", "--user", "set-property", root._svc, root._path, root._iface, "active", "b", "false"]
        stdout: StdioCollector {}
    }

    function show() { if (Env.mock) return; _show.running = true }
    function hide() { if (Env.mock) return; _hide.running = true }
}
