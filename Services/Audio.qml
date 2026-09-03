pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Volume + mute. The presentation layer never learns that this is PipeWire.
QtObject {
    id: root

    // PwObjectTracker is required for a node's audio properties to go live.
    property var _tracker: PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    readonly property var _sink: Pipewire.defaultAudioSink
    readonly property var _audio: _sink && _sink.audio ? _sink.audio : null

    // real mode with no daemon must degrade, not crash
    readonly property bool available: Env.mock ? true : (Pipewire.ready && _audio !== null)

    readonly property real volume:
        Env.mock ? Mock.volume : (_audio ? _audio.volume : 0)
    readonly property bool muted:
        Env.mock ? Mock.muted : (_audio ? _audio.muted : false)
    readonly property string sinkName:
        Env.mock ? Mock.sinkName
                 : (_sink ? (_sink.description || _sink.nickname || _sink.name || "") : "")

    // ---- output picker (control-center step 10) ----
    readonly property var sinks: Env.mock ? Mock.sinks : _realSinks
    readonly property var _realSinks: {
        if (!Pipewire.nodes) return []
        var v = Pipewire.nodes.values, out = []
        var hasType = (typeof PwNodeType !== "undefined" && PwNodeType.AudioSink !== undefined)
        for (var i = 0; i < v.length; i++) {
            var n = v[i]
            if (!n) continue
            var ok = hasType ? (n.type === PwNodeType.AudioSink) : (n.isSink && !n.isStream)
            if (ok) out.push(n)
        }
        return out
    }
    function sinkLabel(n) { return n ? (n.description || n.nickname || n.name || "Output") : "" }
    function isDefaultSink(n) {
        if (!n) return false
        if (Env.mock) return n.description === Mock.sinkName
        return _sink === n
    }
    function setDefaultSink(n) {
        if (!n) return
        if (Env.mock) { Mock.sinkName = n.description; return }
        Pipewire.preferredDefaultAudioSink = n
    }

    function setVolume(v) {
        v = Math.max(0, Math.min(1, v))
        if (Env.mock) { Mock.volume = v; return }
        if (_audio) _audio.volume = v
    }
    function toggleMute() {
        if (Env.mock) { Mock.muted = !Mock.muted; return }
        if (_audio) _audio.muted = !_audio.muted
    }
}
