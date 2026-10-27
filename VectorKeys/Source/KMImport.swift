import Foundation

/// Reads a Keyboard Maestro export (.kmmacros), accepting only script-file and embedded JSX steps.
/// A macro containing any other action is skipped in full; never import only part of its behavior.
/// Only the values written in the macro are read (a script path, the user's own code); the plug-ins' scripts
/// (sttk3 MaestroPack) are neither read nor copied, and VectorKeys runs the script with its own do javascript.
enum KMImport {
    enum Part: Equatable {
        case file(String)
        /// ExtendScript written in the macro itself (Ai Execute Jsx Text); saved as a .jsx file on import.
        case code(String)
    }
    struct Item: Equatable {
        var name: String
        /// The Keyboard Maestro group, used as the category.
        var group: String
        /// The macro's UID in Keyboard Maestro, to turn the original off later.
        var uid: String?
        var hotkey: Hotkey?
        var enabled: Bool
        var parts: [Part]
    }
    struct Skipped: Equatable {
        var name: String
        var reason: Reason
    }
    enum Reason: String, Error, Equatable {
        case notScript          // no step VectorKeys can run (keys, other apps…)
        case severalSteps       // some steps VectorKeys cannot run
        case variable           // the path or code uses %…% tokens
        case notJSX             // a file that is not .jsx / .js / .jsxbin
    }

    /// Exports are an array of groups, each with Macros; a dictionary holding MacroGroups is read the same way.
    static func parse(_ data: Data) -> (items: [Item], skipped: [Skipped])? {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return nil }
        let groups = (root as? [[String: Any]]) ?? ((root as? [String: Any])?["MacroGroups"] as? [[String: Any]]) ?? []
        guard !groups.isEmpty else { return nil }
        var items: [Item] = [], skipped: [Skipped] = []
        for group in groups {
            let groupName = group["Name"] as? String ?? ""
            for macro in group["Macros"] as? [[String: Any]] ?? [] {
                let name = macro["Name"] as? String ?? ""
                switch parts(of: macro["Actions"] as? [[String: Any]] ?? []) {
                case .success(let parts):
                    items.append(Item(name: name, group: groupName, uid: macro["UID"] as? String, hotkey: hotkey(of: macro), enabled: bool(macro["IsActive"], default: true), parts: parts))
                case .failure(let reason):
                    skipped.append(Skipped(name: name, reason: reason))
                }
            }
        }
        return (items, skipped)
    }

    /// Every step of a macro, in order. Comments and turned-off actions do not count.
    private static func parts(of actions: [[String: Any]]) -> Result<[Part], Reason> {
        let steps = actions.filter { bool($0["IsActive"], default: true) && $0["MacroActionType"] as? String != "Comment" }
        let found = steps.map { part($0) }
        if found.allSatisfy({ $0 == nil }) { return .failure(.notScript) }
        if found.contains(where: { $0 == nil }) { return .failure(.severalSteps) }
        var parts: [Part] = []
        for part in found.compactMap({ $0 }) {
            switch part {
            case .file(let path):
                if path.contains("%") { return .failure(.variable) }
                if !ScriptEntry.accepts(URL(fileURLWithPath: path)) { return .failure(.notJSX) }
                parts.append(.file((path as NSString).expandingTildeInPath))
            case .code(let code):
                if Tokens.contains(code) { return .failure(.variable) }
                parts.append(part)
            }
        }
        return .success(parts)
    }

    private static func part(_ action: [String: Any]) -> Part? {
        switch action["MacroActionType"] as? String {
        case "PlugIn":
            let parameters = action["PlugInParameters"] as? [String: Any] ?? [:]
            switch action["PlugInFolderName"] as? String {
            case "Ai Execute Script File": return (parameters["Script path"] as? String).map(Part.file)
            case "Ai Execute Jsx Text": return (parameters["Jsx code"] as? String).map(Part.code)
            default: return nil
            }
        case "Open1File":
            // A script opened with Illustrator runs it.
            let app = action["Application"] as? [String: Any]
            guard let bundle = app?["BundleIdentifier"] as? String, bundle.lowercased().hasPrefix("com.adobe.illustrator") else { return nil }
            return (action["Path"] as? String).map(Part.file)
        default:
            return nil
        }
    }

    /// The first hot key trigger. Keyboard Maestro stores Carbon key codes and modifiers, the same numbers as Hotkey.
    /// "Tapped" / "TappedOnly" with TapCount 2 is a double press; three taps and more are left out.
    static func hotkey(of macro: [String: Any]) -> Hotkey? {
        for trigger in macro["Triggers"] as? [[String: Any]] ?? [] where trigger["MacroTriggerType"] as? String == "HotKey" {
            guard let code = (trigger["KeyCode"] as? NSNumber)?.uint32Value, code != 0xFFFF else { continue }
            let modifiers = (trigger["Modifiers"] as? NSNumber)?.uint32Value ?? 0
            let fire = trigger["FireType"] as? String ?? "Pressed"
            let count = (trigger["TapCount"] as? NSNumber)?.intValue ?? 1
            if fire.hasPrefix("Tapped") && count > 2 { continue }
            return Hotkey(code: code, modifiers: modifiers & (256 | 512 | 2048 | 4096), taps: fire.hasPrefix("Tapped") && count == 2 ? 2 : nil)
        }
        return nil
    }

    static func bool(_ value: Any?, default fallback: Bool) -> Bool {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return fallback
    }

    /// A file name for saved code: the macro name without characters a file name cannot hold.
    static func fileName(for name: String, taken: Set<String>) -> String {
        var base = name.replacingOccurrences(of: "/", with: "／").replacingOccurrences(of: ":", with: "：")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty || base.hasPrefix(".") { base = "Script" + base }
        var candidate = base + ".jsx", number = 2
        while taken.contains(candidate.lowercased()) { candidate = "\(base) \(number).jsx"; number += 1 }
        return candidate
    }
}

/// Keyboard Maestro tokens such as %Variable%name% or %TriggerValue% (a bare 50% is not one).
enum Tokens {
    static func contains(_ text: String) -> Bool {
        text.range(of: #"%(Variable|TriggerValue|ExecutingMacro|SystemClipboard|CurrentClipboard|ApplicationPath|FrontWindowName|FinderSelection|Calculate|ICUDateTime|LocalVariable|InstanceVariable)%"#, options: .regularExpression) != nil
    }
}
