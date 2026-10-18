import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Ported from ExtensionLinker 0.2.29 (「アプリの版」), limited to Illustrator.

/// One installed Illustrator version (the yearly versions share the bundle ID com.adobe.illustrator).
struct InstalledVersion: Identifiable, Hashable {
    /// CFBundleVersion: what Launch Services matches LSHandlerPreferredVersions against.
    let version: String
    let shortVersion: String
    /// Copies with the same version (e.g. 「Adobe Illustrator 2024」 and 「Adobe Illustrator 2024 en」) cannot be told apart by Launch Services.
    let urls: [URL]
    var id: String { version }
    var label: String {
        let names = urls.map(VersionPinning.versionedName).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return names.joined(separator: " / ") + "（\(shortVersion)）"
    }
}

/// Opens Illustrator's file types with a chosen installed version.
/// The public API (LSSetDefaultRoleHandlerForContentType, NSWorkspace.setDefaultApplication) stores the bundle ID only,
/// with the version "-" (newest). The version is written as LSHandlerPreferredVersions into Launch Services' own
/// record, and lsd is restarted to read it (measured on macOS 26: honored by Finder's open and urlForApplication(toOpen:)).
enum VersionPinning {
    static let bundleID = "com.adobe.illustrator"
    static let anyVersion = "-"
    static var recordURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist")
    }
    static var backupFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/VectorMate/LaunchServicesBackups", isDirectory: true)
    }

    /// The enclosing folder name when it names the version (「Adobe Illustrator 2026」 for 「Adobe Illustrator.app」), otherwise the app name.
    static func versionedName(_ url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        let folder = url.deletingLastPathComponent().lastPathComponent
        return folder != name && folder.hasPrefix(name + " ") ? folder : name
    }

    /// Installed versions, newest first. Copies in the Trash are left out.
    static func versions(of bundleID: String = bundleID) -> [InstalledVersion] {
        let urls = (LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL] ?? [])
            .filter { !$0.path.contains("/.Trash/") }
        var grouped: [String: (short: String, urls: [URL])] = [:]
        for url in urls {
            guard let info = Bundle(url: url)?.infoDictionary, let version = info["CFBundleVersion"] as? String else { continue }
            grouped[version, default: ((info["CFBundleShortVersionString"] as? String) ?? version, [])].urls.append(url)
        }
        return grouped.map { InstalledVersion(version: $0.key, shortVersion: $0.value.short, urls: $0.value.urls.sorted { $0.path < $1.path }) }
            .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }
    static func bundleVersion(of url: URL) -> String? { Bundle(url: url)?.infoDictionary?["CFBundleVersion"] as? String }

    /// Preferred version per content type in the record; "-" or no entry means the newest.
    static func pinnedVersions(for types: [String]) -> [String: String] {
        guard let handlers = try? readRecord().handlers else { return [:] }
        var result: [String: String] = [:]
        for type in types {
            let key = recordKey(for: type)
            let entry = handlers.first { matches($0, key) }
            result[type] = (entry?["LSHandlerPreferredVersions"] as? [String: Any])?["LSHandlerRoleAll"] as? String ?? anyVersion
        }
        return result
    }

    /// Writes the version for all types at once, restarts lsd once and confirms what Launch Services now opens.
    /// `version` nil: back to the newest. On a failed confirmation the previous record is put back.
    static func apply(version: String?, types: [String]) async throws {
        let original = try Data(contentsOf: recordURL)
        var record = try readRecord(original)
        try checkNothingPending(record.handlers)
        let now = Int(Date().timeIntervalSinceReferenceDate)
        for type in types {
            let key = recordKey(for: type)
            var entry = record.handlers.first { matches($0, key) } ?? key.newEntry
            record.handlers.removeAll { matches($0, key) }
            // lsd itself writes bundle IDs in lowercase.
            entry["LSHandlerRoleAll"] = bundleID.lowercased()
            entry["LSHandlerPreferredVersions"] = ["LSHandlerRoleAll": version ?? anyVersion]
            entry["LSHandlerModificationDate"] = now
            record.handlers.append(entry)
        }
        record.root["LSHandlers"] = record.handlers
        let data = try PropertyListSerialization.data(fromPropertyList: record.root, format: record.format, options: 0)
        try backUp(original)
        try data.write(to: recordURL, options: .atomic)
        await restartLaunchServices()
        guard await confirm(version: version, types: types) else {
            try? original.write(to: recordURL, options: .atomic)
            await restartLaunchServices()
            throw failure(2, "version.failConfirm")
        }
    }

    private static func failure(_ code: Int, _ key: String) -> NSError {
        NSError(domain: "VectorMate", code: code, userInfo: [NSLocalizedDescriptionKey: L(key)])
    }

    /// Declared types are recorded by identifier; dynamic ones (dyn.…, e.g. .ait without a declaring app) by filename extension.
    private struct RecordKey {
        let field: String
        let value: String
        var newEntry: [String: Any] {
            field == "LSHandlerContentTag" ? ["LSHandlerContentTagClass": "public.filename-extension", field: value] : [field: value]
        }
    }
    private static func recordKey(for type: String) -> RecordKey {
        if let utType = UTType(type), utType.isDynamic, let ext = utType.preferredFilenameExtension {
            return RecordKey(field: "LSHandlerContentTag", value: ext)
        }
        return RecordKey(field: "LSHandlerContentType", value: type)
    }
    private static func matches(_ entry: [String: Any], _ key: RecordKey) -> Bool {
        guard (entry[key.field] as? String)?.caseInsensitiveCompare(key.value) == .orderedSame else { return false }
        return key.field == "LSHandlerContentType" || entry["LSHandlerContentTagClass"] as? String == "public.filename-extension"
    }
    /// The content type an entry stands for.
    private static func contentType(of entry: [String: Any]) -> String? {
        if let type = entry["LSHandlerContentType"] as? String { return type }
        guard entry["LSHandlerContentTagClass"] as? String == "public.filename-extension", let ext = entry["LSHandlerContentTag"] as? String else { return nil }
        return UTType(filenameExtension: ext)?.identifier
    }

    private struct Record {
        var root: [String: Any]
        var handlers: [[String: Any]]
        var format: PropertyListSerialization.PropertyListFormat
    }
    private static func readRecord(_ data: Data? = nil) throws -> Record {
        var format = PropertyListSerialization.PropertyListFormat.binary
        let data = try data ?? Data(contentsOf: recordURL)
        guard let root = try PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any] else {
            throw failure(3, "version.failRead")
        }
        return Record(root: root, handlers: root["LSHandlers"] as? [[String: Any]] ?? [], format: format)
    }
    /// lsd keeps recent changes in memory for a while (measured: minutes) and drops them when it is restarted.
    /// A record that disagrees with what Launch Services answers means such changes are waiting; write nothing then.
    private static func checkNothingPending(_ handlers: [[String: Any]]) throws {
        for entry in handlers {
            guard let type = contentType(of: entry), let recorded = entry["LSHandlerRoleAll"] as? String,
                  NSWorkspace.shared.urlForApplication(withBundleIdentifier: recorded) != nil else { continue }
            let current = LSCopyDefaultRoleHandlerForContentType(type as CFString, .all)?.takeRetainedValue() as String?
            if current?.caseInsensitiveCompare(recorded) != .orderedSame { throw failure(4, "version.failPending") }
        }
    }
    /// Keeps the 10 newest copies of the record before each change.
    private static func backUp(_ data: Data) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        try data.write(to: backupFolder.appendingPathComponent("launchservices.secure-\(formatter.string(from: Date())).plist"), options: .atomic)
        let old = (try? fm.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "plist" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }.dropFirst(10) ?? []
        for url in old { try? fm.removeItem(at: url) }
    }
    private static func restartLaunchServices() async {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = ["lsd"]
            try? process.run()
            process.waitUntilExit()
        }.value
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    private static func confirm(version: String?, types: [String]) async -> Bool {
        // Right after the restart this process may still answer from the old record, so wait for the expected version
        // (for "-", the newest one, which Launch Services picks).
        let expected = version ?? versions().first?.version
        for attempt in 0..<20 {
            let done = types.allSatisfy { type in
                guard let utType = UTType(type), let url = NSWorkspace.shared.urlForApplication(toOpen: utType),
                      Bundle(url: url)?.bundleIdentifier?.caseInsensitiveCompare(bundleID) == .orderedSame else { return false }
                return expected.map { bundleVersion(of: url) == $0 } ?? true
            }
            if done { return true }
            if attempt < 19 { try? await Task.sleep(nanoseconds: 250_000_000) }
        }
        return false
    }
}

/// 「関連付け」タブ（メインウインドウ）: switches the checked extensions to one installed Illustrator version at once.
@MainActor
final class VersionSwitchModel: ObservableObject {
    static let extensions = ["ai", "ait", "eps", "svg"]
    struct Row: Identifiable {
        let ext: String
        let type: String
        /// Version label that opens it now, or the app's name when another app opens it.
        let current: String
        /// Opened by Illustrator (any version) now.
        let illustrator: Bool
        /// Recorded preferred version ("-": newest).
        let pinned: String
        var id: String { ext }
    }
    @Published var versions: [InstalledVersion] = []
    @Published var rows: [Row] = []
    /// Checked extensions (saved; all by default).
    @Published var checked: Set<String> { didSet { UserDefaults.standard.set(Array(checked).sorted(), forKey: "versionExtensions") } }
    @Published var choice = VersionPinning.anyVersion
    @Published var applying = false
    @Published var status = ""
    @Published var error: String?

    init() {
        checked = Set(UserDefaults.standard.stringArray(forKey: "versionExtensions") ?? Self.extensions)
    }
    var targets: [Row] { rows.filter { checked.contains($0.ext) } }
    var changed: Bool { targets.contains { !$0.illustrator || $0.pinned != choice } }

    /// `keepChoice`: a reload on returning to the app keeps a version picked but not yet applied.
    func reload(keepChoice: Bool = false) {
        let picked = keepChoice ? choice : nil
        versions = VersionPinning.versions()
        let types = Self.extensions.compactMap { ext in UTType(filenameExtension: ext).map { (ext, $0) } }
        let pinned = VersionPinning.pinnedVersions(for: types.map(\.1.identifier))
        rows = types.map { ext, type in
            let handler = LSCopyDefaultRoleHandlerForContentType(type.identifier as CFString, .all)?.takeRetainedValue() as String?
            let illustrator = handler?.caseInsensitiveCompare(VersionPinning.bundleID) == .orderedSame
            let url = NSWorkspace.shared.urlForApplication(toOpen: type)
            let current: String
            if illustrator, let url {
                current = versions.first { $0.urls.contains(url) || $0.version == VersionPinning.bundleVersion(of: url) }?.label ?? VersionPinning.versionedName(url)
            } else {
                current = url.map(VersionPinning.versionedName) ?? "—"
            }
            return Row(ext: ext, type: type.identifier, current: current, illustrator: illustrator, pinned: pinned[type.identifier] ?? VersionPinning.anyVersion)
        }
        let known = Set(versions.map(\.version) + [VersionPinning.anyVersion])
        let recorded = Set(rows.filter(\.illustrator).map(\.pinned))
        let fallback = recorded.count == 1 && known.contains(recorded.first!) ? recorded.first! : VersionPinning.anyVersion
        choice = picked.flatMap { known.contains($0) ? $0 : nil } ?? fallback
    }
    func apply() {
        let targets = targets
        guard changed, !applying else { return }
        applying = true
        status = L("version.applying")
        let version = choice == VersionPinning.anyVersion ? nil : choice
        Task {
            do {
                try await VersionPinning.apply(version: version, types: targets.map(\.type))
                status = String(format: L("version.done"), targets.count)
            } catch {
                self.error = error.localizedDescription
                status = ""
            }
            reload()
            applying = false
        }
    }
}

struct VersionSwitchView: View {
    @StateObject private var model = VersionSwitchModel()
    @State private var confirm = false
    var body: some View {
        FeaturePage(title: L("version.title")) {
            if model.versions.count < 2 {
                Text(L("version.none")).foregroundColor(.secondary)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(model.rows) { row in
                        GridRow {
                            Toggle("." + row.ext, isOn: Binding(get: { model.checked.contains(row.ext) },
                                                               set: { if $0 { model.checked.insert(row.ext) } else { model.checked.remove(row.ext) } }))
                            Text(row.current).foregroundColor(.secondary)
                        }
                    }
                }
                HStack {
                    Text(L("version.open"))
                    Picker(L("version.open"), selection: $model.choice) {
                        Text(L("version.newest")).tag(VersionPinning.anyVersion)
                        Divider()
                        ForEach(model.versions) { version in Text(version.label).tag(version.version) }
                    }
                    .labelsHidden().frame(maxWidth: 320, alignment: .leading)
                }.padding(.top, 4)
                HStack {
                    Text(model.status).font(.caption).foregroundColor(.secondary).lineLimit(2)
                    Spacer()
                    Button(L("reload")) { model.reload() }
                    Button(L("version.apply")) { confirm = true }
                        .buttonStyle(.borderedProminent).disabled(!model.changed)
                }
                Note(text: L("version.hint"))
            }
            Note(text: L("version.detail"))
        }
        .disabled(model.applying)
        .onAppear { model.reload() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !model.applying { model.reload(keepChoice: true) }
        }
        .alert(L("version.confirmTitle"), isPresented: $confirm) {
            Button(L("cancel"), role: .cancel) { }
            Button(L("version.apply")) { model.apply() }
        } message: {
            Text(String(format: L("version.confirmMessage"), model.targets.map { "." + $0.ext }.joined(separator: ", ")))
        }
        .alert(L("version.failTitle"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { }
        } message: { Text(model.error ?? "") }
    }
}
