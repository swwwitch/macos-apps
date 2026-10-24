import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
                Text(SettingsUI.shortcutTitle).padding(.top, 4)
                AppHotkeyView()
            })),
            (L("フォント"), AnyView(FontSettingsView())),
            (L("ホットキー"), AnyView(MenuShortcutsSettingsView())),
            // 共有はまとめて1つのタブに：ライブラリ（フォント・セット・プロジェクト）と設定の値（共通部品）
            (L("共有"), AnyView(VStack(alignment: .leading, spacing: 16) {
                SharingSection()
                SettingsSharingView()
            })),
            (AboutSection.title, AnyView(AboutView())),
        ]).padding(12)
    }
}

/// アプリを呼び出すホットキー（共通の記録欄）
private struct AppHotkeyView: View {
    @ObservedObject private var hotkey = AppHotkey.shared

    var body: some View {
        Toggle(HotkeyText.enable, isOn: $hotkey.enabled)
        HotkeyField(id: AppHotkey.fieldID, combo: $hotkey.combo, defaultCombo: AppHotkey.defaultCombo, allowsClear: true,
                    registered: !hotkey.failed, isEnabled: hotkey.enabled)
        Text(L("NotMyTypeが起動している間、どのアプリからでもメインウインドウを開きます。初期値は⌃⇧⌘F。同じキーを前面のアプリ専用で使うほかの自作アプリが起動しているときは、そのアプリが前面の間だけ譲ります。NotMyTypeが起動していないときは効かないので、「ログイン時に起動」と合わせて使います。"))
            .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// 「フォント」タブ：起動・終了時のアクティブの扱いとプレビューの文字
private struct FontSettingsView: View {
    @AppStorage(LibraryStore.restoreAtLaunchKey) private var restore = true
    @AppStorage(LibraryStore.deactivateOnQuitKey) private var deactivate = false
    @AppStorage(LibraryStore.sampleTextKey) private var sample = LibraryStore.defaultSampleText
    @AppStorage(LibraryStore.includeUserFontsKey) private var includeUserFonts = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("アクティブ")) {
                Toggle(L("起動時に、前回アクティブだったフォントを戻す"), isOn: $restore)
                note(L("NotMyTypeでアクティブにしたフォントは、ログアウトすると解除されます。「ログイン時に起動」と合わせてオンにすると、ログインするたびに戻ります。"))
                Toggle(L("終了するときにすべて解除する"), isOn: $deactivate)
                note(L("オフのときは、終了してもログアウトするまでアクティブのままです。"))
            }
            WatchFoldersSection()
            FontFileHandlerSection()
            AdobeAutoActivationSection()
            SettingsSection(L("システム")) {
                Toggle(L("フォントフォルダーのフォントも一覧に入れる"), isOn: $includeUserFonts)
                note(L("~/Library/Fonts（ユーザー名）・/Library/Fonts（All Users）・/System/Library/Fonts（System）を、起動したときとフォントが変わったときに読み込みます。ユーザー名とAll Usersはチェックボックスで切り替えられ、ファイルは動かさずにmacOSに覚えさせます。Systemは切り替えられません。"))
            }
            SettingsSection(L("プレビュー")) {
                HStack {
                    Text(L("プレビューの文字 :"))
                    TextField("", text: $sample)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(L("プレビューの文字"))
                }
            }
            Button(L("初期値に戻す")) {
                restore = true; deactivate = false; sample = LibraryStore.defaultSampleText; includeUserFonts = true
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Adobe アプリ向けの自動アクティベート
private struct AdobeAutoActivationSection: View {
    @AppStorage(AdobeAutoActivation.enabledKey) private var enabled = false

    var body: some View {
        SettingsSection(L("Adobeアプリ")) {
            Toggle(L("IllustratorとInDesignで開いたドキュメントの足りないフォントを自動でアクティブにする"), isOn: $enabled)
            Text(L("IllustratorかInDesignが前面に来たときに、開いているドキュメントのフォントを調べ、使えないフォントのうちライブラリにPostScript名が一致するものをアクティブにします。ほかのフォントは解除しません。初めて使うとき、macOSがそれぞれのアプリの操作の許可を確認します。Illustratorはドキュメントを保存したときのフォントの一覧を使います。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// フォントファイルを開くアプリ：NotMyType にするか Font Book に戻す
private struct FontFileHandlerSection: View {
    @ObservedObject private var handler = FontFileHandler.shared

    var body: some View {
        SettingsSection(L("フォントファイルを開くアプリ")) {
            HStack {
                Text(L("いま開くアプリ :"))
                Text(summary).foregroundStyle(.secondary).lineLimit(2)
                if handler.working { ProgressView().controlSize(.small) }
            }
            HStack {
                Button(L("フォントファイルをNotMyTypeで開く")) { handler.makeDefault() }
                    .disabled(handler.working || handler.isDefault)
                Button(L("Font Bookに戻す")) { handler.restoreFontBook() }
                    .disabled(handler.working)
            }
            Text(L("フォントファイル（.otf・.ttf・.ttc・.otc・.dfont・.woff・.woff2）をダブルクリックしたときに開くアプリを決めます。NotMyTypeで開くと、ライブラリに追加してそのファミリーを選びます（アクティブにはしません）。切り替えが反映されるまで数秒かかります。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { handler.refresh() }
    }

    /// 形式ごとのアプリを、同じアプリはまとめて出す（例：NotMyType（otf・ttf）、Font Book（woff））
    private var summary: String {
        var order: [String] = []
        var groups: [String: [String]] = [:]
        for (ext, app) in handler.handlers {
            if groups[app] == nil { order.append(app) }
            groups[app, default: []].append(ext)
        }
        return order.map { "\($0)（\(groups[$0]!.joined(separator: "・"))）" }.joined(separator: L("、"))
    }
}

/// ウォッチフォルダー：見張るフォルダーの一覧と追加・削除
private struct WatchFoldersSection: View {
    @ObservedObject private var watch = WatchFolders.shared
    @State private var selection = Set<String>()

    var body: some View {
        SettingsSection(L("ウォッチフォルダー")) {
            List(watch.folders, id: \.self, selection: $selection) { path in
                Label {
                    Text(path).lineLimit(1).truncationMode(.middle)
                } icon: {
                    Image(systemName: FileManager.default.fileExists(atPath: path) ? "folder" : "exclamationmark.triangle")
                }
                .help(path)
            }
            .frame(height: 96)
            .overlay {
                if watch.folders.isEmpty {
                    Text(L("ウォッチフォルダーはありません")).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Button { watch.add() } label: { Image(systemName: "plus") }
                    .help(L("フォルダーを追加…")).accessibilityLabel(L("フォルダーを追加…"))
                Button { watch.remove(selection); selection.removeAll() } label: { Image(systemName: "minus") }
                    .disabled(selection.isEmpty)
                    .help(L("選んだフォルダーを外す")).accessibilityLabel(L("選んだフォルダーを外す"))
                Button { if let path = selection.first { watch.move(path, by: -1) } } label: { Image(systemName: "chevron.up") }
                    .disabled(selection.count != 1 || selection.first == watch.folders.first)
                    .help(L("上へ（重複したフォントで優先する）")).accessibilityLabel(L("上へ"))
                Button { if let path = selection.first { watch.move(path, by: 1) } } label: { Image(systemName: "chevron.down") }
                    .disabled(selection.count != 1 || selection.first == watch.folders.last)
                    .help(L("下へ")).accessibilityLabel(L("下へ"))
                Spacer()
                Button(L("今すぐ読み込む")) { watch.scan() }
                    .disabled(watch.folders.isEmpty)
            }
            Text(L("選んだフォルダー（下の階層も）を見張り、新しいフォントファイルを見つけるとライブラリに追加します。アクティブにはしません。フォルダーから消えたファイルは「見つからない」に出ます。外しても、追加済みのフォントはライブラリに残ります。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(L("同じPostScript名のフォントが複数のフォルダーにあるときは、この一覧で上にあるフォルダーのものを優先してアクティブにします（ウォッチフォルダーの外のものは最後）。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// ライブラリの共有：共有フォルダーの選択と解除
private struct SharingSection: View {
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        SettingsSection(L("ライブラリの共有")) {
            HStack {
                Text(L("共有フォルダー :"))
                Text(store.sharedFolder ?? L("共有していません"))
                    .foregroundStyle(store.sharedFolder == nil ? .secondary : .primary)
                    .lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled)
            }
            HStack {
                Button(L("共有フォルダーを選ぶ…")) { store.chooseSharedFolder() }
                Button(L("共有をやめる")) { store.stopSharing() }
                    .disabled(store.sharedFolder == nil)
            }
            Text(L("Dropboxなどのフォルダーに「FontSwitcher-Library.json」を置き、登録したフォント・セット・お気に入り・アクティブの状態をほかのMacとそろえます。Dropboxとホームフォルダーの中の場所は、Macごとの場所に読み替えます。すでにファイルがあるフォルダーを選ぶと、このMacのライブラリと合わせます。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
