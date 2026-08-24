pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

// MPRIS. Player selection is STICKY — browsers register a player per tab, so
// naive players[0] makes the island flicker between sources.
QtObject {
    id: root
    property var _current: null

    readonly property var _list: Mpris.players ? Mpris.players.values : []

    function _pick() {
        if (_list.length === 0) return null
        // keep the current one unless it vanished or another started playing
        if (_current && _list.indexOf(_current) >= 0) {
            if (_current.playbackState === MprisPlaybackState.Playing) return _current
        }
        var playing = null, paused = null
        for (var i = 0; i < _list.length; i++) {
            var p = _list[i]
            if (!p) continue
            if (p.playbackState === MprisPlaybackState.Playing) { playing = p; break }
            if (!paused && p.playbackState === MprisPlaybackState.Paused) paused = p
        }
        var next = playing || paused || _list[0]
        if (_current && _list.indexOf(_current) >= 0 && !playing) return _current
        return next
    }
    property var _conn: Connections {
        target: Mpris.players
        function onValuesChanged() { root._current = root._pick() }
    }
    Component.onCompleted: _current = _pick()

    readonly property var player: Env.mock ? null : _current
    readonly property bool available: Env.mock ? true : (player !== null)

    readonly property bool playing:
        Env.mock ? Mock.playing
                 : (player ? player.playbackState === MprisPlaybackState.Playing : false)
    readonly property string title:
        Env.mock ? Mock.title : (player ? (player.trackTitle || "") : "")
    readonly property string artist:
        Env.mock ? Mock.artist : (player ? (player.trackArtist || "") : "")
    readonly property int length:
        Env.mock ? Mock.length : (player ? Math.round(player.length) : 0)
    readonly property bool canNext:
        Env.mock ? Mock.canNext : (player ? player.canGoNext : false)
    readonly property bool canPrev:
        Env.mock ? Mock.canPrev : (player ? player.canGoPrevious : false)
    readonly property bool canSeek:
        Env.mock ? Mock.canSeek : (player ? (player.canSeek && player.positionSupported) : false)
    readonly property bool hasPlayer: Env.mock ? (title !== "") : (player !== null)

    // Position is NOT polled. Reading is always current, so the CONSUMER drives
    // the cadence and nothing ticks while no consumer displays position.
    function positionNow() {
        if (Env.mock) return Mock.position
        return player ? Math.round(player.position) : 0
    }

    function playPause() {
        if (Env.mock) { Mock.playing = !Mock.playing; return }
        if (!player) return
        if (playing) player.pause(); else player.play()
    }
    function next()     { if (Env.mock) { Mock.position = 0; return } if (player && canNext) player.next() }
    function previous() { if (Env.mock) { Mock.position = 0; return } if (player && canPrev) player.previous() }
}
