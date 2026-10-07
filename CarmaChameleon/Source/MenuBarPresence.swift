import AppKit
import Carbon
import SwiftUI

/// Shared menu-bar opt-in. Installation does not alter login launch or hotkeys.
@MainActor
final class MenuBarPresence: NSObject {
    static let shared = MenuBarPresence()
    static let enabledKey = "shared.menuBar.enabled"
    static let choiceKey = "shared.menuBar.choiceMade"
    private var item: NSStatusItem?
    private var installed = false
    private var name = ""
    private var reveal: (() -> Void)?
    private var preferences: (() -> Void)?
    private var help: (() -> Void)?
    private var settingsWindow: NSWindow?
    private var check: NSButton?
    private var promptShown = false
    private var defaultEnabled = false

    // Same language rule as the rest of the settings window (Japanese-only apps stay Japanese).
    private func text(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String { StartupWindow.text(ja, en, zh, ko) }
    var enabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) == nil ? defaultEnabled : UserDefaults.standard.bool(forKey: Self.enabledKey)
    }
    /// `keepExistingImage`: leave an existing item's custom icon alone (PodiumFlight's clock-on-screen icon).
    func install(name: String, symbol: String, existing: NSStatusItem? = nil, keepExistingImage: Bool = false,
                 show: @escaping () -> Void, settings: (() -> Void)?, help: @escaping () -> Void) {
        guard !installed else { return }
        installed = true
        self.name = name; reveal = show; preferences = settings; self.help = help
        defaultEnabled = existing != nil
        item = existing ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if existing == nil { item?.menu = makeMenu() }
        if !(keepExistingImage && existing?.button?.image != nil) {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: name)
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            item?.button?.image = image
        }
        item?.button?.toolTip = name
        // PodiumFlight's live timer title remains unchanged.
        if name == "CommandDee" { item?.button?.title = ""; item?.length = NSStatusItem.squareLength }
        item?.button?.setAccessibilityLabel(name)
        apply()
        installMenuEntry()
        NotificationCenter.default.addObserver(self, selector: #selector(activated), name: NSApplication.didBecomeActiveNotification, object: NSApp)
        let event = NSAppleEventManager.shared().currentAppleEvent
        let login = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !login {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.offerIfNeeded() }
        }
    }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: text("メインウインドウを開く", "Open Main Window", "打开主窗口", "메인 윈도우 열기"), action: #selector(show), keyEquivalent: "").target = self
        // Apps without a settings window pass settings: nil and get no 設定… item.
        if preferences != nil {
            menu.addItem(withTitle: text("設定…", "Settings…", "设置…", "설정…"), action: #selector(showPreferences), keyEquivalent: "").target = self
        }
        // Help submenu: app help and the note article (BASELINE「メニューの共通構成」).
        let help = NSMenu()
        help.addItem(withTitle: String(format: text("%@ヘルプ", "%@ Help", "%@ 帮助", "%@ 도움말"), name), action: #selector(showHelp), keyEquivalent: "").target = self
        HelpLinks.addNoteItem(to: help)
        let helpItem = menu.addItem(withTitle: text("ヘルプ", "Help", "帮助", "도움말"), action: nil, keyEquivalent: "")
        menu.setSubmenu(help, for: helpItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: text("メニューバー設定…", "Menu Bar Settings…", "菜单栏设置…", "메뉴 막대 설정…"), action: #selector(showSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(format: text("%@を終了", "Quit %@", "退出 %@", "%@ 종료"), name), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApp
        return menu
    }
    private func installMenuEntry() {
        guard let menu = NSApp.mainMenu?.items.first?.submenu else { return }
        if menu.items.contains(where: { $0.identifier?.rawValue == "shared.menuBar.settings" }) { return }
        let entry = NSMenuItem(title: text("メニューバー設定…", "Menu Bar Settings…", "菜单栏设置…", "메뉴 막대 설정…"), action: #selector(showSettings), keyEquivalent: "")
        entry.target = self; entry.identifier = .init("shared.menuBar.settings")
        menu.insertItem(entry, at: min(2, menu.items.count))
    }
    @objc private func activated() { installMenuEntry(); offerIfNeeded() }
    private func offerIfNeeded() {
        guard !StartupWindow.hidden, !promptShown, !UserDefaults.standard.bool(forKey: Self.choiceKey),
              NSApp.windows.contains(where: { $0.isVisible && !$0.isSheet }), NSApp.modalWindow == nil else { return }
        promptShown = true
        let alert = NSAlert()
        alert.messageText = name + text("をメニューバーに追加しますか？", " — Add to the menu bar?", "：添加到菜单栏？", " — 메뉴 막대에 추가할까요?")
        alert.informativeText = text("モノクロのアイコンから呼び出せます。ログイン時の起動とは別の設定です。後からアプリメニューの「メニューバー設定…」で変更できます。", "Use a monochrome icon to access the app. This is separate from login launch. Change it later in the app menu’s Menu Bar Settings.", "通过单色图标访问应用。这与登录时启动无关，可在应用菜单的菜单栏设置中更改。", "흑백 아이콘으로 앱을 열 수 있습니다. 로그인 시 실행과 별개이며 앱 메뉴의 메뉴 막대 설정에서 변경할 수 있습니다.")
        alert.addButton(withTitle: text("メニューバーに追加", "Add to Menu Bar", "添加到菜单栏", "메뉴 막대에 추가"))
        alert.addButton(withTitle: text("追加しない", "Do Not Add", "不添加", "추가하지 않음"))
        alert.addButton(withTitle: text("あとで", "Later", "稍后", "나중에"))
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { save(true) }
        else if response == .alertSecondButtonReturn { save(false) }
    }
    func settingsControl() -> NSButton {
        let button = NSButton(checkboxWithTitle: text("メニューバーに表示", "Show in menu bar", "在菜单栏中显示", "메뉴 막대에 표시"), target: self, action: #selector(toggle(_:)))
        button.state = enabled ? .on : .off
        return button
    }
    private func save(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
        UserDefaults.standard.set(true, forKey: Self.choiceKey)
        apply()
    }
    private func apply() { item?.isVisible = enabled; check?.state = enabled ? .on : .off }
    @objc private func show() { NSApp.unhideWithoutActivation(); reveal?() }
    @objc private func showPreferences() { preferences?() }
    @objc private func showHelp() { help?() }
    @objc private func toggle(_ sender: NSButton) { save(sender.state == .on) }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 160), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = name + " — " + text("メニューバー設定", "Menu Bar Settings", "菜单栏设置", "메뉴 막대 설정")
            window.isReleasedWhenClosed = false
            let heading = NSTextField(labelWithString: text("起動・常駐", "Startup & Background", "启动与后台", "시작 및 백그라운드"))
            heading.font = .boldSystemFont(ofSize: 14)
            let button = NSButton(checkboxWithTitle: text("メニューバーに追加", "Add to Menu Bar", "添加到菜单栏", "메뉴 막대에 추가"), target: self, action: #selector(toggle(_:)))
            check = button
            let detail = NSTextField(wrappingLabelWithString: text("非表示でもアプリは終了しません。再表示はこの設定から行えます。", "Hiding the icon does not quit the app. Show it again here.", "隐藏图标不会退出应用。可在此重新显示。", "아이콘을 숨겨도 앱은 종료되지 않습니다. 여기서 다시 표시할 수 있습니다."))
            detail.textColor = .secondaryLabelColor
            let stack = NSStackView(views: [heading, button, detail]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20)])
            window.center(); settingsWindow = window
        }
        apply(); NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

struct MenuBarPresenceView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSButton { MenuBarPresence.shared.settingsControl() }
    func updateNSView(_ view: NSButton, context: Context) { view.state = MenuBarPresence.shared.enabled ? .on : .off }
}
