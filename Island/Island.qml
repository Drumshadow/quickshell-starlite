import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Config"

// island-core §2. ONE surface, full-width, mapped for the life of the session.
//
//   * `visible` is NEVER set false anywhere in this shell (KWin bug 503121).
//   * Anchoring full width keeps surface geometry stable, gives the full
//     top-edge input strip reachability needs, and lets the drawn island
//     resize freely.
//   * The mask is what makes a full-width surface tolerable — it MUST be
//     recomputed on every state change or the top of the desktop silently
//     stops responding.
PanelWindow {
    id: win
    anchors { top: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:
        IslandState.focusFor(IslandState.current) === "Exclusive"
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

    // tall enough for the largest state; the mask keeps it click-through
    implicitHeight: 520

    // ---- the drawn island -------------------------------------------------
    Rectangle {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        radius: height / 2 > Tokens.radius * 2 ? Tokens.radius * 1.6 : height / 2
        color: Tokens.surface

        // geometry animates; content cross-fades — driven together (island-core §5)
        implicitWidth:  content.implicitWidth
        implicitHeight: content.implicitHeight
        Behavior on implicitWidth  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Item {
            id: content
            anchors.centerIn: parent
            // per-state content loaders go here; sized by the active one
            implicitWidth:  loader.item ? loader.item.implicitWidth  : 90
            implicitHeight: loader.item ? loader.item.implicitHeight : Settings.barHeight

            Loader {
                id: loader
                anchors.centerIn: parent
                asynchronous: false
                source: {
                    switch (IslandState.current) {
                    case "rest":     return "RestContent.qml"
                    case "expanded": return "ExpandedContent.qml"
                    default:         return "RestContent.qml"   // TODO: other states
                    }
                }
                opacity: 1
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }

    // ---- the top-edge gesture strip (island-core §2.3, §8) ----------------
    Item {
        id: topStrip
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 20
    }

    // ---- input mask: island + strip only; everything else passes through --
    mask: Region {
        Region { item: island }
        Region { item: topStrip }
    }
}
