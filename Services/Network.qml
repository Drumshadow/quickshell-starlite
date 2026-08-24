pragma Singleton
import QtQuick

// Wi-Fi / wired state. Strength is QUANTISED here, not in the UI —
// NetworkManager emits constant small fluctuations and binding a raw value
// re-animates a Shape for changes nobody can perceive (docs: status-capsule §5).
QtObject {
    id: root
    readonly property bool enabled:   Env.mock ? Mock.wifiEnabled   : _realEnabled
    readonly property bool connected: Env.mock ? Mock.wifiConnected : _realConnected
    readonly property string ssid:    Env.mock ? Mock.ssid          : _realSsid
    readonly property int strength:   Env.mock ? Mock.wifiStrength  : quantise(_realStrengthRaw)
    readonly property string type: connected ? "wifi" : "none"

    // TODO(real): `Quickshell.Networking` — native, verified present on the
    // target (docs/QUICKSHELL-NOTES.md §13). An earlier note here claimed no
    // module existed and that raw D-Bus was required; that was wrong.
    // Quantise strength here regardless (§5) — NM churns constantly.
    property bool _realEnabled: true
    property bool _realConnected: false
    property string _realSsid: ""
    property int _realStrengthRaw: 0     // 0..100 from NM

    function quantise(pct) {
        if (pct <= 0)  return 0
        if (pct < 30)  return 1
        if (pct < 55)  return 2
        if (pct < 80)  return 3
        return 4
    }
    function setEnabled(on) { if (Env.mock) Mock.wifiEnabled = on; else _realEnabled = on }
}
