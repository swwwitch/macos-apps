import AppKit
@preconcurrency import ApplicationServices
import SwiftUI

// Canonical source: Shared/Accessibility/AccessibilityPermission.swift.
// Reading trust never prompts. Only the explicit request action may prompt.
final class AccessibilityPermissionState {
    let required: Bool
    private let check: () -> Bool
    private let request: () -> Void
    private(set) var allowed = false
    init(required: Bool, check: @escaping () -> Bool = { AXIsProcessTrusted() },
         request: @escaping () -> Void = {
             _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
         }) {
        self.required = required; self.check = check; self.request = request
    }
    func refresh() { allowed = check() }
    func requestFromUser() {
        refresh()
        guard required && !allowed else { return }
        request()
        // The asynchronous OS prompt's return value is not a grant.
        refresh()
    }
}

enum AccessibilityText {
    /// App-specific reason for the permission, in ja/en/zh/ko order. Set at launch when "needed" does not fit the app.
    nonisolated(unsafe) static var optionTypeToSelect = false
    nonisolated(unsafe) static var neededOverride: [String]?
    static func text(_ key: String) -> String {
        // Same language rule as the rest of the settings window (Japanese-only apps stay Japanese).
        let index = Int(StartupWindow.text("0", "1", "2", "3")) ?? 1
        if key == "needed", let neededOverride, neededOverride.count == 4 { return neededOverride[index] }
        return strings[key]?[index] ?? key
    }
    static let strings: [String: [String]] = [
        "title": ["アクセシビリティ", "Accessibility", "辅助功能", "손쉬운 사용"],
        "allowed": ["許可済み", "Allowed", "已允许", "허용됨"],
        "denied": ["未許可", "Not allowed", "未允许", "허용되지 않음"],
        "needed": ["他のアプリで選択した文字の取得・置換に使用します。未許可の場合、選択文字の加工は利用できません。", "Used to read and replace selected text in other apps. Selected-text actions are unavailable without permission.", "用于读取和替换其他应用中选定的文字。未获授权时，无法处理选定的文字。", "다른 앱에서 선택한 텍스트를 읽고 바꾸는 데 사용합니다. 권한이 없으면 선택한 텍스트를 처리할 수 없습니다."],
        "unneeded": ["現在の機能では、この権限は不要です。未許可のまま利用できます。", "Current features do not require this permission. You can use this app without granting it.", "当前功能不需要此权限。无需授权即可使用。", "현재 기능에는 이 권한이 필요하지 않습니다. 허용하지 않아도 사용할 수 있습니다."],
        "request": ["許可を要求…", "Ask for Permission…", "请求授权…", "권한 요청…"],
        "open": ["アクセシビリティ設定を開く", "Open Accessibility Settings", "打开辅助功能设置", "손쉬운 사용 설정 열기"],
        "hint": ["変更後にこの画面へ戻ると状態を再確認します。反映されない場合はアプリを再起動してください。", "Return to this window to refresh the status. If it has not changed, restart the app.", "返回此窗口时将重新检查状态。如未更新，请重新启动应用。", "이 창으로 돌아오면 상태를 다시 확인합니다. 반영되지 않으면 앱을 다시 시작하세요."],
        "blocked": ["アクセシビリティが未許可のため実行できませんでした。設定の「起動・常駐」で許可してください。", "Could not run because Accessibility is not allowed. Allow it in Settings → Startup & Background.", "未获得辅助功能授权，无法执行。请在设置的“启动与后台”中授权。", "손쉬운 사용 권한이 없어 실행하지 못했습니다. 설정의 ‘시작 및 백그라운드’에서 허용하세요."],
        "failed": ["システム設定を開けませんでした。「プライバシーとセキュリティ」→「アクセシビリティ」を手動で開いてください。", "Could not open System Settings. Open Privacy & Security → Accessibility manually.", "无法打开系统设置。请手动打开“隐私与安全性”→“辅助功能”。", "시스템 설정을 열 수 없습니다. 개인정보 보호 및 보안 → 손쉬운 사용을 직접 여세요."]
    ]
}

final class AccessibilityPermissionControl: NSView {
    private let state: AccessibilityPermissionState
    private let status = NSTextField(labelWithString: "")
    private let icon = NSImageView()
    private let feedback = NSTextField(wrappingLabelWithString: "")
    private let reason = NSTextField(wrappingLabelWithString: "")
    private let stack = NSStackView()
    private var laidOutWidth: CGFloat = 0
    private var requestButton: NSButton?
    /// showsTitle: false when the caller already puts it under a section titled 「アクセシビリティ」.
    init(required: Bool = false, showsTitle: Bool = true, state: AccessibilityPermissionState? = nil) {
        self.state = state ?? AccessibilityPermissionState(required: required)
        super.init(frame: .zero)
        let title = NSTextField(labelWithString: AccessibilityText.text("title"))
        title.font = .boldSystemFont(ofSize: 13)
        reason.stringValue = AccessibilityText.text(self.state.required ? "needed" : "unneeded")
        reason.font = .systemFont(ofSize: 12)
        let row = NSStackView(views: [icon, status]); row.spacing = 8
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        let buttons = NSStackView(); buttons.spacing = 8
        if self.state.required {
            let button = NSButton(title: AccessibilityText.text("request"), target: self, action: #selector(requestPermission))
            button.bezelStyle = .rounded; buttons.addArrangedSubview(button); requestButton = button
        }
        let open = NSButton(title: AccessibilityText.text("open"), target: self, action: #selector(openSettings))
        open.bezelStyle = .rounded; buttons.addArrangedSubview(open)
        feedback.stringValue = AccessibilityText.text("hint")
        feedback.font = .systemFont(ofSize: 11); feedback.textColor = .secondaryLabelColor
        stack.setViews((showsTitle ? [title] : []) + [reason, row, buttons, feedback], in: .leading)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            reason.widthAnchor.constraint(equalTo: stack.widthAnchor), feedback.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSWindow.didBecomeKeyNotification, object: nil)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    /// Height of the content at the current width, so no blank space is left below it.
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: ceil(stack.fittingSize.height)) }
    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.width != laidOutWidth else { return }
        laidOutWidth = bounds.width
        reason.preferredMaxLayoutWidth = bounds.width; feedback.preferredMaxLayoutWidth = bounds.width
        invalidateIntrinsicContentSize()
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
    @objc func refresh() {
        state.refresh()
        status.stringValue = AccessibilityText.text(state.allowed ? "allowed" : "denied")
        status.setAccessibilityLabel(AccessibilityText.text("title") + ": " + status.stringValue)
        icon.image = NSImage(systemSymbolName: state.allowed ? "checkmark.circle.fill" : "minus.circle", accessibilityDescription: nil)
        icon.contentTintColor = state.allowed ? .systemGreen : .secondaryLabelColor
        requestButton?.isEnabled = !state.allowed
    }
    @objc private func requestPermission() { state.requestFromUser(); refresh() }
    @objc private func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        let assist = AccessibilityText.optionTypeToSelect && NSEvent.modifierFlags.contains(.option)
        if !NSWorkspace.shared.open(url) {
            feedback.stringValue = AccessibilityText.text("failed")
        } else if assist {
            MainActor.assumeIsolated {
                AccessibilitySettingsLocator.shared.start { [weak self] text in self?.feedback.stringValue = text }
            }
        }
    }
}

struct AccessibilityPermissionView: NSViewRepresentable {
    var required = false
    var showsTitle = true
    func makeNSView(context: Context) -> AccessibilityPermissionControl { AccessibilityPermissionControl(required: required, showsTitle: showsTitle) }
    func updateNSView(_ nsView: AccessibilityPermissionControl, context: Context) { nsView.refresh() }
}

final class AccessibilityPreferencesDocumentView: NSView {
    override var isFlipped: Bool { true }
}

/// The standard 「アクセシビリティ」 group of the 「起動・常駐」 tab, for apps that need the permission (B20).
/// Apps that do not use Accessibility show nothing. The reason goes in AccessibilityText.neededOverride at launch.
struct AccessibilitySection: View {
    /// false while the features that need the permission are off (the reason then says it is not needed now).
    var required = true
    var body: some View {
        SettingsSection(AccessibilityText.text("title")) { AccessibilityPermissionView(required: required, showsTitle: false) }
    }
    /// Checked just before acting; never prompts.
    static var isTrusted: Bool { AXIsProcessTrusted() }
    /// AppKit form (SettingsUI.tabs pages).
    @MainActor static func group() -> NSBox {
        SettingsUI.group(AccessibilityText.text("title"), [AccessibilityPermissionControl(required: true, showsTitle: false)])
    }
}

/// Optional, explicit user action. Never changes a permission switch or clicks an app row.
@MainActor
final class AccessibilitySettingsLocator {
    static let shared = AccessibilitySettingsLocator()
    private var task: Task<Void, Never>?
    private func text(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String {
        StartupWindow.text(ja, en, zh, ko)
    }
    func start(feedback: @escaping (String) -> Void) {
        task?.cancel()
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
            feedback(text("設定を開きました。未許可のため自動入力・ポインタ移動は行えません。一覧をクリックしてアプリ名の先頭3文字を入力してください。", "Settings opened. Permission is required for automatic typing and pointer movement. Click the list and type the first three letters of the app name.", "已打开设置。自动输入和移动指针需要授权。请点击列表并输入应用名称的前三个字符。", "설정을 열었습니다. 자동 입력과 포인터 이동에는 권한이 필요합니다. 목록을 클릭하고 앱 이름의 처음 세 글자를 입력하세요."))
            return
        }
        let name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ""
        guard !name.isEmpty else { return }
        task = Task { [weak self] in
            // Poll the ready AX list rather than sending keystrokes after a blind delay.
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, let self else { return }
                guard let front = NSWorkspace.shared.frontmostApplication,
                      front.bundleIdentifier == "com.apple.systempreferences" else { continue }
                let root = AXUIElementCreateApplication(front.processIdentifier)
                if let match = self.find(name: name, in: root), let point = self.position(match) {
                    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier,
                          AXIsProcessTrusted(), CGPreflightPostEventAccess() else { return }
                    // Focus the containing list before invoking its type-to-select behavior.
                    var parent: CFTypeRef?
                    AXUIElementCopyAttributeValue(match, kAXParentAttribute as CFString, &parent)
                    if let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() {
                        let list = unsafeBitCast(parent, to: AXUIElement.self)
                        var role: CFTypeRef?
                        AXUIElementCopyAttributeValue(list, kAXRoleAttribute as CFString, &role)
                        let isList = ["AXTable", "AXOutline", "AXList"].contains(role as? String ?? "")
                        let result = isList ? AXUIElementSetAttributeValue(list, kAXFocusedAttribute as CFString, kCFBooleanTrue) : .attributeUnsupported
                        if result == .success {
                            let letters = Array(name.prefix(3).utf16)
                            for down in [true, false] {
                                if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) {
                                    letters.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress) }
                                    event.postToPid(front.processIdentifier)
                                }
                            }
                        }
                    }
                    var supported: CFArray?
                    if AXUIElementCopyActionNames(match, &supported) == .success,
                       (supported as? [String])?.contains("AXScrollToVisible") == true {
                        AXUIElementPerformAction(match, "AXScrollToVisible" as CFString)
                    }
                    AXUIElementSetAttributeValue(match, kAXSelectedAttribute as CFString, kCFBooleanTrue)
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier,
                       let target = self.position(match) ?? Optional(point) {
                        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: target, mouseButton: .left)?.post(tap: .cghidEventTap)
                    }
                    feedback(self.text("アプリ名の位置へ移動しました。許可のスイッチは手動で操作してください。", "Moved near the app name. Change the permission switch yourself.", "已移至应用名称附近。请手动操作授权开关。", "앱 이름 근처로 이동했습니다. 권한 스위치는 직접 조작하세요."))
                    return
                }
            }
            guard !Task.isCancelled, let self else { return }
            feedback(self.text("アプリ名の行を確認できなかったため、自動入力・移動を行いませんでした。", "Could not identify the app row; no automatic typing or movement was performed.", "无法确认应用所在行，未自动输入或移动。", "앱 행을 확인하지 못해 자동 입력과 이동을 수행하지 않았습니다."))
        }
    }
    private func find(name: String, in root: AXUIElement) -> AXUIElement? {
        var queue = [root], index = 0
        while index < queue.count && index < 1200 {
            let element = queue[index]; index += 1
            for key in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success,
                   let title = value as? String, title.caseInsensitiveCompare(name) == .orderedSame {
                    var candidate = element
                    for _ in 0..<6 {
                        var role: CFTypeRef?
                        AXUIElementCopyAttributeValue(candidate, kAXRoleAttribute as CFString, &role)
                        if role as? String == "AXRow" { return candidate }
                        var parent: CFTypeRef?
                        guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parent) == .success,
                              let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                        candidate = unsafeBitCast(parent, to: AXUIElement.self)
                    }
                    return element
                }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let list = children as? [AXUIElement] { queue.append(contentsOf: list) }
        }
        return nil
    }
    private func position(_ element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cgPoint, &point) else { return nil }
        return CGPoint(x: point.x + 12, y: point.y + 8)
    }
}
