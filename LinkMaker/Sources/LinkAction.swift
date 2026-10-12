import Foundation

/// Every function ported from the Keyboard Maestro group 「Make Link」. Default keys are the macros' triggers.
enum LinkAction: String, CaseIterable, Codable {
    case copyURL, copyTitleLine, copyTitleSpace, copyMarkdown, copyHTML, copyAmazon
    case tabsURLs, tabsTitled, tabsMarkdown
    case weblocDesktop, weblocFinder, weblocChoose, qrDesktop, qrFinder, qrChoose
    case reloadClean, forceReload, editMode, translate, newWindow, privateWindow
    case openSafari, openChrome, openFirefox, openEdge
    case openClipboardURLs, searchClipboardLines
    // 「Make Link (misc)」: selected text in any app (numbers continue after the cases above).
    case selOpenDefault, selOpenChoose, selOpenAll, selSearch, selDictionary, selJina
    case selURLTextDesktop, selURLTextFinder, selWeblocDesktop, selWeblocFinder, fileWhereFrom
    /// 「Amazonリンク（アフィリエイト）」, split from copyAmazon (listed after it in the copy group).
    case copyAmazonAffiliate
    /// One webloc / QR code function each; the destination is asked when it runs.
    case weblocAsk, qrAsk

    enum Group: String, CaseIterable { case copy, tabs, file, open, reopen, clipboard, selection }

    var group: Group {
        switch self {
        case .copyURL, .copyTitleLine, .copyTitleSpace, .copyMarkdown, .copyHTML, .copyAmazon, .copyAmazonAffiliate: return .copy
        case .tabsURLs, .tabsTitled, .tabsMarkdown: return .tabs
        case .weblocAsk, .weblocDesktop, .weblocFinder, .weblocChoose, .qrAsk, .qrDesktop, .qrFinder, .qrChoose: return .file
        case .reloadClean, .forceReload, .editMode, .translate, .newWindow, .privateWindow: return .open
        case .openSafari, .openChrome, .openFirefox, .openEdge: return .reopen
        case .openClipboardURLs, .searchClipboardLines: return .clipboard
        case .selOpenDefault, .selOpenChoose, .selOpenAll, .selSearch, .selDictionary, .selJina,
             .selURLTextDesktop, .selURLTextFinder, .selWeblocDesktop, .selWeblocFinder, .fileWhereFrom: return .selection
        }
    }

    /// Carbon hotkey id (stable; never reorder existing cases' numbers).
    var number: UInt32 { UInt32(LinkAction.allCases.firstIndex(of: self)! + 1) }
    static func from(number: UInt32) -> LinkAction? {
        let index = Int(number) - 1
        return allCases.indices.contains(index) ? allCases[index] : nil
    }

    var titleKey: String { "action." + rawValue }

    /// Fixed-destination webloc / QR functions: hotkeys only (Settings → Hotkeys). The palette, the menus and the
    /// main window show the combined 「…を書き出す」 that asks where.
    var hotkeyOnly: Bool { [.weblocDesktop, .weblocFinder, .weblocChoose, .qrDesktop, .qrFinder, .qrChoose].contains(self) }
    /// Listed actions in a group, in the order shown: the combined file functions first.
    static func listed(_ group: Group) -> [LinkAction] {
        let all = allCases.filter { $0.group == group && !$0.hotkeyOnly }
        return group == .file ? [.weblocAsk, .qrAsk] : all
    }
    /// Settings → Hotkeys: everything, the combined file functions before the fixed-destination ones.
    static func inSettings(_ group: Group) -> [LinkAction] {
        group == .file ? [.weblocAsk, .qrAsk] + allCases.filter(\.hotkeyOnly) : allCases.filter { $0.group == group }
    }

    /// Whether the action needs the page in front (title/URL); the clipboard actions do not.
    var needsPage: Bool { group != .tabs && group != .clipboard && group != .selection }
    /// Works in any app except the excluded ones (the misc group's 「Excluded」 targeting); the others need a browser in front.
    var isGlobal: Bool { group == .selection }

    static let opt: UInt32 = 2048, optShiftCmd: UInt32 = 2816, optCmd: UInt32 = 2304, ctrlOptCmd: UInt32 = 6400, ctrlCmd: UInt32 = 4352

    var defaultDoubleTap: Bool { self == .copyAmazonAffiliate }

    var defaultShortcut: Shortcut? {
        switch self {
        case .copyURL: return .km(1, Self.opt, "S")
        case .copyTitleLine: return .km(17, Self.opt, "T")
        case .copyTitleSpace: return .km(16, Self.opt, "Y")
        case .copyMarkdown: return .km(46, Self.opt, "M")
        case .copyHTML: return .km(4, Self.opt, "H")
        case .copyAmazon: return .km(0, Self.opt, "A")
        case .tabsURLs: return .km(5, Self.opt, "G")
        case .tabsTitled: return .km(3, Self.opt, "F")
        case .weblocDesktop: return .km(40, Self.opt, "K")
        case .weblocChoose: return .km(13, Self.ctrlOptCmd, "W")
        case .reloadClean: return .km(15, Self.opt, "R")
        case .forceReload: return .km(15, Self.optShiftCmd, "R")
        case .editMode: return .km(14, Self.optCmd, "E")
        case .translate: return .km(17, Self.optShiftCmd, "T")
        case .newWindow: return .km(45, Self.ctrlCmd, "N")
        case .privateWindow: return .km(35, Self.optShiftCmd, "P")
        case .openSafari: return .km(1, Self.optShiftCmd, "S")
        case .openChrome: return .km(5, Self.optShiftCmd, "G")
        case .openFirefox: return .km(3, Self.optShiftCmd, "F")
        case .openEdge: return .km(14, Self.optShiftCmd, "E")
        case .openClipboardURLs: return .km(37, Self.ctrlOptCmd, "L")
        case .selOpenDefault: return .km(37, Self.optCmd, "L")
        case .selOpenChoose: return .km(37, Self.ctrlCmd, "L")
        case .selOpenAll: return .km(37, Self.optShiftCmd, "L")
        case .selSearch: return .km(12, Self.optCmd, "Q")
        case .selURLTextDesktop: return .km(31, Self.optCmd, "O")
        case .selURLTextFinder: return .km(31, Self.ctrlOptCmd, "O")
        // The dictionary macro was disabled in Keyboard Maestro (⌃⌥⌘Q), so it starts without a key.
        // KM: ⌥A tapped once = Amazon link, twice = the affiliate link.
        case .copyAmazonAffiliate: return .km(0, Self.opt, "A")
        // ⌥W / ⌥Q ask where (the macros' keys for the front Finder window, which now has no key).
        case .weblocAsk: return .km(13, Self.opt, "W")
        case .qrAsk: return .km(12, Self.opt, "Q")
        case .weblocFinder, .qrFinder: return nil
        case .tabsMarkdown, .qrDesktop, .qrChoose, .searchClipboardLines, .selDictionary, .selJina,
             .selWeblocDesktop, .selWeblocFinder, .fileWhereFrom: return nil
        }
    }
}
