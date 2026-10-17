import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Canonical source: Shared/ExcludedApps/ExcludedApps.swift (copied by Shared/ExcludedApps/sync.py).
/// The shared 「対象外アプリ」 list (B21): apps this app never acts on, identified by Bundle ID.
/// Per Mac: the key is never exported or synced. Each app sets its explanation and first-launch list with configure().
@MainActor
final class ExcludedApps: ObservableObject {
    static let shared = ExcludedApps()
    static let key = "excludedBundleIDs"
    static var title: String { StartupWindow.text("対象外アプリ", "Excluded Apps", "排除的应用", "제외할 앱") }

    @Published private(set) var ids: [String] = []
    @Published fileprivate(set) var rejected: [String] = []
    /// What being excluded means in this app, already localized.
    private(set) var explanation = ""
    /// Called after the list changed (re-register hotkeys, refresh menus).
    var onChange: (() -> Void)?
    private let defaults = UserDefaults.standard
    private var ownID: String? { Bundle.main.bundleIdentifier }

    /// legacyKeys: keys older versions used ("excluded", "excludedApps"); their list is carried over once.
    func configure(explanation: String, initial: [String] = [], legacyKeys: [String] = []) {
        self.explanation = explanation
        if defaults.object(forKey: Self.key) == nil,
           let old = legacyKeys.lazy.compactMap({ self.defaults.stringArray(forKey: $0) }).first {
            defaults.set(old, forKey: Self.key)
        }
        ids = defaults.stringArray(forKey: Self.key) ?? initial
    }

    /// Bundle IDs compare case-insensitively, as Launch Services does.
    private static func same(_ a: String?, _ b: String) -> Bool { a?.caseInsensitiveCompare(b) == .orderedSame }
    func excludes(_ bundleID: String?) -> Bool { ids.contains { Self.same(bundleID, $0) } }

    /// Global hotkeys stay unregistered while the front app is excluded or this app itself,
    /// so the keystroke reaches that app. An unknown front app (nil) keeps them registered.
    func blocksHotkeys(bundleID: String?, pid: Int32?) -> Bool {
        if let pid, pid == ProcessInfo.processInfo.processIdentifier { return true }
        if let ownID, Self.same(bundleID, ownID) { return true }
        return excludes(bundleID)
    }
    /// The front app right now, checked again just before acting.
    var frontAppExcluded: Bool {
        let app = NSWorkspace.shared.frontmostApplication
        return blocksHotkeys(bundleID: app?.bundleIdentifier, pid: app?.processIdentifier)
    }

    func add(_ urls: [URL]) {
        var messages: [String] = []
        for url in urls {
            let name = Self.displayName(url)
            guard let id = Bundle(url: url)?.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                messages.append(String(format: StartupWindow.text("%@ のBundle IDを読み取れませんでした。", "Could not read the Bundle ID of %@.",
                                                                  "无法读取 %@ 的 Bundle ID。", "%@의 Bundle ID를 읽을 수 없습니다."), name)); continue
            }
            if let ownID, Self.same(id, ownID) {
                messages.append(String(format: StartupWindow.text("%@自身は追加できません。", "%@ itself cannot be added.",
                                                                  "不能添加 %@ 本身。", "%@ 자체는 추가할 수 없습니다."), name)); continue
            }
            if excludes(id) {
                messages.append(String(format: StartupWindow.text("%@ はすでに登録されています。", "%@ is already in the list.",
                                                                  "%@ 已在列表中。", "%@은(는) 이미 목록에 있습니다."), name)); continue
            }
            ids.append(id)
        }
        rejected = messages
        save()
    }
    func remove(_ selection: Set<String>) {
        ids.removeAll { id in selection.contains { Self.same(id, $0) } }
        rejected = []
        save()
    }
    /// 「初期値に戻す」: replaces the list with the app's first-launch list and runs onChange.
    func reset(to initial: [String]) {
        ids = initial
        rejected = []
        save()
    }
    private func save() {
        defaults.set(ids, forKey: Self.key)
        onChange?()
    }

    static func displayName(_ url: URL) -> String {
        FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
    static func info(_ bundleID: String) -> (name: String, icon: NSImage, missing: Bool) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return (displayName(url), NSWorkspace.shared.icon(forFile: url.path), false)
        }
        return (bundleID, NSWorkspace.shared.icon(for: .applicationBundle), true)
    }

    /// AppKit settings page (SettingsUI.tabs).
    func page() -> NSView { SettingsHostingPage(observing: self) { ExcludedAppsView() } }
}

/// Contents of the 「対象外アプリ」 tab: SettingsSection(ExcludedApps.title) { ExcludedAppsView() }
struct ExcludedAppsView: View {
    @ObservedObject private var store = ExcludedApps.shared
    @State private var selection = Set<String>()
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.explanation.isEmpty { Text(store.explanation).fixedSize(horizontal: false, vertical: true) }
            List(selection: $selection) {
                ForEach(store.ids, id: \.self) { id in
                    let info = ExcludedApps.info(id)
                    HStack(spacing: 8) {
                        Image(nsImage: info.icon).resizable().frame(width: 24, height: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(info.name).lineLimit(1)
                            Text(info.missing ? StartupWindow.text("このMacにありません", "Not on this Mac", "此 Mac 上没有", "이 Mac에 없음") : id)
                                .font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .help(id)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(info.name + ", " + id)
                }
            }
            .frame(height: 200)
            .accessibilityLabel(ExcludedApps.title)
            HStack {
                Button(StartupWindow.text("追加…", "Add…", "添加…", "추가…")) { add() }
                Button(StartupWindow.text("削除", "Remove", "移除", "제거")) { store.remove(selection); selection = [] }.disabled(selection.isEmpty)
            }
            Text(store.ids.isEmpty
                 ? StartupWindow.text("対象外アプリはありません。", "No excluded apps.", "没有排除的应用。", "제외할 앱이 없습니다.")
                 : String(format: StartupWindow.text("%@個のアプリを対象外にしています。", "%@ apps are excluded.", "已排除 %@ 个应用。", "%@개의 앱을 제외하고 있습니다."), String(store.ids.count)))
                .font(.caption).foregroundColor(.secondary)
            if !store.rejected.isEmpty {
                Text(store.rejected.joined(separator: "\n")).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func add() {
        let picker = NSOpenPanel()
        picker.title = StartupWindow.text("対象外にするアプリを選択", "Choose Apps to Exclude", "选择要排除的应用", "제외할 앱 선택")
        picker.prompt = StartupWindow.text("追加", "Add", "添加", "추가")
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            MainActor.assumeIsolated { store.add(picker.urls) }
        }
        if let window = NSApp.keyWindow { picker.beginSheetModal(for: window, completionHandler: completion) }
        else { picker.begin(completionHandler: completion) }
    }
}
