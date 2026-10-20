import Foundation

/// Every function ported from the Keyboard Maestro group 「Make Link」. Default keys are the macros' triggers.
enum LinkAction: String, CaseIterable, Codable {
    case copyURL, copyTitleLine, copyTitleSpace, copyMarkdown, copyHTML, copyAmazon
    case reloadClean, forceReload, editMode, translate, newWindow, privateWindow
    case openSafari, openChrome, openFirefox, openEdge
    case openClipboardURLs, searchClipboardLines
    // 「Make Link (misc)」: selected text in any app (numbers continue after the cases above).
    case selOpenDefault, selOpenChoose, selOpenAll
    /// 「Amazonリンク（アフィリエイト）」, split from copyAmazon (listed after it in the copy group).
    case copyAmazonAffiliate
    /// One webloc / QR code function each; the destination is asked when it runs.
    case weblocAsk, qrAsk
    /// One copy function; the format is asked when it runs.
    case copyAsk
    /// The all-tabs function; the format (URLs only / with titles / Markdown) is asked when it runs.
    case tabsAsk
    /// 「開き直し → Notion」: a notion.so page in the Notion app.
    case openNotion
    /// 「ほかのタブを閉じる」: every tab of the front window except the current one.
    case closeOtherTabs

    enum Group: String, CaseIterable { case copy, tabs, file, open, reopen, clipboard, selection }

    var group: Group {
        switch self {
        case .copyAsk, .copyURL, .copyTitleLine, .copyTitleSpace, .copyMarkdown, .copyHTML, .copyAmazon, .copyAmazonAffiliate: return .copy
        case .tabsAsk, .closeOtherTabs: return .tabs
        case .weblocAsk, .qrAsk: return .file
        case .reloadClean, .forceReload, .editMode, .translate, .newWindow, .privateWindow: return .open
        case .openSafari, .openChrome, .openFirefox, .openEdge, .openNotion: return .reopen
        case .openClipboardURLs, .searchClipboardLines: return .clipboard
        case .selOpenDefault, .selOpenChoose, .selOpenAll: return .selection
        }
    }

    /// Carbon hotkey id (stable; never reorder existing cases' numbers).
    var number: UInt32 { UInt32(LinkAction.allCases.firstIndex(of: self)! + 1) }
    static func from(number: UInt32) -> LinkAction? {
        let index = Int(number) - 1
        return allCases.indices.contains(index) ? allCases[index] : nil
    }

    var titleKey: String { "action." + rawValue }

    /// Listed actions in a group, in the order shown: the combined functions first.
    static func listed(_ group: Group) -> [LinkAction] {
        let all = allCases.filter { $0.group == group }
        switch group {
        case .file: return [.weblocAsk, .qrAsk]
        case .copy: return [.copyAsk] + all.filter { $0 != .copyAsk }
        default: return all
        }
    }
    /// What the combined copy function offers, in menu order.
    static let copyFormats: [LinkAction] = [.copyURL, .copyTitleLine, .copyTitleSpace, .copyMarkdown, .copyHTML, .copyAmazon, .copyAmazonAffiliate]
    /// Settings → Hotkeys: the same as the palette and the menus.
    static func inSettings(_ group: Group) -> [LinkAction] { listed(group) }

    /// The palette button's icon in 「簡易モード」 (MightyEdit's icon buttons): the browser's own icon for 「別のブラウザーで開く」.
    var browserBundleID: String? {
        [LinkAction.openSafari: "com.apple.Safari", .openChrome: "com.google.Chrome", .openFirefox: "org.mozilla.firefox", .openEdge: "com.microsoft.edgemac", .openNotion: "notion.id"][self]
    }
    var symbolName: String {
        switch self {
        case .copyAsk: return "doc.on.doc"
        case .copyURL: return "link"
        case .copyTitleLine: return "text.alignleft"
        case .copyTitleSpace: return "space"
        case .copyMarkdown: return "number"
        case .copyHTML: return "chevron.left.forwardslash.chevron.right"
        case .copyAmazon: return "cart"
        case .copyAmazonAffiliate: return "cart.badge.plus"
        case .tabsAsk: return "rectangle.stack"
        case .closeOtherTabs: return "xmark.square"
        case .weblocAsk: return "square.and.arrow.down"
        case .qrAsk: return "qrcode"
        case .reloadClean: return "arrow.clockwise"
        case .forceReload: return "exclamationmark.arrow.circlepath"
        case .editMode: return "pencil"
        case .translate: return "translate"
        case .newWindow: return "macwindow.badge.plus"
        case .privateWindow: return "eye.slash"
        case .openSafari, .openChrome, .openFirefox, .openEdge, .openNotion: return "globe"
        case .openClipboardURLs: return "doc.on.clipboard"
        case .searchClipboardLines: return "text.magnifyingglass"
        case .selOpenDefault: return "arrow.up.forward.app"
        case .selOpenChoose: return "arrow.up.right.square"
        case .selOpenAll: return "rectangle.3.group"
        }
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
        // ⌥G asks the format (the URL-only macro's key).
        case .tabsAsk: return .km(5, Self.opt, "G")
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
        case .openNotion: return .km(45, Self.optShiftCmd, "N")
        case .openClipboardURLs: return .km(37, Self.ctrlOptCmd, "L")
        case .selOpenDefault: return .km(37, Self.optCmd, "L")
        case .selOpenChoose: return .km(37, Self.ctrlCmd, "L")
        case .selOpenAll: return .km(37, Self.optShiftCmd, "L")
        // KM: ⌥A tapped once = Amazon link, twice = the affiliate link.
        case .copyAmazonAffiliate: return .km(0, Self.opt, "A")
        // ⌥W / ⌥Q ask where (the macros' keys for the front Finder window, which now has no key).
        case .weblocAsk: return .km(13, Self.opt, "W")
        case .qrAsk: return .km(12, Self.opt, "Q")
        // ⌥C asks the format (no Keyboard Maestro macro; KM's ⌥C is only in non-browser groups).
        case .copyAsk: return Shortcut(code: 8, modifiers: Self.opt, label: "⌥C")
        // ⌃⌥⇧⌘W (KM's 「ほかのタブを閉じる」 was ⌥⇧⌘W).
        case .closeOtherTabs: return Shortcut(code: 13, modifiers: Self.ctrlOptCmd | Shortcut.shift, label: "⌃⌥⇧⌘W")
        case .searchClipboardLines: return nil
        }
    }
}
