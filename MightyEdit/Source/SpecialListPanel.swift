import AppKit

// A nonactivating panel keeps the editor and its selection as the paste target.
final class SpecialListPanel: Palette {
    private var choices: [NSButton] = []
    private let preview = NSTextField(wrappingLabelWithString: "")
    private let feedback = NSTextField(wrappingLabelWithString: "")
    private let applyOperation: (TextTransform) -> String
    private var applyButton: NSButton?
    private var selection: TextTransform

    init(apply: @escaping (TextTransform) -> String) {
        applyOperation = apply
        let saved = UserDefaults.standard.integer(forKey: "specialListStyle")
        selection = TextTransform.specialLists.first { $0.rawValue == saved } ?? .blackCircled
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                   styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        title = L("special.lists")
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false
        contentView!.addSubview(column)
        column.addArrangedSubview(NSTextField(labelWithString: L("special.kind")))
        for operation in TextTransform.specialLists {
            let button = NSButton(radioButtonWithTitle: operation.title, target: nil, action: nil)
            button.target = self
            button.action = #selector(choose(_:))
            button.tag = operation.rawValue
            button.refusesFirstResponder = true
            choices.append(button)
            column.addArrangedSubview(button)
        }
        preview.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        column.addArrangedSubview(preview)
        let applyButton = NSButton(title: L("action.applySelection"), target: self, action: #selector(applySelection))
        self.applyButton = applyButton
        applyButton.bezelStyle = .rounded
        applyButton.refusesFirstResponder = true
        column.addArrangedSubview(applyButton)
        feedback.font = .systemFont(ofSize: 11)
        feedback.textColor = .secondaryLabelColor
        feedback.stringValue = L("special.feedback")
        column.addArrangedSubview(feedback)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 20),
            column.bottomAnchor.constraint(lessThanOrEqualTo: contentView!.bottomAnchor, constant: -20),
            preview.widthAnchor.constraint(equalTo: column.widthAnchor),
            feedback.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
        reloadOptions()
        center()
        setFrameAutosaveName("SpecialListPosition")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { center() }
    }

    func reloadOptions() {
        let allowed = TextTransform.specialLists.filter { PaletteConfiguration.listEnabled($0.rawValue) }
        if !allowed.contains(selection), let first = allowed.first { selection = first }
        for button in choices { button.isHidden = !PaletteConfiguration.listEnabled(button.tag) }
        applyButton?.isEnabled = !allowed.isEmpty
        refresh()
        if allowed.isEmpty { preview.stringValue = L("special.noneEnabled") }
    }

    private func refresh() {
        for button in choices { button.state = button.tag == selection.rawValue ? .on : .off }
        // Sample words are a localized preview; the markers come from the transform unchanged.
        preview.stringValue = selection.apply(L("special.sample"))
    }

    @objc private func choose(_ sender: NSButton) {
        guard let operation = TextTransform(rawValue: sender.tag), TextTransform.specialLists.contains(operation) else { return }
        selection = operation
        UserDefaults.standard.set(operation.rawValue, forKey: "specialListStyle")
        refresh()
        applySelection()
    }

    @objc private func applySelection() {
        guard PaletteConfiguration.listEnabled(selection.rawValue) else { return }
        feedback.stringValue = applyOperation(selection)
    }
}
