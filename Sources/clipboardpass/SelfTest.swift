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

        let label = "__clipboardpass_selftest__"
        KeychainStore.delete(label: label)

        check("add returns true", KeychainStore.add(label: label, secret: "s3cr3t"))
        check("list contains added label", KeychainStore.list().contains(label))

        _ = KeychainStore.add(label: label, secret: "s3cr3t-v2") // upsert
        check("upsert keeps a single entry",
              KeychainStore.list().filter { $0 == label }.count == 1)

        check("delete returns true", KeychainStore.delete(label: label))
        check("list no longer contains label", !KeychainStore.list().contains(label))

        // Sorting is case-insensitive and stable.
        let a = "__clipboardpass_a__", b = "__clipboardpass_B__", c = "__clipboardpass_c__"
        [a, b, c].forEach { _ = KeychainStore.add(label: $0, secret: "x") }
        let listed = KeychainStore.list().filter { $0.hasPrefix("__clipboardpass_") }
        check("list is case-insensitively sorted", listed == [a, b, c])
        [a, b, c].forEach { KeychainStore.delete(label: $0) }

        // Shortcut persistence round-trips; restore the user's real value after.
        let original = ShortcutStore.current
        ShortcutStore.save(Shortcut(keyCode: 49, carbonModifiers: 256, display: "⌘Space"))
        check("shortcut persists keyCode", ShortcutStore.current.keyCode == 49)
        check("shortcut persists display", ShortcutStore.current.display == "⌘Space")
        ShortcutStore.save(original)

        print(ok ? "ALL PASS" : "SOME FAILED")
        return ok
    }
}
