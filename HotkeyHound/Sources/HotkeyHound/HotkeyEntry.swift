import AppKit

/// ホットキーの定義元。組み込みのものと、設定で追加した独自の照合元（custom.<UUID>）
struct HotkeySource: Hashable, Identifiable, Sendable {
    let rawValue: String

    static let system = HotkeySource(rawValue: "system")
    static let services = HotkeySource(rawValue: "services")
    static let userKeyEquivalents = HotkeySource(rawValue: "userKeyEquivalents")
    static let menus = HotkeySource(rawValue: "menus")
    static let keyboardMaestro = HotkeySource(rawValue: "keyboardMaestro")
    static let betterTouchTool = HotkeySource(rawValue: "betterTouchTool")
    static let karabiner = HotkeySource(rawValue: "karabiner")
    static let alfred = HotkeySource(rawValue: "alfred")
    static let defaultFolderX = HotkeySource(rawValue: "defaultFolderX")
    static let keystrokePro = HotkeySource(rawValue: "keystrokePro")
    static let swApps = HotkeySource(rawValue: "swApps")
    static let keyboardShortcuts = HotkeySource(rawValue: "keyboardShortcuts")
    static let atok = HotkeySource(rawValue: "atok")
    static let illustrator = HotkeySource(rawValue: "illustrator")

    static let builtIns: [HotkeySource] = [.system, .services, .userKeyEquivalents, .menus, .keyboardMaestro, .betterTouchTool,
                                           .karabiner, .alfred, .defaultFolderX, .keystrokePro, .atok, .illustrator, .swApps, .keyboardShortcuts]

    static let orderKey = "source.order"

    /// 設定の並び順。保存した順に並べ、新しく増えた組み込みは既定の位置、独自の照合元は末尾に足す
    static var ordered: [HotkeySource] {
        let available = builtIns + CustomSources.load().map(\.source)
        let saved = (UserDefaults.standard.stringArray(forKey: orderKey) ?? []).map(HotkeySource.init(rawValue:)).filter(available.contains)
        var result = saved
        for source in available where !result.contains(source) {
            if let builtIn = builtIns.firstIndex(of: source), builtIn > 0, let previous = result.firstIndex(of: builtIns[builtIn - 1]) {
                result.insert(source, at: previous + 1)
            } else if builtIns.first == source {
                result.insert(source, at: 0)
            } else {
                result.append(source)
            }
        }
        return result
    }

    static func saveOrder(_ list: [HotkeySource]) {
        UserDefaults.standard.set(list.map(\.rawValue), forKey: orderKey)
    }

    var id: String { rawValue }
    var isCustom: Bool { rawValue.hasPrefix(CustomSources.prefix) }
    var custom: CustomSource? { isCustom ? CustomSources.load().first { $0.source == self } : nil }

    var title: String {
        switch self {
        case .system: L("macOSのホットキー")
        case .services: L("サービス")
        case .userKeyEquivalents: L("アプリのショートカット（システム設定）")
        case .menus: L("起動中のアプリのメニュー")
        case .keyboardMaestro: "Keyboard Maestro"
        case .betterTouchTool: "BetterTouchTool"
        case .karabiner: "Karabiner-Elements"
        case .alfred: "Alfred"
        case .defaultFolderX: "Default Folder X"
        case .keystrokePro: "Keystroke Pro"
        case .swApps: L("自作アプリ（swwwitch）")
        case .keyboardShortcuts: L("KeyboardShortcuts形式のアプリ")
        case .atok: "ATOK"
        case .illustrator: "Adobe Illustrator"
        default: custom?.name ?? L("独自の照合元")
        }
    }

    /// アイコンと起動状態の判定に使うアプリ
    var bundleIDs: [String] {
        switch self {
        case .system, .services, .userKeyEquivalents: ["com.apple.systempreferences"]
        case .menus, .swApps, .keyboardShortcuts: []
        case .keyboardMaestro: ["com.stairways.keyboardmaestro.editor"]
        case .betterTouchTool: ["com.hegenberg.BetterTouchTool", "com.hegenberg.bettertouchtool-setapp"]
        case .karabiner: ["org.pqrs.Karabiner-Elements.Settings"]
        case .alfred: ["com.runningwithcrayons.Alfred"]
        case .defaultFolderX: ["com.stclairsoft.DefaultFolderX5", "com.stclairsoft.DefaultFolderX5-setapp"]
        case .keystrokePro: ["de.ixeau.KeystrokePro2"]
        case .illustrator: [IllustratorHotkeys.bundleID]
        case .atok: (33...45).reversed().map { "com.justsystems.inputmethod.atok\($0)" }
        default: []
        }
    }

    /// 動いていないとホットキーが効かないプロセス（nil は判定しない）
    var engineBundleIDs: [String]? {
        switch self {
        case .keyboardMaestro: ["com.stairways.keyboardmaestro.engine"]
        case .betterTouchTool: bundleIDs
        case .alfred: bundleIDs
        case .defaultFolderX: bundleIDs
        case .keystrokePro: bundleIDs
        case .atok: bundleIDs
        case .illustrator: bundleIDs
        default: nil
        }
    }

    /// 項目ごとに定義元のアプリが異なる（アイコンと起動状態は ownerBundleID で見る）
    var isPerApp: Bool { [.menus, .swApps, .keyboardShortcuts].contains(self) }

    var settingKey: String { "source.\(rawValue)" }
    var isIncluded: Bool { UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true }

    @MainActor var icon: NSImage {
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        switch self {
        case .swApps: return NSApp.applicationIconImage
        case .keyboardShortcuts: return NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) ?? NSImage()
        case _ where isCustom: return NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil) ?? NSImage()
        default: return NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil) ?? NSImage()
        }
    }

    /// 定義元のアプリが動いているか（判定しないものは nil）
    @MainActor var isRunning: Bool? {
        guard let ids = engineBundleIDs else { return nil }
        return NSWorkspace.shared.runningApplications.contains { ids.contains($0.bundleIdentifier ?? "") }
    }
}

/// 見つかったホットキー1件
struct HotkeyEntry: Identifiable, Hashable {
    let id = UUID()
    let source: HotkeySource
    let combo: KeyCombo
    /// マクロ名・メニュー項目名など
    let title: String
    /// グループ・メニューの階層・プリセット
    var group: String?
    /// 効く範囲（すべてのアプリ／特定のアプリだけ など）の表示
    var scope: String
    /// 効く範囲の判定用（最前面のアプリで絞るとき）
    var apps = AppScope.all
    /// 設定で無効にされている
    var isEnabled = true
    /// メニューの持ち主など、アイコンに使うアプリ
    var ownerBundleID: String?
    var ownerPID: pid_t?
    /// 補足（Karabiner の変換先など）
    var note: String?
    /// 修飾キーを追加で押しても反応する（Karabiner の optional: any）
    var allowsExtraModifiers = false

    /// 定義元のアプリが動いているか（判定しないものは nil）。自作アプリなどは項目ごとのアプリで見る
    @MainActor var isRunning: Bool? {
        guard source == .swApps || source == .keyboardShortcuts else { return source.isRunning }
        guard let ownerBundleID else { return nil }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == ownerBundleID }
    }

    func matches(_ combo: KeyCombo) -> Bool {
        if allowsExtraModifiers {
            return combo.keyCode == self.combo.keyCode && combo.modifiers.isSuperset(of: self.combo.modifiers)
        }
        return self.combo.matches(combo)
    }

    static func == (lhs: HotkeyEntry, rhs: HotkeyEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// ホットキーが効くアプリ。Bundle ID（Karabiner は正規表現）で持つ
struct AppScope: Hashable, Sendable {
    var only: [String]?
    var except: [String] = []
    var usesPatterns = false

    static let all = AppScope()
    static func only(_ ids: [String], patterns: Bool = false) -> AppScope { AppScope(only: ids, usesPatterns: patterns) }
    static func except(_ ids: [String], patterns: Bool = false) -> AppScope { AppScope(except: ids, usesPatterns: patterns) }

    /// 条件が判定できないもの（ファイルダイアログ内など）は効く可能性があるので true
    func applies(to bundleID: String?) -> Bool {
        guard let bundleID else { return only == nil }
        if let only, !only.contains(where: { matches($0, bundleID) }) { return false }
        return !except.contains { matches($0, bundleID) }
    }

    private func matches(_ pattern: String, _ bundleID: String) -> Bool {
        guard usesPatterns else { return pattern == bundleID }
        return bundleID.range(of: pattern, options: .regularExpression) != nil
    }
}

/// そのキーを押せないようにしているアプリ（イベントタップ）・システムの専有
struct InterceptorInfo: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let bundleID: String?
    let canModify: Bool
}
