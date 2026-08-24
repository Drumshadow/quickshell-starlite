pragma Singleton
import QtQuick

// Lock / suspend / logout / reboot / poweroff.
//
// The presentation layer must never call systemctl. The graceful KDE interface
// runs Plasma's application-save handshake and honours logind inhibitors; the
// hard systemctl equivalents do neither, and that difference costs unsaved work
// (docs: power-menu §1).
QtObject {
    id: root
    readonly property bool locked: Env.mock ? Mock.locked : _realLocked
    readonly property bool idle:   Env.mock ? Mock.idle   : _realIdle

    property bool _realLocked: false
    property bool _realIdle: false

    // last action requested, so mock mode can show what WOULD have happened
    property string lastAction: ""

    function _do(action) {
        lastAction = action
        if (Env.mock) {
            if (action === "lock") Mock.locked = true
            return                      // never actually act in mock mode
        }
        // TODO(real):
        //   lock     -> loginctl lock-session  (logind emits Lock; we listen)
        //   suspend  -> logind Suspend(false)
        //   logout   -> org.kde.Shutdown logout()
        //   reboot   -> org.kde.Shutdown logoutAndReboot()
        //   poweroff -> org.kde.Shutdown logoutAndShutdown()
    }
    function lock()     { _do("lock") }
    function suspend()  { _do("suspend") }
    function logout()   { _do("logout") }
    function reboot()   { _do("reboot") }
    function poweroff() { _do("poweroff") }
}
