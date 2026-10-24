import Foundation

/// Display groups follow the supplied Keynote guide. Execution categories and saved command IDs stay unchanged.
enum ShortcutSection: String, CaseIterable, Codable {
    case general, navigation, textSelection, textFormat, findComments, objects, editableShapes
    case tables, chartData, formulas, navigator, lightTable, presentation, video
    case transition, animation, export, sweeper

    var title: String { NSLocalizedString("catalog.category." + rawValue, comment: "") }
    var commands: [KeynoteCommand] {
        KeynoteCommand.availableCommands.filter { $0.shortcutSection == self }
    }
}

extension KeynoteCommand {
    var shortcutSection: ShortcutSection {
        switch self {
        case .newDocument, .saveAs, .zoomIn, .zoomOut, .zoomToSelection, .zoomToContent, .fitSlide,
             .objectList, .inspectorFormat, .inspectorAnimate, .inspectorDocument, .hideInspector,
             .layoutGuides, .guides, .clearGuides: return .general
        case .previousSlide, .nextSlide, .firstSlide, .lastSlide, .goToSlide: return .navigation
        case .newSlide, .skipSlide, .collapse, .expand, .collapseAll, .expandAll: return .navigator
        case .play, .playInWindow, .rehearse: return .presentation
        default:
            switch category {
            case .text: return .textFormat
            case .transition: return .transition
            case .animation: return .animation
            case .export: return .export
            case .sweeper: return .sweeper
            default: return .objects
            }
        }
    }
}

struct NativeShortcut: Codable, Identifiable {
    let id: String
    let section: ShortcutSection
    let title: String
    let shortcut: String
    let commandID: String?
    var command: KeynoteCommand? { commandID.flatMap(KeynoteCommand.init(rawValue:)) }
}

struct ShortcutRow: Identifiable {
    let id: String
    let section: ShortcutSection
    let native: NativeShortcut?
    let command: KeynoteCommand?
    var title: String {
        native?.title ?? command.map { NSLocalizedString("command." + $0.rawValue, comment: "") } ?? ""
    }
    var nativeLabel: String? { native.map { ShortcutSearch.displayKey($0.shortcut) } }

    func matches(_ query: String, currentKey: String?) -> Bool {
        var terms = [title, section.title, native?.shortcut ?? "", currentKey ?? ""]
        if let command { terms.append(NSLocalizedString("command." + command.rawValue, comment: "")) }
        return ShortcutSearch.matches(query, in: terms)
    }
}

enum ShortcutScope: String, CaseIterable {
    case all, maestro, native
    var title: String { NSLocalizedString("catalog.scope." + rawValue, comment: "") }
    func includes(_ row: ShortcutRow) -> Bool {
        switch self {
        case .all: return true
        case .maestro: return row.command != nil
        case .native: return row.native != nil
        }
    }
}

/// Search accepts both modifier names and the symbols displayed in the app.
enum ShortcutSearch {
    private static let modifierExpression = try! NSRegularExpression(pattern: "[⌃⌥⇧⌘]+")
    static func displayKey(_ value: String) -> String {
        value.replacingOccurrences(of: "Command＋", with: "⌘")
            .replacingOccurrences(of: "Option＋", with: "⌥")
            .replacingOccurrences(of: "Shift＋", with: "⇧")
            .replacingOccurrences(of: "Control＋", with: "⌃")
    }
    static func normalized(_ value: String) -> String {
        var result = value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        for (name, symbol) in [("command", "⌘"), ("cmd", "⌘"), ("option", "⌥"), ("alt", "⌥"),
                               ("control", "⌃"), ("ctrl", "⌃"), ("shift", "⇧")] {
            result = result.replacingOccurrences(of: name, with: symbol)
        }
        result = result.filter { !$0.isWhitespace && $0 != "+" && $0 != "＋" }
        // Modifier order varies between the guide, Carbon and typed searches.
        for match in modifierExpression.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let symbols = Set(result[range])
            result.replaceSubrange(range, with: "⌃⌥⇧⌘".filter { symbols.contains($0) })
        }
        return result
    }
    static func matches(_ query: String, in terms: [String]) -> Bool {
        let needle = normalized(query)
        return needle.isEmpty || terms.contains { normalized($0).contains(needle) }
    }
}

struct ShortcutCatalog {
    let native: [NativeShortcut]
    let rows: [ShortcutRow]
    let unavailable: Bool

    init(native: [NativeShortcut], unavailable: Bool = false) {
        self.native = native
        self.unavailable = unavailable
        let mapped = Set(native.compactMap(\.command))
        // The guide repeats the Color window and Object List in multiple chapters.
        // Display identical operations/keys once, keeping the first (original category order).
        var seen = Set<String>()
        let unique = native.filter { seen.insert($0.title + "\u{0}" + $0.shortcut).inserted }
        rows = unique.map { ShortcutRow(id: "native." + $0.id, section: $0.section, native: $0, command: $0.command) }
            + KeynoteCommand.availableCommands.filter { !mapped.contains($0) }.map {
                ShortcutRow(id: "maestro." + $0.rawValue, section: $0.shortcutSection, native: nil, command: $0)
            }
    }

    init(contentsOf url: URL) throws {
        let data = try JSONDecoder().decode([NativeShortcut].self, from: Data(contentsOf: url))
        guard !data.isEmpty, Set(data.map(\.id)).count == data.count,
              data.allSatisfy({ !$0.title.isEmpty && !$0.shortcut.isEmpty && ($0.commandID == nil || $0.command != nil) }),
              Set(data.compactMap(\.commandID)).count == data.compactMap(\.commandID).count,
              data.allSatisfy({ $0.command == nil || $0.command!.shortcutSection == $0.section }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.init(native: data)
    }

    static let bundled: ShortcutCatalog = {
        guard let url = Bundle.main.url(forResource: "NativeShortcuts", withExtension: "json"),
              let catalog = try? ShortcutCatalog(contentsOf: url) else {
            return ShortcutCatalog(native: [], unavailable: true)
        }
        return catalog
    }()
}


/// One layout calculation is shared by standard headers and rows.
struct StandardShortcutColumns {
    let availableWidth: Double
    let stacked: Bool
    let operationWidth: Double
    let bindingWidth: Double
    let spacing = 16.0
    init(availableWidth: Double) {
        self.availableWidth = max(1, availableWidth)
        stacked = availableWidth < 620
        bindingWidth = stacked ? max(1, availableWidth) : 340
        operationWidth = stacked ? max(1, availableWidth) : max(1, availableWidth - 340 - 16)
    }
}

/// Only the special-settings item label loses the redundant service-app suffix.
/// Raw titles remain intact for searching, manifests, help and service execution.
enum SpecialShortcutDisplay {
    static func title(_ raw: String, command: KeynoteCommand?) -> String {
        guard command?.category == .sweeper else { return raw }
        return raw.replacingOccurrences(of: #"\s*[（(]KeynoteSweeper[）)]\s*$"#, with: "", options: .regularExpression)
    }
}
