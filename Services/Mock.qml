pragma Singleton
import QtQuick

// The simulated system. Every value the shell can react to, in one place,
// settable from the mock control panel (dev/MockPanel.qml) or over IPC
// (`qs ipc call mock ...`).
//
// This is the ONLY file that knows what a fake system looks like. Services
// read it; UI components never do.
QtObject {
    id: mock

    // --- power ---
    property int  batteryPercent: 72
    property bool charging: false
    property bool acConnected: false
    property int  chargeCap: 80          // StarLite-style threshold; 100 = none
    property int  timeToEmpty: 9000      // seconds

    // --- audio ---
    property real volume: 0.55
    property bool muted: false
    property string sinkName: "Mock Analog Output"

    // --- brightness ---
    property real brightness: 0.7

    // --- network ---
    property bool wifiEnabled: true
    property bool wifiConnected: true
    property int  wifiStrength: 3        // 0..4, already quantised
    property string ssid: "Mock 5G"

    // --- bluetooth ---
    property bool btEnabled: false
    property var  btDevices: [
        { name: "WF-1000XM5",       connected: false },
        { name: "OnePlus Nord Buds 2", connected: false }
    ]

    // --- media ---
    property bool  playing: true
    property string title: "IRIS OUT"
    property string artist: "Kenshi Yonezu"
    property int   position: 42
    property int   length: 231
    property bool  canNext: true
    property bool  canPrev: true
    property bool  canSeek: true

    // --- input / form factor (the adaptive-behaviour inputs) ---
    property bool   tabletMode: false
    property bool   keyboardAttached: true
    property string orientation: "landscape"   // landscape | portrait
    property bool   pointerFine: true          // a mouse/touchpad is present

    // --- notifications ---
    property bool peaceMode: false
    property int  notificationCount: 2
    property bool needsAttention: false

    // --- session ---
    property bool locked: false
    property bool idle: false

    // Convenience presets — one call to reach a whole device posture.
    function preset(name) {
        if (name === "laptop") {
            tabletMode = false; keyboardAttached = true;
            orientation = "landscape"; pointerFine = true
        } else if (name === "tablet") {
            tabletMode = true; keyboardAttached = false;
            orientation = "landscape"; pointerFine = false
        } else if (name === "tablet-portrait") {
            tabletMode = true; keyboardAttached = false;
            orientation = "portrait"; pointerFine = false
        } else if (name === "low-battery") {
            batteryPercent = 8; charging = false; acConnected = false
        } else if (name === "charging") {
            charging = true; acConnected = true; batteryPercent = 64
        } else if (name === "at-cap") {
            charging = false; acConnected = true; batteryPercent = chargeCap
        } else if (name === "offline") {
            wifiConnected = false; wifiStrength = 0
        }
    }
}
