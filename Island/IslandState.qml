pragma Singleton
import QtQuick

// island-core §1 + §3. The canonical state machine and preemption matrix.
// Components own their CONTENT; they do not decide when they appear.
QtObject {
    id: root

    readonly property string rest: "rest"

    // priority: auth > user panels > osd > notification > rest
    // Principle: a direct response to something the user just did outranks
    // something unsolicited; a blocking request outranks everything.
    readonly property var priority: ({
        "rest": -1,
        "notification": 0,
        "osd": 1,
        "expanded": 2, "launcher": 2, "control": 2, "theme": 2,
        "wallpaper": 2, "settings": 2, "power": 2,
        "auth": 3
    })

    readonly property var keyboardFocus: ({
        "launcher": "Exclusive",
        "auth": "Exclusive"
        // everything else: None
    })

    property string current: rest
    property string _preempted: ""      // restored after auth (polkit §5)

    function prio(s) { return priority[s] !== undefined ? priority[s] : -1 }
    function isPanel(s) { return prio(s) === 2 }
    function focusFor(s) { return keyboardFocus[s] !== undefined ? keyboardFocus[s] : "None" }

    // Returns true if `next` is allowed to take the surface right now.
    function mayEnter(next) {
        if (next === current) return true
        return prio(next) >= prio(current)
    }

    function request(next) {
        if (!mayEnter(next)) return false
        if (next === "auth" && current !== "rest" && current !== "auth")
            _preempted = current                 // restore afterwards
        current = next
        return true
    }

    function release() {
        if (current === "auth" && _preempted !== "") {
            current = _preempted
            _preempted = ""
        } else {
            current = rest
        }
    }

    function toggle(s) {
        if (current === s) { release(); return }
        request(s)
    }
}
