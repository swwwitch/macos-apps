import AppKit

/// Runs one LinkAction. Messages name what was done, never the clipboard contents beyond the copied link (B12).
final class ActionRunner {
    private weak var model: Model?
    init(model: Model) { self.model = model }

    private var simplify: Bool { model?.simplifyURL ?? true }

    // MARK: Page actions

    func run(_ action: LinkAction, browser: Browser, app: NSRunningApplication, completion: @escaping (ActionOutcome) -> Void) {
        let pid = app.processIdentifier
        if action == .tabsAsk {
            // 「どの形式で？」: asked at the mouse pointer.
            let formats: [LinkRules.TabListFormat] = [.urls, .titled, .markdown]
            guard let picked = Self.askChoice(L("copyTitle"), [L("tabFormat.urls"), L("tabFormat.titled"), L("tabFormat.markdown")]) else { completion(.success(L("cancelled"))); return }
            completion(copyTabs(formats[picked], browser: browser, pid: pid)); return
        }
        if action == .closeOtherTabs {
            completion(closeOtherTabs(browser: browser, pid: pid)); return
        }
        if action == .forceReload {
            let (code, flags) = browser.forceReloadKey
            BrowserBridge.key(code, flags, to: pid)
            completion(.silent); return
        }
        guard var page = BrowserBridge.page(pid: pid) else { completion(.failure(AccessibilityText.text("blocked"))); return }
        if page.url.isEmpty, let url = BrowserBridge.addressBarURL(pid: pid) { page.url = url }
        guard !page.url.isEmpty else { completion(.failure(String(format: L("fail.noURL"), browser.name))); return }
        guard !LinkRules.isEmptyPage(title: page.title, url: page.url) else { completion(.failure(L("fail.emptyPage"))); return }
        let url = LinkRules.cleanURL(page.url, simplify: simplify)
        var title = LinkRules.cleanTitle(page.title)
        if title.isEmpty { title = URLComponents(string: url)?.host ?? url }

        switch action {
        case .copyAsk:
            // 「どの形式で？」: asked at the mouse pointer; Amazon items only on a product page.
            let isAmazon = LinkRules.amazonASIN(page.url) != nil
            let formats = LinkAction.copyFormats.filter { isAmazon || ($0 != .copyAmazon && $0 != .copyAmazonAffiliate) }
            guard let picked = Self.askChoice(L("copyTitle"), formats.map { L($0.titleKey) }) else { completion(.success(L("cancelled"))); return }
            run(formats[picked], browser: browser, app: app, completion: completion)
        case .copyURL: completion(copy(LinkRules.format(.url, title: title, url: url), L("done.copyURL")))
        case .copyTitleLine: completion(copy(LinkRules.format(.titleLine, title: title, url: url), L("done.copyText")))
        case .copyTitleSpace: completion(copy(LinkRules.format(.titleSpace, title: title, url: url), L("done.copyText")))
        case .copyMarkdown: completion(copy(LinkRules.format(.markdown, title: title, url: url), L("done.copyMarkdown")))
        case .copyHTML: completion(copy(LinkRules.format(.html, title: title, url: url), L("done.copyHTML")))
        case .copyAmazon:
            guard let asin = LinkRules.amazonASIN(page.url) else { completion(.failure(L("fail.notAmazon"))); return }
            completion(copy(LinkRules.amazonLink(asin: asin, associateID: ""), L("done.copyAmazon")))
        case .copyAmazonAffiliate:
            guard let asin = LinkRules.amazonASIN(page.url) else { completion(.failure(L("fail.notAmazon"))); return }
            let id = (model?.associateID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { completion(.failure(L("fail.noAssociateID"))); return }
            completion(copy(LinkRules.amazonLink(asin: asin, associateID: id), L("done.copyAmazonAffiliate")))
        case .weblocAsk:
            saveFile(title: title, ext: "webloc", data: { try LinkFiles.webloc(url: url) }, completion: completion)
        case .qrAsk:
            saveFile(title: "qr-" + LinkRules.fileName(title, fallback: "link"), ext: "png", data: {
                guard let png = LinkFiles.qrPNG(text: url) else { throw CocoaError(.fileWriteUnknown) }
                return png
            }, completion: completion)
        case .reloadClean:
            let simple = LinkRules.cleanURL(page.url, simplify: true)
            guard simple != page.url else { completion(.success(L("done.alreadySimple"))); return }
            let outcome = copy(simple, L("done.reloadClean"))
            BrowserBridge.go(to: simple, pid: pid)
            completion(outcome)
        case .editMode:
            switch LinkRules.editURL(for: page.url) {
            case .url(let edit): BrowserBridge.go(to: edit, pid: pid); completion(.silent)
            case .alreadyEditing: completion(.success(L("done.alreadyEditing")))
            case .unsupported: completion(.failure(L("fail.noEditMode")))
            }
        case .translate:
            let target = model?.translateTarget ?? "ja"
            BrowserBridge.open([LinkRules.translateURL(url, target: target)], in: browser) { ok in
                completion(ok ? .silent : .failure(String(format: L("fail.open"), browser.name)))
            }
        case .newWindow:
            // The page's tab is closed first: after ⌘N the new window is in front and ⌘W would close it instead.
            BrowserBridge.key(13, .maskCommand, to: pid)       // ⌘W
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { BrowserBridge.key(45, .maskCommand, to: pid) }   // ⌘N
            BrowserBridge.go(to: url, pid: pid, afterDelay: 0.8)
            completion(.silent)
        case .privateWindow:
            let (code, flags) = browser.privateWindowKey
            BrowserBridge.key(code, flags, to: pid)
            BrowserBridge.go(to: url, pid: pid, afterDelay: 0.8)
            completion(.silent)
        case .openSafari, .openChrome, .openFirefox, .openEdge:
            let id = action.browserBundleID!
            let other = Browser.find(id)!
            guard other.bundleID != browser.bundleID else { completion(.failure(String(format: L("fail.sameBrowser"), other.name))); return }
            guard other.isInstalled else { completion(.failure(String(format: L("fail.notInstalled"), other.name))); return }
            BrowserBridge.open([url], in: other) { ok in
                completion(ok ? .silent : .failure(String(format: L("fail.open"), other.name)))
            }
        case .openNotion:
            // KM: only when the URL is a Notion page; opening it hands the https URL to the app.
            guard URL(string: url)?.host?.lowercased().contains("notion") == true else { completion(.failure(L("fail.notNotion"))); return }
            guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "notion.id"), let target = URL(string: url) else {
                completion(.failure(String(format: L("fail.notInstalled"), "Notion"))); return
            }
            let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = true
            NSWorkspace.shared.open([target], withApplicationAt: app, configuration: configuration) { _, error in
                DispatchQueue.main.async { completion(error == nil ? .silent : .failure(String(format: L("fail.open"), "Notion"))) }
            }
        default:
            completion(.silent)
        }
    }

    private func copy(_ text: String, _ message: String) -> ActionOutcome {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return .failure(L("fail.write")) }
        return .success(message + "\n\n" + text)
    }

    private func copyTabs(_ format: LinkRules.TabListFormat, browser: Browser, pid: pid_t) -> ActionOutcome {
        switch browser.kind == .firefox ? BrowserBridge.firefoxTabs(pid: pid) : BrowserBridge.tabs(of: browser) {
        case .failure(.denied): return .failure(String(format: L("fail.automation"), browser.name))
        case .failure(.failed(let message)): return .failure(L("fail.tabs") + message)
        case .success(let tabs):
            let text = LinkRules.tabList(tabs, format: format)
            guard !text.isEmpty else { return .failure(L("fail.noTabs")) }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.setString(text, forType: .string) else { return .failure(L("fail.write")) }
            let count = text.isEmpty ? 0 : tabs.filter { !LinkRules.isEmptyPage(title: $0.title, url: $0.url) }.count
            return .success(String(format: L("done.tabs"), String(count)))
        }
    }

    private func closeOtherTabs(browser: Browser, pid: pid_t) -> ActionOutcome {
        let result: Result<Int, BrowserBridge.ScriptError>
        if browser.kind == .firefox {
            guard AccessibilitySection.isTrusted else { return .failure(AccessibilityText.text("blocked")) }
            guard let count = BrowserBridge.firefoxCloseOtherTabs(pid: pid) else { return .failure(L("fail.closeTabsNoTabBar")) }
            result = .success(count)
        } else {
            result = BrowserBridge.closeOtherTabs(of: browser)
        }
        switch result {
        case .failure(.denied): return .failure(String(format: L("fail.automation"), browser.name))
        case .failure(.failed(let message)): return .failure(L("fail.closeTabs") + message)
        case .success(0): return .success(L("done.noOtherTabs"))
        case .success(let count): return .success(String(format: L("done.closedTabs"), String(count)))
        }
    }

    enum Destination { case desktop, folder(URL), choose }

    /// Pop-up menu at the mouse pointer: デスクトップ／開いているFinder・Path Finderのウインドウ（前面から順）／
    /// 最近使ったフォルダー（FinderとPath Finderの履歴、ウインドウと重複しないもの）／場所を指定…. nil = cancelled.
    static func askDestination(windows: Result<[URL], BrowserBridge.ScriptError>, recent: [URL]) -> Destination? {
        let menu = NSMenu(); menu.autoenablesItems = false
        let picker = MenuPicker()
        func header(_ title: String) { menu.addItem(withTitle: title, action: nil, keyEquivalent: "").isEnabled = false }
        func add(_ title: String, tag: Int, enabled: Bool = true, symbol: String) {
            let item = menu.addItem(withTitle: title, action: #selector(MenuPicker.pick(_:)), keyEquivalent: "")
            item.target = picker; item.tag = tag; item.isEnabled = enabled
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        var folders: [URL] = []
        func addFolders(_ list: [URL]) {
            for folder in list {
                let item = menu.addItem(withTitle: String(format: L("where.finder"), FileManager.default.displayName(atPath: folder.path)),
                                        action: #selector(MenuPicker.pick(_:)), keyEquivalent: "")
                item.target = picker; item.tag = folders.count; item.toolTip = folder.path
                item.image = NSWorkspace.shared.icon(forFile: folder.path)
                item.image?.size = NSSize(width: 16, height: 16)
                folders.append(folder)
            }
        }
        header(L("whereTitle"))
        add(L("where.desktop"), tag: -1, symbol: "menubar.dock.rectangle")
        switch windows {
        case .success(let list) where !list.isEmpty: addFolders(list)
        case .success: add(L("where.finderNone"), tag: -9, enabled: false, symbol: "folder")
        case .failure: add(L("where.finderDenied"), tag: -9, enabled: false, symbol: "folder")
        }
        let opened = Set(folders.map(\.standardizedFileURL.path))
        let history = recent.filter { !opened.contains($0.standardizedFileURL.path) && $0.standardizedFileURL.path != LinkFiles.desktop.standardizedFileURL.path }
        if !history.isEmpty {
            menu.addItem(.separator())
            header(L("where.recent"))
            addFolders(history)
        }
        menu.addItem(.separator())
        add(L("where.choose"), tag: -2, symbol: "ellipsis.circle")
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        switch picker.picked {
        case .some(-1): return .desktop
        case .some(-2): return .choose
        case let index? where folders.indices.contains(index): return .folder(folders[index])
        default: return nil
        }
    }

    /// Pop-up menu at the mouse pointer with a disabled header. Returns the picked index, nil = cancelled.
    static func askChoice(_ title: String, _ items: [String]) -> Int? {
        let menu = NSMenu(); menu.autoenablesItems = false
        let header = menu.addItem(withTitle: title, action: nil, keyEquivalent: ""); header.isEnabled = false
        let picker = MenuPicker()
        for (index, text) in items.enumerated() {
            let item = menu.addItem(withTitle: text, action: #selector(MenuPicker.pick(_:)), keyEquivalent: "")
            item.target = picker; item.tag = index
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        return picker.picked
    }

    private func saveFile(title: String, ext: String, data: () throws -> Data, completion: @escaping (ActionOutcome) -> Void) {
        let name = ext == "png" ? title : LinkRules.fileName(title, fallback: "link")
        let payload: Data
        do { payload = try data() } catch { completion(.failure(L("fail.write"))); return }
        func write(to folder: URL, reveal: Bool, note: String = "") {
            do {
                let file = try LinkFiles.write(payload, to: folder, name: name, ext: ext)
                if reveal { NSWorkspace.shared.activateFileViewerSelecting([file]) }
                completion(.success(String(format: L("done.saved"), file.lastPathComponent, folder.path) + note))
            } catch {
                completion(.failure(String(format: L("fail.save"), folder.path) + error.localizedDescription))
            }
        }
        // 「どこに？」: asked at the mouse pointer; every open Finder / Path Finder window, then their recent folders.
        guard let destination = Self.askDestination(windows: BrowserBridge.openFolderWindows(), recent: BrowserBridge.recentFolders()) else { completion(.success(L("cancelled"))); return }
        switch destination {
        case .desktop:
            write(to: LinkFiles.desktop, reveal: false)
        case .folder(let folder):
            write(to: folder, reveal: true)
        case .choose:
            NSApp.activate(ignoringOtherApps: true)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = L("chooseFolder"); panel.prompt = L("chooseFolderButton")
            panel.begin { response in
                guard response == .OK, let folder = panel.url else { completion(.success(L("cancelled"))); return }
                write(to: folder, reveal: true)
            }
        }
    }

    // MARK: Clipboard actions

    func runClipboard(_ action: LinkAction, browser: Browser?, completion: @escaping (ActionOutcome) -> Void) {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        let urls: [String]
        switch action {
        case .openClipboardURLs:
            urls = LinkRules.extractURLs(text)
            guard !urls.isEmpty else { completion(.failure(L("fail.noURLInClipboard"))); return }
        default:
            let terms = LinkRules.searchTerms(text)
            guard !terms.isEmpty else { completion(.failure(L("fail.noTextInClipboard"))); return }
            urls = terms.map(LinkRules.searchURL)
        }
        guard urls.count <= 30 else { completion(.failure(String(format: L("fail.tooMany"), String(urls.count)))); return }
        let done = String(format: L("done.opened"), String(urls.count))
        if let browser {
            BrowserBridge.open(urls, in: browser) { ok in completion(ok ? .success(done) : .failure(String(format: L("fail.open"), browser.name))) }
        } else {
            // No browser in use yet: the default browser, as the macro's 「OpenURL」.
            urls.compactMap(URL.init(string:)).forEach { NSWorkspace.shared.open($0) }
            completion(.success(done))
        }
    }
}

// MARK: Selected text in any app (「Make Link (misc)」)

extension ActionRunner {
    /// Copies the selection like the macros' 「テキストを選択しているときには自動でコピーする」: ⌘C is sent to the app;
    /// if the clipboard does not change (nothing selected), its current text is used instead.
    /// `restore` puts the previous clipboard back unless something else was copied meanwhile (B10).
    struct Selection { let text: String; let restore: () -> Void }
    static func copySelection(pid: pid_t) -> Selection {
        let pasteboard = NSPasteboard.general
        let saved = PasteboardSnapshot.take()
        let before = pasteboard.changeCount
        BrowserBridge.key(8, .maskCommand, to: pid)
        guard BrowserBridge.waitForChange(from: before, timeout: 0.5) else {
            return Selection(text: pasteboard.string(forType: .string) ?? "", restore: {})
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))  // some apps add more types right after the change
        let copied = pasteboard.changeCount
        return Selection(text: pasteboard.string(forType: .string) ?? "", restore: {
            if pasteboard.changeCount == copied { saved.restore() }
        })
    }

    func runSelection(_ action: LinkAction, app: NSRunningApplication, completion: @escaping (ActionOutcome) -> Void) {
        let selection = Self.copySelection(pid: app.processIdentifier)
        let text = selection.text
        let urls = LinkRules.extractURLs(text)
        func needURLs() -> Bool {
            if urls.isEmpty { selection.restore(); completion(.failure(L("fail.noURLInSelection"))); return false }
            if urls.count > 30 { selection.restore(); completion(.failure(String(format: L("fail.tooMany"), String(urls.count)))); return false }
            return true
        }
        switch action {
        case .selOpenDefault:
            guard needURLs() else { return }
            selection.restore()
            urls.compactMap(URL.init(string:)).forEach { NSWorkspace.shared.open($0) }
            completion(.success(String(format: L("done.opened"), String(urls.count))))
        case .selOpenChoose:
            guard needURLs() else { return }
            selection.restore()
            let browsers = Browser.all.filter(\.isInstalled)
            guard let browser = Self.chooseBrowser(browsers, count: urls.count) else { completion(.success(L("cancelled"))); return }
            BrowserBridge.open(urls, in: browser) { ok in
                completion(ok ? .success(String(format: L("done.opened"), String(urls.count))) : .failure(String(format: L("fail.open"), browser.name)))
            }
        case .selOpenAll:
            guard needURLs() else { return }
            selection.restore()
            // The macro's three browsers, those installed.
            let browsers = ["com.apple.Safari", "org.mozilla.firefox", "com.google.Chrome"].compactMap(Browser.find).filter(\.isInstalled)
            guard !browsers.isEmpty else { completion(.failure(String(format: L("fail.notInstalled"), "Safari / Firefox / Google Chrome"))); return }
            browsers.forEach { BrowserBridge.open(urls, in: $0) { _ in } }
            completion(.success(String(format: L("done.openedAll"), String(urls.count), browsers.map(\.name).joined(separator: "・"))))
        default:
            selection.restore()
            completion(.silent)
        }
    }

    /// 「ダイアログボックスでブラウザーを選択」. nil = cancelled.
    static func chooseBrowser(_ browsers: [Browser], count: Int) -> Browser? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("chooseBrowser")
        alert.informativeText = String(format: L("chooseBrowserDetail"), String(count))
        for browser in browsers {
            let button = alert.addButton(withTitle: browser.name)
            button.image = appIcon(for: browser.bundleID).map { image in image.size = NSSize(width: 16, height: 16); return image }
            button.imagePosition = .imageLeading
        }
        let cancel = alert.addButton(withTitle: L("cancel"))
        cancel.keyEquivalent = "\u{1b}"
        let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return browsers.indices.contains(index) ? browsers[index] : nil
    }

}

/// Receives the item chosen in the destination menu (popUp returns after the action is sent).
final class MenuPicker: NSObject {
    var picked: Int?
    @objc func pick(_ item: NSMenuItem) { picked = item.tag }
}
