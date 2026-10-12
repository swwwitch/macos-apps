import AppKit

/// Runs one LinkAction. Messages name what was done, never the clipboard contents beyond the copied link (B12).
final class ActionRunner {
    private weak var model: Model?
    init(model: Model) { self.model = model }

    private var simplify: Bool { model?.simplifyURL ?? true }

    // MARK: Page actions

    func run(_ action: LinkAction, browser: Browser, app: NSRunningApplication, completion: @escaping (ActionOutcome) -> Void) {
        let pid = app.processIdentifier
        if action.group == .tabs { completion(copyTabs(action, browser: browser)); return }
        if action == .forceReload {
            let (code, flags) = browser.forceReloadKey
            BrowserBridge.key(code, flags, to: pid)
            completion(.silent); return
        }
        guard var page = BrowserBridge.page(pid: pid) else { completion(.failure(L("fail.access"))); return }
        if page.url.isEmpty, let url = BrowserBridge.addressBarURL(pid: pid) { page.url = url }
        guard !page.url.isEmpty else { completion(.failure(String(format: L("fail.noURL"), browser.name))); return }
        guard !LinkRules.isEmptyPage(title: page.title, url: page.url) else { completion(.failure(L("fail.emptyPage"))); return }
        let url = LinkRules.cleanURL(page.url, simplify: simplify)
        var title = LinkRules.cleanTitle(page.title)
        if title.isEmpty { title = URLComponents(string: url)?.host ?? url }

        switch action {
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
        case .weblocAsk, .weblocDesktop, .weblocFinder, .weblocChoose:
            saveFile(action, title: title, ext: "webloc", data: { try LinkFiles.webloc(url: url) }, completion: completion)
        case .qrAsk, .qrDesktop, .qrFinder, .qrChoose:
            saveFile(action, title: "qr-" + LinkRules.fileName(title, fallback: "link"), ext: "png", data: {
                guard let png = LinkFiles.qrPNG(text: url) else { throw CocoaError(.fileWriteUnknown) }
                return png
            }, completion: completion)
        case .reloadClean:
            let simple = LinkRules.cleanURL(page.url, simplify: true)
            guard simple != page.url else { completion(.success(L("done.alreadySimple"))); return }
            BrowserBridge.go(to: simple, pid: pid)
            completion(.silent)
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
            BrowserBridge.key(45, .maskCommand, to: pid)       // ⌘N
            BrowserBridge.go(to: url, pid: pid, afterDelay: 0.6)
            completion(.silent)
        case .privateWindow:
            let (code, flags) = browser.privateWindowKey
            BrowserBridge.key(code, flags, to: pid)
            BrowserBridge.go(to: url, pid: pid, afterDelay: 0.8)
            completion(.silent)
        case .openSafari, .openChrome, .openFirefox, .openEdge:
            let id = [LinkAction.openSafari: "com.apple.Safari", .openChrome: "com.google.Chrome", .openFirefox: "org.mozilla.firefox", .openEdge: "com.microsoft.edgemac"][action]!
            let other = Browser.find(id)!
            guard other.bundleID != browser.bundleID else { completion(.failure(String(format: L("fail.sameBrowser"), other.name))); return }
            guard other.isInstalled else { completion(.failure(String(format: L("fail.notInstalled"), other.name))); return }
            BrowserBridge.open([url], in: other) { ok in
                completion(ok ? .silent : .failure(String(format: L("fail.open"), other.name)))
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

    private func copyTabs(_ action: LinkAction, browser: Browser) -> ActionOutcome {
        guard browser.canListTabs else { return .failure(String(format: L("fail.tabsUnsupported"), browser.name)) }
        switch BrowserBridge.tabs(of: browser) {
        case .failure(.denied): return .failure(String(format: L("fail.automation"), browser.name))
        case .failure(.failed(let message)): return .failure(L("fail.tabs") + message)
        case .success(let tabs):
            let format: LinkRules.TabListFormat = action == .tabsURLs ? .urls : (action == .tabsTitled ? .titled : .markdown)
            let text = LinkRules.tabList(tabs, format: format)
            guard !text.isEmpty else { return .failure(L("fail.noTabs")) }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.setString(text, forType: .string) else { return .failure(L("fail.write")) }
            let count = text.isEmpty ? 0 : tabs.filter { !LinkRules.isEmptyPage(title: $0.title, url: $0.url) }.count
            return .success(String(format: L("done.tabs"), String(count)))
        }
    }

    enum Destination: Int { case desktop = 1, finder, choose }

    /// Pop-up menu at the mouse pointer: デスクトップ／前面のFinderウインドウ（フォルダー名）／場所を指定…. nil = cancelled.
    static func askDestination(finder: Result<URL?, BrowserBridge.ScriptError>) -> Destination? {
        let menu = NSMenu(); menu.autoenablesItems = false
        let header = menu.addItem(withTitle: L("whereTitle"), action: nil, keyEquivalent: ""); header.isEnabled = false
        let picker = MenuPicker()
        func add(_ title: String, _ destination: Destination, enabled: Bool = true, symbol: String) {
            let item = menu.addItem(withTitle: title, action: #selector(MenuPicker.pick(_:)), keyEquivalent: "")
            item.target = picker; item.tag = destination.rawValue; item.isEnabled = enabled
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        add(L("where.desktop"), .desktop, symbol: "menubar.dock.rectangle")
        switch finder {
        case .success(let folder?): add(String(format: L("where.finder"), FileManager.default.displayName(atPath: folder.path)), .finder, symbol: "folder")
        case .success(nil): add(L("where.finderNone"), .finder, enabled: false, symbol: "folder")
        case .failure: add(L("where.finderDenied"), .finder, enabled: false, symbol: "folder")
        }
        add(L("where.choose"), .choose, symbol: "ellipsis.circle")
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        return picker.picked.flatMap(Destination.init(rawValue:))
    }

    private func saveFile(_ action: LinkAction, title: String, ext: String, data: () throws -> Data, completion: @escaping (ActionOutcome) -> Void) {
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
        var destination: Destination
        var finder: Result<URL?, BrowserBridge.ScriptError>?
        switch action {
        case .weblocDesktop, .qrDesktop: destination = .desktop
        case .weblocFinder, .qrFinder: destination = .finder
        case .weblocChoose, .qrChoose: destination = .choose
        default:
            // 「どこに？」: asked at the mouse pointer; the Finder item names the folder it will use.
            finder = BrowserBridge.frontFinderFolder()
            guard let picked = Self.askDestination(finder: finder!) else { completion(.success(L("cancelled"))); return }
            destination = picked
        }
        switch destination {
        case .desktop:
            write(to: LinkFiles.desktop, reveal: false)
        case .finder:
            switch finder ?? BrowserBridge.frontFinderFolder() {
            case .success(let folder?): write(to: folder, reveal: true)
            case .success(nil): write(to: LinkFiles.desktop, reveal: true, note: "\n" + L("note.noFinderWindow"))
            case .failure(.denied): completion(.failure(String(format: L("fail.automation"), "Finder")))
            case .failure(.failed(let message)): completion(.failure(L("fail.finder") + message))
            }
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
        if action == .fileWhereFrom { completion(weblocFromDownloadedFiles()); return }
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
        case .selSearch, .selDictionary:
            selection.restore()
            let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else { completion(.failure(L("fail.noSelection"))); return }
            guard term.count <= 1000 else { completion(.failure(L("fail.selectionTooLong"))); return }
            let address = action == .selSearch ? LinkRules.searchURL(term) : LinkRules.dictionaryURL(term)
            guard let url = URL(string: address) else { completion(.failure(L("fail.noSelection"))); return }
            if action == .selDictionary, NSWorkspace.shared.urlForApplication(toOpen: url) == nil {
                completion(.failure(L("fail.noDictionary"))); return
            }
            NSWorkspace.shared.open(url)
            completion(.silent)
        case .selJina:
            guard needURLs() else { return }
            completion(copy(LinkRules.jinaLines(urls), L("done.copyJina")))
        case .selURLTextDesktop, .selURLTextFinder:
            guard needURLs() else { return }
            let list = LinkRules.urlList(urls)
            let folder: URL
            var note = ""
            if action == .selURLTextDesktop { folder = LinkFiles.desktop }
            else {
                switch BrowserBridge.frontFinderFolder() {
                case .success(let found?): folder = found
                case .success(nil): folder = LinkFiles.desktop; note = "\n" + L("note.noFinderWindow")
                case .failure(.denied): selection.restore(); completion(.failure(String(format: L("fail.automation"), "Finder"))); return
                case .failure(.failed(let message)): selection.restore(); completion(.failure(L("fail.finder") + message)); return
                }
            }
            do {
                let file = try LinkFiles.write(Data(list.utf8), to: folder, name: LinkRules.urlListFileName(Date()), ext: "txt")
                NSWorkspace.shared.activateFileViewerSelecting([file])
                NSWorkspace.shared.open(file)
                // As the macro: the extracted list stays on the clipboard.
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents(); pasteboard.setString(list, forType: .string)
                completion(.success(String(format: L("done.saved"), file.lastPathComponent, folder.path) + note))
            } catch {
                selection.restore()
                completion(.failure(String(format: L("fail.save"), folder.path) + error.localizedDescription))
            }
        case .selWeblocDesktop, .selWeblocFinder:
            guard needURLs() else { return }
            selection.restore()
            var folder = LinkFiles.desktop
            var note = ""
            if action == .selWeblocFinder {
                switch BrowserBridge.frontFinderFolder() {
                case .success(let found?): folder = found
                case .success(nil): note = "\n" + L("note.noFinderWindow")
                case .failure(.denied): completion(.failure(String(format: L("fail.automation"), "Finder"))); return
                case .failure(.failed(let message)): completion(.failure(L("fail.finder") + message)); return
                }
            }
            var written: [URL] = []
            for url in urls.prefix(10) {
                // 「ファイル名（サイト名）を入力してください。」 for each URL, as the macro.
                guard let name = Self.askName(url: url) else { break }
                do {
                    written.append(try LinkFiles.write(try LinkFiles.webloc(url: url), to: folder, name: LinkRules.fileName(name, fallback: LinkRules.suggestedName(for: url)), ext: "webloc"))
                } catch {
                    completion(.failure(String(format: L("fail.save"), folder.path) + error.localizedDescription)); return
                }
            }
            guard !written.isEmpty else { completion(.success(L("cancelled"))); return }
            NSWorkspace.shared.activateFileViewerSelecting(written)
            completion(.success(String(format: L("done.savedCount"), String(written.count), folder.path) + note))
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

    /// Name for a webloc made from selected text; nil = cancelled.
    static func askName(url: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("weblocNameTitle")
        alert.informativeText = String(format: L("weblocNameDetail"), url)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = LinkRules.suggestedName(for: url)
        field.setAccessibilityLabel(L("weblocNameTitle"))
        alert.accessoryView = field
        alert.addButton(withTitle: L("save"))
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? LinkRules.suggestedName(for: url) : name
    }

    /// 「選択したファイルから」: a webloc next to each file selected in Finder, pointing to where it was downloaded from.
    func weblocFromDownloadedFiles() -> ActionOutcome {
        let source = """
        tell application id "com.apple.finder"
            set picked to selection as alias list
        end tell
        set out to ""
        repeat with f in picked
            set out to out & POSIX path of f & linefeed
        end repeat
        return out
        """
        let paths: [String]
        switch BrowserBridge.run(source) {
        case .denied: return .failure(String(format: L("fail.automation"), "Finder"))
        case .failed(let message): return .failure(L("fail.finder") + message)
        case .value(let text): paths = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty && !$0.hasSuffix("/") }
        }
        guard !paths.isEmpty else { return .failure(L("fail.noFileSelected")) }
        var written: [URL] = []
        var missing = 0
        for path in paths.prefix(20) {
            let file = URL(fileURLWithPath: path)
            let froms = (MDItemCreateWithURL(nil, file as CFURL).flatMap { MDItemCopyAttribute($0, kMDItemWhereFroms) } as? [String]) ?? []
            let sources = LinkRules.webSources(froms)
            guard !sources.isEmpty else { missing += 1; continue }
            // The macro showed the source for confirmation; with both the file's URL and its page, either can be chosen.
            guard let url = Self.chooseSource(sources, file: file.lastPathComponent) else { break }
            do {
                written.append(try LinkFiles.write(try LinkFiles.webloc(url: url), to: file.deletingLastPathComponent(),
                                                   name: file.deletingPathExtension().lastPathComponent, ext: "webloc"))
            } catch {
                return .failure(String(format: L("fail.save"), file.deletingLastPathComponent().path) + error.localizedDescription)
            }
        }
        if written.isEmpty { return missing > 0 ? .failure(L("fail.noWhereFrom")) : .success(L("cancelled")) }
        NSWorkspace.shared.activateFileViewerSelecting(written)
        let note = missing > 0 ? "\n" + String(format: L("note.noWhereFrom"), String(missing)) : ""
        return .success(String(format: L("done.savedCount"), String(written.count), written[0].deletingLastPathComponent().path) + note)
    }

    static func chooseSource(_ sources: [String], file: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(format: L("whereFromTitle"), file)
        alert.informativeText = sources.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        for (index, _) in sources.prefix(2).enumerated() { alert.addButton(withTitle: L(index == 0 ? "whereFromFile" : "whereFromPage")) }
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return index < min(2, sources.count) ? sources[index] : nil
    }
}

/// Receives the item chosen in the destination menu (popUp returns after the action is sent).
final class MenuPicker: NSObject {
    var picked: Int?
    @objc func pick(_ item: NSMenuItem) { picked = item.tag }
}
