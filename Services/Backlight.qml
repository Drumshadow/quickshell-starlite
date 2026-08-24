pragma Singleton
import QtQuick

// Display brightness. Callers do NOT know whether this is sysfs, D-Bus,
// brightnessctl or Solid — that is the entire point of this file.
QtObject {
    id: root
    readonly property real value: Env.mock ? Mock.brightness : _real

    // TODO(real): org.kde.Solid.PowerManagement over D-Bus, NOT brightnessctl
    // and NOT sysfs — reusing Plasma's service keeps its OSD and power profile
    // in agreement with ours (docs: cc §2).
    property real _real: 0.7

    function setValue(v) {
        v = Math.max(0.01, Math.min(1, v))
        if (Env.mock) Mock.brightness = v
        else _real = v                // TODO: D-Bus setBrightness
    }
}
