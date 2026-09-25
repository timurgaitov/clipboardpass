import Foundation

/// Headless checks for the non-interactive logic. Run with `clipboardpass --selftest`.
/// The Touch ID-gated read path (secret(label:reason:)) requires user presence
/// and must be verified interactively.
enum SelfTest {
    static func run() -> Bool {
        var ok = true
        func check(_ name: String, _ cond: Bool) {
            print((cond ? "PASS" : "FAIL") + ": " + name)
            if !cond { ok = false }
        }
        func entry(_ label: String) -> Entry? { KeychainStore.list().first { $0.label == label } }

        let label = "__clipboardpass_selftest__"
        let renamed = "__clipboardpass_selftest_renamed__"
        KeychainStore.delete(label: label)
        KeychainStore.delete(label: renamed)

        check("add returns true", KeychainStore.add(label: label, username: "alice", secret: "s3cr3t"))
        check("list contains added label", entry(label) != nil)
        check("list carries username", entry(label)?.username == "alice")

        _ = KeychainStore.add(label: label, secret: "s3cr3t-v2") // upsert
        check("upsert keeps a single entry",
              KeychainStore.list().filter { $0.label == label }.count == 1)
        check("upsert without username clears it", entry(label)?.username == "")

        check("update returns true",
              KeychainStore.update(label: label, newLabel: renamed, username: "bob", secret: nil))
        check("update renames the entry", entry(label) == nil && entry(renamed) != nil)
        check("update sets username", entry(renamed)?.username == "bob")

        check("delete returns true", KeychainStore.delete(label: renamed))
        check("list no longer contains label", entry(renamed) == nil)

        // Sorting is case-insensitive and stable.
        let a = "__clipboardpass_a__", b = "__clipboardpass_B__", c = "__clipboardpass_c__"
        [a, b, c].forEach { _ = KeychainStore.add(label: $0, secret: "x") }
        let listed = KeychainStore.list().map(\.label).filter { $0.hasPrefix("__clipboardpass_") }
        check("list is case-insensitively sorted", listed == [a, b, c])
        [a, b, c].forEach { KeychainStore.delete(label: $0) }

        // Shortcut persistence round-trips; restore the user's real values after.
        for kind in ShortcutKind.allCases {
            let original = ShortcutStore.current(kind)
            ShortcutStore.save(Shortcut(keyCode: 49, carbonModifiers: 256, display: "⌘Space"), for: kind)
            check("\(kind) shortcut persists keyCode", ShortcutStore.current(kind).keyCode == 49)
            check("\(kind) shortcut persists display", ShortcutStore.current(kind).display == "⌘Space")
            ShortcutStore.save(original, for: kind)
        }
        check("shortcut kinds have distinct defaults",
              ShortcutKind.password.defaultShortcut != ShortcutKind.username.defaultShortcut)

        print(ok ? "ALL PASS" : "SOME FAILED")
        return ok
    }
}
