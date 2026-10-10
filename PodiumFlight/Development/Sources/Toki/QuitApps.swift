import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct QuitAppTarget: Codable, Identifiable {
    var id: String
    var name: String
    var path: String
}

@MainActor
final class QuitAppsStore: ObservableObject {
    static let shared = QuitAppsStore()
    @Published var targets: [QuitAppTarget] = []
    @Published var status = ""
    @Published var busy = false
    private let key = "quitAppTargets"
    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([QuitAppTarget].self, from: data) {
            targets = saved
        } else {
            for folder in ["/Applications", NSHomeDirectory() + "/Applications"] {
                let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? []
                for url in urls where ["clipeye.app", "dropbox.app"].contains(url.lastPathComponent.lowercased()) { add(url) }
            }
            persist()
        }
    }
    func persist() {
        if let data = try? JSONEncoder().encode(targets) { UserDefaults.standard.set(data, forKey: key) }
    }
    func add(_ url: URL) {
        guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
        guard !targets.contains(where: { $0.id == id }) else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        targets.append(QuitAppTarget(id: id, name: name, path: url.path)); persist()
    }
    func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            MainActor.assumeIsolated {
                if response == .OK { panel.urls.forEach { self.add($0) } }
            }
        }
    }
    func remove(_ id: String) { targets.removeAll { $0.id == id }; persist() }
    func quit(_ selected: [QuitAppTarget]? = nil, excluding: Set<String> = []) {
        guard !busy else { return }
        let running = (selected ?? targets).filter { !excluding.contains($0.id) }.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0.id) }
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
        guard !running.isEmpty else { status = L("終了対象のアプリは起動していません。"); return }
        busy = true
        status = L("アプリに終了を要求しています…")
        for app in running { _ = app.terminate() }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let remaining = running.filter { !$0.isTerminated }.compactMap(\.localizedName)
            status = remaining.isEmpty ? L("対象アプリを終了しました。") : L("終了待ち: %@", remaining.joined(separator: ", "))
            busy = false
        }
    }
}

struct QuitAppsPreferences: View {
    @ObservedObject private var store = QuitAppsStore.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("指定アプリを終了する")).font(.title2.bold())
            Text(L("手動操作用の一覧です。プリセットの対象はプリセット画面で編集します。"))
                .font(.caption).foregroundStyle(.secondary)
            List {
                ForEach(store.targets) { target in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: target.path)).resizable().frame(width: 24, height: 24)
                        Text(target.name).lineLimit(1)
                        Spacer()
                        Button(L("削除")) { store.remove(target.id) }
                    }
                }
            }
            Button(L("アプリを追加…")) { store.choose() }
            Text(L("未保存の書類がある場合は、対象アプリの確認画面で保存してください。強制終了はしません。"))
                .font(.caption).foregroundStyle(.secondary)
            Text(store.status).font(.caption).foregroundStyle(.secondary)
            Button(L("指定アプリを終了する")) { store.quit() }
                .disabled(store.targets.isEmpty || store.busy)
        }.padding(20)
    }
}


struct PresetAppListEditor: View {
    let title: String
    @Binding var targets: [QuitAppTarget]
    let done: () -> Void
    /// The list as it was when the sheet opened; Cancel (Esc) puts it back.
    @State private var original: [QuitAppTarget]?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            Text(L("このプリセット専用の一覧です。編集後はプリセットを保存してください。"))
                .font(.caption).foregroundStyle(.secondary)
            List {
                ForEach(targets) { target in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: target.path)).resizable().frame(width: 24, height: 24)
                        Text(target.name).lineLimit(1)
                        Spacer()
                        Button(L("削除")) { targets.removeAll { $0.id == target.id } }
                    }
                }
            }
            HStack {
                Button(L("アプリを追加…")) { choose() }
                Spacer()
                Button(L("キャンセル")) { if let original { targets = original }; done() }.keyboardShortcut(.cancelAction)
                Button(L("完了"), action: done).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 380, height: 420)
        .onAppear { if original == nil { original = targets } }
    }
    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            MainActor.assumeIsolated {
                guard response == .OK else { return }
                for url in panel.urls {
                    guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                          id != Bundle.main.bundleIdentifier, !targets.contains(where: { $0.id == id }) else { continue }
                    let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                        ?? url.deletingPathExtension().lastPathComponent
                    targets.append(QuitAppTarget(id: id, name: name, path: url.path))
                }
            }
        }
    }
}
