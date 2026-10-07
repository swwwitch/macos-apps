import AppKit
import CoreServices
import UniformTypeIdentifiers

struct Preset {
    let ext: String
    let name: String
    let bundleID: String
    static let all: [Preset] = [
        .init(ext: "ppt", name: "PowerPoint", bundleID: "com.microsoft.Powerpoint"),
        .init(ext: "psd", name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(ext: "indd", name: "InDesign", bundleID: "com.adobe.InDesign"),
        .init(ext: "json", name: "VS Code", bundleID: "com.microsoft.VSCode"),
        .init(ext: "ts", name: "VS Code", bundleID: "com.microsoft.VSCode"),
        .init(ext: "csv", name: "Excel", bundleID: "com.microsoft.Excel"),
        .init(ext: "xlsx", name: "Excel", bundleID: "com.microsoft.Excel"),
        .init(ext: "xls", name: "Excel", bundleID: "com.microsoft.Excel"),
        .init(ext: "doc", name: "Word", bundleID: "com.microsoft.Word"),
        .init(ext: "ai", name: "Illustrator", bundleID: "com.adobe.illustrator"),
        .init(ext: "svg", name: "Illustrator", bundleID: "com.adobe.illustrator"),
        .init(ext: "eps", name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(ext: "gif", name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(ext: "jpg", name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(ext: "png", name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(ext: "webp", name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(ext: "tif", name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(ext: "html", name: "Firefox", bundleID: "org.mozilla.firefox"),
        .init(ext: "jsx", name: "VS Code", bundleID: "com.microsoft.VSCode"),
        .init(ext: "js", name: "VS Code", bundleID: "com.microsoft.VSCode"),
        .init(ext: "css", name: "VS Code", bundleID: "com.microsoft.VSCode"),
        .init(ext: "pdf", name: "Acrobat Pro", bundleID: "com.adobe.Acrobat.Pro"),
        .init(ext: "txt", name: "Jedit Pro", bundleID: "jp.co.artman21.Jedit-Pro"),
        .init(ext: "rtf", name: "Jedit Pro", bundleID: "jp.co.artman21.Jedit-Pro"),
        .init(ext: "md", name: "MacDown", bundleID: "com.uranusjr.macdown")
    ]
}

struct Application: Identifiable, Equatable {
    let url: URL
    let bundleID: String
    let name: String
    var id: String { bundleID }
    init?(url: URL) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        self.url = url
        bundleID = id
        name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
    static func find(_ id: String) -> Application? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).flatMap(Application.init)
    }
    static func dropped(at url: URL) -> Application? {
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.isFileURL, resolved.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: resolved.path),
              let bundle = Bundle(url: resolved), let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else { return nil }
        return Application(url: resolved)
    }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

struct Association: Identifiable {
    let ext: String
    var id: String { ext }
    var type: UTType? { UTType(filenameExtension: ext) }
    var aliases: [String] { AssociationService.aliases(for: ext) }
    var extensionLabel: String { aliases.map { "." + $0 }.joined(separator: " / ") }
    var types: [UTType] {
        var seen = Set<String>()
        return aliases.compactMap { UTType(filenameExtension: $0) }.filter { seen.insert($0.identifier).inserted }
    }
    var current: Application?
    var aliasesDiffer = false
    var proposed: Application?
    var unavailable: String?
    var unavailableBundleID: String?
    var error: String?
    var changed: Bool { proposed != nil && (proposed?.bundleID != current?.bundleID || aliasesDiffer) }
    var displayName: String { proposed?.name ?? unavailable ?? current?.name ?? L("未設定") }
    mutating func reloadCurrent() {
        current = type.flatMap(AssociationService.current)
        aliasesDiffer = current.map { app in types.contains { AssociationService.current(for: $0)?.bundleID != app.bundleID } } ?? false
    }
}

enum AssociationService {
    static func extensionPrecedes(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs == "svg" ? "ai~" : lhs == "indd" ? "eps~" : lhs == "xls" ? "csv~" : lhs
        let right = rhs == "svg" ? "ai~" : rhs == "indd" ? "eps~" : rhs == "xls" ? "csv~" : rhs
        return left < right
    }

    static func canonicalExtension(_ ext: String) -> String {
        switch ext { case "jpeg": return "jpg"; case "htm": return "html"; case "tiff": return "tif"; case "xlsx": return "xls"; case "markdown": return "md"; case "jsx": return "js"; case "docx": return "doc"; case "pptx": return "ppt"; case "tsx": return "ts"; default: return ext }
    }
    static func aliases(for ext: String) -> [String] {
        switch canonicalExtension(ext) { case "jpg": return ["jpg", "jpeg"]; case "html": return ["html", "htm"]; case "tif": return ["tif", "tiff"]; case "xls": return ["xls", "xlsx"]; case "md": return ["md", "markdown"]; case "js": return ["js", "jsx"]; case "doc": return ["doc", "docx"]; case "ppt": return ["ppt", "pptx"]; case "ts": return ["ts", "tsx"]; default: return [ext] }
    }
    static func current(for type: UTType) -> Application? {
        guard let id = LSCopyDefaultRoleHandlerForContentType(type.identifier as CFString, .all)?.takeRetainedValue() as String? else { return nil }
        return Application.find(id)
    }
    // Same Launch Services operation as `duti -s <bundle-id> <extension> all`.
    static func set(_ app: Application, for type: UTType) async throws {
        let result = LSSetDefaultRoleHandlerForContentType(type.identifier as CFString, .all, app.bundleID as CFString)
        guard result == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result)) }
        // `.all` means any suitable opening role when reading. Requiring shell
        // would falsely reject document apps that do not execute this content.
        let confirmed = await verify(expected: app.bundleID) {
            LSCopyDefaultRoleHandlerForContentType(type.identifier as CFString, .all)?.takeRetainedValue() as String?
        }
        guard confirmed else {
            throw NSError(domain: "DutiGUI", code: 1, userInfo: [NSLocalizedDescriptionKey: L("既定アプリの反映を確認できませんでした。再読み込みして確認してください。")])
        }
    }
    static func verify(expected: String, attempts: Int = 6, delay: UInt64 = 100_000_000, read: () -> String?) async -> Bool {
        for attempt in 0..<max(1, attempts) {
            if read() == expected { return true }
            if attempt + 1 < attempts {
                do { try await Task.sleep(nanoseconds: delay) }
                catch { return false }
            }
        }
        return false
    }
    static func normalized(_ value: String) -> String? {
        let ext = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !ext.isEmpty, ext.count <= 64, ext.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }) else { return nil }
        return ext
    }
}

enum AssociationSortColumn { case fileExtension, application }

@MainActor
final class AssociationStore: ObservableObject {
    @Published var rows: [Association] = []
    @Published var query = ""
    @Published var status = ""
    @Published var applying = false
    @Published var onlyChanges = false
    @Published var selectedCategory: AssociationCategory = .all
    @Published var sortColumn: AssociationSortColumn?
    @Published var sortAscending = true
    @Published var presetError: String?
    private let savedKey = "additionalExtensions"
    private let removedKey = "removedExtensions"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let extra = defaults.stringArray(forKey: savedKey) ?? []
        let removed = Set(defaults.stringArray(forKey: removedKey) ?? [])
        let extensions = Array(Set((Preset.all.map(\.ext) + extra).map(AssociationService.canonicalExtension)).subtracting(removed)).sorted(by: AssociationService.extensionPrecedes)
        rows = extensions.map { ext in
            var row = Association(ext: ext)
            row.reloadCurrent()
            return row
        }
        status = L("現在の設定を読み込みました。")
    }
    func sort(by column: AssociationSortColumn) {
        if sortColumn == column { sortAscending.toggle() }
        else { sortColumn = column; sortAscending = true }
    }
    var visible: [Association] {
        let filtered = rows.filter { row in
            (selectedCategory == .all || AssociationCategory.category(for: row.ext) == selectedCategory) &&
            (!onlyChanges || row.changed || row.unavailable != nil || row.error != nil) &&
            (query.isEmpty || ("\(row.extensionLabel) \(row.displayName) \(row.current?.name ?? "")").localizedCaseInsensitiveContains(query))
        }
        guard let sortColumn else { return filtered }
        return filtered.sorted { lhs, rhs in
            let comparison: ComparisonResult
            switch sortColumn {
            case .fileExtension:
                comparison = lhs.ext.localizedStandardCompare(rhs.ext)
            case .application:
                let names = lhs.displayName.localizedStandardCompare(rhs.displayName)
                comparison = names == .orderedSame ? lhs.ext.localizedStandardCompare(rhs.ext) : names
            }
            return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }
    var pending: Int { rows.filter(\.changed).count }
    var missing: Int { rows.filter { $0.unavailable != nil }.count }
    func loadPreset() {
        for index in rows.indices {
            guard let preset = Preset.all.first(where: { $0.ext == rows[index].ext }) else { continue }
            rows[index].proposed = Application.find(preset.bundleID)
            rows[index].unavailable = rows[index].proposed == nil ? preset.name : nil
            rows[index].unavailableBundleID = rows[index].proposed == nil ? preset.bundleID : nil
            rows[index].error = nil
        }
        status = L("初期プリセット%@種類を読み込みました。変更はまだ適用されていません。", String(describing: Preset.all.count))
    }
    func refresh(discard: Bool = false) {
        for index in rows.indices {
            rows[index].reloadCurrent()
            if let proposed = rows[index].proposed, proposed.bundleID == rows[index].current?.bundleID, !rows[index].aliasesDiffer {
                rows[index].proposed = nil
                rows[index].error = nil
            }
            if discard {
                rows[index].proposed = nil
                rows[index].unavailable = nil
                rows[index].unavailableBundleID = nil
                rows[index].error = nil
            }
        }
        status = discard ? L("変更を取り消しました。") : L("現在の設定を再読み込みしました。")
    }
    func choose(_ app: Application, for ext: String) {
        guard let i = rows.firstIndex(where: { $0.ext == ext }) else { return }
        rows[i].proposed = app
        rows[i].unavailable = nil
        rows[i].unavailableBundleID = nil
        rows[i].error = nil
        status = L(".%@ の変更を準備しました。", String(describing: ext))
    }
    func add(_ input: String) -> Bool {
        guard let normalized = AssociationService.normalized(input) else { return false }
        let ext = AssociationService.canonicalExtension(normalized)
        guard !rows.contains(where: { $0.ext == ext }), let type = UTType(filenameExtension: ext) else { return false }
        rows.append(Association(ext: ext, current: AssociationService.current(for: type)))
        rows[rows.count - 1].reloadCurrent()
        rows.sort { AssociationService.extensionPrecedes($0.ext, $1.ext) }
        persistExtensions()
        query = ext
        onlyChanges = false
        if selectedCategory != .all { selectedCategory = AssociationCategory.category(for: ext) }
        return true
    }
    func removeExtensions(_ extensions: Set<String>) {
        guard !applying else { return }
        let canonical = Set(extensions.map(AssociationService.canonicalExtension))
        rows.removeAll { canonical.contains($0.ext) }
        var removed = Set(defaults.stringArray(forKey: removedKey) ?? [])
        removed.formUnion(canonical)
        defaults.set(removed.sorted(), forKey: removedKey)
        persistExtensions()
        status = L("拡張子を一覧から削除しました。")
    }
    private func persistExtensions() {
        defaults.set(rows.map(\.ext).filter { ext in !Preset.all.contains(where: { $0.ext == ext }) }, forKey: savedKey)
        var removed = Set(defaults.stringArray(forKey: removedKey) ?? [])
        removed.subtract(rows.map(\.ext))
        defaults.set(removed.sorted(), forKey: removedKey)
    }
    var affectedExtensions: String {
        let types = Set(rows.filter(\.changed).compactMap { $0.type?.identifier })
        return rows.filter { $0.type.map { types.contains($0.identifier) } ?? false }.map(\.extensionLabel).joined(separator: ", ")
    }
    func importPreset(_ file: PresetFile) {
        for entry in file.associations {
            if !rows.contains(where: { $0.ext == entry.ext }) {
                let type = UTType(filenameExtension: entry.ext)
                rows.append(Association(ext: entry.ext, current: type.flatMap(AssociationService.current)))
                rows[rows.count - 1].reloadCurrent()
            }
            guard let i = rows.firstIndex(where: { $0.ext == entry.ext }) else { continue }
            let app = Application.find(entry.bundleID)
            rows[i].proposed = app
            rows[i].unavailable = app == nil ? entry.appName ?? entry.bundleID : nil
            rows[i].unavailableBundleID = app == nil ? entry.bundleID : nil
            rows[i].error = nil
        }
        rows.sort { AssociationService.extensionPrecedes($0.ext, $1.ext) }
        persistExtensions()
        query = ""
        onlyChanges = false
        selectedCategory = .all
        status = L("「%@」%@種類を読み込みました。変更はまだ適用されていません。", String(describing: file.name), String(describing: file.associations.count))
    }
    func openPreset() {
        let panel = NSOpenPanel()
        panel.title = L("プリセットを読み込む")
        panel.allowedContentTypes = [.plainText, .shellScript]
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = false
        panel.prompt = L("読み込む")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_048_576 else { throw NSError(domain: "dutiGUI.Preset", code: 1, userInfo: [NSLocalizedDescriptionKey: L("ファイルが大きすぎます（上限1MB）。")]) }
            let file = try PresetFile.decode(Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent)
            importPreset(file)
        } catch { presetError = error.localizedDescription }
    }
    func savePreset() {
        let entries: [PresetFile.Entry] = rows.compactMap { row in
            if let id = row.unavailableBundleID { return .init(ext: row.ext, bundleID: id, appName: row.unavailable) }
            guard let app = row.proposed ?? row.current else { return nil }
            return .init(ext: row.ext, bundleID: app.bundleID, appName: app.name)
        }
        guard !entries.isEmpty else { presetError = L("保存できる関連付けがありません。"); return }
        let panel = NSSavePanel()
        panel.title = L("プリセットを保存")
        panel.message = L("一覧の関連付けを保存します。変更予定のアプリも含まれます。")
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "ExtensionLinker-preset.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let file = PresetFile(name: url.deletingPathExtension().lastPathComponent, associations: entries)
            let data = try file.encoded()
            // Ensure our export can be loaded back without losing ambiguous aliases.
            _ = try PresetFile.decode(data)
            try data.write(to: url, options: .atomic)
            status = L("%@種類を「%@」に保存しました。", String(describing: entries.count), String(describing: url.lastPathComponent))
        } catch { presetError = error.localizedDescription }
    }
    func apply() {
        guard !applying else { return }
        applying = true
        Task { @MainActor in
            var succeeded = 0
            var failed = 0
            // Snapshot: refresh of aliases must not remove pending work halfway through.
            let changes = rows.filter(\.changed)
            for row in changes {
                guard let i = rows.firstIndex(where: { $0.ext == row.ext }), let app = row.proposed, !row.types.isEmpty else { continue }
                do {
                    for type in row.types { try await AssociationService.set(app, for: type) }
                    rows[i].proposed = nil
                    rows[i].error = nil
                    succeeded += 1
                } catch {
                    rows[i].error = error.localizedDescription
                    failed += 1
                }
                await Task.yield()
            }
            for i in rows.indices { rows[i].reloadCurrent() }
            status = L("%@件を適用", String(describing: succeeded)) + (failed > 0 ? L("・%@件でエラー。行の警告を確認してください。", String(describing: failed)) : L("しました。"))
            applying = false
        }
    }
}
