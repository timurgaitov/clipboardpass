import AppKit
import Carbon.HIToolbox

struct Shortcut {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    /// Default: ⌘\  (kVK_ANSI_Backslash = 0x2A)
    static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_Backslash),
                                    carbonModifiers: UInt32(cmdKey),
                                    display: "⌘\\")
}

enum ShortcutStore {
    private static let d = UserDefaults.standard
    private static let kKey = "hotkey.keyCode"
    private static let kMods = "hotkey.carbonModifiers"
    private static let kDisplay = "hotkey.display"

    static var current: Shortcut {
        guard d.object(forKey: kKey) != nil else { return .default }
        return Shortcut(keyCode: UInt32(d.integer(forKey: kKey)),
                        carbonModifiers: UInt32(d.integer(forKey: kMods)),
                        display: d.string(forKey: kDisplay) ?? Shortcut.default.display)
    }

    static func save(_ s: Shortcut) {
        d.set(Int(s.keyCode), forKey: kKey)
        d.set(Int(s.carbonModifiers), forKey: kMods)
        d.set(s.display, forKey: kDisplay)
    }
}

/// Translates Cocoa modifier flags into the Carbon masks RegisterEventHotKey wants.
func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.command) { m |= UInt32(cmdKey) }
    if flags.contains(.option)  { m |= UInt32(optionKey) }
    if flags.contains(.control) { m |= UInt32(controlKey) }
    if flags.contains(.shift)   { m |= UInt32(shiftKey) }
    return m
}

/// Conventional modifier glyph order: ⌃⌥⇧⌘
func modifierSymbols(from flags: NSEvent.ModifierFlags) -> String {
    var s = ""
    if flags.contains(.control) { s += "⌃" }
    if flags.contains(.option)  { s += "⌥" }
    if flags.contains(.shift)   { s += "⇧" }
    if flags.contains(.command) { s += "⌘" }
    return s
}
