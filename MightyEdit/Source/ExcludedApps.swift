import AppKit
import UniformTypeIdentifiers

/// Settings tab and front-app checks for 対象外アプリ (B21). Mirrors KakkoReplace's
/// excluded list: Bundle ID, no duplicates, hotkeys released while an excluded app is front.
final class ExcludedApps: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = ExcludedApps()
    static var title: String { L("excluded.title") }
    static var reason: String { L("excluded.reason") }
    private(set) var list = ExcludedAppList(ownID: Bundle.main.bundleIdentifier ?? "jp.local.TextPalette")
    /// Called when the front app changes or the list is edited; owners re-check hotkey registration.
    var onChange: (() -> Void)?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var observer: NSObjectProtocol?
    private var table: NSTableView?
    private var removeButton: NSButton?
    private let note = NSTextField(wrappingLabelWithString: "")

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                      object: nil, queue: .main) { [weak self] _ in self?.onChange?() }
    }
    deinit { if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }

    func isExcluded(_ app: NSRunningApplication?) -> Bool { list.excludes(app?.bundleIdentifier) }
    func isExcluded(pid: pid_t?) -> Bool { isExcluded(pid.flatMap { NSRunningApplication(processIdentifier: $0) }) }
    var hotkeysBlocked: Bool {
        let front = NSWorkspace.shared.frontmostApplication
        return list.blocksHotkeys(bundleID: front?.bundleIdentifier, pid: front?.processIdentifier, ownPID: ownPID)
    }

    @MainActor func settingsView() -> NSView {
        let heading = NSTextField(labelWithString: Self.title)
        heading.font = .boldSystemFont(ofSize: 18)
        let explanation = NSTextField(wrappingLabelWithString: L("excluded.explanation"))
        let table = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.title = L("excluded.column")
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 36
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self; table.delegate = self
        table.setAccessibilityLabel(L("excluded.axList"))
        self.table = table
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 200).isActive = true
        let add = NSButton(title: L("excluded.add"), target: self, action: #selector(addApplications))
        let remove = NSButton(title: L("excluded.remove"), target: self, action: #selector(removeSelected))
        for button in [add, remove] { button.bezelStyle = .rounded }
        remove.isEnabled = false
        removeButton = remove
        let buttons = NSStackView(views: [add, remove]); buttons.spacing = 8
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor
        let group = SettingsUI.group(Self.title, [explanation, scroll, buttons, note])
        let stack = NSStackView(views: [heading, group])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = ExcludedAppsDocumentView(); document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
            group.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        let page = NSScrollView(); page.hasVerticalScroller = true; page.drawsBackground = false
        page.documentView = document
        document.widthAnchor.constraint(equalTo: page.contentView.widthAnchor).isActive = true
        refresh()
        return page
    }

    private func refresh() {
        table?.reloadData()
        removeButton?.isEnabled = !(table?.selectedRowIndexes.isEmpty ?? true)
        note.stringValue = list.ids.isEmpty ? L("excluded.none") : L("excluded.count", String(list.ids.count))
    }
    private func commit() { list.save(); refresh(); onChange?() }

    /// Name and icon come from the installed app; a missing app shows its Bundle ID.
    private func describe(_ id: String) -> (name: String, icon: NSImage, missing: Bool) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            let name = Self.displayName(url)
            return (name, NSWorkspace.shared.icon(forFile: url.path), false)
        }
        return (id, NSWorkspace.shared.icon(for: .applicationBundle), true)
    }

    private static func displayName(_ url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    func numberOfRows(in tableView: NSTableView) -> Int { list.ids.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = list.ids[row]
        let info = describe(id)
        let icon = NSImageView(image: info.icon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        icon.setAccessibilityElement(false)
        let name = NSTextField(labelWithString: info.name)
        name.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(labelWithString: info.missing ? L("excluded.missing") : id)
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        let text = NSStackView(views: [name, detail]); text.orientation = .vertical; text.alignment = .leading; text.spacing = 0
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [icon, text]); row.spacing = 8; row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        row.toolTip = id
        row.setAccessibilityElement(true); row.setAccessibilityLabel(L("fmt.nameDetail", info.name, id))
        return row
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        removeButton?.isEnabled = !(table?.selectedRowIndexes.isEmpty ?? true)
    }

    @objc private func removeSelected() {
        guard let table else { return }
        let ids = table.selectedRowIndexes.compactMap { list.ids.indices.contains($0) ? list.ids[$0] : nil }
        guard !ids.isEmpty else { return }
        ids.forEach { list.remove($0) }
        table.deselectAll(nil)
        commit()
    }

    @objc private func addApplications() {
        let picker = NSOpenPanel()
        picker.title = L("excluded.pickerTitle")
        picker.prompt = L("action.add")
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK else { return }
            var rejected: [String] = []
            for url in picker.urls {
                let name = Self.displayName(url)
                switch self.list.add(Bundle(url: url)?.bundleIdentifier) {
                case .added: break
                case .duplicate: rejected.append(L("excluded.duplicate", name))
                case .own: rejected.append(L("excluded.own"))
                case .invalid: rejected.append(L("excluded.invalid", name))
                }
            }
            self.commit()
            guard !rejected.isEmpty else { return }
            let alert = NSAlert()
            alert.messageText = L("excluded.rejectedTitle")
            alert.informativeText = rejected.joined(separator: "\n")
            DispatchQueue.main.async { // after the open panel's sheet has ended
                if let window = self.table?.window { alert.beginSheetModal(for: window) } else { alert.runModal() }
            }
        }
        if let window = table?.window { picker.beginSheetModal(for: window, completionHandler: completion) }
        else { picker.begin(completionHandler: completion) }
    }
}

private final class ExcludedAppsDocumentView: NSView { override var isFlipped: Bool { true } }
