import Foundation

/// One InDesign workspace: the saved file (`name.xml`) and/or its current state (`name_CurrentWorkspace.xml`).
/// Built-in workspaces (初期設定 etc.) only have the current-state file; their saved copy lives inside the app.
struct Workspace: Identifiable, Equatable {
    /// `saved`: the user's own workspace (`name.xml` exists). `builtIn`: one of InDesign's presets.
    /// `orphan`: only a current-state file is left — its workspace was deleted, so InDesign does not list it.
    enum Kind: Equatable { case saved, builtIn, orphan }
    let version: String
    let locale: String
    let name: String
    let files: [URL]
    var kind: Kind = .saved
    var id: String { (files.first?.deletingLastPathComponent().path ?? "") + "/" + name }
}

/// `hidden`: every file has `<app-container-control-bar … is-closed="true"/>`.
enum BarState: Equatable {
    case hidden
    case shown
    case invalid
}

/// Hides the application bar by editing workspace XML, as in
/// https://note.com/dtp_tranist/n/n08559ccb6a3b (InDesign rewrites these files when it quits, so it must not be running).
enum ApplicationBar {
    static let suffix = "_CurrentWorkspace"
    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/Adobe InDesign", isDirectory: true)
    }

    /// Dropbox/iCloud conflicted copies, also when InDesign has loaded one and written its own current-state file
    /// (`sw-left_CurrentWorkspace (… 競合コピー …)_CurrentWorkspace.xml`).
    static func isConflictedCopy(_ name: String) -> Bool {
        name.contains("競合コピー") || name.localizedCaseInsensitiveContains("conflicted copy") || name.contains(suffix)
    }

    /// Names of InDesign's preset workspaces per locale, from every installed InDesign
    /// (`/Applications/Adobe InDesign <year>/Presets/InDesign_Workspaces/<locale>/*.xml`).
    static func builtInNames(applications: URL = URL(fileURLWithPath: "/Applications", isDirectory: true)) -> [String: Set<String>] {
        let fm = FileManager.default
        var result: [String: Set<String>] = [:]
        for folder in ((try? fm.contentsOfDirectory(atPath: applications.path)) ?? []) where folder.hasPrefix("Adobe InDesign") {
            let presets = applications.appendingPathComponent(folder).appendingPathComponent("Presets/InDesign_Workspaces", isDirectory: true)
            for locale in (try? fm.contentsOfDirectory(atPath: presets.path)) ?? [] {
                let files = (try? fm.contentsOfDirectory(atPath: presets.appendingPathComponent(locale).path)) ?? []
                result[locale, default: []].formUnion(files.filter { $0.hasSuffix(".xml") }.map { String($0.dropLast(4)) })
            }
        }
        return result
    }

    /// `Version <n>/<locale>/Workspaces/*.xml`, newest version first. Conflicted copies are skipped.
    /// Without `builtIn` (no InDesign presets found) nothing is marked as an orphan.
    static func discover(root: URL = root, builtIn: [String: Set<String>] = builtInNames()) -> [Workspace] {
        let fm = FileManager.default
        var result: [Workspace] = []
        let versions = ((try? fm.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.hasPrefix("Version ") }
            .sorted { $0.localizedStandardCompare($1) == .orderedDescending }
        for version in versions {
            let versionURL = root.appendingPathComponent(version, isDirectory: true)
            let locales = ((try? fm.contentsOfDirectory(atPath: versionURL.path)) ?? []).sorted()
            for locale in locales {
                let folder = versionURL.appendingPathComponent(locale).appendingPathComponent("Workspaces", isDirectory: true)
                guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }
                var grouped: [String: [URL]] = [:]
                for file in names where file.hasSuffix(".xml") {
                    var name = String(file.dropLast(4))
                    if name.hasSuffix(suffix) { name = String(name.dropLast(suffix.count)) }
                    if isConflictedCopy(name) { continue }
                    let url = folder.appendingPathComponent(file)
                    guard isClosed(url) != nil else { continue }
                    grouped[name, default: []].append(url)
                }
                for (name, files) in grouped {
                    let saved = files.contains { $0.lastPathComponent == name + ".xml" }
                    let kind: Workspace.Kind = saved ? .saved
                        : (builtIn[locale].map { $0.contains(name) } ?? true) ? .builtIn : .orphan
                    result.append(Workspace(version: String(version.dropFirst("Version ".count)), locale: locale, name: name,
                                            files: files.sorted { $0.lastPathComponent < $1.lastPathComponent }, kind: kind))
                }
            }
        }
        return result.sorted {
            $0.version != $1.version ? $0.version.localizedStandardCompare($1.version) == .orderedDescending
                : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// The `is-closed` value of the application bar, or nil when the file has no such element.
    static func isClosed(_ url: URL) -> Bool? {
        guard let text = try? String(contentsOf: url, encoding: .utf8), let range = tagRange(text) else { return nil }
        let tag = text[range]
        if tag.contains(#"is-closed="true""#) { return true }
        if tag.contains(#"is-closed="false""#) { return false }
        return nil
    }

    static func state(of workspace: Workspace) -> BarState {
        let values = workspace.files.map(isClosed)
        if values.contains(where: { $0 == nil }) || values.isEmpty { return .invalid }
        return values.allSatisfy { $0 == true } ? .hidden : .shown
    }

    private static func tagRange(_ text: String) -> Range<String.Index>? {
        guard let start = text.range(of: "<app-container-control-bar"),
              let end = text.range(of: ">", range: start.upperBound..<text.endIndex) else { return nil }
        return start.lowerBound..<end.upperBound
    }

    /// Rewrites only the `is-closed` attribute of the application bar element; the rest of the file is left byte-for-byte.
    static func set(_ workspace: Workspace, hidden: Bool) -> Bool {
        var ok = true
        for url in workspace.files {
            guard var text = try? String(contentsOf: url, encoding: .utf8), let range = tagRange(text) else { ok = false; continue }
            let tag = String(text[range])
            let new = tag.replacingOccurrences(of: hidden ? #"is-closed="false""# : #"is-closed="true""#,
                                               with: hidden ? #"is-closed="true""# : #"is-closed="false""#)
            guard new != tag else { continue }
            text.replaceSubrange(range, with: new)
            do { try text.write(to: url, atomically: true, encoding: .utf8) } catch { ok = false }
        }
        return ok
    }
}
