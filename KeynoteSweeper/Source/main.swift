import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var deleteLayouts = UserDefaults.standard.object(forKey: "deleteUnusedLayouts") as? Bool ?? true { didSet { defaults.set(deleteLayouts, forKey: "deleteUnusedLayouts") } }
    @Published var deleteHidden = UserDefaults.standard.object(forKey: "deleteHiddenSlides") as? Bool ?? true { didSet { defaults.set(deleteHidden, forKey: "deleteHiddenSlides") } }
    @Published var removeTransitions = UserDefaults.standard.bool(forKey: "removeTransitions") { didSet { defaults.set(removeTransitions, forKey: "removeTransitions") } }
    @Published var removeBuilds = UserDefaults.standard.bool(forKey: "removeBuilds") { didSet { defaults.set(removeBuilds, forKey: "removeBuilds") } }
    private var checkboxRequest: SweepOptions {
        SweepOptions(deleteUnusedLayouts: deleteLayouts, deleteHiddenSlides: deleteHidden, removeTransitions: removeTransitions, removeBuilds: removeBuilds)
    }
    @Published var snapshot: KeynoteSnapshot?
    /// A dropped or chosen .key file. Nil = work on Keynote's front presentation.
    @Published var targetFile: URL?
    private var targetID: String?
    @Published var busy = false
    @Published var status = ""
    @Published var details = ""
    @Published var progress = ""
    @Published var showAutomationHelp = false
    @Published var showAccessibilityHelp = false
    var sweeper: Sweeper?

    /// Layouts that will be unused once the chosen hidden slides are gone.
    var unusedLayouts: [String] {
        guard let snapshot else { return [] }
        return snapshot.unusedLayoutIndexes(ignoringHidden: deleteHidden && !snapshot.allHidden).reversed().map { snapshot.layouts[$0 - 1] }
    }
    var hiddenCount: Int { snapshot?.hiddenCount ?? 0 }
    /// Slides with a transition that will remain after the chosen hidden slides are gone.
    var transitionCount: Int { snapshot.map { $0.transitionCount(ignoringHidden: deleteHidden && !$0.allHidden) } ?? 0 }
    var canRun: Bool {
        guard !busy, let snapshot else { return false }
        return !plan(checkboxRequest, snapshot).options.isEmpty
    }
    /// Narrows a request to what the presentation actually has, with the counts to show.
    func plan(_ request: SweepOptions, _ snapshot: KeynoteSnapshot) -> (options: SweepOptions, layouts: Int, slides: Int, transitions: Int) {
        let ignoringHidden = request.deleteHiddenSlides && !snapshot.allHidden
        let layouts = snapshot.unusedLayoutIndexes(ignoringHidden: ignoringHidden).count
        let transitions = snapshot.transitionCount(ignoringHidden: ignoringHidden)
        // Builds can only be counted by visiting every slide, so they are always attempted when asked for.
        let options = SweepOptions(deleteUnusedLayouts: request.deleteUnusedLayouts && layouts > 0, deleteHiddenSlides: request.deleteHiddenSlides && snapshot.hiddenCount > 0,
                                   removeTransitions: request.removeTransitions && transitions > 0, removeBuilds: request.removeBuilds && !snapshot.skipped.isEmpty)
        return (options, layouts, snapshot.hiddenCount, transitions)
    }

    /// Reads the target presentation. Does not launch Keynote.
    /// Re-reading on activation keeps the last result message; an explicit reload clears it.
    func refresh(clearStatus: Bool = false) {
        guard !busy else { return }
        showAutomationHelp = false
        guard KeynoteDOM.isInstalled else { snapshot = nil; status = L("keynoteMissing"); return }
        guard KeynoteDOM.runningApp != nil else { clearTarget(); snapshot = nil; status = L("keynoteNotRunning"); return }
        do {
            if let targetID {
                if let found = try KeynoteDOM.snapshot(documentID: targetID) { snapshot = found; if clearStatus { status = "" }; return }
                clearTarget()
                snapshot = try KeynoteDOM.snapshot()
                status = L("targetClosed")
                return
            }
            snapshot = try KeynoteDOM.snapshot()
            if snapshot == nil { status = L("noDocument") } else if clearStatus { status = "" }
        } catch {
            snapshot = nil; status = error.localizedDescription
            showAutomationHelp = (error as? SweepError) == .automationDenied
        }
    }

    /// Opens the file in Keynote and makes it the target, whatever is in front later.
    func open(_ urls: [URL]) {
        guard !busy else { return }
        let keynoteFiles = urls.map(\.standardizedFileURL).filter { $0.isFileURL && ["key"].contains($0.pathExtension.lowercased()) }
        guard let url = keynoteFiles.first else { status = L("unsupported"); return }
        guard KeynoteDOM.isInstalled else { status = L("keynoteMissing"); return }
        details = ""; showAutomationHelp = false
        do {
            targetID = try KeynoteDOM.open(url)
            targetFile = url
            refresh(clearStatus: true)
            NSApp.activate(ignoringOtherApps: true)
            if keynoteFiles.count > 1 || keynoteFiles.count < urls.count { status = L("oneFileOnly") }
        } catch {
            status = error.localizedDescription
            showAutomationHelp = (error as? SweepError) == .automationDenied
        }
    }
    func chooseFile() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "key") ?? .data]
        if panel.runModal() == .OK { open(panel.urls) }
    }
    func useFrontDocument() { clearTarget(); refresh(clearStatus: true) }
    private func clearTarget() { targetFile = nil; targetID = nil }

    /// Deletes with the checkbox choices, or with the given ones (Services menu) without changing the checkboxes.
    /// `quiet` (Services menu): no confirmation; the window appears only when something went wrong.
    @discardableResult
    func start(_ request: SweepOptions? = nil, quiet: Bool = false) -> Bool {
        refresh(clearStatus: true)
        guard !busy, let snapshot else { return false }
        let planned = plan(request ?? checkboxRequest, snapshot)
        let options = planned.options
        guard !options.isEmpty else { status = String(format: L("nothingToDelete"), snapshot.documentName); return false }
        if options.deleteHiddenSlides && snapshot.allHidden { status = L("allHidden"); return false }
        if (options.deleteUnusedLayouts || options.removeBuilds) && !AXIsProcessTrusted() { status = L("accessibilityDenied"); showAccessibilityHelp = true; return false }
        showAccessibilityHelp = false
        guard quiet || confirm(snapshot: snapshot, options: options, counts: planned) else { return false }
        let worker = Sweeper(); sweeper = worker
        busy = true; details = ""; progress = ""; status = L("working")
        let documentID = snapshot.documentID
        DispatchQueue.global(qos: .userInitiated).async {
            let result = worker.run(options, documentID: documentID) { done, total in
                DispatchQueue.main.async { self.progress = String(format: L("stepProgress"), done, total) }
            }
            DispatchQueue.main.async { self.finish(result, options: options, cancelled: worker.isCancelled, quiet: quiet) }
        }
        return true
    }
    /// Called with the outcome when a quiet run needs the user's attention.
    var onQuietProblem: (() -> Void)?

    private func confirm(snapshot: KeynoteSnapshot, options: SweepOptions, counts: (options: SweepOptions, layouts: Int, slides: Int, transitions: Int)) -> Bool {
        var lines: [String] = []
        if options.deleteUnusedLayouts { lines.append(String(format: L("confirmLayouts"), counts.layouts)) }
        if options.deleteHiddenSlides { lines.append(String(format: L("confirmSlides"), counts.slides)) }
        if options.removeTransitions { lines.append(String(format: L("confirmTransitions"), counts.transitions)) }
        if options.removeBuilds { lines.append(L("confirmBuilds")) }
        let alert = NSAlert()
        alert.messageText = String(format: L("confirmTitle"), snapshot.documentName)
        alert.informativeText = lines.joined(separator: "\n") + "\n\n" + L("confirmNote")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("delete"))
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func finish(_ result: SweepResult, options: SweepOptions, cancelled: Bool, quiet: Bool) {
        busy = false; sweeper = nil; progress = ""
        // A quiet run leaves Keynote in front unless there is a problem to report.
        let problem = result.error != nil || !result.skippedLayouts.isEmpty
        if !quiet { NSApp.activate(ignoringOtherApps: true) }
        var lines: [String] = []
        if options.deleteHiddenSlides { lines.append(String(format: L("resultSlides"), result.deletedSlides)) }
        if options.removeTransitions { lines.append(String(format: L("resultTransitions"), result.removedTransitions)) }
        if options.removeBuilds { lines.append(String(format: L("resultBuilds"), result.removedBuilds, result.buildSlides)) }
        if options.deleteUnusedLayouts {
            lines.append(String(format: L("resultLayouts"), result.deletedLayouts.count) + (result.deletedLayouts.isEmpty ? "" : L("listColon") + result.deletedLayouts.reversed().joined(separator: L("listSeparator"))))
        }
        if !result.skippedLayouts.isEmpty { lines.append(L("resultSkipped") + result.skippedLayouts.reversed().joined(separator: L("listSeparator"))) }
        if let error = result.error { lines.append(error.localizedDescription) }
        details = lines.joined(separator: "\n")
        showAutomationHelp = result.error == .automationDenied
        showAccessibilityHelp = result.error == .accessibilityDenied
        let changed = result.deletedSlides > 0 || result.removedTransitions > 0 || result.removedBuilds > 0 || !result.deletedLayouts.isEmpty
        let key: String
        if cancelled || result.error == .interrupted { key = "cancelled" }
        else if result.error == nil && result.skippedLayouts.isEmpty { key = "success" }
        else { key = changed ? "partial" : "failed" }
        refresh()
        status = L(key)
        if quiet && problem { onQuietProblem?() }
    }

    func cancel() { sweeper?.cancel(); status = L("cancelling") }
}

struct MainView: View {
    @ObservedObject var model: Model
    @State private var targeted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    heading("01", L("target"))
                    Spacer()
                    Button(L("refresh")) { model.refresh(clearStatus: true) }.disabled(model.busy).help(L("refreshHint"))
                }
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 22, weight: .light)).foregroundColor(.secondary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.snapshot?.documentName ?? L("noTarget")).font(.headline).lineLimit(1).truncationMode(.middle)
                            .help(model.targetFile?.path ?? "")
                        if let snapshot = model.snapshot {
                            Text(String(format: L("summary"), snapshot.skipped.count, snapshot.layouts.count)).font(.caption).foregroundColor(.secondary).monospacedDigit()
                        }
                        Text(model.targetFile == nil ? L("frontMode") : L("fileMode")).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if model.targetFile != nil {
                        Button(L("useFront")) { model.useFrontDocument() }.disabled(model.busy)
                    } else {
                        Button(L("chooseFile")) { model.chooseFile() }.disabled(model.busy)
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(targeted ? Color.accentColor : Color.gray.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                .accessibilityElement(children: .contain).accessibilityLabel(L("dropHint"))
                hint(L("dropHint"))
            }
            VStack(alignment: .leading, spacing: 10) {
                heading("02", L("items"))
                Toggle(isOn: $model.deleteLayouts) {
                    Text(L("deleteLayouts")) + Text(model.snapshot == nil ? "" : String(format: L("countLayouts"), model.unusedLayouts.count)).foregroundColor(.secondary)
                }
                if model.deleteLayouts && !model.unusedLayouts.isEmpty {
                    // A ScrollView has no height of its own here and collapsed to nothing; two lines plus a tooltip instead.
                    let names = model.unusedLayouts.joined(separator: L("listSeparator"))
                    Text(names).font(.caption).foregroundColor(.secondary).lineLimit(2).truncationMode(.tail).help(names)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 20)
                }
                Toggle(isOn: $model.deleteHidden) {
                    Text(L("deleteHidden")) + Text(model.snapshot == nil ? "" : String(format: L("countSlides"), model.hiddenCount)).foregroundColor(.secondary)
                }
                Toggle(isOn: $model.removeTransitions) {
                    Text(L("removeTransitions")) + Text(model.snapshot == nil ? "" : String(format: L("countSlides"), model.transitionCount)).foregroundColor(.secondary)
                }
                Toggle(L("removeBuilds"), isOn: $model.removeBuilds)
                hint(L("itemsHint"))
            }.disabled(model.busy)
            Spacer(minLength: 0)
            Divider()
            if !model.details.isEmpty {
                ScrollView { Text(model.details).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 60)
            }
            HStack(spacing: 12) {
                if model.busy { ProgressView().controlSize(.small) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.status.isEmpty ? (model.snapshot == nil ? L("ready") : model.canRun ? L("readyToRun") : L("nothingHere")) : model.status).font(.callout).lineLimit(2).textSelection(.enabled)
                    if !model.progress.isEmpty { Text(model.progress).font(.caption).foregroundColor(.secondary).monospacedDigit() }
                }
                Spacer()
                if model.showAutomationHelp { Button(L("permOpen")) { KeynoteDOM.openAutomationSettings() } }
                if model.showAccessibilityHelp { Button(AccessibilityText.text("open")) { openAccessibilitySettings() } }
                if model.busy { Button(L("cancel")) { model.cancel() }.keyboardShortcut(.cancelAction) }
                Button(L("run")) { model.start() }.keyboardShortcut(.return, modifiers: .command).buttonStyle(.borderedProminent).controlSize(.large).disabled(!model.canRun)
            }
        }.padding(24)
        // The content's own height is the minimum; a fixed minHeight here hid how tall it really is and the rows got clipped.
        .fixedSize(horizontal: false, vertical: true)
        .frame(minWidth: 520, maxHeight: .infinity, alignment: .top).background(Color(nsColor: AppSurface.color)).tint(Color(red: 0.55, green: 0.38, blue: 0.04))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
        // The whole window accepts a dropped .key file.
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
            guard !model.busy else { return false }
            let group = DispatchGroup(); var urls: [URL] = []; let lock = NSLock()
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { lock.lock(); urls.append(url); lock.unlock() }; group.leave() }
            }
            group.notify(queue: .main) { model.open(urls) }
            return true
        }
    }
    func heading(_ number: String, _ title: String) -> some View {
        HStack(spacing: 8) { Text(number).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.secondary).accessibilityHidden(true); Text(title).font(.system(size: 14, weight: .semibold)) }
    }
    func hint(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Grows its window when the content needs more room (a saved or earlier frame can be too small);
/// `.minSize` alone only stops further shrinking. Never shrinks the window.
final class GrowingHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()
        guard let window else { return }
        let needed = fittingSize, current = window.contentLayoutRect.size
        guard needed.height > current.height + 0.5 || needed.width > current.width + 0.5 else { return }
        DispatchQueue.main.async {
            window.setContentSize(NSSize(width: max(current.width, needed.width), height: max(current.height, needed.height)))
        }
    }
}

func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
}

/// Settings group content: Automation permission for Keynote, re-checked on activation.
struct KeynotePermissionView: View {
    @State private var permission = KeynoteDOM.Permission.unknown
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color).accessibilityHidden(true)
                Text(label)
            }
            Text(L("permissionWhy")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("permAsk")) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let result = KeynoteDOM.permission(ask: true)
                        DispatchQueue.main.async { permission = result }
                    }
                }
                Button(L("permOpen")) { KeynoteDOM.openAutomationSettings() }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }
    private func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let result = KeynoteDOM.permission(ask: false)
            DispatchQueue.main.async { permission = result }
        }
    }
    private var label: String { permission == .allowed ? L("permAllowed") : permission == .denied ? L("permDenied") : L("permUnknown") }
    private var icon: String { permission == .allowed ? "checkmark.circle.fill" : permission == .denied ? "xmark.octagon.fill" : "questionmark.circle" }
    private var color: Color { permission == .allowed ? .green : permission == .denied ? .red : .secondary }
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
            SettingsSection(AccessibilityText.text("title")) { AccessibilityPermissionView(required: true, showsTitle: false) }
            SettingsSection(L("permission")) { KeynotePermissionView() }
        }))]).frame(minWidth: 560, maxWidth: .infinity, minHeight: 680, maxHeight: .infinity)
    }
}

/// Keynote › Services items (Info.plist NSServices, shown only while Keynote is active).
/// Keynote waits for the reply, so the work starts after returning; otherwise our Apple Events to Keynote would deadlock.
@MainActor final class ServiceProvider: NSObject {
    weak var delegate: Delegate?
    init(delegate: Delegate) { self.delegate = delegate }
    @objc func deleteUnusedMasters(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        DispatchQueue.main.async { self.delegate?.runService(deleteLayouts: true, deleteHidden: false) }
    }
    @objc func deleteHiddenSlides(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        DispatchQueue.main.async { self.delegate?.runService(deleteLayouts: false, deleteHidden: true) }
    }
    @objc func removeTransitions(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        DispatchQueue.main.async { self.delegate?.runService(removeTransitions: true) }
    }
    @objc func removeBuilds(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        DispatchQueue.main.async { self.delegate?.runService(removeBuilds: true) }
    }
    @objc func removeAllAnimations(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        DispatchQueue.main.async { self.delegate?.runService(removeTransitions: true, removeBuilds: true) }
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var isDuplicate = false
    var pendingFiles: [URL] = []
    var services: ServiceProvider?
    var launched = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["resident": true])
        AccessibilityText.neededOverride = [
            "Keynoteの［スライドレイアウトを編集］を操作して、使用されていないマスターを削除するために使います。未許可の場合、マスターの削除は利用できません（非表示のスライドの削除は使えます）。",
            "Used to operate Keynote's Edit Slide Layouts view and delete unused masters. Without it, masters cannot be deleted (deleting hidden slides still works).",
            "用于操作 Keynote 的“编辑幻灯片布局”并删除未使用的母版。未获授权时无法删除母版（仍可删除隐藏的幻灯片）。",
            "Keynote의 슬라이드 레이아웃 편집 화면을 조작하여 사용하지 않는 마스터를 삭제하는 데 사용합니다. 권한이 없으면 마스터를 삭제할 수 없습니다(숨긴 슬라이드 삭제는 사용 가능).",
        ]
        if let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            isDuplicate = true
            other.activate(options: [.activateAllWindows])
            let urls = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !urls.isEmpty, let app = other.bundleURL { NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicate else { return }
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "KeynoteSweeper"; window.titleVisibility = .hidden
        // The window's minimum follows the SwiftUI content, so rows never get clipped when the result area appears.
        let host = GrowingHostingView(rootView: MainView(model: model))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.delegate = self; window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width: 520, height: 420)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        model.onQuietProblem = { [weak self] in self?.show() }
        MenuBarPresence.shared.install(name: "KeynoteSweeper", symbol: "sparkles.rectangle.stack", show: { [weak self] in self?.show() }, settings: { [weak self] in self?.showSettings() }, help: { [weak self] in self?.showHelp() })
        services = ServiceProvider(delegate: self)
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
        launched = true
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !pendingFiles.isEmpty { show(); model.open(pendingFiles); pendingFiles = [] }
        else if !login && !StartupWindow.hidden { show() }
    }
    func application(_ sender: NSApplication, open urls: [URL]) {
        if isDuplicate, let id = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }), let app = other.bundleURL {
            NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()); return
        }
        // Files handed over at launch arrive before the window exists.
        guard launched else { pendingFiles += urls; return }
        show(); model.open(urls)
    }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps: true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil)
        // Read after the window is on screen: the first Apple Event can wait on the Automation prompt.
        DispatchQueue.main.async { self.model.refresh() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { show(); return true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey: "resident") { NSApp.terminate(nil); return false }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = L("working"); alert.informativeText = L("quitBusy"); alert.addButton(withTitle: L("ok")); alert.runModal()
        show(); return .terminateCancel
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func refresh() { show(); model.refresh(clearStatus: true) }
    /// Services always work on Keynote's front presentation, where the user just chose the item.
    func runService(deleteLayouts: Bool = false, deleteHidden: Bool = false, removeTransitions: Bool = false, removeBuilds: Bool = false) {
        guard !model.busy else { show(); return }
        model.useFrontDocument()
        // Runs without confirmation and without the window; show it only if the run could not start.
        let request = SweepOptions(deleteUnusedLayouts: deleteLayouts, deleteHiddenSlides: deleteHidden, removeTransitions: removeTransitions, removeBuilds: removeBuilds)
        if !model.start(request, quiet: true) { show() }
    }
    @objc func chooseFile() { show(); model.chooseFile() }
    @objc func showSettings() {
        if settings == nil {
            settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 680), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            // Resizable from the designed size upward; the hosting view reports only its minimum.
            let hosting = NSHostingView(rootView: SettingsView()); hosting.sizingOptions = [.minSize]
            settings!.title = L("settingsWindow"); settings!.contentView = hosting; settings!.contentMinSize = NSSize(width: 560, height: 680); settings!.isReleasedWhenClosed = false; settings!.center()
        }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource: "Help", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle: L("help"), text: text, heading: "KeynoteSweeper")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func about() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "KeynoteSweeper", .applicationVersion: version, .credits: NSAttributedString(string: L("aboutDetail"))])
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
        add(file, L("chooseFile"), #selector(chooseFile), "o")
        add(file, L("refresh"), #selector(refresh), "r"); file.addItem(.separator())
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
