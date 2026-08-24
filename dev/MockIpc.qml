import QtQuick
import Quickshell.Io
import "../Services" as Sys

// CLI control over the simulated system, for scripted testing:
//   qs ipc call mock volume 0.8
//   qs ipc call mock preset tablet
// Same values the MockPanel drives; services read them either way.
IpcHandler {
    target: "mock"
    function volume(v: real): void      { Sys.Mock.volume = v }
    function mute(): void               { Sys.Mock.muted = !Sys.Mock.muted }
    function brightness(v: real): void  { Sys.Mock.brightness = v }
    function battery(p: int): void      { Sys.Mock.batteryPercent = p }
    function charging(on: bool): void   { Sys.Mock.charging = on; Sys.Mock.acConnected = on }
    function wifi(bars: int): void      { Sys.Mock.wifiStrength = bars; Sys.Mock.wifiConnected = bars > 0 }
    function playing(on: bool): void    { Sys.Mock.playing = on }
    function preset(name: string): void { Sys.Mock.preset(name) }
    function keyboard(on: bool): void   { Sys.Mock.keyboardAttached = on }
    function tablet(on: bool): void     { Sys.Mock.tabletMode = on; Sys.Mock.pointerFine = !on }
    function launched(): string         { return Sys.Apps.lastLaunched }
    function inputmode(): string {
        return "touchTarget=" + Sys.InputMode.touchTarget
             + " density=" + Sys.InputMode.density
             + " osk=" + Sys.InputMode.oskNeeded
             + " hover=" + Sys.InputMode.hoverAvailable
    }
}
