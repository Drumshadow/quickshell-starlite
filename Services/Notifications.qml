pragma Singleton
import QtQuick
import Quickshell.Io

// Notifications -- AMBER fallback (docs: notifications §0). plasmashell owns
// org.freedesktop.Notifications on the StarLite (checked 2026-09-03), so Plasma
// keeps rendering toasts and history; the island shows no list and no count.
// Peace mode is therefore a proxy for Plasma's Do Not Disturb.
//
// Why config and not the Inhibit() D-Bus call: Plasma drops an inhibition the
// moment the calling bus name disappears, and a one-shot busctl disappears
// immediately. Plasma's own applet writes plasmanotifyrc [DoNotDisturb] Until=
// and the server watches that file, so we do the same. `Inhibited` on the bus
// is the read-back (it covers DND from any source).
// Re-enable by hand: kwriteconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until --delete
QtObject {
    id: root
    readonly property bool peaceMode: Env.mock ? Mock.peaceMode : _realPeace
    readonly property int count:      Env.mock ? Mock.notificationCount : _realCount
    readonly property bool needsAttention: Env.mock ? Mock.needsAttention : _realAttention

    property bool _realPeace: false
    property int _realCount: 0
    property bool _realAttention: false
    property string lastResult: ""

    readonly property string _svc: "org.freedesktop.Notifications"
    readonly property string _path: "/org/freedesktop/Notifications"
    readonly property string _iface: "org.freedesktop.Notifications"

    property var _readInhibited: Process {
        command: ["busctl", "--user", "get-property", root._svc, root._path, root._iface, "Inhibited"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root._realPeace = String(this.text).indexOf("true") >= 0 }
    }
    property var _monitor: Process {
        command: ["busctl", "--user", "monitor", "--json=short",
                  "--match", "type='signal',path='" + root._path + "',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"]
        running: !Env.mock
        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf('"Inhibited"') < 0) return
                var m = line.match(/"Inhibited":\{"type":"b","data":(true|false)\}/)
                if (m) root._realPeace = (m[1] === "true")
            }
        }
    }
    property var _apply: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (code) { root.lastResult = "peace:" + code; root._readInhibited.running = true }
    }

    function setPeace(on) {
        if (Env.mock) { Mock.peaceMode = on; return }
        if (_apply.running) return
        _apply.command = on
            ? ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until", "2099-01-01T00:00:00"]
            : ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until", "--delete"]
        _apply.running = true
    }
}
