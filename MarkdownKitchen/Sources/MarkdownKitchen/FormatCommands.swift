import AppKit
import SwiftUI

/// 書式の操作。メニューバーの「書式」と原稿の右クリックメニューで共有する
enum FormatAction: CaseIterable {
    case copyHTML
    case bold, italic, inlineCode, strikethrough, underline, comment
    case heading1, heading2, heading3, heading4, heading5, heading6, paragraph
    case orderedList, unorderedList, quote, codeBlock
    case indent, outdent, moveParagraphUp, moveParagraphDown
    case link, image, horizontalRule, newParagraph
    // In the Edit menu, not in 書式.
    case copyHeadings, raiseHeadings, lowerHeadings
    case findReplace, findNext, findPrevious, useSelectionForFind, jumpToSelection

    /// 保存に使うID
    var id: String { String(describing: self) }

    /// 設定の「ホットキー」タブの並び
    static var settingsGroups: [(title: String, actions: [FormatAction])] {
        [(L("構造"), [.heading1, .heading2, .heading3, .heading4, .heading5, .heading6, .paragraph, .orderedList, .unorderedList, .quote, .codeBlock]),
         (L("インライン"), [.bold, .italic, .inlineCode, .strikethrough, .underline, .comment, .link, .image, .horizontalRule]),
         (L("編集"), [.newParagraph, .indent, .outdent, .moveParagraphUp, .moveParagraphDown]),
         (L("コピー"), [.copyHeadings, .copyHTML]),
         (L("見出し"), [.raiseHeadings, .lowerHeadings]),
         (L("検索"), [.findReplace, .findNext, .findPrevious, .useSelectionForFind, .jumpToSelection])]
    }

    /// 設定にもメニューにも出さない、もう一つのキー（⌥⌘5 番号付きリスト・⌥⌘6 箇条書き・⌥⌘M コメント）
    static let hiddenKeys: [(MenuShortcut, FormatAction)] = [
        (MenuShortcut("5", [.command, .option]), .orderedList),
        (MenuShortcut("6", [.command, .option]), .unorderedList),
        (MenuShortcut("m", [.command, .option]), .comment),
    ]

    /// 原稿のウインドウが前面のときだけ、隠れたキーを受け取る
    @MainActor static func installHiddenKeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let window = NSApp.keyWindow, window.sheetParent == nil, MarkdownStore.store(for: window) != nil,
                  let key = event.characters(byApplyingModifiers: [])?.lowercased() else { return event }
            let pressed = MenuShortcut(key, event.modifierFlags)
            guard let action = hiddenKeys.first(where: { $0.0 == pressed })?.1 else { return event }
            action.perform()
            return nil
        }
    }

    /// メニューの区切り（この項目の前に区切り線）
    static let groups: [[FormatAction]] = [
        [.bold, .italic, .inlineCode, .strikethrough, .underline, .comment],
        [.heading1, .heading2, .heading3, .heading4, .heading5, .heading6, .paragraph],
        [.orderedList, .unorderedList, .quote, .codeBlock],
        [.indent, .outdent],
        [.moveParagraphUp, .moveParagraphDown],
        [.link, .image, .horizontalRule, .newParagraph],
    ]
    static let convertGroup = 1

    var title: String {
        switch self {
        case .copyHTML: return L("HTMLをコピー")
        case .bold: return L("太字")
        case .italic: return L("斜体")
        case .inlineCode: return L("インラインコード")
        case .strikethrough: return L("取り消し線")
        case .underline: return L("下線")
        case .comment: return L("コメント")
        case .heading1: return L("見出し%@", "1")
        case .heading2: return L("見出し%@", "2")
        case .heading3: return L("見出し%@", "3")
        case .heading4: return L("見出し%@", "4")
        case .heading5: return L("見出し%@", "5")
        case .heading6: return L("見出し%@", "6")
        case .paragraph: return L("段落")
        case .orderedList: return L("番号付きリスト")
        case .unorderedList: return L("箇条書き")
        case .quote: return L("引用")
        case .codeBlock: return L("コードブロック")
        case .indent: return L("字下げを増やす")
        case .outdent: return L("字下げを減らす")
        case .moveParagraphUp: return L("段落を上へ移動")
        case .moveParagraphDown: return L("段落を下へ移動")
        case .link: return L("リンク")
        case .image: return L("画像")
        case .horizontalRule: return L("水平線")
        case .newParagraph: return L("新しい段落")
        case .copyHeadings: return L("見出しをコピー")
        case .raiseHeadings: return L("すべての見出しを1段上げる")
        case .lowerHeadings: return L("すべての見出しを1段下げる")
        case .findReplace: return L("検索と置換…")
        case .findNext: return L("次を検索")
        case .findPrevious: return L("前を検索")
        case .useSelectionForFind: return L("選択部分を検索に使用")
        case .jumpToSelection: return L("選択部分へジャンプ")
        }
    }

    /// キー（⌘0・⌘1 は「メインウインドウを開く」、⌘[ ⌘] は見出しの上げ下げで使うため ⌥ を足す）
    /// 初期値のキー
    var defaultShortcut: MenuShortcut? { key.0.isEmpty ? nil : MenuShortcut(key.0, key.1) }

    private var key: (String, NSEvent.ModifierFlags) {
        switch self {
        case .copyHTML: return ("c", [.command, .option])
        case .bold: return ("b", .command)
        case .italic: return ("i", .command)
        case .inlineCode: return ("e", .command)
        case .strikethrough: return ("x", [.command, .shift])
        case .underline: return ("u", .command)
        case .comment: return ("m", [.command, .shift])
        case .heading1: return ("1", [.command, .option])
        case .heading2: return ("2", [.command, .option])
        case .heading3: return ("3", [.command, .option])
        case .heading4: return ("4", [.command, .option])
        case .heading5: return ("", [])  // ⌥⌘5 and ⌥⌘6 are hidden list keys (see FormatAction.hiddenKeys).
        case .heading6: return ("", [])
        case .paragraph: return ("0", [.command, .option])
        case .orderedList: return ("7", [.command, .shift])
        case .unorderedList: return ("8", [.command, .shift])
        case .quote: return ("9", [.command, .shift])
        case .codeBlock: return ("8", [.command, .option])
        case .indent: return ("]", [.command, .option])
        case .outdent: return ("[", [.command, .option])
        case .moveParagraphUp: return (MenuShortcut.upArrow, [.control, .shift])
        case .moveParagraphDown: return (MenuShortcut.downArrow, [.control, .shift])
        case .link: return ("k", .command)
        case .image: return ("i", [.command, .shift])
        case .horizontalRule: return ("", [])  // No default key; one can be set in Settings > Hotkeys.
        case .newParagraph: return ("\r", .command)
        case .copyHeadings: return ("c", [.command, .shift])
        case .raiseHeadings: return ("[", .command)
        case .lowerHeadings: return ("]", .command)
        case .findReplace: return ("f", .command)
        case .findNext: return ("g", .command)
        case .findPrevious: return ("g", [.command, .shift])
        case .useSelectionForFind: return ("", [])  // ⌘E is Inline Code; a key can be set in Settings > Hotkeys.
        case .jumpToSelection: return ("j", .command)
        }
    }

    @MainActor func perform() {
        let store = MarkdownStore.shared
        switch self {
        case .copyHTML: store.copyHTML()
        case .bold: store.format(title) { MarkdownFormat.toggleWrap($0, selection: $1, marker: "**") }
        case .italic: store.format(title) { MarkdownFormat.toggleWrap($0, selection: $1, marker: "*") }
        case .inlineCode: store.format(title) { MarkdownFormat.toggleWrap($0, selection: $1, marker: "`") }
        case .strikethrough: store.format(title) { MarkdownFormat.toggleStrikethrough($0, selection: $1) }
        case .underline: store.format(title) { MarkdownFormat.toggleUnderline($0, selection: $1) }
        case .comment: store.format(title) { MarkdownFormat.toggleComment($0, selection: $1) }
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
            let level = [.heading1, .heading2, .heading3, .heading4, .heading5, .heading6].firstIndex(of: self)! + 1
            store.format(title) { MarkdownFormat.setBlock($0, selection: $1, to: .heading(level)) }
        case .paragraph: store.format(title) { MarkdownFormat.setBlock($0, selection: $1, to: .paragraph) }
        case .orderedList: store.format(title) { MarkdownFormat.setBlock($0, selection: $1, to: .orderedList) }
        case .unorderedList: store.format(title) { MarkdownFormat.setBlock($0, selection: $1, to: .unorderedList) }
        case .quote: store.format(title) { MarkdownFormat.setBlock($0, selection: $1, to: .quote) }
        case .codeBlock: store.format(title) { MarkdownFormat.toggleCodeBlock($0, selection: $1) }
        case .indent: store.format(title) { MarkdownFormat.indent($0, selection: $1, outdent: false) }
        case .outdent: store.format(title) { MarkdownFormat.indent($0, selection: $1, outdent: true) }
        case .moveParagraphUp, .moveParagraphDown:
            let up = self == .moveParagraphUp
            store.format(title) { text, selection in
                // At the first or last paragraph nothing moves.
                MarkdownFormat.moveParagraph(text, selection: selection, up: up)
                    ?? TextEdit(range: NSRange(location: selection.location, length: 0), replacement: "", selection: selection)
            }
        case .link: store.format(title) { MarkdownFormat.link($0, selection: $1, image: false) }
        case .image: store.format(title) { MarkdownFormat.link($0, selection: $1, image: true) }
        case .horizontalRule: store.format(title) { MarkdownFormat.horizontalRule($0, selection: $1) }
        case .newParagraph: store.format(title) { MarkdownFormat.newParagraph($0, selection: $1) }
        case .copyHeadings:
            let format = HeadingParser.Format(rawValue: UserDefaults.standard.string(forKey: MarkdownStore.copyFormatKey) ?? "") ?? .markdown
            store.copyHeadings(levels: MarkdownStore.storedLevels, format: format)
        case .raiseHeadings: store.shiftHeadings(by: -1, levels: MarkdownStore.storedLevels)
        case .lowerHeadings: store.shiftHeadings(by: 1, levels: MarkdownStore.storedLevels)
        case .findReplace: FindReplace.shared.show()
        case .findNext: FindReplace.shared.findNext()
        case .findPrevious: FindReplace.shared.findNext(backward: true)
        case .useSelectionForFind: FindReplace.shared.useSelection()
        case .jumpToSelection: FindReplace.shared.jumpToSelection()
        }
    }

    // MARK: - Menus

    /// 右クリックメニューに入れる項目（キーは表示だけ）
    /// 右クリックメニューの並び（先頭は「HTMLをコピー」）
    /// 右クリックメニューの区切り。字下げは Tab・⇧Tab で足りるので、書式メニューだけに出す
    static var contextGroups: [[FormatAction]] {
        [[.copyHTML]] + groups.map { $0.filter { $0 != .indent && $0 != .outdent } }.filter { !$0.isEmpty }
    }
    static let contextHiddenKey = "markdownKitchen.contextMenuHidden"

    /// 設定の「右クリック」で外した項目
    static var hiddenInContextMenu: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: contextHiddenKey) ?? [])
    }

    /// 右クリックメニューに入れる項目（設定で外したものは除く。空になった区切りは出さない）
    @MainActor static func contextMenuItems() -> [NSMenuItem] {
        let hidden = hiddenInContextMenu
        var items: [NSMenuItem] = []
        for (index, group) in contextGroups.enumerated() {
            let shown = group.filter { !hidden.contains($0.id) }
            guard !shown.isEmpty else { continue }
            if !items.isEmpty { items.append(.separator()) }
            if index == convertGroup + 1 {
                let parent = NSMenuItem(title: L("構造"), action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: L("構造"))
                shown.forEach { submenu.addItem($0.menuItem()) }
                parent.submenu = submenu
                items.append(parent)
            } else {
                items.append(contentsOf: shown.map { $0.menuItem() })
            }
        }
        return items
    }

    @MainActor private func menuItem() -> NSMenuItem {
        let shortcut = ShortcutStore.shared.shortcut(for: self)
        let item = NSMenuItem(title: title, action: #selector(FormatMenuTarget.perform(_:)), keyEquivalent: shortcut?.key ?? "")
        item.keyEquivalentModifierMask = shortcut?.flags ?? []
        item.target = FormatMenuTarget.shared
        item.representedObject = FormatActionBox(self)
        return item
    }
}

private final class FormatActionBox: NSObject {
    let action: FormatAction
    init(_ action: FormatAction) { self.action = action }
}

@MainActor
private final class FormatMenuTarget: NSObject {
    static let shared = FormatMenuTarget()
    @objc func perform(_ sender: NSMenuItem) {
        (sender.representedObject as? FormatActionBox)?.action.perform()
    }
}

/// メニューバーの「書式」メニュー
struct FormatMenuCommands: Commands {
    var body: some Commands {
        CommandMenu(L("書式")) {
            ForEach(Array(FormatAction.groups.enumerated()), id: \.offset) { index, group in
                if index > 0 { Divider() }
                // Headings 1–6 and Paragraph sit directly in the menu (the context menu keeps 変換 as a submenu).
                items(group)
            }
        }
    }

    @ViewBuilder private func items(_ group: [FormatAction]) -> some View {
        ForEach(group, id: \.self) { action in ShortcutButton(action: action) }
    }
}
