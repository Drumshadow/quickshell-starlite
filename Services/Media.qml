pragma Singleton
import QtQuick

// MPRIS. Position is NOT polled — see docs/quickshell-media.md §4: reading is
// cheap and always current, so the consumer drives the cadence, and nothing
// ticks while no consumer displays position.
QtObject {
    id: root
    readonly property bool playing:  Env.mock ? Mock.playing : _realPlaying
    readonly property string title:  Env.mock ? Mock.title   : _realTitle
    readonly property string artist: Env.mock ? Mock.artist  : _realArtist
    readonly property int position:  Env.mock ? Mock.position : _realPosition
    readonly property int length:    Env.mock ? Mock.length   : _realLength
    readonly property bool canNext:  Env.mock ? Mock.canNext  : _realCanNext
    readonly property bool canPrev:  Env.mock ? Mock.canPrev  : _realCanPrev
    readonly property bool canSeek:  Env.mock ? Mock.canSeek  : _realCanSeek
    readonly property bool hasPlayer: title !== ""

    // TODO(real): Quickshell.Services.Mpris. Player selection needs STICKINESS —
    // browsers register a player per tab (docs: media §1). Art must be fetched on
    // trackArtUrl changing, NOT on track change (docs: media §2).
    property bool _realPlaying: false
    property string _realTitle: ""
    property string _realArtist: ""
    property int _realPosition: 0
    property int _realLength: 0
    property bool _realCanNext: false
    property bool _realCanPrev: false
    property bool _realCanSeek: false

    function playPause() { if (Env.mock) Mock.playing = !Mock.playing }
    function next()      { if (Env.mock && Mock.canNext) Mock.position = 0 }
    function previous()  { if (Env.mock && Mock.canPrev) Mock.position = 0 }
}
