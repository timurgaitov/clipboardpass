import AppKit
import Carbon.HIToolbox

struct Shortcut: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String
}

/// The two global hot keys: one opens the panel to copy a password, the other
/// to copy a username.
enum ShortcutKind: CaseIterable {
    case password, username

    /// Identifier passed to RegisterEventHotKey so the handler can tell them apart.
    var hotKeyID: UInt32 {
        switch self {
        case .password: return 1
        case .username: return 2
        }
    }

    /// Defaults: ⌘\ for passwords, ⌘⇧\ for usernames (kVK_ANSI_Backslash = 0x2A).
    var defaultShortcut: Shortcut {
        switch self {
        case .password:
            return Shortcut(keyCode: UInt32(kVK_ANSI_Backslash),
                            carbonModifiers: UInt32(cmdKey), display: "⌘\\")
        case .username:
            return Shortcut(keyCode: UInt32(kVK_ANSI_Backslash),
                            carbonModifiers: UInt32(cmdKey | shiftKey), display: "⇧⌘\\")
        }
    }

    var title: String {
        switch self {
        case .password: return "Search Passwords"
        case .username: return "Search Usernames"
        }
    }

    // The password keys keep their 1.0.x names so existing settings carry over.
    fileprivate var defaultsPrefix: String {
        switch self {
        case .password: return "hotkey"
        case .username: return "hotkey.username"
        }
    }
}

enum ShortcutStore {
    private static let d = UserDefaults.standard

    static func current(_ kind: ShortcutKind = .password) -> Shortcut {
        let p = kind.defaultsPrefix
        guard d.object(forKey: p + ".keyCode") != nil else { return kind.defaultShortcut }
        return Shortcut(keyCode: UInt32(d.integer(forKey: p + ".keyCode")),
                        carbonModifiers: UInt32(d.integer(forKey: p + ".carbonModifiers")),
                        display: d.string(forKey: p + ".display") ?? kind.defaultShortcut.display)
    }

    static func save(_ s: Shortcut, for kind: ShortcutKind = .password) {
        let p = kind.defaultsPrefix
        d.set(Int(s.keyCode), forKey: p + ".keyCode")
        d.set(Int(s.carbonModifiers), forKey: p + ".carbonModifiers")
        d.set(s.display, forKey: p + ".display")
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
