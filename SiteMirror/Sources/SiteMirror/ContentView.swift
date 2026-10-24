import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var mirror = Mirror.shared
    @State private var isTargeted = false
    @FocusState private var urlFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            form
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            log
                .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        .onAppear { urlFocused = mirror.urlText.isEmpty }
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
            VStack(spacing: 4) {
                Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                AppVersionLabel()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Webサイトをまるごと保存"))
                    .font(.title2.weight(.semibold))
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
                    TextField("", text: $mirror.urlText, prompt: Text(verbatim: "https://example.com/"))
                        .textFieldStyle(.roundedBorder)
                        .focused($urlFocused)
                        .disabled(mirror.isRunning)
                        .onSubmit { if mirror.canStart { mirror.start() } }
                        .accessibilityLabel(L("取り込むサイトのURL"))
                    if mirror.isRunning {
                        Button(L("中止")) { mirror.cancel() }
                            .disabled(mirror.isRewriting)
                            .frame(minWidth: 88)
                    } else {
                        Button(L("取り込む")) { mirror.start() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(!mirror.canStart)
                            .frame(minWidth: 88)
                    }
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
        }
    }

    // MARK: 一覧

    private var log: some View {
        ScrollViewReader { proxy in
            List(mirror.rows) { row in
                LogRowView(row: row).id(row.id)
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
                        Text(mirror.isRunning ? L("取り込み中…") : L("URLを入力して「取り込む」を押します"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onChange(of: mirror.rows.count) { _, count in
                guard mirror.isRunning, count > 0 else { return }
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if mirror.isRunning {
                ProgressView().controlSize(.small)
                Text(mirror.isRewriting ? mirror.status : L("保存 %d・失敗 %d・待ち %d", mirror.saved, mirror.failed, mirror.waiting))
                    .monospacedDigit()
            } else {
                Text(mirror.status).lineLimit(2)
            }
            Spacer()
            Button(L("Finderで表示")) { mirror.revealResult() }
                .disabled(mirror.isRunning || mirror.resultFolder == nil)
            Button(L("ブラウザで開く")) { mirror.openInBrowser() }
                .disabled(mirror.isRunning || mirror.startPage == nil)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
/// Placed under the header icon.
private struct AppVersionLabel: View {
    var body: some View {
        Text(appVersionText()).font(.system(size: 10)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).fixedSize()
    }
}
