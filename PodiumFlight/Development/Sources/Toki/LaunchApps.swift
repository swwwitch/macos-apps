import AppKit
import SwiftUI
import UniformTypeIdentifiers


@MainActor
final class LaunchAppsStore: ObservableObject {
    static let shared = LaunchAppsStore()
    @Published var targets: [QuitAppTarget] = []
    @Published var status = ""
    @Published var busy = false
    private let key = "launchAppTargets"
    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([QuitAppTarget].self, from: data) {
            targets = saved
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
    func launch(_ selected: [QuitAppTarget]? = nil) {
        guard !busy else { return }
        let apps = selected ?? targets
        guard !apps.isEmpty else { status = L("起動するアプリを追加してください。"); return }
        busy = true
        status = L("アプリを起動しています…")
        Task { @MainActor in
            var failures: [String] = []
            for target in apps {
                if NSRunningApplication.runningApplications(withBundleIdentifier: target.id).contains(where: { !$0.isTerminated }) { continue }
                let storedURL = URL(fileURLWithPath: target.path)
                let url = Bundle(url: storedURL)?.bundleIdentifier == target.id ? storedURL : NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.id)
                guard let url else { failures.append(target.name); continue }
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false
                do { _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config) }
                catch { failures.append(target.name) }
            }
            status = failures.isEmpty ? L("指定アプリは起動済みです。") : L("起動できませんでした: %@", failures.joined(separator: ", "))
            busy = false
        }
    }
}

struct LaunchAppsPreferences: View {
    @ObservedObject private var store = LaunchAppsStore.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("指定アプリを起動する")).font(.title2.bold())
            Text(L("起動するアプリを追加・削除できます。登録だけでは起動しません。"))
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
            Text(L("手動操作用の一覧です。プリセットの対象はプリセット画面で編集します。"))
                .font(.caption).foregroundStyle(.secondary)
            Text(store.status).font(.caption).foregroundStyle(.secondary)
            Button(L("指定アプリを起動する")) { store.launch() }
                .disabled(store.targets.isEmpty || store.busy)
        }.padding(20)
    }
}
