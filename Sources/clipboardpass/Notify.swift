import AppKit

/// Lightweight self-contained HUD toast (no notification permission needed).
enum Notify {
    private static var hud: NSPanel?

    static func show(title: String, body: String) {
        hud?.orderOut(nil)

        let w: CGFloat = 340, h: CGFloat = 74
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        bg.layer?.masksToBounds = true

        let t = NSTextField(labelWithString: title)
        t.font = .boldSystemFont(ofSize: 14)
        t.frame = NSRect(x: 16, y: h - 36, width: w - 32, height: 20)
        t.lineBreakMode = .byTruncatingTail

        let b = NSTextField(labelWithString: body)
        b.font = .systemFont(ofSize: 12)
        b.textColor = .secondaryLabelColor
        b.frame = NSRect(x: 16, y: 12, width: w - 32, height: 18)
        b.lineBreakMode = .byTruncatingTail

        bg.addSubview(t)
        bg.addSubview(b)
        panel.contentView = bg

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: sf.maxX - w - 20, y: sf.maxY - h - 20))
        }
        panel.orderFrontRegardless()
        hud = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if hud === panel {
                panel.orderOut(nil)
                hud = nil
            }
        }
    }
}
