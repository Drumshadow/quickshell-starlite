pragma Singleton
import QtQuick

// Single switch deciding whether services read real backends or mock state.
// Everything downstream is a BINDING, so flipping this at runtime propagates
// live — you can toggle mock mode without restarting the shell.
QtObject {
    // set true by dev/shell.qml; production shell.qml leaves it false
    property bool mock: false
}
