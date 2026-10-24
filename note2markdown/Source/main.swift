import AppKit
import SwiftUI
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// A converter with the localized link and image texts.
func makeConverter() -> NoteMarkdown {
    var converter = NoteMarkdown()
    converter.noteLinkText = L("noteLinkText")
    converter.tweetLinkText = L("tweetLinkText")
    converter.imageText = L("imageText")
    converter.keywordsHeading = L("keywordsHeading")
    return converter
}

/// Loads a note article by URL, converts it to Markdown and writes it to a file.
@MainActor
final class Model: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case saved(URL)
        case failed(String)
        /// 最前面のブラウザーから読み込む needs the Accessibility permission.
        case needsAccess
    }

    @Published var urlText = ""
    @Published private(set) var markdown = ""
    @Published private(set) var article: NoteArticle?
    @Published private(set) var status: Status = .idle
    /// The input the current `markdown` was made from (a changed field needs loading again).
    private var loadedInput = ""
    private var task: Task<Void, Never>?

    private let defaults = UserDefaults.standard
    /// Stay running after the main window is closed. On by default.
    @Published var keepRunning: Bool { didSet { defaults.set(keepRunning, forKey: "keepRunning") } }
    /// Look up the titles of embedded note articles for their link text. On by default.
    @Published var fetchEmbedTitles: Bool { didSet { defaults.set(fetchEmbedTitles, forKey: "fetchEmbedTitles") } }
    /// ファイル名: the article title (default) or the article key (n + 12 characters, as in the URL).
    @Published var fileNameByKey: Bool { didSet { defaults.set(fileNameByKey, forKey: "fileNameByKey") } }
    /// Markdownエディター: the app 「…で開く」 uses. Empty = the default app for .md files. Set on each Mac.
    @Published var editorPath: String { didSet { defaults.set(editorPath, forKey: "editorPath") } }
    /// Send the in-app note session so the paid part of own or bought articles loads. Off by default, set on each Mac.
    @Published var useLogin: Bool { didSet { defaults.set(useLogin, forKey: "useLogin") } }

    init() {
        keepRunning = defaults.object(forKey: "keepRunning") as? Bool ?? true
        fetchEmbedTitles = defaults.object(forKey: "fetchEmbedTitles") as? Bool ?? true
        useLogin = defaults.bool(forKey: "useLogin")
        fileNameByKey = defaults.bool(forKey: "fileNameByKey")
        editorPath = defaults.string(forKey: "editorPath") ?? ""
    }

    /// Re-reads the shared settings after an import (設定の共有) so the next save does not write the old value back.
    func reloadSharedSettings() {
        let embed = defaults.object(forKey: "fetchEmbedTitles") as? Bool ?? true
        if embed != fetchEmbedTitles { fetchEmbedTitles = embed }
        let byKey = defaults.bool(forKey: "fileNameByKey")
        if byKey != fileNameByKey { fileNameByKey = byKey }
    }

    var isLoading: Bool { status == .loading }
    var isCurrent: Bool { !markdown.isEmpty && loadedInput == urlText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var validInput: Bool { NoteArticle.key(from: urlText) != nil }

    var statusText: String {
        switch status {
        case .idle: return ""
        case .loading: return L("statusLoading")
        case .loaded: return article.map { $0.price > 0 && !$0.isFull ? L("statusPaid") : String(format: L("statusLoaded"), $0.title) } ?? ""
        case .saved(let url): return String(format: L("statusSaved"), url.path)
        case .failed(let message): return message
        case .needsAccess: return AccessibilityText.text("blocked")
        }
    }

    /// A URL dropped on the window (the favicon in a browser's address bar, a link or plain text): loads it.
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isLoading, let provider = providers.first else { return false }
        let accept: (String?) -> Void = { text in
            DispatchQueue.main.async {
                let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard NoteArticle.key(from: value) != nil else {
                    self.status = .failed(value.isEmpty ? L("errorInvalidURL") : String(format: L("errorDropNotNote"), value))
                    return
                }
                self.urlText = value
                self.load()
            }
        }
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in accept(url?.absoluteString) }
            return true
        }
        if provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { text, _ in accept(text) }
            return true
        }
        return false
    }

    /// Puts the URL of the front browser window in the field and loads it.
    func loadFromBrowser() {
        guard !isLoading else { return }
        switch FrontBrowser.currentURL() {
        case .failure(.notTrusted):
            status = .needsAccess
        case .failure(.noBrowser):
            status = .failed(L("errorNoBrowser"))
        case .failure(.noURL(let browser)):
            status = .failed(String(format: L("errorNoBrowserURL"), browser))
        case .success(let page):
            guard NoteArticle.key(from: page.url) != nil else {
                status = .failed(String(format: L("errorBrowserNotNote"), page.browser, page.url))
                return
            }
            urlText = page.url
            load()
        }
    }

    /// Loads the article in the field. `then` runs after a successful load (書き出す… on an unloaded URL).
    func load(then: (() -> Void)? = nil) {
        guard !isLoading else { return }
        let input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key = NoteArticle.key(from: input) else {
            status = .failed(input.isEmpty ? L("errorEmpty") : L("errorInvalidURL"))
            NSSound.beep()
            return
        }
        status = .loading
        let withTitles = fetchEmbedTitles
        let withLogin = useLogin
        task = Task {
            do {
                let cookie = withLogin ? await NoteLogin.shared.cookieHeader() : nil
                let article = try await NoteArticle.fetch(key: key, cookie: cookie)
                var converter = makeConverter()
                if withTitles { converter.embedTitles = await NoteArticle.titles(for: NoteMarkdown.noteEmbedURLs(in: article.body)) }
                try Task.checkCancellation()
                self.article = article
                self.markdown = converter.convert(title: article.title, html: article.body, keywords: article.keywords)
                self.loadedInput = input
                self.status = .loaded
                then?()
            } catch is CancellationError {
                self.status = .idle
            } catch let failure as NoteArticle.Failure {
                self.status = .failed(Self.message(failure))
            } catch {
                self.status = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() { task?.cancel() }

    static func message(_ failure: NoteArticle.Failure) -> String {
        switch failure {
        case .invalidURL: return L("errorInvalidURL")
        case .notFound: return L("errorNotFound")
        case .forbidden: return L("errorForbidden")
        case .noBody: return L("errorNoBody")
        case .badResponse(let code): return String(format: L("errorResponse"), code)
        case .network(let detail): return L("errorNetwork") + detail
        }
    }

    /// What happens after 書き出す… saves the file.
    enum ExportAction { case saveOnly, open, markdownKitchen }
    static let markdownKitchenID = "jp.dtp-transit.markdownkitchen"
    static var markdownKitchenURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: markdownKitchenID) }

    static let markdownType = UTType(filenameExtension: "md") ?? .plainText
    static var defaultEditorURL: URL? { NSWorkspace.shared.urlForApplication(toOpen: markdownType) }
    static func appName(_ url: URL?) -> String {
        guard let url else { return "—" }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
    /// The chosen editor when it still exists, otherwise the default app for .md files.
    var editorURL: URL? {
        if !editorPath.isEmpty, FileManager.default.fileExists(atPath: editorPath) { return URL(fileURLWithPath: editorPath) }
        return Self.defaultEditorURL
    }
    var openWithTitle: String { String(format: L("exportOpenWith"), Self.appName(editorURL)) }
    /// MarkdownKitchenに送る is left out when the editor is MarkdownKitchen itself.
    var showsKitchenItem: Bool {
        guard let kitchen = Self.markdownKitchenURL else { return false }
        return editorURL?.standardizedFileURL != kitchen.standardizedFileURL
    }

    func chooseEditor() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = L("chooseEditorPrompt")
        if panel.runModal() == .OK, let url = panel.url { editorPath = url.path }
    }

    /// 書き出す…: loads first when needed, then asks where to save.
    func export(from window: NSWindow?, then action: ExportAction = .saveOnly) {
        guard !isLoading else { return }
        guard isCurrent else { load { [weak self] in self?.export(from: window, then: action) }; return }
        guard let article else { return }
        let panel = NSSavePanel()
        panel.title = L("exportTitle")
        panel.nameFieldStringValue = fileNameByKey ? article.key + ".md" : NoteArticle.fileName(for: article.title, key: article.key)
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let path = defaults.string(forKey: "exportDirectory"), FileManager.default.fileExists(atPath: path) {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        let markdown = self.markdown
        let save: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                // NSSavePanel already asked before replacing an existing file.
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                self.defaults.set(url.deletingLastPathComponent().path, forKey: "exportDirectory")
                self.status = .saved(url)
                switch action {
                case .saveOnly: break
                case .open:
                    if let app = self.editorURL { NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) }
                    else { NSWorkspace.shared.open(url) }
                case .markdownKitchen:
                    guard let app = Self.markdownKitchenURL else { self.status = .failed(L("errorNoKitchen")); return }
                    NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
                }
            } catch {
                self.status = .failed(L("errorWrite") + error.localizedDescription)
            }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: save) } else { save(panel.runModal()) }
    }

    func copy() {
        guard isCurrent else { load { [weak self] in self?.copy() }; return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        status = .loaded
        copiedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.copiedNotice = false }
    }
    @Published var copiedNotice = false
}

struct Header: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView {
        let header = appHeader(L("headline"), subtitle: L("subtitle"))
        func unselectable(_ view: NSView) {
            if let field = view as? NSTextField { field.isSelectable = false; field.drawsBackground = false; field.refusesFirstResponder = true }
            view.subviews.forEach(unselectable)
        }
        unselectable(header)
        return header
    }
    func updateNSView(_ v: NSStackView, context: Context) {}
}

/// Read-only, selectable Markdown preview.
struct PreviewText: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let view = scroll.documentView as! NSTextView
        view.isEditable = false
        view.isSelectable = true
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 8, height: 8)
        view.drawsBackground = false
        view.setAccessibilityLabel(L("previewLabel"))
        scroll.drawsBackground = false
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let view = scroll.documentView as! NSTextView
        if view.string != text { view.string = text; DispatchQueue.main.async { view.scroll(.zero) } }
    }
}

struct ContentView: View {
    @ObservedObject var model: Model
    @FocusState private var urlFocused: Bool
    @State private var dropTargeted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header().frame(height: 48)
            HStack(spacing: 8) {
                TextField(L("urlPlaceholder"), text: $model.urlText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.load() }
                    .focused($urlFocused)
                    .disabled(model.isLoading)
                    .accessibilityLabel(L("urlLabel"))
                    // Clear button inside the field, like a search field's.
                    .overlay(alignment: .trailing) {
                        if !model.urlText.isEmpty && !model.isLoading {
                            Button {
                                model.urlText = ""
                                urlFocused = true
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 6)
                            .help(L("clearURL"))
                            .accessibilityLabel(L("clearURL"))
                        }
                    }
                Button { model.loadFromBrowser() } label: { Label(L("fromBrowser"), systemImage: "safari") }
                    .disabled(model.isLoading)
                    .help(L("fromBrowserHelp"))
                // Loading is ⌘Return (File menu); the button only appears to cancel a load in progress.
                if model.isLoading {
                    Button(L("cancel")) { model.cancel() }.keyboardShortcut(.cancelAction)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                if model.isLoading { ProgressView().controlSize(.small) }
                if case .failed(let message) = model.status, !message.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                } else if model.status == .needsAccess {
                    Image(systemName: "lock.fill").foregroundColor(.orange)
                } else if case .saved = model.status {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
                Text(model.copiedNotice ? L("statusCopied") : model.statusText)
                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                Spacer()
                if case .saved(let url) = model.status {
                    Button(L("revealInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }.controlSize(.small)
                } else if model.status == .needsAccess {
                    Button(AccessibilityText.text("open")) {
                        MainActor.assumeIsolated { _ = AccessibilitySettingsLocator.shared.open() }
                    }.controlSize(.small)
                }
            }
            .frame(minHeight: 18)
            Group {
                if model.markdown.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text").font(.largeTitle).foregroundColor(.secondary)
                        Text(L("emptyPreview")).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
                } else {
                    PreviewText(text: model.markdown)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: dropTargeted ? 3 : 1))
            .accessibilityLabel(L("dropLabel"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                Button(L("settingsButton")) { delegate.showPreferences() }
                Spacer()
                Button(L("copyMarkdown")) { model.copy() }.disabled(model.isLoading || !model.validInput)
                Menu(L("export")) {
                    Button(L("exportSaveOnly")) { model.export(from: delegate.mainWindow) }
                    Button(model.openWithTitle) { model.export(from: delegate.mainWindow, then: .open) }
                    if model.showsKitchenItem {
                        Button(L("exportToKitchen")) { model.export(from: delegate.mainWindow, then: .markdownKitchen) }
                    }
                }
                .fixedSize().disabled(model.isLoading || !model.validInput)
            }
        }
        .padding(20).frame(minWidth: 600, minHeight: 500).background(Color(nsColor: AppSurface.color))
        // Drop a URL anywhere in the window (e.g. the favicon in a browser's address bar).
        .onDrop(of: [.url, .plainText], isTargeted: $dropTargeted) { model.handleDrop($0) }
        // Start in the URL field (otherwise the first button takes the focus).
        .onAppear { DispatchQueue.main.async { urlFocused = true } }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    // LoginAtLaunchView already includes the automatic login launch explanation.
                    LoginAtLaunchView()
                    Toggle(L("keepRunning"), isOn: $model.keepRunning)
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    MenuBarPresenceView()
                }
                AccessibilitySection()
            })),
            (L("outputTab"), AnyView(VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("outputSection")) {
                Toggle(L("embedTitles"), isOn: $model.fetchEmbedTitles)
                Text(L("embedTitlesHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(L("fileNameSection")) {
                Picker("", selection: $model.fileNameByKey) {
                    Text(L("fileNameTitle")).tag(false)
                    Text(L("fileNameKey")).tag(true)
                }
                .pickerStyle(.radioGroup).labelsHidden()
            }
            EditorSettings(model: model)
            })),
            (L("loginTab"), AnyView(LoginSettings(model: model))),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
    }
}

/// Markdownエディター: the default app for .md files, or a chosen one.
struct EditorSettings: View {
    @ObservedObject var model: Model
    private var useCustom: Binding<Bool> {
        Binding(get: { !model.editorPath.isEmpty }, set: { custom in
            if !custom { model.editorPath = "" } else if model.editorPath.isEmpty { model.chooseEditor() }
        })
    }
    var body: some View {
        SettingsSection(L("editorSection")) {
            Picker("", selection: useCustom) {
                Text(String(format: L("editorDefault"), Model.appName(Model.defaultEditorURL))).tag(false)
                HStack {
                    Text(model.editorPath.isEmpty ? L("editorCustom") : String(format: L("editorCustomNamed"), Model.appName(URL(fileURLWithPath: model.editorPath))))
                    Button(L("chooseEditor")) { model.chooseEditor() }
                }.tag(true)
            }
            .pickerStyle(.radioGroup).labelsHidden()
            Text(L("editorHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 「アカウント」タブ: the sign-in option and the in-app note session.
struct LoginSettings: View {
    @ObservedObject var model: Model
    @ObservedObject var login = NoteLogin.shared
    @ObservedObject var site = SiteExport.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
        SettingsSection(L("loginSection")) {
            Toggle(L("useLogin"), isOn: $model.useLogin)
            Text(L("useLoginHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(L("loginLimit")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(login.isSignedIn ? L("signedIn") : L("signedOut")).foregroundColor(.secondary)
                Spacer()
                if login.isSignedIn { Button(L("signOut")) { login.signOut() } }
                else { Button(L("signIn")) { login.showWindow() } }
            }
        }
        // サイトをエクスポート: only while signed in.
        if login.isSignedIn {
            SettingsSection(L("siteExportSection")) {
                HStack {
                    Text(L("siteExportFolder"))
                    Text(site.folderPath.isEmpty ? L("siteExportNoFolder") : (site.folderPath as NSString).abbreviatingWithTildeInPath)
                        .foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button(L("chooseEditor")) { site.chooseFolder() }.disabled(site.isRunning)
                }
                Picker(L("siteExportImages"), selection: $site.downloadImages) {
                    Text(L("siteExportImagesRemote")).tag(false)
                    Text(L("siteExportImagesLocal")).tag(true)
                }
                .pickerStyle(.radioGroup).disabled(site.isRunning)
                Text(L("siteExportHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    if site.isRunning, site.total > 0 { ProgressView(value: Double(site.done), total: Double(site.total)) }
                    Text(site.message).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if site.isRunning { Button(L("cancel")) { site.cancel() } }
                    else { Button(L("siteExportButton")) { site.start(fetchEmbedTitles: model.fetchEmbedTitles) } }
                }
            }
        }
        }
        .onAppear { login.refresh() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = MainActor.assumeIsolated { Model() }
    var mainWindow: NSWindow!
    var preferences: NSWindow?
    var helpWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupWindow.captureLaunch()
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "jp.dtp-transit.note2markdown").sorted(by: { ($0.launchDate ?? .distantPast) == ($1.launchDate ?? .distantPast) ? $0.processIdentifier < $1.processIdentifier : ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }).first, other.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            other.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]); NSApp.terminate(nil); return
        }
        let loginLaunch = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        AccessibilityText.neededOverride = [
            "最前面のブラウザーで表示中のページのURLを読み取るために使用します。未許可の場合、「ブラウザーから」は使えません（URLの入力による書き出しは使えます）。",
            "Used to read the URL of the page in the front browser window. Without permission, From Browser is unavailable (entering a URL still works).",
            "用于读取最前面浏览器窗口中页面的 URL。未获授权时无法使用“从浏览器”（仍可输入 URL 导出）。",
            "맨 앞 브라우저 윈도우에 표시된 페이지의 URL을 읽는 데 사용합니다. 권한이 없으면 브라우저에서를 사용할 수 없습니다(URL 입력으로 내보내기는 가능)."
        ]
        installMenus()
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        mainWindow.title = ""; mainWindow.titleVisibility = .hidden; mainWindow.isReleasedWhenClosed = false; mainWindow.delegate = self
        mainWindow.contentView = NSHostingView(rootView: ContentView(model: model)); mainWindow.minSize = NSSize(width: 600, height: 500)
        mainWindow.center(); mainWindow.setFrameAutosaveName("note2markdownMain")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(mainWindow.frame) }) { mainWindow.center() }
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "note2markdown", symbol: "doc.text",
                show: { [weak self] in self?.showMain() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.showHelp() })
        }
        SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
        SettingsSync.shared.start(.init(keys: ["fetchEmbedTitles", "fileNameByKey"], prefixes: [],
            note: StartupWindow.text("「出力」タブの設定を書き出し・同期します。",
                                     "Exports and syncs the Output tab setting.",
                                     "导出并同步“输出”标签的设置。",
                                     "출력 탭의 설정을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("最後の保存先フォルダー、ログイン時の起動・常駐・メニューバーの表示はMacごとに設定します。",
                                       "The last export folder, open at login, keep running and the menu bar icon are set on each Mac.",
                                       "上次导出的文件夹、登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。",
                                       "마지막 내보내기 폴더, 로그인 시 실행, 계속 실행, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        if !loginLaunch && !StartupWindow.suppressInitialWindow { showMain() }
    }

    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ m: NSMenu, _ title: String, _ sel: Selector, _ key: String = "", _ target: AnyObject? = nil) { let i = m.addItem(withTitle: title, action: sel, keyEquivalent: key); i.target = target ?? self }
        let app = submenu("note2markdown")
        add(app, L("about"), #selector(about)); app.addItem(.separator())
        // MenuBarPresence inserts メニューバー設定… at index 2, between these separators.
        add(app, L("settings"), #selector(showPreferences), ",")
        app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: app) }
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        add(app, L("hideApp"), #selector(NSApplication.hide(_:)), "h", NSApp)
        add(app, L("hideOthers"), #selector(NSApplication.hideOtherApplications(_:)), "h", NSApp); app.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(app, L("showAll"), #selector(NSApplication.unhideAllApplications(_:)), "", NSApp); app.addItem(.separator())
        add(app, L("quit"), #selector(NSApplication.terminate(_:)), "q", NSApp)
        let file = submenu(L("file"))
        add(file, L("openMainWindow"), #selector(showMain), "0")
        file.addItem(.separator())
        add(file, L("loadMenu"), #selector(loadArticle), "\r")
        add(file, L("fromBrowserMenu"), #selector(loadFromBrowser), "l")
        add(file, L("exportMenu"), #selector(exportArticle), "s")
        add(file, L("exportOpenWith"), #selector(exportAndOpen), "s"); file.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(file, L("exportToKitchenMenu"), #selector(exportToKitchen))
        add(file, L("copyMarkdown"), #selector(copyMarkdown), "C")
        file.addItem(.separator())
        add(file, L("close"), #selector(NSWindow.performClose(_:)), "w"); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo", "undo:", "z"), ("redo", "redo:", "Z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] { let i = edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter); i.target = nil; if key == "redo" { edit.addItem(.separator()) } }
        let window = submenu(L("window"))
        for (key, selector) in [("minimize", "performMiniaturize:"), ("zoom", "performZoom:")] { window.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: "").target = nil }
        window.addItem(.separator())
        window.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "").target = NSApp
        NSApp.windowsMenu = window
        let help = submenu(L("help")); add(help, L("helpItem"), #selector(showHelp), "?"); MainActor.assumeIsolated { HelpLinks.addNoteItem(to: help) }; NSApp.helpMenu = help
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        MainActor.assumeIsolated {
            switch item.action {
            case #selector(loadArticle), #selector(exportArticle), #selector(copyMarkdown): return !model.isLoading && model.validInput
            case #selector(exportToKitchen): return !model.isLoading && model.validInput && model.showsKitchenItem
            case #selector(exportAndOpen):
                item.title = model.openWithTitle
                return !model.isLoading && model.validInput
            case #selector(loadFromBrowser): return !model.isLoading
            default: return true
            }
        }
    }

    @objc func showMain() { guard mainWindow != nil else { return }; NSApp.activate(ignoringOtherApps: true); mainWindow.makeKeyAndOrderFront(nil) }
    @objc func loadArticle() { showMain(); MainActor.assumeIsolated { model.load() } }
    @objc func loadFromBrowser() { showMain(); MainActor.assumeIsolated { model.loadFromBrowser() } }
    @objc func exportArticle() { showMain(); MainActor.assumeIsolated { model.export(from: mainWindow) } }
    @objc func exportAndOpen() { showMain(); MainActor.assumeIsolated { model.export(from: mainWindow, then: .open) } }
    @objc func exportToKitchen() { showMain(); MainActor.assumeIsolated { model.export(from: mainWindow, then: .markdownKitchen) } }
    @objc func copyMarkdown() { MainActor.assumeIsolated { model.copy() } }
    @objc func showPreferences() {
        if preferences == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = L("settingsTitle"); w.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: Preferences(model: model))
            host.sizingOptions = [.minSize]
            w.contentView = host; w.center(); w.setFrameAutosaveName("note2markdownSettings")
            preferences = w
        }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StartupWindow.userRequestedWindow(); showMain(); return true }
    /// With 常駐 off, closing the main window quits.
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        if !MainActor.assumeIsolated({ model.keepRunning }) { DispatchQueue.main.async { NSApp.terminate(nil) } }
    }
    @objc func showHelp() {
        if helpWindow == nil {
            helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: "note2markdown — " + L("help"), text: L("helpContent")) }
        }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))]) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
