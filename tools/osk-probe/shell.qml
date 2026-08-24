// ---------------------------------------------------------------------------
// OSK probe — spec §3.1.8 item 1 / stage 4 of ~/specs/quickshell-starlite-rice.md
//
// Question: does Plasma's on-screen keyboard raise for a Quickshell text field
// on a layer surface? If not, the launcher (§1.6) and the polkit card (§1.13)
// are unusable with the folio detached, which is a project-level risk.
//
// Run:  qs -p ~/specs/osk-probe/shell.qml
//   or: ~/specs/osk-probe/run.sh   (tees console output to a log)
//
// This is a DIAGNOSTIC, not a demo. It separates failure modes that look
// identical from the outside — see README.md for the decision table.
// ---------------------------------------------------------------------------

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    // "None" | "OnDemand" | "Exclusive" — live-switchable, because
    // PanelWindow.focusable defaults to FALSE. A text field on a
    // non-focusable panel receives nothing, which is easy to misread as
    // "Quickshell can't do input method at all".
    property string focusMode: "OnDemand"
    property var events: []

    function note(msg) {
        const t = new Date().toTimeString().substring(0, 8);
        root.events = [t + "  " + msg].concat(root.events).slice(0, 9);
        console.log("[osk-probe] " + t + "  " + msg);
    }

    // ---- instrument: Qt's own view of the input method -------------------
    // If the OSK appears on screen but visible stays false, Qt is not being
    // told about it — a different bug from the OSK never appearing.
    Connections {
        target: Qt.inputMethod
        function onVisibleChanged() {
            root.note("Qt.inputMethod.visible -> " + Qt.inputMethod.visible);
        }
        function onKeyboardRectangleChanged() {
            const r = Qt.inputMethod.keyboardRectangle;
            root.note("kbdRect -> " + Math.round(r.x) + "," + Math.round(r.y)
                      + "  " + Math.round(r.width) + "x" + Math.round(r.height));
        }
    }

    // ---- reusable pieces --------------------------------------------------

    component Btn: Rectangle {
        id: btn
        property string label: ""
        property bool active: false
        signal tapped()
        implicitHeight: 52                    // >= 48px touch floor (§3.1.3)
        implicitWidth: Math.max(96, txt.implicitWidth + 28)
        radius: 8
        color: ma.pressed ? "#2f4a42" : (btn.active ? "#14b88f" : "#1b2320")
        border.color: btn.active ? "#5eead4" : "#2d3733"
        border.width: 1
        Text {
            id: txt
            anchors.centerIn: parent
            text: btn.label
            color: btn.active ? "#04120e" : "#cfdcd8"
            font.pixelSize: 14
        }
        MouseArea { id: ma; anchors.fill: parent; onClicked: btn.tapped() }
    }

    // Deliberately NO MouseArea over the TextInput: the touch must reach the
    // TextInput itself, since that is what would normally trigger the OSK.
    component ProbeField: Rectangle {
        id: fld
        property string label: ""
        property bool password: false
        property alias field: input
        implicitHeight: 74
        radius: 10
        color: "#121815"
        border.color: input.activeFocus ? "#5eead4" : "#2a3330"
        border.width: 2
        Text {
            text: fld.label + (input.activeFocus ? "   ● focused" : "")
            color: input.activeFocus ? "#5eead4" : "#6f7f7a"
            font.pixelSize: 12
            anchors { left: parent.left; top: parent.top; leftMargin: 12; topMargin: 7 }
        }
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 26; bottomMargin: 4 }
            verticalAlignment: TextInput.AlignVCenter
            color: "#e9f2ef"
            font.pixelSize: 20
            selectByMouse: true
            echoMode: fld.password ? TextInput.Password : TextInput.Normal
            inputMethodHints: fld.password ? Qt.ImhSensitiveData : Qt.ImhNone
            onActiveFocusChanged: root.note(fld.label + ": activeFocus=" + activeFocus)
            onTextChanged: if (text.length > 0) root.note(fld.label + ": text len=" + text.length)
        }
    }

    component Readout: Text {
        color: "#8fa39d"
        font.pixelSize: 13
        font.family: "monospace"
    }

    // ---- THE TEST: a layer-shell surface ---------------------------------

    PanelWindow {
        id: panel
        anchors { top: true; left: true; right: true }
        implicitHeight: 430
        color: "#0b100e"

        WlrLayershell.namespace: "osk-probe"
        WlrLayershell.layer: WlrLayer.Overlay
        // PanelWindow.focusable is the portable alias for this. Set the
        // Wayland property directly so the probe is explicit about the
        // keyboard-interactivity value actually being committed.
        WlrLayershell.keyboardFocus: root.focusMode === "None"
                ? WlrKeyboardFocus.None
                : root.focusMode === "Exclusive"
                    ? WlrKeyboardFocus.Exclusive
                    : WlrKeyboardFocus.OnDemand

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 10

            Text {
                text: "OSK probe — layer surface (Overlay)"
                color: "#e9f2ef"; font.pixelSize: 19; font.bold: true
            }

            Row {
                spacing: 8
                Text {
                    text: "keyboardFocus:"; color: "#8fa39d"; font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                Btn { label: "None";      active: root.focusMode === "None"
                      onTapped: { root.focusMode = "None";      root.note("keyboardFocus -> None"); } }
                Btn { label: "OnDemand";  active: root.focusMode === "OnDemand"
                      onTapped: { root.focusMode = "OnDemand";  root.note("keyboardFocus -> OnDemand"); } }
                Btn { label: "Exclusive"; active: root.focusMode === "Exclusive"
                      onTapped: { root.focusMode = "Exclusive"; root.note("keyboardFocus -> Exclusive"); } }
            }

            ProbeField {
                id: plainField
                width: parent.width
                label: "plain text  — tap here, expect the OSK"
            }

            ProbeField {
                id: pwField
                width: parent.width
                label: "password (§1.13 polkit card)"
                password: true
            }

            Row {
                spacing: 8
                // If tapping does nothing but this DOES raise the OSK, you have
                // a workaround: call show() when the launcher opens.
                Btn { label: "Qt.inputMethod.show()"
                      onTapped: { root.note("calling show()"); Qt.inputMethod.show(); } }
                Btn { label: "hide()"
                      onTapped: { root.note("calling hide()"); Qt.inputMethod.hide(); } }
                // Programmatic focus vs. touch focus is a real distinction:
                // some stacks only raise the OSK on an actual touch event.
                Btn { label: "focus by code"
                      onTapped: { root.note("forceActiveFocus()"); plainField.field.forceActiveFocus(); } }
                Btn { label: "control window"
                      active: controlWindow.visible
                      onTapped: controlWindow.visible = !controlWindow.visible }
                Btn { label: "reset"
                      onTapped: {
                          plainField.field.text = ""; pwField.field.text = "";
                          root.events = []; root.note("reset");
                      } }
            }

            Rectangle { width: parent.width; height: 1; color: "#202a27" }

            Readout {
                text: "Qt.inputMethod.visible : " + Qt.inputMethod.visible
                      + "      animating: " + Qt.inputMethod.animating
                color: Qt.inputMethod.visible ? "#5eead4" : "#8fa39d"
            }
            Readout {
                text: {
                    const r = Qt.inputMethod.keyboardRectangle;
                    const sh = panel.screen ? panel.screen.height : 0;
                    return "keyboardRectangle   : " + Math.round(r.x) + "," + Math.round(r.y)
                         + "  " + Math.round(r.width) + "x" + Math.round(r.height)
                         + "   (screen h=" + sh + ")";
                }
            }
            Readout { text: "text received       : " + JSON.stringify(plainField.field.text) }

            Column {
                spacing: 2
                Repeater {
                    model: root.events
                    delegate: Text {
                        required property string modelData
                        text: modelData
                        color: "#5c6e69"; font.pixelSize: 11; font.family: "monospace"
                    }
                }
            }
        }
    }

    // ---- THE CONTROL: an ordinary window ---------------------------------
    // Isolates "layer surfaces can't do input method" from "Quickshell can't
    // do input method". If the OSK raises here but not on the panel above,
    // the problem is layer-shell specific and worth reporting upstream.

    FloatingWindow {
        id: controlWindow
        visible: false
        implicitWidth: 560
        implicitHeight: 230
        color: "#0b100e"

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 10
            Text {
                text: "CONTROL — ordinary window, not a layer surface"
                color: "#e9f2ef"; font.pixelSize: 17; font.bold: true
            }
            Text {
                text: "If the OSK raises here but NOT on the panel, the fault is layer-shell specific."
                color: "#8fa39d"; font.pixelSize: 12; wrapMode: Text.WordWrap
                width: parent.width
            }
            ProbeField {
                width: parent.width
                label: "plain text (control)"
            }
        }
    }

    Component.onCompleted: {
        root.note("probe started — keyboardFocus=" + root.focusMode);
        root.note("Qt.inputMethod.visible=" + Qt.inputMethod.visible);
    }
}
