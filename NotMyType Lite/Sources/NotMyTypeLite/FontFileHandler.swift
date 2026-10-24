import AppKit
import UniformTypeIdentifiers

/// フォントファイルをダブルクリックしたときに開くアプリ（FontExplorer X Pro の Use … as default handler for font files に当たる）。
/// Info.plist の CFBundleDocumentTypes でフォントを開けるアプリとして宣言し、ここで既定のアプリを NotMyType か Font Book に切り替える。
/// 既定のアプリの切り替えは反映まで数秒かかる（ExtensionLinker の実測）ので、少し待ってから読み直す
@MainActor
final class FontFileHandler: ObservableObject {
    static let shared = FontFileHandler()
    static let extensions = ["otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"]
    static let fontBookID = "com.apple.FontBook"

    /// 形式ごとの今の既定のアプリの名前
    @Published private(set) var handlers: [(ext: String, app: String)] = []
    @Published private(set) var working = false

    var types: [(String, UTType)] { Self.extensions.compactMap { ext in UTType(filenameExtension: ext).map { (ext, $0) } } }

    /// すべての形式で NotMyType が既定か
    var isDefault: Bool { !handlers.isEmpty && handlers.allSatisfy { $0.app == appName } }
    private var appName: String { FileManager.default.displayName(atPath: Bundle.main.bundlePath) }

    func refresh() {
        handlers = types.map { ext, type in
            let url = NSWorkspace.shared.urlForApplication(toOpen: type)
            return (ext, url.map { FileManager.default.displayName(atPath: $0.path) } ?? "—")
        }
    }

    func makeDefault() { setDefault(Bundle.main.bundleURL) }

    func restoreFontBook() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.fontBookID) else { return }
        setDefault(url)
    }

    private func setDefault(_ app: URL) {
        working = true
        Task {
            for (_, type) in types {
                try? await NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type)
            }
            try? await Task.sleep(for: .seconds(3))
            refresh()
            working = false
        }
    }
}
