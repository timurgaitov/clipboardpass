import AppKit

/// Borderless panels won't accept keyboard focus unless we say so.
final class KeyablePanel: NSPanel {
    /// Gets first crack at ⌘-key chords (e.g. ⌘E) before the field editor.
    var onKeyEquivalent: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyEquivalent?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// Draws a rounded, inset accent highlight like Spotlight's results.
final class SpotlightRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let r = bounds.insetBy(dx: 10, dy: 3)
        let path = NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8)
        NSColor.controlAccentColor.withAlphaComponent(0.9).setFill()
        path.fill()
    }
}

/// Label on the left, username in a quieter color on the right.
final class EntryCellView: NSTableCellView {
    let nameField = NSTextField(labelWithString: "")
    let userField = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        nameField.font = NSFont.systemFont(ofSize: 15)
        nameField.lineBreakMode = .byTruncatingTail
        userField.font = NSFont.systemFont(ofSize: 13)
        userField.lineBreakMode = .byTruncatingMiddle
        userField.alignment = .right
        for f in [nameField, userField] {
            f.translatesAutoresizingMaskIntoConstraints = false
            addSubview(f)
        }
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        userField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        NSLayoutConstraint.activate([
            nameField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),
            userField.leadingAnchor.constraint(greaterThanOrEqualTo: nameField.trailingAnchor, constant: 16),
            userField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            userField.centerYAnchor.constraint(equalTo: centerYAnchor),
            userField.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.5),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ selected: Bool) {
        nameField.textColor = selected ? .white : .labelColor
        userField.textColor = selected ? NSColor.white.withAlphaComponent(0.8) : .secondaryLabelColor
    }
}

final class SearchController: NSObject, NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    /// What ⏎ does to the selected entry. Switching modes keeps the panel and
    /// the typed query.
    enum Mode {
        case password, username, edit, delete

        var placeholder: String {
            switch self {
            case .password: return "Password Search"
            case .username: return "Username Search"
            case .edit:     return "Edit Password"
            case .delete:   return "Delete Password"
            }
        }
        var badge: String {
            switch self {
            case .password: return "⏎ password"
            case .username: return "⏎ username"
            case .edit:     return "⏎ edit"
            case .delete:   return "⏎ delete"
            }
        }
    }

    /// Asked to open the edit form for an entry (⌘E).
    var onEdit: ((Entry) -> Void)?

    private let width: CGFloat = 680
    private let searchH: CGFloat = 58
    private let rowH: CGFloat = 44
    private let maxVisible = 6
    private let corner: CGFloat = 18

    private var panel: KeyablePanel!
    private var container: NSVisualEffectView!
    private let magnifier = NSImageView()
    private let field = NSTextField()
    private let modeBadge = NSTextField(labelWithString: "")
    private let separator = NSBox()
    private let scroll = NSScrollView()
    private let tableView = NSTableView()

    private(set) var mode: Mode = .password
    private var entries: [Entry] = []
    private var filtered: [Entry] = []
    private var originX: CGFloat = 0
    private var topY: CGFloat = 0
    // Set while we present our own modal (delete confirm) so the click-away
    // auto-hide doesn't fire when the panel temporarily loses key.
    private var suppressAutoHide = false

    override init() {
        super.init()
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        panel = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: width, height: searchH),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        panel.onKeyEquivalent = { [weak self] event in self?.handleKeyEquivalent(event) ?? false }

        container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: searchH))
        container.material = .menu
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = corner
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        // maskImage clips the vibrant material itself (cornerRadius alone leaves
        // square material poking past the rounded corners); masksToBounds clips
        // the subviews. Both together = fully rounded.
        container.maskImage = Self.roundedMask(radius: corner)
        panel.contentView = container

        magnifier.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        magnifier.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        magnifier.contentTintColor = .secondaryLabelColor
        container.addSubview(magnifier)

        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 26, weight: .light)
        field.textColor = .labelColor
        field.delegate = self
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        container.addSubview(field)

        modeBadge.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        modeBadge.textColor = .secondaryLabelColor
        modeBadge.alignment = .right
        container.addSubview(modeBadge)

        separator.boxType = .separator
        container.addSubview(separator)

        scroll.hasVerticalScroller = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.automaticallyAdjustsContentInsets = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.width = width - 20
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = rowH
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(activateSelection)
        scroll.documentView = tableView
        container.addSubview(scroll)

        applyMode()
    }

    /// A resizable rounded-rect mask so the material rounds at any panel height.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let d = radius * 2 + 1
        let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        img.resizingMode = .stretch
        return img
    }

    private func applyMode() {
        field.placeholderAttributedString = NSAttributedString(
            string: mode.placeholder,
            attributes: [.foregroundColor: NSColor.tertiaryLabelColor,
                         .font: NSFont.systemFont(ofSize: 26, weight: .light)])
        modeBadge.stringValue = mode.badge
    }

    // MARK: - Show / hide

    /// Hot-key behaviour: same mode again → hide; other mode → switch in place.
    func toggle(_ newMode: Mode) {
        if panel.isVisible {
            if newMode == mode { hide() } else { switchMode(newMode) }
        } else {
            show(newMode)
        }
    }

    func show(_ newMode: Mode = .password) {
        mode = newMode
        applyMode()
        entries = KeychainStore.list()
        filtered = entries
        field.stringValue = ""
        tableView.reloadData()

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            originX = sf.midX - width / 2
            topY = sf.maxY - sf.height * 0.18
        }
        relayout()
        selectFirstRow()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    private func switchMode(_ newMode: Mode) {
        mode = newMode
        applyMode()
        panel.makeFirstResponder(field)
    }

    func hide() { panel.orderOut(nil) }

    // Dismiss when the panel loses focus (click on another app/window/desktop),
    // unless we're showing our own modal (the delete confirmation).
    func windowDidResignKey(_ notification: Notification) {
        guard !suppressAutoHide, panel.isVisible else { return }
        hide()
    }

    /// Resizes the panel to fit the result count, keeping the search bar pinned
    /// to the top (Spotlight grows downward).
    private func relayout() {
        let count = filtered.count
        let hasResults = count > 0
        let visible = min(count, maxVisible)
        let resultsH = hasResults ? CGFloat(visible) * rowH + 12 : 0
        let sepH: CGFloat = hasResults ? 1 : 0
        let H = searchH + sepH + resultsH

        panel.setFrame(NSRect(x: originX, y: topY - H, width: width, height: H), display: true)
        container.frame = NSRect(x: 0, y: 0, width: width, height: H)

        let bandCenter = H - searchH / 2
        let badgeW: CGFloat = 96
        magnifier.frame = NSRect(x: 24, y: bandCenter - 13, width: 26, height: 26)
        field.frame = NSRect(x: 58, y: bandCenter - 19, width: width - 58 - badgeW - 32, height: 36)
        modeBadge.frame = NSRect(x: width - badgeW - 24, y: bandCenter - 9, width: badgeW, height: 18)

        separator.isHidden = !hasResults
        separator.frame = NSRect(x: 16, y: H - searchH, width: width - 32, height: 1)

        scroll.isHidden = !hasResults
        scroll.frame = NSRect(x: 0, y: 6, width: width, height: max(0, H - searchH - 6))
    }

    private func selectFirstRow() {
        if !filtered.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Filtering & key handling

    private func refilter() {
        let q = field.stringValue
        filtered = q.isEmpty ? entries : entries.filter { $0.label.localizedCaseInsensitiveContains(q) }
        tableView.reloadData()
        relayout()
    }

    func controlTextDidChange(_ obj: Notification) {
        refilter()
        selectFirstRow()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            activateSelection(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide(); return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(1); return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(-1); return true
        case #selector(NSStandardKeyBindingResponding.deleteToBeginningOfLine(_:)): // ⌘⌫
            deleteSelected(thenHide: false); return true
        default:
            return false
        }
    }

    private func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods == .command, event.charactersIgnoringModifiers == "e" else { return false }
        editSelected()
        return true
    }

    private var selectedEntry: Entry? {
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return nil }
        return filtered[row]
    }

    private func editSelected() {
        guard let entry = selectedEntry else { NSSound.beep(); return }
        hide()
        onEdit?(entry)
    }

    /// Confirms, then deletes. In delete mode the panel closes afterwards;
    /// via ⌘⌫ it stays open so several entries can be removed in a row.
    private func deleteSelected(thenHide: Bool) {
        let row = tableView.selectedRow
        guard let entry = selectedEntry else { return }

        let alert = NSAlert()
        alert.messageText = "Delete “\(entry.label)”?"
        alert.informativeText = "This removes the stored password from clipboardpass."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        suppressAutoHide = true
        let confirmed = alert.runModal() == .alertFirstButtonReturn
        suppressAutoHide = false
        panel.makeKeyAndOrderFront(nil)
        guard confirmed else { panel.makeFirstResponder(field); return }

        KeychainStore.delete(label: entry.label)
        Notify.show(title: "Deleted “\(entry.label)”", body: "Removed from clipboardpass.")
        if thenHide { hide(); return }
        entries = KeychainStore.list()
        refilter()
        if !filtered.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: min(row, filtered.count - 1)),
                                       byExtendingSelection: false)
        }
        panel.makeFirstResponder(field)
    }

    private func moveSelection(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        let next = max(0, min(filtered.count - 1, tableView.selectedRow + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    // MARK: - ⏎ action

    @objc private func activateSelection() {
        guard let entry = selectedEntry else { return }

        switch mode {
        case .edit:
            editSelected()
        case .delete:
            deleteSelected(thenHide: true)
        case .username:
            hide()
            // Usernames are plain keychain attributes, not secrets: no Touch ID.
            guard !entry.username.isEmpty else {
                Notify.show(title: "No username for “\(entry.label)”", body: "Press ⌘E in the search panel to add one.")
                return
            }
            Clipboard.copyPlain(entry.username)
            Notify.show(title: "Copied username for “\(entry.label)”", body: entry.username)
        case .password:
            hide() // return focus to the previous app before authenticating
            KeychainStore.secret(label: entry.label, reason: "unlock “\(entry.label)” to copy its password") { secret in
                guard let secret else { return }
                Clipboard.copy(secret)
                Notify.show(title: "Copied “\(entry.label)”",
                            body: "Password is on the clipboard. Clears in 45s.")
            }
        }
    }

    // MARK: - Table data source / delegate

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        SpotlightRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Refresh text colors so the selected row reads white on accent.
        tableView.enumerateAvailableRowViews { rowView, index in
            (rowView.view(atColumn: 0) as? EntryCellView)?.setSelected(index == tableView.selectedRow)
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell: EntryCellView
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? EntryCellView {
            cell = reused
        } else {
            cell = EntryCellView(frame: .zero)
            cell.identifier = id
        }
        let entry = filtered[row]
        cell.nameField.stringValue = entry.label
        cell.userField.stringValue = entry.username
        cell.setSelected(row == tableView.selectedRow)
        return cell
    }
}
