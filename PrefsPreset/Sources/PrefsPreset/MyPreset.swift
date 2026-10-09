import AppKit
import SwiftUI

/// マイプリセット：今のMacの設定一式を、クリーンインストールで消えない場所（既定は iCloud Drive）に1つ保存しておく
@MainActor
enum MyPreset {
    /// 保存先フォルダを変えたときだけ UserDefaults に入る。新しいMacでは既定の iCloud Drive に戻る
    static let folderKey = "myPresetFolder"
    static let fileName = "My Preset.prefspreset"
    static let previousName = "My Preset (previous).prefspreset"

    static var iCloudDrive: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    }
    static var defaultFolder: URL { iCloudDrive.appendingPathComponent("PrefsPreset") }
    static var folder: URL {
        if let path = UserDefaults.standard.string(forKey: folderKey) { return URL(fileURLWithPath: path) }
        return defaultFolder
    }
    static var file: URL { folder.appendingPathComponent(fileName) }
    static var usesICloud: Bool { UserDefaults.standard.string(forKey: folderKey) == nil }

    /// 最後に保存した日時（ファイルが無ければ nil）
    static var savedDate: Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }

    /// 全項目の「現在の値」を保存する。前回のものは1つだけ (previous) として残す
    static func save() {
        let store = Store.shared
        if usesICloud, !FileManager.default.fileExists(atPath: iCloudDrive.path) {
            store.message = (L("マイプリセットを保存できませんでした"),
                             L("iCloud Driveが使えません。システム設定でiCloud Driveをオンにするか、設定の「マイプリセット」タブで保存先を変えてください。"))
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
                try FileManager.default.copyItem(at: file, to: previous)
            }
            try data.write(to: file, options: .atomic)
            store.message = (L("マイプリセットを保存しました"),
                             L("%@件の設定を「%@」に保存しました。新しいMacでは「マイプリセットを読み込む」を選び、「適用」を押します。",
                               String(store.entries.count), file.path))
        } catch {
            store.message = (L("マイプリセットを保存できませんでした"), error.localizedDescription)
        }
    }

    /// マイプリセットの値を「変更後」に入れる
    static func load() {
        guard FileManager.default.fileExists(atPath: file.path) else {
            Store.shared.message = (L("マイプリセットがありません"),
                                    L("「%@」が見つかりません。iCloud Driveの同期が終わっていない場合は、しばらく待ってからもう一度選んでください。", file.path))
            return
        }
        openPreset(file)
    }

    static func showFolder() {
        if FileManager.default.fileExists(atPath: file.path) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }

    static func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L("選択")
        panel.directoryURL = folder
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: folderKey)
        }
    }

    static func resetFolder() { UserDefaults.standard.removeObject(forKey: folderKey) }
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

/// 設定の「マイプリセット」タブ
struct MyPresetSettings: View {
    @AppStorage(MyPreset.folderKey) private var folderPath: String?

    var body: some View {
        SettingsSection(L("保存先")) {
            Text(MyPreset.folder.path)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("変更…")) { MyPreset.chooseFolder() }
                Button(L("iCloud Driveに戻す")) { MyPreset.resetFolder() }
                    .disabled(folderPath == nil)
            }
            Text(L("新しいMacでは既定のiCloud Driveを探します。別のフォルダに変えた場合は、新しいMacでも同じフォルダを指定し直してください。"))
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
