import AppKit

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run() ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Text fields only get ⌘X/⌘C/⌘V/⌘A when a main menu carries the standard
// Edit actions, even for an accessory app that never shows a menu bar.
app.mainMenu = MainMenu.build()
// Accessory: no Dock icon, runs as a menu-bar background app.
app.setActivationPolicy(.accessory)
app.run()
