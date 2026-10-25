import AppKit
import SwiftUI

/// ファミリーの一覧（AppKit の NSOutlineView）。
/// SwiftUI の List(children:) は選択を変えるたびに全行（数千）を比べ直して 0.2 秒ほど止まるため、
/// 中身が変わったとき（listVersion が進んだとき）だけ読み直し、選択の変更では読み直さない
struct FamilyOutline: NSViewRepresentable, Equatable {
    let nodes: [FamilyNode]
    let version: Int
    /// 画面の外（メニューなど）で選択が変わったときに updateNSView を呼んでもらうため
    let selection: Set<String>

    /// 比べるのは版と選択だけ。nodes は数千行あり、描き直しのたびに丸ごと比べると重い（版が同じなら中身も同じ）
    nonisolated static func == (lhs: FamilyOutline, rhs: FamilyOutline) -> Bool {
        lhs.version == rhs.version && lhs.selection == rhs.selection
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let outline = SpaceToggleOutlineView()
        let column = NSTableColumn(identifier: .init("family"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.rowHeight = 24
        outline.style = .inset
        outline.allowsMultipleSelection = true
        outline.usesAlternatingRowBackgroundColors = false
        outline.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outline.dataSource = context.coordinator
        outline.delegate = context.coordinator
        outline.target = context.coordinator
        outline.doubleAction = #selector(Coordinator.doubleClicked(_:))
        let menu = NSMenu()
        menu.delegate = context.coordinator
        outline.menu = menu
        outline.setAccessibilityLabel(L("ファミリー"))
        context.coordinator.outline = outline

        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        context.coordinator.reload(nodes, version: version)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.version != version {
            coordinator.reload(nodes, version: version)
        } else {
            coordinator.syncSelection()
        }
    }

    /// NSOutlineView の項目は参照で見分けるので、行ごとに箱を作る
    final class Box: NSObject {
        let node: FamilyNode
        let children: [Box]
        init(_ node: FamilyNode) {
            self.node = node
            children = node.children?.map(Box.init) ?? []
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
        weak var outline: NSOutlineView?
        var version = -1
        private var boxes: [Box] = []
        private var applyingSelection = false
        private var store: LibraryStore { LibraryStore.shared }

        func reload(_ nodes: [FamilyNode], version: Int) {
            self.version = version
            guard let outline else { return }
            // 開いていたファミリーと位置を保つ
            let expanded = Set(boxes.filter { outline.isItemExpanded($0) }.map(\.node.id))
            let visible = outline.rows(in: outline.visibleRect)
            let topID = (outline.item(atRow: visible.location) as? Box)?.node.id
            boxes = nodes.map(Box.init)
            applyingSelection = true
            outline.reloadData()
            for box in boxes where expanded.contains(box.node.id) { outline.expandItem(box) }
            applyingSelection = false
            syncSelection()
            if let topID, let box = box(for: topID) {
                let row = outline.row(forItem: box)
                if row >= 0 { outline.scrollRowToVisible(row) }
            }
        }

        /// 画面以外（メニュー・取り除く）で選択が変わったときに合わせる
        func syncSelection() {
            guard let outline else { return }
            let wanted = store.selection
            let current = Set(outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? Box)?.node.id })
            guard wanted != current else { return }
            var rows = IndexSet()
            for id in wanted {
                guard let box = box(for: id) else { continue }
                let row = outline.row(forItem: box)
                if row >= 0 { rows.insert(row) }
            }
            applyingSelection = true
            outline.selectRowIndexes(rows, byExtendingSelection: false)
            applyingSelection = false
        }

        private func box(for id: String) -> Box? {
            for box in boxes {
                if box.node.id == id { return box }
                if let child = box.children.first(where: { $0.node.id == id }) { return child }
            }
            return nil
        }

        // MARK: データ

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? Box)?.children.count ?? boxes.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            (item as? Box)?.children[index] ?? boxes[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            !((item as? Box)?.children.isEmpty ?? true)
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let box = item as? Box else { return nil }
            let cell = outlineView.makeView(withIdentifier: FamilyCell.identifier, owner: nil) as? FamilyCell ?? FamilyCell()
            cell.configure(box.node)
            return cell
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !applyingSelection, let outline else { return }
            store.selection = Set(outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? Box)?.node.id })
        }

        /// ダブルクリックで切り替える（ファミリーの行はまとめて、書体の行はその書体だけ）
        @objc func doubleClicked(_ sender: NSOutlineView) {
            guard let box = sender.item(atRow: sender.clickedRow) as? Box else { return }
            if let file = box.node.file {
                store.setActive([file], !store.isActive(file))
            } else {
                store.toggle(box.node.family)
            }
        }

        // MARK: 右クリックのメニュー

        /// 右クリックした行が選択の中ならその選択、外ならその行だけ
        private func menuIDs() -> Set<String> {
            guard let outline else { return [] }
            let clicked = outline.clickedRow
            guard clicked >= 0, let box = outline.item(atRow: clicked) as? Box else { return store.selection }
            return outline.selectedRowIndexes.contains(clicked) ? store.selection : [box.node.id]
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            let files = store.files(for: menuIDs())
            guard !files.isEmpty else { return }
            add(menu, L("アクティブにする")) { $0.setActive(files, true) }
            add(menu, L("解除")) { $0.setActive(files, false) }
            menu.addItem(.separator())
            let sets = NSMenu()
            let selectedIDs = Set(files.map(\.id))
            for set in store.data.sets {
                let item = add(sets, set.name) { $0.addToSet(set.id, files) }
                let included = selectedIDs.intersection(set.files)
                item.state = included.isEmpty ? .off : (included == selectedIDs ? .on : .mixed)
            }
            if !store.data.sets.isEmpty { sets.addItem(.separator()) }
            add(sets, L("新規セット…")) { $0.newSet(with: files) }
            let setsItem = NSMenuItem(title: L("セットに追加"), action: nil, keyEquivalent: "")
            setsItem.submenu = sets
            menu.addItem(setsItem)
            if case .set(let id) = store.sidebar {
                add(menu, L("このセットから外す")) { $0.removeFromSet(id, files) }
            }
            menu.addItem(.separator())
            add(menu, L("Finderで表示")) { $0.revealInFinder(files) }
            add(menu, L("ライブラリから取り除く…")) { $0.remove(files) }
            if !store.conflictingFiles(files).isEmpty {
                menu.addItem(.separator())
                add(menu, L("衝突しているフォントの登録を外す")) { $0.releaseConflicts(files) }
            }
            if store.hasDuplicates(files) {
                menu.addItem(.separator())
                add(menu, L("選んだフォントを優先にする")) { $0.preferSelected(files) }
            }
            // 選んだものに優先外の重複があるときだけ出す
            if files.contains(where: { store.duplicatePreference($0) == false }) {
                menu.addItem(.separator())
                // 右クリックした行（選択と違うこともある）の中の優先外だけを対象にする
                let others = files.filter { store.duplicatePreference($0) == false }
                add(menu, L("優先外の重複を解除")) { $0.setActive(others, false) }
                add(menu, L("優先外の重複をライブラリから取り除く…")) { $0.remove(others) }
            }
        }

        @discardableResult
        private func add(_ menu: NSMenu, _ title: String, _ action: @escaping @MainActor (LibraryStore) -> Void) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = MenuAction(action)
            menu.addItem(item)
            return item
        }

        @objc private func menuAction(_ sender: NSMenuItem) {
            (sender.representedObject as? MenuAction)?.run(store)
        }
    }

    final class MenuAction: NSObject {
        let run: @MainActor (LibraryStore) -> Void
        init(_ run: @escaping @MainActor (LibraryStore) -> Void) { self.run = run }
    }
}

/// スペースバーで、選んでいる行をまとめて切り替える一覧。
/// 選んだものがすべてアクティブなら解除、それ以外はアクティブにする（System のフォントは除く）
final class SpaceToggleOutlineView: NSOutlineView {
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard event.keyCode == 49, modifiers.isEmpty else { super.keyDown(with: event); return }
        let store = LibraryStore.shared
        let files = store.selectedFiles.filter { !LibraryStore.isLocked($0) }
        guard !files.isEmpty else { super.keyDown(with: event); return }
        store.setActive(files, !files.allSatisfy(store.isActive))
    }
}

/// 一覧の1行：チェックボックス・名前・注意・書体数（またはファイル名）
final class FamilyCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("FamilyCell")
    private let check = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let name = NSTextField(labelWithString: "")
    private let warning = NSImageView()
    private let detail = NSTextField(labelWithString: "")
    private var node: FamilyNode?

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        check.allowsMixedState = true
        // クリックで切り替えたあともキーの入力は一覧に残す（スペースバーは一覧で選んだ行を切り替える）
        check.refusesFirstResponder = true
        check.target = self
        check.action = #selector(checkClicked)
        name.lineBreakMode = .byTruncatingMiddle
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        warning.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        warning.contentTintColor = .systemOrange
        detail.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        detail.alignment = .right
        let stack = NSStackView(views: [check, name, NSView(), warning, detail])
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        textField = name
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            detail.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ node: FamilyNode) {
        self.node = node
        let store = LibraryStore.shared
        let problem: String?
        if let file = node.file {
            let active = store.isActive(file)
            check.state = active ? .on : .off
            check.isEnabled = !LibraryStore.isLocked(file)
            check.toolTip = !check.isEnabled ? LibraryStore.lockedReason(file)
                : active ? L("クリックで解除") : L("クリックでアクティブにする")
            check.setAccessibilityLabel(active ? L("アクティブ") : L("非アクティブ"))
            let styles = file.faces.map(\.displayStyle).joined(separator: L("、"))
            let postScript = file.faces.map(\.postScriptName).joined(separator: L("、"))
            let dimmed = Self.isUnavailable(file)
            switch NameDisplay.current {
            case .localized: set(styles, nil, dimmed: dimmed)
            case .postScript: set(postScript, nil, dimmed: dimmed)
            case .both: set(styles, postScript, dimmed: dimmed)
            }
            // 重複しているときは、ウォッチフォルダーの順で優先かどうかを添える（隠さず印で区別する）
            switch store.duplicatePreference(file) {
            case true?: detail.stringValue = L("優先") + "  " + file.fileName
            case false?: detail.stringValue = L("優先外") + "  " + file.fileName
            case nil: detail.stringValue = file.fileName
            }
            problem = Self.problem(store.states[file.id]) ?? Self.clash(file)
        } else {
            let family = node.family
            let state = store.familyState(family)
            check.state = state == true ? .on : state == nil ? .mixed : .off
            check.isEnabled = !family.files.allSatisfy(LibraryStore.isLocked)
            check.toolTip = !check.isEnabled ? family.files.first.map(LibraryStore.lockedReason)
                : state == true ? L("クリックで解除") : L("クリックでアクティブにする")
            check.setAccessibilityLabel(state == true ? L("アクティブ") : state == nil ? L("一部アクティブ") : L("非アクティブ"))
            let dimmed = family.files.allSatisfy(Self.isUnavailable)
            switch NameDisplay.current {
            case .localized: set(family.displayName, nil, dimmed: dimmed)
            case .postScript: set(family.name, nil, dimmed: dimmed)
            case .both: set(family.displayName, family.displayName == family.name ? nil : family.name, dimmed: dimmed)
            }
            detail.stringValue = L("%d書体", family.faceCount)
            problem = family.files.lazy.compactMap { Self.problem(store.states[$0.id]) ?? Self.clash($0) }.first
        }
        warning.isHidden = problem == nil
        warning.toolTip = problem
        warning.setAccessibilityLabel(problem)
    }

    /// このアプリから切り替えられない書体か（macOS 付属・Adobe Fonts、またはファイルが見つからない）。一覧では名前を薄いグレーにする
    private static func isUnavailable(_ file: FontFile) -> Bool {
        LibraryStore.isLocked(file) || LibraryStore.shared.states[file.id] == .missing
    }

    /// 名前と、薄い色の補足（両方を出すときの PostScript名・英語名）。dimmed は切り替えられない書体
    private func set(_ main: String, _ extra: String?, dimmed: Bool) {
        let color: NSColor = dimmed ? .tertiaryLabelColor : .labelColor
        guard let extra else {
            name.stringValue = main
            name.textColor = color
            return
        }
        let text = NSMutableAttributedString(string: main, attributes: [.foregroundColor: color])
        text.append(NSAttributedString(string: "  " + extra, attributes: [
            .foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]))
        name.attributedStringValue = text
    }

    /// 名前の衝突：別の書体なのに PostScript名が同じ（フォントの作りの誤りなど）
    private static func clash(_ file: FontFile) -> String? {
        LibraryStore.shared.nameClash(file).map {
            L("PostScript名が同じ別の書体があります。同時にアクティブにすると、アプリからは一方しか見えません：%@", $0)
        }
    }

    private static func problem(_ state: FontState?) -> String? {
        switch state {
        case .missing: return L("ファイルが見つかりません")
        case .conflict(let path): return L("同じ名前のフォントが別の場所で使われています：%@", path)
        default: return nil
        }
    }

    @objc private func checkClicked() {
        guard let node else { return }
        let store = LibraryStore.shared
        if let file = node.file {
            store.setActive([file], !store.isActive(file))
        } else {
            store.toggle(node.family)
        }
    }

}
