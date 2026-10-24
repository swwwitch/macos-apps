import AppKit
import Carbon

/// アプリを呼び出すホットキー（初期値 ⌃⇧⌘F）。起動中に押すとメインウインドウを開く。
/// Carbon の登録は同じキーのアプリすべてに届くので、同じキーを「前面のアプリだけ」で申告しているほかの自作アプリ
/// （1.4.0 の ⌃⌥⌘F は FolderHopper の Finder、SpreadsheetHelper の Google スプレッドシートと重なっていた）が起動中で、
/// その前面アプリのときは登録を外して譲る
@MainActor
final class AppHotkey: ObservableObject {
    static let shared = AppHotkey()
    static let enabledKey = "appHotkeyEnabled"
    static let comboKey = "appHotkey"
    static let fieldID = "fontswitcher.appHotkey"
    static let defaultCombo = KeyCombo(code: UInt32(kVK_ANSI_F), modifiers: KeyCombo.control | KeyCombo.shift | KeyCombo.command)
    /// 1.4.0 の初期値。FolderHopper・SpreadsheetHelper と重なるので、そのまま使っていたら1回だけ新しい初期値に移す
    private static let oldDefaultCombo = KeyCombo(code: UInt32(kVK_ANSI_F), modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.command)
    private static let migratedKey = "appHotkeyMigratedFromControlOptionCommandF"

    @Published var enabled: Bool { didSet { save(); apply() } }
    @Published var combo: KeyCombo? { didSet { save(); apply() } }
    /// 登録に失敗した（ほかのアプリが専有している）
    @Published private(set) var failed = false
    var onPress: (() -> Void)?

    private let hotkeys = HotkeySet(signature: "FSwt")
    private var observer: NSObjectProtocol?

    private init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        // 保存なし＝初期値、空のデータ＝割り当てを解除した
        if let data = defaults.data(forKey: Self.comboKey) {
            combo = data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
        } else {
            combo = Self.defaultCombo
        }
        if !defaults.bool(forKey: Self.migratedKey) {
            defaults.set(true, forKey: Self.migratedKey)
            if combo == Self.oldDefaultCombo {
                combo = Self.defaultCombo
                defaults.set(try? JSONEncoder().encode(Self.defaultCombo), forKey: Self.comboKey)
            }
        }
    }

    func start() {
        hotkeys.action = { [weak self] _ in self?.onPress?() }
        // 前面のアプリが変わるたびに、譲るかどうかを決め直す
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in AppHotkey.shared.apply() } }
        apply()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: Self.enabledKey)
        defaults.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: Self.comboKey)
    }

    func apply() {
        defer { publish() }
        guard enabled, let combo else {
            hotkeys.unregister(1)
            failed = false
            return
        }
        if HotkeyManifest.claimedByOtherApp(keyCode: Int(combo.code), modifiers: Int(combo.modifiers),
                                            front: NSWorkspace.shared.frontmostApplication) {
            hotkeys.unregister(1)
            failed = false
        } else if !hotkeys.registered.contains(1) {
            failed = hotkeys.register(1, combo) != noErr
        }
    }

    /// HotkeyHound が読む一覧に申告する
    private func publish() {
        guard let combo else { HotkeyManifest.publish([]); return }
        HotkeyManifest.publish([HotkeyManifest.Item(
            id: "appHotkey", title: L("メインウインドウを開く"), keyCode: Int(combo.code), modifiers: Int(combo.modifiers),
            enabled: enabled, scope: "custom",
            note: L("どのアプリからでも。同じキーを前面のアプリ専用で使うほかの自作アプリがあるときは、そのアプリが前面の間だけ譲る"))])
    }
}
