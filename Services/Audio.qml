pragma Singleton
import QtQuick

// Volume + mute. The presentation layer must never learn whether this is
// PipeWire, PulseAudio or something else.
QtObject {
    id: root
    readonly property real volume:  Env.mock ? Mock.volume  : _realVolume
    readonly property bool muted:   Env.mock ? Mock.muted   : _realMuted
    readonly property string sinkName: Env.mock ? Mock.sinkName : _realSink

    // TODO(real): Quickshell.Services.Pipewire — defaultAudioSink, its
    // audio.volume / audio.muted. Native, no shelling out (docs: cc §2).
    property real _realVolume: 0.5
    property bool _realMuted: false
    property string _realSink: ""

    function setVolume(v) {
        v = Math.max(0, Math.min(1, v))
        if (Env.mock) Mock.volume = v
        else _realVolume = v          // TODO: write to the Pipewire node
    }
    function toggleMute() {
        if (Env.mock) Mock.muted = !Mock.muted
        else _realMuted = !_realMuted // TODO: write to the Pipewire node
    }
}
