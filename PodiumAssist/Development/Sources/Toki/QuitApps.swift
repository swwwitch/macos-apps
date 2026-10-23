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

/// Selections belong only to this application of the preset; stored lists are unchanged.
struct PresetAppConfirmation: View {
    let preset: Preset
    let cancel: () -> Void
    let apply: (Preset) -> Void
    @State private var skippedLaunch: Set<String> = []
    @State private var skippedQuit: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("プリセットの切り換えを確認")).font(.headline)
            Text(preset.name).font(.title3).fontWeight(.semibold)
            Text(L("チェックしたアプリだけを起動・終了します。今回の選択はプリセットに保存されません。"))
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    appSection(L("起動するアプリ"), targets: preset.launchApps ?? [], skipped: $skippedLaunch)
                    appSection(L("終了するアプリ"), targets: Self.selection(preset, skippedLaunch: [], skippedQuit: []).quitAppTargets ?? [], skipped: $skippedQuit)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(L("終了時に未保存の書類がある場合は、各アプリの確認画面で操作してください。"))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(L("キャンセル"), action: cancel).keyboardShortcut(.cancelAction)
                Button(L("切り換える")) {
                    apply(Self.selection(preset, skippedLaunch: skippedLaunch, skippedQuit: skippedQuit))
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 460, height: 460)
    }

    static func selection(_ preset: Preset, skippedLaunch: Set<String>, skippedQuit: Set<String>) -> Preset {
        var selected = preset
        selected.launchApps = (preset.launchApps ?? []).filter { !skippedLaunch.contains($0.id) }
        let protected = Set((preset.launchApps ?? []).map(\.id))
        selected.quitAppTargets = (preset.quitAppTargets ?? []).filter {
            !skippedQuit.contains($0.id) && !protected.contains($0.id)
        }
        return selected
    }

    private func appSection(_ title: String, targets: [QuitAppTarget], skipped: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !targets.isEmpty {
                Text(title).font(.subheadline).fontWeight(.semibold)
                ForEach(targets) { target in
                    Toggle(isOn: Binding(get: { !skipped.wrappedValue.contains(target.id) }, set: { checked in
                        if checked { skipped.wrappedValue.remove(target.id) }
                        else { skipped.wrappedValue.insert(target.id) }
                    })) {
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: target.path))
                                .resizable().frame(width: 24, height: 24)
                            Text(target.name)
                        }
                    }.toggleStyle(.checkbox)
                }
            }
        }
    }
}

struct PresetAppsSettings: View {
    @ObservedObject var presets: PresetStore
    @State private var selectedID: UUID?
    @State private var editingLaunch: Bool?
    private var selected: Preset? { presets.items.first { $0.id == selectedID } ?? presets.items.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if presets.items.isEmpty {
                Text(L("「基本設定」タブの「プリセットに保存…」で作れます。"))
            } else {
                Picker(L("プリセット名"), selection: Binding(get: { selected?.id }, set: { selectedID = $0 })) {
                    ForEach(presets.items) { Text($0.name).tag(Optional($0.id)) }
                }
                if let preset = selected {
                    SettingsSection(L("起動するアプリ")) { list(preset.launchApps ?? [], launch: true) }
                    SettingsSection(L("終了するアプリ")) { list(preset.quitAppTargets ?? [], launch: false) }
                }
            }
        }
        .sheet(isPresented: Binding(get: { editingLaunch != nil }, set: { if !$0 { editingLaunch = nil } })) {
            if let launch = editingLaunch, let preset = selected {
                PresetAppListEditor(title: L(launch ? "起動アプリを編集…" : "終了アプリを編集…"),
                    targets: Binding(get: {
                        guard let current = presets.items.first(where: { $0.id == preset.id }) else { return [] }
                        return (launch ? current.launchApps : current.quitAppTargets) ?? []
                    }, set: { targets in
                        guard var current = presets.items.first(where: { $0.id == preset.id }) else { return }
                        if launch { current.launchApps = targets } else { current.quitAppTargets = targets }
                        presets.save(current)
                    }), done: { editingLaunch = nil })
            }
        }
    }

    private func list(_ targets: [QuitAppTarget], launch: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if targets.isEmpty { Text(L("未設定")).foregroundStyle(.secondary) }
            ForEach(targets) { target in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: target.path)).resizable().frame(width: 20, height: 20)
                    Text(target.name)
                }.help(target.path)
            }
            Button(L(launch ? "起動アプリを編集…" : "終了アプリを編集…")) { editingLaunch = launch }
        }
    }
}
