import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

struct InputFile: Identifiable, Equatable {
    let url: URL
    let pages: Int
    var id: URL { url }
}

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var files: [InputFile] = [] { didSet { refreshBackgrounds() } }
    @Published var slideSize = KeynoteSlideSize(rawValue: UserDefaults.standard.string(forKey: "slideSize") ?? "") ?? .matchPDF { didSet { defaults.set(slideSize.rawValue, forKey: "slideSize") } }
    @Published var placement = KeynotePlacement(rawValue: UserDefaults.standard.string(forKey: "placement") ?? "") ?? .fit { didSet { defaults.set(placement.rawValue, forKey: "placement") } }
    @Published var box = KeynotePageBox(rawValue: UserDefaults.standard.string(forKey: "pageBox") ?? "") ?? .crop { didSet { defaults.set(box.rawValue, forKey: "pageBox"); refreshBackgrounds() } }
    @Published var useRange = false { didSet { refreshBackgrounds() } }
    @Published var rangeFrom = 1 { didSet { refreshBackgrounds() } }
    @Published var rangeTo = 1 { didSet { refreshBackgrounds() } }
    @Published var removeBackground = UserDefaults.standard.bool(forKey: "removeBackground") { didSet { defaults.set(removeBackground, forKey: "removeBackground"); refreshBackgrounds() } }
    /// "" = Keynote's default theme / no master.
    @Published var theme = UserDefaults.standard.string(forKey: "theme") ?? "" { didSet { defaults.set(theme, forKey: "theme"); if theme != oldValue { loadMasters() } } }
    @Published var master = UserDefaults.standard.string(forKey: "master") ?? "" { didSet { defaults.set(master, forKey: "master") } }
    /// Background signature → master name, kept across launches so the same template maps again.
    @Published var masterForBackground = UserDefaults.standard.dictionary(forKey: "masterForBackground") as? [String: String] ?? [:] { didSet { defaults.set(masterForBackground, forKey: "masterForBackground") } }
    @Published var themes: [String] = []
    @Published var masters: [String] = []
    @Published var loadingThemes = false
    @Published var backgrounds: [KeynoteBackgroundSummary] = []
    @Published var destinationMode = UserDefaults.standard.string(forKey: "destinationMode") ?? "source" { didSet { defaults.set(destinationMode, forKey: "destinationMode") } }
    @Published var folder: URL? = UserDefaults.standard.string(forKey: "outputFolder").map { URL(fileURLWithPath: $0) } { didSet { defaults.set(folder?.path, forKey: "outputFolder") } }
    @Published var openAfter = UserDefaults.standard.object(forKey: "openAfter") as? Bool ?? true { didSet { defaults.set(openAfter, forKey: "openAfter") } }
    @Published var busy = false
    @Published var status = ""
    @Published var details = ""
    @Published var completed = 0
    @Published var pageProgress = ""
    @Published var results: [URL] = []
    @Published var showAutomationHelp = false
    var runner: ConversionRunner?

    func add(_ urls: [URL]) {
        guard !busy else { return }
        var rejected = false
        for url in urls {
            let canonical = url.standardizedFileURL
            guard canonical.isFileURL, canonical.pathExtension.lowercased() == "pdf", let document = KeynotePDFSplitter.pageCount(canonical) else { rejected = true; continue }
            if !files.contains(where: { $0.url == canonical }) { files.append(InputFile(url: canonical, pages: document)) }
        }
        if !useRange { rangeTo = max(1, files.map(\.pages).max() ?? 1) }
        status = rejected ? L("unsupported") : ""
        results = []; details = ""; showAutomationHelp = false
    }
    /// Theme choices; a saved theme stays listed until Keynote has been asked.
    var themeChoices: [String] { themes.isEmpty && !theme.isEmpty ? [theme] : themes }
    var masterChoices: [String] {
        if !masters.isEmpty { return masters }
        return Array(Set([master] + masterForBackground.values).filter { !$0.isEmpty }).sorted()
    }
    func masterBinding(_ signature: String) -> Binding<String> {
        Binding(get: { self.masterForBackground[signature] ?? "" }, set: { self.masterForBackground[signature] = $0.isEmpty ? nil : $0 })
    }

    private var backgroundGeneration = 0
    func refreshBackgrounds() {
        backgroundGeneration += 1
        let generation = backgroundGeneration
        guard removeBackground, !files.isEmpty else { backgrounds = []; return }
        let urls = files.map(\.url), box = box, range = useRange ? min(rangeFrom, rangeTo)...max(rangeFrom, rangeTo) : nil
        DispatchQueue.global(qos: .userInitiated).async {
            var merged: [KeynoteBackgroundSummary] = []
            for url in urls {
                for found in KeynotePDFSplitter.backgrounds(source: url, box: box, pageRange: range) {
                    if let index = merged.firstIndex(where: { $0.signature == found.signature }) { merged[index].pageCount += found.pageCount } else { merged.append(found) }
                }
            }
            DispatchQueue.main.async { if generation == self.backgroundGeneration { self.backgrounds = merged } }
        }
    }

    /// Asks Keynote for its themes, then the masters of the chosen theme.
    func loadThemes() {
        guard !loadingThemes else { return }
        guard KeynoteBridge.isInstalled else { status = L("keynoteMissing"); return }
        loadingThemes = true; status = L("loadingThemes")
        let chosen = theme
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () -> ([String], [String]) in
                let bridge = KeynoteBridge()
                return (try bridge.themes(), chosen.isEmpty ? [] : try bridge.masters(theme: chosen))
            }
            DispatchQueue.main.async {
                self.loadingThemes = false
                switch result {
                case .success(let (themes, masters)): self.themes = themes; self.masters = masters; self.status = ""
                case .failure(let error):
                    self.status = error.localizedDescription
                    if case KeynoteError.automationDenied = error { self.showAutomationHelp = true }
                }
            }
        }
    }

    func loadMasters() {
        masters = []
        guard !theme.isEmpty, !themes.isEmpty else { return }
        let chosen = theme
        loadingThemes = true; status = L("loadingThemes")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try KeynoteBridge().masters(theme: chosen) }
            DispatchQueue.main.async {
                self.loadingThemes = false
                guard chosen == self.theme else { return }
                switch result {
                case .success(let masters): self.masters = masters; self.status = ""
                case .failure(let error): self.status = error.localizedDescription
                }
            }
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK { add(panel.urls) }
    }
    func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = L("selectFolder")
        if panel.runModal() == .OK { folder = panel.url }
    }
    func start() {
        guard !busy, !files.isEmpty else { return }
        guard KeynoteBridge.isInstalled else { status = L("keynoteMissing"); return }
        if destinationMode == "custom", folder == nil { chooseFolder() }
        guard destinationMode != "custom" || folder != nil else { return }
        let customFolder: URL?
        switch destinationMode {
        case "custom": customFolder = folder
        case "desktop": customFolder = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        default: customFolder = nil
        }
        var options = KeynoteOptions(slideSize: slideSize, placement: placement, box: box, pageRange: nil, openAfter: openAfter)
        if useRange { options.pageRange = min(rangeFrom, rangeTo)...max(rangeFrom, rangeTo) }
        options.removeBackground = removeBackground
        if !theme.isEmpty {
            options.theme = theme
            options.master = master.isEmpty ? nil : master
            if removeBackground { options.masterForBackground = masterForBackground }
        }
        let inputs = files.map(\.url)
        let worker = ConversionRunner(); runner = worker
        busy = true; completed = 0; results = []; details = ""; pageProgress = ""; showAutomationHelp = false; status = L("working")
        DispatchQueue.global(qos: .userInitiated).async {
            var outputs: [URL] = []; var errors: [String] = []; var denied = false
            for (index, input) in inputs.enumerated() {
                if worker.isCancelled { break }
                do {
                    let output = try worker.convert(input: input, folder: customFolder ?? input.deletingLastPathComponent(), options: options) { done, total in
                        DispatchQueue.main.async { self.pageProgress = "\(input.lastPathComponent) · \(done)/\(total) " + L("pages") }
                    }
                    outputs.append(output)
                } catch is CancellationError { break }
                catch {
                    if case KeynoteError.automationDenied = error { denied = true }
                    errors.append(input.lastPathComponent + ": " + error.localizedDescription)
                    if denied { break }  // Every remaining file would fail the same way.
                }
                DispatchQueue.main.async { self.completed = index + 1 }
            }
            let finalOutputs = outputs, finalErrors = errors, finalDenied = denied
            DispatchQueue.main.async {
                self.busy = false; self.runner = nil; self.results = finalOutputs; self.pageProgress = ""
                self.details = finalErrors.joined(separator: "\n")
                self.showAutomationHelp = finalDenied
                let key = worker.isCancelled ? "cancelled" : finalErrors.isEmpty ? "success" : finalOutputs.isEmpty ? "failed" : "partial"
                self.status = L(key) + " · \(finalOutputs.count)/\(inputs.count)"
                if options.openAfter, !finalOutputs.isEmpty, !worker.isCancelled {
                    KeynoteBridge.activateKeynote()
                }
            }
        }
    }
    func cancel() { runner?.cancel(); status = L("cancelling") }
}

struct MainView: View {
    @ObservedObject var model: Model
    @State private var targeted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    heading("01", L("input"))
                    VStack(spacing: 12) {
                        Image(systemName: "doc.richtext").font(.system(size: 32, weight: .light)).foregroundColor(.secondary)
                        Text(L("drop")).font(.headline)
                        Text(L("inputHint")).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("chooseFiles")) { model.chooseFiles() }
                    }.frame(maxWidth: .infinity).frame(height: 160)
                    .background(Color(nsColor: .textBackgroundColor)).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(targeted ? Color.accentColor : Color.gray.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
                        guard !model.busy else { return false }
                        for provider in providers { _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { DispatchQueue.main.async { model.add([url]) } } } }
                        return true
                    }
                    .accessibilityElement(children: .contain).accessibilityLabel(L("drop"))
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.files) { file in
                                HStack(spacing: 8) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path)).resizable().frame(width: 24, height: 24).accessibilityHidden(true)
                                    Text(file.url.lastPathComponent).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).help(file.url.path)
                                    Text("\(file.pages) " + L("pages")).font(.caption).foregroundColor(.secondary).monospacedDigit()
                                    Button { model.files.removeAll { $0 == file } } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }.buttonStyle(.plain).accessibilityLabel(L("remove"))
                                }.padding(9).background(Color(nsColor: .textBackgroundColor)).cornerRadius(7)
                            }
                        }
                    }
                    HStack { Text("\(model.files.count) " + L("files")).font(.caption).foregroundColor(.secondary); Spacer(); Button(L("clear")) { model.files = [] }.disabled(model.files.isEmpty) }
                }.frame(maxWidth: .infinity).disabled(model.busy)
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    heading("02", L("options"))
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker(L("slideSize"), selection: $model.slideSize) { ForEach(KeynoteSlideSize.allCases) { Text($0.label).tag($0) } }
                            Picker(L("placement"), selection: $model.placement) { Text(L("fit")).tag(KeynotePlacement.fit); Text(L("fill")).tag(KeynotePlacement.fill) }.pickerStyle(.radioGroup)
                            if model.placement == .fill { hint(L("fillHint")) }
                            Picker(L("box"), selection: $model.box) { ForEach(KeynotePageBox.allCases) { Text($0.label).tag($0) } }
                            Divider()
                            backgroundSection
                            Divider()
                            Toggle(L("pageRange"), isOn: $model.useRange)
                            if model.useRange {
                                HStack(spacing: 6) {
                                    TextField(L("from"), value: $model.rangeFrom, format: .number).frame(width: 60).accessibilityLabel(L("from"))
                                    Text("–")
                                    TextField(L("to"), value: $model.rangeTo, format: .number).frame(width: 60).accessibilityLabel(L("to"))
                                    Text(L("pages")).foregroundColor(.secondary)
                                }
                                hint(L("rangeHint"))
                            }
                            Divider()
                            Text(L("output")).fontWeight(.medium)
                            Picker(L("output"), selection: $model.destinationMode) {
                                Text(L("sameFolder")).tag("source")
                                Text(L("desktop")).tag("desktop")
                                Text(L("specifiedFolder")).tag("custom")
                            }.pickerStyle(.radioGroup).labelsHidden()
                            if model.destinationMode == "custom" {
                                Text(model.folder?.path ?? L("chooseOnConvert")).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                Button(L("selectFolder")) { model.chooseFolder() }
                            }
                            Toggle(L("openAfter"), isOn: $model.openAfter)
                            hint(L("preserveOriginal"))
                        }.padding(.trailing, 8)
                    }
                }.frame(width: 320).disabled(model.busy)
            }
            Divider()
            if !model.details.isEmpty {
                ScrollView { Text(model.details).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 56)
            }
            HStack(spacing: 12) {
                if model.busy {
                    ProgressView().controlSize(.small)
                    Text("\(model.completed)/\(model.files.count)").monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.status.isEmpty ? L("ready") : model.status).font(.callout).lineLimit(2).textSelection(.enabled)
                    if !model.pageProgress.isEmpty { Text(model.pageProgress).font(.caption).foregroundColor(.secondary).lineLimit(1).monospacedDigit() }
                }
                Spacer()
                if model.showAutomationHelp { Button(L("permOpen")) { KeynoteBridge.openAutomationSettings() } }
                if !model.results.isEmpty { Button(L("reveal")) { NSWorkspace.shared.activateFileViewerSelecting(model.results) } }
                if model.busy { Button(L("cancel")) { model.cancel() }.keyboardShortcut(.cancelAction) }
                Button(L("convert")) { model.start() }.keyboardShortcut(.return, modifiers: .command).buttonStyle(.borderedProminent).controlSize(.large).disabled(model.files.isEmpty || model.busy)
            }
        }.padding(24).frame(minWidth: 860, minHeight: 600).background(Color(nsColor: AppSurface.color)).tint(appTint)
    }
    @ViewBuilder var backgroundSection: some View {
        Text(L("background")).fontWeight(.medium)
        Toggle(L("removeBackground"), isOn: $model.removeBackground)
        hint(L("removeBackgroundHint"))
        Picker(L("theme"), selection: $model.theme) {
            Text(L("themeDefault")).tag("")
            ForEach(model.themeChoices, id: \.self) { Text($0).tag($0) }
        }
        if !model.theme.isEmpty {
            Picker(L("master"), selection: $model.master) {
                Text(L("masterAuto")).tag("")
                ForEach(model.masterChoices, id: \.self) { Text($0).tag($0) }
            }
            if model.removeBackground {
                if model.backgrounds.isEmpty {
                    if !model.files.isEmpty { hint(L("noBackground")) }
                } else {
                    Text(L("backgroundsFound")).font(.caption).foregroundColor(.secondary)
                    ForEach(model.backgrounds) { background in
                        HStack(spacing: 6) {
                            HStack(spacing: 2) {
                                ForEach(Array(background.colors.prefix(4).enumerated()), id: \.offset) { _, color in
                                    RoundedRectangle(cornerRadius: 3).fill(Color(cgColor: color.cgColor)).frame(width: 16, height: 16)
                                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.gray.opacity(0.5), lineWidth: 0.5))
                                }
                            }.accessibilityHidden(true)
                            Text("\(background.pageCount) " + L("pages")).font(.caption).monospacedDigit().lineLimit(1).frame(width: 64, alignment: .trailing)
                            Picker(L("master"), selection: model.masterBinding(background.signature)) {
                                Text(L("masterSame")).tag("")
                                ForEach(model.masterChoices, id: \.self) { Text($0).tag($0) }
                            }.labelsHidden()
                        }
                    }
                }
            }
        }
        HStack {
            Button(L("loadThemes")) { model.loadThemes() }.disabled(model.loadingThemes)
            if model.loadingThemes { ProgressView().controlSize(.small) }
        }
        hint(L("themeHint"))
    }
    func heading(_ number: String, _ title: String) -> some View {
        HStack(spacing: 8) { Text(number).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.secondary).accessibilityHidden(true); Text(title).font(.system(size: 14, weight: .semibold)) }
    }
    func hint(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsView: View {
    @AppStorage("resident") var resident = true
    var body: some View {
        SettingsTabs(sections: [(SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
            SettingsSection(SettingsUI.launchTitle) {
                LaunchPresenceSection(title: SettingsUI.launchTitle, loginControl: LoginAtLaunchView(), residentTitle: L("resident"), residentDetail: L("residentDetail"), resident: $resident,
                                      presenceExtra: MenuBarPresenceView(), shortcutTitle: L("launchShortcut"), shortcutButton: L("openShortcuts"), shortcutDetail: L("shortcutDetail")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
            }
            SettingsSection(L("permission")) { KeynotePermissionView() }
        })), (AboutSection.title, AnyView(AboutView()))]).frame(minWidth: 560, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var isDuplicate = false
    var pendingFiles: [URL] = []
    var launched = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["resident": true])
        if let id = Bundle.main.bundleIdentifier, let other = otherInstance(id) {
            isDuplicate = true
            other.activate(options: [.activateAllWindows])
            let urls = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !urls.isEmpty, let app = other.bundleURL { NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        }
    }
    func otherInstance(_ id: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicate else { return }
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "PDF2Keynote"; window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: MainView(model: model))
        window.delegate = self; window.isReleasedWhenClosed = false
        if UserDefaults.standard.string(forKey: "NSWindow Frame MainWindow") == nil { window.center() }  // First launch: no saved frame yet.
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 860, height: 600)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        MenuBarPresence.shared.install(name: "PDF2Keynote", symbol: "rectangle.on.rectangle.angled", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() })
        launched = true
        if !pendingFiles.isEmpty { model.add(pendingFiles); pendingFiles = [] }
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !model.files.isEmpty || (!login && !StartupWindow.hidden) { show() }
    }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { show(); return true }
    func application(_ sender: NSApplication, open urls: [URL]) {
        if isDuplicate, let id = Bundle.main.bundleIdentifier, let other = otherInstance(id), let app = other.bundleURL {
            NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()); return
        }
        // Files handed over at launch arrive before the window exists.
        guard launched else { pendingFiles += urls; return }
        model.add(urls); show()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = L("working"); alert.informativeText = L("quitBusy"); alert.addButton(withTitle: L("ok")); alert.runModal()
        show(); return .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) {
        KeynoteBridge.removeRuntimeScript()
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func choose() { show(); model.chooseFiles() }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            // Resizable from the designed size upward; the hosting view reports only its minimum.
            let hosting = NSHostingView(rootView: SettingsView()); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 560); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "PDF2Keynote")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "PDF2Keynote", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) { menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        add(app, L("about"), #selector(about), ""); app.addItem(.separator())
        add(app, L("settings"), #selector(showSettings), ","); app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to: app)   // 「アップデートを確認…」「アップデートを自動確認」 + separator
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        app.addItem(withTitle: L("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: L("hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator()); add(app, L("quit"), #selector(quit), "q")
        let file = NSMenu(title: L("fileMenu")); let fileItem = NSMenuItem(title: L("fileMenu"), action: nil, keyEquivalent: ""); fileItem.submenu = file; bar.addItem(fileItem)
        add(file, L("openMainWindow"), #selector(show), "0"); file.addItem(.separator())
        add(file, L("chooseFiles"), #selector(choose), "o"); file.addItem(.separator())
        file.addItem(withTitle: L("close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = NSMenu(title: L("editMenu")); let editItem = NSMenuItem(title: L("editMenu"), action: nil, keyEquivalent: ""); editItem.submenu = edit; bar.addItem(editItem)
        for (key, action, shortcut) in [("undo", "undo:", "z"), ("redo", "redo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            edit.addItem(withTitle: L(key), action: Selector(action), keyEquivalent: shortcut)
        }
        edit.item(at: 1)?.keyEquivalentModifierMask = [.command, .shift]   // やり直す ⇧⌘Z
        let windowMenu = NSMenu(title: L("windowMenu")); let windowItem = NSMenuItem(title: L("windowMenu"), action: nil, keyEquivalent: ""); windowItem.submenu = windowMenu; bar.addItem(windowItem)
        windowMenu.addItem(withTitle: L("minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L("zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        let help = NSMenu(title: L("helpMenu")); let helpItem = NSMenuItem(title: L("helpMenu"), action: nil, keyEquivalent: ""); helpItem.submenu = help; bar.addItem(helpItem)
        add(help, L("help"), #selector(showHelp), "?"); HelpLinks.addNoteItem(to: help); NSApp.helpMenu = help
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
