import AppKit
import SwiftUI

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

final class Model: ObservableObject {
    @Published var apps: [InDesignApp] = []
    @Published var states: [String: MarkerState] = [:]
    @Published var running: Set<String> = []
    @Published var busy = false
    @Published var status = ""
    /// Bundles chosen with "Add InDesign…" outside the scanned folders.
    private var addedPaths: [String] {
        get { UserDefaults.standard.stringArray(forKey: "addedApps") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "addedApps") }
    }

    /// Keeps the last result message unless `resetStatus` (activation after the password dialog must not erase it).
    func refresh(resetStatus: Bool = false) {
        let fm = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        let known = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: AsyncExports.bundleID)
        apps = AsyncExports.discover(roots: roots, extra: known + addedPaths.map { URL(fileURLWithPath: $0) })
        states = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, AsyncExports.state(of: $0)) })
        running = Set(NSRunningApplication.runningApplications(withBundleIdentifier: AsyncExports.bundleID).compactMap { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path })
        if status.isEmpty || resetStatus { status = apps.isEmpty ? L("notFound") : String(format: L("found"), apps.count) }
    }

    func add() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let app = AsyncExports.app(at: url.resolvingSymlinksInPath().standardizedFileURL) else { status = L("notInDesign"); return }
        if !addedPaths.contains(app.id) { addedPaths.append(app.id) }
        refresh(resetStatus: true)
    }

    func change(_ selection: [InDesignApp], turnOff: Bool) {
        guard !busy else { return }
        // Re-check on disk right before acting; the list may be stale after an InDesign update.
        let targets = AsyncExports.targets(selection.compactMap { AsyncExports.app(at: $0.url) }, turnOff: turnOff)
        guard !targets.isEmpty else { refresh(); status = L("nothingToDo"); return }
        busy = true
        defer { busy = false }
        var pending: [InDesignApp] = []
        for app in targets where !AsyncExports.changeWithoutPrivileges(app, turnOff: turnOff) { pending.append(app) }
        var failure: String?
        if !pending.isEmpty, let command = AsyncExports.command(for: pending, turnOff: turnOff) {
            var error: NSDictionary?
            NSAppleScript(source: AsyncExports.appleScript(command: command, prompt: L("authPrompt")))?.executeAndReturnError(&error)
            if let error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                failure = code == -128 ? L("authCancelled") : L("failed") + (error[NSAppleScript.errorMessage] as? String ?? String(code))
            }
        } else if !pending.isEmpty {
            failure = L("failed") + L("invalidPath")
        }
        refresh()
        let succeeded = targets.filter { AsyncExports.state(of: $0) == (turnOff ? .off : .on) }.count
        let failed = targets.count - succeeded
        if succeeded == 0 {
            status = failure ?? L("failed")
        } else if failed > 0 {
            status = String(format: L("partial"), succeeded, failed) + (failure.map { "\n" + $0 } ?? "")
        } else {
            status = String(format: L(turnOff ? "doneOff" : "doneOn"), succeeded)
        }
        if succeeded > 0, targets.contains(where: { running.contains($0.id) }) { status += "\n" + L("restartNote") }
    }
}

struct Header: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView {
        let header = appHeader(L("headline"), subtitle: L("subtitle"))
        // The wrapping subtitle is selectable and becomes first responder on open, showing a blue selection.
        func unselectable(_ view: NSView) {
            if let field = view as? NSTextField { field.isSelectable = false; field.drawsBackground = false; field.refusesFirstResponder = true }
            view.subviews.forEach(unselectable)
        }
        unselectable(header)
        return header
    }
    func updateNSView(_ v: NSStackView, context: Context) {}
}

struct StateBadge: View {
    let state: MarkerState
    var body: some View {
        switch state {
        case .off: Label(L("stateOff"), systemImage: "checkmark.circle.fill").foregroundColor(.green)
        case .on: Label(L("stateOn"), systemImage: "circle").foregroundColor(.secondary)
        case .invalid: Label(L("stateInvalid"), systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
        }
    }
}

struct AppRow: View {
    @ObservedObject var model: Model
    let app: InDesignApp
    var state: MarkerState { model.states[app.id] ?? .invalid }
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().scaledToFit().frame(width: 40, height: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name).font(.system(size: 14, weight: .semibold))
                    Text(app.version).font(.system(size: 12)).foregroundColor(.secondary)
                    if model.running.contains(app.id) {
                        Text(L("running")).font(.system(size: 10, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                }
                StateBadge(state: state).font(.system(size: 12))
                Text(state == .invalid ? L("invalidDetail") : app.macOSFolder.path).font(.system(size: 11)).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle).help(app.markerFile.path)
            }
            Spacer()
            Button { NSWorkspace.shared.activateFileViewerSelecting([state == .on ? app.macOSFolder : app.markerFile]) } label: { Image(systemName: "magnifyingglass") }
                .help(L("reveal")).accessibilityLabel(app.name + ": " + L("reveal"))
            switch state {
            case .on: Button(L("turnOff")) { model.change([app], turnOff: true) }.accessibilityLabel(app.name + ": " + L("turnOff"))
            case .off: Button(L("restore")) { model.change([app], turnOff: false) }.accessibilityLabel(app.name + ": " + L("restore"))
            case .invalid: EmptyView()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }
}

struct ContentView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header().frame(height: 48)
            VStack(spacing: 0) {
                if model.apps.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                        Text(L("notFound")).font(.system(size: 14, weight: .medium))
                        Text(L("notFoundDetail")).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("addApp")) { model.add() }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(model.apps) { app in
                                AppRow(model: model, app: app)
                                if app != model.apps.last { Divider().padding(.leading, 66) }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            Text(L("updateNote")).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(model.status).font(.system(size: 13)).lineLimit(3).textSelection(.enabled).frame(minHeight: 34, alignment: .topLeading)
            HStack {
                Button(L("help")) { delegate.showHelp() }
                Button(L("addApp")) { model.add() }
                Spacer()
                Button(L("reload")) { model.refresh(resetStatus: true) }
                Button(L("turnOffAll")) { model.change(model.apps, turnOff: true) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.apps.contains { model.states[$0.id] == .on })
            }
        }
        .disabled(model.busy)
        .padding(20).frame(minWidth: 620, minHeight: 420).background(Color(nsColor: AppSurface.color))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var mainWindow: NSWindow!
    var helpWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.takano.IdAsyncOff").sorted(by: { ($0.launchDate ?? .distantPast) == ($1.launchDate ?? .distantPast) ? $0.processIdentifier < $1.processIdentifier : ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }).first, other.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            other.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]); NSApp.terminate(nil); return
        }
        installMenus()
        model.refresh()
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 460), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        mainWindow.title = ""; mainWindow.titleVisibility = .hidden; mainWindow.isReleasedWhenClosed = false; mainWindow.delegate = self
        mainWindow.contentView = NSHostingView(rootView: ContentView(model: model)); mainWindow.minSize = NSSize(width: 620, height: 420)
        mainWindow.center(); mainWindow.setFrameAutosaveName("IdBackgroundOffMain")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(mainWindow.frame) }) { mainWindow.center() }
        showMain()
    }
    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ m: NSMenu, _ title: String, _ sel: Selector, _ key: String = "", _ target: AnyObject? = nil) { let i = m.addItem(withTitle: title, action: sel, keyEquivalent: key); i.target = target ?? self }
        let app = submenu("IdBackgroundOff")
        add(app, L("about"), #selector(about))
        add(app, L("updates"), #selector(updates))
        app.addItem(.separator())
        add(app, L("quit"), #selector(NSApplication.terminate(_:)), "q", NSApp)
        let file = submenu(L("file"))
        add(file, L("reload"), #selector(reload), "r")
        add(file, L("addApp"), #selector(addApp), "o")
        file.addItem(.separator())
        add(file, L("close"), #selector(NSWindow.performClose(_:)), "w"); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo", "undo:", "z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] { let i = edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter); i.target = nil }
        let help = submenu(L("help")); add(help, L("helpItem"), #selector(showHelp), "?"); NSApp.helpMenu = help
    }
    @objc func showMain() { guard mainWindow != nil else { return }; NSApp.activate(ignoringOtherApps: true); mainWindow.makeKeyAndOrderFront(nil) }
    @objc func reload() { model.refresh(resetStatus: true) }
    @objc func addApp() { showMain(); model.add() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    // InDesign may have been updated or reinstalled while we were in the background.
    func applicationDidBecomeActive(_ notification: Notification) { if !model.busy { model.refresh() } }
    /// Not resident by design: closing the main window quits (help window alone does not keep it alive).
    func windowWillClose(_ notification: Notification) { if notification.object as? NSWindow === mainWindow { NSApp.terminate(nil) } }
    @objc func showHelp() {
        if helpWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 560), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false); w.title = "IdBackgroundOff — " + L("help"); w.isReleasedWhenClosed = false
            let scroll = NSScrollView(frame: w.contentView!.bounds); scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true
            let text = NSTextView(frame: scroll.bounds); text.isEditable = false; text.isVerticallyResizable = true; text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true; text.textContainerInset = NSSize(width: 24, height: 24); text.font = .systemFont(ofSize: 14); text.string = L("helpContent")
            scroll.documentView = text; w.contentView = scroll; w.center(); helpWindow = w
        }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))]) }
    @objc func updates() { let a = NSAlert(); a.messageText = L("updatesPending"); a.informativeText = L("updatesDetail"); a.runModal() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
