import QtQuick
import "../Config"
import "../Icons"
import "../Services" as Sys

// Polkit card -- docs/quickshell-polkit.md §4. `message` and `actionId` are
// rendered verbatim (anti-spoofing: the action ID is the one thing a user can
// check). Fail closed: Escape, Cancel, tap-outside and the timeout all cancel
// the flow and clear the field (§2, §6). The password is never logged, never
// kept: it goes from the field into submit() and the field is cleared.
Item {
    id: root
    implicitWidth: Tokens.fontSize * 26
    implicitHeight: col.implicitHeight

    signal dismissed()

    function focusInput() {
        pw.forceActiveFocus()
        if (Sys.InputMode.oskNeeded) { Qt.inputMethod.show(); Sys.Osk.show() }
    }
    function cancel() { pw.text = ""; Sys.Polkit.cancel() }
    function authenticate() {
        if (pw.text === "" || !Sys.Polkit.responseRequired) return
        var v = pw.text
        pw.text = ""
        Sys.Polkit.submit(v)
        v = ""
        idle.restart()
    }
    Component.onDestruction: { pw.text = ""; if (Sys.InputMode.oskNeeded) Sys.Osk.hide() }

    // §6: an unattended prompt must not hold exclusive focus forever
    Timer { id: idle; interval: 90000; running: true; repeat: false; onTriggered: root.cancel() }

    Column {
        id: col
        width: parent.width
        spacing: Tokens.fontSize * 0.6

        Row {
            spacing: 8
            Glyph { anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; path: Paths.lock; ink: Tokens.accent }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Authentication Required"
                   color: Tokens.ink; font.pixelSize: Tokens.fontSize; font.bold: true }
        }
        Text {
            width: parent.width
            text: Sys.Polkit.message
            color: Tokens.ink; font.pixelSize: Tokens.fontSize * 0.85
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            text: Sys.Polkit.actionId
            color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.65
            font.family: "monospace"
            wrapMode: Text.WrapAnywhere
        }
        // identity (§3): static when one, a picker when several
        Text {
            visible: Sys.Polkit.identities.length <= 1 && Sys.Polkit.identity !== ""
            text: "Authenticating as " + Sys.Polkit.identity
            color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.7
        }
        Row {
            visible: Sys.Polkit.identities.length > 1
            spacing: 6
            Repeater {
                model: Sys.Polkit.identities
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: Sys.Polkit.identityName(modelData) === Sys.Polkit.identity
                    width: idText.implicitWidth + 20; height: Math.max(36, Sys.InputMode.touchTarget - 8)
                    radius: Tokens.radius
                    color: sel ? Tokens.accent : Tokens.surfaceVariant
                    Text { id: idText; anchors.centerIn: parent; text: Sys.Polkit.identityName(modelData)
                           color: sel ? Tokens.inkOnAccent : Tokens.ink; font.pixelSize: Tokens.fontSize * 0.75 }
                    MouseArea { anchors.fill: parent; onClicked: Sys.Polkit.selectIdentity(index) }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Math.max(48, Sys.InputMode.touchTarget + 4)
            radius: Tokens.radius
            color: Tokens.surfaceVariant
            border.width: 2
            border.color: Sys.Polkit.failed ? Tokens.critical : (pw.activeFocus ? Tokens.accent : Tokens.outline)
            TextInput {
                id: pw
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                verticalAlignment: TextInput.AlignVCenter
                color: Tokens.ink; font.pixelSize: Tokens.fontSize
                echoMode: Sys.Polkit.responseVisible ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                enabled: Sys.Polkit.responseRequired
                focus: true
                onTextChanged: idle.restart()
                onAccepted: root.authenticate()
                Keys.onEscapePressed: root.cancel()
                Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                       visible: pw.text === ""; text: Sys.Polkit.prompt
                       color: Tokens.inkDim; font: pw.font }
                MouseArea { anchors.fill: parent; onClicked: root.focusInput() }
            }
        }
        Text {
            visible: text !== ""
            width: parent.width
            text: Sys.Polkit.failed && Sys.Polkit.supplementary === "" ? "Authentication failed — try again"
                : Sys.Polkit.supplementary
            color: (Sys.Polkit.failed || Sys.Polkit.supplementaryIsError) ? Tokens.critical : Tokens.inkDim
            font.pixelSize: Tokens.fontSize * 0.7
            wrapMode: Text.Wrap
        }

        Row {
            anchors.right: parent.right
            spacing: 8
            Rectangle {
                width: Tokens.fontSize * 6; height: Math.max(48, Sys.InputMode.touchTarget)
                radius: Tokens.radius; color: cancelMa.pressed ? Tokens.outline : Tokens.surfaceVariant
                Text { anchors.centerIn: parent; text: "Cancel"; color: Tokens.ink; font.pixelSize: Tokens.fontSize * 0.85 }
                MouseArea { id: cancelMa; anchors.fill: parent; onClicked: root.cancel() }
            }
            Rectangle {
                readonly property bool ok: pw.text !== "" && Sys.Polkit.responseRequired
                width: Tokens.fontSize * 8; height: Math.max(48, Sys.InputMode.touchTarget)
                radius: Tokens.radius; color: ok ? Tokens.accent : Tokens.surfaceVariant
                Text { anchors.centerIn: parent; text: "Authenticate"; font.bold: true
                       color: parent.ok ? Tokens.inkOnAccent : Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.85 }
                MouseArea { anchors.fill: parent; enabled: parent.ok; onClicked: root.authenticate() }
            }
        }
    }
}
