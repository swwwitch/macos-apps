import AppKit
import SwiftUI

/// 比較の相手として選べるもの（インストール済みのバージョン、または保存済みのスナップショットだけのもの）
struct MenuSource: Identifiable, Hashable {
    let name: String
    var install: AppInstall?
    var id: String { name }

    var title: String {
        guard let install else { return name }
        return "\(install.displayName)（\(install.version)）"
    }
}

enum ResultCategory: String, CaseIterable, Identifiable {
    case added = "追加"
    case removed = "削除"
    case renamed = "名前の変更"
    case moved = "場所の変更"
    case shortcuts = "ショートカット"
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var sources: [MenuSource] = []
    @Published var product = AdobeApp(rawValue: UserDefaults.standard.string(forKey: "product") ?? "") ?? .illustrator {
        didSet {
            UserDefaults.standard.set(product.rawValue, forKey: "product")
            oldName = UserDefaults.standard.string(forKey: Self.key("oldName", product)) ?? ""
            newName = UserDefaults.standard.string(forKey: Self.key("newName", product)) ?? ""
            diff = nil
            errorText = ""
            status = ""
            refresh()
        }
    }
    @Published var oldName = "" {
        didSet { UserDefaults.standard.set(oldName, forKey: Self.key("oldName", product)) }
    }
    @Published var newName = "" {
        didSet { UserDefaults.standard.set(newName, forKey: Self.key("newName", product)) }
    }

    /// 選択はアプリごとに覚える（Illustrator は 1.0.0 からのキーをそのまま使う）
    static func key(_ base: String, _ app: AdobeApp) -> String {
        app == .illustrator ? base : "\(base).\(app.rawValue)"
    }
    @Published var status = ""
    @Published var errorText = ""
    @Published var isWorking = false
    @Published var trusted = AXIsProcessTrusted()
    @Published var diff: MenuDiff?
    @Published var comparedTitle = ""
    @Published var category: ResultCategory = .added
    @Published var query = ""
    /// 表示を更新するための目印（起動・終了・保存のたび）
    @Published var stateStamp = 0

    private var observers: [NSObjectProtocol] = []

    init() {
        oldName = UserDefaults.standard.string(forKey: Self.key("oldName", product)) ?? ""
        newName = UserDefaults.standard.string(forKey: Self.key("newName", product)) ?? ""
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.stateStamp += 1 }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.trusted = AXIsProcessTrusted() }
        })
    }

    func refresh() {
        let installs = AppInstall.discover(product)
        var list = installs.map { MenuSource(name: $0.snapshotName, install: $0) }
        let installedNames = Set(list.map(\.name))
        for name in SnapshotStore.names(for: product) where !installedNames.contains(name) {
            list.append(MenuSource(name: name, install: nil))
        }
        list.sort { $0.name.compare($1.name, options: .numeric) == .orderedDescending }
        sources = list
        // 既定：新＝Beta・Prerelease 以外で最も新しいもの、旧＝その次
        let names = list.map(\.name)
        if !names.contains(newName) {
            newName = list.first { $0.install != nil && $0.install?.channel == "" }?.name ?? names.first ?? ""
        }
        if !names.contains(oldName) {
            let newVersion = source(named: newName)?.install?.version ?? ""
            let releases = list.filter { $0.install?.channel == "" }
            oldName = releases.first { ($0.install?.version ?? "").compare(newVersion, options: .numeric) == .orderedAscending }?.name
                ?? names.first { $0 != newName } ?? ""
        }
        stateStamp += 1
    }

    func source(named name: String) -> MenuSource? { sources.first { $0.name == name } }

    func stateText(for source: MenuSource) -> String {
        _ = stateStamp
        var parts: [String] = []
        if source.install?.runningApplication != nil { parts.append("起動中") }
        if let snapshot = SnapshotStore.load(source.name) {
            parts.append("保存済み \(snapshot.date)")
        } else if source.install?.runningApplication == nil {
            parts.append("未取得（比較時に起動）")
        }
        if source.install == nil { parts.append("アプリなし") }
        return parts.joined(separator: "・")
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 起動中なら読み直す。起動していなければ保存済みを使い、無ければ起動して読む（forceRead で常に読む）
    func snapshot(for source: MenuSource, forceRead: Bool) async throws -> MenuSnapshot {
        if let install = source.install, forceRead || install.runningApplication != nil || SnapshotStore.load(source.name) == nil {
            let snapshot = try await MenuReader.capture(install) { message in
                Task { @MainActor in self.status = message }
            }
            try SnapshotStore.save(snapshot)
            stateStamp += 1
            return snapshot
        }
        if let saved = SnapshotStore.load(source.name) { return saved }
        throw MenuReaderError.launchFailed("\(source.name) のアプリも保存済みのデータもありません。")
    }

    func compare() {
        guard let oldSource = source(named: oldName), let newSource = source(named: newName) else { return }
        run {
            let oldSnapshot = try await self.snapshot(for: oldSource, forceRead: false)
            let newSnapshot = try await self.snapshot(for: newSource, forceRead: false)
            self.diff = MenuDiff(old: oldSnapshot, new: newSnapshot)
            self.comparedTitle = "\(oldSnapshot.name)（\(oldSnapshot.entries.count)項目）→ \(newSnapshot.name)（\(newSnapshot.entries.count)項目）"
            if oldSnapshot.locale != newSnapshot.locale {
                self.errorText = "言語が異なります（\(oldSnapshot.locale) / \(newSnapshot.locale)）。ほとんどの項目が追加・削除として出ます。"
            }
            if let diff = self.diff, self.count(of: self.category, in: diff) == 0,
               let first = ResultCategory.allCases.first(where: { self.count(of: $0, in: diff) > 0 }) {
                self.category = first
            }
            self.status = ""
        }
    }

    func reread(_ name: String) {
        guard let source = source(named: name) else { return }
        run {
            let snapshot = try await self.snapshot(for: source, forceRead: true)
            self.status = "\(snapshot.name) を読み直しました（\(snapshot.entries.count)項目）。"
        }
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        isWorking = true
        errorText = ""
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await work()
            } catch {
                status = ""
                errorText = error.localizedDescription
                trusted = AXIsProcessTrusted()
            }
        }
    }

    func count(of category: ResultCategory, in diff: MenuDiff) -> Int {
        switch category {
        case .added: return diff.added.count
        case .removed: return diff.removed.count
        case .renamed: return diff.renamed.count
        case .moved: return diff.moved.count
        case .shortcuts: return diff.shortcutChanges.count
        }
    }

    /// いま表示している一覧（絞り込み後）を1行1件の文字列で
    func rows(for category: ResultCategory, in diff: MenuDiff) -> [ResultRow] {
        let all: [ResultRow]
        switch category {
        case .added: all = diff.added.map { ResultRow(path: $0) }
        case .removed: all = diff.removed.map { ResultRow(path: $0) }
        case .renamed: all = diff.renamed.map { ResultRow(path: $0.new, oldPath: $0.old) }
        case .moved: all = diff.moved.map { ResultRow(path: $0.new, oldPath: $0.old) }
        case .shortcuts: all = diff.shortcutChanges.map { ResultRow(path: $0.path, oldShortcut: $0.old, newShortcut: $0.new) }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.path.localizedCaseInsensitiveContains(trimmed) || ($0.oldPath ?? "").localizedCaseInsensitiveContains(trimmed) }
    }

    func copyRows(_ rows: [ResultRow]) {
        let text = rows.map(\.plainText).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        status = "\(rows.count)件をコピーしました。"
    }
}

struct ResultRow: Identifiable, Hashable {
    let path: String
    var oldPath: String?
    var oldShortcut: String?
    var newShortcut: String?
    var id: String { (oldPath ?? "") + "\u{1}" + path }

    var plainText: String {
        if let oldPath { return "\(oldPath)\t\(path)" }
        if let oldShortcut, let newShortcut { return "\(path)\t\(oldShortcut)\t\(newShortcut)" }
        return path
    }
}

// MARK: - 画面

struct MainView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if !model.trusted { accessibilityNotice }
            selectionBox
            if !model.errorText.isEmpty {
                Label(model.errorText, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).textSelection(.enabled)
            }
            if let diff = model.diff {
                ResultsView(model: model, diff: diff)
            } else {
                Spacer(minLength: 0)
            }
            bottomBar
        }
        .padding(24)
        .frame(minWidth: 600, idealWidth: 640, minHeight: 640)
        .background(Color(nsColor: AppSurface.color))
        .background(WindowTitleHider())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 4) {
                Image(nsImage: currentAppIcon()).resizable().frame(width: 44, height: 44)
                AppVersionLabel()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("メニューをバージョン間で比較").font(.system(size: 20, weight: .semibold))
                Text("Illustrator・InDesign・Photoshop の2つのバージョンのメニュー項目を読み、追加・削除・名前や場所の変更・ショートカットの変化を一覧にします。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private var accessibilityNotice: some View {
        HStack {
            Label("メニューを読むには、アクセシビリティの許可が必要です（未許可）。", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
            Spacer()
            Button("許可する...") { model.requestAccessibility() }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var selectionBox: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("アプリ")
                HStack(spacing: 12) {
                    ForEach(AdobeApp.allCases) { app in
                        AppTile(app: app, selected: model.product == app) { model.product = app }
                            .disabled(model.isWorking)
                    }
                }
            }
            Divider()
            HStack(alignment: .top, spacing: 14) {
                sourceColumn(label: "新", selection: $model.newName)
                Button {
                    swap(&model.oldName, &model.newName)
                } label: { Image(systemName: "arrow.left.arrow.right") }
                    .help("新と旧を入れ替えます")
                    .disabled(model.isWorking)
                    .padding(.top, 26)
                sourceColumn(label: "旧", selection: $model.oldName)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
    }

    /// 見出し（新・旧）、ポップアップ、その下に状態と［読み直す］
    private func sourceColumn(label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(label)
            Picker("", selection: selection) {
                ForEach(model.sources) { source in
                    Text(source.title).tag(source.name)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(model.isWorking)
            if let source = model.source(named: selection.wrappedValue) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.stateText(for: source)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if source.install != nil {
                        Button("読み直す") { model.reread(source.name) }
                            .controlSize(.small)
                            .disabled(model.isWorking)
                            .help("起動していなければ起動して読み、終わったら終了します")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 下端：左に［保存先を開く］、右に進み具合と［比較］
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("保存先を開く") {
                try? FileManager.default.createDirectory(at: SnapshotStore.folder, withIntermediateDirectories: true)
                NSWorkspace.shared.open(SnapshotStore.folder)
            }
            Spacer()
            if model.isWorking { ProgressView().controlSize(.small) }
            Text(model.status).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            Button { model.compare() } label: {
                Text("比較").frame(minWidth: 100)
            }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isWorking || model.oldName.isEmpty || model.newName.isEmpty || model.oldName == model.newName)
        }
    }
}

extension AdobeApp {
    /// アプリごとの色（文字と下地）
    var letterColor: Color {
        switch self {
        case .illustrator: return Color(red: 1.0, green: 0.60, blue: 0.0)
        case .indesign: return Color(red: 1.0, green: 0.20, blue: 0.40)
        case .photoshop: return Color(red: 0.19, green: 0.66, blue: 1.0)
        }
    }
    var tileColor: Color {
        switch self {
        case .illustrator: return Color(red: 0.20, green: 0.0, blue: 0.0)
        case .indesign: return Color(red: 0.29, green: 0.01, blue: 0.12)
        case .photoshop: return Color(red: 0.0, green: 0.12, blue: 0.21)
        }
    }
}

/// アプリを選ぶ大きなボタン（Ai・Id・Ps の文字をアプリの色で）
struct AppTile: View {
    let app: AdobeApp
    let selected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(app.prefix)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(app.letterColor)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(app.tileColor))
                Text(app.title).font(.system(size: 12, weight: selected ? .semibold : .regular))
            }
            .frame(width: 112, height: 100)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(selected ? Color.accentColor.opacity(0.12) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .focusable(false)  // フォーカスリングが選択中の枠と紛らわしいので出さない
        .help(app.title + " のバージョンを比べます")
    }
}

/// タイトルバーにアプリ名を出さない（［ウインドウ］メニューの一覧には名前が残る）
struct WindowTitleHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            // 保存された大きさが無い初回だけ、幅を狭めに
            if UserDefaults.standard.object(forKey: "NSWindow Frame main") == nil {
                window.setContentSize(NSSize(width: 640, height: 720))
                window.center()
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ResultsView: View {
    @ObservedObject var model: AppModel
    let diff: MenuDiff

    var body: some View {
        let rows = model.rows(for: model.category, in: diff)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.comparedTitle).font(.system(size: 13, weight: .semibold)).textSelection(.enabled)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                TextField("絞り込み", text: $model.query).textFieldStyle(.roundedBorder).frame(width: 150)
                Button("コピー") { model.copyRows(rows) }
                    .disabled(rows.isEmpty)
                    .help("表示中の一覧をタブ区切りでコピーします")
            }
            Picker("", selection: $model.category) {
                ForEach(ResultCategory.allCases) { category in
                    Text("\(category.rawValue) \(model.count(of: category, in: diff))").tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if let note = note(for: model.category) {
                Text(note).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            List(rows) { row in
                ResultRowView(row: row)
                    .contextMenu {
                        Button("パスをコピー") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(row.path, forType: .string)
                        }
                        if let oldPath = row.oldPath {
                            Button("旧のパスをコピー") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(oldPath, forType: .string)
                            }
                        }
                    }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if rows.isEmpty { Text("なし").foregroundStyle(.secondary) }
            }
        }
    }

    private func note(for category: ResultCategory) -> String? {
        switch category {
        case .renamed: return "子の項目が移った先のサブメニューと、同じメニューの中で削除と追加が1つずつあったものを組にしています。"
        case .moved:
            var text = "同じ名前の項目が、削除側・追加側に1つずつあったものを組にしています。"
            if diff.impliedMoves > 0 { text += "親メニューの名前・場所が変わっただけのもの（\(diff.impliedMoves)件）は省いています。" }
            return text
        case .shortcuts: return "読んだときに選ばれていたキーボードショートカットのセットの値です。"
        default: return nil
        }
    }
}

struct ResultRowView: View {
    let row: ResultRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let oldPath = row.oldPath {
                pathText(oldPath).foregroundStyle(.secondary).strikethrough(false)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary).font(.system(size: 10))
                    pathText(row.path)
                }
            } else if let oldShortcut = row.oldShortcut, let newShortcut = row.newShortcut {
                HStack {
                    pathText(row.path)
                    Spacer()
                    Text(oldShortcut.isEmpty ? "—" : oldShortcut).foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.system(size: 10))
                    Text(newShortcut.isEmpty ? "—" : newShortcut).fontWeight(.semibold)
                }
            } else {
                pathText(row.path)
            }
        }
        .textSelection(.enabled)
    }

    /// 親を薄く、末端を通常の色で
    private func pathText(_ path: String) -> Text {
        let parent = MenuDiff.parent(path)
        let leaf = MenuDiff.leaf(path)
        if parent.isEmpty { return Text(leaf) }
        return Text(parent + MenuReader.separator).foregroundColor(.secondary) + Text(leaf)
    }
}

struct HelpView: View {
    var body: some View {
        ScrollView {
            Text(helpText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .frame(minWidth: 520, minHeight: 480)
    }

    private var helpText: String {
        """
        MenuDiff ヘルプ

        ■ できること
        インストールされている Illustrator・InDesign・Photoshop の2つのバージョンのメニュー項目を読み、次の違いを一覧にします。
        ・追加・削除された項目
        ・名前が変わったらしい項目、場所が変わったらしい項目
        ・ショートカットの変化

        ■ 使い方
        1. ［アプリ］で Illustrator・InDesign・Photoshop を切り替え、［新］と［旧］でバージョンを選びます（アプリごとに前回の選択を覚えています）。
        2. ［比較］を押します。
           ・起動中のバージョンは、その場でメニューを読みます。
           ・起動していないバージョンは、保存済みのデータを使います。無ければ起動して読み、読み終えたら終了させます（このアプリが起動したものだけ）。
        3. 上のボタンで種類を切り替え、［絞り込み］で項目を探します。［コピー］で表示中の一覧をタブ区切りでコピーできます。
        保存済みのデータを新しくしたいときは［読み直す］を押します。

        ■ 権限
        メニューはアクセシビリティの機能で読みます。初回は［許可する...］から、システム設定の［プライバシーとセキュリティ］>［アクセシビリティ］でこのアプリをオンにしてください。

        ■ 保存先
        読んだメニューは「Ai31.0.0 ja_JP.tsv」（InDesign は Id、Photoshop は Ps）のような名前で保存します（［保存先を開く］で表示）。

        ■ 注意
        ・Apple メニュー、フォント・最近使用したファイル・スクリプト・各種ライブラリなどの中身は読みません。
        ・アプリメニューの名前は、年を外したアプリ名（Photoshop など）にそろえます。
        ・操作やドキュメントで名前が変わる項目（「〜を取り消し」「〜をやり直し」「〜 の新規ウィンドウ」、ワークスペースの「〜をリセット」）は、決まった名前にそろえます。
        ・表示／非表示などオン・オフで名前が入れ替わる項目は、読んだときの状態の名前になるので、「名前の変更」に出ることがあります。
        ・開いているドキュメントの名前（［ウィンドウ］メニュー）とメールアドレスは保存しません。
        ・ショートカットは、読んだときに選ばれていたキーボードショートカットのセットの値です。
        ・言語が異なるバージョンどうしでは、ほとんどの項目が追加・削除として出ます。
        ・名前の変更・場所の変更は推定です。

        ■ 困ったとき
        ・「メニューがそろいませんでした」：起動に4分以上かかったか、ダイアログボックスで止まっています。そのバージョンを手で起動してから［読み直す］を押してください。
        ・許可したのに読めない：アクセシビリティの一覧でこのアプリを一度オフにしてからオンにし、アプリを再起動してください。

        ■ 終了
        ウインドウを閉じるか、⌘Q で終了します。
        """
    }
}
