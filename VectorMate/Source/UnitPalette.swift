import AppKit
import Combine

/// 単位パレット: the unit sets in a list as BrowserSwitcher shows browsers. Tab / ↑↓ select, ⌘Return / ⌘-click /
/// double-click switch, Esc hides. A floating panel, so it stays above Illustrator while Illustrator is in front.
final class UnitPaletteWindow: NSPanel {
    var moveCandidate: ((Int) -> Void)?
    override var canBecomeKey: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            switch event.keyCode {
            case 53: performClose(nil); return
            case 48: moveCandidate?(event.modifierFlags.contains(.shift) ? -1 : 1); return
            case 125: moveCandidate?(1); return
            case 126: moveCandidate?(-1); return
            default: break
            }
        }
        super.sendEvent(event)
    }
    override func cancelOperation(_ sender: Any?) { performClose(nil) }
}

private final class UnitRowView: NSTableRowView {
    var isOddRow = false
    override func drawBackground(in dirtyRect: NSRect) {
        let colors = NSColor.alternatingContentBackgroundColors
        (isOddRow && colors.count > 1 ? colors[1] : colors[0]).setFill()
        bounds.fill()
    }
}

private final class UnitTableView: NSTableView {
    var activateRow: ((Int) -> Void)?
    func moveSelection(_ direction: Int) {
        let candidates = (0..<numberOfRows).filter { delegate?.tableView?(self, shouldSelectRow: $0) != false }
        guard !candidates.isEmpty else { return }
        let next: Int
        if let index = candidates.firstIndex(of: selectedRow) { next = candidates[(index + direction + candidates.count) % candidates.count] }
        else { next = direction > 0 ? candidates[0] : candidates[candidates.count - 1] }
        window?.makeFirstResponder(self)
        selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        scrollRowToVisible(next)
    }
    override func mouseDown(with event: NSEvent) {
        let clicked = row(at: convert(event.locationInWindow, from: nil))
        if event.modifierFlags.contains(.command) || event.clickCount == 2 {
            guard clicked >= 0, delegate?.tableView?(self, shouldSelectRow: clicked) != false else { return }
            selectRowIndexes(IndexSet(integer: clicked), byExtendingSelection: false)
            activateRow?(clicked)
            return
        }
        super.mouseDown(with: event)
    }
}

@MainActor
final class UnitPalette: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    static let rowHeight: CGFloat = 48
    /// Kept small: the palette floats over Illustrator's canvas.
    static let width: CGFloat = 230
    private let model: Model
    private var window: UnitPaletteWindow?
    private let table = UnitTableView()
    private let status = NSTextField(wrappingLabelWithString: "")
    private var switchButton: NSButton?
    private var selectedID: String?
    private var observers: Set<AnyCancellable> = []
    private var presets: [UnitSet] { model.unitSets }
    private var currentID: String? { UnitSettings.matching(model.units, in: model.unitSets) }
    private let basicRadio = NSButton(radioButtonWithTitle: L("palette.basic"), target: nil, action: nil)
    private let detailRadio = NSButton(radioButtonWithTitle: L("palette.detail"), target: nil, action: nil)
    private var scrollHeight: NSLayoutConstraint?

    init(model: Model) {
        self.model = model
        super.init()
        // The list follows the state the model reads (after a switch, on activation, on reload).
        model.$units.combineLatest(model.$busy, model.$unitResult).receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }.store(in: &observers)
        model.$unitSets.combineLatest(model.$unitDetail).receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }.store(in: &observers)
    }

    private lazy var visibility = IllustratorPaletteVisibility { [weak self] in self?.window }
    var isVisible: Bool { window?.isVisible == true }

    func show() {
        _ = visibility
        if window == nil { build() }
        model.refreshSettingsState()
        reload()
        if let window, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(table)
    }
    func toggle() { isVisible ? window?.performClose(nil) : show() }

    private func build() {
        let panel = UnitPaletteWindow(contentRect: NSRect(x: 0, y: 0, width: 230, height: 300),
                                      styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = L("palette.title")
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior.insert(.fullScreenAuxiliary)
        panel.delegate = self
        panel.moveCandidate = { [weak self] direction in self?.table.moveSelection(direction) }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("unit"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = Self.rowHeight
        table.intercellSpacing = .zero
        table.style = .plain
        table.selectionHighlightStyle = .regular
        table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.dataSource = self
        table.delegate = self
        table.activateRow = { [weak self] row in
            guard let self, self.presets.indices.contains(row) else { return }
            self.selectedID = self.presets[row].id
            self.performSwitch()
        }
        let scroll = NSScrollView()
        scroll.borderType = .lineBorder
        scroll.documentView = table
        scroll.translatesAutoresizingMaskIntoConstraints = false

        status.font = .systemFont(ofSize: 10)
        status.textColor = .secondaryLabelColor
        let change = NSButton(title: L("palette.switch"), target: self, action: #selector(performSwitch))
        change.bezelStyle = .rounded
        change.controlSize = .small
        change.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        change.keyEquivalent = "\r"
        change.keyEquivalentModifierMask = [.command]
        switchButton = change
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let actions = NSStackView(views: [spacer, change])
        actions.orientation = .horizontal

        basicRadio.target = self; basicRadio.action = #selector(modeChanged(_:))
        detailRadio.target = self; detailRadio.action = #selector(modeChanged(_:))
        // Standard macOS radio buttons (regular size and font), unlike the compact list below.
        let mode = NSStackView(views: [NSTextField(labelWithString: L("palette.mode")), basicRadio, detailRadio])
        mode.orientation = .horizontal
        mode.spacing = 8
        let edit = NSButton(title: L("palette.edit"), target: self, action: #selector(editSets))
        edit.bezelStyle = .rounded
        edit.controlSize = .small
        edit.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        actions.insertArrangedSubview(edit, at: 0)
        let stack = NSStackView(views: [mode, scroll, status, actions])
        stack.orientation = .vertical
        // The other rows are as wide as the stack, so only モード is centered.
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = panel.contentView!
        AppSurface.install(in: content)
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -10),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),

            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        scrollHeight = scroll.heightAnchor.constraint(equalToConstant: 0)
        scrollHeight?.isActive = true
        fitHeight()
        panel.center()
        panel.setFrameAutosaveName("VectorMateUnitPalette")
        window = panel
    }

    /// The list shows every set (at most 6 rows without scrolling).
    private func fitHeight() {
        let rows = CGFloat(max(1, min(presets.count, 6)))
        scrollHeight?.constant = rows * Self.rowHeight + 2
        window?.setContentSize(NSSize(width: Self.width, height: rows * Self.rowHeight + 96))
    }

    @objc private func modeChanged(_ sender: NSButton) { model.unitDetail = sender === detailRadio }
    @objc private func editSets() { (NSApp.delegate as? AppDelegate)?.openPreferences(tab: L("sets.tab")) }

    private func reload() {
        guard window != nil else { return }
        basicRadio.state = model.unitDetail ? .off : .on
        detailRadio.state = model.unitDetail ? .on : .off
        if let scrollHeight, scrollHeight.constant != CGFloat(max(1, min(presets.count, 6))) * Self.rowHeight + 2 { fitHeight() }
        if let selectedID, selectedID == currentID { self.selectedID = nil }
        table.reloadData()
        if let selectedID, let index = presets.firstIndex(where: { $0.id == selectedID }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        switchButton?.isEnabled = selectedID != nil && !model.busy && model.units != nil
        if model.busy { status.stringValue = L("working") }
        else if model.units == nil { status.stringValue = model.notRunningText }
        else if let result = model.unitResult { status.stringValue = result.text; status.textColor = result.isError ? .systemRed : .secondaryLabelColor; return }
        else { status.stringValue = L("palette.hint") }
        status.textColor = .secondaryLabelColor
    }

    func numberOfRows(in tableView: NSTableView) -> Int { presets.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        !model.busy && model.units != nil && presets[row].id != currentID
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedID = presets.indices.contains(table.selectedRow) ? presets[table.selectedRow].id : nil
        switchButton?.isEnabled = selectedID != nil && !model.busy && model.units != nil
    }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = UnitRowView()
        view.isOddRow = row.isMultiple(of: 2)
        return view
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let preset = presets[row]
        let current = preset.id == currentID
        let cell = NSTableCellView()
        let badge = NSTextField(labelWithString: UnitPalette.badge(preset))
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.alignment = .center
        badge.textColor = current ? .disabledControlTextColor : .controlAccentColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        let name = NSTextField(labelWithString: preset.name + (current ? L("palette.current") : ""))
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        name.textColor = current ? .disabledControlTextColor : .labelColor
        // One line in the list; the whole summary (increments and document settings in 詳細) is the tooltip.
        let summary = UnitPalette.summary(preset, detail: model.unitDetail)
        // 東アジア is left out of the row (it is in the tooltip).
        let detail = NSTextField(labelWithString: UnitPalette.unitsLine(preset, includeAsian: false))
        detail.font = .systemFont(ofSize: 10)
        detail.textColor = current ? .disabledControlTextColor : .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cell.toolTip = summary
        let text = NSStackView(views: [name, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 0
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(badge)
        cell.addSubview(text)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            badge.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 34),
            text.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 6),
            text.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -6),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        cell.setAccessibilityLabel(name.stringValue + ", " + detail.stringValue)
        return cell
    }

    /// 「mm\npt」: the 一般 unit over the 文字 unit.
    static func badge(_ set: UnitSet) -> String {
        let general = UnitSettings.label(code: set.units[0], popup: 0), type = UnitSettings.label(code: set.units[2], popup: 2)
        return general == type ? general : general + "\n" + type
    }
    /// 一般 mm／線 pt／文字 pt（／東アジア pt）.
    static func unitsLine(_ set: UnitSet, includeAsian: Bool) -> String {
        let names = ["units.general", "units.stroke", "units.type", "units.asian"]
        return (0..<(includeAsian ? 4 : 3)).map { L(names[$0]) + " " + UnitSettings.label(code: set.units[$0], popup: $0) }.joined(separator: L("palette.sep"))
    }
    /// The units, and in 詳細 the increments and document settings (the row's tooltip).
    static func summary(_ set: UnitSet, detail: Bool) -> String {
        var text = unitsLine(set, includeAsian: true)
        let increments = (0..<4).map { index -> String in
            let popup = UnitSettings.incrementUnitIndex[index]
            return UnitSettings.format(set.increments[index]) + UnitSettings.label(code: set.units[popup], popup: popup)
        }
        text += "\n" + String(format: L("palette.increments"), increments[0], increments[1], increments[2], increments[3])
        guard detail else { return text }
        var document: [String] = []
        if let mode = set.colorMode { document.append(mode == .cmyk ? "CMYK" : "RGB") }
        if let overprint = set.overprintPreview { document.append(L(overprint ? "palette.overprintOn" : "palette.overprintOff")) }
        if let resolution = set.rasterResolution { document.append("\(resolution)ppi") }
        if let snap = set.snapToPixel { document.append(L(snap ? "palette.snapOn" : "palette.snapOff")) }
        if let grid = set.gridMode { document.append(grid == .matchTop ? L("palette.gridMatchTop") : String(format: L("palette.gridColor"), set.gridHex ?? "FFFFFF")) }
        if !document.isEmpty { text += L("palette.sep") + document.joined(separator: L("palette.sep")) }
        return text
    }

    @objc func performSwitch() {
        guard !model.busy, let selectedID else { return }
        self.selectedID = nil
        model.applyUnitSet(selectedID)
    }

    func windowWillClose(_ notification: Notification) { selectedID = nil }
}

/// Keep palette interaction in this app possible, while hiding palettes over unrelated apps.
@MainActor
final class IllustratorPaletteVisibility {
    private let window: () -> NSWindow?
    private var suspended = false
    private var activation: NSObjectProtocol?
    private var closing: NSObjectProtocol?

    init(window: @escaping () -> NSWindow?) {
        self.window = window
        activation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        closing = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let panel = notification.object as? NSWindow, panel === self.window() else { return }
                self.suspended = false
            }
        }
    }

    deinit {
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        if let closing { NotificationCenter.default.removeObserver(closing) }
    }

    private func update() {
        guard let front = NSWorkspace.shared.frontmostApplication, let panel = window() else { return }
        if Illustrator.isIllustrator(front) {
            if suspended { suspended = false; panel.orderFrontRegardless() }
        } else if front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            if panel.isVisible { suspended = true; panel.orderOut(nil) }
        }
    }
}
