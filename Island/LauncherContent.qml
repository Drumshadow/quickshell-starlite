import QtQuick
import "../Config"
import "../Icons"
import "../Components"
import "../Services" as Sys

// Launcher — docs/quickshell-launcher.md, build order steps 1–6.
//
//  * Results live in a STABLE ListModel and every keystroke applies a diff
//    (insert / remove / move), so the ListView's transitions actually run (§8).
//    Reassigning `model` would tear the delegates down and snap.
//  * Sizing is OSK-aware (§6): rows never sit under the keyboard. Plasma
//    Keyboard does not report keyboardRectangle here, so Settings.oskFraction
//    stands in when the probe's measured 0x0 comes back.
//  * Row 0 is selected by default so the OSK's Enter launches the top hit (§9).
//  * Frecency, modes, chips and the bottom-edge swipe are steps 7–11: not here.
Item {
    id: root
    property alias query: input.text
    property int selected: 0
    // Island sets this from its screen on load; the default is the StarLite panel.
    property real screenHeight: 1029

    signal launched(string name)
    signal dismissed()

    readonly property int rowH: Math.max(56, Sys.InputMode.touchTarget)
    readonly property real _kbRect: Qt.inputMethod.keyboardRectangle.height
    readonly property real oskH: _kbRect > 0 ? _kbRect
                                : (Sys.InputMode.oskNeeded ? screenHeight * Settings.oskFraction : 0)
    readonly property real _chrome: header.height + Tokens.fontSize * 1.4   // header + margins
    readonly property int maxVisible:
        Math.max(1, Math.floor((screenHeight - oskH - _chrome - 40 /*top margin*/ - 24 /*safety*/) / rowH))
    readonly property int visibleRows: Math.min(results.count, maxVisible)

    implicitWidth: Tokens.fontSize * 28
    implicitHeight: _chrome + visibleRows * rowH

    ListModel { id: results }

    function focusInput() {
        input.forceActiveFocus()
        // Probe verdict (§3.1.8): tap raises the OSK, programmatic focus does not.
        // The launcher opens programmatically, so ask for it explicitly (Amber path).
        if (Sys.InputMode.oskNeeded) Qt.inputMethod.show()
    }

    function activate() {
        if (results.count === 0) return
        const i = Math.max(0, Math.min(selected, results.count - 1))
        const row = results.get(i)
        if (Sys.Apps.launchId(row.id)) root.launched(row.name)
    }

    // ---- the diff (§8) ---------------------------------------------------
    function _indexOfId(id) {
        for (let i = 0; i < results.count; i++) if (results.get(i).id === id) return i
        return -1
    }
    function applyResults(next) {
        const keep = {}
        for (let i = 0; i < next.length; i++) keep[next[i].id] = true
        // 1. remove rows that no longer match (backwards so indices hold)
        for (let i = results.count - 1; i >= 0; i--)
            if (!keep[results.get(i).id]) results.remove(i, 1)
        // 2. walk the target order: insert missing, move misplaced, refresh text
        for (let i = 0; i < next.length; i++) {
            const r = next[i]
            const j = _indexOfId(r.id)
            if (j < 0) results.insert(i, { id: r.id, name: r.name, generic: r.generic, icon: r.icon })
            else {
                if (j !== i) results.move(j, i, 1)
                const cur = results.get(i)
                if (cur.name !== r.name) results.setProperty(i, "name", r.name)
                if (cur.generic !== r.generic) results.setProperty(i, "generic", r.generic)
                if (cur.icon !== r.icon) results.setProperty(i, "icon", r.icon)
            }
        }
        if (selected >= results.count) selected = Math.max(0, results.count - 1)
    }
    Timer {
        id: debounce
        interval: 40; repeat: false
        onTriggered: root.applyResults(Sys.Apps.search(input.text))
    }
    Component.onCompleted: applyResults(Sys.Apps.search(""))

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
                width: root.width - Tokens.iconSize - Tokens.fontSize * 2 - (oskHint.visible ? oskHint.width + Tokens.fontSize : 0)
                color: Tokens.ink
                font.pixelSize: Tokens.fontSize
                focus: true
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                Component.onCompleted: forceActiveFocus()
                onTextChanged: { root.selected = 0; debounce.restart() }
                Keys.onDownPressed: root.selected = Math.min(root.selected + 1, results.count - 1)
                Keys.onUpPressed:   root.selected = Math.max(root.selected - 1, 0)
                Keys.onReturnPressed: root.activate()
                Keys.onEnterPressed:  root.activate()
                Keys.onEscapePressed: root.dismissed()
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: "Search…"
                    color: Tokens.inkDim
                    font: input.font
                }
            }
            // OSK affordance only when there is no physical keyboard — InputMode
            // decides; tapping it re-raises the keyboard if it was dismissed
            Rectangle {
                id: oskHint
                anchors.verticalCenter: parent.verticalCenter
                visible: Sys.InputMode.oskNeeded
                width: Sys.InputMode.touchTarget; height: Sys.InputMode.touchTarget
                radius: Tokens.radius
                color: hintPress.pressed ? Tokens.surfaceVariant : "transparent"
                Text { anchors.centerIn: parent; text: "⌨"; color: Tokens.accent; font.pixelSize: Tokens.fontSize * 1.2 }
                MouseArea { id: hintPress; anchors.fill: parent; onClicked: { input.forceActiveFocus(); Qt.inputMethod.show() } }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: root.visibleRows * root.rowH
            clip: true
            model: results
            interactive: results.count > root.maxVisible
            currentIndex: root.selected
            highlightFollowsCurrentItem: true
            boundsBehavior: Flickable.StopAtBounds

            // §8: survivors slide, leavers fade, arrivals fade in. Same easing
            // family as the island's own morph (Island.qml Behaviors).
            add:       Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic } }
            remove:    Transition { NumberAnimation { property: "opacity"; to: 0; duration: 140; easing.type: Easing.OutCubic } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 240; easing.type: Easing.OutCubic } }
            move:      Transition { NumberAnimation { properties: "y"; duration: 240; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                id: row
                required property int index
                required property string id
                required property string name
                required property string generic
                required property string icon
                width: list.width
                height: root.rowH
                radius: Tokens.radius
                readonly property bool isSelected: index === root.selected
                // immediate press state (<50 ms, no spring) — parent §3.1.6
                color: press.pressed ? Tokens.outline
                     : (isSelected ? Tokens.surfaceVariant : "transparent")

                Rectangle {   // selection accent bar
                    visible: row.isSelected
                    x: 0; width: 3; height: parent.height * 0.6; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.accent
                }
                Row {
                    anchors { left: parent.left; leftMargin: Tokens.fontSize; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.fontSize * 0.7
                    Item {
                        width: 24; height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            anchors.fill: parent
                            visible: row.icon !== "" && status === Image.Ready
                            source: row.icon !== "" ? "file://" + row.icon : ""
                            sourceSize: Qt.size(48, 48)
                            smooth: true
                        }
                        LetterAvatar {
                            anchors.fill: parent
                            visible: row.icon === ""
                            name: row.name
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: row.name
                            color: Tokens.ink
                            font.pixelSize: Tokens.fontSize * 0.95
                            font.bold: true
                        }
                        Text {
                            visible: row.generic !== "" && row.generic !== row.name
                            text: row.generic
                            color: Tokens.inkDim
                            font.pixelSize: Tokens.fontSize * 0.75
                        }
                    }
                }
                MouseArea {
                    id: press
                    anchors.fill: parent
                    onClicked: { root.selected = row.index; root.activate() }
                }
            }
        }
    }
}
