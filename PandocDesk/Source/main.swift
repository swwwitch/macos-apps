import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement

func L(_ key: String) -> String { NSLocalizedString(key, comment:"") }

@MainActor final class Model: ObservableObject {
    @Published var files: [URL] = []
    @Published var formatID = UserDefaults.standard.string(forKey:"format") ?? "docx" { didSet { UserDefaults.standard.set(formatID,forKey:"format") } }
    @Published var reader = "auto"
    @Published var toc = false
    @Published var numbers = false
    @Published var standalone = true
    @Published var wrap = "auto"
    @Published var htmlFormatting = HTMLFormatting(rawValue:UserDefaults.standard.string(forKey:"htmlFormatting") ?? "standard") ?? .standard { didSet { UserDefaults.standard.set(htmlFormatting.rawValue,forKey:"htmlFormatting") } }
    @Published var pdfEngine = UserDefaults.standard.string(forKey:"pdfEngine") ?? "typst" { didSet { UserDefaults.standard.set(pdfEngine,forKey:"pdfEngine") } }
    @Published var keynoteSlideSize = KeynoteSlideSize(rawValue:UserDefaults.standard.string(forKey:"keynoteSlideSize") ?? "") ?? .matchPDF { didSet { UserDefaults.standard.set(keynoteSlideSize.rawValue,forKey:"keynoteSlideSize") } }
    @Published var keynotePlacement = KeynotePlacement(rawValue:UserDefaults.standard.string(forKey:"keynotePlacement") ?? "") ?? .fit { didSet { UserDefaults.standard.set(keynotePlacement.rawValue,forKey:"keynotePlacement") } }
    @Published var keynoteBox = KeynotePageBox(rawValue:UserDefaults.standard.string(forKey:"keynoteBox") ?? "") ?? .crop { didSet { UserDefaults.standard.set(keynoteBox.rawValue,forKey:"keynoteBox") } }
    @Published var showAutomationHelp = false
    @Published var busy = false
    @Published var status = ""
    @Published var details = ""
    @Published var completed = 0
    @Published var results: [URL] = []
    @Published var destinationMode = UserDefaults.standard.string(forKey:"destinationMode") ?? "source" { didSet { UserDefaults.standard.set(destinationMode,forKey:"destinationMode") } }
    @Published var openAfterConversion = UserDefaults.standard.bool(forKey:"openAfterConversion") { didSet { UserDefaults.standard.set(openAfterConversion,forKey:"openAfterConversion") } }
    @Published var folder: URL? = UserDefaults.standard.string(forKey:"outputFolder").map { URL(fileURLWithPath:$0) } { didSet { UserDefaults.standard.set(folder?.path,forKey:"outputFolder") } }
    var runner: ConversionRunner?
    var format: OutputFormat { OutputFormat.all.first { $0.id == formatID } ?? OutputFormat.defaultFormat }
    func add(_ urls: [URL]) {
        guard !busy else { return }
        let allowed = Set(["md","markdown","txt","html","htm","docx","odt","rtf","epub","tex","rst","org","ipynb","json","csv","tsv","pptx","typ","wiki","xml","idml","pdf"])
        var rejected = false
        for url in urls {
            guard url.isFileURL, (try? url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile) == true, allowed.contains(url.pathExtension.lowercased()) else { rejected = true; continue }
            let canonical = url.standardizedFileURL
            if !files.contains(canonical) { files.append(canonical) }
        }
        status = rejected ? L("unsupported") : ""
        results = []; details = ""
    }
    func chooseFiles() {
        let p = NSOpenPanel(); p.allowsMultipleSelection = true; p.canChooseDirectories = false
        if p.runModal() == .OK { add(p.urls) }
    }
    func chooseFolder() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        p.prompt = L("selectFolder")
        if p.runModal() == .OK { folder = p.url }
    }
    func start() {
        guard !busy, !files.isEmpty else { return }
        guard let engine = ConversionRunner.engine() else { status = L("engineMissing"); return }
        if formatID == "pdf", !ConversionRunner.pdfAvailable(pdfEngine) { status = L("pdfMissing"); return }
        if formatID == "keynote" {
            guard KeynoteBridge.isInstalled else { status = L("keynoteMissing"); return }
            if files.contains(where: { !ConversionRunner.isPDF($0) }), !ConversionRunner.pdfAvailable(pdfEngine) { status = L("keynoteNeedsPDF"); return }
        }
        if destinationMode == "custom", folder == nil { chooseFolder() }
        guard destinationMode == "source" || folder != nil else { return }
        let customFolder = destinationMode == "custom" ? folder : nil
        let shouldOpen = openAfterConversion
        let inputs = files
        var opts = ConversionOptions(format:format,reader:reader,standalone:standalone,toc:toc,numbers:numbers,wrap:wrap,pdfEngine:pdfEngine,htmlFormatting:htmlFormatting)
        // Keynote keeps the finished presentation open instead of reopening the saved file.
        opts.keynote = KeynoteOptions(slideSize:keynoteSlideSize, placement:keynotePlacement, box:keynoteBox, pageRange:nil, openAfter:shouldOpen)
        let worker = ConversionRunner(); runner = worker; busy = true; completed = 0; results = []; details = ""; showAutomationHelp = false; status = L("working")
        DispatchQueue.global(qos:.userInitiated).async {
            var outputs: [URL] = []; var errors: [String] = []; var denied = false
            for (index,input) in inputs.enumerated() {
                if worker.isCancelled { break }
                do { outputs.append(try worker.convert(engine:engine,input:input,folder:customFolder ?? input.deletingLastPathComponent(),options:opts)) }
                catch is CancellationError { break }
                catch {
                    errors.append(input.lastPathComponent + ": " + error.localizedDescription)
                    if (error as? KeynoteError) == .automationDenied { denied = true; break }  // Every remaining file would fail the same way.
                }
                DispatchQueue.main.async { self.completed = index + 1 }
            }
            let finalOutputs = outputs; let finalErrors = errors; let finalDenied = denied
            DispatchQueue.main.async {
                self.busy = false; self.runner = nil; self.results = finalOutputs
                self.details = finalErrors.joined(separator:"\n\n")
                let key = worker.isCancelled ? "cancelled" : finalErrors.isEmpty ? "success" : finalOutputs.isEmpty ? "failed" : "partial"
                self.status = L(key) + " · \(finalOutputs.count)/\(inputs.count)"
                self.showAutomationHelp = finalDenied
                if shouldOpen && !worker.isCancelled {
                    for url in finalOutputs where url.pathExtension.lowercased() != "key" { NSWorkspace.shared.open(url) }
                    if finalOutputs.contains(where: { $0.pathExtension.lowercased() == "key" }) { KeynoteBridge.activateKeynote() }
                }
            }
        }
    }
    func cancel() { runner?.cancel(); status = L("cancelling") }
}

struct MainView: View {
    @ObservedObject var model: Model
    @ObservedObject var pdfManager = PDFEngineManager.shared
    @State private var targeted = false
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(spacing:12) {
                Image(nsImage:currentAppIcon()).resizable().frame(width:52,height:52).accessibilityHidden(true)
                VStack(alignment:.leading,spacing:4) { Text(L("heading")).font(.system(size:22,weight:.semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
                Text("PANDOC DESK").font(.system(size:10,weight:.semibold,design:.rounded)).tracking(2).foregroundStyle(.secondary)
            }
            HStack(alignment:.top,spacing:16) {
                VStack(alignment:.leading,spacing:12) {
                    heading("01", L("input"))
                    VStack(spacing:12) {
                        Image(systemName:"doc.badge.plus").font(.system(size:32,weight:.light)).foregroundColor(.secondary)
                        Text(L("drop")).font(.headline)
                        Text(L("inputHint")).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("chooseFiles")) { model.chooseFiles() }
                    }.frame(maxWidth:.infinity).frame(height:155)
                    .background(Color(nsColor:.textBackgroundColor)).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(targeted ? Color.accentColor : Color.gray.opacity(0.35),style:StrokeStyle(lineWidth:1.5,dash:[6,4])))
                    .onDrop(of:[UTType.fileURL.identifier],isTargeted:$targeted) { providers in
                        guard !model.busy else { return false }
                        for provider in providers { _ = provider.loadObject(ofClass:URL.self) { url,_ in if let url { DispatchQueue.main.async { model.add([url]) } } } }
                        return true
                    }
                    ScrollView {
                        VStack(spacing:8) {
                            ForEach(model.files,id:\.self) { url in
                                HStack(spacing:8) {
                                    Image(nsImage:NSWorkspace.shared.icon(forFile:url.path)).resizable().frame(width:24,height:24)
                                    Text(url.lastPathComponent).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading).help(url.path)
                                    Button { model.files.removeAll { $0 == url } } label: { Image(systemName:"xmark.circle.fill").foregroundColor(.secondary) }.buttonStyle(.plain).accessibilityLabel(L("remove"))
                                }.padding(9).background(Color(nsColor:.textBackgroundColor)).cornerRadius(7)
                            }
                        }
                    }
                    HStack { Text("\(model.files.count) " + L("files")).font(.caption).foregroundColor(.secondary); Spacer(); Button(L("clear")) { model.files = [] }.disabled(model.files.isEmpty) }
                }.frame(maxWidth:.infinity).disabled(model.busy)
                Divider()
                VStack(alignment:.leading,spacing:12) {
                    heading("02",L("format"))
                    ScrollView {
                        VStack(spacing:6) {
                            ForEach(OutputFormat.all) { format in
                                Button { model.formatID = format.id } label: {
                                    HStack { VStack(alignment:.leading,spacing:2) { Text(format.name).fontWeight(.medium); Text("." + format.ext).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName:model.formatID == format.id ? "checkmark.circle.fill" : "circle").foregroundColor(model.formatID == format.id ? .accentColor : .gray.opacity(0.4)) }
                                    .padding(.horizontal,12).padding(.vertical,8).background(model.formatID == format.id ? Color.accentColor.opacity(0.12) : Color(nsColor:.textBackgroundColor)).cornerRadius(7)
                                }.buttonStyle(.plain).accessibilityLabel(format.name).accessibilityValue(model.formatID == format.id ? L("selected") : "")
                            }
                        }
                    }
                }.frame(width:195).disabled(model.busy)
                Divider()
                VStack(alignment:.leading,spacing:14) {
                    heading("03",L("options"))
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            Text(L("readAs")).fontWeight(.medium)
                            Picker("",selection:$model.reader) {
                                Text(L("auto")).tag("auto")
                                ForEach(["markdown","gfm","html","docx","odt","rtf","epub","latex","rst","org","ipynb","csv","tsv","idml","pdf"],id:\.self) { Text($0).tag($0) }
                            }.labelsHidden().accessibilityLabel(L("readAs"))
                            Divider()
                            Toggle(L("standalone"),isOn:$model.standalone)
                            Toggle(L("toc"),isOn:$model.toc).disabled(!model.format.supportsTOC)
                            Toggle(L("numbers"),isOn:$model.numbers).disabled(!model.format.supportsNumbers)
                            if ["gfm","plain","latex"].contains(model.formatID) {
                                Picker(L("wrap"),selection:$model.wrap) { Text(L("auto")).tag("auto"); Text(L("preserve")).tag("preserve"); Text(L("none")).tag("none") }
                            }
                            if model.formatID == "html5" {
                                Picker(L("htmlFormatting"),selection:$model.htmlFormatting) {
                                    Text(L("htmlStandard")).tag(HTMLFormatting.standard)
                                    Text("minify").tag(HTMLFormatting.minify)
                                    Text("beautify").tag(HTMLFormatting.beautify)
                                }.pickerStyle(.radioGroup)
                                Text(L("htmlFormattingHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                            }
                            if model.formatID == "keynote" {
                                Picker(L("slideSize"),selection:$model.keynoteSlideSize) { ForEach(KeynoteSlideSize.allCases) { Text($0.label).tag($0) } }
                                Picker(L("placement"),selection:$model.keynotePlacement) { Text(L("fit")).tag(KeynotePlacement.fit); Text(L("fill")).tag(KeynotePlacement.fill) }.pickerStyle(.radioGroup)
                                if model.keynotePlacement == .fill { Text(L("fillHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                                Picker(L("box"),selection:$model.keynoteBox) { ForEach(KeynotePageBox.allCases) { Text($0.label).tag($0) } }
                                Text(L("keynoteHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                            }
                            if model.formatID == "pdf" || (model.formatID == "keynote" && model.files.contains(where: { !ConversionRunner.isPDF($0) })) {
                                Picker(L("pdfEngine"),selection:$model.pdfEngine) { Text("Typst").tag("typst"); Text("XeLaTeX").tag("xelatex"); Text("LuaLaTeX").tag("lualatex") }
                                Label(L(ConversionRunner.pdfAvailable(model.pdfEngine) ? "pdfReady" : "pdfMissing"),systemImage:"info.circle").font(.caption).foregroundColor(.secondary)
                                Button(L("pdfSetup")) { (NSApp.delegate as? Delegate)?.showSettings() }
                            }
                            Divider()
                            Text(L("output")).fontWeight(.medium)
                            Picker(L("output"),selection:$model.destinationMode) {
                                Text(L("sameFolder")).tag("source")
                                Text(L("specifiedFolder")).tag("custom")
                            }.pickerStyle(.radioGroup).labelsHidden()
                            if model.destinationMode == "custom" {
                                Text(model.folder?.path ?? L("chooseOnConvert")).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                                Button(L("selectFolder")) { model.chooseFolder() }
                            }
                            Toggle(L("openAfterConversion"),isOn:$model.openAfterConversion)
                            if model.files.contains(where: { $0.pathExtension.lowercased() == "idml" }) || model.reader == "idml" { Text(L("idmlLimit")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                            if model.formatID != "keynote", model.files.contains(where: { $0.pathExtension.lowercased() == "pdf" }) || model.reader == "pdf" { Text(L("pdfInputHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                            if model.formatID == "idml" { Text(L("idmlOutputHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                            Text(L("preserveOriginal")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                        }
                    }
                }.frame(width:260).disabled(model.busy)
            }
            Divider()
            if !model.details.isEmpty { ScrollView { Text(model.details).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(height:64) }
            HStack(spacing:12) {
                if model.busy { ProgressView().controlSize(.small); Text("\(model.completed)/\(model.files.count)").monospacedDigit() }
                Text(model.status.isEmpty ? L("ready") : model.status).font(.callout).lineLimit(2).textSelection(.enabled)
                Spacer()
                if model.showAutomationHelp { Button(L("permOpen")) { KeynoteBridge.openAutomationSettings() } }
                if !model.results.isEmpty { Button(L("reveal")) { NSWorkspace.shared.activateFileViewerSelecting(model.results) } }
                if model.busy { Button(L("cancel")) { model.cancel() }.keyboardShortcut(.cancelAction) }
                Button(L("convert")) { model.start() }.keyboardShortcut(.return,modifiers:.command).buttonStyle(.borderedProminent).controlSize(.large).disabled(model.files.isEmpty || model.busy)
            }
        }.onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) { _ in
            model.pdfEngine = UserDefaults.standard.string(forKey:"pdfEngine") ?? "typst"
        }.onReceive(pdfManager.$version) { _ in
            model.pdfEngine = UserDefaults.standard.string(forKey:"pdfEngine") ?? "typst"
        }.padding(24).frame(minWidth:990,minHeight:670).background(Color(nsColor:AppSurface.color)).tint(Color(red:0.55,green:0.38,blue:0.04))
    }
    func heading(_ number: String,_ title: String) -> some View {
        HStack(spacing:8) { Text(number).font(.system(size:11,weight:.semibold,design:.rounded)).foregroundColor(.secondary); Text(title).font(.system(size:14,weight:.semibold)) }
    }
}

struct SettingsView: View {
    @AppStorage("resident") var resident = true
    @AppStorage("pandocPath") var path = ""
    var body: some View {
        ScrollView { VStack(spacing:16) {
            SettingsSection(SettingsUI.launchTitle) {
                LoginAtLaunchView()
                Toggle(L("resident"),isOn:$resident)
                Text(L("residentDetail")).font(.caption).foregroundColor(.secondary)
                HStack { Text(L("launchShortcut")); Spacer(); Button(L("openShortcuts")) { NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/Shortcuts.app")) } }
                Text(L("shortcutDetail")).font(.caption).foregroundColor(.secondary)
            }
            SettingsSection(L("engine")) { EngineSettingsView() }
            SettingsSection(L("pdfEngineGroup")) { PDFEngineSettingsView() }
            SettingsSection(L("permission")) { KeynotePermissionView() }
        }.padding(20) }.frame(width:600,height:680)
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var statusItem: NSStatusItem?
    var isDuplicate = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults:["resident":true])
        if let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier:id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            isDuplicate = true
            other.activate(options:[.activateAllWindows,.activateIgnoringOtherApps])
            let urls = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }.map { URL(fileURLWithPath:$0) }.filter { FileManager.default.fileExists(atPath:$0.path) }
            if !urls.isEmpty, let app = other.bundleURL { NSWorkspace.shared.open(urls,withApplicationAt:app,configuration:NSWorkspace.OpenConfiguration()) }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { NSApp.terminate(nil) }
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicate else { return }
        buildMenus()
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:1080,height:720),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title = "PandocDesk"; window.titleVisibility = .hidden; window.contentView = NSHostingView(rootView:MainView(model:model)); window.delegate = self; window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width:1030,height:710)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName:"doc.on.doc",accessibilityDescription:"PandocDesk")
        let menu = NSMenu(); add(menu,L("show"),#selector(show),""); add(menu,L("settings"),#selector(showSettings),""); add(menu,L("help"),#selector(showHelp),""); menu.addItem(withTitle:HelpLinks.noteTitle,action:#selector(HelpLinks.openNote),keyEquivalent:"").target = HelpLinks.shared; menu.addItem(.separator()); add(menu,L("quit"),#selector(quit),""); statusItem?.menu = menu
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !model.files.isEmpty || (!login && !StartupWindow.hidden) { show() }
    }
    @objc func show() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool) -> Bool { show(); return true }
    func application(_ sender:NSApplication,open urls:[URL]) {
        if isDuplicate, let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier:id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }), let app = other.bundleURL { NSWorkspace.shared.open(urls,withApplicationAt:app,configuration:NSWorkspace.OpenConfiguration()); return }
        model.add(urls); show()
    }
    func windowShouldClose(_ sender:NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey:"resident") { NSApp.terminate(nil); return false }
        return true
    }
    func applicationShouldTerminate(_ sender:NSApplication) -> NSApplication.TerminateReply {
        if EngineManager.shared.busy || PDFEngineManager.shared.busy { let a = NSAlert(); a.messageText = L("installing"); a.informativeText = L("waitInstall"); a.runModal(); return .terminateCancel }
        if model.busy {
            let a = NSAlert(); a.messageText = L("working"); a.informativeText = L("quitBusy"); a.addButton(withTitle:L("ok")); a.runModal(); show(); return .terminateCancel
        }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) { KeynoteBridge.removeRuntimeScript() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func choose() { show(); model.chooseFiles() }
    @objc func showSettings() {
        if settings == nil { settings = NSWindow(contentRect:NSRect(x:0,y:0,width:560,height:450),styleMask:[.titled,.closable],backing:.buffered,defer:false); settings!.title = L("settingsWindow"); settings!.contentView = NSHostingView(rootView:SettingsView()); settings!.isReleasedWhenClosed = false; settings!.center() }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource:"Help",withExtension:"txt").flatMap { try? String(contentsOf:$0,encoding:.utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle:L("help"), text:text, heading:"PandocDesk")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func updates() { let a = NSAlert(); a.messageText = L("updatePending"); a.informativeText = L("updateDetail"); a.runModal() }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"PandocDesk",.applicationVersion:"\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))",.credits:NSAttributedString(string:L("aboutDetail"))]) }
    func add(_ menu:NSMenu,_ title:String,_ action:Selector,_ key:String) { let item = menu.addItem(withTitle:title,action:action,keyEquivalent:key); item.target = self }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        add(app,L("about"),#selector(about),""); add(app,L("updates"),#selector(updates),""); app.addItem(.separator()); add(app,L("settings"),#selector(showSettings),","); app.addItem(.separator()); add(app,L("quit"),#selector(quit),"q")
        let file = NSMenu(title:L("fileMenu")); let f = NSMenuItem(title:L("fileMenu"),action:nil,keyEquivalent:""); f.submenu = file; bar.addItem(f); add(file,L("chooseFiles"),#selector(choose),"o"); file.addItem(withTitle:L("close"),action:#selector(NSWindow.performClose(_:)),keyEquivalent:"w")
        let edit = NSMenu(title:L("editMenu")); let e = NSMenuItem(title:L("editMenu"),action:nil,keyEquivalent:""); e.submenu = edit; bar.addItem(e)
        for (key,action,shortcut) in [("undo","undo:","z"),("cut","cut:","x"),("copy","copy:","c"),("paste","paste:","v"),("selectAll","selectAll:","a")] { edit.addItem(withTitle:L(key),action:Selector(action),keyEquivalent:shortcut) }
        let h = NSMenu(title:L("help")); let hi = NSMenuItem(title:L("help"),action:nil,keyEquivalent:""); hi.submenu = h; bar.addItem(hi); add(h,L("help"),#selector(showHelp),"?"); HelpLinks.addNoteItem(to:h); NSApp.helpMenu = h
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
