// Quickshell StarLite rice — entry point.
// Specs: ~/specs/quickshell-build-order.md (start there)
//
// Two layer surfaces, neither ever unmapped (island-core §2).
import Quickshell
import "Island"

ShellRoot {
    Island {}
    // TODO: bottom-edge gesture catcher (launcher §2 / island-core §2.4)
}
