import AppKit
import ApplicationServices
import Carbon

final class PaletteDocumentView: NSView {
    override var isFlipped: Bool { true }
}

class Palette: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let autoShow = AppAutoShow()
    var targetSession = PaletteTargetSession(ownPID: ProcessInfo.processInfo.processIdentifier)
    let settingsViews = PaletteSettingsViews()
    var paletteGroups: [(name: String, box: NSBox, grid: ResponsiveButtonGrid)] = []
    var panel: Palette!
    var displayItems: [NSMenuItem] = []
    var displayRow: NSStackView!
    var utilityRow: NSStackView!
    var headerText: NSView!
    var headerIconSize: [NSLayoutConstraint] = []
    var toolbarInsets: [NSLayoutConstraint] = []
    var compactConstraints: [NSLayoutConstraint] = []
    var regularConstraints: [NSLayoutConstraint] = []
    var compactLayout: Bool?
    var columnInsets: [NSLayoutConstraint] = []
    var statusWidths: [NSLayoutConstraint] = []
    let displayPicker = NSPopUpButton()
    let profilePicker = NSPopUpButton()
    var paletteButtons: [PaletteButton] = []
    var buttonGrids: [ResponsiveButtonGrid] = []
    var typographyPanel: TypographyPanel?
    var typographyOptions = TypographyOption.allCases
    var wrapPanel: WrapPanel?
    var affixPanel: LineToolsPanel?
    var countPanel: LineToolsPanel?
    var linePrefix = ""
    var lineSuffix = ""
    var wrapCount = 40
    var specialPanel: SpecialListPanel?
    var statusItem: NSStatusItem!
    let message = NSTextField(wrappingLabelWithString: L("app.ready"))
    let target = NSTextField(labelWithString: "")
    var timer: Timer?
    var busy = false
    var shortcuts: GlobalShortcuts?
    var paletteShortcut: PaletteShortcut?
    var wasTrusted: Bool?
    lazy var permissionButton = NSButton(title: L("menu.openAccessibility"), target: self, action: #selector(openPermission))
    var copyOnly = UserDefaults.standard.bool(forKey: "copyOnly")

    func applicationDidFinishLaunching(_ notification: Notification) {
        defer { DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MenuBarPresence.shared.install(name: "MightyEdit", symbol: "text.alignleft", existing: self.statusItem,
                show: { [weak self] in self?.showPalette() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in LocalHelp.shared.show() })
        } }
        DispatchQueue.main.async { LocalHelp.shared.install() }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "textformat", accessibilityDescription: "MightyEdit")
        let menu = NSMenu()
        menu.addItem(withTitle: L("menu.showPalette"), action: #selector(showPalette), keyEquivalent: "")
        menu.addItem(withTitle: L("menu.hidePalette"), action: #selector(hidePalette), keyEquivalent: "")
        menu.addItem(withTitle: L("menu.settings"), action: #selector(showPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        let copy = menu.addItem(withTitle: L("menu.copyOnly"), action: #selector(toggleCopy(_:)), keyEquivalent: "")
        copy.state = copyOnly ? .on : .off
        menu.addItem(withTitle: L("menu.openAccessibility"), action: #selector(openPermission), keyEquivalent: "")
        menu.addItem(withTitle: L("menu.revealApp"), action: #selector(revealApplication), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        let help = menu.addItem(withTitle: L("menu.help"), action: #selector(LocalHelp.show), keyEquivalent: "")
        help.target = LocalHelp.shared
        // The note link sits right below Help (addNoteItem inserts its own separator).
        MainActor.assumeIsolated { HelpLinks.addNoteItem(to: menu) }
        if let note = menu.items.firstIndex(where: { $0.identifier?.rawValue == "shared.help.note" }), note > 0, menu.items[note - 1].isSeparatorItem { menu.removeItem(at: note - 1) }
        let display = NSMenu(title: L("menu.buttonDisplay"))
        for mode in PaletteDisplayMode.allCases {
            let item = display.addItem(withTitle: mode.title, action: #selector(changeDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.tag = mode.rawValue
            item.state = mode == .saved ? .on : .off
            displayItems.append(item)
        }
        let displayRoot = NSMenuItem(title: L("menu.buttonDisplay"), action: nil, keyEquivalent: "")
        displayRoot.submenu = display
        menu.insertItem(displayRoot, at: 2)
        statusItem.menu = menu

        let defaults: [TextTransform: Int] = [.minify: 28, .sum: 29, .join: 26, .joinAll: 27, .number: 1, .circled: 3, .alphabet: 4, .bullet: 6, .markdown: 7,
                                             .addCommas: 10, .removeCommas: 11, .bracketNumber: 12, .bracketAlphabet: 13]
        let displayShortcut = (id: 10000, title: L("hotkey.toggleDisplay"), digit: HotkeyBinding(key: 2, modifiers: UInt32(cmdKey | controlKey | optionKey)).encoded)
        shortcuts = GlobalShortcuts(actions: [displayShortcut] + TextTransform.allCases.map { ($0.rawValue, $0.title, defaults[$0] ?? -1) }) { [weak self] id in
            guard let self else { return }
            if id == 10000 { self.setDisplay(PaletteDisplayMode.saved.next); return }
            // A direct transform hotkey targets the current editor, independently
            // of the app previously bound to the visible palette.
            guard let front = NSWorkspace.shared.frontmostApplication,
                  front.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            // Re-check at key release: never act on an excluded app (B21).
            guard !ExcludedApps.shared.isExcluded(front) else { self.message.stringValue = ExcludedApps.reason; return }
            self.targetSession.bind(frontPID: front.processIdentifier)
            if id == TextTransform.affixLines.rawValue { self.showAffixPanel(); return }
            if id == TextTransform.wrapLines.rawValue { self.showWrapPanel(); return }
            if id == TextTransform.specialTypography.rawValue { self.showTypography(); return }
            let sender = NSButton()
            sender.tag = id
            self.transform(sender)
        }
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "MightyEdit")
        let about = applicationMenu.addItem(withTitle: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        applicationMenu.addItem(.separator())
        let settings = applicationMenu.addItem(withTitle: L("menu.settings"), action: #selector(showPreferences), keyEquivalent: ",")
        settings.target = self
        applicationMenu.addItem(.separator())
        let quitItem = applicationMenu.addItem(withTitle: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        applicationItem.submenu = applicationMenu
        mainMenu.insertItem(applicationItem, at: 0)
        // Standard edit commands for text fields such as the line-tools panel.
        let editItem = NSMenuItem(title: L("menu.edit"), action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: L("menu.edit"))
        editMenu.addItem(withTitle: L("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L("menu.redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.insertItem(editItem, at: 1)
        let windowItem = NSMenuItem(title: L("menu.window"), action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(withTitle: L("menu.closeWindow"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.mainMenu = mainMenu
        let shortcutItem = NSMenuItem(title: L("menu.hotkeys"), action: nil, keyEquivalent: "")
        shortcutItem.submenu = shortcuts?.menu
        menu.insertItem(shortcutItem, at: 3)

        panel = Palette(contentRect: NSRect(x: 0, y: 0, width: 380, height: 642),
                        styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        panel.title = ""
        panel.contentMinSize = NSSize(width: PaletteDisplayMode.saved == .both ? 280 : (PaletteDisplayMode.saved == .iconOnly ? 72 : 180), height: 300)
        panel.minSize = NSSize(width: panel.contentMinSize.width, height: 322)
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameAutosaveName("TextPalettePosition")
        let content = NSView()
        AppSurface.install(in: content)
        panel.contentView = content
        let settingsButton = NSButton(title: L("menu.settings"), target: self, action: #selector(showPreferences))
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: L("settings.window"))
        settingsButton.toolTip = L("tip.settings")
        let helpButton = NSButton(title: L("help"), target: LocalHelp.shared, action: #selector(LocalHelp.show))
        helpButton.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: L("help"))
        helpButton.toolTip = L("tip.help")
        for button in [settingsButton, helpButton] {
            button.bezelStyle = .rounded
            button.imagePosition = .imageLeading
            button.font = .systemFont(ofSize: 11)
            button.controlSize = .small
            button.refusesFirstResponder = true
            button.setAccessibilityLabel(button.title)
        }
        utilityRow = NSStackView(views: [settingsButton, helpButton])
        utilityRow.spacing = 8
        displayRow = NSStackView(views: [displayPicker, profilePicker])
        displayRow.spacing = 6
        let header = appHeader(L("header.title"), subtitle: L("header.subtitle"), size: 32)
        headerText = header.arrangedSubviews[1]
        headerIconSize = header.arrangedSubviews[0].constraints.filter { $0.firstAttribute == .width || $0.firstAttribute == .height }
        let toolbar = NSStackView(views: [header, displayRow])
        toolbar.orientation = .vertical
        toolbar.alignment = .leading
        toolbar.spacing = 6
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toolbar)
        utilityRow.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(utilityRow)
        displayPicker.addItems(withTitles: PaletteDisplayMode.allCases.map(\.title))
        displayPicker.selectItem(at: PaletteDisplayMode.saved.rawValue)
        displayPicker.target = self
        displayPicker.action = #selector(pickDisplay(_:))
        displayPicker.setAccessibilityLabel(L("menu.buttonDisplay"))
        profilePicker.addItems(withTitles: PaletteProfile.allCases.map(\.title))
        profilePicker.selectItem(at: PaletteProfile.allCases.firstIndex(of: .saved)!)
        profilePicker.target = self
        profilePicker.action = #selector(pickProfile(_:))
        profilePicker.setAccessibilityLabel(L("ax.profilePicker"))
        for picker in [displayPicker, profilePicker] {
            picker.refusesFirstResponder = true
            picker.font = .systemFont(ofSize: 11)
            picker.controlSize = .small
        }
        toolbarInsets = [toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
                         toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12)]
        NSLayoutConstraint.activate(toolbarInsets)
        NSLayoutConstraint.activate([
            header.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
            toolbar.topAnchor.constraint(equalTo: content.topAnchor, constant: 10)
        ])
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            utilityRow.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            utilityRow.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12)
        ])
        regularConstraints = [
            utilityRow.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 6),
            scroll.topAnchor.constraint(equalTo: utilityRow.bottomAnchor, constant: 4),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ]
        compactConstraints = [
            utilityRow.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 4),
            scroll.bottomAnchor.constraint(equalTo: utilityRow.topAnchor, constant: -8)
        ]
        NSLayoutConstraint.activate(regularConstraints)
        let document = PaletteDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(column)
        target.font = .systemFont(ofSize: 11, weight: .medium)
        target.textColor = .secondaryLabelColor
        column.addArrangedSubview(target)
        let symbols = ["arrow.turn.up.left", "list.number", "list.bullet", "text.alignleft", "text.badge.minus", "1.circle", "a.square", "plus.circle", "minus.circle", "line.3.horizontal.decrease", "arrow.up.and.down.text.horizontal", "plus.circle", "minus.circle", "number", "a.square", "arrow.down.right.and.arrow.up.left", "arrow.triangle.merge", "textformat.abc", "textformat", "arrow.left.and.right.righttriangle.left.righttriangle.right", "arrow.left.and.right", "sum", "textformat.size.larger", "textformat.size.smaller", "textformat.abc", "textformat"]
        let extraSymbols: [TextTransform: String] = [.trimLineEdges: "text.alignleft", .sortLineLength: "arrow.up.arrow.down", .countText: "number", .affixLines: "text.append", .beautify: "chevron.left.forwardslash.chevron.right", .sortLines: "arrow.up.arrow.down", .uniqueLines: "doc.on.doc", .joinWestern: "text.word.spacing", .wrapLines: "text.insert", .randomLines: "shuffle", .toggleDateFormat: "calendar", .camelCase: "textformat.abc"]
        let groups = PaletteConfiguration.groups
        for (title, operations) in groups {
            var buttons: [PaletteButton] = []
            for operation in operations {
                    let button = PaletteButton(frame: .zero)
                    button.title = operation.title
                    button.target = self
                    button.action = operation == .affixLines ? #selector(showAffixPanel) : (operation == .wrapLines ? #selector(showWrapPanel) : #selector(transform(_:)))
                    button.tag = operation.rawValue
                    button.image = NSImage(systemSymbolName: extraSymbols[operation] ?? (symbols.indices.contains(operation.rawValue) ? symbols[operation.rawValue] : "calendar"), accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 20, weight: .regular))
                    button.imagePosition = .imageAbove
                    configureDisplay(button)
                    switch operation {
                    case .trimLineEdges: button.toolTip = L("tip.trimLineEdges")
                    case .sortLineLength: button.toolTip = L("tip.sortLineLength")
                    case .countText: button.toolTip = L("tip.countText")
                    case .affixLines: button.toolTip = L("tip.affixLines")
                    case .removeDatePadding, .dateToCompact, .dateToISO, .dateToJapanese, .dateToEra, .dateToGregorian, .removeDateYear, .addDateYear, .weekdayShort, .weekdayLong:
                        button.toolTip = L("tip.date")
                    case .narrowAlphanumerics: button.toolTip = L("tip.narrowAlphanumerics")
                    case .widenKana: button.toolTip = L("tip.widenKana")
                    case .removeJapaneseSpaces: button.toolTip = L("tip.removeJapaneseSpaces")
                    case .addJapaneseSpaces: button.toolTip = L("tip.addJapaneseSpaces")
                    case .fullwidthWestern: button.toolTip = L("tip.fullwidthWestern")
                    case .halfwidthWestern: button.toolTip = L("tip.halfwidthWestern")
                    case .capitalizeWords: button.toolTip = L("tip.capitalizeWords")
                    case .camelCase: button.toolTip = L("tip.camelCase")
                    case .titleCase: button.toolTip = L("tip.titleCase")
                    case .sum: button.toolTip = L("tip.sum")
                    case .wrapLines: button.toolTip = L("tip.wrapLines")
                    case .toggleDateFormat: button.toolTip = L("tip.toggleDateFormat")
                    case .randomLines: button.toolTip = L("tip.randomLines")
                    case .sortLines: button.toolTip = L("tip.sortLines")
                    case .uniqueLines: button.toolTip = L("tip.uniqueLines")
                    case .joinWestern: button.toolTip = L("tip.joinWestern")
                    case .join: button.toolTip = L("tip.join")
                    case .joinAll: button.toolTip = L("tip.joinAll")
                    case .beautify: button.toolTip = L("tip.beautify")
                    case .minify: button.toolTip = L("tip.minify")
                    case .removeBlankLines: button.toolTip = L("tip.removeBlankLines")
                    case .spaceLines: button.toolTip = L("tip.spaceLines")
                    case .addPeriod: button.toolTip = L("tip.addPeriod")
                    case .removePeriod: button.toolTip = L("tip.removePeriod")
                    case .addCommas: button.toolTip = L("tip.addCommas")
                    case .removeCommas: button.toolTip = L("tip.removeCommas")
                    case .removeList: button.toolTip = L("tip.removeList")
                    case .number: button.toolTip = L("tip.number")
                    case .alphabet: button.toolTip = L("tip.alphabet")
                    default: button.toolTip = L("tip.default")
                    }
                    button.toolTip = L("tip.format", operation.title, button.toolTip ?? "")
                buttons.append(button)
            }
            if title == "リスト" || title == "文字の整形" {
                let button = PaletteButton(frame: .zero)
                button.title = PaletteConfiguration.specialTitle(for: title)
                button.tag = title == "リスト" ? PaletteConfiguration.listSpecialID : PaletteConfiguration.typographySpecialID
                button.target = self
                button.action = title == "リスト" ? #selector(showSpecialLists) : #selector(showTypography)
                button.image = NSImage(systemSymbolName: "list.star", accessibilityDescription: nil)
                button.imagePosition = .imageAbove
                button.toolTip = title == "リスト" ? L("tip.specialLists") : L("tip.specialTypography")
                configureDisplay(button)
                buttons.append(button)
            }
            let rows = ResponsiveButtonGrid(buttons: buttons, buttonHeight: displayHeight)
            buttonGrids.append(rows)
            let group = NSBox()
            group.title = PaletteConfiguration.displayName(for: title)
            group.titleFont = .systemFont(ofSize: 12, weight: .semibold)
            group.contentViewMargins = NSSize(width: 10, height: 10)
            let groupContent = NSView()
            group.contentView = groupContent
            rows.translatesAutoresizingMaskIntoConstraints = false
            groupContent.addSubview(rows)
            NSLayoutConstraint.activate([
                rows.leadingAnchor.constraint(equalTo: groupContent.leadingAnchor),
                rows.trailingAnchor.constraint(equalTo: groupContent.trailingAnchor),
                rows.topAnchor.constraint(equalTo: groupContent.topAnchor),
                rows.bottomAnchor.constraint(equalTo: groupContent.bottomAnchor)
            ])
            paletteGroups.append((title, group, rows))
            column.addArrangedSubview(group)
            group.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        message.font = .systemFont(ofSize: 11)
        message.textColor = .secondaryLabelColor
        column.addArrangedSubview(message)
        permissionButton.bezelStyle = .rounded
        permissionButton.refusesFirstResponder = true
        column.addArrangedSubview(permissionButton)
        columnInsets = [column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 16),
                        column.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -16)]
        statusWidths = [message.widthAnchor.constraint(equalTo: column.widthAnchor),
                        target.widthAnchor.constraint(equalTo: column.widthAnchor)]
        NSLayoutConstraint.activate(statusWidths)
        NSLayoutConstraint.activate(columnInsets)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: document.topAnchor, constant: 14),

            column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -14)
        ])
        if !panel.setFrameUsingName("TextPalettePosition") { panel.center() }
        if PaletteDisplayMode.saved == .iconOnly {
            var frame = panel.frame; frame.size.width = 72
            panel.setFrame(frame, display: false)
        }
        if let screen = panel.screen ?? NSScreen.main {
            var frame = panel.frame
            frame.size.width = min(max(frame.width, panel.contentMinSize.width), screen.visibleFrame.width)
            frame.size.height = min(max(frame.height, 300), screen.visibleFrame.height)
            frame.origin.x = max(screen.visibleFrame.minX, min(frame.origin.x, screen.visibleFrame.maxX - frame.width))
            frame.origin.y = max(screen.visibleFrame.minY, min(frame.origin.y, screen.visibleFrame.maxY - frame.height))
            panel.setFrame(frame, display: false)
        }
        settingsViews.onChange = { [weak self] in
            self?.applyVisibility()
            self?.specialPanel?.reloadOptions()
            self?.typographyPanel?.reloadOptions()
            self?.shortcuts?.reloadConfiguration()
        }
        paletteShortcut = PaletteShortcut { [weak self] pid in self?.presentPalette(targetPID: pid) }
        shortcuts?.additionalPreferenceTabs = [(SettingsUI.launchTitle, paletteShortcut!.settingsView())] + settingsViews.tabs()
            + [(L("tab.autoShow"), autoShow.makeSettingsView()), (ExcludedApps.title, ExcludedApps.shared.settingsView())]
        // Excluded apps and MightyEdit itself get their keystrokes back (B21).
        shortcuts?.hotkeysBlocked = { ExcludedApps.shared.hotkeysBlocked }
        // Palette-only hotkeys follow the palette's visibility (show, hide, close, app hide).
        shortcuts?.paletteVisible = { [weak self] in self?.panel?.isVisible == true }
        for name in [NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.shortcuts?.refreshForPaletteVisibility() }
        }
        paletteShortcut?.hotkeysBlocked = { ExcludedApps.shared.hotkeysBlocked }
        ExcludedApps.shared.onChange = { [weak self] in
            self?.shortcuts?.refreshForFrontApp(); self?.paletteShortcut?.refreshForFrontApp(); self?.updateTarget()
        }
        ExcludedApps.shared.start()
        paletteShortcut?.refreshForFrontApp()
        autoShow.showPalette = { [weak self] in
            guard !ExcludedApps.shared.isExcluded(NSWorkspace.shared.frontmostApplication) else { return }
            self?.showPalette()
        }
        autoShow.externalAppActivated = { [weak self] app in
            guard let self else { return }
            if self.targetSession.activated(app.processIdentifier) { self.hidePalette() }
        }
        targetSession.bind(frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        autoShow.externalAppDeactivated = { [weak self] app in
            self?.targetSession.departed(app.processIdentifier, frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        }
        autoShow.start()
        shortcuts?.actionEnabled = { id in
            guard let operation = TextTransform(rawValue: id), TextTransform.specialLists.contains(operation) else { return true }
            return PaletteConfiguration.listEnabled(id)
        }
        shortcuts?.reloadConfiguration()
        applyVisibility()
        updateCompactControls()
        if PaletteDisplayMode.saved == .iconOnly {
            var frame = panel.frame; frame.size.width = 72
            panel.setFrame(frame, display: true)
        }
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let loginLaunch = launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch && !StartupWindow.hidden { showPalette() }
        updateTarget()
        if PaletteDisplayMode.saved == .iconOnly {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.panel.contentView?.layoutSubtreeIfNeeded()
                self.panel.contentMinSize.width = 72
                self.panel.minSize.width = 72
                var frame = self.panel.frame; frame.size.width = 72
                self.panel.setFrame(frame, display: true)

            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateTarget() }
    }

    func updateTarget() {
        let boundApp = targetSession.targetPID.flatMap { NSRunningApplication(processIdentifier: $0) }
        let name = boundApp?.localizedName ?? L("target.app")
        let excluded = ExcludedApps.shared.isExcluded(boundApp)
        target.stringValue = excluded ? L("target.excluded", name) : L("target.normal", name, copyOnly ? L("target.copy") : L("target.replace"))
        let trusted = AXIsProcessTrusted()
        permissionButton.isHidden = trusted
        if !trusted {
            message.stringValue = L("msg.needPermission")
        } else if wasTrusted != true {
            message.stringValue = L("msg.permissionOK")
        }
        wasTrusted = trusted
        if trusted && !excluded && message.stringValue == ExcludedApps.reason { message.stringValue = L("app.ready") }
        // Excluded apps are not inspected; the palette stays dimmed for them.
        if panel.isVisible && (excluded || ExcludedApps.shared.isExcluded(NSWorkspace.shared.frontmostApplication)) { panel.alphaValue = 0.45; return }
        // Dim only on a definite read-only/non-text focus; unknown custom editors stay usable.
        if panel.isVisible && trusted { panel.alphaValue = focusedTextIsEditable() == false ? 0.45 : 1 }
        else { panel.alphaValue = 1 }
    }

    private func focusedTextIsEditable() -> Bool? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(ax, 0.08)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        var editable: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editable) == .success,
           let editable = editable as? Bool { return editable }
        for attribute in [kAXSelectedTextAttribute, kAXValueAttribute] {
            var settable = DarwinBoolean(false)
            if AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success, settable.boolValue { return true }
        }
        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
              let role = role as? String else { return nil }
        if ["AXStaticText", "AXImage", "AXButton", "AXToolbar", "AXMenuBar", "AXScrollArea", "AXOutline", "AXTable"].contains(role) { return false }
        return nil
    }

    private func configureDisplay(_ button: PaletteButton) {
        button.setAccessibilityLabel(button.title)
        paletteButtons.append(button)
    }

    private var displayHeight: CGFloat {
        switch PaletteDisplayMode.saved {
        case .both: return 74
        case .iconOnly: return 44
        case .textOnly: return 48
        }
    }

    @objc func changeDisplay(_ sender: NSMenuItem) {
        guard let mode = PaletteDisplayMode(rawValue: sender.tag) else { return }
        setDisplay(mode)
    }
    @objc func pickDisplay(_ sender: NSPopUpButton) {
        guard let mode = PaletteDisplayMode(rawValue: sender.indexOfSelectedItem) else { return }
        setDisplay(mode)
    }
    @objc func pickProfile(_ sender: NSPopUpButton) {
        let profile = PaletteProfile.allCases[sender.indexOfSelectedItem]
        UserDefaults.standard.set(profile.rawValue, forKey: "paletteProfile")
        applyVisibility()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel, UserDefaults.standard.object(forKey: "paletteResident") != nil,
           !UserDefaults.standard.bool(forKey: "paletteResident") {
            NSApp.terminate(nil)
            return false
        }
        return true
    }
    func windowDidResize(_ notification: Notification) { updateCompactControls() }
    func windowWillClose(_ notification: Notification) {
        // isVisible is still true here; re-check once the close has finished.
        guard notification.object as? NSWindow === panel else { return }
        DispatchQueue.main.async { [weak self] in self?.shortcuts?.refreshForPaletteVisibility() }
    }
    private func updateCompactControls() {
        guard let panel, let displayRow, let utilityRow else { return }
        panel.contentView?.layoutSubtreeIfNeeded()
        guard let grid = buttonGrids.first else { return }
        let singleColumn = ResponsiveButtonGrid.columnCount(for: max(0, panel.frame.width - 56), buttonWidth: grid.preferredButtonWidth) == 1
        let slim = PaletteDisplayMode.saved == .iconOnly && singleColumn
        let minimumWindow = slim && panel.frame.width < 180
        let iconSize: CGFloat = minimumWindow ? min(60, panel.frame.width - 12) : 32
        headerIconSize.forEach { $0.constant = iconSize }
        for (index, inset) in toolbarInsets.enumerated() {
            inset.constant = (index == 0 ? 1 : -1) * (minimumWindow ? 6 : 12)
        }
        statusWidths.forEach { $0.isActive = !slim }
        target.isHidden = slim
        message.isHidden = slim
        panel.contentView?.toolTip = slim ? target.stringValue + "\n" + message.stringValue : nil
        for (index, inset) in columnInsets.enumerated() { inset.constant = (index == 0 ? 1 : -1) * (slim ? 4 : 16) }
        for group in paletteGroups {
            group.box.title = slim ? "" : PaletteConfiguration.displayName(for: group.name)
            group.box.titlePosition = slim ? .noTitle : .atTop
            group.box.contentViewMargins = NSSize(width: slim ? 2 : 10, height: slim ? 4 : 10)
            group.box.toolTip = slim ? PaletteConfiguration.displayName(for: group.name) : nil
        }
        for button in utilityRow.arrangedSubviews.compactMap({ $0 as? NSButton }) {
            button.imagePosition = slim ? .imageOnly : .imageLeading
        }
        permissionButton.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: L("ax.accessibilitySettings"))
        permissionButton.imagePosition = slim ? .imageOnly : .noImage
        permissionButton.toolTip = L("tip.openAccessibility")
        headerText.isHidden = singleColumn
        if let labels = headerText as? NSStackView {
            for label in labels.arrangedSubviews { label.isHidden = singleColumn }
        }
        displayPicker.isHidden = singleColumn
        let hidePickers = singleColumn && PaletteDisplayMode.saved != .both
        profilePicker.isHidden = hidePickers
        displayRow.isHidden = hidePickers
        if compactLayout != singleColumn {
            NSLayoutConstraint.deactivate(singleColumn ? regularConstraints : compactConstraints)
            NSLayoutConstraint.activate(singleColumn ? compactConstraints : regularConstraints)
            compactLayout = singleColumn
        }
        displayRow.orientation = .horizontal
        displayRow.alignment = .centerY
        utilityRow.orientation = panel.frame.width < 220 ? .vertical : .horizontal
        utilityRow.alignment = panel.frame.width < 220 ? .leading : .centerY
    }
    private func setDisplay(_ mode: PaletteDisplayMode) {
        let wasSingleColumn = buttonGrids.first.map { ResponsiveButtonGrid.columnCount(for: $0.bounds.width, buttonWidth: $0.preferredButtonWidth) == 1 } ?? false
        panel.contentMinSize.width = mode == .both ? 280 : (mode == .iconOnly ? 72 : 180)
        panel.minSize.width = panel.contentMinSize.width
        if panel.frame.width < panel.contentMinSize.width {
            var frame = panel.frame; frame.size.width = panel.contentMinSize.width
            panel.setFrame(frame, display: true)
        }
        displayPicker.selectItem(at: mode.rawValue)
        UserDefaults.standard.set(mode.rawValue, forKey: "paletteDisplayMode")
        for item in displayItems { item.state = item.tag == mode.rawValue ? .on : .off }
        for button in paletteButtons { button.displayMode = mode }
        for grid in buttonGrids { grid.buttonHeight = displayHeight }
        updateCompactControls()
        if mode == .iconOnly && wasSingleColumn {
            var frame = panel.frame; frame.size.width = 72
            panel.setFrame(frame, display: true)
        }
        updateCompactControls()
    }

    private func applyVisibility() {
        for group in paletteGroups {
            for button in group.grid.buttons { button.isHidden = !PaletteConfiguration.shown("button.\(button.tag)") }
            group.grid.refreshVisibility()
            group.box.isHidden = !PaletteConfiguration.shown(PaletteConfiguration.categoryKey(for: group.name)) || group.grid.buttons.allSatisfy { $0.isHidden }
        }
    }

    @objc func showPreferences() { settingsViews.editProfile(.saved); shortcuts?.showPreferences() }

    @objc func showTypography() {
        targetSession.bind(frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        if typographyPanel == nil {
            typographyPanel = TypographyPanel { [weak self] options in
                guard let self else { return "" }
                self.typographyOptions = options
                let button = NSButton()
                button.tag = TextTransform.specialTypography.rawValue
                self.transform(button)
                return self.message.stringValue
            }
        }
        typographyPanel?.reloadOptions()
        typographyPanel?.orderFrontRegardless()
    }

    @objc func showAffixPanel() {
        targetSession.bind(frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        if affixPanel == nil {
            affixPanel = LineToolsPanel { [weak self] prefix, suffix in
                guard let self else { return "" }
                guard self.targetSession.targetPID == NSWorkspace.shared.frontmostApplication?.processIdentifier else {
                    self.message.stringValue = L("msg.targetChangedReselect")
                    return self.message.stringValue
                }
                self.linePrefix = prefix; self.lineSuffix = suffix
                let sender = NSButton(); sender.tag = TextTransform.affixLines.rawValue
                self.transform(sender)
                return self.message.stringValue
            }
        }
        affixPanel?.makeKeyAndOrderFront(nil)
    }

    @objc func showWrapPanel() {
        targetSession.bind(frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        if wrapPanel == nil {
            wrapPanel = WrapPanel { [weak self] count in
                guard let self else { return "" }
                self.wrapCount = count
                let button = NSButton()
                button.tag = TextTransform.wrapLines.rawValue
                self.transform(button)
                return self.message.stringValue
            }
        }
        wrapPanel?.orderFrontRegardless()
    }

    @objc func showSpecialLists() {
        targetSession.bind(frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        if specialPanel == nil {
            specialPanel = SpecialListPanel { [weak self] operation in
                let sender = NSButton()
                sender.tag = operation.rawValue
                self?.transform(sender)
                return self?.message.stringValue ?? ""
            }
        }
        specialPanel?.reloadOptions()
        specialPanel?.orderFrontRegardless()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPalette()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy {
            message.stringValue = L("msg.busyQuit")
            return .terminateCancel
        }
        return .terminateNow
    }

    @objc func showPalette() {
        presentPalette(targetPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }

    private func presentPalette(targetPID: pid_t?) {
        guard let panel else { return }
        targetSession.bind(frontPID: targetPID)
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
           let pid = targetSession.targetPID, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        updateTarget()
        // Menu-bar invocation over an excluded app shows the reason instead of acting.
        if ExcludedApps.shared.isExcluded(pid: targetSession.targetPID) { message.stringValue = ExcludedApps.reason }
        if panel.isMiniaturized { panel.deminiaturize(nil) }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            panel.center()
        }
        NSApp.unhideWithoutActivation()
        panel.orderFrontRegardless()
        shortcuts?.refreshForPaletteVisibility()
    }
    @objc func hidePalette() {
        panel.orderOut(nil)
        specialPanel?.orderOut(nil)
        typographyPanel?.orderOut(nil)
        wrapPanel?.orderOut(nil)
        affixPanel?.orderOut(nil)
        countPanel?.orderOut(nil)
        shortcuts?.refreshForPaletteVisibility()
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showAbout() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "MightyEdit", .applicationVersion: "\(version) (\(build))",
                                                     .credits: NSAttributedString(string: L("about.support"))])
    }
    @objc func toggleCopy(_ sender: NSMenuItem) {
        copyOnly.toggle()
        UserDefaults.standard.set(copyOnly, forKey: "copyOnly")
        sender.state = copyOnly ? .on : .off
        updateTarget()
    }
    @objc func openPermission() {
        // Open only on explicit request. Never reissue the OS permission prompt.
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc func revealApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func selectReplacement(in element: AXUIElement, application: AXUIElement,
                                   pid: pid_t, original: CFRange, replacement: String,
                                   expectedDocument: String?, attempts: Int = 8) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  !ExcludedApps.shared.isExcluded(pid: pid) else { return }
            var focused: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
                  let focused, CFEqual(focused, element) else { return }
            var currentValue: CFTypeRef?
            var current = CFRange()
            guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &currentValue) == .success,
                  let currentValue, CFGetTypeID(currentValue) == AXValueGetTypeID(),
                  AXValueGetValue(unsafeBitCast(currentValue, to: AXValue.self), .cfRange, &current) else { return }
            // Accessibility ranges use UTF-16 units, including for emoji.
            var inserted = CFRange(location: original.location, length: replacement.utf16.count)
            guard let insertedValue = AXValueCreate(.cfRange, &inserted) else { return }
            var actual: CFTypeRef?
            let contentMatches: Bool
            if let expectedDocument {
                contentMatches = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &actual) == .success
                    && (actual as? String) == expectedDocument
            } else {
                contentMatches = AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString,
                                                                            insertedValue, &actual) == .success
                    && (actual as? String) == replacement
            }
            let caretAtEnd = current.length == 0 && current.location == inserted.location + inserted.length
            let alreadySelected = current.location == inserted.location && current.length == inserted.length
            if contentMatches && (caretAtEnd || alreadySelected) {
                if alreadySelected { return }
                let status = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, insertedValue)
                var readback: CFTypeRef?
                var selectedRange = CFRange()
                if status == .success,
                   AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &readback) == .success,
                   let readback, CFGetTypeID(readback) == AXValueGetTypeID(),
                   AXValueGetValue(unsafeBitCast(readback, to: AXValue.self), .cfRange, &selectedRange),
                   selectedRange.location == inserted.location, selectedRange.length == inserted.length {
                    self.message.stringValue = replacement.isEmpty ? L("msg.selectedEmpty") : L("msg.selected")
                } else {
                    self.message.stringValue = L("msg.reselectUnsupported")
                }
                return
            }
            // Do not take selection back after the user moves the caret or changes selection.
            let unchanged = current.location == original.location && current.length == original.length
            if attempts > 1 && (unchanged || caretAtEnd) {
                self.selectReplacement(in: element, application: application, pid: pid, original: original,
                                       replacement: replacement, expectedDocument: expectedDocument, attempts: attempts - 1)
            }
        }
    }

    @objc func transform(_ sender: NSButton) {
        guard !busy, let operation = TextTransform(rawValue: sender.tag) else { return }
        guard AXIsProcessTrusted() else { updateTarget(); return }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            message.stringValue = L("msg.selectInApp"); return
        }
        // B21: check before reading the selection; panels and hotkeys all pass through here.
        guard !ExcludedApps.shared.isExcluded(app) else { message.stringValue = ExcludedApps.reason; return }
        if panel.isVisible || specialPanel?.isVisible == true || typographyPanel?.isVisible == true || wrapPanel?.isVisible == true || affixPanel?.isVisible == true {
            guard targetSession.targetPID == app.processIdentifier else {
                hidePalette()
                message.stringValue = L("msg.targetChangedReopen")
                return
            }
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 1)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            message.stringValue = L("msg.noAccess"); return
        }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String, !text.isEmpty else {
            message.stringValue = L("msg.selectText"); return
        }
        if operation == .countText {
            countPanel?.close()
            countPanel = LineToolsPanel(statistics: LineTools.statistics(text))
            countPanel?.orderFrontRegardless()
            return
        }
        let result: String
        do {
            if operation == .affixLines {
                result = LineTools.affix(text, prefix: linePrefix, suffix: lineSuffix)
            } else if operation == .specialTypography {
                result = TypographyOption.applyAll(text, options: typographyOptions)
            } else if operation == .wrapLines {
                result = TextTransform.wrappedText(text, count: wrapCount)
            } else {
                result = operation == .sum ? try TextTransform.summedText(text) : operation.apply(text)
            }
        } catch {
            message.stringValue = error.localizedDescription
            return
        }
        guard result != text else { message.stringValue = L("msg.noChange"); return }
        let pasteboard = NSPasteboard.general
        if copyOnly {
            pasteboard.clearContents()
            pasteboard.setString(result, forType: .string)
            message.stringValue = L("msg.copied")
            return
        }
        // Require a concrete nonempty range before sending Paste; never replace an entire field.
        var rangeValue: CFTypeRef?
        var range = CFRange()
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID(),
              AXValueGetValue(unsafeBitCast(rangeValue, to: AXValue.self), .cfRange, &range), range.length > 0 else {
            message.stringValue = L("msg.noRange"); return
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              !ExcludedApps.shared.isExcluded(NSWorkspace.shared.frontmostApplication),
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            message.stringValue = L("msg.noTarget"); return
        }
        // Confirm the document after Paste before changing the selection.
        var documentValue: CFTypeRef?
        var expectedDocument: String?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &documentValue) == .success,
           let document = documentValue as? String,
           range.location >= 0, range.length <= document.utf16.count,
           range.location <= document.utf16.count - range.length {
            expectedDocument = (document as NSString).replacingCharacters(
                in: NSRange(location: range.location, length: range.length), with: result)
        }
        // Save every available pasteboard representation; restore only if no later copy occurred.
        let previous: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var saved: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { saved[type] = data } }
            return saved
        }
        pasteboard.clearContents()
        guard pasteboard.setString(result, forType: .string) else { message.stringValue = L("msg.clipboardFailed"); return }
        let change = pasteboard.changeCount
        down.flags = .maskCommand
        up.flags = .maskCommand
        busy = true
        down.postToPid(app.processIdentifier)
        up.postToPid(app.processIdentifier)
        message.stringValue = L("msg.pasteSent", app.localizedName ?? L("target.appLong"))
        selectReplacement(in: element, application: application, pid: app.processIdentifier,
                          original: range, replacement: result, expectedDocument: expectedDocument)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if pasteboard.changeCount == change {
                pasteboard.clearContents()
                let items = previous.map { saved -> NSPasteboardItem in
                    let item = NSPasteboardItem()
                    for (type, data) in saved { item.setData(data, forType: type) }
                    return item
                }
                if !items.isEmpty { pasteboard.writeObjects(items) }
            }
            self?.busy = false
        }
    }
}

let app = NSApplication.shared
SingleInstanceLaunch.enforce()
let delegate = AppDelegate()
app.delegate = delegate
app.run()

// Reused from KakkoReplace (BrowserSwitcher). Oldest process wins on simultaneous launch.
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
    let label = NSTextField(wrappingLabelWithString: title)
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
