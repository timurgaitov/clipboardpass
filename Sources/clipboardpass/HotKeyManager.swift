import AppKit
import Carbon.HIToolbox

/// Registers system-wide hot keys via the Carbon API (no Accessibility
/// permission required, unlike NSEvent global monitors). Supports re-binding.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var handler: ((ShortcutKind) -> Void)?

    func setHandler(_ action: @escaping (ShortcutKind) -> Void) {
        handler = action
        installHandlerIfNeeded()
    }

    /// (Re)binds the global hot key for `kind`. Safe to call repeatedly.
    /// Returns false if the combo couldn't be registered (e.g. already taken).
    @discardableResult
    func apply(_ shortcut: Shortcut, for kind: ShortcutKind) -> Bool {
        if let ref = hotKeyRefs.removeValue(forKey: kind.hotKeyID) {
            UnregisterEventHotKey(ref)
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5050 /* 'CLPP' */), id: kind.hotKeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeyRefs[kind.hotKeyID] = ref
        return true
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData!).takeUnretainedValue()
            if let kind = ShortcutKind.allCases.first(where: { $0.hotKeyID == id.id }) {
                manager.handler?(kind)
            }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandlerRef)
    }
}
