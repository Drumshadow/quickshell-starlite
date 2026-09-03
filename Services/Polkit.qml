pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Polkit

// Polkit authentication agent -- docs/quickshell-polkit.md. One agent per
// session: registration only succeeds while plasma-polkit-agent.service is
// stopped (§1.2), so `registered` must be CHECKED, never assumed. The card
// (Island/AuthContent.qml) reads this; it never touches PolkitAgent directly.
// Security §2: the password passes straight through submit() and is held
// nowhere here.
QtObject {
    id: root
    property var _agent: PolkitAgent { id: agent }

    readonly property bool registered: !Env.mock && agent.isRegistered
    readonly property bool active: !Env.mock && agent.isActive
    readonly property var flow: agent.flow

    readonly property string message:      flow ? flow.message : ""
    readonly property string actionId:     flow ? flow.actionId : ""
    readonly property string prompt:       flow && flow.inputPrompt !== "" ? flow.inputPrompt : "Password:"
    readonly property bool responseVisible: flow ? flow.responseVisible : false
    readonly property bool responseRequired: flow ? flow.isResponseRequired : false
    readonly property string supplementary: flow ? flow.supplementaryMessage : ""
    readonly property bool supplementaryIsError: flow ? flow.supplementaryIsError : false
    readonly property bool failed:         flow ? flow.failed : false
    readonly property bool completed:      flow ? flow.isCompleted : false
    readonly property var identities:      flow && flow.identities ? flow.identities : []

    function identityName(i) {
        if (!i) return ""
        if (i.name !== undefined) return String(i.name)
        if (i.displayName !== undefined) return String(i.displayName)
        return String(i)
    }
    readonly property string identity: flow && flow.selectedIdentity ? identityName(flow.selectedIdentity)
                                     : (identities.length > 0 ? identityName(identities[0]) : "")
    function selectIdentity(i) { if (flow && identities[i]) flow.selectedIdentity = identities[i] }

    function submit(value) { if (flow && !Env.mock) flow.submit(value) }
    function cancel() { if (flow && !Env.mock) flow.cancelAuthenticationRequest() }

    // dev-only wrong-password IPC exists only when this file was present at startup
    property bool devMode: false
    property var _devProbe: Process {
        command: ["sh", "-c", "test -f \"$HOME/.config/quickshell-starlite/polkit-dev\" && echo yes || echo no"]
        running: !Env.mock
        stdout: StdioCollector { onStreamFinished: root.devMode = String(this.text).indexOf("yes") >= 0 }
    }
}
