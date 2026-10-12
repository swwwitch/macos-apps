import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var store = HotkeyStore.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 10) {
                Picker("", selection: Binding(get: { store.target }, set: { store.selectTarget($0) })) {
                    Text(HotkeyScanners.allApps).tag(HotkeyStore.Target.allApps)
                    Text(L("アプリを指定")).tag(HotkeyStore.Target.specified)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .help(L("アプリを指定：そのアプリのメニューと、そのアプリで効くものだけを照合します"))
                if store.target == .specified { AppChooser() }
            }
            .padding(.bottom, 10)
            LookupView()
                .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        .onAppear { if store.loadedAt == nil { store.reload() } }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                .frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("ホットキーの使用元を調べる"))
                    .font(.title2.weight(.semibold))
                Text(L("キーを押すと、そのキーを設定しているアプリを一覧表示"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { SettingsWindow.shared.show() } label: {
                Label(L("設定"), systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if store.isLoading {
                ProgressView().controlSize(.small)
                Text(L("読み込み中…")).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(store.message ?? summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(L("読み直す")) { store.reload() }
                .disabled(store.isLoading)
                .keyboardShortcut("r", modifiers: .command)
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var summary: String {
        guard let date = store.loadedAt else { return "" }
        let time = date.formatted(date: .omitted, time: .shortened)
        return L("%@件を照合（%@に読み込み）", String(store.allEntries.count), time)
    }
}

// MARK: - 対象のアプリ

/// 「アプリを指定」のときのアプリ選択（起動中のアプリ＋その他…）
private struct AppChooser: View {
    @ObservedObject private var store = HotkeyStore.shared
    private static let otherTag = "\u{0}other"

    var body: some View {
        Picker("", selection: Binding(get: { store.chosenApp?.bundleID ?? "" }, set: choose)) {
            if store.chosenApp == nil { Text(L("アプリを選択")).tag("") }
            ForEach(apps, id: \.bundleID) { app in
                Label { Text(app.name) } icon: { Image(nsImage: icon(app.bundleID)) }.tag(app.bundleID)
            }
            Divider()
            Text(L("その他…")).tag(Self.otherTag)
        }
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel(L("照合するアプリ"))
    }

    /// 起動中の通常のアプリ（自分を除く）。指定中のアプリが終了していても残す
    private var apps: [HotkeyStore.ChosenApp] {
        let me = Bundle.main.bundleIdentifier
        var list = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != me }
            .compactMap { HotkeyStore.ChosenApp($0) }
        if let chosen = store.chosenApp, !list.contains(where: { $0.bundleID == chosen.bundleID }) { list.append(chosen) }
        var seen = Set<String>()
        return list.filter { seen.insert($0.bundleID).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func icon(_ bundleID: String) -> NSImage {
        let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage()
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    private func choose(_ tag: String) {
        guard tag == Self.otherTag else {
            if !tag.isEmpty { store.chosenApp = HotkeyStore.ChosenApp(bundleID: tag, name: apps.first { $0.bundleID == tag }?.name) }
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = L("照合するアプリを選んでください（起動していないアプリはメニューを照合しません）")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        store.chosenApp = HotkeyStore.ChosenApp(bundleID: id, name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
    }
}

// MARK: - キーで調べる

private struct LookupView: View {
    @ObservedObject private var store = HotkeyStore.shared
    @AppStorage("lookup.hideInactive") private var hideInactive = false

    var body: some View {
        VStack(spacing: 10) {
            recorder
            if store.combo != nil && !store.isRecording {
                results
            } else {
                hint
            }
        }
    }

    private var recorder: some View {
        Button {
            store.isRecording ? store.cancelRecording() : store.startRecording()
        } label: {
            VStack(spacing: 4) {
                if store.isRecording {
                    Text(L("キーを押してください")).font(.title3.weight(.semibold))
                    Text(L("Escで取り消し")).font(.caption).foregroundStyle(.secondary)
                } else if let combo = store.combo {
                    Text(combo.display).font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text(L("クリックして別のキーを調べる")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(L("クリックしてキーを押す")).font(.title3.weight(.semibold))
                    Text(L("押したキーはほかのアプリに渡しません")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(store.isRecording ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(store.isRecording ? Color.accentColor : Color.secondary.opacity(0.3),
                                  style: StrokeStyle(lineWidth: store.isRecording ? 2 : 1, dash: store.isRecording ? [6, 4] : []))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.combo.map { L("調べるキー：%@", $0.display) } ?? L("クリックしてキーを押す"))
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !KeyRecorderStatus.trusted {
                Label(L("アクセシビリティが未許可のため、ほかのアプリが先に受け取るキーは記録できません。設定から許可してください。"),
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                Button(L("設定を開く")) { SettingsWindow.shared.show() }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var results: some View {
        let matches = store.matches
        let effective = matches.filter(store.isEffective)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                    Text(L("照合中…"))
                } else if matches.isEmpty {
                    Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                    Text(L("設定ファイル・メニューには見つかりませんでした"))
                } else {
                    // 有効なものが複数＝競合、1件＝原因が特定できた、0件＝どれも今は効いていない
                    Image(systemName: effective.count > 1 ? "exclamationmark.triangle.fill" : effective.count == 1 ? "checkmark.circle.fill" : "minus.circle")
                        .foregroundStyle(effective.count > 1 ? Color.orange : effective.count == 1 ? Color.green : Color.secondary)
                    Text(L("%@件（有効なもの %@件）", String(matches.count), String(effective.count)))
                }
                Spacer()
                Toggle(L("無効なホットキーを非表示"), isOn: $hideInactive)
                    .toggleStyle(.checkbox)
                    .font(.body)
                    .help(L("設定でオフのもの・定義元のアプリが停止中のものを隠します"))
            }
            .font(.headline)
            List {
                if store.reserved {
                    Section {
                        Label(L("システム（またはほかのアプリ）がこのキーを専有しています。macOSのホットキーやSpotlightなどを確認してください。"),
                              systemImage: "lock.fill")
                    }
                }
                Section {
                    ForEach(hideInactive ? effective : matches) { EntryRow(entry: $0) }
                }
                if !store.interceptors.isEmpty {
                    Section(L("キー入力を横取りできるアプリ（設定ファイルを読めないアプリの候補）")) {
                        ForEach(store.interceptors) { InterceptorRow(info: $0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

enum KeyRecorderStatus {
    static var trusted: Bool { AXIsProcessTrusted() }
}

// MARK: - 行

private struct EntryRow: View {
    let entry: HotkeyEntry
    @ObservedObject private var store = HotkeyStore.shared

    var body: some View {
        let effective = store.isEffective(entry)
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: IconCache.icon(for: entry))
                .resizable()
                .frame(width: 28, height: 28)
                .opacity(effective ? 1 : 0.45)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.title).font(.headline).lineLimit(1)
                    ForEach(badges(effective: effective), id: \.self) { badge in
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.18)))
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if let note = entry.note {
                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .opacity(effective ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(L("内容をコピー")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString([entry.combo.display, entry.title, subtitle].joined(separator: "\t"), forType: .string)
            }
            if let url = sourceAppURL {
                Button(L("%@を開く", FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))) {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                }
            }
        }
    }

    private var subtitle: String {
        [entry.source.title, entry.group, entry.scope].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func badges(effective: Bool) -> [String] {
        var list: [String] = []
        if !entry.isEnabled { list.append(L("無効")) }
        if entry.isEnabled && entry.isRunning == false { list.append(L("停止中")) }
        if entry.allowsExtraModifiers { list.append(L("修飾キー追加でも反応")) }
        return list
    }

    private var sourceAppURL: URL? {
        let ids = entry.source.isPerApp ? [entry.ownerBundleID].compactMap { $0 } : entry.source.bundleIDs
        return ids.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
    }
}

private struct InterceptorRow: View {
    let info: InterceptorInfo
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSRunningApplication(processIdentifier: info.id)?.icon ?? NSImage())
                .resizable().frame(width: 22, height: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.name)
                Text(info.canModify ? L("キーを止めたり書き換えたりできる") : L("キーを監視しているだけ"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

@MainActor
enum IconCache {
    private static var cache: [String: NSImage] = [:]
    static func icon(for entry: HotkeyEntry) -> NSImage {
        let key = entry.source == .menus ? "pid:\(entry.ownerPID ?? 0)" : "source:\(entry.source.rawValue)"
        if let image = cache[key] { return image }
        let image: NSImage
        if entry.source == .menus, let pid = entry.ownerPID, let icon = NSRunningApplication(processIdentifier: pid)?.icon {
            image = icon
        } else {
            image = entry.source.icon
        }
        cache[key] = image
        return image
    }
}

// Main-window header uses the same icon resource as the distributed app.
@MainActor private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
