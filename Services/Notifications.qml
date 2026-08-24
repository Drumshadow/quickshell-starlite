pragma Singleton
import QtQuick

QtObject {
    id: root
    readonly property bool peaceMode: Env.mock ? Mock.peaceMode : _realPeace
    readonly property int count:      Env.mock ? Mock.notificationCount : _realCount
    readonly property bool needsAttention: Env.mock ? Mock.needsAttention : _realAttention

    // TODO(real): Quickshell.Services.Notifications NotificationServer.
    // GATED: plasmashell owns org.freedesktop.Notifications and may not release
    // it (docs: notifications §0). Declare capabilities conservatively — no
    // body-markup in v1; body text is untrusted input (docs: notifications §3).
    property bool _realPeace: false
    property int _realCount: 0
    property bool _realAttention: false

    function setPeace(on) { if (Env.mock) Mock.peaceMode = on; else _realPeace = on }
}
