pragma Singleton
import QtQuick

// Static glyph path data, 24x24 grid. PLACEHOLDERS — swap for the chosen
// permissive set and record the licence + attribution (icons §1, §12 q2).
QtObject {
    readonly property string lock:     "M7 11V8a5 5 0 0 1 10 0v3M5 11h14v10H5z"
    readonly property string power:    "M12 3v9M6.6 6.6a9 9 0 1 0 10.8 0"
    readonly property string reboot:   "M3 12a9 9 0 1 0 3-6.7M3 4v5h5"
    readonly property string logout:   "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"
    readonly property string moon:     "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"
    readonly property string search:   "M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.3-4.3"
    readonly property string close:    "M18 6 6 18M6 6l12 12"
    readonly property string chevronR: "M9 18l6-6-6-6"
    readonly property string chevronL: "M15 18l-6-6 6-6"
    readonly property string play:     "M6 4l14 8-14 8z"
    readonly property string pause:    "M8 5h3v14H8zM13 5h3v14h-3z"
    readonly property string next:     "M5 4l10 8-10 8zM17 4h2v16h-2z"
    readonly property string prev:     "M19 4L9 12l10 8zM5 4h2v16H5z"
    readonly property string palette:  "M12 21a9 9 0 1 1 9-9c0 2-1.5 3-3 3h-2a2 2 0 0 0 0 4c0 1-1 2-4 2z"
    readonly property string image:    "M3 5h18v14H3zM8 11a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM21 16l-5-5-6 6"
    readonly property string gear:     "M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-2.9 1.2 2 2 0 1 1-4 0 1.7 1.7 0 0 0-2.9-1.2l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.7 1.7 0 0 0 3 15a2 2 0 1 1 0-4 1.7 1.7 0 0 0 1.4-2.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.7 1.7 0 0 0 10 4.6a2 2 0 1 1 4 0 1.7 1.7 0 0 0 2.9 1.2l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1A1.7 1.7 0 0 0 21 11a2 2 0 1 1 0 4z"
    // Lucide (ISC) outlines, 24x24 / 2px -- icons step 7: the control-centre binaries
    readonly property string wifi:      "M12 20h.01M2 8.82a15 15 0 0 1 20 0M5 12.859a10 10 0 0 1 14 0M8.5 16.429a5 5 0 0 1 7 0"
    readonly property string bluetooth: "m7 7 10 10-5 5V2l5 5L7 17"
    readonly property string bellOff:   "M10.3 21a1.94 1.94 0 0 0 3.4 0M17 17H4c1.3-1.4 2-3.5 2-9M8.7 3A6 6 0 0 1 18 8c0 3.5.6 5.5 1.3 7M2 2l20 20"
    readonly property string bell:      "M10.3 21a1.94 1.94 0 0 0 3.4 0M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"
    readonly property string sun:       "M12 4V2M12 22v-2M4 12H2M22 12h-2M6.34 6.34 4.93 4.93M19.07 19.07l-1.41-1.41M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"
}
