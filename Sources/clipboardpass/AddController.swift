import AppKit

final class AddController: NSObject {
    private var window: NSWindow!
    private let labelField = NSTextField()
    private let passField = NSSecureTextField()

    func showWindow() {
        if window == nil { build() }
        labelField.stringValue = ""
        passField.stringValue = ""
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(passField)
    }

    private func build() {
        let w: CGFloat = 400, h: CGFloat = 168
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        window.title = "Add Password"
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

        // Password first so macOS AutoFill has no preceding text field to drop
        // the login into; Label below stays whatever the user types.
        c.addSubview(label("Password", h - 50)); place(passField, h - 50, "secret");          c.addSubview(passField)
        c.addSubview(label("Label", h - 88));    place(labelField, h - 88, "e.g. Work VPN");  c.addSubview(labelField)

        // One-directional key loop: nothing points to passField, so it has no
        // previousKeyView for AutoFill to treat as the username field.
        passField.nextKeyView = labelField
        window.initialFirstResponder = passField

        let save = NSButton(title: "Save", target: self, action: #selector(saveEntry))
        save.frame = NSRect(x: w - 112, y: 16, width: 96, height: 30)
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        c.addSubview(save)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.frame = NSRect(x: w - 214, y: 16, width: 96, height: 30)
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        c.addSubview(cancel)

        window.contentView = c
    }

    @objc private func saveEntry() {
        let label = labelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !passField.stringValue.isEmpty else { NSSound.beep(); return }
        if KeychainStore.add(label: label, secret: passField.stringValue) {
            window.orderOut(nil)
            Notify.show(title: "Saved “\(label)”", body: "Touch ID required to copy it.")
        } else {
            NSSound.beep()
            Notify.show(title: "Couldn’t save “\(label)”",
                        body: "A device passcode is required for protected items.")
        }
    }

    @objc private func cancel() {
        window.orderOut(nil)
    }
}
