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
    /// Finder's name (Adobe Illustrator 2021) instead of the file name (Adobe Illustrator).
    var usesDisplayName = false
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
    @Published private(set) var requiresOutputDirectorySelection = OutputDirectoryPolicy.isSandboxed
    var outputDirectoryLabel: String {
        requiresOutputDirectorySelection ? L("保存先を選択してください") : outputDirectory.path(percentEncoded: false)
    }

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

    @Published var usesDisplayName = UserDefaults.standard.object(forKey: "usesDisplayName") as? Bool ?? true {
        didSet { UserDefaults.standard.set(usesDisplayName, forKey: "usesDisplayName") }
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
            removesUnwantedCharacters: removesUnwantedCharacters,
            usesDisplayName: usesDisplayName
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
           let bookmarkedURL = Self.resolveBookmark(bookmark),
           OutputDirectoryPolicy.isUserDirectory(bookmarkedURL) {
            outputDirectory = bookmarkedURL
            isAccessingSecurityScopedOutput = bookmarkedURL.startAccessingSecurityScopedResource()
            requiresOutputDirectorySelection = OutputDirectoryPolicy.isSandboxed &&
                (!isAccessingSecurityScopedOutput || !FileManager.default.isWritableFile(atPath: bookmarkedURL.path))
        } else if !OutputDirectoryPolicy.isSandboxed,
           let savedPath = UserDefaults.standard.string(forKey: Self.outputDirectoryKey),
           OutputDirectoryPolicy.isUserDirectory(URL(fileURLWithPath: savedPath)),
           FileManager.default.fileExists(atPath: savedPath) {
            outputDirectory = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            outputDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        }
    }

    @discardableResult
    func chooseOutputDirectory() -> Bool {
        let panel = NSOpenPanel()
        panel.title = L("書き出し先を選択")
        panel.prompt = L("選択")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if !requiresOutputDirectorySelection { panel.directoryURL = outputDirectory }

        if panel.runModal() == .OK, let selectedURL = panel.url {
            return setOutputDirectory(selectedURL)
        }
        return false
    }

    /// Shared by window drops, the file picker, Dock/Finder opens and Services.
    func prepareOutputDirectory() -> Bool {
        if !OutputDirectoryPolicy.isUserDirectory(outputDirectory) ||
            (OutputDirectoryPolicy.isSandboxed && !FileManager.default.isWritableFile(atPath: outputDirectory.path)) {
            requiresOutputDirectorySelection = true
        }
        return !requiresOutputDirectorySelection || chooseOutputDirectory()
    }

    func restoreDesktop() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        if OutputDirectoryPolicy.isSandboxed {
            // FileManager's Desktop is container-relative under App Sandbox.
            // Let the system's standard folder picker grant the real destination.
            chooseOutputDirectory()
        } else {
            setOutputDirectory(desktop)
        }
    }

    /// Keys shared by 「設定の共有」: file naming and what happens after export. The output folder stays per Mac.
    static let sharedKeys: Set<String> = [filenamePrefixKey, iconNamePositionKey, filenameSeparatorKey, spaceReplacementKey,
                                         removesUnwantedCharactersKey, showsCompletionNotificationKey, playsCompletionSoundKey,
                                         "revealsInFinder", "hidesAfterExport", "usesDisplayName"]

    /// Reads the shared settings again after an import or a sync from another Mac.
    func reloadSharedSettings() {
        let defaults = UserDefaults.standard
        filenamePrefix = defaults.object(forKey: Self.filenamePrefixKey) == nil ? "icon" : defaults.string(forKey: Self.filenamePrefixKey) ?? "icon"
        iconNamePosition = IconNamePosition(rawValue: defaults.string(forKey: Self.iconNamePositionKey) ?? "") ?? .beforeFilename
        filenameSeparator = FilenameSeparator(rawValue: defaults.string(forKey: Self.filenameSeparatorKey) ?? "") ?? .hyphen
        spaceReplacement = SpaceReplacement(rawValue: defaults.string(forKey: Self.spaceReplacementKey) ?? "") ?? .hyphen
        removesUnwantedCharacters = defaults.object(forKey: Self.removesUnwantedCharactersKey) as? Bool ?? true
        usesDisplayName = defaults.object(forKey: "usesDisplayName") as? Bool ?? true
        showsCompletionNotification = defaults.object(forKey: Self.showsCompletionNotificationKey) as? Bool ?? false
        playsCompletionSound = defaults.object(forKey: Self.playsCompletionSoundKey) as? Bool ?? false
        revealsInFinder = defaults.object(forKey: "revealsInFinder") as? Bool ?? true
        hidesAfterExport = defaults.object(forKey: "hidesAfterExport") as? Bool ?? false
    }

    func restoreFilenameDefaults() {
        filenamePrefix = "icon"
        iconNamePosition = .beforeFilename
        filenameSeparator = .hyphen
        spaceReplacement = .hyphen
        removesUnwantedCharacters = true
        usesDisplayName = true
    }

    @Published var recentExportResults: [ExportResult] = []
    @Published var externalExportError: String?

    func reportSuccessfulExport(_ results: [ExportResult]) {
        recentExportResults = results
        guard !results.isEmpty else { return }
        if revealsInFinder { NSWorkspace.shared.activateFileViewerSelecting(results.map(\.outputURL)) }
        if hidesAfterExport { NSApp.hide(nil) }

        if playsCompletionSound {
            NSSound(named: "Glass")?.play()
        }

        guard showsCompletionNotification else { return }
        let body: String
        if results.count == 1, let result = results.first {
            body = L("%@を書き出しました。", String(describing: result.outputURL.lastPathComponent))
        } else {
            body = L("%@個のアイコンを書き出しました。", String(describing: results.count))
        }
        NotificationPreferences.shared.post(title: "QuickIconExporter", body: body, enabledKey: Self.showsCompletionNotificationKey, enabledDefault: false)
    }

    @discardableResult
    private func setOutputDirectory(_ url: URL) -> Bool {
        guard OutputDirectoryPolicy.isUserDirectory(url) else {
            let alert = NSAlert()
            alert.messageText = L("保存先を選択してください")
            alert.informativeText = L("アプリのコンテナ内には保存できません。通常のフォルダを選択してください。")
            alert.runModal()
            return false
        }
        if isAccessingSecurityScopedOutput {
            outputDirectory.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedOutput = false
        }

        outputDirectory = url
        // Never leave an old folder's bookmark paired with the newly selected path.
        UserDefaults.standard.removeObject(forKey: Self.outputDirectoryBookmarkKey)
        requiresOutputDirectorySelection = false
        isAccessingSecurityScopedOutput = url.startAccessingSecurityScopedResource()
        if let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmark, forKey: Self.outputDirectoryBookmarkKey)
        }
        return true
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
