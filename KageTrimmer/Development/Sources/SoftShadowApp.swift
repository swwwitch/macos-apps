import AppKit
import UniformTypeIdentifiers
import Carbon

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shortcut = KageShortcut()
    private var settingsWindow: NSWindow?
    private var window: NSWindow!
    private var mainViewController: MainViewController?
    private var pendingOpenURLs: [URL] = []
    private var quitAfterPendingOpen = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowActivationPolicy.install()
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "KageTrimmer", symbol: "photo", existing: nil,
                show: { [weak self] in self?.showMainWindow() },
                settings: { [weak self] in self?.showSettings() },
                help: { [weak self] in LocalHelp.shared.show() })
        } }
        DispatchQueue.main.async { LocalHelp.shared.install() }
        let loginLaunch = Self.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        installMainMenu()
        shortcut.action = { [weak self] in self?.performShortcut() }
        shortcut.restore()
        // Miniaturizable so the yellow button and Window > Minimize work (no key equivalent); full screen stays off.
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 455), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = ""
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let controller = MainViewController()
        mainViewController = controller
        window.contentViewController = controller
        window.center()
        FolderWatcher.shared.onCapture = { [weak self] urls in self?.processWatched(urls) }
        FolderWatcher.shared.restart()
        // 「設定の共有」: shadow, border, suffixes and success actions. The hotkey, login, menu bar and folder watch stay per Mac.
        SettingsSync.shared.onImport = { [weak self] in
            self?.mainViewController?.reloadSharedSettings()
            (self?.settingsWindow?.contentViewController as? ShortcutSettingsController)?.reloadSharedSettings()
        }
        SettingsSync.shared.start(.init(
            keys: ["addBorder", ShadowSizes.defaultKey, SuccessActions.soundKey, SuccessActions.revealKey, SuccessActions.trashKey],
            prefixes: ["outputSuffix."],  // ShadowProcessor.suffixKey(shadowSize:)
            note: StartupWindow.text("影の大きさ・罫線・ファイル名の接尾辞・処理に成功したときの動作を書き出し・同期します。",
                                     "Exports and syncs the shadow size, border, file name suffixes and what happens after success.",
                                     "导出并同步阴影大小、边框、文件名后缀以及处理成功后的操作。",
                                     "그림자 크기, 테두리, 파일 이름 접미사, 처리에 성공했을 때의 동작을 내보내고 동기화합니다."),
            perMac: StartupWindow.text("ログイン時の起動・メニューバー・ホットキー・フォルダ監視はMacごとに設定します。",
                                       "Login launch, the menu bar, the hotkey and folder watching are set on each Mac.",
                                       "登录时启动、菜单栏、快捷键和文件夹监视需在每台 Mac 上分别设置。",
                                       "로그인 시 실행, 메뉴 막대, 단축키, 폴더 감시는 Mac마다 설정합니다.")))
        // A login launch stays quiet; files handed over at launch still show the window.
        if (!StartupWindow.hidden && !loginLaunch) || !pendingOpenURLs.isEmpty { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
        if !pendingOpenURLs.isEmpty {
            let urls = pendingOpenURLs
            let shouldQuit = quitAfterPendingOpen
            pendingOpenURLs.removeAll()
            quitAfterPendingOpen = false
            DispatchQueue.main.async {
                controller.process(urls) { _ in
                    if shouldQuit { NSApp.terminate(nil) }
                }
            }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard mainViewController?.isProcessing == true else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = L("画像の処理中は終了できません"); alert.informativeText = L("処理が終わってから、もう一度終了してください。"); alert.addButton(withTitle: L("OK"))
        alert.runModal()
        return .terminateCancel
    }
    private static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openMainWindowFromMenu(_ sender: Any?) {
        showMainWindow()
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let controller = ShortcutSettingsController(shortcut: shortcut)
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            panel.title = L("設定")
            panel.isReleasedWhenClosed = false
            panel.contentViewController = controller
            // Resizable from the designed size upward; the tab view follows via its autoresizing mask.
            panel.contentMinSize = NSSize(width: 520, height: 560)
            panel.center()
            settingsWindow = panel
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Window screenshots added to the watched folder: processed in the background like a hotkey run,
    /// without bringing the window forward. Waits while another batch is being processed.
    private func processWatched(_ urls: [URL]) {
        guard let mainViewController else { return }
        if mainViewController.isProcessing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.processWatched(urls) }
            return
        }
        mainViewController.process(urls)
    }

    private func performShortcut() {
        #if !APP_STORE
        // Images selected in the frontmost Finder / Path Finder are processed in place; otherwise the window comes forward.
        if let mainViewController, !mainViewController.isProcessing {
            switch FileBrowserSelection.selectedFiles() {
            case .files(let urls) where mainViewController.containsImages(urls):
                mainViewController.process(urls) { [weak self] succeeded in
                    if !succeeded { self?.showMainWindow() }
                }
                return
            case .denied:
                mainViewController.showStatus(L("FinderまたはPath Finderの選択を読み取れませんでした。システム設定の「プライバシーとセキュリティ」＞「オートメーション」で、KageTrimmerに許可してください。"))
            default:
                break
            }
        }
        #endif
        showMainWindow()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        if let mainViewController {
            // Already running (Dock drop / Open With into the resident app): keep running after processing.
            mainViewController.process(urls)
            window?.makeKeyAndOrderFront(nil)
            sender.activate(ignoringOtherApps: true)
        } else {
            // Launched just to open these files: quit after processing.
            pendingOpenURLs.append(contentsOf: urls)
            quitAfterPendingOpen = true
        }
        sender.reply(toOpenOrPrint: .success)
    }

    @objc private func chooseImages() {
        // The menu item is disabled while processing (validateMenuItem); this guards a stale invocation.
        guard mainViewController?.isProcessing != true else { return }
        showMainWindow()
        let panel = NSOpenPanel()
        panel.title = L("処理する画像を選択")
        panel.prompt = L("選択")
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.mainViewController?.process(panel.urls)
        }
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: "KageTrimmer", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "KageTrimmer")
        appMenu.addItem(withTitle: L("KageTrimmerについて"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: L("設定…"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: appMenu) }
        #endif
        addStandardApplicationCommands(to: appMenu, name: "KageTrimmer")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem(title: L("ファイル"), action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: L("ファイル"))
        let showMain = fileMenu.addItem(withTitle: L("メインウインドウを開く"), action: #selector(openMainWindowFromMenu(_:)), keyEquivalent: "0")
        showMain.keyEquivalentModifierMask = [.command]
        showMain.target = self
        fileMenu.addItem(.separator())
        let open = fileMenu.addItem(withTitle: L("画像を選択…"), action: #selector(chooseImages), keyEquivalent: "o")
        open.target = self
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("ウインドウを閉じる"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        let editRoot = NSMenuItem(title: L("編集"), action: nil, keyEquivalent: "")
        let edit = NSMenu(title: L("編集")); editRoot.submenu = edit; mainMenu.addItem(editRoot)
        edit.addItem(withTitle: L("取り消す"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L("やり直す"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        for (title, selector, key) in [(L("カット"), "cut:", "x"), (L("コピー"), "copy:", "c"), (L("ペースト"), "paste:", "v"), (L("すべてを選択"), "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        addStandardWindowMenu(to: mainMenu)
        NSApp.mainMenu = mainMenu
    }
}

@main
enum KageTrimmerMain {
    @MainActor static func main() {
        SingleInstanceLaunch.enforce()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        _ = delegate
    }
}

extension AppDelegate: NSMenuItemValidation {
    /// 「画像を選択…」 is unavailable while images are being processed, instead of beeping when chosen.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(chooseImages) { return mainViewController?.isProcessing != true }
        return true
    }
}

final class MainViewController: NSViewController {
    private let dropView = DropView()
    var isProcessing: Bool { dropView.isProcessing }
    private let borderCheck = NSButton(checkboxWithTitle: L("薄い罫線を付ける"), target: nil, action: nil)
    private let choices = ShadowSizes.choices
    private var radioButtons: [NSButton] = []
    private let status = NSTextField(labelWithString: L("処理後の画像は元ファイルと同じ場所に「-s.png」で保存されます"))
    private var addBorder = UserDefaults.standard.object(forKey: "addBorder") as? Bool ?? true
    // Starts from the default in Settings; a choice in the main window lasts until quit.
    private var shadowSize = ShadowSizes.defaultSize
    private var outputFolderGrants: [String: URL] = [:]

    deinit {
        for folder in outputFolderGrants.values { folder.stopAccessingSecurityScopedResource() }
    }

    private func authorizeOutputFolders(for urls: [URL]) -> Bool {
        let folders = Set(urls.map { $0.deletingLastPathComponent().standardizedFileURL })
        for folder in folders.sorted(by: { $0.path < $1.path }) {
            if outputFolderGrants[folder.path] != nil || FileManager.default.isWritableFile(atPath: folder.path) { continue }
            // A hotkey run starts in the background; the panel needs the app in front.
            NSApp.activate(ignoringOtherApps: true)
            let panel = NSOpenPanel()
            panel.title = L("元画像のフォルダへの保存を許可")
            panel.message = L("処理した画像を同じフォルダに「%@.png」で保存するため、元画像があるフォルダを選択してください。", String(describing: ShadowProcessor.outputSuffix(shadowSize: shadowSize)))
            panel.prompt = L("アクセスを許可")
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false
            panel.directoryURL = folder
            guard panel.runModal() == .OK, let selected = panel.url,
                  selected.standardizedFileURL.resolvingSymlinksInPath() == folder.resolvingSymlinksInPath() else {
                status.stringValue = L("元画像のフォルダへのアクセスが許可されなかったため、処理を中止しました。")
                return false
            }
            if selected.startAccessingSecurityScopedResource() {
                outputFolderGrants[folder.path] = selected
            } else if !FileManager.default.isWritableFile(atPath: folder.path) {
                status.stringValue = L("元画像のフォルダに保存できません。アクセス権を確認してください。")
                return false
            }
        }
        return true
    }
    override func loadView() {
        NotificationCenter.default.addObserver(self, selector: #selector(outputSettingsChanged(_:)), name: ShadowSizes.settingsChanged, object: nil)
        updateOutputDescription()
        view = AdaptiveBackgroundView(frame: NSRect(x: 0, y: 0, width: 540, height: 455), color: NSColor(srgbRed: 236.0 / 255, green: 236.0 / 255, blue: 236.0 / 255, alpha: 1), isMainBackground: true)
        let icon = NSImageView(image: currentAppIcon()); icon.imageScaling = .scaleProportionallyUpOrDown
        let title = NSTextField(labelWithString: L("画像の影を調整")); title.font = .boldSystemFont(ofSize: 18)
        let subtitle = NSTextField(labelWithString: L("スクリーンショットの影をコンパクトに")); subtitle.font = .systemFont(ofSize: 11); subtitle.textColor = .secondaryLabelColor
        let titleStack = NSStackView(views: [title, subtitle]); titleStack.orientation = .vertical; titleStack.alignment = .leading; titleStack.spacing = 2
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Same as the other apps: a borderless gear button at the right of the header. Nil target reaches AppDelegate.
        let settingsButton = NSButton(title: L("設定"), image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)!, target: nil, action: #selector(AppDelegate.showSettings))
        settingsButton.isBordered = false; settingsButton.imagePosition = .imageLeading; settingsButton.toolTip = L("設定") + " (⌘,)"
        settingsButton.refusesFirstResponder = true
        let iconColumn = NSStackView(views: [icon, appVersionLabel()]); iconColumn.orientation = .vertical; iconColumn.alignment = .centerX; iconColumn.spacing = 4
        let header = NSStackView(views: [iconColumn, titleStack, spacer, settingsButton]); header.orientation = .horizontal; header.alignment = .centerY; header.spacing = 10
        let sizeLabel = NSTextField(labelWithString: L("影の大きさ")); sizeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        radioButtons = choices.map { name, size in
            let button = NSButton(radioButtonWithTitle: size == 0 ? name : "\(name)（\(size)）", target: self, action: #selector(sizeChanged(_:)))
            button.controlSize = .small; button.tag = size; button.state = size == shadowSize ? .on : .off
            return button
        }
        let sizeRow = NSStackView(views: [sizeLabel] + radioButtons); sizeRow.orientation = .horizontal; sizeRow.alignment = .centerY; sizeRow.spacing = 10
        borderCheck.controlSize = .small; borderCheck.state = addBorder ? .on : .off; borderCheck.target = self; borderCheck.action = #selector(borderChanged(_:))
        let optionsStack = NSStackView(views: [sizeRow, borderCheck]); optionsStack.orientation = .vertical; optionsStack.alignment = .leading; optionsStack.spacing = 6
        updateOutputDescription()
        dropView.onDrop = { [weak self] urls in self?.process(urls) }
        status.textColor = .secondaryLabelColor; status.font = .systemFont(ofSize: 11); status.maximumNumberOfLines = 3; status.lineBreakMode = .byWordWrapping; status.alignment = .center
        let headerPanel = AppSurfaceView(frame: .zero)
        headerPanel.translatesAutoresizingMaskIntoConstraints = false; header.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.translatesAutoresizingMaskIntoConstraints = false; dropView.translatesAutoresizingMaskIntoConstraints = false; status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerPanel); view.addSubview(header); view.addSubview(optionsStack); view.addSubview(dropView); view.addSubview(status)
        NSLayoutConstraint.activate([
            headerPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor), headerPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor), headerPanel.topAnchor.constraint(equalTo: view.topAnchor), headerPanel.heightAnchor.constraint(equalToConstant: 82),
            header.leadingAnchor.constraint(equalTo: headerPanel.leadingAnchor, constant: 22), header.trailingAnchor.constraint(equalTo: headerPanel.trailingAnchor, constant: -22), header.centerYAnchor.constraint(equalTo: headerPanel.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 44), icon.heightAnchor.constraint(equalToConstant: 44),
            optionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), optionsStack.topAnchor.constraint(equalTo: headerPanel.bottomAnchor, constant: 12),
            dropView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22), dropView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22), dropView.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 12), dropView.heightAnchor.constraint(equalToConstant: 245),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22), status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22), status.topAnchor.constraint(equalTo: dropView.bottomAnchor, constant: 15)
        ])
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        // The key-view loop focuses the first radio (影なし); Space or an arrow key would then switch the size unnoticed.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.view.window, let focused = window.firstResponder as? NSButton,
                  self.radioButtons.contains(where: { $0 === focused }) else { return }
            window.makeFirstResponder(nil)
        }
    }
    private func updateOutputDescription() {
        borderCheck.isEnabled = shadowSize != 0
        status.stringValue = (shadowSize == 0 ? L("影のない画像はスキップします。\n") : "") + L("処理後の画像は元ファイルと同じ場所に「%@.png」で保存されます", String(describing: ShadowProcessor.outputSuffix(shadowSize: shadowSize)))
    }
    @objc private func sizeChanged(_ sender: NSButton) {
        shadowSize = sender.tag
        updateOutputDescription()
        for button in radioButtons { button.state = button === sender ? .on : .off }
    }
    /// A new default in Settings is applied to the main window too; a suffix change only updates the description.
    @objc private func outputSettingsChanged(_ notification: Notification) {
        if let size = notification.userInfo?[ShadowSizes.defaultKey] as? Int {
            shadowSize = size
            for button in radioButtons { button.state = button.tag == size ? .on : .off }
        }
        updateOutputDescription()
    }
    /// Settings imported or synced from another Mac: the border and the starting shadow size.
    func reloadSharedSettings() {
        addBorder = UserDefaults.standard.object(forKey: "addBorder") as? Bool ?? true
        borderCheck.state = addBorder ? .on : .off
        shadowSize = ShadowSizes.defaultSize
        for button in radioButtons { button.state = button.tag == shadowSize ? .on : .off }
        updateOutputDescription()
    }
    @objc private func borderChanged(_ sender: NSButton) {
        addBorder = sender.state == .on
        UserDefaults.standard.set(addBorder, forKey: "addBorder")
    }
    private static func imageFiles(_ urls: [URL]) -> [URL] {
        urls.filter { $0.isFileURL && UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }
    }
    func containsImages(_ urls: [URL]) -> Bool { !Self.imageFiles(urls).isEmpty }
    func showStatus(_ text: String) { status.stringValue = text }
    /// The completion gets false when anything failed or was skipped, so a background run (hotkey, folder watch)
    /// can show the window with the results. What happens after success follows the 「出力」 settings.
    func process(_ urls: [URL], completion: @escaping (Bool) -> Void = { _ in }) {
        let supported = Self.imageFiles(urls)
        guard !supported.isEmpty else {
            status.stringValue = L("画像ファイルをドロップしてください。")
            completion(false)
            return
        }
        guard authorizeOutputFolders(for: supported) else {
            completion(false)
            return
        }
        status.stringValue = L("処理しています…"); dropView.isProcessing = true
        let border = addBorder
        let size = shadowSize
        let trashesOriginals = SuccessActions.trashesOriginals
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var results: [String] = []
            var outputs: [URL] = []
            var allSucceeded = true
            for url in supported {
                do {
                    let result = try ShadowProcessor.process(url: url, addBorderWhenMissing: border, shadowSize: size)
                    let action = size == 0 ? L("影を除去") : (result.hadShadow ? L("既存の影を軽量化") : L("影を追加"))
                    results.append("✓ \(result.output.lastPathComponent)（\(action)）")
                    outputs.append(result.output)
                    // Only the original of an image that was written; to the Trash so it can be put back.
                    if trashesOriginals, result.output.standardizedFileURL != url.standardizedFileURL {
                        do { try FileManager.default.trashItem(at: url, resultingItemURL: nil) } catch {
                            results.append(L("⚠︎ %@：元の画像をゴミ箱に入れられませんでした", String(describing: url.lastPathComponent))); allSucceeded = false
                        }
                    }
                } catch ShadowError.noShadow { results.append(L("− %@：影がないためスキップ", String(describing: url.lastPathComponent))); allSucceeded = false
                } catch { results.append("⚠︎ \(url.lastPathComponent)：\(error.localizedDescription)"); allSucceeded = false }
            }
            DispatchQueue.main.async {
                self?.status.stringValue = results.joined(separator: "\n")
                self?.dropView.isProcessing = false
                if allSucceeded && SuccessActions.playsSound { NSSound(named: "Glass")?.play() }
                if !outputs.isEmpty && SuccessActions.revealsOutputs { NSWorkspace.shared.activateFileViewerSelecting(outputs) }
                completion(allSucceeded)
            }
        }
    }
}

final class DropView: NSView {
    var onDrop: (([URL]) -> Void)?
    var isProcessing = false { didSet { needsDisplay = true; NSAccessibility.post(element: self, notification: .titleChanged) } }
    private var targeted = false
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); registerForDraggedTypes([.fileURL]) }
    // Custom-drawn drop target: VoiceOver reads what it is and how to choose an image without dragging.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? {
        if isProcessing { return L("処理しています…") }
        let stop = StartupWindow.text("。", ". ", "。", ". ")
        let menuHint = String(format: StartupWindow.text("ファイルメニューの「%@」（⌘O）でも選べます", "You can also use File > %@ (⌘O)", "也可以使用“文件”菜单中的“%@”（⌘O）", "파일 메뉴의 '%@'(⌘O)로도 선택할 수 있습니다"), L("画像を選択…"))
        return L("画像ファイルをここにドロップ") + stop + L("複数画像・アプリアイコンへのドロップにも対応") + stop + menuHint
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1.5, dy: 1.5); let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        (targeted ? NSColor.controlAccentColor.withAlphaComponent(0.10) : NSColor.textBackgroundColor).setFill(); path.fill()
        (targeted ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 2
        if !targeted { path.setLineDash([7, 5], count: 2, phase: 0) }
        path.stroke()
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 46, weight: .regular)
            .applying(.init(hierarchicalColor: .controlAccentColor))
        let symbol = NSImage(systemSymbolName: isProcessing ? "hourglass" : "arrow.down.app", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        let symbolRect = NSRect(x: bounds.midX - 25, y: bounds.midY + 20, width: 50, height: 50)
        symbol?.draw(in: symbolRect)
        drawCentered(isProcessing ? L("処理しています…") : L("画像ファイルをここにドロップ"), y: bounds.midY - 25, font: .boldSystemFont(ofSize: 15), color: .labelColor)
        drawCentered(L("複数画像・アプリアイコンへのドロップにも対応"), y: bounds.midY - 52, font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
    }
    private func drawCentered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]; let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attrs)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { targeted = true; needsDisplay = true; return .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { targeted = false; needsDisplay = true }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        targeted = false; needsDisplay = true
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return false }
        onDrop?(items); return true
    }
}

/// 「アプリを呼び出すホットキー」. Stored as before (shortcutEnabled / shortcutKey / shortcutModifiers, Carbon values);
/// registered through the shared HotkeySet, which steps aside while the settings field records a key.
@MainActor final class KageShortcut {
    static let defaultCombo = KeyCombo(code: 32, modifiers: UInt32(controlKey | optionKey | cmdKey))
    private(set) var enabled = UserDefaults.standard.object(forKey: "shortcutEnabled") as? Bool ?? true
    private(set) var combo = KageShortcut.storedCombo(key: UserDefaults.standard.object(forKey: "shortcutKey") as? Int,
                                                modifiers: UserDefaults.standard.object(forKey: "shortcutModifiers") as? Int)
    private(set) var registrationSucceeded = true
    var action: (() -> Void)?
    private let hotkeys = HotkeySet(signature: "KAGE")
    private var activation: NSObjectProtocol?
    init() {
        hotkeys.action = { [weak self] _ in self?.action?() }
        // Another of our apps may claim this key for the app in front (AiHelper's 単位パレット, ⌃⌥⌘U in Illustrator):
        // step aside there, so the key reaches it (HotkeyManifest.claimedByOtherApp).
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.register() }
        }
    }
    /// Saved Carbon key code and modifiers → KeyCombo; missing values fall back to the initial key.
    nonisolated static func storedCombo(key: Int?, modifiers: Int?) -> KeyCombo {
        KeyCombo(code: UInt32(key ?? Int(defaultCombo.code)), modifiers: UInt32(modifiers ?? Int(defaultCombo.modifiers)))
    }
    func restore() {
        register()
        publish()
    }
    /// Saves even when registration fails, so the field shows the key with the shared failure message.
    func save(enabled: Bool, combo: KeyCombo) {
        self.enabled = enabled; self.combo = combo
        UserDefaults.standard.set(enabled, forKey: "shortcutEnabled")
        UserDefaults.standard.set(Int(combo.code), forKey: "shortcutKey")
        UserDefaults.standard.set(Int(combo.modifiers), forKey: "shortcutModifiers")
        register()
        publish()
    }
    private func register() {
        let yielded = HotkeyManifest.claimedByOtherApp(keyCode: Int(combo.code), modifiers: Int(combo.modifiers), front: NSWorkspace.shared.frontmostApplication)
        if enabled && !yielded { registrationSucceeded = hotkeys.register(1, combo) == noErr }
        else { hotkeys.unregister(1); if !enabled { registrationSucceeded = true } }
    }
    /// Declares the hotkey to HotkeyHound (Shared/HotkeyManifest). `enabled` is the setting, not whether registration succeeded.
    private func publish() {
        HotkeyManifest.publish([HotkeyManifest.Item(id: "shortcut", title: L("メインウインドウを開く"), keyCode: Int(combo.code), modifiers: Int(combo.modifiers), enabled: enabled)])
    }
}

#if !APP_STORE
/// Reads the selection of the frontmost Finder or Path Finder with Apple Events (asks for Automation once).
enum FileBrowserSelection {
    enum Result { case notFileBrowser, files([URL]), denied, failed }
    private static let finder = "com.apple.finder"
    private static let pathFinders: Set<String> = ["com.cocoatech.PathFinder", "com.cocoatech.PathFinder-setapp"]

    static func selectedFiles() -> Result {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              bundleID == finder || pathFinders.contains(bundleID) else { return .notFileBrowser }
        // Finder items convert through alias; Path Finder's fsItem has its own POSIX path. Empty selection gives "".
        let item = bundleID == finder ? "POSIX path of (anItem as alias)" : "POSIX path of anItem"
        let source = """
        tell application id "\(bundleID)"
            set out to ""
            try
                repeat with anItem in (get selection)
                    set out to out & (\(item)) & linefeed
                end repeat
            end try
            return out
        end tell
        """
        var error: NSDictionary?
        guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
            // -1743: not allowed in Automation.
            return (error?[NSAppleScript.errorNumber] as? Int) == -1743 ? .denied : .failed
        }
        let paths = (output.stringValue ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return .files(paths.map { URL(fileURLWithPath: $0) })
    }
}
#endif

enum ShadowSizes {
    static let choices = [(L("影なし"), 0), ("XS", 10), ("S", 27), ("L", 112)]
    static let defaultKey = "defaultShadowSize"
    static let settingsChanged = Notification.Name("KageTrimmerOutputSettingsChanged")
    static var defaultSize: Int {
        let saved = UserDefaults.standard.object(forKey: defaultKey) as? Int ?? 27
        return choices.contains { $0.1 == saved } ? saved : 27
    }
}

/// 「出力」 tab: what happens after images are processed. All off by default.
enum SuccessActions {
    static let soundKey = "playSoundOnSuccess"
    static let revealKey = "revealOutputsOnSuccess"
    static let trashKey = "trashOriginalsOnSuccess"
    static var playsSound: Bool { UserDefaults.standard.bool(forKey: soundKey) }
    static var revealsOutputs: Bool { UserDefaults.standard.bool(forKey: revealKey) }
    static var trashesOriginals: Bool { UserDefaults.standard.bool(forKey: trashKey) }
}

/// 「出力」 tab: the shadow size the main window starts with, the file name suffix for each size, and what happens after success.
@MainActor final class OutputSettingsController: NSObject, NSTextFieldDelegate {
    private let sizePopUp = NSPopUpButton()
    private var suffixFields: [NSTextField] = []
    private var successChecks: [NSButton] = []

    func makeView() -> NSView {
        sizePopUp.addItems(withTitles: ShadowSizes.choices.map { $0.1 == 0 ? $0.0 : "\($0.0)（\($0.1)）" })
        sizePopUp.selectItem(at: ShadowSizes.choices.firstIndex { $0.1 == ShadowSizes.defaultSize } ?? 2)
        sizePopUp.target = self; sizePopUp.action = #selector(defaultSizeChanged)
        sizePopUp.setAccessibilityLabel(L("起動時の影の大きさ"))
        let sizeLabel = NSTextField(labelWithString: L("起動時の影の大きさ"))
        let sizeRow = NSStackView(views: [sizeLabel, sizePopUp]); sizeRow.spacing = 8; sizeRow.alignment = .firstBaseline
        let sizeHelp = NSTextField(wrappingLabelWithString: L("メインウインドウはこの大きさで始まります。メインウインドウで選び直した大きさは、終了するまで使われます。"))
        sizeHelp.font = .systemFont(ofSize: 11); sizeHelp.textColor = .secondaryLabelColor
        let sizeGroup = SettingsUI.group(L("影の大きさ"), [sizeRow, sizeHelp])

        let grid = NSGridView(numberOfColumns: 2, rows: 0)
        grid.rowSpacing = 8; grid.columnSpacing = 8
        for (name, size) in ShadowSizes.choices {
            let label = NSTextField(labelWithString: name)
            let field = NSTextField(string: UserDefaults.standard.string(forKey: ShadowProcessor.suffixKey(shadowSize: size)) ?? "")
            field.placeholderString = ShadowProcessor.defaultOutputSuffix(shadowSize: size)
            field.tag = size; field.delegate = self
            field.setAccessibilityLabel(L("%@の接尾辞", String(describing: name)))
            field.widthAnchor.constraint(equalToConstant: 180).isActive = true
            grid.addRow(with: [label, field])
            suffixFields.append(field)
        }
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        let suffixHelp = NSTextField(wrappingLabelWithString: L("影の大きさごとに、元の名前の後ろに付ける文字を指定します。空欄にするとデフォルトの接尾辞を使います。「/」と「:」は使えません。"))
        suffixHelp.font = .systemFont(ofSize: 11); suffixHelp.textColor = .secondaryLabelColor
        let reset = NSButton(title: L("初期値に戻す"), target: self, action: #selector(resetSuffixes))
        // The group stretches each row to its width; the spacer keeps the button at its natural size.
        let resetSpacer = NSView(); resetSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let resetRow = NSStackView(views: [reset, resetSpacer])
        let suffixGroup = SettingsUI.group(L("ファイル名の接尾辞"), [grid, suffixHelp, resetRow])

        successChecks = [
            (L("サウンドを鳴らす"), SuccessActions.soundKey),
            (L("書き出した画像をFinderで選択する"), SuccessActions.revealKey),
            (L("元の画像をゴミ箱に入れる"), SuccessActions.trashKey)
        ].map { title, key -> NSButton in
            let check = NSButton(checkboxWithTitle: title, target: self, action: #selector(successActionChanged(_:)))
            check.identifier = NSUserInterfaceItemIdentifier(key)
            check.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
            return check
        }
        let successHelp = NSTextField(wrappingLabelWithString: L("サウンドはすべての画像を処理できたときに鳴ります。ゴミ箱に入れるのは、書き出しに成功した画像の元ファイルだけです。"))
        successHelp.font = .systemFont(ofSize: 11); successHelp.textColor = .secondaryLabelColor
        let successGroup = SettingsUI.group(L("処理に成功したとき"), successChecks + [successHelp])

        let stack = NSStackView(views: [sizeGroup, suffixGroup, successGroup]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        for group in [sizeGroup, suffixGroup, successGroup] { group.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        return stack
    }
    /// Shows values imported or synced from another Mac.
    func reload() {
        sizePopUp.selectItem(at: ShadowSizes.choices.firstIndex { $0.1 == ShadowSizes.defaultSize } ?? 2)
        for field in suffixFields { field.stringValue = UserDefaults.standard.string(forKey: ShadowProcessor.suffixKey(shadowSize: field.tag)) ?? "" }
        for check in successChecks {
            if let key = check.identifier?.rawValue { check.state = UserDefaults.standard.bool(forKey: key) ? .on : .off }
        }
    }
    @objc private func defaultSizeChanged() {
        let size = ShadowSizes.choices[sizePopUp.indexOfSelectedItem].1
        UserDefaults.standard.set(size, forKey: ShadowSizes.defaultKey)
        NotificationCenter.default.post(name: ShadowSizes.settingsChanged, object: nil, userInfo: [ShadowSizes.defaultKey: size])
    }
    @objc private func successActionChanged(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        UserDefaults.standard.set(sender.state == .on, forKey: key)
    }
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        save(field)
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        // Show what is actually used once editing ends: unusable characters removed.
        field.stringValue = ShadowProcessor.sanitizedSuffix(field.stringValue)
        save(field)
    }
    private func save(_ field: NSTextField) {
        let suffix = ShadowProcessor.sanitizedSuffix(field.stringValue)
        let key = ShadowProcessor.suffixKey(shadowSize: field.tag)
        if suffix.isEmpty { UserDefaults.standard.removeObject(forKey: key) } else { UserDefaults.standard.set(suffix, forKey: key) }
        NotificationCenter.default.post(name: ShadowSizes.settingsChanged, object: nil)
    }
    @objc private func resetSuffixes() {
        for field in suffixFields {
            field.stringValue = ""
            UserDefaults.standard.removeObject(forKey: ShadowProcessor.suffixKey(shadowSize: field.tag))
        }
        NotificationCenter.default.post(name: ShadowSizes.settingsChanged, object: nil)
    }
}

final class ShortcutSettingsController: NSViewController {
    private let shortcut: KageShortcut
    private let enabled = NSButton(checkboxWithTitle: HotkeyText.enable, target: nil, action: nil)
    private let output = OutputSettingsController()
    private let folderWatch = FolderWatchSettingsController()
    init(shortcut: KageShortcut) { self.shortcut = shortcut; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 560))
        let title = NSTextField(labelWithString: SettingsUI.shortcutTitle)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        #if APP_STORE
        let help = NSTextField(wrappingLabelWithString: L("KageTrimmerのウインドウを表示します。ウインドウを閉じても、アプリを終了するまでは使用できます。"))
        #else
        let help = NSTextField(wrappingLabelWithString: L("FinderまたはPath Finderで画像を選択しているときは、その画像をすぐに処理します。選択していないときはKageTrimmerのウインドウを表示します。ウインドウを閉じても、アプリを終了するまでは使用できます。"))
        #endif
        help.textColor = .secondaryLabelColor
        enabled.target = self; enabled.action = #selector(enabledChanged)
        enabled.state = shortcut.enabled ? .on : .off
        let shortcut = self.shortcut
        let field = HotkeyField.control(id: "shortcut", get: { shortcut.combo }, set: { combo in
            if let combo { shortcut.save(enabled: shortcut.enabled, combo: combo) }
        }, defaultCombo: KageShortcut.defaultCombo, registered: { shortcut.registrationSucceeded }, isEnabled: { shortcut.enabled })
        let launchGroup = SettingsUI.group(SettingsUI.launchTitle, [LoginAtLaunchControl(), MenuBarPresence.shared.settingsControl(), title, enabled, field, help])
        SettingsUI.tabs([(SettingsUI.launchTitle, launchGroup), (L("出力"), output.makeView()), (L("フォルダ監視"), folderWatch.makeView()), (SettingsSync.shared.tabTitle, SettingsSync.shared.sharingPage()), (AboutSection.title, AboutSection.view())], in: view)
    }
    func reloadSharedSettings() { if isViewLoaded { output.reload() } }
    @objc private func enabledChanged() {
        shortcut.save(enabled: enabled.state == .on, combo: shortcut.combo)
        HotkeyRecorder.shared.touch()
    }
}

private final class AdaptiveBackgroundView: NSView {
    let color: NSColor
    let isMainBackground: Bool
    init(frame: NSRect, color: NSColor, isMainBackground: Bool = false) {
        self.color = color; self.isMainBackground = isMainBackground
        super.init(frame: frame)
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let fill = isMainBackground && dark ? NSColor(srgbRed: 0.16, green: 0.16, blue: 0.16, alpha: 1) : color
        fill.setFill(); bounds.intersection(dirtyRect).fill()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

/// Standard Window menu (placed before Help); registered as NSApp.windowsMenu so open windows are listed.
private func addStandardWindowMenu(to mainMenu: NSMenu) {
    let root = NSMenuItem(title: L("ウインドウ"), action: nil, keyEquivalent: "")
    let menu = NSMenu(title: L("ウインドウ"))
    menu.addItem(withTitle: L("しまう"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")
    menu.addItem(withTitle: L("拡大／縮小"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: L("すべてを手前に移動"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
    root.submenu = menu
    mainMenu.addItem(root)
    NSApp.windowsMenu = menu
}

private func addStandardApplicationCommands(to menu: NSMenu, name: String) {
    let services = NSMenu(title: L("サービス"))
    let item = menu.addItem(withTitle: L("サービス"), action: nil, keyEquivalent: "")
    item.submenu = services
    NSApp.servicesMenu = services
    menu.addItem(.separator())
    menu.addItem(withTitle: L("%@を隠す", String(describing: name)), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    let others = menu.addItem(withTitle: L("ほかを隠す"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
    others.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(withTitle: L("すべてを表示"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: L("%@を終了", String(describing: name)), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
}

// Bundle identity, rather than the bundle path or build number, defines one app.
@MainActor
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) {
            candidates.append(current)
        }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast
            let right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first,
              existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
                exit(0)
            }
            // Allow the reopen Apple event to reach hidden/menu-bar applications.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}


// Main-window header uses the same icon resource as the distributed app.
private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
/// Shown under the header icon: version, then build in parentheses (「1.4.5」「（15）」).
private func appVersionText() -> String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info["CFBundleVersion"] as? String, !build.isEmpty, build != version else { return version }
    let japanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    return version + "\n" + (japanese ? "（\(build)）" : "(\(build))")
}
private func appVersionLabel() -> NSTextField {
    let label = NSTextField(labelWithString: appVersionText())
    label.font = .systemFont(ofSize: 10)
    label.textColor = .secondaryLabelColor
    label.alignment = .center
    label.maximumNumberOfLines = 2
    return label
}
private func appHeader(_ title: String, subtitle: String = "", size: CGFloat = 44, showsVersion: Bool = true) -> NSStackView {
    let icon = NSImageView(image: currentAppIcon())
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.setAccessibilityElement(false)
    icon.widthAnchor.constraint(equalToConstant: size).isActive = true
    icon.heightAnchor.constraint(equalToConstant: size).isActive = true
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: size == 44 ? 20 : 15, weight: .semibold)
    let detail = NSTextField(wrappingLabelWithString: subtitle)
    detail.font = .systemFont(ofSize: size == 44 ? 12 : 11)
    detail.textColor = .secondaryLabelColor
    let text = NSStackView(views: subtitle.isEmpty ? [label] : [label, detail])
    text.orientation = .vertical; text.alignment = .leading; text.spacing = 4
    let iconColumn = NSStackView(views: showsVersion ? [icon, appVersionLabel()] : [icon])
    iconColumn.orientation = .vertical; iconColumn.alignment = .centerX; iconColumn.spacing = 4
    let row = NSStackView(views: [iconColumn, text])
    row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 12
    return row
}
