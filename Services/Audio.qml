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
