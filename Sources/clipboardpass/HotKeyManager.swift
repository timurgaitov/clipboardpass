import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hot key via the Carbon API (no Accessibility
/// permission required, unlike NSEvent global monitors). Supports re-binding.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    func setHandler(_ action: @escaping () -> Void) {
        handler = action
        installHandlerIfNeeded()
    }

    /// (Re)binds the global hot key. Safe to call repeatedly.
    func apply(_ shortcut: Shortcut) {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5050 /* 'CLPP' */), id: 1)
        RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData!).takeUnretainedValue()
            manager.handler?()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandlerRef)
    }
}
