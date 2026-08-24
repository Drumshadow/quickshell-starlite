import QtQuick
import "../Config"
import "../Services" as Sys

// Interactive control over the simulated system. Everything here writes to
// Sys.Mock; services read from it; UI components never know.
Rectangle {
    id: root
    color: Tokens.surface
    implicitWidth: 380
    implicitHeight: col.implicitHeight + 24

    component Row_: Row { spacing: 8; anchors.left: parent.left; anchors.right: parent.right }

    component Toggle: Rectangle {
        id: tg
        property string label: ""
        property bool on: false
        signal toggled()
        implicitWidth: t.implicitWidth + 24
        implicitHeight: 30
        radius: 15
        color: tg.on ? Tokens.accent : Tokens.surfaceVariant
        border.color: Tokens.outline; border.width: 1
        Text { id: t; anchors.centerIn: parent; text: tg.label
               color: tg.on ? Tokens.inkOnAccent : Tokens.inkDim; font.pixelSize: 12 }
        MouseArea { anchors.fill: parent; onClicked: tg.toggled() }
    }

    component Slide: Item {
        id: sl
        property string label: ""
        property real value: 0.5
        property real from: 0
        property real to: 1
        signal moved(real v)
        implicitHeight: 38
        anchors.left: parent.left; anchors.right: parent.right
        Text { id: lb; text: sl.label + "  " + (sl.to > 1 ? Math.round(sl.value) : sl.value.toFixed(2))
               color: Tokens.inkDim; font.pixelSize: 11 }
        Rectangle {
            id: track
            anchors { left: parent.left; right: parent.right; top: lb.bottom; topMargin: 4 }
            height: 14; radius: 7
            color: Tokens.surfaceVariant
            Rectangle {
                height: parent.height; radius: parent.radius
                width: parent.width * (sl.value - sl.from) / (sl.to - sl.from)
                color: Tokens.accent
            }
            MouseArea {
                anchors.fill: parent
                function set(x) { sl.moved(sl.from + Math.max(0, Math.min(1, x / width)) * (sl.to - sl.from)) }
                onPressed: (m) => set(m.x)
                onPositionChanged: (m) => { if (pressed) set(m.x) }
            }
        }
    }

    Column {
        id: col
        anchors { fill: parent; margins: 12 }
        spacing: 8

        Text { text: "MOCK CONTROLS"; color: Tokens.ink; font.pixelSize: 14; font.bold: true }
        Text { text: "services read these; UI never does"; color: Tokens.inkDim; font.pixelSize: 10 }

        Text { text: "form factor"; color: Tokens.accent; font.pixelSize: 11; font.bold: true }
        Row_ {
            Toggle { label: "tablet";   on: Sys.Mock.tabletMode;       onToggled: Sys.Mock.tabletMode = !Sys.Mock.tabletMode }
            Toggle { label: "keyboard"; on: Sys.Mock.keyboardAttached; onToggled: Sys.Mock.keyboardAttached = !Sys.Mock.keyboardAttached }
            Toggle { label: "portrait"; on: Sys.Mock.orientation === "portrait"
                     onToggled: Sys.Mock.orientation = Sys.Mock.orientation === "portrait" ? "landscape" : "portrait" }
            Toggle { label: "pointer";  on: Sys.Mock.pointerFine;      onToggled: Sys.Mock.pointerFine = !Sys.Mock.pointerFine }
        }
        Text {
            text: "→ touchTarget=" + Sys.InputMode.touchTarget + "  density=" + Sys.InputMode.density
                  + "  osk=" + Sys.InputMode.oskNeeded + "  hover=" + Sys.InputMode.hoverAvailable
            color: Tokens.inkDim; font.pixelSize: 10; font.family: "monospace"
        }

        Text { text: "power"; color: Tokens.accent; font.pixelSize: 11; font.bold: true }
        Slide { label: "battery %"; value: Sys.Mock.batteryPercent; from: 0; to: 100
                onMoved: (v) => Sys.Mock.batteryPercent = Math.round(v) }
        Row_ {
            Toggle { label: "charging"; on: Sys.Mock.charging; onToggled: { Sys.Mock.charging = !Sys.Mock.charging; Sys.Mock.acConnected = Sys.Mock.charging } }
            Toggle { label: "on AC";    on: Sys.Mock.acConnected;     onToggled: Sys.Mock.acConnected = !Sys.Mock.acConnected }
            Text { text: "state: " + Sys.Power.state; color: Tokens.ink; font.pixelSize: 11
                   anchors.verticalCenter: parent.verticalCenter }
        }

        Text { text: "audio / brightness"; color: Tokens.accent; font.pixelSize: 11; font.bold: true }
        Slide { label: "volume"; value: Sys.Mock.volume; onMoved: (v) => Sys.Mock.volume = v }
        Slide { label: "brightness"; value: Sys.Mock.brightness; onMoved: (v) => Sys.Mock.brightness = v }
        Row_ { Toggle { label: "muted"; on: Sys.Mock.muted; onToggled: Sys.Mock.muted = !Sys.Mock.muted } }

        Text { text: "network / media"; color: Tokens.accent; font.pixelSize: 11; font.bold: true }
        Row_ {
            Toggle { label: "wifi"; on: Sys.Mock.wifiConnected; onToggled: Sys.Mock.wifiConnected = !Sys.Mock.wifiConnected }
            Toggle { label: "bt";   on: Sys.Mock.btEnabled;     onToggled: Sys.Mock.btEnabled = !Sys.Mock.btEnabled }
            Toggle { label: "playing"; on: Sys.Mock.playing;    onToggled: Sys.Mock.playing = !Sys.Mock.playing }
            Toggle { label: "peace";   on: Sys.Mock.peaceMode;  onToggled: Sys.Mock.peaceMode = !Sys.Mock.peaceMode }
        }
        Slide { label: "wifi bars"; value: Sys.Mock.wifiStrength; from: 0; to: 4
                onMoved: (v) => Sys.Mock.wifiStrength = Math.round(v) }

        Text { text: "presets"; color: Tokens.accent; font.pixelSize: 11; font.bold: true }
        Row_ {
            Toggle { label: "laptop";  onToggled: Sys.Mock.preset("laptop") }
            Toggle { label: "tablet";  onToggled: Sys.Mock.preset("tablet") }
            Toggle { label: "portrait";onToggled: Sys.Mock.preset("tablet-portrait") }
            Toggle { label: "low bat"; onToggled: Sys.Mock.preset("low-battery") }
            Toggle { label: "at cap";  onToggled: Sys.Mock.preset("at-cap") }
        }
    }
}
