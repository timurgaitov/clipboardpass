import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var searchMenuItems: [ShortcutKind: NSMenuItem] = [:]
    private var loginMenuItem: NSMenuItem!
    private let search = SearchController()
    private let form = EntryFormController()
    private let settings = SettingsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "asterisk.circle.fill", accessibilityDescription: "clipboardpass")
        }

        let menu = NSMenu()
        menu.delegate = self
        // Alphabetical within each group.
        let addItem = menu.addItem(withTitle: "Add Password", action: #selector(showAdd), keyEquivalent: "")
        addItem.target = self
        let deleteItem = menu.addItem(withTitle: "Delete Password", action: #selector(showDeleteSearch), keyEquivalent: "")
        deleteItem.target = self
        let editItem = menu.addItem(withTitle: "Edit Password", action: #selector(showEditSearch), keyEquivalent: "")
        editItem.target = self
        let passItem = menu.addItem(withTitle: menuTitle(.password), action: #selector(showPasswordSearch), keyEquivalent: "")
        passItem.target = self
        searchMenuItems[.password] = passItem
        let userItem = menu.addItem(withTitle: menuTitle(.username), action: #selector(showUsernameSearch), keyEquivalent: "")
        userItem.target = self
        searchMenuItems[.username] = userItem
        menu.addItem(.separator())
        loginMenuItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginMenuItem.target = self
        let settingsItem = menu.addItem(withTitle: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit clipboardpass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        search.onEdit = { [weak self] entry in self?.form.showEdit(entry) }

        HotKeyManager.shared.setHandler { [weak self] kind in
            self?.search.toggle(kind == .password ? .password : .username)
        }
        for kind in ShortcutKind.allCases {
            bind(ShortcutStore.current(kind), for: kind)
        }

        settings.onShortcutChange = { [weak self] kind, shortcut in
            self?.bind(shortcut, for: kind)
            self?.searchMenuItems[kind]?.title = self?.menuTitle(kind) ?? kind.title
        }
    }

    private func bind(_ shortcut: Shortcut, for kind: ShortcutKind) {
        if !HotKeyManager.shared.apply(shortcut, for: kind) {
            Notify.show(title: "Couldn’t bind \(shortcut.display)",
                        body: "Another app may already use it. Pick a different combo in Settings.")
        }
    }

    private func menuTitle(_ kind: ShortcutKind) -> String {
        "\(kind.title)  (\(ShortcutStore.current(kind).display))"
    }

    // Refresh the checkmark each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        loginMenuItem.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func showPasswordSearch() { search.show(.password) }
    @objc private func showUsernameSearch() { search.show(.username) }
    @objc private func showAdd() { form.showAdd() }
    @objc private func showEditSearch() { search.show(.edit) }
    @objc private func showDeleteSearch() { search.show(.delete) }
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
