import AppKit
import ApplicationServices

enum MenuReaderError: LocalizedError {
    case notTrusted
    case noMenuBar
    case launchFailed(String)
    case timedOut
    case nothingToRead(String)

    var errorDescription: String? {
        switch self {
        case .notTrusted: return L("error.notTrusted")
        case .noMenuBar: return L("error.noMenuBar")
        case .launchFailed(let message): return LF("error.launchFailed", message)
        case .timedOut: return L("error.timedOut")
        case .nothingToRead(let name): return LF("error.nothingToRead", name)
        }
    }
}

/// アクセシビリティでメニューバーを辿る
enum MenuReader {
    static let separator = ">"

    /// 子孫を辿らない項目（中身が環境やユーザーごとに異なるもの）。先頭はアプリメニュー（年を外した名前）
    static func excludedDescendants(for app: AdobeApp) -> Set<String> {
        switch app {
        case .illustrator:
            return [
                "Illustrator>Services", "File>Open Recent Files", "File>Scripts", "Type>Font", "Type>Recent Fonts", "Type>Size",
                "Type>Insert Special Character", "Type>Insert WhiteSpace Character", "Type>Insert Break Character",
                "View>Rotate View", "Window>Extensions", "Window>Graphic Style Libraries", "Window>Symbol Libraries",
                "Window>Swatch Libraries", "Window>Brush Libraries",
                "Illustrator>サービス", "ファイル>最近使用したファイルを開く", "ファイル>スクリプト", "書式>フォント", "書式>最近使用したフォント",
                "書式>サイズ", "書式>特殊文字を挿入", "書式>空白文字を挿入", "書式>分割文字を挿入", "表示>ビューを回転",
                "ウィンドウ>エクステンション", "ウィンドウ>グラフィックスタイルライブラリ", "ウィンドウ>シンボルライブラリ",
                "ウィンドウ>スウォッチライブラリ", "ウィンドウ>ブラシライブラリ",
            ]
        case .indesign:
            return [
                "InDesign>Services", "File>Open Recent", "File>Adobe PDF Presets", "File>Document Presets", "File>Print Presets",
                "Type>Font", "Type>Size", "Type>Character Styles", "Type>Paragraph Styles",
                "Type>Insert Special Character", "Type>Insert White Space", "Type>Insert Break Character",
                "InDesign>サービス", "ファイル>最近使用したファイルを開く", "ファイル>PDF 書き出しプリセット", "ファイル>ドキュメントプリセット",
                "ファイル>プリントプリセット", "書式>フォント", "書式>サイズ", "書式>文字スタイル", "書式>段落スタイル",
                "書式>特殊文字を挿入", "書式>空白文字を挿入", "書式>分割文字を挿入",
            ]
        case .photoshop:
            return [
                "Photoshop>Services", "File>Open Recent", "File>Scripts", "Plugins>Plugins Panel",
                "Photoshop>サービス", "ファイル>最近使用したファイルを開く", "ファイル>スクリプト", "プラグイン>プラグインパネル",
            ]
        }
    }

    /// メニューバーの項目をすべて読む。Apple メニューは macOS のものなので読まない
    static func read(pid: pid_t, app: AdobeApp) throws -> [MenuEntry] {
        guard AXIsProcessTrusted() else { throw MenuReaderError.notTrusted }
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 5)
        guard let menuBar = attribute(appElement, kAXMenuBarAttribute).map({ $0 as! AXUIElement }) else {
            throw MenuReaderError.noMenuBar
        }
        var entries: [MenuEntry] = []
        let excluded = excludedDescendants(for: app)
        let topItems = children(of: menuBar)
        // 先頭は Apple メニュー。次のアプリメニューは「Photoshop 2026」のように年が入るので、アプリ名にそろえる
        for (index, item) in topItems.dropFirst().enumerated() {
            walk(item, parentPath: "", titleOverride: index == 0 ? app.title : nil, excluded: excluded, into: &entries)
        }
        return MenuSnapshot.numberingDuplicates(entries)
    }

    private static func walk(_ item: AXUIElement, parentPath: String, titleOverride: String? = nil,
                             excluded: Set<String>, into entries: inout [MenuEntry]) {
        guard let rawTitle = titleOverride ?? cleanTitle(attribute(item, kAXTitleAttribute) as? String ?? "") else { return }
        let title = stateFreeTitle(rawTitle, parentPath: parentPath)
        let path = parentPath.isEmpty ? title : parentPath + separator + title
        entries.append(MenuEntry(path: path, shortcut: parentPath.isEmpty ? "" : shortcut(of: item)))
        guard !excluded.contains(path) else { return }
        for submenu in children(of: item) where (attribute(submenu, kAXRoleAttribute) as? String) == "AXMenu" {
            for child in children(of: submenu) {
                walk(child, parentPath: path, excluded: excluded, into: &entries)
            }
        }
    }

    /// 書き出さない項目は nil。区切り線（名前なし）・開いているドキュメント名を除き、メールアドレスを消す
    /// 操作やドキュメントで名前が変わる項目を、決まった名前にそろえる
    /// （「〜を取り消し」「sw-fullをリセット」「小冊子.indd の新規ウィンドウ」など）
    static func stateFreeTitle(_ title: String, parentPath: String) -> String {
        // 取り消し・やり直しは［編集］メニューの直下だけ（［変更をトラック］の「〜を取り消し」は別物）
        let undoRules: [(String, String)] = [
            ("^.+[をの]取り消し$", "取り消し"), ("^.+[をの]やり直し$", "やり直し"), ("^Undo .+$", "Undo"), ("^Redo .+$", "Redo"),
        ]
        if parentPath == "編集" || parentPath == "Edit" {
            for (pattern, replacement) in undoRules where title.range(of: pattern, options: .regularExpression) != nil {
                return replacement
            }
        }
        if title.range(of: "^.+ の新規ウィンドウ$", options: .regularExpression) != nil { return "新規ウィンドウ" }
        if title.range(of: "^New Window for .+$", options: .regularExpression) != nil { return "New Window" }
        if parentPath.hasSuffix("ワークスペース"), title.hasSuffix("をリセット") { return "（現在のワークスペース）をリセット" }
        if parentPath.hasSuffix("Workspace"), title.hasPrefix("Reset ") { return "Reset (current workspace)" }
        return title
    }

    static func cleanTitle(_ raw: String) -> String? {
        if raw.isEmpty { return nil }
        if raw.range(of: " @ [0-9.,]+ ?%", options: .regularExpression) != nil { return nil }
        guard raw.contains("@") else { return raw }
        return raw
            .replacingOccurrences(of: "\\s*[(（][^()（）]*@[^()（）]*[)）]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\S+@\\S+\\.\\S+", with: "(email)", options: .regularExpression)
    }

    // MARK: ショートカット

    static func shortcut(of item: AXUIElement) -> String {
        var key = ""
        if let glyph = attribute(item, "AXMenuItemCmdGlyph") as? Int, glyph != 0, let label = glyphLabels[glyph] {
            key = label
        } else if let character = attribute(item, "AXMenuItemCmdChar") as? String, !character.isEmpty {
            key = keyLabel(character)
        }
        guard !key.isEmpty else { return "" }
        let modifiers = attribute(item, "AXMenuItemCmdModifiers") as? Int ?? 0
        var text = ""
        if modifiers & 4 != 0 { text += "⌃" }
        if modifiers & 2 != 0 { text += "⌥" }
        if modifiers & 1 != 0 { text += "⇧" }
        if modifiers & 8 == 0 { text += "⌘" }
        return text + key
    }

    static func keyLabel(_ character: String) -> String {
        guard let scalar = character.unicodeScalars.first else { return "" }
        switch scalar.value {
        case 3, 13: return "↩"
        case 9: return "⇥"
        case 27: return "⎋"
        case 8, 127: return "⌫"
        case 32: return "Space"
        case 0xF700: return "↑"
        case 0xF701: return "↓"
        case 0xF702: return "←"
        case 0xF703: return "→"
        case 0xF704...0xF726: return "F\(scalar.value - 0xF703)"
        case 0xF728: return "⌦"
        case 0xF729: return "↖"
        case 0xF72B: return "↘"
        case 0xF72C: return "⇞"
        case 0xF72D: return "⇟"
        default: return character.uppercased()
        }
    }

    /// AXMenuItemCmdGlyph（Carbon の kMenu…Glyph）
    static let glyphLabels: [Int: String] = [
        0x02: "⇥", 0x04: "⌤", 0x09: "Space", 0x0A: "⌦", 0x0B: "↩", 0x0D: "↩", 0x17: "⌫", 0x1B: "⎋", 0x1C: "⌧",
        0x62: "⇞", 0x64: "←", 0x65: "→", 0x66: "↖", 0x68: "↑", 0x69: "↘", 0x6A: "↓", 0x6B: "⇟",
        0x6F: "F1", 0x70: "F2", 0x71: "F3", 0x72: "F4", 0x73: "F5", 0x74: "F6", 0x75: "F7", 0x76: "F8",
        0x77: "F9", 0x78: "F10", 0x79: "F11", 0x7A: "F12", 0x87: "F13", 0x88: "F14", 0x89: "F15",
    ]

    // MARK: AX

    static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    // MARK: 起動して読む

    /// 起動中ならそのまま読む。起動していなければ起動し、メニューがそろうのを待って読み、終了させる
    static func capture(_ install: AppInstall, progress: @escaping @Sendable (String) -> Void) async throws -> MenuSnapshot {
        guard AXIsProcessTrusted() else { throw MenuReaderError.notTrusted }
        var launchedApp: NSRunningApplication?
        let entries: [MenuEntry]
        if let running = install.runningApplication {
            progress(LF("progress.reading", install.displayName))
            entries = try read(pid: running.processIdentifier, app: install.app)
        } else {
            progress(LF("progress.launching", install.displayName))
            let app = try await launch(install)
            launchedApp = app
            progress(LF("progress.waiting", install.displayName))
            do {
                entries = try await waitForMenus(pid: app.processIdentifier, app: install.app)
            } catch {
                app.terminate()
                throw error
            }
        }
        // 自分が起動したものだけ終了させる。待っている間に使い始めていたら（前面にある）残す
        if let app = launchedApp {
            if app.isActive {
                progress(LF("progress.leftRunning", install.displayName))
            } else {
                progress(LF("progress.quitting", install.displayName))
                app.terminate()
            }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let meta = ["name": install.snapshotName, "app": install.appURL.path, "product": install.app.title, "version": install.version,
                    "locale": install.locale, "date": formatter.string(from: Date()), "tool": "MenuDiff.app \(appVersion)"]
        return MenuSnapshot(meta: meta, entries: entries)
    }

    /// 同じ Bundle ID の別バージョンが起動中でも、この場所のアプリを新しく起動する
    static func launch(_ install: AppInstall) async throws -> NSRunningApplication {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = true
        do {
            return try await NSWorkspace.shared.openApplication(at: install.appURL, configuration: configuration)
        } catch {
            throw MenuReaderError.launchFailed(error.localizedDescription)
        }
    }

    /// メニューの項目数が2回続けて変わらなくなるまで待つ（最大4分）
    static func waitForMenus(pid: pid_t, app: AdobeApp) async throws -> [MenuEntry] {
        var previousCount = -1
        var stableReads = 0
        for _ in 0..<160 {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            guard let entries = try? read(pid: pid, app: app), entries.count > 300 else { continue }
            if entries.count == previousCount {
                stableReads += 1
                if stableReads >= 2 { return entries }
            } else {
                stableReads = 0
                previousCount = entries.count
            }
        }
        throw MenuReaderError.timedOut
    }
}
