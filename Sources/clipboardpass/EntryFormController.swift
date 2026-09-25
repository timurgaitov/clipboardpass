import AppKit

/// The Add / Edit window. One instance serves both: `showAdd()` starts blank,
/// `showEdit(_:)` prefills label + username and keeps the stored password
/// unless a new one is typed.
final class EntryFormController: NSObject {
    private var window: NSWindow!
    private let userField = NSTextField()
    private let passField = NSSecureTextField()
    private let labelField = NSTextField()
    private var saveButton: NSButton!
    /// Label of the entry being edited; nil while adding.
    private var editing: String?

    func showAdd() {
        if window == nil { build() }
        editing = nil
        window.title = "Add Password"
        saveButton.title = "Save"
        userField.stringValue = ""
        passField.stringValue = ""
        passField.placeholderString = "secret"
        labelField.stringValue = ""
        present(focus: userField)
    }

    func showEdit(_ entry: Entry) {
        if window == nil { build() }
        editing = entry.label
        window.title = "Edit “\(entry.label)”"
        saveButton.title = "Save Changes"
        userField.stringValue = entry.username
        passField.stringValue = ""
        passField.placeholderString = "leave blank to keep current"
        labelField.stringValue = entry.label
        present(focus: labelField)
    }

    private func present(focus: NSTextField) {
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(focus)
    }

    private func build() {
        let w: CGFloat = 400, h: CGFloat = 206
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false

        let c = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        func label(_ s: String, _ y: CGFloat) -> NSTextField {
            let l = NSTextField(labelWithString: s)
            l.frame = NSRect(x: 16, y: y, width: 80, height: 20)
            l.alignment = .right
            return l
        }
        func place(_ f: NSTextField, _ y: CGFloat, _ placeholder: String) {
            f.frame = NSRect(x: 104, y: y - 2, width: w - 120, height: 24)
            f.placeholderString = placeholder
        }

        c.addSubview(label("Username", h - 50)); place(userField, h - 50, "login");         c.addSubview(userField)
        c.addSubview(label("Password", h - 88)); place(passField, h - 88, "secret");           c.addSubview(passField)
        c.addSubview(label("Label", h - 126));   place(labelField, h - 126, "e.g. Work VPN");  c.addSubview(labelField)

        // Username → Password is the pairing macOS needs to offer password
        // AutoFill from the Passwords app: pick an item there and both fields
        // fill in. Tab order: Username → Password → Label.
        userField.contentType = .username
        passField.contentType = .password
        userField.nextKeyView = passField
        passField.nextKeyView = labelField
        labelField.nextKeyView = userField
        window.initialFirstResponder = userField

        saveButton = NSButton(title: "Save", target: self, action: #selector(saveEntry))
        saveButton.frame = NSRect(x: w - 140, y: 16, width: 124, height: 30)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        c.addSubview(saveButton)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.frame = NSRect(x: w - 242, y: 16, width: 96, height: 30)
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        c.addSubview(cancel)

        window.contentView = c
    }

    @objc private func saveEntry() {
        let label = labelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = userField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passField.stringValue
        guard !label.isEmpty, !username.isEmpty else { NSSound.beep(); return }

        let ok: Bool
        if let old = editing {
            ok = KeychainStore.update(label: old, newLabel: label, username: username,
                                      secret: password.isEmpty ? nil : password)
        } else {
            guard !password.isEmpty else { NSSound.beep(); return }
            ok = KeychainStore.add(label: label, username: username, secret: password)
        }

        if ok {
            window.orderOut(nil)
            Notify.show(title: editing == nil ? "Saved “\(label)”" : "Updated “\(label)”",
                        body: "Touch ID required to copy its password.")
        } else {
            NSSound.beep()
            Notify.show(title: "Couldn’t save “\(label)”",
                        body: "The keychain refused the change.")
        }
    }

    @objc private func cancel() {
        window.orderOut(nil)
    }
}
