import QtQuick
import QtQuick.Shapes
import "../Config"

// icons §4 + status-capsule §4.
// The percentage sits INSIDE the cell. A single ink colour is wrong at one end
// or the other, so the number is drawn TWICE — once in on-empty ink, once in
// on-fill ink clipped to the fill rect. Digits flip colour at the boundary.
Item {
    id: root
    property int percent: 80
    // Discharging | Charging | AtCap | Full | Low | Critical | None
    property string state: "Discharging"
    property color ink: Tokens.ink

    implicitWidth: Math.round(Tokens.iconSize * 1.9)
    implicitHeight: Tokens.iconSize

    readonly property bool charging: state === "Charging"
    readonly property color fillColor:
          charging                ? Tokens.success
        : state === "Critical"    ? Tokens.critical
        : state === "Low"         ? Tokens.critical
        : Tokens.accent

    readonly property real cellW: width * 0.88
    readonly property real cellH: height * 0.72
    readonly property real cellY: (height - cellH) / 2
    readonly property real inset: Math.max(1.5, width * 0.035)

    // cell outline + terminal nub
    Rectangle {
        id: cell
        x: 0; y: root.cellY
        width: root.cellW; height: root.cellH
        radius: height * 0.32
        color: "transparent"
        border.color: root.ink
        border.width: root.inset
        opacity: 0.75
    }
    Rectangle {
        x: root.cellW + root.inset
        y: root.height/2 - root.cellH*0.16
        width: root.width * 0.05; height: root.cellH * 0.32
        radius: width/2
        color: root.ink
        opacity: 0.75
    }

    // fill
    Item {
        id: fillClip
        x: cell.x + root.inset*1.5
        y: cell.y + root.inset*1.5
        height: cell.height - root.inset*3
        width: Math.max(0, (cell.width - root.inset*3) * Math.min(1, root.percent/100))
        clip: true
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Rectangle {
            width: cell.width - root.inset*3
            height: parent.height
            radius: height * 0.28
            color: root.fillColor
        }

        // second copy of the label, in on-fill ink, offset so it lines up
        // with the unclipped copy below
        Text {
            x: label.x - fillClip.x
            y: label.y - fillClip.y
            width: label.width; height: label.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: label.text
            font: label.font
            color: (Tokens.isDarkColor(root.fillColor) ? Tokens.inkLight : Tokens.inkDark)
        }
    }

    // first copy — on-empty ink, sits under the clipped copy
    Text {
        id: label
        x: 0; y: root.cellY
        width: root.cellW; height: root.cellH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.state === "None" ? "" : String(root.percent)
        color: root.ink
        font.pixelSize: Math.round(root.cellH * 0.62)
        font.bold: true
        // tabular so the capsule does not jitter as digits change
        font.styleName: "Regular"
        z: -1
    }

    // charging bolt
    Shape {
        anchors.fill: parent
        opacity: root.charging ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: (Tokens.isDarkColor(root.fillColor) ? Tokens.inkLight : Tokens.inkDark); strokeColor: "transparent"
            startX: root.cellW*0.52; startY: root.cellY + root.cellH*0.16
            PathLine { x: root.cellW*0.40; y: root.cellY + root.cellH*0.54 }
            PathLine { x: root.cellW*0.50; y: root.cellY + root.cellH*0.54 }
            PathLine { x: root.cellW*0.44; y: root.cellY + root.cellH*0.86 }
            PathLine { x: root.cellW*0.60; y: root.cellY + root.cellH*0.44 }
            PathLine { x: root.cellW*0.50; y: root.cellY + root.cellH*0.44 }
            PathLine { x: root.cellW*0.52; y: root.cellY + root.cellH*0.16 }
        }
    }
}
