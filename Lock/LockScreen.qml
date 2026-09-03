import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../Config"
import "../Icons"
import "../Services" as Sys

// NOT WIRED IN (shell.qml does not import it). KWin 6.7.4 lacks
// ext-session-lock-v1 entirely -- verified on the StarLite 2026-09-03 -- so this
// cannot run yet. Kept for the KWin release that ships the protocol. Known
// remaining bug: `pw` is inside the per-screen surface component and out of
// scope for the Scope-level helpers; route clears through a signal when reviving.
//
// Lock screen -- docs/quickshell-lock-greeter.md. ext-session-lock-v1 via
// WlSessionLock; PAM ("kde" stack = password-auth, plain pam_unix on this box).
//
// FAILS HARD BY DESIGN (§1): if the shell dies while locked the compositor keeps
// the screen covered. Recovery is SSH -> `sudo loginctl unlock-session 2`
// (Services/Session.qml). Never accept input before `secure` (§4). Password is
// never logged, never persisted, cleared on every exit path (§6).
Scope {
    id: root

    WlSessionLock {
        id: lock
        locked: Sys.Session.locked

        WlSessionLockSurface {
            id: surf
            color: Tokens.surface

            // wallpaper, dimmed (§7) -- the current one, read back from Plasma
            Image {
                anchors.fill: parent
                source: Sys.Wallpaper.current !== "" ? "file://" + Sys.Wallpaper.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: surf.width
                sourceSize.height: surf.height
                visible: status === Image.Ready
            }
            Rectangle { anchors.fill: parent; color: Tokens.surface; opacity: 0.55 }

            readonly property real kbH: Qt.inputMethod.keyboardRectangle.height > 0
                ? Qt.inputMethod.keyboardRectangle.height
                : (Sys.InputMode.oskNeeded ? height * Settings.oskFraction : 0)

            // centred column: rotates gracefully (§7)
            Column {
                id: col
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(Tokens.fontSize * 2, (surf.height - surf.kbH - height) / 2)
                spacing: Tokens.fontSize * 1.2
                width: Math.min(surf.width * 0.8, Tokens.fontSize * 26)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Tokens.ink; font.pixelSize: Tokens.fontSize * 5; font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 1.2
                }

                Item { width: 1; height: Tokens.fontSize }

                // password field, >= 48 px, never accepts input before `secure`
                Rectangle {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: Math.max(52, Sys.InputMode.touchTarget + 8)
                    radius: Tokens.radius
                    color: Tokens.surfaceVariant
                    border.width: 2
                    border.color: root.failed ? Tokens.critical : (pw.activeFocus ? Tokens.accent : Tokens.outline)
                    opacity: lock.secure ? 1 : 0.4
                    TextInput {
                        id: pw
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Tokens.ink; font.pixelSize: Tokens.fontSize * 1.2
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        enabled: lock.secure && !root.busy
                        focus: true
                        onAccepted: root.submit()
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            visible: pw.text === "" && !root.busy
                            text: root.failed ? "Wrong password" : (lock.secure ? "Password" : "Securing…")
                            color: root.failed ? Tokens.critical : Tokens.inkDim; font: pw.font
                        }
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            visible: root.busy
                            text: "Checking…"; color: Tokens.inkDim; font: pw.font
                        }
                        MouseArea { anchors.fill: parent; onClicked: { pw.forceActiveFocus(); Qt.inputMethod.show(); Sys.Osk.show() } }
                    }
                }

                // status row: battery + network (§7), media when something plays
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.fontSize * 1.5
                    Row {
                        spacing: 6
                        visible: Sys.Power.available
                        Battery { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter
                                  percent: Sys.Power.percentage; state: Sys.Power.state; ink: Tokens.ink }
                        Text { anchors.verticalCenter: parent.verticalCenter
                               text: Sys.Power.percentage + "%"; color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.85 }
                    }
                    Wifi { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter
                           bars: Sys.Network.strength; connected: Sys.Network.connected; ink: Tokens.ink }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    visible: Sys.Media.hasPlayer
                    Glyph { anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20
                            path: Sys.Media.playing ? Paths.pause : Paths.play; ink: Tokens.ink
                            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: Sys.Media.playPause() } }
                    Text { anchors.verticalCenter: parent.verticalCenter
                           text: Sys.Media.title + (Sys.Media.artist !== "" ? " — " + Sys.Media.artist : "")
                           color: Tokens.inkDim; font.pixelSize: Tokens.fontSize * 0.85
                           elide: Text.ElideRight; width: Math.min(implicitWidth, col.width - 60) }
                }
            }

            Timer { id: clock; property date date: new Date(); interval: 1000; running: true; repeat: true
                    onTriggered: date = new Date() }

            // the OSK: ask KWin once the compositor confirms every screen is covered
            Connections {
                target: lock
                function onSecureChanged() {
                    if (lock.secure) { pw.forceActiveFocus(); if (Sys.InputMode.oskNeeded) Sys.Osk.show() }
                }
            }
        }
    }

    // ---- authentication (§6: fail closed) ----
    property bool busy: false
    property bool failed: false
    property string _pending: ""        // lives only between submit() and respond()

    PamContext {
        id: pam
        config: "kde"
        user: Quickshell.env("USER")
        onPamMessage: {
            if (pam.responseRequired) { pam.respond(root._pending); root._pending = "" }
        }
        onCompleted: function (result) {
            root.busy = false
            root._pending = ""
            if (result === PamResult.Success) {
                root.failed = false
                root._clear()
                Sys.Session._realLocked = false
            } else {
                root.failed = true
                root._clear()
            }
        }
        onError: function (err) { root.busy = false; root._pending = ""; root.failed = true; root._clear() }
    }
    function _clear() { pw.text = "" }
    function submit() {
        if (!lock.secure || busy || pw.text === "") return
        _pending = pw.text
        _clear()
        failed = false
        busy = true
        if (!pam.start()) { busy = false; _pending = ""; failed = true }
    }

    Connections {
        target: Sys.Session
        function onLockedChanged() {
            if (Sys.Session.locked) { root.failed = false; root._clear() }
            else { root._clear(); root._pending = ""; root.busy = false; if (Sys.InputMode.oskNeeded) Sys.Osk.hide() }
        }

    }

    // ---- IPC ----
    // `test N` locks and auto-unlocks after N seconds: the §3.1 probe, so a failed
    // OSK cannot lock you out while testing. Dev-only `submit` exists only when
    // ~/.config/quickshell-starlite/lock-dev existed at startup, and is for the
    // wrong-password path -- never send a real password over IPC.
    readonly property bool devMode: Sys.Session.lockDevMode
    Timer { id: autoUnlock; repeat: false; onTriggered: { pam.abort(); Sys.Session._realLocked = false } }
    IpcHandler {
        target: "lock"
        function lock(): void { Sys.Session.lock() }
        function test(seconds: int): void { autoUnlock.interval = Math.max(5, seconds) * 1000; autoUnlock.restart(); Sys.Session.lock() }
        function state(): string {
            return "locked=" + Sys.Session.locked + " secure=" + lock.secure + " busy=" + root.busy
                 + " failed=" + root.failed + " dev=" + root.devMode + " pamActive=" + pam.active
        }
        function submit(text: string): void {
            if (!root.devMode) return
            pw.text = text; root.submit()
        }
    }
}
