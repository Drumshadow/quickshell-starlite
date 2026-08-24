pragma Singleton
import QtQuick

QtObject {
    id: root
    readonly property bool enabled: Env.mock ? Mock.btEnabled : _realEnabled
    readonly property var devices:  Env.mock ? Mock.btDevices : _realDevices
    readonly property int connectedCount: {
        var n = 0
        for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++
        return n
    }

    // TODO(real): Quickshell.Bluetooth (native BlueZ, top-level module — NOT
    // under Services in Quickshell's own namespace).
    property bool _realEnabled: false
    property var _realDevices: []

    function setEnabled(on) { if (Env.mock) Mock.btEnabled = on; else _realEnabled = on }
    function toggleDevice(i) {
        if (!Env.mock) return          // TODO: BlueZ connect/disconnect
        var d = Mock.btDevices.slice()
        d[i] = { name: d[i].name, connected: !d[i].connected }
        Mock.btDevices = d
    }
}
