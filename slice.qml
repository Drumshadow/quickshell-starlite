// Vertical-slice harness: the real Island on a real layer surface, driven by
// mock services so every state can be reached from the CLI.
//
//   qs -p slice.qml     then   qs ipc call island toggle launcher
import QtQuick
import Quickshell
import "Island"
import "Services" as Sys
import "dev"

ShellRoot {
    Component.onCompleted: {
        Sys.Env.mock = true
        var p = Quickshell.env("QS_PRESET")
        if (p) Sys.Mock.preset(p)
    }
    Island {}
    MockIpc {}
}
