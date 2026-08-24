pragma Singleton
import QtQuick

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

    // TODO(hardware): real sources.
    //   tabletMode       — logind/upower "tablet mode" switch, or KDE's own signal
    //   keyboardAttached — libinput device add/remove for the folio
    //   pointerFine      — presence of a pointer device
    // Determined empirically when the StarLite arrives (docs §8).
    property bool _realTabletMode: false
    property bool _realKeyboardAttached: true
    property bool _realPointerFine: true

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
