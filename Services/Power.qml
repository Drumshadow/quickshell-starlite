pragma Singleton
import QtQuick

// Battery + AC. Encodes the charge-cap distinction the StarLite is likely to
// need: "plugged in at the cap" is NOT charging, and 100% is not the only full.
QtObject {
    id: root
    readonly property int  percentage: Env.mock ? Mock.batteryPercent : _realPercent
    readonly property bool acConnected:       Env.mock ? Mock.acConnected           : _realAcConnected
    readonly property int  chargeCap:  Env.mock ? Mock.chargeCap      : _realCap
    readonly property int  timeToEmpty:Env.mock ? Mock.timeToEmpty    : _realTTE
    readonly property bool _charging:  Env.mock ? Mock.charging       : _realCharging

    // TODO(real): Quickshell.Services.UPower (native), plus the sysfs
    // charge_control_end_threshold for the cap. Read UPower's STATE — never
    // infer charging from `percentage < 100 && acConnected` (docs: status-capsule §4).
    property int  _realPercent: 100
    property bool _realAcConnected: true
    property bool _realCharging: false
    property int  _realCap: 100
    property int  _realTTE: 0

    // Discharging | Charging | AtCap | Full | Low | Critical | None
    readonly property string state: {
        if (percentage <= 0) return "None"
        if (_charging) return "Charging"
        if (acConnected && chargeCap < 100 && percentage >= chargeCap) return "AtCap"
        if (acConnected && percentage >= 100) return "Full"
        if (percentage <= 10) return "Critical"
        if (percentage <= 25) return "Low"
        return "Discharging"
    }
    readonly property bool low: state === "Low" || state === "Critical"
}
