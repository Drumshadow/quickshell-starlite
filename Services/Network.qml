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
    // The connected WifiNetwork on the wifi device: its `name` is the SSID and
    // `signalStrength` the live AP strength. `_wifi.name` is the INTERFACE
    // (wlp0s20f3 on the StarLite), which is what the tile showed until 2026-09-03.
    readonly property var _active: {
        if (!_wifi || !_wifi.networks) return null
        var v = _wifi.networks.values
        for (var i = 0; i < v.length; i++) if (v[i] && v[i].connected) return v[i]
        return null
    }
    readonly property string ssid:
        Env.mock ? Mock.ssid : (_active && _active.name ? _active.name : "")
    readonly property string type:
        !connected ? "none" : (_wired && _wired.connected ? "wired" : "wifi")

    // Quantised HERE regardless of source -- NM churns constantly and a raw
    // binding re-animates a Shape for changes nobody can perceive. signalStrength
    // is a double; treat <=1 as a fraction, otherwise as a percentage.
    readonly property int strength:
        Env.mock ? Mock.wifiStrength
                 : (!connected ? 0
                    : (_active ? quantise(_active.signalStrength <= 1 ? _active.signalStrength * 100 : _active.signalStrength)
                               : 4))

    // ---- sub-view (control-center step 9) ----
    // Rows are the live WifiNetwork objects (name, connected, known, security,
    // signalStrength, stateChanging) or Mock.wifiNetworks with the same fields.
    // Sorted connected > known > name; NOT by strength, or rows reshuffle on
    // every dBm wobble while the user is aiming a finger at one.
    readonly property var networks: Env.mock ? Mock.wifiNetworks : _realNetworks
    readonly property var _realNetworks: {
        if (!_wifi || !_wifi.networks) return []
        var v = _wifi.networks.values, out = []
        for (var i = 0; i < v.length; i++) if (v[i] && v[i].name) out.push(v[i])
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.known !== b.known) return a.known ? -1 : 1
            return String(a.name).localeCompare(String(b.name))
        })
        return out
    }
    readonly property bool scanning: (!Env.mock && _wifi) ? _wifi.scannerEnabled : false
    function setScanning(on) { if (!Env.mock && _wifi) _wifi.scannerEnabled = on }

    function isOpen(n) {
        if (!n) return false
        if (Env.mock) return !n.secured
        return (typeof WifiSecurityType !== "undefined" && WifiSecurityType.None !== undefined)
               ? n.security === WifiSecurityType.None : false
    }
    function strengthOf(n) {
        if (!n) return 0
        var s = n.signalStrength
        return quantise(s <= 1 ? s * 100 : s)
    }
    function connectTo(n, psk) {
        if (!n) return
        if (Env.mock) {
            var list = Mock.wifiNetworks.slice()
            for (var i = 0; i < list.length; i++) {
                var c = list[i]
                list[i] = { name: c.name, known: c.known || c === n, secured: c.secured,
                            signalStrength: c.signalStrength, stateChanging: false,
                            connected: c === n }
            }
            Mock.wifiNetworks = list; Mock.wifiConnected = true; Mock.ssid = n.name
            return
        }
        if (psk && psk.length > 0) n.connectWithPsk(psk); else n.connect()
    }
    function disconnectFrom(n) {
        if (!n) return
        if (Env.mock) { Mock.preset("offline"); return }
        n.disconnect()
    }

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
