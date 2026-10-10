import AppKit
import Foundation
import UserNotifications

enum SpaceReplacement: String, CaseIterable, Identifiable {
    case keep
    case hyphen
    case underscore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keep: return L("そのまま")
        case .hyphen: return L("ハイフンに変更")
        case .underscore: return L("アンダースコアに変更")
        }
    }
}

enum IconNamePosition: String, CaseIterable, Identifiable {
    case beforeFilename
    case afterFilename

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beforeFilename: return L("{icon}-ファイル名.png")
        case .afterFilename: return L("ファイル名-{icon}.png")
        }
    }
}

enum FilenameSeparator: String, CaseIterable, Identifiable {
    case hyphen = "-"
    case underscore = "_"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hyphen: return L("ハイフン（-）")
        case .underscore: return L("アンダースコア（_）")
        }
    }
}

struct FilenameRules {
    var prefix: String
    var iconNamePosition: IconNamePosition
    var separator: FilenameSeparator
    var spaceReplacement: SpaceReplacement
    var removesUnwantedCharacters: Bool
}

@MainActor
final class AppSettings: ObservableObject {
    /// One instance for the window, Settings, Dock drops and Services so changes apply immediately.
    static let shared = AppSettings()
    private static let outputDirectoryKey = "outputDirectory"
    private static let outputDirectoryBookmarkKey = "outputDirectoryBookmark"
    private static let filenamePrefixKey = "filenamePrefix"
    private static let iconNamePositionKey = "iconNamePosition"
    private static let filenameSeparatorKey = "filenameSeparator"
    private static let spaceReplacementKey = "spaceReplacement"
    private static let removesUnwantedCharactersKey = "removesUnwantedCharacters"
    private static let showsCompletionNotificationKey = "showsCompletionNotification"
    private static let playsCompletionSoundKey = "playsCompletionSound"

    @Published var outputDirectory: URL {
        didSet {
            UserDefaults.standard.set(outputDirectory.path, forKey: Self.outputDirectoryKey)
        }
    }
    private var isAccessingSecurityScopedOutput = false

    @Published var filenamePrefix: String {
        didSet { UserDefaults.standard.set(filenamePrefix, forKey: Self.filenamePrefixKey) }
    }

    @Published var iconNamePosition: IconNamePosition {
        didSet { UserDefaults.standard.set(iconNamePosition.rawValue, forKey: Self.iconNamePositionKey) }
    }

    @Published var filenameSeparator: FilenameSeparator {
        didSet { UserDefaults.standard.set(filenameSeparator.rawValue, forKey: Self.filenameSeparatorKey) }
    }

    @Published var spaceReplacement: SpaceReplacement {
        didSet { UserDefaults.standard.set(spaceReplacement.rawValue, forKey: Self.spaceReplacementKey) }
    }

    @Published var removesUnwantedCharacters: Bool {
        didSet { UserDefaults.standard.set(removesUnwantedCharacters, forKey: Self.removesUnwantedCharactersKey) }
    }

    @Published var showsCompletionNotification: Bool {
        didSet { UserDefaults.standard.set(showsCompletionNotification, forKey: Self.showsCompletionNotificationKey) }
    }

    @Published var playsCompletionSound: Bool {
        didSet { UserDefaults.standard.set(playsCompletionSound, forKey: Self.playsCompletionSoundKey) }
    }

    @Published var revealsInFinder = UserDefaults.standard.object(forKey: "revealsInFinder") as? Bool ?? true {
        didSet { UserDefaults.standard.set(revealsInFinder, forKey: "revealsInFinder") }
    }
    @Published var hidesAfterExport = UserDefaults.standard.object(forKey: "hidesAfterExport") as? Bool ?? false {
        didSet { UserDefaults.standard.set(hidesAfterExport, forKey: "hidesAfterExport") }
    }

    var filenameRules: FilenameRules {
        FilenameRules(
            prefix: filenamePrefix,
            iconNamePosition: iconNamePosition,
            separator: filenameSeparator,
            spaceReplacement: spaceReplacement,
            removesUnwantedCharacters: removesUnwantedCharacters
        )
    }

    init() {
        filenamePrefix = UserDefaults.standard.object(forKey: Self.filenamePrefixKey) == nil
            ? "icon"
            : UserDefaults.standard.string(forKey: Self.filenamePrefixKey) ?? "icon"
        iconNamePosition = IconNamePosition(
            rawValue: UserDefaults.standard.string(forKey: Self.iconNamePositionKey) ?? ""
        ) ?? .beforeFilename
        filenameSeparator = FilenameSeparator(
            rawValue: UserDefaults.standard.string(forKey: Self.filenameSeparatorKey) ?? ""
        ) ?? .hyphen
        spaceReplacement = SpaceReplacement(
            rawValue: UserDefaults.standard.string(forKey: Self.spaceReplacementKey) ?? ""
        ) ?? .hyphen
        removesUnwantedCharacters = UserDefaults.standard.object(forKey: Self.removesUnwantedCharactersKey) as? Bool ?? true
        showsCompletionNotification = UserDefaults.standard.object(forKey: Self.showsCompletionNotificationKey) as? Bool ?? false
        playsCompletionSound = UserDefaults.standard.object(forKey: Self.playsCompletionSoundKey) as? Bool ?? false

        if let bookmark = UserDefaults.standard.data(forKey: Self.outputDirectoryBookmarkKey),
           let bookmarkedURL = Self.resolveBookmark(bookmark) {
            outputDirectory = bookmarkedURL
            isAccessingSecurityScopedOutput = bookmarkedURL.startAccessingSecurityScopedResource()
        } else if let savedPath = UserDefaults.standard.string(forKey: Self.outputDirectoryKey),
           FileManager.default.fileExists(atPath: savedPath) {
            outputDirectory = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            outputDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        }
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = L("書き出し先を選択")
        panel.prompt = L("選択")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory

        if panel.runModal() == .OK, let selectedURL = panel.url {
            setOutputDirectory(selectedURL)
        }
    }

    func restoreDesktop() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            let panel = NSOpenPanel()
            panel.title = L("デスクトップへのアクセスを許可")
            panel.prompt = L("デスクトップを選択")
            panel.message = L("QuickIconExporterがPNGを書き出せるよう、デスクトップを選択してください。")
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = desktop
            if panel.runModal() == .OK, let selectedURL = panel.url {
                setOutputDirectory(selectedURL)
            }
        } else {
            outputDirectory = desktop
        }
    }

    func restoreFilenameDefaults() {
        filenamePrefix = "icon"
        iconNamePosition = .beforeFilename
        filenameSeparator = .hyphen
        spaceReplacement = .hyphen
        removesUnwantedCharacters = true
    }

    func reportSuccessfulExport(_ results: [ExportResult]) {
        guard !results.isEmpty else { return }
        if revealsInFinder { NSWorkspace.shared.activateFileViewerSelecting(results.map(\.outputURL)) }
        if hidesAfterExport { NSApp.hide(nil) }

        if playsCompletionSound {
            NSSound(named: "Glass")?.play()
        }

        guard showsCompletionNotification else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "QuickIconExporter"
            if results.count == 1, let result = results.first {
                content.body = L("%@を書き出しました。", String(describing: result.outputURL.lastPathComponent))
            } else {
                content.body = L("%@個のアイコンを書き出しました。", String(describing: results.count))
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func setOutputDirectory(_ url: URL) {
        if isAccessingSecurityScopedOutput {
            outputDirectory.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedOutput = false
        }

        outputDirectory = url
        if let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmark, forKey: Self.outputDirectoryBookmarkKey)
            isAccessingSecurityScopedOutput = url.startAccessingSecurityScopedResource()
        }
    }

    private static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale,
           let refreshed = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
           ) {
            UserDefaults.standard.set(refreshed, forKey: Self.outputDirectoryBookmarkKey)
        }
        return url
    }
}
