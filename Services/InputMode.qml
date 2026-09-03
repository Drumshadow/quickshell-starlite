pragma Singleton
import QtQuick
import Quickshell.Io

// The adaptive-behaviour brain. UI components ask THIS what size to be and
// how to behave — they never test for "is this a StarLite".
//
// Everything here is derived, so a generic component stays generic:
//   width: InputMode.touchTarget      NOT   width: 48
pragma ComponentBehavior: Bound
QtObject {
    id: root

    // --- raw form-factor inputs ---
    readonly property bool tabletMode:
        Env.mock ? Mock.tabletMode : _realTabletMode
    readonly property bool keyboardAttached:
        Env.mock ? Mock.keyboardAttached : _realKeyboardAttached
    readonly property string orientation:
        Env.mock ? Mock.orientation : Orientation.orientation
    readonly property bool pointerFine:
        Env.mock ? Mock.pointerFine : _realPointerFine

    // Real source, decided on the StarLite 2026-09-03: KWin's TabletModeManager.
    // Plasma flips it on folio detach (the §2.1 premise), and it is exactly the
    // signal Plasma itself uses to decide scaling and the OSK -- so keyboard
    // presence and pointer fineness are derived from it rather than from
    // libinput, whose device list on this hardware shows an "AT Translated Set 2
    // keyboard" whether or not the folio is attached.
    property bool _realTabletMode: false
    readonly property bool _realKeyboardAttached: !_realTabletMode
    readonly property bool _realPointerFine: !_realTabletMode

    property var _tmRead: Process {
        command: ["busctl", "--user", "get-property", "org.kde.KWin", "/org/kde/KWin",
                  "org.kde.KWin.TabletModeManager", "tabletMode"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root._realTabletMode = this.text.indexOf("true") >= 0 }
    }
    property var _tmMonitor: Process {
        command: ["busctl", "--user", "monitor", "--json=short", "--match",
                  "type='signal',interface='org.kde.KWin.TabletModeManager',member='tabletModeChanged'"]
        running: !Env.mock
        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("tabletModeChanged") < 0) return
                if (line.indexOf('"data":[true]') >= 0) root._realTabletMode = true
                else if (line.indexOf('"data":[false]') >= 0) root._realTabletMode = false
            }
        }
    }

    // --- derived behaviour ---
    readonly property bool portrait: orientation === "portrait"
    readonly property bool touchFirst: tabletMode || !pointerFine

    // 9mm ≈ 48px for fingers; a pointer can hit far smaller
    readonly property int touchTarget: touchFirst ? 48 : 32
    readonly property int gutter:      touchFirst ? 8  : 6
    readonly property string density:  touchFirst ? "comfortable" : "compact"

    // an on-screen keyboard is needed when there is no physical one
    readonly property bool oskNeeded: !keyboardAttached

    // hover exists only with a fine pointer — components use this to decide
    // whether a hover affordance is meaningful at all (docs §3.1)
    readonly property bool hoverAvailable: pointerFine

    // gestures are the fast path on touch, never the only path
    readonly property bool gesturesPrimary: touchFirst
}
