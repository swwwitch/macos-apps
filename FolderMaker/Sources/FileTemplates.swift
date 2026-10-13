import Foundation

/// Starting contents for files made by projects (after Post Haste's bundled blank documents).
/// User folder: ~/Library/Application Support/FolderMaker/Templates, or <shared folder>/FolderMaker/Templates. The bundled templates are copied in
/// when missing; files the user put or changed there are never overwritten.
enum FileTemplates {
    /// In the library folder (Application Support, or the shared folder chosen in Settings).
    static var folder: URL { Library.folder.appendingPathComponent("Templates", isDirectory: true) }
    static var bundled: URL? { Bundle.main.resourceURL?.appendingPathComponent("FileTemplates", isDirectory: true) }

    /// Copies bundled templates that are not in the folder yet. Returns how many were added.
    @discardableResult
    static func installDefaults(into folder: URL = folder, from source: URL? = bundled) -> Int {
        guard let source, let names = try? FileManager.default.contentsOfDirectory(atPath: source.path) else { return 0 }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var added = 0
        for name in names where !name.hasPrefix(".") {
            let target = folder.appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: target.path) else { continue }
            if (try? FileManager.default.copyItem(at: source.appendingPathComponent(name), to: target)) != nil { added += 1 }
        }
        return added
    }

    enum Lookup: Equatable { case template(URL), missing(String), none }

    /// Explicit name (from "index.html < html5.html") → same file name → template.<ext>. An explicit name that is
    /// not there is reported, and the file is made empty.
    static func lookup(fileName: String, explicit: String?, in folder: URL = folder) -> Lookup {
        func existing(_ name: String) -> URL? {
            let url = folder.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue ? url : nil
        }
        if let explicit, !explicit.isEmpty { return existing(explicit).map(Lookup.template) ?? .missing(explicit) }
        if let url = existing(fileName) { return .template(url) }
        let ext = (fileName as NSString).pathExtension
        if !ext.isEmpty, let url = existing("template." + ext) { return .template(url) }
        return .none
    }

    /// Text templates (UTF-8, under 1 MB) get {{project}}, {{file}} and {{date}} filled in; others are copied as is.
    /// Never replaces an existing file.
    static func write(to target: URL, template: URL?, project: String, date: Date = Date()) throws {
        guard let template else { return try Data().write(to: target, options: .withoutOverwriting) }
        let data = try Data(contentsOf: template)
        if data.count < 1_000_000, var text = String(data: data, encoding: .utf8) {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            text = text.replacingOccurrences(of: "{{project}}", with: project)
                .replacingOccurrences(of: "{{file}}", with: target.deletingPathExtension().lastPathComponent)
                .replacingOccurrences(of: "{{date}}", with: formatter.string(from: date))
            try Data(text.utf8).write(to: target, options: .withoutOverwriting)
        } else {
            try data.write(to: target, options: .withoutOverwriting)
        }
    }
}
