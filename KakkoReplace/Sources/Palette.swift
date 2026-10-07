import AppKit
func actionTitle(_ id: String) -> String {
    if id.hasPrefix("force_"), let pair = BracketAction.pair(String(id.dropFirst(6))) { return pair.title + " · " + L("forceAction") }
    return BracketAction.pair(id)?.title ?? L(id)
}
final class BracketPalette: NSPanel {
    let model: Model
    let result = NSTextField(wrappingLabelWithString: "")
    private let force = NSButton(checkboxWithTitle: L("forceWrap"), target: nil, action: nil)
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init(model: Model) {
        self.model = model
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 620), styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        title = ""; isReleasedWhenClosed = false; hidesOnDeactivate = false; level = .floating
        isFloatingPanel = true; becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentMinSize = NSSize(width: 280, height: 340)
        let content = NSView()
        AppSurface.install(in: content)
        contentView = content
        let column = NSStackView(); column.orientation = .vertical; column.spacing = 10; column.alignment = .leading
        column.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false; scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let document = BracketPaletteDocument(); document.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = document
        document.addSubview(column)
        let header = appHeader(L("カッコを付ける・置き換える"), subtitle: L("選択テキストのカッコをまとめて変換。"), size: 32)
        column.addArrangedSubview(header); header.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        let utilities = NSStackView()
        for (key, selector) in [("settings", #selector(openSettings)), ("help", #selector(openHelp))] {
            let button = NSButton(title: L(key), target: self, action: selector)
            button.bezelStyle = .rounded; button.controlSize = .small; button.refusesFirstResponder = true
            utilities.addArrangedSubview(button)
        }
        utilities.spacing = 6; column.addArrangedSubview(utilities)
        let restoreButton = NSButton(title: L("restore"), target: self, action: #selector(restore))
        restoreButton.bezelStyle = .rounded; restoreButton.refusesFirstResponder = true
        column.addArrangedSubview(restoreButton)
        for group in OperationGroup.all where group.titleKey != "groupForce" {
            let ids = group.ids.filter { $0 != "palette" }
            let box = NSBox(); box.title = L(group.titleKey); box.titleFont = .systemFont(ofSize: 12, weight: .semibold)
            let buttons = ids.map { id -> NSButton in
                let button = NSButton(title: actionTitle(id), target: self, action: #selector(apply(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(id); button.bezelStyle = .regularSquare
                button.font = .systemFont(ofSize: group.titleKey == "groupOther" ? 13 : 23)
                button.refusesFirstResponder = true
                button.setAccessibilityLabel(OperationGroup.displayTitle(id))
                button.toolTip = OperationGroup.displayTitle(id)
                actionButtons.append(button)
                return button
            }
            let grid = BracketButtonGrid(buttons: buttons, buttonHeight: 44, buttonWidth: group.titleKey == "groupOther" ? 220 : (group.titleKey == "groupComments" ? 110 : 72))
            box.contentView = NSView(); box.contentView!.addSubview(grid)
            NSLayoutConstraint.activate([grid.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor), grid.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor), grid.topAnchor.constraint(equalTo: box.contentView!.topAnchor), grid.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor)])
            column.addArrangedSubview(box); box.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        force.target = self; force.action = #selector(toggleForce); force.refusesFirstResponder = true
        force.cell?.wraps = true
        column.addArrangedSubview(force); force.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        result.font = .systemFont(ofSize: 11); result.setAccessibilityLabel(L("status"))
        column.addArrangedSubview(result); result.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor), scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 12), column.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -12),
            column.topAnchor.constraint(equalTo: document.topAnchor, constant: 12), column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -12)])
        center(); setFrameAutosaveName("BracketPalette")
        // Apply the requested narrower layout once, retaining location and later user resizing.
        if !UserDefaults.standard.bool(forKey: "compactPaletteWidthV1") {
            var compactFrame = frame; compactFrame.size.width = 300
            setFrame(compactFrame, display: false)
            saveFrame(usingName: "BracketPalette")
            UserDefaults.standard.set(true, forKey: "compactPaletteWidthV1")
        }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.contains(frame) }) { center() }
        refresh()
    }
    private var actionButtons: [NSButton] = []
    private func OperationPickerTitle(_ id: String) -> String { OperationGroup.displayTitle(id) }
    func refresh() {
        force.state = model.forceWrap ? .on : .off; result.stringValue = model.status
        for button in actionButtons {
            let id = button.identifier!.rawValue
            button.toolTip = OperationGroup.displayTitle(id) + "  " + (model.bindings[id]?.label ?? L("unassigned"))
        }
    }
    @objc private func openSettings() { (NSApp.delegate as? AppDelegate)?.showPreferences() }
    @objc private func openHelp() { (NSApp.delegate as? AppDelegate)?.help() }
    @objc private func restore() {
        guard (NSApp.delegate as? AppDelegate)?.paletteCanEdit() == true else { result.stringValue = L("chooseTarget"); return }
        model.status = model.editor.restore(expectedPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }

    @objc private func apply(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        guard (NSApp.delegate as? AppDelegate)?.paletteCanEdit() == true else { result.stringValue = L("chooseTarget"); return }
        guard !model.disabled, !model.paused, !model.recording else { result.stringValue = L("pausedHint"); return }
        model.trigger(id)
    }
    @objc private func toggleForce() { model.forceWrap = force.state == .on; model.save() }
}


// Main-window header uses the same icon resource as the distributed app.
private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
private func appHeader(_ title: String, subtitle: String = "", size: CGFloat = 44) -> NSStackView {
    let icon = NSImageView(image: currentAppIcon())
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.setAccessibilityElement(false)
    icon.widthAnchor.constraint(equalToConstant: size).isActive = true
    icon.heightAnchor.constraint(equalToConstant: size).isActive = true
    let label = NSTextField(wrappingLabelWithString: title)
    label.font = .systemFont(ofSize: size == 44 ? 20 : 15, weight: .semibold)
    let detail = NSTextField(wrappingLabelWithString: subtitle)
    detail.font = .systemFont(ofSize: size == 44 ? 12 : 11)
    detail.textColor = .secondaryLabelColor
    let text = NSStackView(views: subtitle.isEmpty ? [label] : [label, detail])
    text.orientation = .vertical; text.alignment = .leading; text.spacing = 4
    let row = NSStackView(views: [icon, text])
    row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 12
    return row
}

// Adapted from MightyEdit/Source/ResponsiveButtonGrid.swift.
import AppKit

/// Each category uses the same width thresholds, even with an incomplete last row.
final class BracketButtonGrid: NSView {
    let buttons: [NSButton]
    let buttonWidth: CGFloat
    var buttonHeight: CGFloat { didSet { updateGridHeight(); needsLayout = true } }
    private var gridHeight: NSLayoutConstraint!
    override var isFlipped: Bool { true }

    static func columnCount(for width: CGFloat, buttonWidth: CGFloat) -> Int {
        max(1, Int((max(0, width) + 8) / (buttonWidth + 8)))
    }

    init(buttons: [NSButton], buttonHeight: CGFloat, buttonWidth: CGFloat) {
        self.buttonWidth = buttonWidth
        self.buttons = buttons
        self.buttonHeight = buttonHeight
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

    func refreshVisibility() { updateGridHeight(); needsLayout = true }

    private func updateGridHeight() {
        guard gridHeight != nil else { return }
        let columns = Self.columnCount(for: bounds.width, buttonWidth: buttonWidth)
        let rows = (buttons.filter { !$0.isHidden }.count + columns - 1) / columns
        let height = CGFloat(rows) * buttonHeight + CGFloat(max(0, rows - 1)) * 8
        if gridHeight.constant != height { gridHeight.constant = height }
    }

    override func layout() {
        super.layout()
        updateGridHeight()
        let columns = Self.columnCount(for: bounds.width, buttonWidth: buttonWidth)
        let width = buttonWidth
        for (index, button) in buttons.filter({ !$0.isHidden }).enumerated() {
            button.frame = NSRect(x: CGFloat(index % columns) * (width + 8),
                                  y: CGFloat(index / columns) * (buttonHeight + 8),
                                  width: width, height: buttonHeight)
        }
    }
}

private final class BracketPaletteDocument: NSView { override var isFlipped: Bool { true } }
