import AppKit
import Combine

/// Floating palette with a button per function (KakkoReplace's BracketPalette). It never becomes key, so the
/// browser stays in front and the buttons act on its page exactly like the hotkeys.
final class LinkPalette: NSPanel {
    let model: Model
    let result = NSTextField(wrappingLabelWithString: "")
    private var buttons: [NSButton] = []
    private var sections: [(box: NSBox, grid: PaletteButtonGrid)] = []
    /// 「簡易モード／全部入り」 (MightyEdit's profile picker at the top of its palette).
    private let profilePicker = NSPopUpButton()
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

        let header = appHeader(L("paletteTitle"), subtitle: L("paletteSubtitle"), size: 32)
        column.addArrangedSubview(header); header.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        let utilities = NSStackView()
        for (key, selector) in [("settings", #selector(openSettings)), ("help", #selector(openHelp))] {
            let button = NSButton(title: L(key), target: self, action: selector)
            button.bezelStyle = .rounded; button.controlSize = .small; button.refusesFirstResponder = true
            utilities.addArrangedSubview(button)
        }
        profilePicker.addItems(withTitles: [L("paletteProfile.simple"), L("paletteProfile.full")])
        profilePicker.controlSize = .small; profilePicker.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        profilePicker.refusesFirstResponder = true
        profilePicker.target = self; profilePicker.action = #selector(pickProfile(_:))
        profilePicker.setAccessibilityLabel(L("paletteProfile"))
        utilities.addArrangedSubview(profilePicker)
        utilities.spacing = 6; column.addArrangedSubview(utilities)

        for group in LinkAction.Group.allCases {
            let box = NSBox(); box.title = groupTitle(group); box.titleFont = .systemFont(ofSize: 12, weight: .semibold)
            let groupButtons = LinkAction.listed(group).map { action -> NSButton in
                let button = NSButton(title: L(action.titleKey), target: self, action: #selector(run(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
                button.bezelStyle = .regularSquare; button.font = .systemFont(ofSize: 12)
                button.refusesFirstResponder = true
                button.lineBreakMode = .byTruncatingTail
                button.setAccessibilityLabel(groupTitle(group) + " " + L(action.titleKey))
                buttons.append(button)
                return button
            }
            let grid = PaletteButtonGrid(buttons: groupButtons, buttonHeight: 30, buttonWidth: Self.narrowGroups.contains(group) ? 124 : 256)
            box.contentView = NSView(); box.contentView!.addSubview(grid)
            NSLayoutConstraint.activate([grid.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor), grid.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor), grid.topAnchor.constraint(equalTo: box.contentView!.topAnchor), grid.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor)])
            column.addArrangedSubview(box); box.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            sections.append((box, grid))
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
        model.$paletteSimple.combineLatest(model.$simpleActions).receive(on: RunLoop.main).sink { [weak self] _ in self?.applyProfile() }.store(in: &watchers)
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

    /// Hides the buttons left out of 「簡易モード」 and the groups left empty; their hotkeys keep working.
    private func applyProfile() {
        profilePicker.selectItem(at: model.paletteSimple ? 0 : 1)
        for section in sections {
            for button in section.grid.buttons {
                button.isHidden = LinkAction(rawValue: button.identifier!.rawValue).map { !model.showsInPalette($0) } ?? false
            }
            section.box.isHidden = section.grid.visibleButtons.isEmpty
            section.grid.reflow()
        }
    }
    @objc private func pickProfile(_ sender: NSPopUpButton) {
        model.paletteSimple = sender.indexOfSelectedItem == 0
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
    let buttonWidth: CGFloat
    let buttonHeight: CGFloat
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
