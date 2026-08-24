pragma Singleton
import QtQuick

// Screen orientation. Feeds InputMode; nothing else should read it directly.
QtObject {
    readonly property string orientation:
        Env.mock ? Mock.orientation : _real

    // TODO(hardware): iio-sensor-proxy over D-Bus
    //   net.hadess.SensorProxy / ClaimAccelerometer + AccelerometerOrientation
    // KWin may already handle rotation itself (docs: parent §3.3) — verify on
    // hardware whether the shell needs to know at all, or only needs to relayout.
    property string _real: "landscape"

    readonly property bool portrait: orientation === "portrait"
}
