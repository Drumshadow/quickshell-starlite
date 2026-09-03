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

    // Read-back is the config file, not the bus: plasmashell's `Inhibited`
    // property only covers application Inhibit() calls, never DND (checked
    // 2026-09-03 -- stayed false with DND on). Plasma stores the deadline in
    // KConfig list form, "yyyy,M,d,h,m,s"; an ISO string is silently ignored.
    property var _readUntil: Process {
        command: ["kreadconfig6", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root._realPeace = root._inFuture(this.text) }
    }
    function _inFuture(text) {
        var parts = String(text).trim().split(",")
        if (parts.length < 3) return false
        var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10),
                         parseInt(parts[3] || "0", 10), parseInt(parts[4] || "0", 10), parseInt(parts[5] || "0", 10))
        return d.getTime() > Date.now()
    }
    property var _apply: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (code) { root.lastResult = "peace:" + code; root._readUntil.running = true }
    }
    // Plasma's own applet can flip DND too; refresh whenever the panel opens
    function refresh() { if (!Env.mock) _readUntil.running = true }

    function setPeace(on) {
        if (Env.mock) { Mock.peaceMode = on; return }
        if (_apply.running) return
        _apply.command = on
            ? ["kwriteconfig6", "--notify", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until", "2099,1,1,0,0,0"]
            : ["kwriteconfig6", "--notify", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until", "--delete"]
        _apply.running = true
    }
}
