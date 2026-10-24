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
            (L("重複フォント"), AnyView(DuplicateSettingsView())),
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
                folderRow(path)
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
            Text(L("同じPostScript名のフォントが複数のフォルダーにあるときは、この一覧で上にあるフォルダーのものを優先してアクティブにします（ウォッチフォルダーの外のものは最後）。登録済みのフォルダーの中のフォルダーを追加すると、親のすぐ上に入り、親の中のほかのフォルダーより優先します。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 親が一覧にあるフォルダーは字下げし、親からの場所で出す。親より下に置くと優先が効かないので印を出す
    private func folderRow(_ path: String) -> some View {
        let parent = watch.parent(of: path)
        let belowParent = parent.map { parent in
            (watch.folders.firstIndex(of: parent) ?? 0) < (watch.folders.firstIndex(of: path) ?? 0)
        } ?? false
        let name = parent.map { String(path.dropFirst($0.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) } ?? path
        return HStack(spacing: 4) {
            Label {
                Text(name).lineLimit(1).truncationMode(.middle)
            } icon: {
                Image(systemName: FileManager.default.fileExists(atPath: path) ? (parent == nil ? "folder" : "arrow.turn.down.right") : "exclamationmark.triangle")
            }
            if belowParent {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    .help(L("親のフォルダーより下にあるため、重複したフォントの優先に効きません。▲で親より上へ動かします"))
                    .accessibilityLabel(L("親のフォルダーより下にあるため、重複したフォントの優先に効きません。▲で親より上へ動かします"))
            }
        }
        .padding(.leading, CGFloat(watch.depth(of: path)) * 16)
        .help(path)
    }
}

/// 重複フォントのタブ：優先を決める順の説明、規則、形式の順
private struct DuplicateSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("同じPostScript名のフォントが複数あるときは、ウォッチフォルダーの順 → 規則 → ファイルごとの選択 → ファイルの中身で決める条件の順で優先を決めます。"))
                    .font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(L("重複フォントを解決…")) { DuplicateResolverWindow.shared.show() }
            }
            DuplicateRulesSection()
            AutoCriteriaSection()
            FormatOrderSection()
        }
    }
}

/// ファイルの中身で決める条件：形式・バージョン・字形数。チェックで使う・使わない、ドラッグか▲▼で順を変える
private struct AutoCriteriaSection: View {
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(LibraryStore.autoCriteriaOrderKey) private var saved = ""
    @AppStorage(LibraryStore.preferOpenTypeKey) private var format = true
    @AppStorage(LibraryStore.preferNewerVersionKey) private var version = true
    @AppStorage(LibraryStore.preferMoreGlyphsKey) private var glyphs = true
    @AppStorage(LibraryStore.pickIdenticalKey) private var identical = true
    @State private var selection: LibraryStore.AutoCriterion?

    private var order: [LibraryStore.AutoCriterion] { LibraryStore.autoCriteriaOrder(saved) }

    var body: some View {
        SettingsSection(L("ファイルの中身で決める条件")) {
            List(selection: $selection) {
                ForEach(Array(order.enumerated()), id: \.element) { index, criterion in
                    HStack {
                        Text("\(index + 1)").foregroundStyle(.secondary).monospacedDigit().frame(width: 16, alignment: .trailing)
                        Toggle(criterion.title, isOn: binding(criterion))
                    }
                    .tag(criterion)
                }
                .onMove { source, destination in
                    var list = order
                    list.move(fromOffsets: source, toOffset: destination)
                    save(list)
                }
            }
            .frame(height: 84)
            HStack(spacing: 6) {
                Button { move(by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(selection == nil || selection == order.first)
                    .help(L("上へ")).accessibilityLabel(L("上へ"))
                Button { move(by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(selection == nil || selection == order.last)
                    .help(L("下へ")).accessibilityLabel(L("下へ"))
                Spacer()
                Button(L("初期値に戻す")) {
                    save(LibraryStore.AutoCriterion.allCases)
                    format = true; version = true; glyphs = true; identical = true
                    store.invalidate()
                }
                .disabled(order == LibraryStore.AutoCriterion.allCases && format && version && glyphs && identical)
            }
            Toggle(L("それでも残ったものが中身の同じファイル（ハッシュが一致）なら、自動で1つに決める"), isOn: $identical)
                .onChange(of: identical) { store.invalidate() }
            Text(L("ウォッチフォルダーの順・規則・ファイルごとの選択でも決まらないときに、上の条件から順に使います。バージョンはフォントの版（headテーブル）、字形数は収録グリフの数で比べ、分からないファイルがあるときはその条件を飛ばします。中身が同じときは先に登録したファイルを優先します（ハッシュは候補のファイルだけ裏で計ります）。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func binding(_ criterion: LibraryStore.AutoCriterion) -> Binding<Bool> {
        Binding(get: {
            switch criterion {
            case .format: return format
            case .version: return version
            case .glyphs: return glyphs
            }
        }, set: { value in
            switch criterion {
            case .format: format = value
            case .version: version = value
            case .glyphs: glyphs = value
            }
            store.invalidate()
        })
    }

    private func move(by offset: Int) {
        guard let selection, let index = order.firstIndex(of: selection), order.indices.contains(index + offset) else { return }
        var list = order
        list.swapAt(index, index + offset)
        save(list)
    }

    private func save(_ list: [LibraryStore.AutoCriterion]) {
        saved = list.map(\.rawValue).joined(separator: ",")
        store.invalidate()
    }
}

/// 形式の順：同じフォントで形式が異なるときの順。ドラッグか▲▼で変える（使うかどうかは「ファイルの中身で決める条件」の「形式」）
private struct FormatOrderSection: View {
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(LibraryStore.preferOpenTypeKey) private var enabled = true
    @AppStorage(LibraryStore.formatOrderKey) private var saved = ""
    @State private var selection: String?

    private var order: [String] { LibraryStore.formatOrder(saved) }

    var body: some View {
        SettingsSection(L("形式の順")) {
            List(selection: $selection) {
                ForEach(Array(order.enumerated()), id: \.element) { index, ext in
                    HStack {
                        Text("\(index + 1)").foregroundStyle(.secondary).monospacedDigit().frame(width: 16, alignment: .trailing)
                        Text(Self.name(ext))
                        Text("." + ext).foregroundStyle(.secondary)
                    }
                    .tag(ext)
                }
                .onMove { source, destination in
                    var list = order
                    list.move(fromOffsets: source, toOffset: destination)
                    save(list)
                }
            }
            .frame(height: 160)
            .disabled(!enabled)
            HStack(spacing: 6) {
                Button { move(by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(!enabled || selection == nil || selection == order.first)
                    .help(L("上へ")).accessibilityLabel(L("上へ"))
                Button { move(by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(!enabled || selection == nil || selection == order.last)
                    .help(L("下へ")).accessibilityLabel(L("下へ"))
                Spacer()
                Button(L("初期値に戻す")) { save(LibraryStore.defaultFormatOrder) }
                    .disabled(order == LibraryStore.defaultFormatOrder)
            }
            Text(L("上の形式ほど優先します。ドラッグか▲▼で並べ替えます。"))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func move(by offset: Int) {
        guard let selection, let index = order.firstIndex(of: selection), order.indices.contains(index + offset) else { return }
        var list = order
        list.swapAt(index, index + offset)
        save(list)
    }

    private func save(_ list: [String]) {
        saved = list.joined(separator: ",")
        store.invalidate()
    }

    /// 一覧の形式名（FontFile.format と同じ名前）
    static func name(_ ext: String) -> String {
        switch ext {
        case "otf": return "OpenType (CFF)"
        case "otc": return "OpenType Collection"
        case "ttf": return "TrueType"
        case "ttc": return "TrueType Collection"
        case "dfont": return "Datafork TrueType"
        case "woff": return "WOFF"
        case "woff2": return "WOFF2"
        default: return ext.uppercased()
        }
    }
}

/// 重複の優先の規則：「重複フォントを解決」で選んだフォルダーの組と、ファイルごとの選択
private struct DuplicateRulesSection: View {
    @ObservedObject private var store = LibraryStore.shared
    @State private var selection = Set<UUID>()

    var body: some View {
        SettingsSection(L("重複の優先の規則")) {
            List(store.data.folderRules, selection: $selection) { rule in
                VStack(alignment: .leading, spacing: 1) {
                    Text(DuplicateResolver.display(rule.preferred)).lineLimit(1).truncationMode(.middle)
                    Text(L("＞ %@", DuplicateResolver.display(rule.other))).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                .help(L("%@ を %@ より優先", rule.preferred, rule.other))
            }
            .frame(height: 96)
            .overlay {
                if store.data.folderRules.isEmpty { Text(L("規則はありません")).foregroundStyle(.secondary) }
            }
            HStack(spacing: 6) {
                Button { store.removeFolderRules(selection); selection.removeAll() } label: { Image(systemName: "minus") }
                    .disabled(selection.isEmpty)
                    .help(L("選んだ規則を削除")).accessibilityLabel(L("選んだ規則を削除"))
                Spacer()
            }
            HStack {
                Text(L("ファイルごとに選んだ優先：%d件", store.data.preferredFiles.count)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L("選択を消去")) { store.clearPreferredFiles() }
                    .controlSize(.small)
                    .disabled(store.data.preferredFiles.isEmpty)
            }
            Text(L("ウォッチフォルダーの順で優先が決まらない重複に使います。上のフォルダー（下の階層も）のフォントを、下のフォルダーのものより優先します。"))
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
