import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var searchMenuItem: NSMenuItem!
    private var loginMenuItem: NSMenuItem!
    private let search = SearchController()
    private let add = AddController()
    private let settings = SettingsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "clipboardpass")
        }

        let menu = NSMenu()
        menu.delegate = self
        searchMenuItem = menu.addItem(withTitle: searchTitle(), action: #selector(showSearch), keyEquivalent: "")
        searchMenuItem.target = self
        let addItem = menu.addItem(withTitle: "Add Password…", action: #selector(showAdd), keyEquivalent: "")
        addItem.target = self
        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        loginMenuItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginMenuItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit clipboardpass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        HotKeyManager.shared.setHandler { [weak self] in self?.search.toggle() }
        HotKeyManager.shared.apply(ShortcutStore.current)

        settings.onShortcutChange = { [weak self] shortcut in
            HotKeyManager.shared.apply(shortcut)
            self?.searchMenuItem.title = self?.searchTitle() ?? "Search Passwords"
        }
    }

    private func searchTitle() -> String {
        "Search Passwords  (\(ShortcutStore.current.display))"
    }

    // Refresh the checkmark each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        loginMenuItem.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func showSearch() { search.show() }
    @objc private func showAdd() { add.showWindow() }
    @objc private func showSettings() { settings.showWindow() }

    @objc private func toggleLaunchAtLogin() {
        let enable = !LoginItem.isEnabled
        let ok = LoginItem.setEnabled(enable)

        if enable {
            if LoginItem.requiresApproval {
                Notify.show(title: "Approval needed",
                            body: "Enable clipboardpass under Login Items in System Settings.")
                LoginItem.openSettings()
            } else if ok {
                Notify.show(title: "Launch at Login on", body: "clipboardpass will start automatically.")
            } else {
                Notify.show(title: "Couldn’t enable",
                            body: "Add clipboardpass manually in System Settings → Login Items.")
            }
        } else {
            Notify.show(title: "Launch at Login off", body: "clipboardpass won’t start automatically.")
        }
        loginMenuItem.state = LoginItem.isEnabled ? .on : .off
    }
}
