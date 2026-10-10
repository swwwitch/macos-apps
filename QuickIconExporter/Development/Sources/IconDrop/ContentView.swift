import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var isTargeted = false
    @State private var status: Status = .idle

    private enum Status {
        case idle
        case exporting(done: Int, total: Int)
        case success([ExportResult])
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            dropZone
                .padding(18)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        .onReceive(NotificationCenter.default.publisher(for: .init("QuickIconExporterChooseFiles"))) { _ in chooseFiles() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                .frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("アイコンを書き出す"))
                    .font(.title2.weight(.semibold))
                Text(L("ファイルのアイコンを最大サイズのPNGに"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SettingsLink {
                Label(L("設定"), systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [9, 7])
                )

            VStack(spacing: 16) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 58, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusColor)

                statusText
                Button(L("ファイルを選択…"), action: chooseFiles)
                    .disabled(isExporting)

                if case .success(let results) = status, let latest = results.last {
                    Button(L("Finderで表示")) {
                        NSWorkspace.shared.activateFileViewerSelecting([latest.outputURL])
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .animation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeOut(duration: 0.16), value: isTargeted)
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .idle:
            Text(L("アプリやファイルをここにドロップ"))
                .font(.title3.weight(.medium))
            Text(L("複数のファイルもまとめて書き出せます"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .exporting(let done, let total):
            Text(L("アイコンを書き出しています…"))
                .font(.title3.weight(.medium))
            if total > 1 {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(maxWidth: 240)
                Text("\(done) / \(total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .success(let results):
            Text(results.count == 1 ? L("書き出しました") : L("%@個を書き出しました", String(describing: results.count)))
                .font(.title3.weight(.semibold))
            if let latest = results.last {
                Text("\(latest.outputURL.lastPathComponent)  ·  \(latest.pixelWidth) × \(latest.pixelHeight) px")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        case .failure(let message):
            Text(L("書き出せませんでした"))
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(L("書き出し先:"))
                .foregroundStyle(.secondary)
            Text(settings.outputDirectory.path(percentEncoded: false))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(L("変更…")) {
                settings.chooseOutputDirectory()
            }
        }
        .font(.caption)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var statusSymbol: String {
        switch status {
        case .idle: return isTargeted ? "arrow.down.app.fill" : "arrow.down.app"
        case .exporting: return "hourglass"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .success: return .green
        case .failure: return .orange
        default: return .accentColor
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let capableProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !capableProviders.isEmpty else { return false }

        status = .exporting(done: 0, total: capableProviders.count)
        Task {
            var urls: [URL] = []
            for provider in capableProviders {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                   let url = fileURL(from: item) {
                    urls.append(url)
                }
            }

            await export(urls: urls)
        }
        return true
    }

    private var isExporting: Bool { if case .exporting = status { return true }; return false }

    private func chooseFiles() {
        guard !isExporting else { return }
        let panel = NSOpenPanel()
        panel.title = L("アイコンを書き出すファイルを選択")
        panel.prompt = L("選択")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            let urls = panel.urls
            status = .exporting(done: 0, total: urls.count)
            Task { await export(urls: urls) }
        }
    }

    /// 書き出しは1件ずつバックグラウンドで行い、進捗を画面に反映する。
    private func export(urls: [URL]) async {
        let rules = settings.filenameRules
        let directory = settings.outputDirectory
        var results: [ExportResult] = []
        status = .exporting(done: 0, total: urls.count)
        do {
            for url in urls {
                let result = try await Task.detached(priority: .userInitiated) {
                    let isAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessing { url.stopAccessingSecurityScopedResource() }
                    }
                    return try IconExporter.exportIcon(for: url, to: directory, rules: rules)
                }.value
                results.append(result)
                status = .exporting(done: results.count, total: urls.count)
            }
            status = results.isEmpty ? .failure(L("ファイルを読み取れませんでした。")) : .success(results)
            if !results.isEmpty {
                settings.reportSuccessfulExport(results)
            }
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func fileURL(from item: NSSecureCoding) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        if let string = item as? String { return URL(string: string) }
        return nil
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
