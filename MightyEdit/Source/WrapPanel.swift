import AppKit

final class WrapPanel: Palette {
    private let countLabel = NSTextField(labelWithString: "")
    private let stepper = NSStepper()
    private let feedback = NSTextField(wrappingLabelWithString: L("action.selectFirst"))
    private let applyOperation: (Int) -> String
    private var count: Int

    init(apply: @escaping (Int) -> String) {
        applyOperation = apply
        let saved = UserDefaults.standard.integer(forKey: "wrapCharacterCount")
        count = (1...10000).contains(saved) ? saved : 40
        super.init(contentRect: NSRect(x: 0, y: 0, width: 350, height: 245),
                   styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        title = TextTransform.wrapLines.title
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        contentView!.addSubview(column)
        let presets = NSPopUpButton()
        presets.addItems(withTitles: [L("wrap.presets"), "10", "20", "30", "40", "50", "60", "80", "100", "120", "200"])
        presets.target = self
        presets.action = #selector(preset(_:))
        column.addArrangedSubview(presets)
        let row = NSStackView()
        row.spacing = 12
        countLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        countLabel.setAccessibilityLabel(L("wrap.axCount"))
        row.addArrangedSubview(countLabel)
        stepper.minValue = 1
        stepper.maxValue = 10000
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(changeCount)
        stepper.setAccessibilityLabel(L("wrap.axStepper"))
        row.addArrangedSubview(stepper)
        column.addArrangedSubview(row)
        let note = NSTextField(wrappingLabelWithString: L("wrap.note"))
        note.font = .systemFont(ofSize: 11)
        column.addArrangedSubview(note)
        let button = NSButton(title: L("action.applySelection"), target: self, action: #selector(applySelection))
        button.bezelStyle = .rounded
        button.refusesFirstResponder = true
        column.addArrangedSubview(button)
        feedback.font = .systemFont(ofSize: 11)
        feedback.textColor = .secondaryLabelColor
        column.addArrangedSubview(feedback)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 20),
            column.bottomAnchor.constraint(lessThanOrEqualTo: contentView!.bottomAnchor, constant: -14),
            note.widthAnchor.constraint(equalTo: column.widthAnchor),
            feedback.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
        refresh()
        center()
        setFrameAutosaveName("WrapPanelPosition")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { center() }
    }

    private func refresh() {
        countLabel.stringValue = L("wrap.every", String(count))
        stepper.integerValue = count
        UserDefaults.standard.set(count, forKey: "wrapCharacterCount")
    }
    @objc private func preset(_ sender: NSPopUpButton) {
        guard let text = sender.titleOfSelectedItem, let value = Int(text) else { return }
        count = value
        refresh()
        sender.selectItem(at: 0)
    }
    @objc private func changeCount() { count = stepper.integerValue; refresh() }
    @objc private func applySelection() { feedback.stringValue = applyOperation(count) }
}
