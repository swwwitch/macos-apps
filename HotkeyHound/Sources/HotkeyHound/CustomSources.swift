import Foundation

/// 設定で追加した独自の照合元（設定ファイルを読めないアプリのホットキーを手入力で控える）
struct CustomSource: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var hotkeys: [CustomHotkey] = []

    var source: HotkeySource { HotkeySource(rawValue: CustomSources.prefix + id.uuidString) }
}

/// 独自の照合元に登録した1件
struct CustomHotkey: Codable, Identifiable, Hashable {
    var id = UUID()
    var keyCode: Int?
    /// KeyModifiers の rawValue
    var modifiers = 0
    var title = ""
    /// 効く範囲（空ならすべてのアプリ）
    var scope = ""

    var combo: KeyCombo? {
        get { keyCode.map { KeyCombo(keyCode: $0, modifiers: KeyModifiers(rawValue: modifiers)) } }
        set { keyCode = newValue?.keyCode; modifiers = newValue?.modifiers.rawValue ?? 0 }
    }
}

/// 独自の照合元の保存先（UserDefaults に JSON で）
enum CustomSources {
    static let prefix = "custom."
    static let key = "customSources"

    /// 一覧の行ごとに名前を引くので、読み込んだものを控えておく（読み込みはバックグラウンドからも呼ばれる）
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [CustomSource]?

    static func load() -> [CustomSource] {
        lock.lock(); defer { lock.unlock() }
        if let cache { return cache }
        let list = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([CustomSource].self, from: $0) } ?? []
        cache = list
        return list
    }

    static func save(_ list: [CustomSource]) {
        lock.lock(); defer { lock.unlock() }
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
        cache = list
    }

    /// 照合用の一覧（キー未設定の行は除く）
    static func scan(_ source: HotkeySource) -> [HotkeyEntry] {
        guard let custom = load().first(where: { $0.source == source }) else { return [] }
        return custom.hotkeys.compactMap { hotkey in
            guard let combo = hotkey.combo else { return nil }
            let scope = hotkey.scope.trimmingCharacters(in: .whitespaces)
            return HotkeyEntry(source: source, combo: combo, title: hotkey.title.isEmpty ? L("（名前なし）") : hotkey.title,
                               scope: scope.isEmpty ? HotkeyScanners.allApps : scope)
        }
    }
}
