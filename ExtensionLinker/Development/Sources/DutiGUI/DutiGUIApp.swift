import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct DutiGUIApp: App {
    init() {
        SingleInstanceLaunch.enforce()
        #if DIRECT_UPDATES && !APP_STORE
        DispatchQueue.main.async { AppUpdates.shared.start() }
        #endif
    }
    @StateObject private var store = AssociationStore()
    #if DIRECT_UPDATES && !APP_STORE
    @ObservedObject private var updates = AppUpdates.shared
    #endif
    var body: some Scene {
        WindowGroup(id: MainWindow.sceneID) {
            ContentView(store: store)
                .background(StartupWindowGate())
                .background(MainWindowMarker())
                .background(UtilityWindowChrome(title: ""))
                .frame(minWidth: 520, minHeight: 580)
                .onAppear {
                    NSApp.setActivationPolicy(.regular); if !StartupWindow.hidden { NSApp.activate(ignoringOtherApps: true) }
                    MenuBarPresence.shared.install(name: "ExtensionLinker", symbol: "link", show: {
                        MainWindow.show()
                    }, settings: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }, help: { LocalHelp.shared.show() })
                }
        }
        .defaultSize(width: 620, height: 740)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .help) {
                Button(L("%@ヘルプ", "ExtensionLinker")) { LocalHelp.shared.show() }.keyboardShortcut("?", modifiers: .command)
                Divider()
                Button(HelpLinks.noteTitle) { HelpLinks.openNote() }
            }
            #if DIRECT_UPDATES && !APP_STORE
            // After 設定… (BASELINE order), not the shared UpdateCommands' after-About slot,
            // so the menu-bar settings entry inserted below About stays next to 設定….
            CommandGroup(after: .appSettings) {
                Divider()
                Button(AppUpdates.shared.text("アップデートを確認…", "Check for Updates…", "检查更新…", "업데이트 확인…")) { AppUpdates.shared.checkForUpdates() }
                    .disabled(!updates.canCheck)
                Toggle(AppUpdates.shared.text("アップデートを自動確認", "Automatically Check for Updates", "自动检查更新", "자동으로 업데이트 확인"), isOn: Binding(
                    get: { updates.automaticChecks }, set: { _ in updates.toggleAutomaticChecks() }))
                    .disabled(!updates.isConfigured)
            }
            #endif
            MainWindowCommands(reload: { store.refresh() })
        }
        Settings { EnvironmentView(store: store).frame(width: 540).background(UtilityWindowChrome(title: L("設定"))) }
    }
}

struct ContentView: View {
    @ObservedObject var store: AssociationStore
    @State private var selected: Association?
    @State private var addSheet = false
    @State private var confirm = false
    @State private var droppedApp: Application?
    @State private var windowDropTargeted = false
    @State private var windowDropError: String?

    private func sortHeader(_ title: String, column: AssociationSortColumn) -> some View {
        Button { store.sort(by: column) } label: {
            HStack(spacing: 4) {
                Text(L(title))
                if store.sortColumn == column {
                    Image(systemName: store.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L(title))
        .accessibilityValue(store.sortColumn == column ? L(store.sortAscending ? "昇順" : "降順") : "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("拡張子へのアプリ関連付け")).font(.system(size: 20, weight: .semibold))
                    Text(L("アプリをドロップして関連付け。")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help(L("現在の設定を再読み込み（⌘R）"))
                Button { addSheet = true } label: { Image(systemName: "plus") }.help(L("拡張子を追加")).accessibilityLabel(L("拡張子を追加"))
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)

            Picker(L("カテゴリ"), selection: $store.selectedCategory) {
                ForEach(AssociationCategory.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L("拡張子・アプリを検索"), text: $store.query).textFieldStyle(.plain)
                    if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary) }
                }.padding(9).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                Toggle(L("変更のみ"), isOn: $store.onlyChanges).toggleStyle(.checkbox)
            }.padding(.horizontal, 20).padding(.bottom, 8)

            HStack {
                sortHeader("拡張子", column: .fileExtension).frame(width: 145, alignment: .leading)
                sortHeader("対応アプリ", column: .application)
                Spacer()
                Text(L("%@ 種類", String(describing: store.visible.count))).fontWeight(.regular)
            }.font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 24).padding(.vertical, 10)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.visible.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 0) {
                            HStack(spacing: 10) {
                                Image(systemName: "doc").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(row.aliases, id: \.self) { ext in
                                        Text("." + ext)
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(row.extensionLabel)
                            }.frame(width: 145, alignment: .leading)
                            Button { selected = row } label: {
                                HStack(spacing: 12) {
                                    if let app = row.proposed ?? row.current, row.unavailable == nil {
                                        Image(nsImage: app.icon).resizable().scaledToFit().frame(width: 28, height: 28)
                                    } else {
                                        Image(systemName: row.unavailable == nil ? "app.dashed" : "exclamationmark.triangle")
                                            .font(.system(size: 22)).foregroundStyle(row.unavailable == nil ? Color.secondary : .orange).frame(width: 30, height: 30)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(row.displayName).fontWeight(.medium).foregroundStyle(.primary).lineLimit(1)
                                        if let error = row.error {
                                            Text(error).font(.caption).foregroundStyle(.red).lineLimit(2)
                                        } else if row.unavailable != nil {
                                            Text(L("未インストール · 別のアプリを選択")).font(.caption).foregroundStyle(.orange)
                                        } else if row.changed {
                                            Text(L("現在: %@", String(describing: row.current?.name ?? "未設定"))).font(.caption).foregroundStyle(.secondary)
                                        } else if row.aliasesDiffer {
                                            Text(L("別名の設定が異なります · アプリを選ぶと統一できます")).font(.caption).foregroundStyle(.orange).lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    if row.changed { Text(L("変更予定")).font(.system(size: 10, weight: .medium)).foregroundStyle(.blue).padding(.horizontal, 8).padding(.vertical, 4).background(.blue.opacity(0.09), in: Capsule()) }
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).help(L("⌘／Control＋クリック、またはダブルクリックで .%@ のアプリを選択", String(describing: row.ext)))
                            .accessibilityLabel(L(".%@ の対応アプリ: %@", String(describing: row.ext), String(describing: row.displayName)))
                        }.padding(.horizontal, 24).frame(minHeight: row.aliases.count > 1 ? 58 : 46)
                            .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.06) : .clear)
                            .modifier(ApplicationDropZone(clicked: { selected = row }, dragSource: row.unavailable == nil ? row.proposed ?? row.current : nil, requiredClickCount: 2) { app in store.choose(app, for: row.ext) })
                        Divider().padding(.leading, 24)
                    }
                    if store.visible.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").font(.largeTitle)
                            Text(L("該当する拡張子がありません"))
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(60)
                    }
                }
            }.background(Color(nsColor: .textBackgroundColor))
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(store.pending > 0 ? Color.blue : Color.green).frame(width: 6, height: 6)
                    Text(store.applying ? L("設定を適用中…") : store.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()

                }
                HStack {
                    Menu(L("プリセット")) {
                        Button(L("読み込む…")) { store.openPreset() }
                        Button(L("現在の組み合わせを保存…")) { store.savePreset() }
                        Divider()
                        Button(L("初期プリセットを読み込む")) { store.loadPreset() }
                    }
                    Button(L("取り消す")) { store.refresh(discard: true) }.disabled(store.pending == 0 && store.missing == 0)
                    Spacer()
                    if store.missing > 0 { Text(L("%@件のアプリが未検出", String(describing: store.missing))).font(.caption).foregroundStyle(.orange) }
                    Button(L("%@件の変更を適用", String(describing: store.pending))) { confirm = true }
                        .buttonStyle(.borderedProminent).disabled(store.pending == 0)
                        .help(L("すべてのカテゴリの変更予定をまとめて適用します"))
                }
            }.padding(.horizontal, 20).padding(.vertical, 18)
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        .disabled(store.applying)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(windowDropTargeted ? Color.accentColor : .clear, lineWidth: 4)
                .background(windowDropTargeted ? Color.accentColor.opacity(0.07) : .clear)
                .allowsHitTesting(false)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $windowDropTargeted) { providers in
            guard !store.applying, providers.count == 1, let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                let url: URL?
                if let value = item as? URL { url = value }
                else if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let string = item as? String { url = URL(string: string) }
                else { url = nil }
                Task { @MainActor in
                    guard error == nil, let url, let app = Application.dropped(at: url) else {
                        windowDropError = L("Finderの「アプリケーション」から.appを1つドロップしてください。")
                        return
                    }
                    selected = nil
                    addSheet = false
                    droppedApp = app
                }
            }
            return true
        }
        .sheet(item: $selected) { row in ApplicationPicker(row: row) { app in store.choose(app, for: row.ext) } }
        .sheet(isPresented: $addSheet) { AddExtensionView(store: store) }
        .sheet(item: $droppedApp) { app in DroppedApplicationView(app: app, store: store) }
        .alert(L("プリセットを処理できません"), isPresented: Binding(get: { store.presetError != nil }, set: { if !$0 { store.presetError = nil } })) {
            Button("OK", role: .cancel) { store.presetError = nil }
        } message: { Text(store.presetError ?? "") }
        .alert(L("アプリを追加できません"), isPresented: Binding(get: { windowDropError != nil }, set: { if !$0 { windowDropError = nil } })) {
            Button("OK", role: .cancel) { windowDropError = nil }
        } message: { Text(windowDropError ?? "") }
        .alert(L("%@件の既定アプリを変更しますか？", String(describing: store.pending)), isPresented: $confirm) {
            Button(L("キャンセル"), role: .cancel) { }
            Button(L("変更を適用")) { store.apply() }
        } message: {
            Text(L("対象（すべてのカテゴリ）: %@\n\nmacOSのファイルタイプ単位で、全ロールに適用します。同じタイプの別の拡張子（例: .jpg と .jpeg）にも反映されます。未インストールの行はスキップします。", String(describing: store.affectedExtensions)))
        }
    }
}

struct DroppedApplicationView: View {
    let app: Application
    @ObservedObject var store: AssociationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []
    @State private var newExtension = ""
    @State private var addError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: app.icon).resizable().scaledToFit().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name).font(.title2.bold())
                    Text(L("関連付ける拡張子を選択")).foregroundStyle(.secondary)
                }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.rows) { row in
                        Toggle(isOn: Binding(get: { selection.contains(row.ext) }, set: { value in
                            if value { selection.insert(row.ext) } else { selection.remove(row.ext) }
                        })) {
                            HStack {
                                Text(row.extensionLabel).font(.system(.body, design: .monospaced)).frame(width: 140, alignment: .leading)
                                Text(row.current?.name ?? L("未設定")).font(.caption).foregroundStyle(.secondary)
                            }
                        }.toggleStyle(.checkbox)
                    }
                }.padding(8)
            }.frame(height: 280)
            HStack {
                TextField(L("新しい拡張子（例: ai）"), text: $newExtension).textFieldStyle(.roundedBorder)
                Button(L("追加")) {
                    let oldQuery = store.query
                    if let ext = AssociationService.normalized(newExtension), store.add(ext) {
                        selection.insert(ext)
                        store.query = oldQuery
                        newExtension = ""
                        addError = false
                    } else { addError = true }
                }.disabled(newExtension.isEmpty)
            }
            if addError { Text(L("有効な未登録の拡張子を入力してください。")).font(.caption).foregroundStyle(.red) }
            HStack {
                Button(L("キャンセル")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L("%@種類に指定", String(describing: selection.count))) {
                    for ext in selection { store.choose(app, for: ext) }
                    store.query = ""
                    store.selectedCategory = .all
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(selection.isEmpty)
            }
            Text(L("設定の反映はメイン画面の「変更を適用」で行います。")).font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 440)
    }
}

struct ApplicationPicker: View {
    let row: Association
    let choose: (Application) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [Application] = []
    @State private var query = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L(".%@ を開くアプリ", String(describing: row.ext))).font(.title2.bold())
            Text(row.type?.identifier ?? L("不明なファイルタイプ")).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Label(L("ここにアプリをドラッグ＆ドロップ"), systemImage: "square.and.arrow.down")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .modifier(ApplicationDropZone(clicked: { browse() }) { app in choose(app); dismiss() })
            TextField(L("アプリを検索"), text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(candidates.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { app in
                        Button {
                            choose(app); dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(nsImage: app.icon).resizable().scaledToFit().frame(width: 32, height: 32)
                                VStack(alignment: .leading) {
                                    Text(app.name).foregroundStyle(.primary)
                                    Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if app.bundleID == row.current?.bundleID { Text(L("現在")).font(.caption).foregroundStyle(.secondary) }
                                if app.bundleID == row.proposed?.bundleID { Image(systemName: "checkmark").foregroundStyle(.blue) }
                            }.padding(10).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    if candidates.isEmpty { Text(L("対応アプリが見つかりません。「その他のアプリ」から選択してください。")).foregroundStyle(.secondary).padding() }
                }
            }.frame(height: 280)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button(L("その他のアプリ…")) { browse() }
                Spacer()
                Button(L("キャンセル")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width: 460)
        .onAppear {
            var apps = row.type.map { NSWorkspace.shared.urlsForApplications(toOpen: $0).compactMap(Application.init) } ?? []
            for app in [row.current, row.proposed].compactMap({ $0 }) where !apps.contains(where: { $0.bundleID == app.bundleID }) { apps.append(app) }
            var seen = Set<String>()
            candidates = apps.filter { seen.insert($0.bundleID).inserted }
        }
    }
    private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = L("選択")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let app = Application(url: url) else { error = L("有効なアプリを選択してください。"); return }
        choose(app); dismiss()
    }
}


struct AddExtensionView: View {
    @ObservedObject var store: AssociationStore
    @Environment(\.dismiss) private var dismiss
    @State private var ext = ""
    @State private var error = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("拡張子を追加")).font(.title2.bold())
            TextField(L("例: jpeg、json、ai"), text: $ext).textFieldStyle(.roundedBorder)
            if error { Text(L("有効な拡張子を入力してください。既存の拡張子は追加できません。")).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(L("キャンセル")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("追加")) { if store.add(ext) { dismiss() } else { error = true } }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 400)
    }
}

// One routine shows the main window from the File menu (⌘0) and the menu bar item.
// A closed WindowGroup window is gone, so the scene is reopened through openWindow.
@MainActor
enum MainWindow {
    static let sceneID = "main"
    fileprivate static weak var window: NSWindow?
    fileprivate static var opener: OpenWindowAction?
    static func show(_ open: OpenWindowAction? = nil) {
        if let open { opener = open }
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if let opener {
            opener(id: sceneID)
        }
    }
}

// File menu per BASELINE「メニューの共通構成」: replacing .newItem drops SwiftUI's
// 「新規ウインドウ」⌘N; replacing .saveItem (which holds SwiftUI's 「閉じる」) renames ⌘W.
private struct MainWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let reload: () -> Void
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L("メインウインドウを開く")) { MainWindow.show(openWindow) }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
            Button(L("設定を再読み込み")) { reload() }.keyboardShortcut("r")
        }
        CommandGroup(replacing: .saveItem) {
            Button(L("ウインドウを閉じる")) {
                NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }
}

// Remembers the live main window; cleared when it closes so ⌘0 reopens the scene.
private struct MainWindowMarker: NSViewRepresentable {
    @Environment(\.openWindow) private var openWindow
    func makeNSView(context: Context) -> MarkerView { MarkerView() }
    func updateNSView(_ view: MarkerView, context: Context) { MainWindow.opener = openWindow }
    final class MarkerView: NSView {
        private var observer: NSObjectProtocol?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            MainWindow.window = window
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak window] _ in
                Task { @MainActor in if MainWindow.window === window { MainWindow.window = nil } }
            }
        }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}

// Configure the actual SwiftUI window once it joins the view hierarchy.
private struct UtilityWindowChrome: NSViewRepresentable {
    let title: String
    func makeNSView(context: Context) -> ChromeView { ChromeView(title: title) }
    func updateNSView(_ view: ChromeView, context: Context) { view.windowTitle = title; view.apply() }
    final class ChromeView: NSView {
        var windowTitle: String
        init(title: String) { windowTitle = title; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            guard let window else { return }
            window.title = windowTitle
            // Keep .miniaturizable so ⌘M and the yellow button work (BASELINE「メニューの共通構成」);
            // only zoom and full screen stay disabled.
            window.styleMask.insert(.miniaturizable)
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.collectionBehavior.insert(.fullScreenNone)
        }
    }
}

// Bundle identity, rather than the bundle path or build number, defines one app.
@MainActor
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) {
            candidates.append(current)
        }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast
            let right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first,
              existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                exit(0)
            }
            // Allow the reopen Apple event to reach hidden/menu-bar applications.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}


// Main-window header uses the same icon resource as the distributed app.
private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
