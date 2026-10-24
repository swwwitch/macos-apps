import Foundation

/// 旧名 FontSwitcher（Bundle ID jp.dtp-transit.fontswitcher）からの引き継ぎ。1.24.0 で Bundle ID を変えたので、
/// 初めて起動したときに一度だけ、旧 ID の設定とライブラリのフォルダーを写す（旧の側は消さない）。
/// 共有ライブラリのファイル名（FontSwitcher-Library.json）は、ほかのMacとそろえるため旧名のまま使う
enum LegacyMigration {
    static let oldBundleID = "jp.dtp-transit.fontswitcher"
    static let doneKey = "migratedFromFontSwitcher"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        copySettings(into: defaults)
        copyLibraryFolder()
    }

    /// 旧 ID の設定を写す。新しい ID ですでに決めた値は上書きしない
    private static func copySettings(into defaults: UserDefaults) {
        let domain = oldBundleID as CFString
        guard let keys = CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String],
              let values = CFPreferencesCopyMultiple(keys as CFArray, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any]
        else { return }
        for (key, value) in values where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    /// ~/Library/Application Support/FontSwitcher を NotMyType に写す（新しい方が無いときだけ）
    private static func copyLibraryFolder() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = support.appendingPathComponent("FontSwitcher", isDirectory: true)
        let new = support.appendingPathComponent("NotMyType", isDirectory: true)
        guard FileManager.default.fileExists(atPath: old.path), !FileManager.default.fileExists(atPath: new.path) else { return }
        try? FileManager.default.copyItem(at: old, to: new)
    }
}
