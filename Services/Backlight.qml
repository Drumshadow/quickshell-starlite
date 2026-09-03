pragma Singleton
import QtQuick
import Quickshell.Io

// Display brightness. Callers do NOT know whether this is sysfs, D-Bus,
// brightnessctl or Solid — that is the entire point of this file.
//
// Real backend: org.kde.Solid.PowerManagement's BrightnessControl over the session
// bus, NOT brightnessctl and NOT sysfs — reusing Plasma's service keeps its OSD and
// power profile in agreement with ours (docs: cc §2). Verified on the StarLite
// 2026-09-03: `brightness` 3838 / `brightnessMax` 10000 matches acpi_video0 39/100.
// `busctl` (systemd) is the only tool used, so nothing extra has to be installed.
QtObject {
    id: root
    readonly property real value: Env.mock ? Mock.brightness : _real

    readonly property string _svc: "org.kde.Solid.PowerManagement"
    readonly property string _path: "/org/kde/Solid/PowerManagement/Actions/BrightnessControl"
    readonly property string _iface: "org.kde.Solid.PowerManagement.Actions.BrightnessControl"

    property int _max: 0
    property int _cur: -1
    readonly property bool available: !Env.mock && _max > 0 && _cur >= 0
    readonly property real _real: (_max > 0 && _cur >= 0) ? Math.max(0.01, Math.min(1, _cur / _max)) : 0.7

    // Our own writes come straight back as brightnessChanged; treat that as
    // confirmation, not as a second change (would double-fire the OSD).
    property int _pending: -1

    function _parseInt(text) {
        // busctl call prints e.g. "i 3838"; busctl monitor --json=short prints
        // {"type":"signal",...,"payload":{"data":[3838]}}. Take the last integer.
        const m = String(text).match(/(\d+)(?!.*\d)/)
        return m ? parseInt(m[1], 10) : -1
    }

    property var _readMax: Process {
        command: ["busctl", "--user", "call", root._svc, root._path, root._iface, "brightnessMax"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: { const v = root._parseInt(this.text); if (v > 0) root._max = v } }
    }
    property var _readCur: Process {
        command: ["busctl", "--user", "call", root._svc, root._path, root._iface, "brightness"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: { const v = root._parseInt(this.text); if (v >= 0) root._cur = v } }
    }
    // Live updates from any source (keys, Plasma's own slider, night light, us).
    property var _monitor: Process {
        command: ["busctl", "--user", "monitor", "--json=short",
                  "--match", "type='signal',interface='" + root._iface + "',member='brightnessChanged'"]
        running: !Env.mock
        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("brightnessChanged") < 0) return
                const v = root._parseInt(line)
                if (v < 0) return
                if (v === root._pending) { root._pending = -1; root._cur = v; return }
                root._cur = v
            }
        }
    }
    property var _writer: Process {
        stdout: StdioCollector {}
    }

    function setValue(v) {
        v = Math.max(0.01, Math.min(1, v))
        if (Env.mock) { Mock.brightness = v; return }
        if (_max <= 0) return
        const target = Math.round(v * _max)
        if (target === _cur) return
        _pending = target
        _cur = target                              // optimistic: slider stays put
        _writer.command = ["busctl", "--user", "call", _svc, _path, _iface, "setBrightnessSilent", "i", String(target)]
        _writer.running = true
    }
}
