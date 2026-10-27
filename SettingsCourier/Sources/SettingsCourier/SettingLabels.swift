import Foundation

/// A label is evidence about a stored key, never a reason to change its value or export selection.
struct SettingLabel {
    let title: String
    let evidence: String
}

enum SettingLabels {
    /// Only exact keys in the selected application's Localizable table are candidates.
    /// Do not guess by splitting camelCase or matching similar words.
    static func resolve(key: String, bundleID: String, bundle: Bundle?) -> SettingLabel? {
        if bundle?.object(forInfoDictionaryKey: "SWAppFamily") as? String == "swwwitch" {
            let title: String?
            switch key {
            case "hideFromDockAndAppSwitcher": title = DockPresence.title
            case "shared.menuBar.enabled": title = L("メニューバーに表示")
            case "settingsSyncFolder": title = L("設定の共有：同期フォルダー")
            default: title = nil
            }
            if let title { return SettingLabel(title: title, evidence: L("共通部品のソースで確認（アプリの版により文言が異なる場合があります）")) }
        }
        if bundleID == "jp.dtp-transit.settingscourier", key == "autoExportOnQuit" {
            return SettingLabel(title: L("登録したアプリを終了したときに書き出す"), evidence: L("SettingsCourierのソースで確認"))
        }
        if key.hasPrefix("NSWindow Frame ") {
            return SettingLabel(title: L("ウインドウの位置・サイズ"), evidence: L("内部保存値（設定画面の項目ではありません）"))
        }
        if key.hasPrefix("NSSplitView Subview Frames ") {
            return SettingLabel(title: L("分割ビューの位置・サイズ"), evidence: L("内部保存値（設定画面の項目ではありません）"))
        }
        if let bundle {
            let missing = "__SettingsCourier_missing_3DF431__"
            let text = bundle.localizedString(forKey: key, value: missing, table: "Localizable")
            if text != missing, text != key, !text.isEmpty {
                return SettingLabel(title: text, evidence: L("候補：アプリ内の翻訳キーが一致。画面との対応は未確認です"))
            }
        }
        return nil
    }

    /// Preserve types and nested contents, including Data (base64) and dates (UTC).
    static func fullValue(_ value: NSObject) -> String {
        if let data = try? PropertyListSerialization.data(fromPropertyList: ["value": value], format: .xml, options: 0),
           let text = String(data: data, encoding: .utf8) { return text }
        return value.description
    }
}
