import AppKit
import SwiftUI

/// マイプリセット：今のMacの設定一式を、クリーンインストールで消えない場所に1つ保存しておく
/// 保存先は「設定の共有」の同期フォルダー。未設定なら iCloud Drive の PrefsPreset フォルダ。
/// macOS の設定を書き換えるので、同期フォルダーに置いても自動では適用しない（読み込んで「適用」を押す）
@MainActor
enum MyPreset {
    /// 1.1.10 までの保存先の指定（設定の「マイプリセット」タブ）。読み込みで見つからないときだけ探す
    private static let legacyFolderKey = "myPresetFolder"
    private static let legacyFileName = "My Preset.prefspreset"

    static var iCloudDrive: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    }
    static var defaultFolder: URL { iCloudDrive.appendingPathComponent("PrefsPreset") }
    static var usesICloud: Bool { !SettingsSync.shared.enabled }
    static var folder: URL { SettingsSync.shared.folder ?? defaultFolder }
    /// 同期フォルダーはほかのアプリの設定ファイルと並ぶので、「<アプリ名>-Settings.plist」に合わせてアプリ名を付ける
    static var fileName: String { usesICloud ? legacyFileName : "PrefsPreset-My Preset.prefspreset" }
    static var previousName: String { fileName.replacingOccurrences(of: ".prefspreset", with: " (previous).prefspreset") }
    static var file: URL { folder.appendingPathComponent(fileName) }

    /// 保存先に無いときに読む、以前の保存先のファイル
    private static var legacyFiles: [URL] {
        var folders = [defaultFolder]
        if let path = UserDefaults.standard.string(forKey: legacyFolderKey) { folders.insert(URL(fileURLWithPath: path), at: 0) }
        return folders.map { $0.appendingPathComponent(legacyFileName) }.filter { $0 != file }
    }

    /// 最後に保存した日時（ファイルが無ければ nil）
    static var savedDate: Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }

    /// 全項目の「現在の値」を保存する。前回のものは1つだけ (previous) として残す
    static func save() {
        let store = Store.shared
        if usesICloud, !FileManager.default.fileExists(atPath: iCloudDrive.path) {
            store.message = (L("マイプリセットを保存できませんでした"),
                             L("iCloud Driveが使えません。システム設定でiCloud Driveをオンにするか、設定の「設定の共有」で同期フォルダーを選んでください。"))
            return
        }
        if FileManager.default.fileExists(atPath: file.path) {
            let alert = NSAlert()
            alert.messageText = L("マイプリセットを今の設定で上書きしますか？")
            alert.informativeText = L("前回のマイプリセットは「%@」として残します。", previousName)
            alert.addButton(withTitle: L("上書き"))
            alert.addButton(withTitle: L("キャンセル"))
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        store.refreshCurrent()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try store.presetData(store.entries.map { ($0, $0.current) })
            let previous = folder.appendingPathComponent(previousName)
            if FileManager.default.fileExists(atPath: file.path) {
                try? FileManager.default.removeItem(at: previous)
                let previousData = try Data(contentsOf: file)
                guard let root = try PropertyListSerialization.propertyList(from: previousData, format: nil) as? [String: Any] else {
                    throw CocoaError(.propertyListReadCorrupt)
                }
                let sanitized = PresetExportPolicy.removingMachineNames(from: root)
                try PropertyListSerialization.data(fromPropertyList: sanitized, format: .xml, options: 0)
                    .write(to: previous, options: .atomic)
            }
            try data.write(to: file, options: .atomic)
            store.message = (L("マイプリセットを保存しました"),
                             L("%@件の設定を「%@」に保存しました。新しいMacでは「マイプリセットを読み込む」を選び、「適用」を押します。",
                               String(store.entries.filter { PresetImportPolicy.canImport(domains: $0.item.domains) }.count), file.path))
        } catch {
            store.message = (L("マイプリセットを保存できませんでした"), error.localizedDescription)
        }
    }

    /// マイプリセットの値を「変更後」に入れる
    static func load() {
        let found = ([file] + legacyFiles).first { FileManager.default.fileExists(atPath: $0.path) }
        guard let found else {
            Store.shared.message = (L("マイプリセットがありません"),
                                    L("「%@」が見つかりません。iCloud Driveの同期が終わっていない場合は、しばらく待ってからもう一度選んでください。", file.path))
            return
        }
        openPreset(found)
    }

    static func showFolder() {
        if FileManager.default.fileExists(atPath: file.path) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }
}

/// 一覧の上のマイプリセットのメニュー
struct MyPresetMenu: View {
    var body: some View {
        Menu {
            Button(L("現在の設定をマイプリセットに保存…")) { MyPreset.save() }
            Button(L("マイプリセットを読み込む")) { MyPreset.load() }
            Divider()
            Button(L("マイプリセットのフォルダを表示")) { MyPreset.showFolder() }
            if let date = MyPreset.savedDate {
                Divider()
                Text(L("最終保存：%@", date.formatted(date: .abbreviated, time: .shortened)))
            }
        } label: {
            Label(L("マイプリセット"), systemImage: "person.crop.square")
        }
        .fixedSize()
        .help(L("今のMacの設定一式をiCloud Driveに保存し、新しいMacで読み込む"))
    }
}

/// 設定の「設定の共有」タブ：共通の「書き出し・読み込み」「設定の同期」に、マイプリセットの節を足す
struct PrefsPresetSharingView: View {
    @ObservedObject private var sync = SettingsSync.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSharingView()
            SettingsSection(L("マイプリセット")) {
                Text(MyPreset.file.path)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(L("現在の設定をマイプリセットに保存…")) { MyPreset.save() }
                    Button(L("マイプリセットを読み込む")) { MyPreset.load() }
                    Button(L("フォルダを表示")) { MyPreset.showFolder() }
                }
                Text(L("macOSの設定一式（.prefspreset）を、設定の同期のフォルダーに保存します。同期フォルダーを選んでいなければ iCloud Drive の PrefsPreset フォルダに保存します。macOSの設定を書き換えるため、自動では適用しません。新しいMacでは読み込んでから「適用」を押します。"))
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
