import AppKit
import SwiftUI
import ServiceManagement
import Carbon

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
final class Model: ObservableObject {
    @Published var source: URL? { didSet { UserDefaults.standard.set(source?.path, forKey: "source") } }
    @Published var destination: URL? { didSet { UserDefaults.standard.set(destination?.path, forKey: "destination") } }
    @Published var sourceTargeted = false
    @Published var destinationTargeted = false
    @Published var busy = false
    @Published var status = L("ready")
    @Published var progress = MoveProgress()
    @Published var stopping = false
    var cancel = Cancellation()
    init() {
        #if APP_STORE
        _ = FolderAccess.shared
        #endif
        source = UserDefaults.standard.string(forKey: "source").map { URL(fileURLWithPath: $0) }
        destination = UserDefaults.standard.string(forKey: "destination").map { URL(fileURLWithPath: $0) }
    }
    func choose(_ isSource: Bool) {
        guard !busy else { return }
        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true; p.allowsMultipleSelection = false
        p.message = L(isSource ? "source" : "destination")
        if p.runModal() == .OK, let url = p.url { assign(url, isSource) }
    }
    func assign(_ url: URL, _ isSource: Bool) {
        guard !busy else { return }
        #if APP_STORE
        do { try FolderAccess.shared.remember(url) } catch { status = error.localizedDescription; return }
        #endif
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])).map({ $0.isDirectory == true && $0.isPackage != true }) == true else { status = L("invalidFolder"); return }
        if isSource { source = url } else { destination = url }
    }
    func start() {
        guard !busy, let s = source, let d = destination else { return }
        #if APP_STORE
        do { guard try FolderAccess.shared.authorize([s, d]) else { return } } catch { status = error.localizedDescription; return }
        #endif
        busy = true; stopping = false; cancel = Cancellation(); progress = MoveProgress(); status = L("scanning")
        let token = cancel
        let hidden = UserDefaults.standard.bool(forKey: "hidden")
        let folders = UserDefaults.standard.object(forKey: "folders") == nil || UserDefaults.standard.bool(forKey: "folders")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let plan = try MoveEngine.plan(source: s, destination: d, includeHidden: hidden, includeFolders: folders, cancel: token)
                DispatchQueue.main.async { self.confirm(plan) }
            } catch { DispatchQueue.main.async { self.status = error.localizedDescription; self.busy = false } }
        }
    }
    func confirm(_ plan: MovePlan) {
        guard !cancel.requested else { busy = false; status = L("cancelled"); return }
        guard !plan.items.isEmpty else { busy = false; status = L("empty"); return }
        let alert = NSAlert(); alert.messageText = String(format: L("confirmTitle"), plan.items.count)
        alert.informativeText = plan.source.path + "\n↓\n" + plan.destination.path + "\n\n" + L("confirmDetail")
        alert.addButton(withTitle: L("move")); alert.addButton(withTitle: L("cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { busy = false; status = L("cancelled"); return }
        status = L("moving"); progress.total = plan.items.count
        let token = cancel
        let journal = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FolderMover/History")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MoveEngine.run(plan, cancel: token, journalDirectory: journal) { update in
                DispatchQueue.main.async { self.progress = update }
            }
            DispatchQueue.main.async {
                self.progress = result; self.busy = false; self.stopping = false
                self.status = L(result.error != nil || result.failed > 0 ? "partial" : result.cancelled ? "cancelled" : result.skipped > 0 ? "completedSkipped" : "completed")
                if let error = result.error { self.status += "\n" + error }
            }
        }
    }
    func stop() { cancel.cancel(); stopping = true; status = L("stopping") }
}
struct Header: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(L("headline"), subtitle: L("subtitle")) }
    func updateNSView(_ v: NSStackView, context: Context) {}
}
struct FolderCard: View {
    @AppStorage("shortenDropboxPaths") var shortenDropboxPaths = true
    @ObservedObject var model: Model
    let isSource: Bool
    var targeted: Bool { isSource ? model.sourceTargeted : model.destinationTargeted }
    var targetBinding: Binding<Bool> { Binding(get: { targeted }, set: { if isSource { model.sourceTargeted = $0 } else { model.destinationTargeted = $0 } }) }
    var url: URL? { isSource ? model.source : model.destination }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(isSource ? "source" : "destination")).font(.system(size: 15, weight: .semibold)).foregroundColor(.secondary)
            Button { model.choose(isSource) } label: {
                VStack(spacing: 10) {
                    Image(nsImage: url.map { folderIcon(for: $0) } ?? NSWorkspace.shared.icon(for: .folder))
                        .resizable().scaledToFit().frame(width: 64, height: 64).accessibilityHidden(true)
                    Text(url?.lastPathComponent ?? L("chooseFolder")).font(.system(size: 17, weight: .medium)).lineLimit(1)
                    Text(url.map { PathDisplay.string($0, shortenDropbox: shortenDropboxPaths) } ?? L("dropFolder")).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2).truncationMode(.middle).frame(height: 30)
                    if let u = url, !FileManager.default.fileExists(atPath: u.path) {
                        Label(L("missing"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 172).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor).opacity(0.65)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(targeted ? Color.accentColor : Color.secondary.opacity(0.16), lineWidth: targeted ? 3 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).disabled(model.busy).help(url?.path ?? L("chooseFolder"))
            .accessibilityLabel(L(isSource ? "source" : "destination") + ": " + (url?.path ?? L("chooseFolder")))
            .onDrop(of: [.fileURL], isTargeted: targetBinding) { providers in
                guard !model.busy, providers.count == 1, let p = providers.first else { return false }
                _ = p.loadObject(ofClass: URL.self) { u, _ in if let u { DispatchQueue.main.async { model.assign(u, isSource) } } }
                return true
            }
        }
    }
}
struct ContentView: View {
    @ObservedObject var model: Model
    @AppStorage("hidden") var hidden = false
    @AppStorage("folders") var folders = true
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header().frame(height: 48)
            HStack(spacing: 18) { FolderCard(model: model, isSource: true); Image(systemName: "arrow.right").foregroundColor(.secondary); FolderCard(model: model, isSource: false) }
            HStack(spacing: 24) {
                Toggle(L("includeFolders"), isOn: $folders)
                Toggle(L("includeHidden"), isOn: $hidden)
                Spacer()
                Button { swap(&model.source, &model.destination) } label: { Image(systemName: "arrow.left.arrow.right") }.help(L("swap"))
            }.disabled(model.busy)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.status).font(.system(size: 13)).lineLimit(3).textSelection(.enabled)
                    Spacer()
                    if model.progress.total > 0 { Text("\(model.progress.processed) / \(model.progress.total)").monospacedDigit().foregroundColor(.secondary) }
                }
                if model.busy { ProgressView(value: Double(model.progress.processed), total: Double(max(1, model.progress.total))) }
                if model.progress.total > 0 {
                    Text(String(format: L("counts"), model.progress.moved, model.progress.skipped, model.progress.failed, model.progress.total - model.progress.processed)).foregroundColor(.secondary).font(.system(size: 12))
                }
            }.frame(minHeight: 45, alignment: .topLeading)
            HStack {
                Button(L("help")) { delegate.showHelp() }
                if let url = model.progress.journal { Button(L("showHistory")) { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
                Spacer()
                if model.busy { Button(L(model.stopping ? "stoppingShort" : "stop")) { model.stop() }.disabled(model.stopping).keyboardShortcut(.cancelAction) }
                Button(L("move")) { model.start() }.keyboardShortcut(.defaultAction).disabled(model.busy || model.source == nil || model.destination == nil)
            }
        }.padding(20).frame(minWidth: 700, minHeight: 435).background(Color(nsColor: AppSurface.color))
    }
}
struct SettingsView: View {
    @AppStorage("shortenDropboxPaths") var shortenDropboxPaths = true
    @AppStorage("resident") var resident = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LaunchPresenceSection(title: L("launchGroup"), loginControl: LoginAtLaunchView(), residentTitle: L("resident"), residentDetail: L("residentDetail"), resident: $resident, shortcutTitle: L("launchShortcut"), shortcutButton: L("systemSettings"), shortcutDetail: L("shortcutDetail")) {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
            }
            Divider()
            Text(L("displayGroup")).font(.headline)
            Toggle(L("shortenDropbox"), isOn: $shortenDropboxPaths)
            Text(L("shortenDropboxDetail")).font(.caption).foregroundColor(.secondary)
            Divider()
            Text(L("privacy")).font(.headline)
            Text(L("privacyDetail")).font(.caption).foregroundColor(.secondary)
            Button(L("historyFolder")) { delegate.openHistory() }
        }.padding(24).frame(width: 500)
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var mainWindow: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.takano.FolderMover").sorted(by: { ($0.launchDate ?? .distantPast) == ($1.launchDate ?? .distantPast) ? $0.processIdentifier < $1.processIdentifier : ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }).first, other.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            other.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]); NSApp.terminate(nil); return
        }
        installMenus()
        mainWindow = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 780,height: 440), styleMask: [.titled,.closable,.miniaturizable,.resizable], backing: .buffered, defer: false)
        mainWindow.title = ""; mainWindow.titleVisibility = .hidden; mainWindow.isReleasedWhenClosed = false; mainWindow.delegate = self
        mainWindow.contentView = NSHostingView(rootView: ContentView(model: model)); mainWindow.minSize = NSSize(width: 740,height: 460)
        mainWindow.center(); mainWindow.setFrameAutosaveName("FolderMoverMain")
        if !UserDefaults.standard.bool(forKey: "compactLayoutV2") { mainWindow.setContentSize(NSSize(width: 780, height: 440)); UserDefaults.standard.set(true, forKey: "compactLayoutV2") }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(mainWindow.frame) }) { mainWindow.center() }
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !login { showMain() }
    }
    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ m: NSMenu, _ title: String, _ sel: Selector, _ key: String = "", _ target: AnyObject? = nil) { let i = m.addItem(withTitle: title, action: sel, keyEquivalent: key); i.target = target ?? self }
        let app = submenu("FolderMover")
        add(app, L("about"), #selector(about))
        #if !APP_STORE
        add(app, L("updates"), #selector(updates))
        #endif
        app.addItem(.separator())
        add(app, L("settings"), #selector(showSettings), ","); app.addItem(.separator())
        add(app, L("quit"), #selector(NSApplication.terminate(_:)), "q", NSApp)
        let file = submenu(L("file")); add(file, L("showWindow"), #selector(showMain), "0"); add(file, L("close"), #selector(NSWindow.performClose(_:)), "w", nil); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo","undo:","z"),("cut","cut:","x"),("copy","copy:","c"),("paste","paste:","v"),("selectAll","selectAll:","a")] { let i = edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter); i.target = nil }
        let help = submenu(L("help")); add(help, L("help"), #selector(showHelp), "?"); NSApp.helpMenu = help
    }
    @objc func showMain() { guard mainWindow != nil else { return }; NSApp.activate(ignoringOtherApps: true); mainWindow.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    func applicationDidBecomeActive(_ notification: Notification) { model.objectWillChange.send(); if mainWindow != nil && !NSApp.windows.contains(where: { $0.isVisible }) { showMain() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === mainWindow, !UserDefaults.standard.bool(forKey: "resident"), !model.busy { NSApp.terminate(nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { return .terminateNow }
        let a = NSAlert(); a.messageText = L("busyQuit"); a.informativeText = L("busyQuitDetail"); a.addButton(withTitle: L("continue")); a.addButton(withTitle: L("stop"))
        if a.runModal() == .alertSecondButtonReturn { model.stop() }
        return .terminateCancel
    }
    @objc func showSettings() {
        if settings == nil { let w = NSWindow(contentRect: .zero, styleMask: [.titled,.closable], backing: .buffered, defer: false); w.title = L("settings"); w.isReleasedWhenClosed = false; w.contentView = NSHostingView(rootView: SettingsView()); w.center(); settings = w }
        settings?.makeKeyAndOrderFront(nil)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 680,height: 580), styleMask: [.titled,.closable,.resizable], backing: .buffered, defer: false); w.title = "FolderMover — " + L("help"); w.isReleasedWhenClosed = false
            let scroll = NSScrollView(frame: w.contentView!.bounds); scroll.autoresizingMask = [.width,.height]; scroll.hasVerticalScroller = true
            let text = NSTextView(frame: scroll.bounds); text.isEditable = false; text.isVerticallyResizable = true; text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true; text.textContainerInset = NSSize(width: 24,height: 24); text.font = .systemFont(ofSize: 14); text.string = L("helpContent")
            scroll.documentView = text; w.contentView = scroll; w.center(); helpWindow = w
        }
        helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))]) }
    @objc func updates() { let a = NSAlert(); a.messageText = L("updatesPending"); a.informativeText = L("updatesDetail"); a.runModal() }
    func openHistory() {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FolderMover/History")
        do { try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); NSWorkspace.shared.open(u) } catch { model.status = error.localizedDescription }
    }
}
UserDefaults.standard.register(defaults: ["resident":true, "folders":true, "hidden":false, "shortenDropboxPaths":true])
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
