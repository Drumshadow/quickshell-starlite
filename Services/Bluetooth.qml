pragma Singleton
import QtQuick
import Quickshell.Bluetooth

// Bluetooth over Quickshell's native BlueZ module (top-level `Quickshell.Bluetooth`,
// present in the 0.3.1 package on the StarLite: BluetoothAdapter.enabled, devices
// with name/deviceName/connected/paired and connect()/disconnect()).
//
// `devices` is the PAIRED list only — the control-centre sub-view is "my things",
// not a scanner. Rows are the live device objects, so `connected` in a delegate
// stays bound; the shape matches Mock.btDevices ({name, connected}).
QtObject {
    id: root
    readonly property var _adapter: Bluetooth.defaultAdapter
    readonly property bool available: !Env.mock && _adapter !== null && _adapter !== undefined

    readonly property bool enabled: Env.mock ? Mock.btEnabled : (available ? _adapter.enabled : false)
    readonly property var devices:  Env.mock ? Mock.btDevices : _realDevices
    readonly property int connectedCount: {
        var n = 0
        for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++
        return n
    }

    readonly property var _realDevices: {
        if (!Bluetooth.devices) return []
        var vals = Bluetooth.devices.values, out = []
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i]
            if (d && d.paired) out.push(d)
        }
        return out
    }

    function setEnabled(on) {
        if (Env.mock) { Mock.btEnabled = on; return }
        if (available) _adapter.enabled = on
    }
    function toggleDevice(i) {
        if (Env.mock) {
            var d = Mock.btDevices.slice()
            d[i] = { name: d[i].name, connected: !d[i].connected }
            Mock.btDevices = d
            return
        }
        var dev = _realDevices[i]
        if (!dev) return
        if (dev.connected) dev.disconnect(); else dev.connect()
    }
}
