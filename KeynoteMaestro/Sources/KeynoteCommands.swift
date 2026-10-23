import AppKit
import ApplicationServices
import Carbon

// Keynote commands ported from the user's Keyboard Maestro macros (group 「Keynote」, Keynote Macros.kmmacros).
// No L() here, so Tests/CommandTests.swift can compile it alone.

/// Headings of the commands in Settings, in this order (the 「~~~」 separators of the KM group).
enum CommandCategory: String, CaseIterable {
    case slideshow, navigation, objects, inspector, transition, sweeper, align, zoom, animation, text, export, guidesMask, size, opacity
    /// Opacity is listed 10% … 100%, the second 100% key right after the first.
    var commands: [KeynoteCommand] {
        let list = KeynoteCommand.allCases.filter { $0.category == self }
        let index = { (command: KeynoteCommand) in KeynoteCommand.allCases.firstIndex(of: command)! }
        return self == .opacity ? list.sorted { ($0.opacityPercent!, index($0)) < ($1.opacityPercent!, index($1)) } : list
    }
}

/// Case order fixes the hotkey numbers, so new commands go at the end; Settings groups them by `category`.
enum KeynoteCommand: String, CaseIterable {
    case play, playInWindow, rehearse, newDocument, saveAs
    case previousSlide, nextSlide, firstSlide, lastSlide, goToSlide, newSlide, skipSlide, collapse, expand, collapseAll, expandAll
    case group, ungroup, bringToFront, bringForward, sendToBack, sendBackward, duplicate, slideSizeShape, whiteBackground, centerCross,
         objectList, hide, showHidden
    case inspectorFormat, inspectorAnimate, inspectorDocument, hideInspector
    case transitionNone, transitionDissolve, transitionMagicMove
    case alignLeft, alignRight, alignTop, alignBottom, alignCenter, alignMiddle, distributeHorizontally, distributeVertically,
         centerBoth, centerBothGrouped, centerGrouped, middleGrouped
    case zoomIn, zoomOut, zoomToSelection, zoomToContent, fitSlide
    case copyAnimation, pasteAnimation, previewAnimation
    case tighten, loosen, fontSmaller, fontBigger, textLeft, textCenter, textRight, textJustify, pasteMatchStyle
    case exportPDF, exportPNG, exportMovie
    case layoutGuides, guides, clearGuides, mask, resetMask
    case widthMinus, widthPlus, scale90, scale110, scale50, scale200, fillWidth, fillHeight, width80, sameHeight, sameWidth, sameWidthNarrowest
    case opacity10, opacity20, opacity30, opacity40, opacity50, opacity60, opacity70, opacity80, opacity90, opacity100
    /// KeynoteSweeper's Services (no KM macro); the cleanup itself stays in KeynoteSweeper.
    case sweepMasters, sweepHiddenSlides, sweepTransitions, sweepObjectAnimations, sweepAllAnimations, sweepTransitionsExceptMagicMove
    /// ⇧`, KM「97)」's second trigger for 100% (⇧0 stays too).
    case opacity100Alt
    case whiteRectangle
    case autoMagicMove

    /// Keep retired IDs in CaseIterable so existing Carbon hotkey numbers and stored dictionaries stay stable.
    /// Playback already has the native ⌥⌘P key, so Maestro must leave it to Keynote.
    var isAvailable: Bool { self != .play }
    static var availableCommands: [KeynoteCommand] { allCases.filter(\.isAvailable) }

    /// The first trigger of each KM macro (KeyCode, KM modifiers). Macros with one trigger per value
    /// (±1, 90/110/50/200 %, fill, opacity) became one command per trigger.
    var defaultShortcut: Shortcut {
        let cmd: UInt32 = 256, shift: UInt32 = 512, opt: UInt32 = 2048, ctrl: UInt32 = 4096
        switch self {
        case .play: return Shortcut(35, km: cmd | opt)
        case .playInWindow: return Shortcut(35, km: cmd | opt | shift)
        case .rehearse: return Shortcut(35, km: cmd | opt | ctrl)
        case .newDocument: return Shortcut(45, km: cmd | opt | shift)
        case .saveAs: return Shortcut(1, km: cmd | shift)
        case .previousSlide: return Shortcut(123, km: ctrl)
        case .nextSlide: return Shortcut(124, km: ctrl)
        case .firstSlide: return Shortcut(43, km: ctrl)
        case .lastSlide: return Shortcut(47, km: ctrl)
        case .goToSlide: return Shortcut(38, km: cmd)
        case .newSlide: return Shortcut(45, km: cmd)
        case .skipSlide: return Shortcut(44, km: cmd)
        case .collapse: return Shortcut(123, km: cmd)
        case .expand: return Shortcut(124, km: cmd)
        case .collapseAll: return Shortcut(123, km: cmd | opt)
        case .expandAll: return Shortcut(124, km: cmd | opt)
        case .group: return Shortcut(5, km: cmd)
        case .ungroup: return Shortcut(5, km: cmd | shift)
        case .bringToFront: return Shortcut(30, km: cmd | opt)
        case .bringForward: return Shortcut(30, km: cmd)
        case .sendToBack: return Shortcut(33, km: cmd | opt)
        case .sendBackward: return Shortcut(33, km: cmd)
        case .duplicate: return Shortcut(2, km: opt)
        case .slideSizeShape: return Shortcut(29, km: ctrl)
        case .whiteRectangle: return Shortcut(29, km: ctrl | opt | cmd)
        case .whiteBackground: return Shortcut(2, km: cmd | opt)
        case .centerCross: return Shortcut(24, km: cmd | opt | shift)
        case .objectList: return Shortcut(37, km: opt)
        case .hide: return Shortcut(20, km: cmd)
        case .showHidden: return Shortcut(20, km: cmd | opt)
        case .inspectorFormat: return Shortcut(18, km: opt)
        case .inspectorAnimate: return Shortcut(19, km: opt)
        case .inspectorDocument: return Shortcut(20, km: opt)
        case .hideInspector: return Shortcut(50, km: opt)
        case .transitionNone: return Shortcut(18, km: ctrl | opt)
        case .transitionDissolve: return Shortcut(19, km: ctrl | opt)
        case .transitionMagicMove: return Shortcut(50, km: ctrl | opt)
        case .autoMagicMove: return Shortcut(46, km: ctrl | opt | shift | cmd)
        case .alignLeft: return Shortcut(123, km: cmd | ctrl)
        case .alignRight: return Shortcut(124, km: cmd | ctrl)
        case .alignTop: return Shortcut(126, km: cmd | ctrl)
        case .alignBottom: return Shortcut(125, km: cmd | ctrl)
        case .alignCenter: return Shortcut(8, km: cmd | ctrl)
        case .alignMiddle: return Shortcut(46, km: cmd | ctrl)
        case .distributeHorizontally: return Shortcut(4, km: cmd | ctrl)
        case .distributeVertically: return Shortcut(9, km: cmd | ctrl)
        case .centerBoth: return Shortcut(8, km: opt)
        case .centerBothGrouped: return Shortcut(5, km: opt)
        case .centerGrouped: return Shortcut(8, km: cmd | opt | ctrl)
        case .middleGrouped: return Shortcut(46, km: cmd | opt | ctrl)
        case .zoomIn: return Shortcut(24, km: cmd)
        case .zoomOut: return Shortcut(27, km: cmd)
        case .zoomToSelection: return Shortcut(19, km: cmd)
        case .zoomToContent: return Shortcut(29, km: cmd)
        case .fitSlide: return Shortcut(18, km: cmd)
        case .copyAnimation: return Shortcut(8, km: opt | shift)
        case .pasteAnimation: return Shortcut(9, km: opt | shift)
        case .previewAnimation: return Shortcut(35, km: opt)
        case .tighten: return Shortcut(123, km: opt)
        case .loosen: return Shortcut(124, km: opt)
        case .fontSmaller: return Shortcut(43, km: cmd | shift)
        case .fontBigger: return Shortcut(47, km: cmd | shift)
        case .textLeft: return Shortcut(37, km: cmd | shift)
        case .textCenter: return Shortcut(8, km: cmd | shift)
        case .textRight: return Shortcut(15, km: cmd | shift)
        case .textJustify: return Shortcut(38, km: cmd | shift)
        case .pasteMatchStyle: return Shortcut(9, km: cmd | shift)
        case .exportPDF: return Shortcut(14, km: cmd)
        case .exportPNG: return Shortcut(14, km: cmd | opt)
        case .exportMovie: return Shortcut(14, km: cmd | opt | shift)
        case .layoutGuides: return Shortcut(41, km: cmd | opt)
        case .guides: return Shortcut(41, km: cmd)
        case .clearGuides: return Shortcut(23, km: cmd | opt | shift)
        case .mask: return Shortcut(26, km: cmd)
        case .resetMask: return Shortcut(26, km: cmd | opt)
        case .widthMinus: return Shortcut(27, km: cmd | opt | ctrl)
        case .widthPlus: return Shortcut(24, km: cmd | opt | ctrl)
        case .scale90: return Shortcut(43, km: cmd | opt)
        case .scale110: return Shortcut(47, km: cmd | opt)
        case .scale50: return Shortcut(23, km: ctrl)
        case .scale200: return Shortcut(19, km: ctrl)
        case .fillWidth: return Shortcut(18, km: cmd | opt)
        case .fillHeight: return Shortcut(19, km: cmd | opt)
        case .width80: return Shortcut(50, km: cmd | opt)
        case .sameHeight: return Shortcut(34, km: opt | shift)
        case .sameWidth: return Shortcut(32, km: opt | shift)
        case .sameWidthNarrowest: return Shortcut(16, km: opt | shift)
        // ⌃⌥⌘1 … ⌃⌥⌘5: not used by the KM group.
        case .sweepMasters: return Shortcut(18, km: cmd | opt | ctrl)
        case .sweepHiddenSlides: return Shortcut(19, km: cmd | opt | ctrl)
        case .sweepTransitions: return Shortcut(20, km: cmd | opt | ctrl)
        case .sweepObjectAnimations: return Shortcut(21, km: cmd | opt | ctrl)
        case .sweepAllAnimations: return Shortcut(23, km: cmd | opt | ctrl)
        // KM「37)【トランジション】なし（Magic Move以外のすべてのスライド）」; moved to KeynoteSweeper in 1.1.0.
        case .sweepTransitionsExceptMagicMove: return Shortcut(29, km: ctrl | opt)
        case .opacity100Alt: return Shortcut(50, km: shift)
        case .opacity10, .opacity20, .opacity30, .opacity40, .opacity50, .opacity60, .opacity70, .opacity80, .opacity90, .opacity100:
            // ⇧1 … ⇧9, ⇧0 (number-row key codes are not in order).
            let codes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
            return Shortcut(codes[opacityPercent! / 10 - 1], km: shift)
        }
    }

    var category: CommandCategory {
        switch self {
        case .play, .playInWindow, .rehearse, .newDocument, .saveAs: return .slideshow
        case .previousSlide, .nextSlide, .firstSlide, .lastSlide, .goToSlide, .newSlide, .skipSlide, .collapse, .expand, .collapseAll, .expandAll: return .navigation
        case .group, .ungroup, .bringToFront, .bringForward, .sendToBack, .sendBackward, .duplicate, .slideSizeShape, .whiteBackground, .centerCross,
             .objectList, .hide, .showHidden, .whiteRectangle: return .objects
        case .inspectorFormat, .inspectorAnimate, .inspectorDocument, .hideInspector: return .inspector
        case .transitionNone, .transitionDissolve, .transitionMagicMove, .autoMagicMove: return .transition
        case .alignLeft, .alignRight, .alignTop, .alignBottom, .alignCenter, .alignMiddle, .distributeHorizontally, .distributeVertically,
             .centerBoth, .centerBothGrouped, .centerGrouped, .middleGrouped: return .align
        case .zoomIn, .zoomOut, .zoomToSelection, .zoomToContent, .fitSlide: return .zoom
        case .copyAnimation, .pasteAnimation, .previewAnimation: return .animation
        case .tighten, .loosen, .fontSmaller, .fontBigger, .textLeft, .textCenter, .textRight, .textJustify, .pasteMatchStyle: return .text
        case .exportPDF, .exportPNG, .exportMovie: return .export
        case .layoutGuides, .guides, .clearGuides, .mask, .resetMask: return .guidesMask
        case .widthMinus, .widthPlus, .scale90, .scale110, .scale50, .scale200, .fillWidth, .fillHeight, .width80, .sameHeight, .sameWidth, .sameWidthNarrowest: return .size
        case .sweepMasters, .sweepHiddenSlides, .sweepTransitions, .sweepObjectAnimations, .sweepAllAnimations, .sweepTransitionsExceptMagicMove: return .sweeper
        default: return .opacity
        }
    }

    var opacityPercent: Int? {
        let all: [KeynoteCommand] = [.opacity10, .opacity20, .opacity30, .opacity40, .opacity50, .opacity60, .opacity70, .opacity80, .opacity90, .opacity100]
        return self == .opacity100Alt ? 100 : all.firstIndex(of: self).map { ($0 + 1) * 10 }
    }

    /// The KeynoteSweeper commands delete without asking, so they start off and the user turns them on.
    /// ⌃⌥0 was a KM macro in daily use, so it stays on.
    var enabledByDefault: Bool { self != .autoMagicMove && (category != .sweeper || self == .sweepTransitionsExceptMagicMove) }

    /// The service titles of KeynoteSweeper in its four languages (its ServicesMenu.strings).
    var serviceNames: [String] {
        switch self {
        case .sweepMasters: return ["使用されていないマスターを削除", "Delete Unused Masters", "删除未使用的母版", "사용하지 않는 마스터 삭제"]
        case .sweepHiddenSlides: return ["非表示のスライドを削除", "Delete Hidden Slides", "删除隐藏的幻灯片", "숨긴 슬라이드 삭제"]
        case .sweepTransitions: return ["トランジションを削除", "Remove Transitions", "删除过渡效果", "전환 효과 삭제"]
        case .sweepObjectAnimations: return ["オブジェクトのアニメーションを削除", "Remove Object Animations", "删除对象动画", "객체 애니메이션 삭제"]
        case .sweepAllAnimations: return ["すべてのアニメーションを削除", "Remove All Animations", "删除所有动画", "모든 애니메이션 삭제"]
        case .sweepTransitionsExceptMagicMove: return ["マジックムーブ以外のトランジションを削除", "Remove Transitions Except Magic Move", "删除神奇移动以外的过渡效果", "매직 이동 이외의 전환 효과 삭제"]
        default: return []
        }
    }

    /// Text commands are meant for text editing, so they keep their ⌥ keys there.
    var worksWhileTyping: Bool { category == .text }
}

// MARK: Steps

/// One menu level: any of these titles (Japanese and English Keynote), or a title starting with one of them.
enum MenuTitle {
    case any([String]), prefix([String])
    func matches(_ title: String) -> Bool {
        let title = Self.normalized(title)
        switch self {
        case .any(let names): return names.contains { Self.normalized($0) == title }
        case .prefix(let names): return names.contains { title.hasPrefix(Self.normalized($0)) }
        }
    }
    /// 「PDF...」 and 「PDF…」 are the same item.
    static func normalized(_ title: String) -> String {
        title.replacingOccurrences(of: "...", with: "…").trimmingCharacters(in: .whitespaces)
    }
}

/// A menu path; each level lists the Japanese and English titles (and both titles of a toggling item).
typealias MenuPath = [MenuTitle]
func path(_ levels: [String]...) -> MenuPath { levels.map { .any($0) } }

/// AppleScript jobs; each returns the number of objects or slides it changed.
enum KeynoteScript: Equatable {
    case hide, showHidden, opacity(Int)
    case transition(Transition), autoMagicMove
    case scale(Double), widthBy(Double), fill(Fill), sameSize(SameSize)
    case slideSizeShape, centerCross, whiteBackgroundShape, selectedWhiteRectangle, selectLastTwo
    enum Transition: Equatable { case none, dissolve, magicMove }
    enum Fill: Equatable { case width, height, width80 }
    enum SameSize: Equatable { case widestWidth, narrowestWidth, tallestHeight }
}

enum Step: Equatable {
    /// The first enabled item among the candidate paths. Missing or disabled: the command stops
    /// (and, as the first step, hands the key back to Keynote).
    case menu([MenuPath])
    /// Pressed when present and enabled; otherwise skipped.
    case optionalMenu([MenuPath])
    case key(CGKeyCode, CGEventFlags)
    case wait(TimeInterval)
    case script(KeynoteScript)
    /// A button of the front window (the Animate inspector's 「プレビュー」).
    case pressButton([String])
    /// Keynote ▸ Services ▸ one of KeynoteSweeper's items; missing means KeynoteSweeper is not installed or its service is off.
    case service([String])
    case exportPNG
    case expandFill

    static func == (lhs: Step, rhs: Step) -> Bool { String(describing: lhs) == String(describing: rhs) }
}

extension KeynoteCommand {
    private static let arrange = ["配置", "Arrange"], view = ["表示", "View"], format = ["フォーマット", "Format"],
                       slide = ["スライド", "Slide"], edit = ["編集", "Edit"], file = ["ファイル", "File"], playMenu = ["再生", "Play"],
                       align = ["オブジェクトを整列", "Align Objects"], inspector = ["インスペクタ", "Inspector"], zoom = ["拡大/縮小", "Zoom"]
    private static let groupItem = path(arrange, ["グループ", "Group"]), ungroupItem = path(arrange, ["グループ解除", "Ungroup"])
    private static let centerItem = path(arrange, align, ["中央揃え（縦）", "Center"]), middleItem = path(arrange, align, ["中央揃え（横）", "Middle"])

    /// Arrow keys typed on a real keyboard carry these flags.
    static let arrowFlags: CGEventFlags = [.maskSecondaryFn, .maskNumericPad]

    var steps: [Step] {
        typealias K = KeynoteCommand
        func menu(_ levels: [String]...) -> Step { .menu([levels.map { .any($0) }]) }
        switch self {
        // Play ▸ Full Screen / In Window chooses how 「スライドショーを再生」 shows (Keynote 14+).
        case .play: return [.optionalMenu([path(K.playMenu, ["フルスクリーン表示", "Full Screen"])]), menu(K.playMenu, ["スライドショーを再生", "Play Slideshow"])]
        case .playInWindow:
            return [.optionalMenu([path(K.playMenu, ["ウインドウ表示", "In Window"])]),
                    .menu([path(K.playMenu, ["スライドショーをウインドウで再生", "Play Slideshow in Window"]), path(K.playMenu, ["スライドショーを再生", "Play Slideshow"])])]
        case .rehearse: return [menu(K.playMenu, ["スライドショーをリハーサル", "Rehearse Slideshow"])]
        case .newDocument: return [menu(K.file, ["新規…", "New…"])]
        case .saveAs: return [menu(K.file, ["別名で保存…", "Save As…"])]
        case .previousSlide: return [menu(K.slide, ["移動", "Go To"], ["前のスライド", "Previous Slide"])]
        case .nextSlide: return [menu(K.slide, ["移動", "Go To"], ["次のスライド", "Next Slide"])]
        case .firstSlide: return [menu(K.slide, ["移動", "Go To"], ["最初のスライド", "First Slide"])]
        case .lastSlide: return [menu(K.slide, ["移動", "Go To"], ["最後のスライド", "Last Slide"])]
        case .goToSlide: return [menu(K.slide, ["移動", "Go To"], ["スライド…", "Slide…"])]
        case .newSlide: return [menu(K.slide, ["新規スライド", "New Slide"])]
        case .skipSlide: return [menu(K.slide, ["スライドをスキップ", "スキップを解除", "Skip Slide", "Don’t Skip Slide", "Don't Skip Slide"])]
        case .collapse: return [menu(K.slide, ["下位項目を隠す", "Collapse"])]
        case .expand: return [menu(K.slide, ["下位項目を表示", "Expand"])]
        case .collapseAll: return [menu(K.slide, ["すべての下位項目を隠す", "Collapse All"])]
        case .expandAll: return [menu(K.slide, ["すべての下位項目を表示", "Expand All"])]
        case .group: return [.menu([K.groupItem])]
        case .ungroup: return [.menu([K.ungroupItem])]
        case .bringToFront: return [menu(K.arrange, ["最前面へ", "Bring to Front"])]
        case .bringForward: return [menu(K.arrange, ["前面へ", "Bring Forward"])]
        case .sendToBack: return [menu(K.arrange, ["最背面へ", "Send to Back"])]
        case .sendBackward: return [menu(K.arrange, ["背面へ", "Send Backward"])]
        // KM「27)複製」: the copy lands 10 pt right and down; ⇧← ⇧↑ move it back over the original.
        case .duplicate:
            return [menu(K.edit, ["選択部分を複製", "Duplicate Selection"]), .wait(0.1),
                    .key(123, K.arrowFlags.union(.maskShift)), .key(126, K.arrowFlags.union(.maskShift))]
        case .slideSizeShape: return [.script(.slideSizeShape)]
        case .centerCross: return [.script(.centerCross)]
        // KM「28)配置したPDFに白バックを追加」: a shape of the same frame behind the selected object, grouped with it.
        // The original is brought to the front, so the new shape sits right behind it.
        case .whiteRectangle:
            return [.script(.selectedWhiteRectangle), .wait(0.2),
                    menu(K.view, K.inspector, ["フォーマット", "Format"]), .wait(0.2),
                    .pressButton(["スタイル", "Style"]), .wait(0.2), .expandFill, .wait(0.2),
                    .pressButton(["塗りつぶしプリセットピッカー", "Fill preset picker"]), .wait(0.2),
                    .pressButton(["ホワイト 100", "White 100"]), .wait(0.2),
                    menu(K.arrange, ["最背面へ", "Send to Back"])]
        case .whiteBackground:
            return [.script(.whiteBackgroundShape), .wait(0.2), menu(K.arrange, ["最前面へ", "Bring to Front"]), .wait(0.2),
                    .script(.selectLastTwo), .wait(0.2), .menu([K.groupItem])]
        case .objectList: return [menu(K.view, ["オブジェクトリストを表示", "オブジェクトリストを非表示", "Show Object List", "Hide Object List"])]
        // KM「98)【隠す】隠す」: opacity 0, then deselect so the hidden object is not moved by accident.
        case .hide: return [.script(.hide), .optionalMenu([path(K.edit, ["すべてを選択解除", "Deselect All"])])]
        case .showHidden: return [.script(.showHidden)]
        case .inspectorFormat: return [menu(K.view, K.inspector, ["フォーマット", "Format"])]
        case .inspectorAnimate: return [menu(K.view, K.inspector, ["アニメーション", "Animate"])]
        case .inspectorDocument: return [menu(K.view, K.inspector, ["書類", "Document"])]
        case .hideInspector: return [menu(K.view, K.inspector, ["インスペクタを非表示", "インスペクタを表示", "Hide Inspector", "Show Inspector"])]
        case .transitionNone: return [.script(.transition(.none))]
        case .transitionDissolve: return [.script(.transition(.dissolve))]
        case .transitionMagicMove: return [.script(.transition(.magicMove))]
        case .autoMagicMove: return [.script(.autoMagicMove)]
        case .alignLeft: return [menu(K.arrange, K.align, ["左揃え", "Left"])]
        case .alignRight: return [menu(K.arrange, K.align, ["右揃え", "Right"])]
        case .alignTop: return [menu(K.arrange, K.align, ["上揃え", "Top"])]
        case .alignBottom: return [menu(K.arrange, K.align, ["下揃え", "Bottom"])]
        case .alignCenter: return [.menu([K.centerItem])]
        case .alignMiddle: return [.menu([K.middleItem])]
        case .distributeHorizontally: return [menu(K.arrange, ["オブジェクトを均等に配置", "Distribute Objects"], ["横方向", "Horizontally"])]
        case .distributeVertically: return [menu(K.arrange, ["オブジェクトを均等に配置", "Distribute Objects"], ["縦方向", "Vertically"])]
        case .centerBoth: return [.menu([K.centerItem]), .optionalMenu([K.middleItem])]
        // Grouped first, so the objects move together to the slide center and keep their layout.
        case .centerBothGrouped: return [.menu([K.groupItem]), .wait(0.1), .optionalMenu([K.centerItem]), .optionalMenu([K.middleItem]), .wait(0.2), .optionalMenu([K.ungroupItem])]
        case .centerGrouped: return [.menu([K.groupItem]), .wait(0.1), .optionalMenu([K.centerItem]), .wait(0.2), .optionalMenu([K.ungroupItem])]
        case .middleGrouped: return [.menu([K.groupItem]), .wait(0.1), .optionalMenu([K.middleItem]), .wait(0.2), .optionalMenu([K.ungroupItem])]
        case .zoomIn: return [menu(K.view, K.zoom, ["拡大", "Zoom In"])]
        case .zoomOut: return [menu(K.view, K.zoom, ["縮小", "Zoom Out"])]
        // KM「63)」: fit the selection, then one step out for some margin.
        case .zoomToSelection: return [menu(K.view, K.zoom, ["選択部分に合わせて拡大/縮小", "Zoom to Fit Selection", "Zoom to Selection"]), .wait(0.3), .optionalMenu([path(K.view, K.zoom, ["縮小", "Zoom Out"])])]
        case .zoomToContent: return [menu(K.view, K.zoom, ["コンテンツに合わせて拡大/縮小", "Zoom to Fit Content", "Zoom to Content"])]
        case .fitSlide: return [menu(K.view, K.zoom, ["スライドに合わせる", "Fit Slide"])]
        case .copyAnimation: return [menu(K.format, ["アニメーションをコピー", "Copy Animation"])]
        case .pasteAnimation: return [menu(K.format, ["アニメーションをペースト", "Paste Animation"])]
        // KM「69)」 clicked the Preview button found by image; it is pressed through Accessibility instead.
        case .previewAnimation: return [.optionalMenu([path(K.view, K.inspector, ["アニメーション", "Animate"])]), .wait(0.3), .pressButton(["プレビュー", "Preview"])]
        case .tighten: return [menu(K.format, ["フォント", "Font"], ["文字間隔", "Character Spacing"], ["きつく", "Tighten"])]
        case .loosen: return [menu(K.format, ["フォント", "Font"], ["文字間隔", "Character Spacing"], ["ゆるく", "Loosen"])]
        case .fontSmaller: return [menu(K.format, ["フォント", "Font"], ["小さく", "Smaller"])]
        case .fontBigger: return [menu(K.format, ["フォント", "Font"], ["大きく", "Bigger"])]
        case .textLeft: return [menu(K.format, ["テキスト", "Text"], ["左揃え", "Align Left"])]
        case .textCenter: return [menu(K.format, ["テキスト", "Text"], ["中央揃え", "Center"])]
        case .textRight: return [menu(K.format, ["テキスト", "Text"], ["右揃え", "Align Right"])]
        case .textJustify: return [menu(K.format, ["テキスト", "Text"], ["両端揃え", "Justify"])]
        case .pasteMatchStyle: return [menu(K.edit, ["ペーストしてスタイルを合わせる", "Paste and Match Style"])]
        case .exportPDF: return [menu(K.file, ["書き出す", "Export To"], ["PDF…", "PDF…"])]
        case .exportPNG: return [.exportPNG]
        case .exportMovie: return [menu(K.file, ["書き出す", "Export To"], ["ムービー…", "Movie…"])]
        case .layoutGuides: return [menu(K.view, ["ガイド", "Guides"], ["スライドレイアウトガイドを表示", "スライドレイアウトガイドを非表示", "Show Slide Layout Guides", "Hide Slide Layout Guides"])]
        case .guides: return [menu(K.view, ["ガイド", "Guides"], ["ガイドを表示", "ガイドを非表示", "Show Guides", "Hide Guides"])]
        case .clearGuides: return [menu(K.view, ["ガイド", "Guides"], ["スライドのガイドをすべて消去", "Clear All Guides on Slide"])]
        // KM「88)」: mask with the selection when possible, otherwise edit the mask.
        case .mask:
            return [.menu([path(K.format, ["画像", "Image"], ["選択部分でマスク", "Mask with Selection"]),
                           path(K.format, ["画像", "Image"], ["マスクを編集", "Edit Mask"])])]
        case .resetMask: return [menu(K.format, ["画像", "Image"], ["マスクをリセット", "Reset Mask"])]
        case .widthMinus: return [.script(.widthBy(-1))]
        case .widthPlus: return [.script(.widthBy(1))]
        case .scale90: return [.script(.scale(0.9))]
        case .scale110: return [.script(.scale(1.1))]
        case .scale50: return [.script(.scale(0.5))]
        case .scale200: return [.script(.scale(2))]
        case .fillWidth: return [.script(.fill(.width))]
        case .fillHeight: return [.script(.fill(.height))]
        case .width80: return [.script(.fill(.width80))]
        case .sameHeight: return [.script(.sameSize(.tallestHeight))]
        case .sameWidth: return [.script(.sameSize(.widestWidth))]
        case .sameWidthNarrowest: return [.script(.sameSize(.narrowestWidth))]
        case .sweepMasters, .sweepHiddenSlides, .sweepTransitions, .sweepObjectAnimations, .sweepAllAnimations, .sweepTransitionsExceptMagicMove: return [.service(serviceNames)]
        default: return [.script(.opacity(opacityPercent!))]
        }
    }
}

// MARK: AppleScript

extension KeynoteScript {
    /// Body inside `tell front document`; returns how many objects or slides changed.
    var body: String {
        let eachSelected = "set sel to selection\nif (count of sel) = 0 then return 0\n"
        switch self {
        case .hide: return opacityBody(0)
        case .opacity(let value): return opacityBody(value)
        case .showHidden:
            return """
            set n to 0
            repeat with o in (get every iWork item of current slide)
            try
            if opacity of o is 0 then
            set opacity of o to 100
            set n to n + 1
            end if
            end try
            end repeat
            return n
            """
        case .autoMagicMove: return AutoMagicMoveScript.body
        case .transition(let kind):
            let properties: String
            switch kind {
            case .none: properties = "{transition effect:no transition effect}"
            case .dissolve: properties = "{transition effect:dissolve, transition duration:0.3, transition delay:0, automatic transition:false}"
            case .magicMove: properties = "{transition effect:magic move, transition duration:0.7, transition delay:0, automatic transition:false}"
            }
            return "set transition properties of current slide to \(properties)\nreturn 1"
        case .scale(let factor):
            return eachSelected + """
            repeat with o in sel
            set {w, h} to {width of o, height of o}
            set {x, y} to position of o
            set {nw, nh} to {w * \(factor), h * \(factor)}
            set position of o to {x + (w - nw) / 2, y + (h - nh) / 2}
            set width of o to nw
            set height of o to nh
            end repeat
            set selection to sel
            return count of sel
            """
        case .widthBy(let delta):
            return eachSelected + """
            repeat with o in sel
            set {x, y} to position of o
            set w to width of o
            set position of o to {x - (\(delta)) / 2, y}
            set width of o to w + (\(delta))
            end repeat
            set selection to sel
            return count of sel
            """
        // KM「93)」 resized, then centered with 「縦横中央」; here every object is centered on the slide.
        case .fill(let fill):
            let resize: String
            switch fill {
            case .width: resize = "set width of o to slideW"
            case .height: resize = "set height of o to slideH"
            case .width80:
                resize = "set width of o to slideW\nset {w, h} to {width of o, height of o}\nset width of o to w * 0.8\nset height of o to h * 0.8"
            }
            return eachSelected + """
            set {slideW, slideH} to {width, height}
            repeat with o in sel
            try
            \(resize)
            set position of o to {(slideW - (width of o)) / 2, (slideH - (height of o)) / 2}
            end try
            end repeat
            set selection to sel
            return count of sel
            """
        // KM「94)」「95)」: same size as the largest (or smallest) object, each kept centered where it was.
        case .sameSize(let kind):
            let isWidth = kind != .tallestHeight
            let property = isWidth ? "width" : "height"
            let compare = kind == .narrowestWidth ? "<" : ">"
            let move = isWidth ? "{x + (old - target) / 2, y}" : "{x, y + (old - target) / 2}"
            return """
            set sel to selection
            if (count of sel) < 2 then return 0
            set target to \(property) of item 1 of sel
            repeat with o in sel
            if (\(property) of o) \(compare) target then set target to \(property) of o
            end repeat
            repeat with o in sel
            set {x, y} to position of o
            set old to \(property) of o
            set \(property) of o to target
            set position of o to \(move)
            end repeat
            set selection to sel
            return count of sel
            """
        case .slideSizeShape:
            return """
            set {slideW, slideH} to {width, height}
            tell current slide to make new shape with properties {position:{0, 0}, width:slideW, height:slideH, opacity:100}
            return 1
            """
        // KM「55)」: lines through the slide center. Keynote lines have no color or width property, so the theme's line style applies.
        case .centerCross:
            return """
            set {slideW, slideH} to {width, height}
            tell current slide
            make new line with properties {start point:{slideW / 2, 0}, end point:{slideW / 2, slideH}}
            make new line with properties {start point:{0, slideH / 2}, end point:{slideW, slideH / 2}}
            end tell
            return 2
            """
        case .selectedWhiteRectangle:
            return eachSelected + """
            if (count of sel) is not 1 then return 0
            set o to item 1 of sel
            set {x, y} to position of o
            set objectWidth to width of o
            set objectHeight to height of o
            tell current slide to set backgroundShape to make new shape with properties {position:{x, y}, width:objectWidth, height:objectHeight, opacity:100}
            set selection to {backgroundShape}
            return 1
            """
        case .whiteBackgroundShape:
            return eachSelected + """
            set o to item 1 of sel
            set {x, y} to position of o
            tell current slide to make new shape with properties {position:{x, y}, width:(width of o), height:(height of o), opacity:100}
            set selection to {o}
            return 1
            """
        // After 「最前面へ」 the original is the last item and the new shape the one before it.
        case .selectLastTwo:
            return """
            tell current slide to set n to count of iWork items
            if n < 2 then return 0
            set selection to {iWork item (n - 1) of current slide, iWork item n of current slide}
            return 2
            """
        }
    }

    /// The selection is read once: changing a size or position leaves only that object selected (checked in Keynote 15.4).
    private func opacityBody(_ value: Int) -> String {
        """
        set sel to selection
        set n to 0
        repeat with o in sel
        try
        set opacity of o to \(value)
        set n to n + 1
        end try
        end repeat
        return n
        """
    }

    func source(bundleID: String) -> String {
        if self == .autoMagicMove { return AutoMagicMoveScript.source(bundleID: bundleID) }
        return "tell application id \"\(bundleID)\"\nif not (exists front document) then error number -1728\ntell front document\n\(body)\nend tell\nend tell"
    }
}
