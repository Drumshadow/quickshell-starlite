pragma Singleton
import QtQuick
import Quickshell.Io

// Night light. KWin owns it (org.kde.KWin /org/kde/KWin/NightLight): `running`
// is the truth we display. The D-Bus interface has no "turn on now" — `preview`
// times out and `enabled` is read-only (it mirrors kwinrc) — so the toggle
// writes kwinrc [NightColor] Active + Mode=Constant and asks KWin to
// reconfigure. Constant mode is deliberate: this tile means "warm the screen
// now", not "follow a schedule". Verified 2026-09-03: available=true,
// enabled=false out of the box, so there is no user schedule to clobber.
QtObject {
    id: root
    readonly property bool available: !Env.mock && _available
    readonly property bool running: Env.mock ? false : _running

    property bool _available: false
    property bool _running: false
    property string lastResult: ""

    readonly property string _svc: "org.kde.KWin"
    readonly property string _path: "/org/kde/KWin/NightLight"
    readonly property string _iface: "org.kde.KWin.NightLight"

    function _bool(text) { return String(text).indexOf("true") >= 0 }

    property var _readAvail: Process {
        command: ["busctl", "--user", "get-property", root._svc, root._path, root._iface, "available"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root._available = root._bool(this.text) }
    }
    property var _readRunning: Process {
        command: ["busctl", "--user", "get-property", root._svc, root._path, root._iface, "running"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root._running = root._bool(this.text) }
    }
    property var _monitor: Process {
        command: ["busctl", "--user", "monitor", "--json=short",
                  "--match", "type='signal',path='" + root._path + "',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"]
        running: !Env.mock
        stdout: SplitParser {
            onRead: (line) => {
                // {"payload":{"data":["org.kde.KWin.NightLight",{"running":{"type":"b","data":true}},[]]}}
                if (line.indexOf('"running"') < 0) return
                var m = line.match(/"running":\{"type":"b","data":(true|false)\}/)
                if (m) root._running = (m[1] === "true")
            }
        }
    }

    // write config, then reconfigure -- one shell so the order is guaranteed
    property var _apply: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (code) { root.lastResult = "night:" + code; root._readRunning.running = true }
    }
    function set(on) {
        if (Env.mock || _apply.running) return
        _apply.command = ["sh", "-c",
            "kwriteconfig6 --file kwinrc --group NightColor --key Active " + (on ? "true" : "false") +
            (on ? " && kwriteconfig6 --file kwinrc --group NightColor --key Mode Constant" : "") +
            " && busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure"]
        _apply.running = true
    }
    function toggle() { set(!running) }
}
