import AppKit

final class TypographyPanel: Palette {
    private var choices: [NSButton] = []
    private let preview = NSTextField(wrappingLabelWithString: "")
    private let feedback = NSTextField(wrappingLabelWithString: L("action.selectFirst"))
    private let applyOperation: ([TypographyOption]) -> String
    private let applyButton = NSButton()
    private var selected: [TypographyOption]
    // Not localized: the sample demonstrates Japanese typography rules.
    private let sample = "ＡＢＣ と ﾊﾟｿｺﾝ ( 補足 )\n時刻 １０：３０　コ-ヒ-､｢ 例 ｣｡\n本文。（補足）。"

    init(apply: @escaping ([TypographyOption]) -> String) {
        applyOperation = apply
        if let saved = UserDefaults.standard.array(forKey: "specialTypographyOptions") as? [Int] {
            selected = TypographyOption.allCases.filter { saved.contains($0.rawValue) }
        } else { selected = TypographyOption.allCases }
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
                   styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        title = TextTransform.specialTypography.title
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let scroll = NSScrollView(frame: contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        contentView!.addSubview(scroll)
        let document = PaletteDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(column)
        column.addArrangedSubview(NSTextField(labelWithString: L("typo.choose")))
        for option in TypographyOption.allCases {
            let button = NSButton(checkboxWithTitle: option.title, target: self, action: #selector(toggle(_:)))
            button.tag = option.rawValue
            button.refusesFirstResponder = true
            button.toolTip = option == .correctLongVowel ? L("typo.tipLongVowel") : option == .widenPunctuation ? L("typo.tipPunctuation") : nil
            choices.append(button)
            column.addArrangedSubview(button)
        }
        column.addArrangedSubview(NSTextField(labelWithString: L("typo.sampleBefore")))
        let original = NSTextField(wrappingLabelWithString: sample)
        original.font = .systemFont(ofSize: 12)
        column.addArrangedSubview(original)
        column.addArrangedSubview(NSTextField(labelWithString: L("typo.sampleAfter")))
        preview.font = .systemFont(ofSize: 12)
        column.addArrangedSubview(preview)
        applyButton.title = L("action.applySelection")
        applyButton.target = self
        applyButton.action = #selector(applySelection)
        applyButton.bezelStyle = .rounded
        applyButton.refusesFirstResponder = true
        column.addArrangedSubview(applyButton)
        feedback.font = .systemFont(ofSize: 11)
        feedback.textColor = .secondaryLabelColor
        column.addArrangedSubview(feedback)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: document.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -18),
            original.widthAnchor.constraint(equalTo: column.widthAnchor),
            preview.widthAnchor.constraint(equalTo: column.widthAnchor),
            feedback.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
        refresh()
        center()
        setFrameAutosaveName("SpecialTypographyPosition")
        if let screen = screen ?? NSScreen.main {
            var rect = frame
            rect.size.height = min(rect.height, screen.visibleFrame.height)
            if !screen.visibleFrame.contains(rect) { rect.origin = NSPoint(x: screen.visibleFrame.midX - rect.width / 2, y: screen.visibleFrame.midY - rect.height / 2) }
            setFrame(rect, display: false)
        }
    }
    func reloadOptions() { selected = TypographyOption.savedOptions; refresh() }

    private func refresh() {
        for button in choices { button.state = selected.contains { $0.rawValue == button.tag } ? .on : .off }
        preview.stringValue = TypographyOption.applyAll(sample, options: selected)
        applyButton.isEnabled = !selected.isEmpty
    }
    @objc private func toggle(_ sender: NSButton) {
        selected = choices.filter { $0.state == .on }.compactMap { TypographyOption(rawValue: $0.tag) }
        UserDefaults.standard.set(selected.map(\.rawValue), forKey: "specialTypographyOptions")
        refresh()
    }
    @objc private func applySelection() {
        guard !selected.isEmpty else { return }
        feedback.stringValue = applyOperation(selected)
    }
}
