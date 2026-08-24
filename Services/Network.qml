pragma Singleton
import QtQuick
import Quickshell.Networking

// Wi-Fi / wired. `Quickshell.Networking` is native — an earlier note here
// wrongly claimed no module existed (docs/QUICKSHELL-NOTES.md §13).
QtObject {
    id: root
    readonly property var _devices: Networking.devices ? Networking.devices.values : []
    readonly property var _wifi: {
        for (var i = 0; i < _devices.length; i++) {
            var d = _devices[i]
            if (d && d.type === DeviceType.Wifi) return d
        }
        return null
    }
    readonly property var _wired: {
        for (var i = 0; i < _devices.length; i++) {
            var d = _devices[i]
            if (d && d.type === DeviceType.Ethernet) return d
        }
        return null
    }

    readonly property bool available: Env.mock ? true : (_devices.length > 0)
    readonly property bool enabled:
        Env.mock ? Mock.wifiEnabled : Networking.wifiEnabled
    readonly property bool connected:
        Env.mock ? Mock.wifiConnected
                 : ((_wifi && _wifi.connected) || (_wired && _wired.connected) || false)
    readonly property string ssid:
        Env.mock ? Mock.ssid : (_wifi && _wifi.name ? _wifi.name : "")
    readonly property string type:
        !connected ? "none" : (_wired && _wired.connected ? "wired" : "wifi")

    // TODO(hardware): per-AP signal strength. Confirm what Networking exposes on
    // the real machine; quantise HERE regardless — NM churns constantly and a raw
    // binding re-animates a Shape for changes nobody can perceive.
    readonly property int strength:
        Env.mock ? Mock.wifiStrength : (connected ? 4 : 0)

    function quantise(pct) {
        if (pct <= 0) return 0
        if (pct < 30) return 1
        if (pct < 55) return 2
        if (pct < 80) return 3
        return 4
    }
    function setEnabled(on) {
        if (Env.mock) { Mock.wifiEnabled = on; return }
        Networking.wifiEnabled = on
    }
}
