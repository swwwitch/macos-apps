import Foundation

/// Illustrator のキーボードショートカット（使用中のセットの .kys）。
/// 使用中のセットは ~/Library/Preferences/Adobe Illustrator <版> Settings/<言語>/Adobe Illustrator 環境設定（Prefs）の
/// /KBSCShortcutFile の /FileName（16 進）。/IsPreset 1 は既定のセットで、.kys は無い
enum IllustratorHotkeys {
    static let bundleID = "com.adobe.illustrator"

    static func scan() -> [HotkeyEntry] {
        guard let (folder, version) = settingsFolder() else { return [] }
        // 使用中のセット。自作のセットはその .kys、既定のセット（プリセット）は同梱した既定の .kys を読む
        let active = prefsText(folder).flatMap(activeSet)
        var setName = L("Illustrator デフォルト")
        var text: String?
        if let active, !active.isPreset, let name = active.name {
            text = try? String(contentsOf: folder.appendingPathComponent(name + ".kys"), encoding: .utf8)
            if text != nil { setName = name }
        }
        if text == nil, let url = Bundle.main.url(forResource: "IllustratorDefault", withExtension: "kys") {
            text = try? String(contentsOf: url, encoding: .utf8)
        }
        guard let text else { return [] }
        let scope = L("%@が前面のとき", "Illustrator \(version)")
        let names = commandNames()
        let commands = parse(text).map { item in
            let path = names[item.id] ?? item.id
            let parts = path.components(separatedBy: " > ")
            return entry(item.combo, title: parts.last ?? path,
                         group: [L("セット「%@」", setName), parts.count > 1 ? parts.dropLast().joined(separator: " › ") : nil]
                            .compactMap { $0 }.joined(separator: " · "),
                         scope: item.inText ? L("Illustratorで文字を編集中") : scope)
        }
        // ツールの切り替えキー（V・A など）は .kys に入らないので、既定のショートカット一覧から補う
        let tools = defaultTools().map { entry($0.combo, title: $0.name, group: L("ツール"), scope: scope) }
        return commands + tools
    }

    private static func entry(_ combo: KeyCombo, title: String, group: String, scope: String) -> HotkeyEntry {
        var entry = HotkeyEntry(source: .illustrator, combo: combo, title: title, group: group, scope: scope)
        entry.ownerBundleID = bundleID
        entry.apps = .only([bundleID])
        return entry
    }

    /// 正式版のうちいちばん新しい版の設定フォルダ（ベータ・プレリリースは除く）。言語フォルダは日本語を優先
    private static func settingsFolder() -> (URL, String)? {
        let preferences = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: preferences.path)) ?? []
        let versions = names.compactMap { name -> (Int, String)? in
            guard name.hasPrefix("Adobe Illustrator "), name.hasSuffix(" Settings") else { return nil }
            let version = name.dropFirst("Adobe Illustrator ".count).dropLast(" Settings".count)
            return Int(version).map { ($0, name) }
        }
        guard let latest = versions.max(by: { $0.0 < $1.0 }) else { return nil }
        let root = preferences.appendingPathComponent(latest.1)
        let locales = ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.contains("_") }.sorted()
        guard let locale = locales.first(where: { $0 == "ja_JP" }) ?? locales.first else { return nil }
        return (root.appendingPathComponent(locale), String(latest.0))
    }

    private static func prefsText(_ folder: URL) -> String? {
        for name in ["Adobe Illustrator 環境設定", "Adobe Illustrator Prefs"] {
            if let data = try? Data(contentsOf: folder.appendingPathComponent(name)) {
                return String(decoding: data, as: UTF8.self)
            }
        }
        return nil
    }

    /// /KBSCShortcutFile { /FileName [ 7 73772d32303230 ] /IsPreset 0 }。項目が無いときは既定のセット
    static func activeSet(_ prefs: String) -> (name: String?, isPreset: Bool)? {
        guard let range = prefs.range(of: "/KBSCShortcutFile") else { return nil }
        let block = prefs[range.upperBound...].prefix(300)
        let isPreset = block.range(of: #"/IsPreset\s+1"#, options: .regularExpression) != nil
        return (fileName(block), isPreset)
    }

    private static func fileName(_ block: Substring) -> String? {
        guard let match = block.range(of: #"/FileName\s*\[\s*\d+\s+([0-9a-fA-F\s]+)\]"#, options: .regularExpression) else { return nil }
        let hex = block[match].drop { $0 != "[" }.dropFirst().split(whereSeparator: \.isWhitespace).dropFirst().joined()
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex), index < hex.endIndex {
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        let name = String(decoding: bytes, as: UTF8.self)
        return name.isEmpty ? nil : name
    }

    // MARK: .kys の形式（実測）
    // /Menus { /<ID> { /Context 0 /Modifiers 64 /Represent 67 /Key 67 } … } /Tools { … }
    // Modifiers は ⌘64・⇧32・⌥128（Illustrator のショートカットに ⌃ は使えない）、Key は文字コード（英字は大文字）、F1〜F12 は 14〜25、Tab は 9。
    // Context 1 は文字の編集中だけ効くもの。Key 0 は未設定。ID の空白は「\ 」、日本語は「\ooo」の 8 進

    struct Item { let id: String; let combo: KeyCombo; let inText: Bool }

    static func parse(_ text: String) -> [Item] {
        let pattern = #"/((?:\\.|[^\s{\\])+)\s*\{\s*/Context\s+(\d+)\s*/Modifiers\s+(\d+)\s*/Represent\s+(\d+)\s*/Key\s+(\d+)\s*\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = text as NSString
        var items: [Item] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            func value(_ index: Int) -> Int { Int(source.substring(with: match.range(at: index))) ?? 0 }
            let key = value(5)
            guard key != 0, let combo = combo(key: key, modifiers: value(3)) else { continue }
            items.append(Item(id: unescape(source.substring(with: match.range(at: 1))), combo: combo, inText: value(2) == 1))
        }
        return items
    }

    static func combo(key: Int, modifiers flags: Int) -> KeyCombo? {
        var modifiers: KeyModifiers = []
        if flags & 64 != 0 { modifiers.insert(.command) }
        if flags & 32 != 0 { modifiers.insert(.shift) }
        if flags & 128 != 0 { modifiers.insert(.option) }
        if let code = specialKeys[key] { return KeyCombo(keyCode: code, modifiers: modifiers) }
        guard let scalar = Unicode.Scalar(key),
              let found = KeyNames.keyCode(forCharacter: String(Character(scalar)).lowercased(), caseImpliesShift: false) else { return nil }
        if found.shift { modifiers.insert(.shift) }
        return KeyCombo(keyCode: found.keyCode, modifiers: modifiers)
    }

    /// F1〜F12・Tab
    static let specialKeys: [Int: Int] = [
        9: 48, 14: 122, 15: 120, 16: 99, 17: 118, 18: 96, 19: 97, 20: 98, 21: 100, 22: 101, 23: 109, 24: 103, 25: 111
    ]

    /// 「\ 」→空白、「\ooo」→バイト（UTF-8）
    static func unescape(_ raw: String) -> String {
        var bytes: [UInt8] = []
        var characters = Array(raw.utf8)[...]
        while let byte = characters.popFirst() {
            guard byte == UInt8(ascii: "\\"), let next = characters.first else { bytes.append(byte); continue }
            let digits = characters.prefix(3)
            if digits.count == 3, digits.allSatisfy({ (48...55).contains($0) }), let value = UInt8(String(decoding: digits, as: UTF8.self), radix: 8) {
                bytes.append(value)
                characters = characters.dropFirst(3)
            } else {
                bytes.append(next)
                characters = characters.dropFirst()
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// 既定のツールのショートカット（Illustrator の「テキストとして書き出し」の「ツール」から作った表。「Shift+O」「¥」など）
    static func defaultTools() -> [(name: String, combo: KeyCombo)] {
        guard let url = Bundle.main.url(forResource: "IllustratorTools", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let columns = line.split(separator: "\t")
            guard columns.count == 2, let combo = combo(text: String(columns[1])) else { return nil }
            return (String(columns[0]), combo)
        }
    }

    /// 「Shift+Cmd+K」形式。最後の「+」の後ろがキー（「Shift++」は＋キー）
    static func combo(text: String) -> KeyCombo? {
        var rest = Substring(text)
        var modifiers: KeyModifiers = []
        let names: [(String, KeyModifiers)] = [("Shift+", .shift), ("Cmd+", .command), ("Option+", .option), ("Alt+", .option)]
        while let found = names.first(where: { rest.hasPrefix($0.0) && rest.count > $0.0.count }) {
            modifiers.insert(found.1)
            rest = rest.dropFirst(found.0.count)
        }
        let key = String(rest)
        if key == "Tab" { return KeyCombo(keyCode: 48, modifiers: modifiers) }
        guard key.count == 1, let found = KeyNames.keyCode(forCharacter: key.lowercased(), caseImpliesShift: false) else { return nil }
        if found.shift { modifiers.insert(.shift) }
        return KeyCombo(keyCode: found.keyCode, modifiers: modifiers)
    }

    /// コマンド ID → メニューの階層つきの名前（AT-doc の ExtendScript.txt から作った表。日本語・英語）
    static func commandNames() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "IllustratorCommands", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        let japanese = (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")
        var names: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else { continue }
            let name = String(japanese ? columns[1] : columns[2])
            if !name.isEmpty { names[String(columns[0])] = name }
        }
        return names
    }
}
