import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var mirror = Mirror.shared
    @ObservedObject private var login = Login.shared
    @State private var isTargeted = false
    @State private var filter = LogFilter.all
    @State private var selection = Set<Int>()
    @FocusState private var urlFocused: Bool

    private var shownRows: [LogRow] {
        guard let state = filter.state else { return mirror.rows }
        return mirror.rows.filter { $0.state == state }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            form
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            log
                .padding(.top, 10)
                .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        .onAppear {
            urlFocused = mirror.urlText.isEmpty
            login.refresh()
        }
        // ブラウザーのアドレスバーやリンクのドロップで URL を入れる
        .onDrop(of: [.url, .plainText], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url, !url.isFileURL { DispatchQueue.main.async { Mirror.shared.urlText = url.absoluteString } }
                }
            } else {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    if let text { DispatchQueue.main.async { Mirror.shared.urlText = text.trimmingCharacters(in: .whitespacesAndNewlines) } }
                }
            }
            return true
        }
        .alert(mirror.message?.title ?? "", isPresented: Binding(
            get: { mirror.message != nil }, set: { if !$0 { mirror.message = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(mirror.message?.body ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                .frame(width: 36, height: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L("Webサイトをまるごと保存"))
                        .font(.headline)
                    Text(appVersionText().replacingOccurrences(of: "\n", with: " "))
                        .font(.caption).foregroundStyle(.secondary).fixedSize()
                }
                Text(L("HTML・CSS・JavaScript・画像を保存し、リンクを相対パスに書き換えます"))
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

    // MARK: 入力

    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
            GridRow {
                Text(L("URL :")).gridColumnAlignment(.trailing)
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("", text: $mirror.urlText, prompt: Text(verbatim: "https://example.com/"))
                            .textFieldStyle(.plain)
                            .frame(minWidth: 160, maxWidth: .infinity)
                            .focused($urlFocused)
                            .disabled(mirror.isRunning)
                            .onSubmit { if mirror.canStart { mirror.start(checkOnly: mirror.checkOnlyMode) } }
                            .accessibilityLabel(L("取り込むサイトのURL"))
                        Menu {
                            if mirror.recentURLs.isEmpty {
                                Text(L("履歴はありません"))
                            } else {
                                ForEach(mirror.recentURLs, id: \.self) { value in
                                    Button { mirror.urlText = value; urlFocused = true } label: {
                                        Text(verbatim: value)
                                    }
                                }
                                Divider()
                                Button(L("URL履歴を消去")) { mirror.clearURLHistory() }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .disabled(mirror.isRunning)
                        .accessibilityLabel(L("最近使ったURL"))
                        .help(L("最近使ったURL"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(urlFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1))
                    let url = Mirror.startURL(from: mirror.urlText)
                    Button {
                        if let url { login.show(url) }
                    } label: {
                        Label(L("ログイン…"), systemImage: login.isLoggedIn(url) ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                    }
                    .disabled(mirror.isRunning || url == nil)
                    .help(login.isLoggedIn(url) ? L("このサイトのログイン情報を使います。ログインし直すときに開きます") : L("ログインが必要なサイトは、ここで開いてログインします"))

                }
            }
            GridRow {
                Text(L("保存先 :"))
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: mirror.outputFolder.path))
                        .resizable().frame(width: 16, height: 16).accessibilityHidden(true)
                    Text((mirror.outputFolder.path as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1).truncationMode(.middle)
                        .help(mirror.outputFolder.path)
                    Spacer()
                    Button(L("変更…")) { mirror.chooseOutputFolder() }
                        .disabled(mirror.isRunning)
                }
            }
            GridRow {
                Color.clear.frame(width: 0, height: 0).accessibilityHidden(true)
                HStack(spacing: 8) {
                    Picker(L("処理"), selection: $mirror.checkOnlyMode) {
                        Text(L("リンクを調べる")).tag(true)
                        Text(L("取り込む")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .disabled(mirror.isRunning)
                    .help(L("保存せず、リンク切れだけを調べます"))
                    Spacer(minLength: 12)
                    if mirror.isRunning {
                        Button(L("中止")) { mirror.cancel() }
                            .disabled(mirror.isRewriting)
                            .fixedSize()
                    } else {
                        Button(L("開始")) { mirror.start(checkOnly: mirror.checkOnlyMode) }
                            .keyboardShortcut(.defaultAction)
                            .disabled(!mirror.canStart)
                            .fixedSize()
                    }
                }
            }
        }
    }

    // MARK: 一覧

    private var log: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.bottom, 2)
            HStack {
                Text(L("取得結果")).font(.subheadline.weight(.semibold))
                Spacer(minLength: 12)
                Picker(L("表示"), selection: $filter) {
                    ForEach(LogFilter.allCases, id: \.self) { item in
                        Text(item.title(count: item.state.map { state in mirror.rows.lazy.filter { $0.state == state }.count } ?? mirror.rows.count))
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .onChange(of: filter) { selection = [] }
            }
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(shownRows, selection: $selection) { row in
                LogRowView(row: row).id(row.id)
            }
            // ⌘C と右クリックで URL をコピー（複数選んでいれば改行区切り）
            .onCopyCommand { [NSItemProvider(object: urls(selection) as NSString)] }
            .contextMenu(forSelectionType: Int.self) { ids in
                if !ids.isEmpty {
                    Button(L("URLをコピー")) { copy(urls(ids)) }
                    Button(L("URLと理由をコピー")) { copy(urls(ids, withDetail: true)) }
                    if ids.count == 1, let row = mirror.rows.first(where: { ids.contains($0.id) }), row.state == .saved,
                       let file = mirror.resultFolder?.appendingPathComponent(row.detail) {
                        Divider()
                        Button(L("Finderで表示")) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay {
                if mirror.rows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: isTargeted ? "globe.badge.chevron.backward" : "globe")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(mirror.isRunning ? L("取り込み中…") : L("URLを入力し、処理を選んで「開始」を押します"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onChange(of: mirror.rows.count) { _, count in
                if count == 0 { selection = [] }
                guard mirror.isRunning, let last = shownRows.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func urls(_ ids: Set<Int>, withDetail: Bool = false) -> String {
        mirror.rows.filter { ids.contains($0.id) }
            .map { withDetail ? $0.url + "\t" + $0.detail : $0.url }
            .joined(separator: "\n")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if mirror.isRunning {
                ProgressView().controlSize(.small)
                Text(mirror.isRewriting ? mirror.status
                     : mirror.isCheckOnly ? L("正常 %d・失敗 %d・待ち %d", mirror.saved, mirror.failed, mirror.waiting)
                     : L("保存 %d・失敗 %d・待ち %d", mirror.saved, mirror.failed, mirror.waiting))
                    .monospacedDigit()
            } else {
                Text(mirror.status).lineLimit(2)
            }
            Spacer()
            Menu(L("結果を開く")) {
                Button(L("差分を開く")) { mirror.revealDiff() }
                    .disabled(mirror.isRunning || mirror.diffReport == nil)
                Button(L("記録を開く")) { mirror.revealLog() }
                    .disabled(mirror.isRunning || mirror.logFile == nil)
                    .help(L("取り込みフォルダーの SiteMirror-log.txt（失敗・除外したURLと理由・参照元）を開きます"))
                Button(L("Finderで表示")) { mirror.revealResult() }
                    .disabled(mirror.isRunning || mirror.resultFolder == nil)
                Button(L("ブラウザで開く")) { mirror.openInBrowser() }
                    .disabled(mirror.isRunning || mirror.startPage == nil)
            }
            .fixedSize()
            .disabled(mirror.isRunning || (mirror.diffReport == nil && mirror.logFile == nil && mirror.resultFolder == nil && mirror.startPage == nil))
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// 一覧の絞り込み
private enum LogFilter: CaseIterable {
    case all, failed, skipped
    var state: LogRow.State? {
        switch self {
        case .all: nil
        case .failed: .failed
        case .skipped: .skipped
        }
    }
    func title(count: Int) -> String {
        switch self {
        case .all: L("すべて（%d）", count)
        case .failed: L("失敗（%d）", count)
        case .skipped: L("除外（%d）", count)
        }
    }
}

private struct LogRowView: View {
    let row: LogRow
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            icon
            Text(row.url).lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.detail).lineLimit(1).truncationMode(.middle)
                .foregroundStyle(row.state == .failed ? Color.red : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    // 色だけに頼らず、記号と読み上げの文字でも状態を示す
    @ViewBuilder private var icon: some View {
        switch row.state {
        case .saved:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel(L("保存"))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityLabel(L("失敗"))
        case .skipped:
            Image(systemName: "minus.circle").foregroundStyle(.secondary).accessibilityLabel(L("除外"))
        }
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
/// Shown under the header icon: version, then build in parentheses (「1.4.5」「（15）」).
private func appVersionText() -> String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info["CFBundleVersion"] as? String, !build.isEmpty, build != version else { return version }
    let japanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    return version + "\n" + (japanese ? "（\(build)）" : "(\(build))")
}
