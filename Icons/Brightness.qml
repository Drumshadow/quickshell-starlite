import QtQuick
import QtQuick.Shapes
import "../Config"

// icons §4: rays lengthen CONTINUOUSLY with level, not in steps.
// 8 fixed rays whose scale/opacity animate — no path regeneration (icons §8).
Item {
    id: root
    property real value: 0.7        // 0..1
    property color ink: Tokens.onSurface
    implicitWidth: Tokens.iconSize
    implicitHeight: Tokens.iconSize

    Shape {
        anchors.centerIn: parent
        width: parent.width; height: parent.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.ink; strokeColor: "transparent"
            PathAngleArc {
                centerX: root.width/2; centerY: root.height/2
                radiusX: root.width*0.20; radiusY: root.height*0.20
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    Repeater {
        model: 8
        delegate: Item {
            required property int index
            anchors.centerIn: parent
            width: root.width; height: root.height
            rotation: index * 45
            Rectangle {
                width: Math.max(1.5, root.width*0.07)
                height: root.height * (0.06 + 0.10 * root.value)
                radius: width/2
                color: root.ink
                opacity: 0.35 + 0.65 * root.value
                x: (root.width - width)/2
                y: root.height*0.5 - root.height*0.28 - height
                Behavior on height  { NumberAnimation { duration: 160 } }
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
        }
    }
}
