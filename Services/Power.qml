pragma Singleton
import QtQuick
import Quickshell.Services.UPower

// Battery + AC. Encodes the charge-cap distinction: "plugged in at the cap" is
// NOT charging, and 100% is not the only full.
QtObject {
    id: root
    readonly property var _dev: UPower.displayDevice
    readonly property bool _present: _dev !== null && _dev !== undefined && _dev.isPresent

    readonly property bool available: Env.mock ? true : _present

    readonly property int percentage:
        Env.mock ? Mock.batteryPercent : (_present ? Math.round(_dev.percentage) : 0)
    readonly property bool acConnected:
        Env.mock ? Mock.acConnected : !UPower.onBattery
    readonly property int timeToEmpty:
        Env.mock ? Mock.timeToEmpty : (_present ? Math.round(_dev.timeToEmpty) : 0)
    readonly property int chargeCap:
        Env.mock ? Mock.chargeCap : _realCap

    // TODO(hardware): read charge_control_end_threshold. Not exposed by UPower,
    // and a sysfs read is the one place a tiny helper may be justified. Verify
    // on the StarLite whether it even has a threshold (day-one check §A5).
    property int _realCap: 100

    // Read UPower's STATE; never infer charging from percentage+AC.
    readonly property bool _charging:
        Env.mock ? Mock.charging
                 : (_present && _dev.state === UPowerDeviceState.Charging)
    readonly property bool _full:
        !Env.mock && _present && _dev.state === UPowerDeviceState.FullyCharged

    // Discharging | Charging | AtCap | Full | Low | Critical | None
    readonly property string state: {
        if (!available || percentage <= 0) return "None"
        if (_charging) return "Charging"
        if (_full) return "Full"
        if (acConnected && chargeCap < 100 && percentage >= chargeCap) return "AtCap"
        if (acConnected && percentage >= 100) return "Full"
        if (percentage <= 10) return "Critical"
        if (percentage <= 25) return "Low"
        return "Discharging"
    }
    readonly property bool low: state === "Low" || state === "Critical"
}
