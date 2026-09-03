pragma Singleton
import QtQuick
import Quickshell.Io

// Lock / suspend / logout / reboot / poweroff.
//
// The presentation layer must never call systemctl. The graceful KDE interface
// runs Plasma's application-save handshake and honours logind inhibitors; the
// hard systemctl equivalents do neither, and that difference costs unsaved work
// (docs: power-menu §1). Verified present on the StarLite 2026-09-03:
// org.kde.Shutdown at /Shutdown exposes logout / logoutAndReboot /
// logoutAndShutdown. Lock goes through loginctl so PowerDevil's idle lock and
// ours are the same path; suspend goes to logind directly.
QtObject {
    id: root
    readonly property bool locked: Env.mock ? Mock.locked : _realLocked
    readonly property bool idle:   Env.mock ? Mock.idle   : _realIdle

    property bool _realLocked: false
    property bool _realIdle: false

    // last action requested, so mock mode can show what WOULD have happened
    property string lastAction: ""
    // for the health IPC: "<action>:<exit code>" of the last real run
    property string lastResult: ""

    readonly property var _commands: ({
        "lock":     ["loginctl", "lock-session"],
        "suspend":  ["busctl", "--system", "call", "org.freedesktop.login1", "/org/freedesktop/login1",
                     "org.freedesktop.login1.Manager", "Suspend", "b", "false"],
        "logout":   ["busctl", "--user", "call", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logout"],
        "reboot":   ["busctl", "--user", "call", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndReboot"],
        "poweroff": ["busctl", "--user", "call", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndShutdown"]
    })

    property var _proc: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (code) { root.lastResult = root.lastAction + ":" + code }
    }

    function _do(action) {
        lastAction = action
        if (Env.mock) {
            if (action === "lock") Mock.locked = true
            return                      // never actually act in mock mode
        }
        if (_proc.running) return       // one session action at a time
        _proc.command = _commands[action]
        _proc.running = true
    }
    function lock()     { _do("lock") }
    function suspend()  { _do("suspend") }
    function logout()   { _do("logout") }
    function reboot()   { _do("reboot") }
    function poweroff() { _do("poweroff") }
}
