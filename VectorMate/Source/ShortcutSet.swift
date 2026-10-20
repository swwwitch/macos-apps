import AppKit
import ApplicationServices
import Carbon

/// カスタム → キーボードショートカット: links every .kys of a synced folder into the Illustrator settings folder,
/// then chooses the selected one in 編集 → キーボードショートカット.... Illustrator lists the sets when it launches: a .kys linked
/// while it was running did not appear in the dialog box (2026-10-20), so a new link is chosen after a restart.
enum ShortcutSet {
    /// A folder, relative to the synced folder (SyncFolder). Up to 2.13 it was one .kys (its folder is used).
    static let defaultSource = "キーボードショートカット"
    /// The default of 2.12–2.13 (a file that did not exist): replaced by `defaultSource` when loaded.
    static let legacyDefault = "~/sw Dropbox/takano masahiro/sync-setting/ai/キーボードショートカット/sw.kys"
    static let menuPaths = [["編集", "キーボードショートカット..."], ["Edit", "Keyboard Shortcuts..."]]
    static let dialogNames = ["キーボードショートカット", "Keyboard Shortcuts"]
    static let locale = "ja_JP"

    enum Choice { case chosen, alreadyChosen, notListed }
    struct Installed {
        var name: String
        var links: SymbolicLinks.Summary
        /// nil: Illustrator is not running, or choosing failed (`problem`).
        var choice: Choice?
        /// Linking worked but choosing the set did not.
        var problem: SettingsFailure?
    }

    static func setName(_ source: URL) -> String { source.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping }
    static func isKys(_ url: URL) -> Bool { url.pathExtension.lowercased() == "kys" }
    /// The .kys files of the folder, by name.
    static func files(in folder: URL) -> [URL] { ((try? SymbolicLinks.files(in: folder)) ?? []).filter(isKys) }

    /// 「Adobe Illustrator <major> Settings/ja_JP」 of the running Illustrator, or of the newest release version installed.
    static func settingsFolder(_ app: NSRunningApplication?) -> URL? {
        let preferences = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
        guard let major = illustratorMajor(app, in: preferences, suffix: " Settings") else { return nil }
        let folder = preferences.appendingPathComponent("Adobe Illustrator \(major) Settings/\(locale)")
        return FileManager.default.fileExists(atPath: folder.path) ? folder : nil
    }

    static let backups = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/VectorMate/LinkBackups/KeyboardShortcuts")

    private static func dialog(_ root: AXUIElement) -> AXUIElement? {
        (AX.elements(root) + AX.elements(root, kAXWindowsAttribute)).first { el in
            dialogNames.contains(AX.string(el, kAXDescriptionAttribute) ?? "") || dialogNames.contains(AX.string(el, kAXTitleAttribute) ?? "")
        }
    }

    /// Blocking: opens 編集 → キーボードショートカット..., picks the set in the セット combo box and confirms with Return.
    /// The combo box cannot be written and its opened list has no actions (arrow keys and clicks in it did nothing,
    /// 2026-10-20); with the closed combo box focused, ↓ moves the set and Return is OK (the user, 2026-10-20).
    static func choose(_ name: String, in app: NSRunningApplication) -> Result<Choice, SettingsFailure> {
        guard AXIsProcessTrusted() else { return .failure(.notTrusted) }
        guard bringToFront(app) else { return .failure(.failed("activate")) }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 3)
        guard let item = InterfaceMenus.menuItem(root, paths: menuPaths) else { return .failure(.menuNotFound) }
        var found: AXUIElement?
        for _ in 0..<2 where found == nil {
            guard AX.press(item) else { return .failure(.menuNotFound) }
            found = AX.wait(50) { dialog(root) }
        }
        guard let dialog = found else { return .failure(.dialogNotFound) }
        func close(ok: Bool) {
            AX.pressButton(in: dialog, named: ok ? AX.okNames : AX.cancelNames)
            _ = AX.wait(50) { Self.dialog(root) == nil ? true : nil }
        }
        // The first combo box is セット (the second is メニューコマンド / ツール).
        guard let combo = AX.elements(dialog).first(where: { AX.role($0) == kAXComboBoxRole }) else { close(ok: false); return .failure(.controlNotFound) }
        let items = AX.elements(combo).compactMap(AX.name)
        let current = AX.string(combo, kAXValueAttribute) ?? ""
        if current == name { close(ok: false); return .success(.alreadyChosen) }
        guard let to = items.firstIndex(of: name) else { close(ok: false); return .success(.notListed) }
        AXUIElementSetAttributeValue(combo, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        Thread.sleep(forTimeInterval: 0.3)
        // From the top, so a stale value read does not count the steps wrong.
        for _ in items { AX.key(kVK_UpArrow); Thread.sleep(forTimeInterval: 0.08) }
        for _ in 0..<to { AX.key(kVK_DownArrow); Thread.sleep(forTimeInterval: 0.1) }
        Thread.sleep(forTimeInterval: 0.4)
        guard AX.string(combo, kAXValueAttribute) == name else { close(ok: false); return .failure(.notChanged) }
        AX.key(kVK_Return)
        // Return is OK; if the dialog box is still there, OK is pressed directly.
        if AX.wait(50, { Self.dialog(root) == nil ? true : nil }) == nil { close(ok: true) }
        return .success(.chosen)
    }

    /// Blocking: links every .kys of `source` (Illustrator need not be running), then chooses `name` when Illustrator runs.
    static func install(_ source: URL, name: String) -> Result<Installed, SettingsFailure> {
        let app = runningIllustrator()
        guard let folder = settingsFolder(app) else { return .failure(.message(L("kbsc.noFolder"))) }
        let names = files(in: source).map(setName)
        guard !names.isEmpty else { return .failure(.message(String(format: L("kbsc.noKys"), source.path))) }
        let links: SymbolicLinks.Summary
        do { links = try SymbolicLinks.linkAll(from: source, into: folder, backups: backups.appendingPathComponent(SymbolicLinks.stamp), where: isKys) }
        catch { return .failure(.message(error.localizedDescription)) }
        var installed = Installed(name: names.contains(name) ? name : names[0], links: links)
        guard let app else { return .success(installed) }
        switch choose(installed.name, in: app) {
        case .success(let choice): installed.choice = choice
        case .failure(let failure): installed.problem = failure
        }
        return .success(installed)
    }
}

/// The major version of the running Illustrator, or the largest one that has a folder 「Adobe Illustrator <major><suffix>」
/// in `parent` (Beta and Prerelease folders carry a full version and a word, so they do not count).
func illustratorMajor(_ app: NSRunningApplication?, in parent: URL, suffix: String) -> Int? {
    if let version = app?.bundleURL.flatMap({ Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String }),
       let major = version.split(separator: ".").first.flatMap({ Int($0) }) { return major }
    let names = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
    return names.compactMap { name -> Int? in
        guard name.hasPrefix("Adobe Illustrator "), name.hasSuffix(suffix) else { return nil }
        return Int(name.dropFirst("Adobe Illustrator ".count).dropLast(suffix.count))
    }.max()
}

/// カスタム → ドキュメントプロファイル・合成フォント: every file of a synced folder is linked one by one into
/// 「~/Library/Application Support/Adobe/Adobe Illustrator <major>/ja_JP/<folder>」, so files only Illustrator has stay.
enum FolderLinks {
    enum Kind: String, CaseIterable {
        case profiles, compositeFonts
        var folderName: String { self == .profiles ? "New Document Profiles" : "合成フォント" }
        /// Relative to the synced folder: the same name as Illustrator's folder.
        var defaultSource: String { folderName }
        var storeKey: String { "linkSource." + rawValue }
    }
    typealias Summary = SymbolicLinks.Summary

    /// 「Adobe Illustrator <major>/ja_JP」 of the running Illustrator, or of the newest release version.
    static func localeFolder(_ app: NSRunningApplication?) -> URL? {
        let adobe = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Adobe")
        guard let major = illustratorMajor(app, in: adobe, suffix: "") else { return nil }
        let folder = adobe.appendingPathComponent("Adobe Illustrator \(major)/\(ShortcutSet.locale)")
        return FileManager.default.fileExists(atPath: folder.path) ? folder : nil
    }

    static func link(_ kind: Kind, source: URL, app: NSRunningApplication?) -> Result<Summary, SettingsFailure> {
        let fm = FileManager.default
        guard let locale = localeFolder(app) else { return .failure(.message(L("links.noFolder"))) }
        let folder = locale.appendingPathComponent(kind.folderName)
        let backups = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/VectorMate/LinkBackups/\(SymbolicLinks.stamp)/\(kind.folderName)")
        do {
            return .success(try SymbolicLinks.linkAll(from: source, into: folder, backups: backups))
        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }
}
