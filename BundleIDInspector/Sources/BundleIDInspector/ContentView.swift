import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject private var store = AppStore.shared
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            listArea
                .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                .frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Bundle IDを調べる"))
                    .font(.title2.weight(.semibold))
                Text(L("アプリをドロップしてBundle IDを表示"))
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

    private var listArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
            if store.items.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                                  style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [9, 7]))
                VStack(spacing: 10) {
                    Image(systemName: isTargeted ? "arrow.down.app.fill" : "arrow.down.app")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.accentColor)
                    Text(L("アプリをここにドロップ"))
                        .font(.headline)
                    Button(L("アプリを選択…")) { store.chooseApps() }
                }
                .padding(16)
            } else {
                List {
                    ForEach(store.items) { item in row(item) }
                }
                .scrollContentBackground(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            store.add(urls)
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.easeOut(duration: 0.16), value: isTargeted)
    }

    private func row(_ item: AppInfo) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.headline).lineLimit(1)
                Text(item.bundleID)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(L("コピー")) { store.copy(item.bundleID, note: L("%@をコピーしました", item.bundleID)) }
                .accessibilityLabel(L("%@のBundle IDをコピー", item.name))
        }
        .padding(.vertical, 2)
        .help(item.path)
        .contextMenu {
            Button(L("Bundle IDをコピー")) { store.copy(item.bundleID, note: L("%@をコピーしました", item.bundleID)) }
            Button(L("パスをコピー")) { store.copy(item.path, note: L("パスをコピーしました")) }
            Button(L("Finderで表示")) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
            Divider()
            Button(L("一覧から削除")) { store.items.removeAll { $0.id == item.id } }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(store.message ?? L("%@件", String(store.items.count)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(L("すべてコピー")) {
                store.copy(store.items.map(\.bundleID).joined(separator: "\n"),
                           note: L("%@件のBundle IDをコピーしました", String(store.items.count)))
            }
            .disabled(store.items.isEmpty)
            Button(L("クリア")) { store.items.removeAll(); store.message = nil }
                .disabled(store.items.isEmpty)
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
