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
// logoutAndShutdown. Suspend goes to logind directly.
//
// LOCK is ours (Lock/LockScreen.qml, ext-session-lock via WlSessionLock).
// `lock()` raises it directly rather than through `loginctl lock-session`,
// because kscreenlocker (inside kwin_wayland) also answers logind's Lock
// signal and two lockers racing for ext-session-lock is undefined
// (lock-greeter §3.2). Recovery route, from SSH, no folio needed:
//   sudo loginctl unlock-session 2      -> logind Unlock -> we set locked=false
// and if the shell itself died while locked: restart the user service, then
//   qs ipc -c ~/quickshell-starlite call lock lock && sudo loginctl unlock-session 2
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

    // logind Unlock (from `loginctl unlock-session`) is the recovery path: it
    // always unlocks, no password. Broadcast signals need no privilege to watch.
    property var _unlockWatch: Process {
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        running: !Env.mock
        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("org.freedesktop.login1.Session.Unlock") >= 0) root.unlockedByLogind()
            }
        }
    }
    signal unlockedByLogind()

    // Lock/LockScreen.qml's wrong-password IPC exists only when this file was
    // present at startup (dev probe); delete the file and restart to close it.
    property bool lockDevMode: false
    property var _devProbe: Process {
        command: ["sh", "-c", "test -f \"$HOME/.config/quickshell-starlite/lock-dev\" && echo yes || echo no"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root.lockDevMode = String(this.text).indexOf("yes") >= 0 }
    }

    function _do(action) {
        lastAction = action
        if (Env.mock) {
            if (action === "lock") Mock.locked = true
            return                      // never actually act in mock mode
        }
        if (action === "lock") { _realLocked = true; lastResult = "lock:0"; return }
        if (_proc.running) return       // one session action at a time
        _proc.command = _commands[action]
        _proc.running = true
    }
    function lock()     { _do("lock") }
    // only the locker calls this, after PAM success or logind Unlock
    function _unlock()  { if (Env.mock) Mock.locked = false; else _realLocked = false }
    function suspend()  { _do("suspend") }
    function logout()   { _do("logout") }
    function reboot()   { _do("reboot") }
    function poweroff() { _do("poweroff") }
}
