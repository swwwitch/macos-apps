import AppKit

enum PaletteProfile: String, CaseIterable {
    case minimal, simple, full
    var title: String {
        switch self {
        case .minimal: return L("profile.minimal")
        case .simple: return L("profile.simple")
        case .full: return L("profile.full")
        }
    }
    static var saved: Self { Self(rawValue: UserDefaults.standard.string(forKey: "paletteProfile") ?? "") ?? .full }
    func defaultShown(_ key: String) -> Bool {
        guard self != .full, key.hasPrefix("button.") else { return true }
        let minimal: [TextTransform] = [.join, .number, .bullet, .removeList, .narrowAlphanumerics, .sum]
        let simple = minimal + [.markdown, .removeBlankLines, .addCommas, .removeCommas, .widenKana, .addPeriod, .removePeriod, .dateToISO, .dateToJapanese]
        return (self == .minimal ? minimal : simple).contains { key == "button.\($0.rawValue)" }
    }
}

enum PaletteConfiguration {
    static let listSpecialID = 9001
    static let typographySpecialID = 9002
    static let groups: [(String, [TextTransform])] = [
        ("行の編集", [.join, .joinWestern, .joinAll, .removeBlankLines, .spaceLines, .sortLines, .randomLines, .uniqueLines, .wrapLines, .trimLineEdges, .sortLineLength, .affixLines, .countText]),
        ("リスト", [.number, .circled, .alphabet, .bullet, .markdown, .removeList]),
        ("桁区切り", [.addCommas, .removeCommas, .sum]),
        ("文字の整形", [.narrowAlphanumerics, .widenKana, .removeJapaneseSpaces, .addJapaneseSpaces]),
        ("欧文", [.fullwidthWestern, .halfwidthWestern, .capitalizeWords, .titleCase, .camelCase]),
        ("日付", [.dateToISO, .dateToJapanese, .dateToCompact, .removeDatePadding, .dateToEra, .dateToGregorian, .removeDateYear, .addDateYear, .weekdayShort, .weekdayLong]),
        ("ソースコード", [.minify, .minifyBody, .beautify]),
        ("その他", [.addPeriod, .removePeriod])
    ]
    // Group names above are internal identifiers (persistence and grouping), never shown directly.
    private static let displayKeys = ["行の編集": "group.lines", "リスト": "group.lists", "桁区切り": "group.digits",
                                      "文字の整形": "group.characters", "欧文": "group.western", "日付": "group.dates",
                                      "ソースコード": "group.code", "その他": "group.other",
                                      "パレット操作": "group.palette", "追加の操作": "group.more"]
    /// Localized title for an internal group identifier.
    static func displayName(for name: String) -> String { displayKeys[name].map { L($0) } ?? name }
    // Display labels may change; keep the original preference keys stable.
    static func categoryKey(for name: String) -> String {
        let original = ["行の編集": "改行", "桁区切り": "桁区切りのカンマ", "文字の整形": "整形"]
        return "category." + (original[name] ?? name)
    }
    static func specialTitle(for name: String) -> String {
        name == "リスト" ? L("special.lists") : L("op.specialTypography")
    }
    static func visibilityKey(_ key: String, profile: PaletteProfile) -> String {
        // Full mode inherits all existing visibility settings without migration or reset.
        "paletteVisible." + (profile == .full ? "" : profile.rawValue + ".") + key
    }
    static func shown(_ key: String, profile: PaletteProfile = .saved) -> Bool {
        let storedKey = visibilityKey(key, profile: profile)
        guard UserDefaults.standard.object(forKey: storedKey) != nil else { return profile.defaultShown(key) }
        return UserDefaults.standard.bool(forKey: storedKey)
    }
    static func listEnabled(_ id: Int) -> Bool {
        let key = "specialListEnabled-\(id)"
        return UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key)
    }
}

final class PaletteSettingsViews: NSObject {
    var onChange: (() -> Void)?
    private var checks: [NSButton] = []
    private var editingProfile = PaletteProfile.saved
    private let profilePicker = NSPopUpButton()
    func editProfile(_ profile: PaletteProfile) {
        editingProfile = profile
        profilePicker.selectItem(at: PaletteProfile.allCases.firstIndex(of: profile)!)
        refresh()
    }
    @objc private func chooseProfile(_ sender: NSPopUpButton) {
        editProfile(PaletteProfile.allCases[sender.indexOfSelectedItem])
    }

    func tabs() -> [(String, NSView)] {
        [(SettingsUI.displayTitle, makeDisplay()), (L("tab.special"), makeSpecial())]
    }
    private func page(_ build: (NSStackView) -> Void) -> NSView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(column)
        build(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            column.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            column.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20)
        ])
        return scroll
    }
    private func check(_ title: String, key: String, into column: NSStackView) {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(toggle(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(key)
        checks.append(button)
        column.addArrangedSubview(button)
    }
    private func heading(_ title: String, into column: NSStackView) {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 15)
        column.addArrangedSubview(label)
    }
    private func makeDisplay() -> NSView {
        page { column in
            heading(L("display.heading"), into: column)
            column.addArrangedSubview(NSTextField(labelWithString: L("display.modeToEdit")))
            profilePicker.addItems(withTitles: PaletteProfile.allCases.map(\.title))
            profilePicker.target = self
            profilePicker.action = #selector(chooseProfile(_:))
            profilePicker.setAccessibilityLabel(L("display.modeToEdit"))
            column.addArrangedSubview(profilePicker)
            profilePicker.selectItem(at: PaletteProfile.allCases.firstIndex(of: editingProfile)!)
            heading(L("display.itemsHeading"), into: column)
            column.addArrangedSubview(NSTextField(wrappingLabelWithString: L("display.explanation")))
            for (name, operations) in PaletteConfiguration.groups {
                let box = NSBox()
                box.title = PaletteConfiguration.displayName(for: name)
                box.titleFont = .boldSystemFont(ofSize: 14)
                box.contentViewMargins = NSSize(width: 14, height: 12)
                let items = NSStackView()
                items.orientation = .vertical
                items.alignment = .leading
                items.spacing = 8
                items.translatesAutoresizingMaskIntoConstraints = false
                let container = NSView()
                box.contentView = container
                container.addSubview(items)
                check(L("display.showCategory"), key: PaletteConfiguration.categoryKey(for: name), into: items)
                let divider = NSBox()
                divider.boxType = .separator
                items.addArrangedSubview(divider)
                divider.widthAnchor.constraint(equalTo: items.widthAnchor).isActive = true
                for operation in operations { check(operation.title, key: "button.\(operation.rawValue)", into: items) }
                if name == "リスト" || name == "文字の整形" {
                    check(PaletteConfiguration.specialTitle(for: name), key: "button.\(name == "リスト" ? PaletteConfiguration.listSpecialID : PaletteConfiguration.typographySpecialID)", into: items)
                }
                NSLayoutConstraint.activate([
                    items.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                    items.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                    items.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                    items.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
                ])
                column.addArrangedSubview(box)
                box.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            }
        }
    }
    private func makeSpecial() -> NSView {
        page { column in
            heading(L("special.listsHeading"), into: column)
            for operation in TextTransform.specialLists { check(operation.title, key: "list.\(operation.rawValue)", into: column) }
            heading(L("special.typographyHeading"), into: column)
            for option in TypographyOption.allCases { check(option.title, key: "typography.\(option.rawValue)", into: column) }
        }
    }
    func refresh() {
        let selected = TypographyOption.savedOptions
        for button in checks {
            let key = button.identifier!.rawValue
            let on: Bool
            if key.hasPrefix("list."), let id = Int(key.dropFirst(5)) { on = PaletteConfiguration.listEnabled(id) }
            else if key.hasPrefix("typography."), let id = Int(key.dropFirst(11)) { on = selected.contains { $0.rawValue == id } }
            else { on = PaletteConfiguration.shown(key, profile: editingProfile) }
            button.state = on ? .on : .off
        }
    }
    @objc private func toggle(_ sender: NSButton) {
        let key = sender.identifier!.rawValue
        if key.hasPrefix("list."), let id = Int(key.dropFirst(5)) {
            UserDefaults.standard.set(sender.state == .on, forKey: "specialListEnabled-\(id)")
        } else if key.hasPrefix("typography."), let id = Int(key.dropFirst(11)), let option = TypographyOption(rawValue: id) {
            var selected = TypographyOption.savedOptions.filter { $0 != option }
            if sender.state == .on { selected.append(option) }
            UserDefaults.standard.set(selected.map(\.rawValue), forKey: "specialTypographyOptions")
        } else { UserDefaults.standard.set(sender.state == .on, forKey: PaletteConfiguration.visibilityKey(key, profile: editingProfile)) }
        refresh()
        onChange?()
    }
}

private final class SettingsDocumentView: NSView { override var isFlipped: Bool { true } }
