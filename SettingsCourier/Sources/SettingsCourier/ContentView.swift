import AppKit
import SwiftUI

/// 一覧の1行（アプリの設定のキー1つ）
struct KeyRow: Identifiable {
    let key: String
    let value: NSObject
    let label: SettingLabel?
    var id: String { key }
}

struct ContentView: View {
    @ObservedObject private var customLabels = CustomSettingLabels.shared
    @AppStorage("showSettingLabels") private var showSettingLabels = false
    @State private var editingLabel: SettingLabelTarget?
    @ObservedObject private var courier = Courier.shared
    @ObservedObject private var sync = SettingsSync.shared
    @AppStorage(Courier.selectedAppKey) private var selectedApp = ""
    @State private var rows: [KeyRow] = []
    @State private var selectedKeys = Set<String>()
    @State private var search = ""
    /// 読んだのに中身が取れなかった（アクセスの確認で拒否された）
    @State private var unreadable = false
    @State private var inspectedRow: KeyRow?
    @State private var showsFolderImport = false
    /// 一覧で選んでいるアプリ（⌘クリック・⇧クリックで複数）
    @State private var selection = Set<String>()
    @State private var isTargeted = false

    private var current: CourierApp? { courier.apps.first { $0.bundleID == selectedApp } }
    /// 2つ以上選んでいるときのアプリ
    private var multiple: [CourierApp] {
        let list = courier.apps.filter { selection.contains($0.bundleID) }
        return list.count > 1 ? list : []
    }

    private func select(_ ids: Set<String>) {
        selection = ids
        courier.selectedIDs = ids
        if ids.count == 1, let id = ids.first { selectedApp = id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 12) {
                sidebar
                detail
            }
            .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        .task(id: "\(selectedApp)\u{1}\(courier.revision)") { reloadRows() }
        .onChange(of: customLabels.revision) { reloadRows() }
        .sheet(item: $editingLabel) { target in SettingLabelEditor(target: target) }
        .onAppear {
            if current == nil { selectedApp = courier.apps.first?.bundleID ?? "" }
            courier.scanFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            courier.refresh()
            courier.scanFolder()
        }
        // 同期フォルダーを選び直したら、受け渡しフォルダーも変わる
        .onChange(of: sync.pathText) { courier.scanFolder() }
        .sheet(item: $inspectedRow) { row in
            VStack(alignment: .leading, spacing: 12) {
                Text(row.key).font(.headline).textSelection(.enabled)
                Text(row.label?.title ?? L("対応不明")).textSelection(.enabled)
                Text(row.label?.evidence ?? L("画面上の文言との対応情報がありません")).font(.caption).foregroundStyle(.secondary)
                Text(L("取得値（型を保持したplist表示）")).font(.subheadline)
                ScrollView([.horizontal, .vertical]) {
                    Text(SettingLabels.fullValue(row.value)).font(.system(.body, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack { Spacer(); Button(L("閉じる")) { inspectedRow = nil }.keyboardShortcut(.cancelAction) }
            }.padding(20).frame(width: 680, height: 440)
        }
        .sheet(isPresented: $showsFolderImport) { FolderImportView() }
        .sheet(item: $courier.pendingImport) { ImportView(box: $0) }
        .alert(courier.message?.title ?? "", isPresented: Binding(
            get: { courier.message != nil }, set: { if !$0 { courier.message = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(courier.message?.body ?? "")
        }
    }

    private func reloadRows() {
        guard let app = current, courier.canRead(app.bundleID) else { rows = []; unreadable = false; return }
        let values = readSettings(app.bundleID)
        unreadable = isUnreadable(app.bundleID, values)
        let bundle = appURL(app.bundleID).flatMap { Bundle(url: $0) }
        rows = values.map { KeyRow(key: $0.key, value: $0.value,
            label: customLabels.title(bundleID: app.bundleID, key: $0.key).map { SettingLabel(title: $0, evidence: L("ユーザー入力")) }
                ?? SettingLabels.resolve(key: $0.key, bundleID: app.bundleID, bundle: bundle)) }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        selectedKeys.formIntersection(rows.map(\.key))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                AppVersionLabel()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("アプリの設定をほかのMacへ運ぶ"))
                    .font(.title2.weight(.semibold))
                Text(L("登録したアプリの設定を書き出し、ほかのMacで取り込みます"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { SettingsWindow.shared.show() } label: {
                Label(L("設定"), systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: アプリの一覧

    private var sidebar: some View {
        VStack(spacing: 0) {
            ZStack {
                List(selection: Binding(get: { selection.isEmpty ? Set([selectedApp]) : selection }, set: { select($0) })) {
                    ForEach(courier.apps) { app in appRow(app).tag(app.bundleID) }
                }
                .scrollContentBackground(.hidden)
                if courier.apps.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: isTargeted ? "arrow.down.app.fill" : "arrow.down.app")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(L("アプリをここにドロップ")).font(.headline)
                        Button(L("アプリを追加…")) { addApps() }
                    }
                    .padding(12)
                }
            }
            Divider()
            HStack(spacing: 4) {
                Button { addApps() } label: { Image(systemName: "plus").frame(width: 20, height: 16) }
                    .help(L("設定を運ぶアプリを追加"))
                    .accessibilityLabel(L("アプリを追加…"))
                Button { (multiple.isEmpty ? current.map { [$0] } ?? [] : multiple).forEach(remove) } label: { Image(systemName: "minus").frame(width: 20, height: 16) }
                    .disabled(current == nil && multiple.isEmpty)
                    .help(L("選んだアプリを一覧から外す（アプリの設定はそのまま）"))
                    .accessibilityLabel(L("一覧から外す"))
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : .clear, lineWidth: 3)
        }
        .frame(width: 240)
        .dropDestination(for: URL.self) { urls, _ in
            let packages = urls.filter { $0.pathExtension == "settingscourier" }
            if !packages.isEmpty { openPackages(packages); return true }
            if let id = courier.add(urls) { selectedApp = id }
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeOut(duration: 0.16), value: isTargeted)
    }

    private func appRow(_ app: CourierApp) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: appIcon(app.bundleID)).resizable().frame(width: 20, height: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(app.name).lineLimit(1)
                if courier.hasNewer(app.bundleID) {
                    Label(L("新しい設定があります"), systemImage: "arrow.down.circle.fill")
                        .font(.caption).foregroundStyle(Color.accentColor)
                } else if appURL(app.bundleID) == nil {
                    Text(L("このMacにはありません")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .help(app.bundleID)
        .contextMenu {
            Button(courier.folder == nil ? L("書き出す…") : L("フォルダーに書き出す")) { courier.export(app) }
            Button(L("設定ファイルをFinderで表示")) { revealFile(app.bundleID) }
            Divider()
            Button(L("一覧から外す")) { remove(app) }
        }
    }

    private func addApps() {
        if let id = courier.chooseApps() { selectedApp = id }
    }

    private func remove(_ app: CourierApp) {
        courier.remove(app.bundleID)
        if selectedApp == app.bundleID { selectedApp = courier.apps.first?.bundleID ?? "" }
    }

    private func revealFile(_ bundleID: String) {
        let file = preferencesFile(bundleID)
        if FileManager.default.fileExists(atPath: file.path) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            courier.message = (L("設定ファイルがありません"), L("「%@」はまだ作られていません。アプリを一度起動して設定を変えると作られます。", file.path))
        }
    }

    // MARK: キーの一覧

    private var visibleRows: [KeyRow] {
        search.isEmpty ? rows : rows.filter { $0.key.localizedCaseInsensitiveContains(search) || describe($0.value).localizedCaseInsensitiveContains(search) || ($0.label?.title.localizedCaseInsensitiveContains(search) ?? false) }
    }

    @ViewBuilder private var detail: some View {
        if !multiple.isEmpty {
            multipleSummary
        } else if let app = current {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(nsImage: appIcon(app.bundleID)).resizable().frame(width: 32, height: 32).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name).font(.headline)
                        Text(preferencesFile(app.bundleID).path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    }
                    Spacer()
                    Button { revealFile(app.bundleID) } label: { Label(L("Finderで表示"), systemImage: "folder") }
                        .help(L("設定ファイルをFinderで表示"))
                    Button { courier.refresh() } label: { Label(L("読み直す"), systemImage: "arrow.clockwise") }
                        .help(L("設定を読み直す"))
                }
                HStack(spacing: 8) {
                    SearchField(placeholder: L("項目・キー・値で検索"), text: $search).frame(maxWidth: 260)
                    Spacer()
                    Text(L("書き出す項目 %@／%@", String(rows.filter { courier.isIncluded(app.bundleID, $0.key, $0.value) }.count), String(rows.count)))
                        .font(.callout).foregroundStyle(.secondary)
                    Button(L("初めの選択に戻す")) { courier.resetSelection(app.bundleID) }
                        .help(L("ウインドウの位置などMacごとに異なるキーと日付だけを外した状態に戻す"))
                }
                HStack {
                    Toggle(L("画面上の項目／意味を表示"), isOn: $showSettingLabels).toggleStyle(.checkbox)
                    Spacer()
                    Button(L("項目名を編集・スクショで照合…")) {
                        if let row = rows.first(where: { selectedKeys.contains($0.key) }) {
                            editingLabel = SettingLabelTarget(bundleID: app.bundleID, appName: app.name, row: row)
                        }
                    }.disabled(selectedKeys.count != 1)
                }
                if courier.canRead(app.bundleID) {
                    table(app)
                    HStack {
                        Text(L("保存済みの値を表示しています。未保存の初期値や、別ファイルの設定は含みません。"))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("取得値の詳細…")) {
                            inspectedRow = rows.first { selectedKeys.contains($0.key) }
                        }.disabled(selectedKeys.count != 1)
                    }
                } else { readPrompt }
                ExtraFilesView(app: app)
            }
        } else {
            VStack(spacing: 8) {
                Text(L("左の一覧でアプリを選んでください")).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @TableColumnBuilder<KeyRow, Never>
    private func valueColumns(_ app: CourierApp) -> some TableColumnContent<KeyRow, Never> {
            TableColumn(L("書き出す")) { row in
                Toggle("", isOn: Binding(
                    get: { courier.isIncluded(app.bundleID, row.key, row.value) },
                    set: { include in
                        // 選んだ行のチェックボックスなら、選んだ行をまとめて切り替える
                        let targets = selectedKeys.contains(row.key) ? rows.filter { selectedKeys.contains($0.key) } : [row]
                        courier.setIncluded(app.bundleID, targets.map { ($0.key, $0.value) }, include)
                    }))
                    .toggleStyle(.checkbox).labelsHidden()
                    .accessibilityLabel(L("%@を書き出す", row.key))
            }
            .width(60)
            TableColumn(L("キー")) { row in
                Text(row.key)
                    .foregroundStyle(courier.isIncluded(app.bundleID, row.key, row.value) ? .primary : .secondary)
                    .help(isExcludedByDefault(row.key, row.value) ? L("Macごとに異なる値のため、初めは書き出しません") : row.key)
            }
            .width(min: 120, ideal: 180)
            TableColumn(L("種類")) { row in Text(typeName(row.value)).foregroundStyle(.secondary) }
                .width(min: 50, ideal: 60)
            TableColumn(L("値")) { row in
                Text(describe(row.value)).lineLimit(1).truncationMode(.tail).textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 180)
    }

    @TableColumnBuilder<KeyRow, Never>
    private func labelColumn(_ app: CourierApp) -> some TableColumnContent<KeyRow, Never> {
        TableColumn(L("画面上の項目／意味")) { row in
            InlineSettingLabel(bundleID: app.bundleID, row: row)
                .id(app.bundleID + "\u{1}" + row.key)
        }
        .width(min: 150, ideal: 240)
    }

    private func table(_ app: CourierApp) -> some View {
        Group {
            if showSettingLabels {
                Table(visibleRows, selection: $selectedKeys) {
                    valueColumns(app)
                    labelColumn(app)
                }
            } else {
                Table(visibleRows, selection: $selectedKeys) { valueColumns(app) }
            }
        }
        .contextMenu(forSelectionType: String.self) { keys in
            let targets = rows.filter { keys.contains($0.key) }.map { ($0.key, $0.value) }
            Button(L("項目名を編集・スクショで照合…")) {
                if let row = rows.first(where: { keys.contains($0.key) }) {
                    editingLabel = SettingLabelTarget(bundleID: app.bundleID, appName: app.name, row: row)
                }
            }.disabled(keys.count != 1)
            Button(L("取得値の詳細…")) { inspectedRow = rows.first { keys.contains($0.key) } }
                .disabled(keys.count != 1)
            Divider()
            Button(L("書き出す")) { courier.setIncluded(app.bundleID, targets, true) }
            Button(L("書き出さない")) { courier.setIncluded(app.bundleID, targets, false) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if unreadable {
                Text(L("設定を読めませんでした。macOSの「ほかのアプリからのデータ」へのアクセスの確認で［許可］を選んでから「読み直す」を押してください。"))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(24)
            } else if rows.isEmpty {
                Text(appURL(app.bundleID) == nil ? L("このMacにはこのアプリがありません") : L("設定はまだありません"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 2つ以上選んでいるとき：まとめて書き出す
    private var multipleSummary: some View {
        VStack(spacing: 12) {
            HStack(spacing: -6) {
                ForEach(multiple.prefix(8)) { app in
                    Image(nsImage: appIcon(app.bundleID)).resizable().frame(width: 40, height: 40)
                }
            }
            .accessibilityHidden(true)
            Text(L("%@個のアプリを選んでいます", String(multiple.count))).font(.headline)
            Text(multiple.map(\.name).joined(separator: L("、")))
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(courier.folder == nil ? L("まとめて書き出す…") : L("まとめてフォルダーに書き出す")) { courier.exportMany(multiple) }
            Text(L("アプリごとに「<アプリ名>.settingscourier」を書き出します。キーの選択と一緒に運ぶファイルは、アプリを1つ選ぶと確かめられます。"))
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// サンドボックスのアプリ：読むと macOS の確認が出るので、押すまで読まない
    private var readPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.doc").font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L("このアプリの設定はサンドボックスのコンテナにあります。読むと、macOSが「ほかのアプリからのデータ」へのアクセスを確認します（Macを再起動するたびに出ます）。"))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button(L("設定を読む")) { courier.allowContainerReads() }
            Text(L("設定の「起動・常駐」でフルディスクアクセスを許可すると、確認なしで読みます。"))
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let folder = courier.folder {
                Label(folder.deletingLastPathComponent().lastPathComponent, systemImage: "folder")
                    .foregroundStyle(.secondary).lineLimit(1)
                    .help(folder.path)
                Button(courier.newerEntries.isEmpty ? L("フォルダーから取り込む…")
                       : L("フォルダーから取り込む…（新しい設定 %@件）", String(courier.newerEntries.count))) {
                    showsFolderImport = true
                }
                .help(L("同期フォルダーにある設定を選んで、このMacのアプリに書き込む"))
            } else if courier.folderMissing {
                Label(L("同期フォルダーが見つかりません"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                Button(L("同期フォルダーを選ぶ…")) { courier.chooseFolder() }
            } else {
                Button(L("同期フォルダーを選ぶ…")) { courier.chooseFolder() }
                    .help(L("Dropbox などほかのMacと同期しているフォルダーを選ぶと、そこで設定を受け渡せます（設定の「設定の共有」と同じフォルダー）"))
            }
            Spacer()
            Button(L("取り込む…")) { openPackage() }
                .help(L("書き出したファイルを開き、このMacのアプリに書き込む"))
            Button(courier.folder == nil ? L("書き出す…") : L("フォルダーに書き出す")) { courier.exportSelected() }
                .keyboardShortcut(.defaultAction)
                .disabled(current == nil && multiple.isEmpty)
                .help(courier.folder == nil ? L("選んでいるアプリの設定をファイルに保存") : L("選んでいるアプリの設定を同期フォルダーに保存"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 一緒に運ぶファイル

/// 設定（defaults）の外にあるアプリのデータ。一覧・追加・外す、Default Folder X などの候補
struct ExtraFilesView: View {
    let app: CourierApp
    @ObservedObject private var courier = Courier.shared

    var body: some View {
        let paths = courier.extraFiles(app.bundleID)
        let suggestions = courier.missingSuggestions(app.bundleID)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("一緒に運ぶファイル")).font(.headline)
                Spacer()
                Button { courier.chooseExtraFiles(app) } label: { Label(L("ファイルを追加…"), systemImage: "plus") }
                    .help(L("設定ファイルの外にあるアプリのデータ（お気に入りの一覧など）を、設定と一緒に書き出す"))
            }
            ForEach(paths, id: \.self) { path in
                HStack(spacing: 8) {
                    Image(systemName: "doc").foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    Text(fileInfo(path)).font(.caption).foregroundStyle(.secondary).fixedSize()
                    Spacer()
                    Button { courier.removeExtraFile(app.bundleID, path) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .help(L("一覧から外す（ファイルはそのまま）"))
                        .accessibilityLabel(L("%@を一覧から外す", path))
                }
            }
            ForEach(suggestions, id: \.self) { path in
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb").foregroundStyle(Color.accentColor).accessibilityHidden(true)
                    Text(L("候補：%@", path)).font(.caption).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button(L("追加")) { courier.addExtraFiles(app.bundleID, [path]) }
                }
            }
            if paths.isEmpty && suggestions.isEmpty {
                Text(L("設定ファイルの外にデータを置くアプリは、そのファイルを追加すると一緒に運べます。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        // 書き出し後・読み直しで日時を更新する
        .id(courier.revision)
    }

    private func fileInfo(_ path: String) -> String {
        guard let url = expandHomePath(path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return L("見つかりません") }
        let size = ByteCountFormatter.string(fromByteCount: Int64(attributes[.size] as? Int ?? 0), countStyle: .file)
        let date = (attributes[.modificationDate] as? Date)?.formatted(date: .abbreviated, time: .shortened) ?? ""
        return (attributes[.size] as? Int ?? 0) > extraFileLimit ? L("%@（大きすぎるため運びません）", size) : "\(size)　\(date)"
    }
}

// MARK: - 受け渡しフォルダーから取り込む

struct FolderImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var courier = Courier.shared
    @State private var chosen = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("フォルダーから取り込む")).font(.headline)
            Text(courier.folder?.path ?? "").font(.caption.monospaced()).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            List {
                ForEach(courier.folderEntries) { entry in
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(get: { chosen.contains(entry.id) },
                                                 set: { if $0 { chosen.insert(entry.id) } else { chosen.remove(entry.id) } }))
                            .toggleStyle(.checkbox).labelsHidden()
                            .disabled(entry.state == .notInstalled)
                            .accessibilityLabel(L("%@を取り込む", entry.app.name))
                        Image(nsImage: appIcon(entry.app.bundleID)).resizable().frame(width: 20, height: 20).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.app.name)
                            Text(detail(entry)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.state == .newer {
                            Text(L("新しい設定")).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .frame(minHeight: 200)
            .overlay {
                if courier.folderEntries.isEmpty {
                    Text(L("同期フォルダーに書き出したファイルがありません")).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button { courier.showFolder() } label: { Label(L("Finderで表示"), systemImage: "folder") }
                let available = courier.folderEntries.filter { $0.state != .notInstalled }.map(\.id)
                Button(chosen.isSuperset(of: available) && !available.isEmpty ? L("選択を解除") : L("すべて選択")) {
                    chosen = chosen.isSuperset(of: available) ? [] : Set(available)
                }
                .disabled(available.isEmpty)
                Spacer()
                Button(L("キャンセル")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("次へ…")) {
                    let entries = courier.folderEntries.filter { chosen.contains($0.id) }
                    dismiss()
                    DispatchQueue.main.async { courier.importFromFolder(entries) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            courier.scanFolder()
            chosen = Set(courier.newerEntries.map(\.id))
        }
    }

    private func detail(_ entry: FolderEntry) -> String {
        var parts: [String] = []
        if !entry.host.isEmpty { parts.append(entry.host) }
        if let date = entry.created { parts.append(date.formatted(date: .abbreviated, time: .shortened)) }
        switch entry.state {
        case .newer: break
        case .older: parts.append(L("このMacの設定の方が新しい"))
        case .notInstalled: parts.append(L("このMacにはありません"))
        }
        return parts.joined(separator: "　")
    }
}

// MARK: - 取り込みの確認

struct ImportView: View {
    let box: PackageBox
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var courier = Courier.shared
    @State private var plans: [ImportPlan] = []
    @State private var chosen = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(box.package.replace ? L("バックアップから元に戻す") : L("設定を取り込む")).font(.headline)
            Text(source).font(.callout).foregroundStyle(.secondary)
            List {
                ForEach(plans) { plan in
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(get: { chosen.contains(plan.id) },
                                                 set: { if $0 { chosen.insert(plan.id) } else { chosen.remove(plan.id) } }))
                            .toggleStyle(.checkbox).labelsHidden()
                            .disabled(!plan.hasWrites || plan.unreadable)
                            .accessibilityLabel(L("%@を取り込む", plan.app.name))
                        Image(nsImage: appIcon(plan.app.bundleID)).resizable().frame(width: 20, height: 20).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(plan.app.name)
                            Text(status(plan)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(minHeight: 160)
            Text(L("書き込む前に、対象のアプリの今の設定をバックアップします。起動中のアプリは終了してから書き込み、あとで起動し直します。"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("キャンセル")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("取り込む")) {
                    let selected = plans.filter { chosen.contains($0.id) }
                    dismiss()
                    DispatchQueue.main.async { courier.apply(selected) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty || courier.isWorking)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            plans = courier.plan(box.package)
            // 「このMacと同じ」と分かったアプリの「新しい設定」の印を消す
            courier.scanFolder()
            chosen = Set(plans.filter { $0.hasWrites && $0.installed && !$0.unreadable }.map(\.id))
        }
    }

    private var source: String {
        var text = box.name
        if !box.package.host.isEmpty { text += "　" + L("書き出したMac：%@", box.package.host) }
        if let date = box.package.created { text += "　" + date.formatted(date: .abbreviated, time: .shortened) }
        return text
    }

    private func status(_ plan: ImportPlan) -> String {
        if plan.unreadable { return L("このMacの今の設定を読めないため取り込めません（アクセスを許可してから開き直してください）") }
        if !plan.hasWrites { return L("このMacと同じです") }
        var parts: [String] = []
        if plan.changed > 0 { parts.append(L("変更 %@", String(plan.changed))) }
        if plan.added > 0 { parts.append(L("追加 %@", String(plan.added))) }
        if plan.removed > 0 { parts.append(L("削除 %@", String(plan.removed))) }
        if !plan.fileWrites.isEmpty { parts.append(L("ファイル %@", String(plan.fileWrites.count))) }
        let text = parts.joined(separator: L("、"))
        return plan.installed ? text : text + L("（このMacにはありません）")
    }
}

/// 標準の検索フィールド。入力があると×ボタンが出て、押すかEscで検索語を消せる
struct SearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.setAccessibilityLabel(placeholder)
        return field
    }
    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField { text.wrappedValue = field.stringValue }
        }
        // ×ボタンで消したときは controlTextDidChange が来ないことがあるので、ここでも拾う
        func searchFieldDidEndSearching(_ sender: NSSearchField) { text.wrappedValue = "" }
    }
}

// Main-window header uses the same icon resource as the distributed app.
@MainActor private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
/// Shown under the header icon: version, then build in parentheses (「1.4.5」「（15）」).
private func appVersionText() -> String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info["CFBundleVersion"] as? String, !build.isEmpty, build != version else { return version }
    let japanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    return version + "\n" + (japanese ? "（\(build)）" : "(\(build))")
}
/// Placed under the header icon.
private struct AppVersionLabel: View {
    var body: some View {
        Text(appVersionText()).font(.system(size: 10)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).fixedSize()
    }
}
