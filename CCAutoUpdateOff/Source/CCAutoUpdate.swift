import Foundation

/// `nil`: not written yet, so Creative Cloud uses its default (on).
typealias AutoUpdateValue = Bool?

/// One app row of 環境設定 → アプリ → 自動更新.
struct CCApp: Identifiable, Equatable {
    let sapCode: String
    /// Value in the prefs; nil when the app has no autoUpdatePreference yet.
    var value: AutoUpdateValue
    /// 詳細オプション → 以前のバージョンを削除 (`removeOlderVersions`; missing → the global default).
    var removeOld = false
    var id: String { sapCode }
    var name: String { CCAutoUpdate.displayName(sapCode) }
    /// Creative Cloud treats a missing value as on.
    var isOn: Bool { value != false }
}

/// The state read from every signed-in user's prefs file.
struct CCState: Equatable {
    var files: [URL] = []
    /// 自動更新（全体） — `autoUpdateEnabled`.
    var global: AutoUpdateValue = nil
    var apps: [CCApp] = []
    /// Global default for 以前のバージョンを削除 (`globalAURemoveOld`).
    var removeOldDefault = false
    /// Files that could not be parsed.
    var invalid: [URL] = []

    enum Level: Equatable {
        /// No prefs file, or one could not be read.
        case unknown
        /// The global switch is off: nothing updates automatically.
        case off
        /// The global switch is on but every app is off.
        case caution
        /// The global switch is on and at least one app is on (or not set).
        case on
    }
    var level: Level {
        if files.isEmpty || !invalid.isEmpty { return .unknown }
        if global == false { return .off }
        return apps.contains(where: \.isOn) ? .on : .caution
    }
    /// Apps that will update automatically (empty unless `level == .on`).
    var appsOn: [CCApp] { level == .on ? apps.filter(\.isOn) : [] }
    /// Apps with 以前のバージョンを削除 checked (applies to manual updates too, so it does not depend on `level`).
    var appsRemovingOld: [CCApp] { level == .unknown ? [] : apps.filter(\.removeOld) }
}

/// Reads the Creative Cloud apps preferences (never writes them):
/// `~/Library/Application Support/Adobe/OOBE/com.adobe.accc.apps.<user>.prefs`.
/// The file is `<prefs><property key="Apps_Panel_Pref">` + escaped `<ccmPreferences>` XML; the keys are
/// `/ccmPreferences/prodPref/autoUpdatePreferences/autoUpdateEnabled` (global switch) and
/// `…/autoUpdatePreferences/app/{sapcode,autoUpdatePreference}` (per app), as used by AppsPanelBL.
/// Creative Cloud writes the file as soon as a switch is changed in Preferences, and keeps one `app`
/// entry per app it lists there.
enum CCAutoUpdate {
    static let propertyKey = "Apps_Panel_Pref"
    static let creativeCloudID = "com.adobe.acc.AdobeCreativeCloud"
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Adobe/OOBE", isDirectory: true)
    }

    static let names: [String: String] = [
        "PHSP": "Photoshop", "ILST": "Illustrator", "IDSN": "InDesign", "AICY": "InCopy", "AEFT": "After Effects",
        "PPRO": "Premiere Pro", "AME": "Media Encoder", "AUDT": "Audition", "FLPR": "Animate", "CHAR": "Character Animator",
        "DRWV": "Dreamweaver", "LTRM": "Lightroom Classic", "LRCC": "Lightroom", "KBRG": "Bridge", "ACR": "Camera Raw",
        "ESHR": "Dimension", "SBSTA": "Substance 3D Sampler", "SBSTD": "Substance 3D Designer", "SBSTP": "Substance 3D Painter",
        "STGR": "Substance 3D Stager", "RUSH": "Premiere Rush", "SPRK": "XD", "FRSC": "Fresco", "APRO": "Acrobat",
    ]

    static func displayName(_ sapCode: String) -> String {
        if let name = names[sapCode] { return name }
        for (suffix, label) in [("BETA", "(Beta)"), ("PR", "(Prerelease)")] where sapCode.hasSuffix(suffix) {
            if let name = names[String(sapCode.dropLast(suffix.count))] { return name + " " + label }
        }
        return sapCode
    }

    /// Per-user files only (`com.adobe.accc.apps.default.prefs` is the logged-out template).
    static func prefsFiles(in folder: URL = folder) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasPrefix("com.adobe.accc.apps.") && $0.hasSuffix(".prefs") && $0 != "com.adobe.accc.apps.default.prefs" }
            .sorted().map { folder.appendingPathComponent($0) }
    }

    static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    /// The unescaped `<ccmPreferences>` XML of the outer file.
    static func innerXML(_ outer: String) -> String? {
        guard let open = outer.range(of: "<property key=\"\(propertyKey)\">"),
              let close = outer.range(of: "</property>", range: open.upperBound..<outer.endIndex) else { return nil }
        let inner = unescape(String(outer[open.upperBound..<close.lowerBound]))
        return inner.contains("<ccmPreferences") && inner.contains("<prodPref") ? inner : nil
    }

    /// Content range of the first `<tag>…</tag>` inside `scope`.
    static func element(_ tag: String, in s: String, range scope: Range<String.Index>? = nil) -> (whole: Range<String.Index>, content: Range<String.Index>)? {
        let scope = scope ?? s.startIndex..<s.endIndex
        guard let open = s.range(of: "<\(tag)>", range: scope),
              let close = s.range(of: "</\(tag)>", range: open.upperBound..<scope.upperBound) else { return nil }
        return (open.lowerBound..<close.upperBound, open.upperBound..<close.lowerBound)
    }

    static func bool(_ text: Substring) -> Bool? {
        switch text.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true", "1": return true
        case "false", "0": return false
        default: return nil
        }
    }

    /// (global, [(sapcode, value)] in file order) or nil when the XML is not the expected shape.
    static func parse(_ inner: String) -> (global: AutoUpdateValue, removeOldDefault: Bool, apps: [(String, AutoUpdateValue, Bool?)])? {
        guard XMLParser(data: Data(inner.utf8)).parse() else { return nil }
        guard let section = element("autoUpdatePreferences", in: inner) else {
            // Creative Cloud has not written any auto-update preference yet.
            return inner.contains("</prodPref>") ? (nil, false, []) : nil
        }
        let global = element("autoUpdateEnabled", in: inner, range: section.content).flatMap { bool(inner[$0.content]) }
        let removeOldDefault = element("globalAURemoveOld", in: inner, range: section.content).flatMap { bool(inner[$0.content]) } ?? false
        var apps: [(String, AutoUpdateValue, Bool?)] = []
        var cursor = section.content.lowerBound
        while let app = element("app", in: inner, range: cursor..<section.content.upperBound) {
            cursor = app.whole.upperBound
            guard let code = element("sapcode", in: inner, range: app.whole) else { continue }
            apps.append((inner[code.content].trimmingCharacters(in: .whitespaces),
                         element("autoUpdatePreference", in: inner, range: app.whole).flatMap { bool(inner[$0.content]) },
                         element("removeOlderVersions", in: inner, range: app.whole).flatMap { bool(inner[$0.content]) }))
        }
        return (global, removeOldDefault, apps)
    }

    /// Merges every user's file: a value counts as off only when it is off in all files.
    static func read(files: [URL] = prefsFiles()) -> CCState {
        var state = CCState(files: files)
        var globals: [AutoUpdateValue] = []
        var values: [String: [AutoUpdateValue]] = [:]
        var removeOld: [String: Bool] = [:]
        var removeOldDefaults: [Bool] = []
        for file in files {
            guard let outer = try? String(contentsOf: file, encoding: .utf8), let inner = innerXML(outer), let parsed = parse(inner) else {
                state.invalid.append(file); continue
            }
            globals.append(parsed.global)
            removeOldDefaults.append(parsed.removeOldDefault)
            for (code, value, old) in parsed.apps {
                values[code, default: []].append(value)
                // Checked in any user's file counts.
                if old ?? parsed.removeOldDefault { removeOld[code] = true }
            }
        }
        func merge(_ list: [AutoUpdateValue]) -> AutoUpdateValue {
            if list.contains(where: { $0 == true }) { return true }
            if list.contains(where: { $0 == nil }) { return nil }
            return list.isEmpty ? nil : false
        }
        state.global = merge(globals)
        state.removeOldDefault = removeOldDefaults.contains(true)
        state.apps = values.map { CCApp(sapCode: $0.key, value: merge($0.value), removeOld: removeOld[$0.key] ?? false) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return state
    }

    // MARK: Messages

    /// "Photoshop、Camera Raw" style list of the apps that are on.
    static func appList(_ state: CCState, separator: String) -> String {
        state.appsOn.map(\.name).joined(separator: separator)
    }

    static func removeOldList(_ state: CCState, separator: String) -> String {
        state.appsRemovingOld.map(\.name).joined(separator: separator)
    }

    /// Something to report: auto-update on, or (when watched) 以前のバージョンを削除 checked.
    static func alerting(_ state: CCState, watchRemoveOld: Bool) -> Bool {
        state.level == .on || (watchRemoveOld && !state.appsRemovingOld.isEmpty)
    }

    /// A stable key of what is reported, so the same state is not announced twice.
    static func signature(_ state: CCState, watchRemoveOld: Bool = false) -> String {
        let on = state.level == .on ? state.appsOn.map(\.sapCode).joined(separator: ",") : ""
        let old = watchRemoveOld ? state.appsRemovingOld.map(\.sapCode).joined(separator: ",") : ""
        return old.isEmpty ? on : on + "|old:" + old
    }

    /// Whether today's mail is due: something to report, and none sent on this calendar day yet.
    static func mailDue(_ state: CCState, watchRemoveOld: Bool = false, lastSent: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard alerting(state, watchRemoveOld: watchRemoveOld) else { return false }
        guard let lastSent else { return true }
        return !calendar.isDate(lastSent, inSameDayAs: now)
    }

    /// AppleScript string literal (quotes and backslashes escaped; line breaks via `linefeed`).
    static func appleScriptLiteral(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped.components(separatedBy: "\n").joined(separator: "\" & linefeed & \"") + "\""
    }

    /// Sends one plain-text message from Mail's default account.
    static func mailScript(to address: String, subject: String, body: String) -> String {
        """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:\(appleScriptLiteral(subject)), content:\(appleScriptLiteral(body)), visible:false}
            tell newMessage to make new to recipient at end of to recipients with properties {address:\(appleScriptLiteral(address))}
            send newMessage
        end tell
        """
    }

    /// Minimal address check (one @, a dot in the domain, no spaces or quotes).
    static func isValidAddress(_ s: String) -> Bool {
        let parts = s.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix(".") else { return false }
        return !s.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "\\" || $0 == "," || $0 == ";" })
    }
}
