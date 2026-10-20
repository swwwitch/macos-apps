import AppKit
import Combine

/// Floating palette with a button per function (KakkoReplace's BracketPalette). It never becomes key, so the
/// browser stays in front and the buttons act on its page exactly like the hotkeys.
final class LinkPalette: NSPanel {
    let model: Model
    let result = NSTextField(wrappingLabelWithString: "")
    private var buttons: [PaletteActionButton] = []
    private var sections: [(group: LinkAction.Group, box: NSBox, grid: PaletteButtonGrid)] = []
    /// 「簡易モード／全部入り」 (MightyEdit's profile picker at the top of its palette).
    private let profilePicker = NSPopUpButton()
    /// 「アイコン＋テキスト／アイコンのみ／テキストのみ」 for both profiles.
    private let displayPicker = NSPopUpButton()
    private var watchers: Set<AnyCancellable> = []
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Groups whose titles fit two buttons per row.
    private static let narrowGroups: Set<LinkAction.Group> = [.copy, .tabs, .reopen]

    init(model: Model) {
        self.model = model
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 640), styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        title = ""; isReleasedWhenClosed = false; hidesOnDeactivate = false; level = .floating
        isFloatingPanel = true; becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentMinSize = NSSize(width: 280, height: 320)
        let content = NSView()
        AppSurface.install(in: content)
        contentView = content
        let column = NSStackView(); column.orientation = .vertical; column.spacing = 10; column.alignment = .leading
        column.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false; scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let document = PaletteDocument(); document.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = document
        document.addSubview(column)

        let header = appHeader(L("paletteTitle"), subtitle: L("paletteSubtitle"), size: 32, showsVersion: false)
        column.addArrangedSubview(header); header.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        let utilities = NSStackView()
        for (key, selector) in [("settings", #selector(openSettings)), ("help", #selector(openHelp))] {
            let button = NSButton(title: L(key), target: self, action: selector)
            button.bezelStyle = .rounded; button.controlSize = .small; button.refusesFirstResponder = true
            utilities.addArrangedSubview(button)
        }
        profilePicker.addItems(withTitles: [L("paletteProfile.simple"), L("paletteProfile.full")])
        profilePicker.target = self; profilePicker.action = #selector(pickProfile(_:))
        profilePicker.setAccessibilityLabel(L("paletteProfile"))
        displayPicker.addItems(withTitles: PaletteDisplayMode.allCases.map(\.title))
        displayPicker.target = self; displayPicker.action = #selector(pickDisplay(_:))
        displayPicker.setAccessibilityLabel(L("paletteDisplay"))
        for picker in [profilePicker, displayPicker] {
            picker.controlSize = .small; picker.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            picker.refusesFirstResponder = true
        }
        utilities.spacing = 6; column.addArrangedSubview(utilities)
        // Its own row (MightyEdit's displayRow): both menus do not fit beside the buttons at the minimum width.
        let pickers = NSStackView(views: [profilePicker, displayPicker]); pickers.spacing = 6
        column.addArrangedSubview(pickers)

        for group in LinkAction.Group.allCases {
            let box = NSBox(); box.title = groupTitle(group); box.titleFont = .systemFont(ofSize: 12, weight: .semibold)
            let groupButtons = LinkAction.listed(group).map { action -> NSButton in
                let button = PaletteActionButton(title: L(action.titleKey), target: self, action: #selector(run(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
                button.bezelStyle = .regularSquare; button.font = .systemFont(ofSize: 12)
                button.refusesFirstResponder = true
                button.lineBreakMode = .byTruncatingTail
                button.image = action.browserBundleID.flatMap(appIcon(for:))
                    ?? NSImage(systemSymbolName: action.symbolName, accessibilityDescription: nil)
                button.imagePosition = .noImage
                button.setAccessibilityLabel(groupTitle(group) + " " + L(action.titleKey))
                buttons.append(button)
                return button
            }
            let grid = PaletteButtonGrid(buttons: groupButtons, buttonHeight: 30, buttonWidth: Self.textWidth(group))
            box.contentView = NSView(); box.contentView!.addSubview(grid)
            NSLayoutConstraint.activate([grid.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor), grid.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor), grid.topAnchor.constraint(equalTo: box.contentView!.topAnchor), grid.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor)])
            column.addArrangedSubview(box); box.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            sections.append((group, box, grid))
        }
        result.font = .systemFont(ofSize: 11); result.setAccessibilityLabel(L("lastResult"))
        result.maximumNumberOfLines = 4; result.lineBreakMode = .byTruncatingTail
        column.addArrangedSubview(result); result.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor), scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 12), column.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -12),
            column.topAnchor.constraint(equalTo: document.topAnchor, constant: 12), column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -12)])
        center(); setFrameAutosaveName("LinkPalette")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { center() }
        // The result line and the key hints follow the model.
        model.$status.receive(on: RunLoop.main).sink { [weak self] status in self?.result.stringValue = status }.store(in: &watchers)
        model.$shortcuts.combineLatest(model.$actionEnabled).receive(on: RunLoop.main).sink { [weak self] _ in self?.refresh() }.store(in: &watchers)
        model.$paletteSimple.combineLatest(model.$simpleActions, model.$paletteDisplay).receive(on: RunLoop.main).sink { [weak self] _ in self?.applyProfile() }.store(in: &watchers)
        model.$busy.receive(on: RunLoop.main).sink { [weak self] busy in self?.buttons.forEach { $0.isEnabled = !busy } }.store(in: &watchers)
        refresh()
    }

    func refresh() {
        result.stringValue = model.status
        for button in buttons {
            guard let action = LinkAction(rawValue: button.identifier!.rawValue) else { continue }
            button.toolTip = L(action.titleKey) + "  " + (model.isActive(action) ? model.label(action) : L("noKey"))
        }
    }

    private static func textWidth(_ group: LinkAction.Group) -> CGFloat { narrowGroups.contains(group) ? 124 : 256 }

    /// Hides the buttons left out of 「簡易モード」 and the groups left empty; their hotkeys keep working.
    /// The buttons follow 「ボタンの表示」 (MightyEdit's sizes: icon and text 74pt high, icon only 44pt).
    private func applyProfile() {
        profilePicker.selectItem(at: model.paletteSimple ? 0 : 1)
        displayPicker.selectItem(at: model.paletteDisplay.rawValue)
        let display = model.paletteDisplay
        for section in sections {
            for button in section.grid.buttons {
                button.isHidden = LinkAction(rawValue: button.identifier!.rawValue).map { !model.showsInPalette($0) } ?? false
                (button as? PaletteActionButton)?.displayMode = display
            }
            switch display {
            case .both: section.grid.buttonWidth = 100; section.grid.buttonHeight = 74
            case .iconOnly: section.grid.buttonWidth = 52; section.grid.buttonHeight = 44
            case .textOnly: section.grid.buttonWidth = Self.textWidth(section.group); section.grid.buttonHeight = 30
            }
            section.box.isHidden = section.grid.visibleButtons.isEmpty
            section.grid.reflow()
        }
    }
    @objc private func pickProfile(_ sender: NSPopUpButton) {
        model.paletteSimple = sender.indexOfSelectedItem == 0
        model.save()
    }

    @objc private func pickDisplay(_ sender: NSPopUpButton) {
        model.paletteDisplay = PaletteDisplayMode(rawValue: sender.indexOfSelectedItem) ?? .both
        model.save()
    }

    @objc private func run(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let action = LinkAction(rawValue: raw) else { return }
        model.perform(action)
    }
    @objc private func openSettings() { (NSApp.delegate as? AppDelegate)?.showPreferences() }
    @objc private func openHelp() { (NSApp.delegate as? AppDelegate)?.help() }
}

// Adapted from KakkoReplace's BracketButtonGrid (MightyEdit's ResponsiveButtonGrid): columns follow the width.
final class PaletteButtonGrid: NSView {
    let buttons: [NSButton]
    var buttonWidth: CGFloat
    var buttonHeight: CGFloat
    private var gridHeight: NSLayoutConstraint!
    override var isFlipped: Bool { true }

    static func columnCount(for width: CGFloat, buttonWidth: CGFloat) -> Int {
        max(1, Int((max(0, width) + 8) / (buttonWidth + 8)))
    }

    init(buttons: [NSButton], buttonHeight: CGFloat, buttonWidth: CGFloat) {
        self.buttons = buttons; self.buttonWidth = buttonWidth; self.buttonHeight = buttonHeight
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for button in buttons {
            button.translatesAutoresizingMaskIntoConstraints = true
            button.autoresizingMask = []
            addSubview(button)
        }
        gridHeight = heightAnchor.constraint(equalToConstant: 1)
        gridHeight.isActive = true
        updateGridHeight()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = abs(newSize.width - frame.width) > 0.01
        super.setFrameSize(newSize)
        if changed { updateGridHeight(); needsLayout = true }
    }
    var visibleButtons: [NSButton] { buttons.filter { !$0.isHidden } }
    func reflow() { updateGridHeight(); needsLayout = true }
    private var columns: Int { Self.columnCount(for: bounds.width, buttonWidth: buttonWidth) }
    /// Buttons share the row's width so a narrow palette still fills it.
    private var cellWidth: CGFloat { columns == 1 ? max(buttonWidth, bounds.width) : (bounds.width - CGFloat(columns - 1) * 8) / CGFloat(columns) }
    private func updateGridHeight() {
        guard gridHeight != nil else { return }
        let rows = (visibleButtons.count + columns - 1) / columns
        let height = CGFloat(rows) * buttonHeight + CGFloat(max(0, rows - 1)) * 8
        if gridHeight.constant != height { gridHeight.constant = height }
    }
    override func layout() {
        super.layout()
        updateGridHeight()
        let width = min(cellWidth, max(bounds.width, 1))
        for (index, button) in visibleButtons.enumerated() {
            button.frame = NSRect(x: CGFloat(index % columns) * (width + 8), y: CGFloat(index / columns) * (buttonHeight + 8), width: width, height: buttonHeight)
        }
    }
}

private final class PaletteDocument: NSView { override var isFlipped: Bool { true } }

/// パレットのボタンの見せ方 (MightyEdit's PaletteDisplayMode).
enum PaletteDisplayMode: Int, CaseIterable {
    case both, iconOnly, textOnly
    var title: String { L("paletteDisplay." + ["both", "iconOnly", "textOnly"][rawValue]) }
}

/// Palette button: the standard square button for 「テキストのみ」, MightyEdit's flat icon tile (PaletteButton) otherwise.
final class PaletteActionButton: NSButton {
    var displayMode = PaletteDisplayMode.textOnly { didSet { if displayMode != oldValue { needsDisplay = true } } }
    var isHovered = false { didSet { if isHovered != oldValue { needsDisplay = true } } }
    private var hoverArea: NSTrackingArea?
    override class var cellClass: AnyClass? { get { PaletteActionButtonCell.self } set {} }

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

// Adapted from MightyEdit's PaletteButtonCell.
final class PaletteActionButtonCell: NSButtonCell {
    override func draw(withFrame frame: NSRect, in controlView: NSView) {
        guard let button = controlView as? PaletteActionButton, button.displayMode != .textOnly else {
            super.draw(withFrame: frame, in: controlView); return
        }
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
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byCharWrapping
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: color, .paragraphStyle: paragraph]
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        let labelHeight: CGFloat = button.displayMode == .iconOnly ? 0 : max(14, min(28, ceil((title as NSString).boundingRect(
            with: NSSize(width: frame.width - 8, height: 28), options: options, attributes: attributes).height)))
        let iconHeight: CGFloat = 22
        let gap: CGFloat = button.displayMode == .both ? 6 : 0
        let offset: CGFloat = pressed ? 1 : 0
        let top = frame.midY - (labelHeight + iconHeight + gap) / 2 + offset
        if let icon = image {
            // SF Symbols take the text color; the browsers' own icons keep theirs.
            let tinted = icon.isTemplate ? icon.withSymbolConfiguration(.init(paletteColors: [color])) ?? icon : icon
            let scale = min(24 / tinted.size.width, iconHeight / tinted.size.height)
            let size = NSSize(width: tinted.size.width * scale, height: tinted.size.height * scale)
            tinted.draw(in: NSRect(x: frame.midX - size.width / 2, y: top + (iconHeight - size.height) / 2, width: size.width, height: size.height),
                        from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.4, respectFlipped: true, hints: nil)
        }
        if labelHeight > 0 {
            (title as NSString).draw(with: NSRect(x: frame.minX + 4, y: top + iconHeight + gap, width: frame.width - 8, height: labelHeight),
                                     options: options, attributes: attributes)
        }
    }
}
