import AppKit

/// Deletes the browsing history of the default browser, keeping bookmarks, cookies and logins.
/// Firefox keeps history and bookmarks in one database (places.sqlite), so only the history rows are removed;
/// Chromium browsers keep history in its own file, which is removed. Safari's history needs Full Disk Access, so it is not supported.
/// The browser is quit first (its databases are locked while it runs) and reopened afterwards if it was running.
enum BrowserHistory {
    struct Browser {
        let name: String
        let bundleID: String
        let kind: Kind
    }
    enum Kind {
        case firefox(profiles: URL)
        case chromium(userData: URL)
        case unsupported
    }

    private static var support: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support") }
    private static let chromium: [String: String] = [
        "com.google.Chrome": "Google/Chrome", "com.microsoft.edgemac": "Microsoft Edge",
        "com.brave.Browser": "BraveSoftware/Brave-Browser", "com.vivaldi.Vivaldi": "Vivaldi",
        "company.thebrowser.Browser": "Arc/User Data"
    ]

    static var defaultBrowser: Browser? {
        guard let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!),
              let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        if id.hasPrefix("org.mozilla.") { return Browser(name: name, bundleID: id, kind: .firefox(profiles: support.appendingPathComponent("Firefox/Profiles"))) }
        if let folder = chromium[id] { return Browser(name: name, bundleID: id, kind: .chromium(userData: support.appendingPathComponent(folder))) }
        return Browser(name: name, bundleID: id, kind: .unsupported)
    }

    /// Removes the history; returns how many profiles were cleared.
    static func clear(_ browser: Browser) async throws -> Int {
        let wasRunning = try await quit(browser.bundleID)
        defer { if wasRunning, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) { NSWorkspace.shared.open(url) } }
        switch browser.kind {
        case .firefox(let profiles): return try clearFirefox(profiles)
        case .chromium(let userData): return try clearChromium(userData)
        case .unsupported: throw SettingsError(L("%@の履歴は削除できません。ブラウザーのメニューから削除してください。", browser.name))
        }
    }

    /// Asks the browser to quit (it saves its own state) and waits up to 15 seconds.
    @MainActor
    private static func quit(_ bundleID: String) async throws -> Bool {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return false }
        running.forEach { $0.terminate() }
        for _ in 0..<75 {
            try await Task.sleep(nanoseconds: 200_000_000)
            if running.allSatisfy(\.isTerminated) { return true }
        }
        throw SettingsError(L("ブラウザーを終了できませんでした。終了してからもう一度実行してください。"))
    }

    // Firefox: history rows only. foreign_count > 0 marks places that bookmarks or keywords use (Firefox's own expiration rule).
    private static let firefoxSQL = """
        PRAGMA foreign_keys = ON;
        BEGIN;
        DELETE FROM moz_historyvisits;
        DELETE FROM moz_inputhistory;
        DELETE FROM moz_places_metadata;
        DELETE FROM moz_places_metadata_search_queries;
        DELETE FROM moz_places WHERE foreign_count = 0;
        UPDATE moz_places SET visit_count = 0, last_visit_date = NULL, typed = 0, recalc_frecency = 1, recalc_alt_frecency = 1;
        DELETE FROM moz_origins WHERE id NOT IN (SELECT origin_id FROM moz_places WHERE origin_id IS NOT NULL);
        UPDATE moz_origins SET recalc_frecency = 1, recalc_alt_frecency = 1;
        DELETE FROM moz_annos WHERE place_id NOT IN (SELECT id FROM moz_places);
        COMMIT;
        """
    private static let bookmarkFingerprint = "SELECT count(*) || ':' || ifnull(group_concat(b.id), '') FROM moz_bookmarks b JOIN moz_places p ON p.id = b.fk;"

    private static func clearFirefox(_ profiles: URL) throws -> Int {
        let databases = ((try? FileManager.default.contentsOfDirectory(at: profiles, includingPropertiesForKeys: nil)) ?? [])
            .map { $0.appendingPathComponent("places.sqlite") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        for database in databases {
            // A temporary copy guards the bookmarks; it is removed once the result checks out, so the history does not linger.
            let backup = FileManager.default.temporaryDirectory.appendingPathComponent("PodiumAssist-places-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: backup) }
            let files = ["", "-wal", "-shm"].map { database.path + $0 }.filter { FileManager.default.fileExists(atPath: $0) }
            for file in files { try FileManager.default.copyItem(atPath: file, toPath: backup.appendingPathComponent((file as NSString).lastPathComponent).path) }
            let before = try sqlite(database, bookmarkFingerprint)
            do {
                _ = try sqlite(database, firefoxSQL)
                guard try sqlite(database, "PRAGMA integrity_check;") == "ok", try sqlite(database, bookmarkFingerprint) == before else {
                    throw SettingsError(L("履歴の削除結果を確認できなかったため、元に戻しました。"))
                }
            } catch {
                for file in ["", "-wal", "-shm"].map({ database.path + $0 }) { try? FileManager.default.removeItem(atPath: file) }
                for file in files { try? FileManager.default.copyItem(atPath: backup.appendingPathComponent((file as NSString).lastPathComponent).path, toPath: file) }
                throw error
            }
        }
        return databases.count
    }

    /// Chromium keeps bookmarks, cookies and logins in other files; History (and its journal and the visited-link table) is history only.
    private static func clearChromium(_ userData: URL) throws -> Int {
        let profiles = ((try? FileManager.default.contentsOfDirectory(at: userData, includingPropertiesForKeys: nil)) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("History").path) }
        for profile in profiles {
            for name in ["History", "History-journal", "Visited Links"] {
                let file = profile.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            }
        }
        return profiles.count
    }

    @discardableResult
    private static func sqlite(_ database: URL, _ sql: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [database.path]
        let input = Pipe(), output = Pipe(), errors = Pipe()
        process.standardInput = input; process.standardOutput = output; process.standardError = errors
        try process.run()
        input.fileHandleForWriting.write(Data(sql.utf8))
        try input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw SettingsError(message.isEmpty ? L("履歴を削除できませんでした。") : message) }
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
