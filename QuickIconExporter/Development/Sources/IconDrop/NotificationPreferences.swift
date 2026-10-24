import AppKit
import SwiftUI
@preconcurrency import UserNotifications

/// B32: reading or posting never asks for permission. Only an explicit settings action may ask.
final class NotificationPreferences: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = NotificationPreferences()
    @Published private(set) var status: UNAuthorizationStatus?
    @Published private(set) var errorMessage = ""
    @Published private(set) var requesting = false
    static var title: String { StartupWindow.text("通知", "Notifications", "通知", "알림") }
    static var completionTitle: String { StartupWindow.text("処理完了を通知", "Notify when finished", "完成时通知", "완료 시 알림") }
    static var detail: String { StartupWindow.text("表示場所・通知スタイル・サウンドはmacOSの通知設定で変更できます。通知が無効でも処理結果はアプリ内で確認できます。", "Choose placement, style and sound in macOS notification settings. Results remain available in the app when notifications are off.", "可在 macOS 通知设置中更改显示位置、样式和声音。关闭通知后仍可在应用内查看结果。", "macOS 알림 설정에서 표시 위치, 스타일, 사운드를 변경할 수 있습니다. 알림을 꺼도 앱에서 결과를 확인할 수 있습니다.") }
    var statusText: String {
        switch status {
        case .authorized, .provisional: return StartupWindow.text("許可済み", "Allowed", "已允许", "허용됨")
        case .denied: return StartupWindow.text("未許可", "Not allowed", "未允许", "허용되지 않음")
        case .notDetermined: return StartupWindow.text("未確認（許可を求めていません）", "Not requested", "尚未请求", "요청하지 않음")
        default: return StartupWindow.text("確認中", "Checking", "正在检查", "확인 중")
        }
    }
    var allowed: Bool { status == .authorized || status == .provisional }
    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let value = settings.authorizationStatus
            DispatchQueue.main.async { self.status = value }
        }
    }
    /// Call on the main thread, in response to a user's action only.
    func request(sound: Bool = false, then: (@Sendable (Bool) -> Void)? = nil) {
        guard !requesting else { return }
        requesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: sound ? [.alert, .sound] : [.alert]) { granted, error in
            let message = error?.localizedDescription ?? ""
            DispatchQueue.main.async {
                self.requesting = false
                self.errorMessage = message
                self.refresh()
                then?(granted)
            }
        }
    }
    func post(title: String, body: String, sound: Bool = false, identifier: String = UUID().uuidString,
              enabledKey: String? = nil, enabledDefault: Bool = true, completion: (@Sendable (Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                DispatchQueue.main.async { self.status = settings.authorizationStatus; completion?(false) }
                return
            }
            if let key = enabledKey, !(UserDefaults.standard.object(forKey: key) as? Bool ?? enabledDefault) {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body
            if sound { content.sound = .default }
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { error in
                let message = error?.localizedDescription ?? ""
                let success = error == nil
                DispatchQueue.main.async { self.errorMessage = message; completion?(success) }
            }
        }
    }
    @MainActor func openSettings() {
        // macOS owns this screen. No UI scripting or changes to permission switches.
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
        if !NSWorkspace.shared.open(url) {
            errorMessage = StartupWindow.text("システム設定の「通知」を開いてください。", "Open Notifications in System Settings.", "请打开系统设置中的“通知”。", "시스템 설정에서 알림을 여세요.")
        }
    }
}

struct NotificationPermissionView: View {
    @ObservedObject private var permission = NotificationPreferences.shared
    @Binding var enabled: Bool
    let toggleTitle: String
    var sound = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(toggleTitle, isOn: Binding(get: { enabled }, set: { value in
                enabled = value
                if value { permission.request(sound: sound) }
            }))
            Label(permission.statusText, systemImage: permission.allowed ? "checkmark.circle.fill" : "info.circle")
                .foregroundStyle(permission.allowed ? Color.green : Color.secondary)
            Text(NotificationPreferences.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if enabled && permission.status == .notDetermined {
                Button(StartupWindow.text("通知を許可…", "Allow Notifications…", "允许通知…", "알림 허용…")) { permission.request(sound: sound) }
                    .disabled(permission.requesting)
            }
            Button(StartupWindow.text("通知設定を開く", "Open Notification Settings", "打开通知设置", "알림 설정 열기")) { permission.openSettings() }
            if !permission.errorMessage.isEmpty {
                Text(permission.errorMessage).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { permission.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in permission.refresh() }
    }
}

struct CompletionNotificationSettings: View {
    @AppStorage("completionNotificationEnabled") private var enabled = true // Preserve FolderHopper's previous behavior.
    var body: some View {
        SettingsSection(NotificationPreferences.title) {
            NotificationPermissionView(enabled: $enabled, toggleTitle: NotificationPreferences.completionTitle)
        }
    }
}
