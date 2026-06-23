import AppKit

/// A button that records a global shortcut: click it, then press the desired
/// key combination (must include at least one of ⌘/⌃/⌥). Esc cancels.
final class RecorderButton: NSButton {
    var onChange: ((Shortcut) -> Void)?
    private var monitor: Any?
    private var recording = false { didSet { refreshTitle() } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggle)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func refreshTitle() {
        title = recording ? "Press shortcut…  (Esc to cancel)" : ShortcutStore.current.display
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
        ShortcutStore.save(shortcut)
        stop()
        onChange?(shortcut)
    }
}

final class SettingsController: NSObject {
    /// Called after the shortcut changes, so the rest of the app can rebind.
    var onShortcutChange: ((Shortcut) -> Void)?

    private var window: NSWindow!
    private var recorder: RecorderButton!

    func showWindow() {
        if window == nil { build() }
        recorder.title = ShortcutStore.current.display
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w: CGFloat = 420, h: CGFloat = 140
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        window.title = "clipboardpass Settings"
        window.isReleasedWhenClosed = false

        let c = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let label = NSTextField(labelWithString: "Global shortcut:")
        label.frame = NSRect(x: 20, y: h - 64, width: 130, height: 22)
        c.addSubview(label)

        recorder = RecorderButton(frame: NSRect(x: 156, y: h - 68, width: 244, height: 30))
        recorder.onChange = { [weak self] shortcut in
            self?.recorder.title = shortcut.display
            self?.onShortcutChange?(shortcut)
        }
        c.addSubview(recorder)

        let hint = NSTextField(labelWithString: "Click, then press a combo including ⌘, ⌃, or ⌥.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 20, width: w - 40, height: 18)
        c.addSubview(hint)

        window.contentView = c
    }
}
