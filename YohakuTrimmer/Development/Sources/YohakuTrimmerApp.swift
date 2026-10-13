import AppKit
import UniformTypeIdentifiers
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shortcut = YohakuShortcut()
    private var settingsWindow: NSWindow?
    private var window: NSWindow!
    private var mainViewController: MainViewController?
    private var pendingOpenURLs: [URL] = []
    private var quitAfterPendingOpen = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "YohakuTrimmer", symbol: "crop", existing: nil,
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 430), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = ""
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior.insert(.fullScreenNone)
        window.isReleasedWhenClosed = false
        let controller = MainViewController()
        mainViewController = controller
        window.contentViewController = controller
        window.center()
        // A login launch stays quiet; files handed over at launch still show the window.
        if (!StartupWindow.hidden && !loginLaunch) || !pendingOpenURLs.isEmpty { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
        if !pendingOpenURLs.isEmpty {
            let urls = pendingOpenURLs
            let shouldQuit = quitAfterPendingOpen
            pendingOpenURLs.removeAll()
            quitAfterPendingOpen = false
            DispatchQueue.main.async {
                controller.process(urls) {
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

    @objc private func showSettings() {
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

    private func performShortcut() {
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
        let appMenuItem = NSMenuItem(title: "YohakuTrimmer", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "YohakuTrimmer")
        appMenu.addItem(withTitle: L("YohakuTrimmerについて"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: L("設定…"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: appMenu) }
        #endif
        addStandardApplicationCommands(to: appMenu, name: "YohakuTrimmer")
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
enum YohakuTrimmerMain {
    @MainActor static func main() {
        SingleInstanceLaunch.enforce()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
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
    private let choices = [(L("なし"), 0), (L("小"), 8), (L("大"), 32)]
    private var radioButtons: [NSButton] = []
    private let status = NSTextField(labelWithString: "")
    private var tolerance = UserDefaults.standard.object(forKey: "tolerance") as? Int ?? MarginProcessor.defaultTolerance
    private var outputFolderGrants: [String: URL] = [:]

    deinit {
        for folder in outputFolderGrants.values { folder.stopAccessingSecurityScopedResource() }
    }

    private func authorizeOutputFolders(for urls: [URL]) -> Bool {
        let folders = Set(urls.map { $0.deletingLastPathComponent().standardizedFileURL })
        for folder in folders.sorted(by: { $0.path < $1.path }) {
            if outputFolderGrants[folder.path] != nil || FileManager.default.isWritableFile(atPath: folder.path) { continue }
            let panel = NSOpenPanel()
            panel.title = L("元画像のフォルダへの保存を許可")
            panel.message = L("処理した画像を同じフォルダに「%@.png」で保存するため、元画像があるフォルダを選択してください。", MarginProcessor.outputSuffix)
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
        if !choices.map(\.1).contains(tolerance) { tolerance = MarginProcessor.defaultTolerance }
        view = AdaptiveBackgroundView(frame: NSRect(x: 0, y: 0, width: 540, height: 430), color: NSColor(srgbRed: 236.0 / 255, green: 236.0 / 255, blue: 236.0 / 255, alpha: 1), isMainBackground: true)
        let icon = NSImageView(image: currentAppIcon()); icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        let title = NSTextField(labelWithString: L("画像の余白を削除")); title.font = .boldSystemFont(ofSize: 18)
        let subtitle = NSTextField(labelWithString: L("四辺の同じ色のピクセルを切り取ります")); subtitle.font = .systemFont(ofSize: 11); subtitle.textColor = .secondaryLabelColor
        let titleStack = NSStackView(views: [title, subtitle]); titleStack.orientation = .vertical; titleStack.alignment = .leading; titleStack.spacing = 2
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [icon, titleStack, spacer]); header.orientation = .horizontal; header.alignment = .centerY; header.spacing = 10
        let toleranceLabel = NSTextField(labelWithString: L("色の許容範囲")); toleranceLabel.font = .systemFont(ofSize: 12, weight: .medium)
        radioButtons = choices.map { name, value in
            let button = NSButton(radioButtonWithTitle: value == 0 ? L("なし（完全に同じ色）") : "\(name)（\(value)）", target: self, action: #selector(toleranceChanged(_:)))
            button.controlSize = .small; button.tag = value; button.state = value == tolerance ? .on : .off
            button.setAccessibilityLabel(L("色の許容範囲") + "：" + button.title)
            return button
        }
        let optionsStack = NSStackView(views: [toleranceLabel] + radioButtons); optionsStack.orientation = .horizontal; optionsStack.alignment = .centerY; optionsStack.spacing = 10
        dropView.onDrop = { [weak self] urls in self?.process(urls) }
        status.textColor = .secondaryLabelColor; status.font = .systemFont(ofSize: 11); status.maximumNumberOfLines = 3; status.lineBreakMode = .byWordWrapping; status.alignment = .center
        status.stringValue = Self.outputDescription
        let headerPanel = AppSurfaceView(frame: .zero)
        headerPanel.translatesAutoresizingMaskIntoConstraints = false; header.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.translatesAutoresizingMaskIntoConstraints = false; dropView.translatesAutoresizingMaskIntoConstraints = false; status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerPanel); headerPanel.addSubview(header); view.addSubview(optionsStack); view.addSubview(dropView); view.addSubview(status)
        NSLayoutConstraint.activate([
            headerPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor), headerPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor), headerPanel.topAnchor.constraint(equalTo: view.topAnchor), headerPanel.heightAnchor.constraint(equalToConstant: 82),
            header.leadingAnchor.constraint(equalTo: headerPanel.leadingAnchor, constant: 22), header.trailingAnchor.constraint(equalTo: headerPanel.trailingAnchor, constant: -22), header.centerYAnchor.constraint(equalTo: headerPanel.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 44), icon.heightAnchor.constraint(equalToConstant: 44),
            optionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), optionsStack.topAnchor.constraint(equalTo: headerPanel.bottomAnchor, constant: 12),
            dropView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22), dropView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22), dropView.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 12), dropView.heightAnchor.constraint(equalToConstant: 245),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22), status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22), status.topAnchor.constraint(equalTo: dropView.bottomAnchor, constant: 15)
        ])
    }
    private static var outputDescription: String {
        L("処理後の画像は元ファイルと同じ場所に「%@.png」で保存されます", MarginProcessor.outputSuffix)
    }
    @objc private func toleranceChanged(_ sender: NSButton) {
        tolerance = sender.tag
        for button in radioButtons { button.state = button === sender ? .on : .off }
        UserDefaults.standard.set(tolerance, forKey: "tolerance")
    }
    func process(_ urls: [URL], completion: (() -> Void)? = nil) {
        let supported = urls.filter { $0.isFileURL && UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }
        guard !supported.isEmpty else {
            status.stringValue = L("画像ファイルをドロップしてください。")
            completion?()
            return
        }
        guard authorizeOutputFolders(for: supported) else {
            completion?()
            return
        }
        status.stringValue = L("処理しています…"); dropView.isProcessing = true
        let tolerance = tolerance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var results: [String] = []
            for url in supported {
                do {
                    let result = try MarginProcessor.process(url: url, tolerance: tolerance)
                    let size = "\(result.originalSize.0)×\(result.originalSize.1) → \(result.trimmedSize.0)×\(result.trimmedSize.1)"
                    results.append("✓ \(result.output.lastPathComponent)（\(size)）")
                } catch MarginError.noMargin { results.append(L("− %@：余白がないためスキップ", url.lastPathComponent))
                } catch MarginError.onlyMargin { results.append(L("− %@：全体が同じ色のためスキップ", url.lastPathComponent))
                } catch { results.append("⚠︎ \(url.lastPathComponent)：\(error.localizedDescription)") }
            }
            DispatchQueue.main.async {
                self?.status.stringValue = results.joined(separator: "\n")
                self?.dropView.isProcessing = false
                completion?()
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

final class YohakuShortcut {
    static let modifiers: [(String, UInt32)] = [
        ("⌃⌥⌘", UInt32(controlKey | optionKey | cmdKey)),
        ("⌃⌥", UInt32(controlKey | optionKey)),
        ("⌥⌘", UInt32(optionKey | cmdKey)),
        ("⌃⌘", UInt32(controlKey | cmdKey))
    ]
    static let keys: [(String, UInt32)] = [
        ("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),
        ("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),
        ("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),
        ("V",9),("W",13),("X",7),("Y",16),("Z",6),("Space",49)
    ]
    var enabled = UserDefaults.standard.object(forKey: "shortcutEnabled") as? Bool ?? false
    var key = UInt32(UserDefaults.standard.object(forKey: "shortcutKey") as? Int ?? 16)
    var flags = UInt32(UserDefaults.standard.object(forKey: "shortcutModifiers") as? Int ?? Int(controlKey | optionKey | cmdKey))
    var registrationSucceeded = true
    func restore() {
        registrationSucceeded = configure(enabled: enabled, key: key, modifiers: flags)
        publish()
    }
    func save(enabled: Bool, key: UInt32, flags: UInt32) -> Bool {
        guard configure(enabled: enabled, key: key, modifiers: flags) else { return false }
        self.enabled = enabled; self.key = key; self.flags = flags
        registrationSucceeded = true
        UserDefaults.standard.set(enabled, forKey: "shortcutEnabled")
        UserDefaults.standard.set(Int(key), forKey: "shortcutKey")
        UserDefaults.standard.set(Int(flags), forKey: "shortcutModifiers")
        publish()
        return true
    }
    /// Declares the hotkey to HotkeyHound (Shared/HotkeyManifest). `enabled` is the setting, not whether registration succeeded.
    private func publish() {
        HotkeyManifest.publish([HotkeyManifest.Item(id: "shortcut", title: L("メインウインドウを開く"), keyCode: Int(key), modifiers: Int(flags), enabled: enabled)])
    }
    var action: (() -> Void)?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: (UInt32, UInt32)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == 0x59484B55 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<YohakuShortcut>.fromOpaque(context).takeUnretainedValue()
            owner.action?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    // Register the replacement first so a conflict leaves the previous shortcut working.
    func configure(enabled: Bool, key: UInt32, modifiers: UInt32) -> Bool {
        guard handler != nil else { return false }
        if enabled, let current, current.0 == key, current.1 == modifiers { return true }
        var replacement: EventHotKeyRef?
        if enabled {
            let result = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x59484B55, id: 1), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement)
            guard result == noErr else { return false }
        }
        if let reference { UnregisterEventHotKey(reference) }
        reference = replacement
        current = enabled ? (key, modifiers) : nil
        return true
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}

final class ShortcutSettingsController: NSViewController {
    private let shortcut: YohakuShortcut
    private let enabled = NSButton(checkboxWithTitle: L("ホットキーを有効にする"), target: nil, action: nil)
    private let modifiers = NSPopUpButton()
    private let key = NSPopUpButton()
    private let message = NSTextField(wrappingLabelWithString: "")
    init(shortcut: YohakuShortcut) { self.shortcut = shortcut; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 560))
        let title = NSTextField(labelWithString: SettingsUI.shortcutTitle)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let help = NSTextField(wrappingLabelWithString: L("YohakuTrimmerのウインドウを表示します。ウインドウを閉じても、アプリを終了するまでは使用できます。"))
        help.textColor = .secondaryLabelColor
        modifiers.addItems(withTitles: YohakuShortcut.modifiers.map { $0.0 })
        key.addItems(withTitles: YohakuShortcut.keys.map { $0.0 })
        for control in [modifiers, key] { control.target = self; control.action = #selector(changed) }
        modifiers.setAccessibilityLabel(SettingsUI.shortcutTitle + "：" + StartupWindow.text("修飾キー", "Modifier keys", "修饰键", "보조 키"))
        key.setAccessibilityLabel(SettingsUI.shortcutTitle + "：" + StartupWindow.text("キー", "Key", "按键", "키"))
        enabled.target = self; enabled.action = #selector(changed)
        let reset = NSButton(title: L("デフォルトに戻す"), target: self, action: #selector(resetShortcut))
        let row = NSStackView(views: [modifiers, key, reset]); row.spacing = 10
        message.font = .systemFont(ofSize: 11); message.textColor = .secondaryLabelColor
        let launchGroup = SettingsUI.group(SettingsUI.launchTitle, [LoginAtLaunchControl(), MenuBarPresence.shared.settingsControl(), title, enabled, row, message, help])
        SettingsUI.tabs([(SettingsUI.launchTitle, launchGroup), (AboutSection.title, AboutSection.view())], in: view)
        refresh()
        message.stringValue = shortcut.registrationSucceeded ? L("デフォルト：オフ（有効にするときの初期キーは⌃⌥⌘Y）") : L("登録できませんでした。別のキーの組み合わせを選択してください。")
    }
    private func refresh() {
        enabled.state = shortcut.enabled ? .on : .off
        modifiers.selectItem(at: YohakuShortcut.modifiers.firstIndex { $0.1 == shortcut.flags } ?? 0)
        key.selectItem(at: YohakuShortcut.keys.firstIndex { $0.1 == shortcut.key } ?? 24)
        modifiers.isEnabled = shortcut.enabled; key.isEnabled = shortcut.enabled
    }
    @objc private func changed() {
        apply(enabled: enabled.state == .on, key: YohakuShortcut.keys[key.indexOfSelectedItem].1, flags: YohakuShortcut.modifiers[modifiers.indexOfSelectedItem].1)
    }
    @objc private func resetShortcut() {
        apply(enabled: false, key: 16, flags: UInt32(controlKey | optionKey | cmdKey))
    }
    private func apply(enabled: Bool, key: UInt32, flags: UInt32) {
        if shortcut.save(enabled: enabled, key: key, flags: flags) {
            message.stringValue = enabled ? L("保存しました。変更はすぐに反映されます。") : L("ホットキーを無効にしました。")
        } else {
            message.stringValue = L("この組み合わせは登録できません。以前の設定を保持しています。")
        }
        refresh()
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
private func appHeader(_ title: String, subtitle: String = "", size: CGFloat = 44) -> NSStackView {
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
    let row = NSStackView(views: [icon, text])
    row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 12
    return row
}
