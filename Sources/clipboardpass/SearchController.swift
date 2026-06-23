import AppKit

/// Borderless panels won't accept keyboard focus unless we say so.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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

final class SearchController: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let width: CGFloat = 680
    private let searchH: CGFloat = 58
    private let rowH: CGFloat = 44
    private let maxVisible = 6
    private let corner: CGFloat = 18

    private var panel: KeyablePanel!
    private var container: NSVisualEffectView!
    private let magnifier = NSImageView()
    private let field = NSTextField()
    private let separator = NSBox()
    private let scroll = NSScrollView()
    private let tableView = NSTableView()

    private var entries: [String] = []
    private var filtered: [String] = []
    private var originX: CGFloat = 0
    private var topY: CGFloat = 0

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
        field.placeholderAttributedString = NSAttributedString(
            string: "Password label",
            attributes: [.foregroundColor: NSColor.tertiaryLabelColor,
                         .font: NSFont.systemFont(ofSize: 26, weight: .light)])
        container.addSubview(field)

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

    // MARK: - Show / hide

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
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

    func hide() { panel.orderOut(nil) }

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
        magnifier.frame = NSRect(x: 24, y: bandCenter - 13, width: 26, height: 26)
        field.frame = NSRect(x: 58, y: bandCenter - 19, width: width - 58 - 24, height: 36)

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

    func controlTextDidChange(_ obj: Notification) {
        let q = field.stringValue
        filtered = q.isEmpty ? entries : entries.filter { $0.localizedCaseInsensitiveContains(q) }
        tableView.reloadData()
        relayout()
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
            deleteSelected(); return true
        default:
            return false
        }
    }

    private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        let label = filtered[row]

        let alert = NSAlert()
        alert.messageText = "Delete “\(label)”?"
        alert.informativeText = "This removes the stored password from clipboardpass."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let confirmed = alert.runModal() == .alertFirstButtonReturn
        guard confirmed else { panel.makeFirstResponder(field); return }

        KeychainStore.delete(label: label)
        entries = KeychainStore.list()
        let q = field.stringValue
        filtered = q.isEmpty ? entries : entries.filter { $0.localizedCaseInsensitiveContains(q) }
        tableView.reloadData()
        relayout()
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

    // MARK: - Copy (Touch ID gated)

    @objc private func activateSelection() {
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        let label = filtered[row]
        hide() // return focus to the previous app before authenticating
        // Touch ID is enforced by the Secure Enclave inside secret(label:reason:):
        // the keychain won't release the data until the context is satisfied.
        KeychainStore.secret(label: label, reason: "unlock “\(label)” to copy its password") { secret in
            guard let secret else { return }
            Clipboard.copy(secret)
            Notify.show(title: "Copied “\(label)”",
                        body: "Password is on the clipboard. Clears in 45s.")
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
            if let cell = rowView.view(atColumn: 0) as? NSTableCellView {
                cell.textField?.textColor = (index == tableView.selectedRow) ? .white : .labelColor
            }
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 20),
                tf.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -20),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = filtered[row]
        cell.textField?.font = NSFont.systemFont(ofSize: 15)
        cell.textField?.textColor = (row == tableView.selectedRow) ? .white : .labelColor
        return cell
    }
}
