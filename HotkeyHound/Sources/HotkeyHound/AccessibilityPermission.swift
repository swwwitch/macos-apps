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
        if !NSWorkspace.shared.open(url) {
            feedback.stringValue = AccessibilityText.text("failed")
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
