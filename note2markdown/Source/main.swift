import AppKit
import SwiftUI
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Loads a note article by URL, converts it to Markdown and writes it to a file.
@MainActor
final class Model: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case saved(URL)
        case failed(String)
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

    init() {
        keepRunning = defaults.object(forKey: "keepRunning") as? Bool ?? true
        fetchEmbedTitles = defaults.object(forKey: "fetchEmbedTitles") as? Bool ?? true
    }

    var isLoading: Bool { status == .loading }
    var isCurrent: Bool { !markdown.isEmpty && loadedInput == urlText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var validInput: Bool { NoteArticle.key(from: urlText) != nil }

    var statusText: String {
        switch status {
        case .idle: return ""
        case .loading: return L("statusLoading")
        case .loaded: return article.map { $0.price > 0 ? L("statusPaid") : String(format: L("statusLoaded"), $0.title) } ?? ""
        case .saved(let url): return String(format: L("statusSaved"), url.path)
        case .failed(let message): return message
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
        task = Task {
            do {
                let article = try await NoteArticle.fetch(key: key)
                var converter = NoteMarkdown()
                converter.noteLinkText = L("noteLinkText")
                converter.tweetLinkText = L("tweetLinkText")
                converter.imageText = L("imageText")
                if withTitles { converter.embedTitles = await NoteArticle.titles(for: NoteMarkdown.noteEmbedURLs(in: article.body)) }
                try Task.checkCancellation()
                self.article = article
                self.markdown = converter.convert(title: article.title, html: article.body)
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

    /// 書き出す…: loads first when needed, then asks where to save.
    func export(from window: NSWindow?) {
        guard !isLoading else { return }
        guard isCurrent else { load { [weak self] in self?.export(from: window) }; return }
        guard let article else { return }
        let panel = NSSavePanel()
        panel.title = L("exportTitle")
        panel.nameFieldStringValue = NoteArticle.fileName(for: article.title, key: article.key)
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
                if model.isLoading {
                    Button(L("cancel")) { model.cancel() }.keyboardShortcut(.cancelAction)
                } else {
                    Button(L("load")) { model.load() }.disabled(!model.validInput)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                if model.isLoading { ProgressView().controlSize(.small) }
                if case .failed(let message) = model.status, !message.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                } else if case .saved = model.status {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
                Text(model.copiedNotice ? L("statusCopied") : model.statusText)
                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                Spacer()
                if case .saved(let url) = model.status {
                    Button(L("revealInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }.controlSize(.small)
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
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                Button(L("help")) { delegate.showHelp() }
                Button(L("settingsButton")) { delegate.showPreferences() }
                Spacer()
                Button(L("copyMarkdown")) { model.copy() }.disabled(model.isLoading || !model.validInput)
                Button(L("export")) { model.export(from: delegate.mainWindow) }
                    .keyboardShortcut(.defaultAction).disabled(model.isLoading || !model.validInput)
            }
        }
        .padding(20).frame(minWidth: 600, minHeight: 500).background(Color(nsColor: AppSurface.color))
        // Start in the URL field (otherwise the first button takes the focus).
        .onAppear { DispatchQueue.main.async { urlFocused = true } }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) {
                LoginAtLaunchView()
                StartupWindowView()
                Toggle(L("keepRunning"), isOn: $model.keepRunning)
                Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            })),
            (L("outputTab"), AnyView(SettingsSection(L("outputSection")) {
                Toggle(L("embedTitles"), isOn: $model.fetchEmbedTitles)
                Text(L("embedTitlesHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            })),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = MainActor.assumeIsolated { Model() }
    var mainWindow: NSWindow!
    var preferences: NSWindow?
    var helpWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "jp.dtp-transit.note2markdown").sorted(by: { ($0.launchDate ?? .distantPast) == ($1.launchDate ?? .distantPast) ? $0.processIdentifier < $1.processIdentifier : ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }).first, other.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            other.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]); NSApp.terminate(nil); return
        }
        let loginLaunch = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
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
        if !loginLaunch && !StartupWindow.hidden { showMain() }
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
        add(file, L("loadMenu"), #selector(loadArticle), "r")
        add(file, L("exportMenu"), #selector(exportArticle), "s")
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
            default: return true
            }
        }
    }

    @objc func showMain() { guard mainWindow != nil else { return }; NSApp.activate(ignoringOtherApps: true); mainWindow.makeKeyAndOrderFront(nil) }
    @objc func loadArticle() { showMain(); MainActor.assumeIsolated { model.load() } }
    @objc func exportArticle() { showMain(); MainActor.assumeIsolated { model.export(from: mainWindow) } }
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
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
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
