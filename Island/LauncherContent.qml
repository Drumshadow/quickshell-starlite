import QtQuick
import "../Config"
import "../Icons"
import "../Services" as Sys

// Minimal launcher: enough to complete the vertical slice. The full design —
// diffed ListModel reflow, mode chips, frecency — is docs/quickshell-launcher.md
// and is deliberately NOT built yet.
Item {
    id: root
    property alias query: input.text
    property var results: Sys.Apps.search(input.text)
    property int selected: 0

    signal launched(string name)

    implicitWidth: Tokens.fontSize * 26
    implicitHeight: header.height + list.contentHeight + Tokens.fontSize

    function focusInput() { input.forceActiveFocus() }

    function activate() {
        if (results.length === 0) return
        var e = results[Math.max(0, Math.min(selected, results.length - 1))].entry
        if (Sys.Apps.launch(e)) root.launched(e.name)
    }

    Column {
        anchors { fill: parent; margins: Tokens.fontSize * 0.5 }
        spacing: Tokens.fontSize * 0.4

        Row {
            id: header
            height: Sys.InputMode.touchTarget
            spacing: Tokens.fontSize * 0.5
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                width: Tokens.iconSize; height: Tokens.iconSize
                path: Paths.search; ink: Tokens.inkDim
            }
            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: root.width - Tokens.iconSize - Tokens.fontSize * 2
                color: Tokens.ink
                font.pixelSize: Tokens.fontSize
                focus: true
                Component.onCompleted: forceActiveFocus()
                onTextChanged: root.selected = 0
                Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
                Keys.onUpPressed:   root.selected = Math.max(root.selected - 1, 0)
                Keys.onReturnPressed: root.activate()
                Keys.onEnterPressed:  root.activate()
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: "Search…"
                    color: Tokens.inkDim
                    font: input.font
                }
            }
            // OSK affordance appears only when there is no physical keyboard —
            // InputMode decides, this component carries no device assumptions
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Sys.InputMode.oskNeeded
                text: "⌨"
                color: Tokens.accent
                font.pixelSize: Tokens.fontSize
            }
        }

        Column {
            id: list
            width: parent.width
            property int contentHeight: results.length * Sys.InputMode.touchTarget
            Repeater {
                model: root.results
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: Sys.InputMode.touchTarget
                    color: index === root.selected ? Tokens.surfaceVariant : "transparent"
                    Rectangle {
                        visible: index === root.selected
                        width: 3; height: parent.height * 0.6; radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.accent
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: Tokens.fontSize
                                  verticalCenter: parent.verticalCenter }
                        text: modelData.name
                        color: Tokens.ink
                        font.pixelSize: Tokens.fontSize * 0.9
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.selected = index; root.activate() }
                    }
                }
            }
        }
    }
}
