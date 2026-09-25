import AppKit

/// A button that records a global shortcut: click it, then press the desired
/// key combination (must include at least one of ⌘/⌃/⌥). Esc cancels.
final class RecorderButton: NSButton {
    let kind: ShortcutKind
    var onChange: ((Shortcut) -> Void)?
    private var monitor: Any?
    private var recording = false { didSet { refreshTitle() } }

    init(kind: ShortcutKind, frame: NSRect) {
        self.kind = kind
        super.init(frame: frame)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggle)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError() }

    func refreshTitle() {
        title = recording ? "Press shortcut…  (Esc to cancel)" : ShortcutStore.current(kind).display
    }

    @objc private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event)
            return nil // swallow the event while recording
        }
    }

    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { stop(); return } // Esc cancels

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
            NSSound.beep() // require a modifier; keep recording
            return
        }

        let keyLabel = (event.charactersIgnoringModifiers ?? "").uppercased()
        let shortcut = Shortcut(keyCode: UInt32(event.keyCode),
                                carbonModifiers: carbonModifiers(from: flags),
                                display: modifierSymbols(from: flags) + keyLabel)

        // Refuse a combo the other hot key already uses.
        let other = ShortcutKind.allCases.first { $0 != kind }!
        if ShortcutStore.current(other) == shortcut { NSSound.beep(); return }

        ShortcutStore.save(shortcut, for: kind)
        stop()
        onChange?(shortcut)
    }
}

final class SettingsController: NSObject {
    /// Called after a shortcut changes, so the rest of the app can rebind.
    var onShortcutChange: ((ShortcutKind, Shortcut) -> Void)?

    private var window: NSWindow!
    private var recorders: [RecorderButton] = []

    func showWindow() {
        if window == nil { build() }
        recorders.forEach { $0.refreshTitle() }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w: CGFloat = 440, h: CGFloat = 176
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        window.title = "clipboardpass Settings"
        window.isReleasedWhenClosed = false

        let c = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let rows: [(String, ShortcutKind)] = [("Copy password:", .password), ("Copy username:", .username)]
        for (i, (text, kind)) in rows.enumerated() {
            let y = h - 64 - CGFloat(i) * 40
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 20, y: y, width: 130, height: 22)
            c.addSubview(label)

            let recorder = RecorderButton(kind: kind, frame: NSRect(x: 156, y: y - 4, width: 264, height: 30))
            recorder.onChange = { [weak self] shortcut in
                self?.onShortcutChange?(kind, shortcut)
            }
            c.addSubview(recorder)
            recorders.append(recorder)
        }

        let hint = NSTextField(labelWithString: "Click, then press a combo including ⌘, ⌃, or ⌥. Each opens the search panel; ⏎ copies that field.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 20, width: w - 40, height: 32)
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2
        c.addSubview(hint)

        window.contentView = c
    }
}
