import AppKit

final class LineToolsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    /// Esc closes the panel (it can become key, so the key reaches it).
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    private let prefixField = NSTextField(string: UserDefaults.standard.string(forKey: "lineAffixPrefix") ?? "")
    private let suffixField = NSTextField(string: UserDefaults.standard.string(forKey: "lineAffixSuffix") ?? "")
    private let feedback = NSTextField(wrappingLabelWithString: L("lines.affixNote"))
    private var applyOperation: ((String, String) -> String)?
    init(statistics: String? = nil, apply: ((String, String) -> String)? = nil) {
        applyOperation = apply
        super.init(contentRect: NSRect(x: 0, y: 0, width: 440, height: 260), styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        title = statistics == nil ? TextTransform.affixLines.title : L("lines.countTitle")
        isReleasedWhenClosed = false; isFloatingPanel = true; level = .floating; hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let column = NSStackView(); column.orientation = .vertical; column.alignment = .leading; column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false; contentView!.addSubview(column)
        if let statistics {
            let label = NSTextField(wrappingLabelWithString: statistics); label.isSelectable = true
            column.addArrangedSubview(label); label.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        } else {
            for (name, field) in [(L("lines.prefix"), prefixField), (L("lines.suffix"), suffixField)] {
                field.setAccessibilityLabel(name)
                let row = NSStackView(views: [NSTextField(labelWithString: name), field]); row.spacing = 10
                column.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
                field.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
            }
            let button = NSButton(title: L("action.applySelection"), target: self, action: #selector(applySelection)); button.bezelStyle = .rounded
            column.addArrangedSubview(button); column.addArrangedSubview(feedback)
            feedback.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 20)
        ])
        center()
    }
    @objc private func applySelection() {
        let prefix = prefixField.stringValue, suffix = suffixField.stringValue
        UserDefaults.standard.set(prefix, forKey: "lineAffixPrefix"); UserDefaults.standard.set(suffix, forKey: "lineAffixSuffix")
        // Release the panel field editor before the existing selection-replacement path sends Paste.
        orderOut(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.feedback.stringValue = self.applyOperation?(prefix, suffix) ?? ""
        }
    }
}

final class SplitLinesPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    private let separatorField = NSTextField(string: UserDefaults.standard.string(forKey: "lineSplitSeparator") ?? "、")
    private let prefixField = NSTextField(string: UserDefaults.standard.string(forKey: "lineSplitPrefix") ?? "")
    private let keepCheck = NSButton(checkboxWithTitle: L("lines.keepSeparator"), target: nil, action: nil)
    private let feedback = NSTextField(wrappingLabelWithString: L("lines.splitNote"))
    private let applyOperation: (String, Bool, String) -> String
    init(apply: @escaping (String, Bool, String) -> String) {
        applyOperation = apply
        super.init(contentRect: NSRect(x: 0, y: 0, width: 440, height: 230), styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        title = TextTransform.splitAtText.title
        isReleasedWhenClosed = false; isFloatingPanel = true; level = .floating; hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let column = NSStackView(); column.orientation = .vertical; column.alignment = .leading; column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false; contentView!.addSubview(column)
        var labels: [NSTextField] = []
        for (name, field) in [(L("lines.separator"), separatorField), (L("lines.splitPrefix"), prefixField)] {
            field.setAccessibilityLabel(name)
            let label = NSTextField(labelWithString: name); label.alignment = .right; labels.append(label)
            let row = NSStackView(views: [label, field]); row.spacing = 10
            column.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
            if field === separatorField {
                keepCheck.state = UserDefaults.standard.bool(forKey: "lineSplitKeepSeparator") ? .on : .off
                column.addArrangedSubview(keepCheck)
                keepCheck.leadingAnchor.constraint(equalTo: field.leadingAnchor).isActive = true
            }
        }
        labels[1].widthAnchor.constraint(equalTo: labels[0].widthAnchor).isActive = true
        let button = NSButton(title: L("action.applySelection"), target: self, action: #selector(applySelection)); button.bezelStyle = .rounded
        column.addArrangedSubview(button); column.addArrangedSubview(feedback)
        feedback.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 20)
        ])
        center()
    }
    @objc private func applySelection() {
        let separator = separatorField.stringValue, keep = keepCheck.state == .on, prefix = prefixField.stringValue
        UserDefaults.standard.set(separator, forKey: "lineSplitSeparator"); UserDefaults.standard.set(keep, forKey: "lineSplitKeepSeparator")
        UserDefaults.standard.set(prefix, forKey: "lineSplitPrefix")
        // Release the panel field editor before the existing selection-replacement path sends Paste.
        orderOut(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.feedback.stringValue = self.applyOperation(separator, keep, prefix)
        }
    }
}
