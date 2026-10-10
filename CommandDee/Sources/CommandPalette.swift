import AppKit

/// Floating palette that never takes focus, so Finder / Path Finder keeps its selection while a button is clicked.
final class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// One action row: icon, title and hotkey on top, the resulting name below.
final class PaletteActionButton: NSButton {
    var shortcutLabel = "" { didSet { needsDisplay = true } }
    var preview = NSAttributedString() { didSet { needsDisplay = true } }
    var isHovered = false { didSet { needsDisplay = true } }
    private var hoverArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = PaletteActionCell(textCell: "")
        setButtonType(.momentaryChange)
        isBordered = false
        refusesFirstResponder = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 54) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

final class PaletteActionCell: NSButtonCell {
    override func draw(withFrame frame: NSRect, in controlView: NSView) {
        guard let button = controlView as? PaletteActionButton else { return }
        let hovered = button.isHovered && isEnabled
        let pressed = isHighlighted && isEnabled
        let shape = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        (pressed ? NSColor.controlAccentColor.withAlphaComponent(0.24)
            : hovered ? NSColor.controlAccentColor.withAlphaComponent(0.10)
            : NSColor.labelColor.withAlphaComponent(0.065)).setFill()
        shape.fill()
        if hovered || pressed {
            NSColor.controlAccentColor.withAlphaComponent(pressed ? 0.8 : 0.4).setStroke()
            shape.lineWidth = 1
            shape.stroke()
        }
        let color = isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor
        let flipped = controlView.isFlipped
        func y(_ top: CGFloat, _ height: CGFloat) -> CGFloat { flipped ? frame.minY + top : frame.maxY - top - height }
        if let icon = image?.withSymbolConfiguration(.init(paletteColors: [isEnabled ? .controlAccentColor : .disabledControlTextColor])) {
            let scale = min(22 / icon.size.width, 22 / icon.size.height)
            let size = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
            icon.draw(in: NSRect(x: frame.minX + 12 + (22 - size.width) / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height),
                      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        let textX = frame.minX + 46
        let shortcutAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        let shortcutWidth = ceil((button.shortcutLabel as NSString).size(withAttributes: shortcutAttributes).width)
        (button.shortcutLabel as NSString).draw(at: NSPoint(x: frame.maxX - 12 - shortcutWidth, y: y(10, 15)), withAttributes: shortcutAttributes)
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(with: NSRect(x: textX, y: y(9, 17), width: frame.maxX - 12 - shortcutWidth - 8 - textX, height: 17),
                                 options: .usesLineFragmentOrigin,
                                 attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .regular), .foregroundColor: color, .paragraphStyle: titleStyle])
        let preview = NSMutableAttributedString(attributedString: button.preview)
        let previewStyle = NSMutableParagraphStyle()
        previewStyle.lineBreakMode = .byTruncatingMiddle
        preview.addAttribute(.paragraphStyle, value: previewStyle, range: NSRange(location: 0, length: preview.length))
        preview.draw(with: NSRect(x: textX, y: y(30, 16), width: frame.maxX - 12 - textX, height: 16), options: .usesLineFragmentOrigin)
    }
}

/// The selection the palette previews: which browser it came from and the selected items.
struct PaletteTarget: Equatable {
    let bundleID: String
    let pid: pid_t
    let files: [URL]
}

final class CommandPalette: NSObject, NSWindowDelegate {
    static let visibleKey = "paletteVisible"
    private let panel: CommandPalettePanel
    private let targetLabel = NSTextField(labelWithString: "")
    private var buttons: [PaletteActionButton] = []
    /// Palette only (1.8.22): opens the status list instead of running directly; never has a hotkey.
    private let statusButton = PaletteActionButton(frame: .zero)
    private var timer: Timer?
    private(set) var target: PaletteTarget?
    private let perform: (Duplicator.Mode, PaletteTarget) -> Void
    private let isBusy: () -> Bool
    private static let symbols = ["plus.square.on.square", "calendar", "calendar.badge.plus", "pencil.and.list.clipboard", "folder", "arrow.left.arrow.right"]

    init(perform: @escaping (Duplicator.Mode, PaletteTarget) -> Void, isBusy: @escaping () -> Bool,
         openSettings: Selector, settingsTarget: AnyObject) {
        self.perform = perform
        self.isBusy = isBusy
        panel = CommandPalettePanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
                                    styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel, .utilityWindow],
                                    backing: .buffered, defer: false)
        super.init()
        panel.title = ""
        panel.isExcludedFromWindowsMenu = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentMinSize = NSSize(width: 300, height: 200)
        panel.delegate = self
        let content = NSView()
        AppSurface.install(in: content)
        panel.contentView = content
        let header = appHeader("CommandDee", subtitle: L("palette.subtitle"), size: 32)
        targetLabel.font = .systemFont(ofSize: 11, weight: .medium)
        targetLabel.textColor = .secondaryLabelColor
        targetLabel.lineBreakMode = .byTruncatingMiddle
        targetLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let column = NSStackView(views: [header, targetLabel])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.setCustomSpacing(12, after: header)
        for index in Shortcut.modes.indices {
            let button = PaletteActionButton(frame: .zero)
            button.title = Shortcut.titles[index]
            button.image = NSImage(systemSymbolName: Self.symbols[index], accessibilityDescription: nil)
            button.tag = index
            button.target = self
            button.action = #selector(run(_:))
            button.setAccessibilityLabel(button.title)
            buttons.append(button)
            column.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        }
        statusButton.title = L("palette.status")
        statusButton.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
        statusButton.target = self
        statusButton.action = #selector(showStatusMenu(_:))
        statusButton.setAccessibilityLabel(statusButton.title)
        column.addArrangedSubview(statusButton)
        statusButton.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        statusButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        let settings = NSButton(title: L("menu.settings"), target: settingsTarget, action: openSettings)
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settings.imagePosition = .imageLeading
        settings.bezelStyle = .rounded
        settings.controlSize = .small
        settings.font = .systemFont(ofSize: 11)
        settings.refusesFirstResponder = true
        column.setCustomSpacing(12, after: statusButton)
        column.addArrangedSubview(settings)
        header.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        targetLabel.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        column.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            column.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            column.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            column.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -12)
        ])
        panel.setContentSize(NSSize(width: 360, height: column.fittingSize.height + 22))
        panel.setFrameAutosaveName("CommandDeePalette")
        refreshShortcutLabels(Shortcut.load())
        render()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appActivated(_:)),
                                                          name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    /// Auto-hide (1.8.22): while the palette is on, it is shown only over Finder / Path Finder (and CommandDee itself).
    /// orderOut keeps the on state, so it comes back with the browser; the hotkey still shows it anywhere.
    @objc private func appActivated(_ notification: Notification) {
        guard UserDefaults.standard.bool(forKey: Self.visibleKey), !panel.isMiniaturized,
              let id = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier else { return }
        if Browser.identifiers.contains(id) || id == Bundle.main.bundleIdentifier {
            if !panel.isVisible { panel.orderFrontRegardless(); refresh() }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        if panel.isMiniaturized { panel.deminiaturize(nil) }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { panel.center() }
        NSApp.unhideWithoutActivation()
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: Self.visibleKey)
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func hide() { panel.performClose(nil) }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        UserDefaults.standard.set(false, forKey: Self.visibleKey)
    }

    func refreshShortcutLabels(_ shortcuts: [Shortcut]) {
        for (index, button) in buttons.enumerated() where shortcuts.indices.contains(index) {
            button.shortcutLabel = shortcuts[index].keyCode == UInt16.max ? "" : shortcuts[index].displayLabel
        }
    }

    /// Re-reads the browser selection. The frontmost browser wins; otherwise the last one used stays the target.
    func refresh() {
        guard panel.isVisible, !panel.isMiniaturized, !isBusy() else { return }
        var source: (id: String, pid: pid_t)?
        if let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier, Browser.identifiers.contains(id) {
            source = (id, app.processIdentifier)
        } else if let target, let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated {
            source = (target.bundleID, target.pid)
        }
        guard let source else { target = nil; render(); return }
        do {
            target = PaletteTarget(bundleID: source.id, pid: source.pid, files: try Browser.selection(from: source.id))
            render()
        } catch {
            target = nil
            render(message: error.localizedDescription)
        }
    }

    private func render(message: String? = nil) {
        let files = target?.files ?? []
        let appName = target.flatMap { NSRunningApplication(processIdentifier: $0.pid)?.localizedName } ?? ""
        if let message { targetLabel.stringValue = message }
        else if files.isEmpty { targetLabel.stringValue = L("palette.noSelection") }
        else if files.count == 1 { targetLabel.stringValue = L("palette.selection", files[0].lastPathComponent, appName) }
        else { targetLabel.stringValue = L("palette.selectionMore", files[0].lastPathComponent, files.count - 1, appName) }
        targetLabel.toolTip = files.map(\.lastPathComponent).joined(separator: "\n")
        for (index, button) in buttons.enumerated() {
            let (preview, enabled, detail) = Self.preview(Shortcut.modes[index], files: files)
            button.preview = preview
            button.isEnabled = enabled
            button.toolTip = detail
        }
        let current = files.first.flatMap { try? Duplicator.currentStatus($0) }
        statusButton.preview = files.isEmpty ? Self.plain("—")
            : Self.plain(current.map { L("palette.statusCurrent", $0) } ?? L("palette.statusHint"), color: current == nil ? .secondaryLabelColor : .labelColor)
        statusButton.isEnabled = !files.isEmpty && !NamingSettings.statuses().isEmpty
    }

    /// The list shows the words only; the first item's current status is checked.
    @objc private func showStatusMenu(_ sender: PaletteActionButton) {
        guard let first = target?.files.first else { NSSound.beep(); return }
        let current = try? Duplicator.currentStatus(first)
        let menu = NSMenu()
        for word in NamingSettings.statuses() {
            let item = menu.addItem(withTitle: word, action: #selector(applyStatus(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = word
            item.state = word == current ? .on : .off
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 46, y: sender.isFlipped ? sender.bounds.maxY : 0), in: sender)
    }

    @objc private func applyStatus(_ sender: NSMenuItem) {
        guard let target, !target.files.isEmpty, let word = sender.representedObject as? String else { NSSound.beep(); return }
        perform(.status(word), target)
    }

    /// Resulting name for the first item (changed part highlighted), whether the action applies, and every item's result for the tooltip.
    static func preview(_ mode: Duplicator.Mode, files: [URL], date: Date = Date(),
                        separator: String = NamingSettings.separator(), order: [String] = NamingSettings.order(),
                        skipping: String = ParentFolderSettings.skippedName()) -> (NSAttributedString, Bool, String?) {
        guard let first = files.first else { return (plain("—"), false, nil) }
        if mode == .swapNames {
            guard files.count == 2 else { return (plain(L("palette.swapNeedsTwo")), false, nil) }
            let a = files[0].lastPathComponent, b = files[1].lastPathComponent
            return (plain("\(a)  ⇄  \(b)", color: .labelColor), true, nil)
        }
        func result(_ file: URL) -> Result<String?, Error> {
            Result {
                switch mode {
                case .version: return try Duplicator.versionDestination(file, order: order, separator: separator).url.lastPathComponent
                case .renameDate, .date: return try Duplicator.datedDestination(file, date: date, order: order, separator: separator)?.lastPathComponent
                case .edited: return try Duplicator.editedDestination(file, order: order, separator: separator)?.lastPathComponent
                case .parent: return try Duplicator.parentToggleDestination(file, skipping: skipping, separator: separator).lastPathComponent
                case .status(let word): return try Duplicator.statusDestination(file, status: word, order: order, separator: separator)?.lastPathComponent
                case .swapNames: return nil
                }
            }
        }
        func line(_ file: URL) -> String {
            switch result(file) {
            case .success(let name?): return "\(file.lastPathComponent) → \(name)"
            case .success(nil): return "\(file.lastPathComponent): \(unchangedReason(mode))"
            case .failure(let error): return "\(file.lastPathComponent): \(error.localizedDescription)"
            }
        }
        let detail = files.count > 1 ? files.prefix(20).map(line).joined(separator: "\n") + (files.count > 20 ? "\n…" : "") : nil
        let more = files.count > 1 ? "  " + L("palette.more", files.count - 1) : ""
        switch result(first) {
        case .success(let name?):
            let text = highlighted(old: first.lastPathComponent, new: name)
            text.insert(plain("→ "), at: 0)
            if !more.isEmpty { text.append(plain(more)) }
            return (text, true, detail)
        case .success(nil):
            return (plain(unchangedReason(mode) + more), files.count > 1, detail)
        case .failure(let error):
            return (plain(error.localizedDescription, color: .systemRed), files.count > 1, detail)
        }
    }

    private static func unchangedReason(_ mode: Duplicator.Mode) -> String {
        mode == .edited ? L("palette.alreadyEdited") : L("palette.alreadyToday")
    }

    static func plain(_ text: String, color: NSColor = .secondaryLabelColor) -> NSMutableAttributedString {
        NSMutableAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: color])
    }

    /// The new name with the part that differs from the old name in the accent color.
    static func highlighted(old: String, new: String) -> NSMutableAttributedString {
        let oldChars = Array(old), newChars = Array(new)
        var prefix = 0
        while prefix < min(oldChars.count, newChars.count), oldChars[prefix] == newChars[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(oldChars.count, newChars.count) - prefix,
              oldChars[oldChars.count - 1 - suffix] == newChars[newChars.count - 1 - suffix] { suffix += 1 }
        let text = plain(String(newChars[..<prefix]), color: .labelColor)
        let changed = String(newChars[prefix..<(newChars.count - suffix)])
        text.append(NSAttributedString(string: changed, attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                                                                     .foregroundColor: NSColor.controlAccentColor]))
        text.append(plain(String(newChars[(newChars.count - suffix)...]), color: .labelColor))
        return text
    }

    @objc private func run(_ sender: PaletteActionButton) {
        guard let target, !target.files.isEmpty, Shortcut.modes.indices.contains(sender.tag) else { NSSound.beep(); return }
        perform(Shortcut.modes[sender.tag], target)
    }
}
