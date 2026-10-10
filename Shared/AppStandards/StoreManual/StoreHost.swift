import AppKit
import SwiftUI
import Carbon

func S(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String {
    StartupWindow.text(ja, en, zh, ko)
}

@MainActor final class StoreDelegate: NSObject, NSApplicationDelegate {
    static let shared = StoreDelegate()
    var processing = false
    var window: NSWindow!
    private var settings: NSWindow?
    private var help: NSWindow?
    var name: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "" }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           let prior = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            prior.activate(options: [.activateAllWindows]); NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 660), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.title = name
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: StoreRoot())
        window.minSize = NSSize(width: 720, height: 520)
        window.setFrameAutosaveName("AppStoreManualMainWindow")
        if !window.setFrameUsingName("AppStoreManualMainWindow") { window.center() }
        installMenus()
        MenuBarPresence.shared.install(name: name, symbol: "square.and.pencil", show: { self.reveal() }, settings: { self.openSettings() }, help: { self.openHelp() })
        let login = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !login && !StartupWindow.hidden { reveal() }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard processing else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = S("処理の完了をお待ちください。", "Wait for the operation to finish.", "请等待操作完成。", "작업이 끝날 때까지 기다려주세요."); alert.runModal()
        return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !resident && !processing }
    private var resident: Bool { UserDefaults.standard.object(forKey: "appStoreManual.resident") as? Bool ?? true }
    @objc private func changeResidency(_ sender: NSButton) { UserDefaults.standard.set(sender.state == .on, forKey: "appStoreManual.resident") }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { reveal(); return false }
    @objc func reveal() { window.deminiaturize(nil); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func openSettings() {
        if settings == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = S("設定", "Settings", "设置", "설정"); panel.isReleasedWhenClosed = false
            let content = NSView(frame: panel.contentView!.bounds)
            AppSurface.install(in: content)
            let residency = NSButton(checkboxWithTitle: S("常駐（閉じた後も起動を保持）", "Keep running after closing windows", "关闭窗口后保持运行", "윈도우를 닫아도 계속 실행"), target: self, action: #selector(changeResidency(_:)))
            residency.state = resident ? .on : .off
            let shortcut = NSTextField(wrappingLabelWithString: S("アプリ起動のホットキーは、ショートカットAppの「アプリを開く」で設定できます。", "Set a launch shortcut using Open App in Shortcuts.", "可在快捷指令中用打开应用设置启动快捷键。", "단축어의 앱 열기로 시작 단축키를 설정하세요."))
            SettingsUI.tabs([(S("起動・常駐", "Startup & Residency", "启动与常驻", "시작 및 상주"), SettingsUI.group(S("起動・常駐", "Startup & Residency", "启动与常驻", "시작 및 상주"), [LoginAtLaunchControl(), residency, shortcut]))], in: content)
            panel.contentView = content; panel.center(); settings = panel
        }
        settings?.makeKeyAndOrderFront(nil)
    }
    @objc func openHelp() {
        if help == nil {
            let text = Bundle.main.url(forResource: "StoreHelp", withExtension: "txt").flatMap { try? String(contentsOf: $0) } ?? ""
            help = HelpDocument.makeWindow(windowTitle: name + S("ヘルプ", " Help", " 帮助", " 도움말"), text: text)
        }
        help?.makeKeyAndOrderFront(nil)
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(nil) }
    private func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func section(_ title: String) -> NSMenu { let menu = NSMenu(title: title); let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", _ target: AnyObject? = nil) { let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = target }
        let app = section(name)
        add(app, S(name + "について", "About " + name, "关于 " + name, name + "에 관하여"), #selector(about), "", self)
        app.addItem(.separator()); add(app, S("設定…", "Settings…", "设置…", "설정…"), #selector(openSettings), ",", self)
        app.addItem(.separator()); let services = NSMenu(); let serviceItem = NSMenuItem(title: S("サービス", "Services", "服务", "서비스"), action: nil, keyEquivalent: ""); serviceItem.submenu = services; app.addItem(serviceItem); NSApp.servicesMenu = services
        app.addItem(.separator()); add(app, S(name + "を隠す", "Hide " + name, "隐藏 " + name, name + " 가리기"), #selector(NSApplication.hide(_:)), "h", NSApp)
        let others = app.addItem(withTitle: S("ほかを隠す", "Hide Others", "隐藏其他", "기타 가리기"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"); others.keyEquivalentModifierMask = [.command, .option]; others.target = NSApp
        add(app, S("すべてを表示", "Show All", "全部显示", "모두 보기"), #selector(NSApplication.unhideAllApplications(_:)), "", NSApp)
        app.addItem(.separator()); add(app, S(name + "を終了", "Quit " + name, "退出 " + name, name + " 종료"), #selector(NSApplication.terminate(_:)), "q", NSApp)
        let file = section(S("ファイル", "File", "文件", "파일")); add(file, S("メインウインドウを開く", "Open Main Window", "打开主窗口", "메인 윈도우 열기"), #selector(reveal), "0", self); file.addItem(.separator()); add(file, S("ウインドウを閉じる", "Close Window", "关闭窗口", "윈도우 닫기"), #selector(NSWindow.performClose(_:)), "w")
        let edit = section(S("編集", "Edit", "编辑", "편집"))
        add(edit, S("取り消す", "Undo", "撤销", "실행 취소"), Selector(("undo:")), "z")
        let redo = edit.addItem(withTitle: S("やり直す", "Redo", "重做", "실행 복귀"), action: Selector(("redo:")), keyEquivalent: "z"); redo.keyEquivalentModifierMask = [.command, .shift]
        for (title, action, key) in [(S("カット", "Cut", "剪切", "오려두기"), "cut:", "x"), (S("コピー", "Copy", "拷贝", "복사하기"), "copy:", "c"), (S("ペースト", "Paste", "粘贴", "붙여넣기"), "paste:", "v"), (S("すべてを選択", "Select All", "全选", "모두 선택"), "selectAll:", "a")] { add(edit, title, Selector(action), key) }
        let windows = section(S("ウインドウ", "Window", "窗口", "윈도우")); NSApp.windowsMenu = windows
        add(windows, S("しまう", "Minimize", "最小化", "최소화"), #selector(NSWindow.performMiniaturize(_:)))
        add(windows, S("拡大／縮小", "Zoom", "缩放", "확대/축소"), #selector(NSWindow.performZoom(_:)))
        add(windows, S("すべてを手前に移動", "Bring All to Front", "前置全部窗口", "모두 앞으로 가져오기"), #selector(NSApplication.arrangeInFront(_:)), "", NSApp)
        let helpMenu = section(S("ヘルプ", "Help", "帮助", "도움말")); NSApp.helpMenu = helpMenu
        add(helpMenu, name + S("ヘルプ", " Help", " 帮助", " 도움말"), #selector(openHelp), "?", self); helpMenu.addItem(.separator()); HelpLinks.addNoteItem(to: helpMenu)
    }
}

struct StoreRoot: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) { Text(storeTitle).font(.title2.bold()); Text(storeDetail).foregroundColor(.secondary) }
                Spacer(); Button(S("設定", "Settings", "设置", "설정")) { StoreDelegate.shared.openSettings() }
            }
            StoreContent()
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: AppSurface.color))
    }
}

@main struct StoreEntry {
    static func main() {
        let app = NSApplication.shared
        app.delegate = StoreDelegate.shared
        app.run()
    }
}
