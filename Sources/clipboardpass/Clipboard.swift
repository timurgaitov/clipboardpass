import AppKit

enum Clipboard {
    /// Copies a secret and clears it after `seconds`, but only if the user
    /// hasn't copied something else in the meantime. Marks the entry as
    /// concealed so well-behaved clipboard managers won't store it.
    static func copy(_ secret: String, clearAfter seconds: TimeInterval = 45) {
        let pb = NSPasteboard.general
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        pb.clearContents()
        pb.declareTypes([.string, concealed], owner: nil)
        pb.setString(secret, forType: .string)
        pb.setString(secret, forType: concealed)

        let changeCount = pb.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
