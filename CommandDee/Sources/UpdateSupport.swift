// Shared implementation. Copies in app targets are checked by prepare.py.
#if DIRECT_UPDATES && !APP_STORE
import AppKit
import SwiftUI
import Sparkle

@MainActor
final class AppUpdates: NSObject, ObservableObject, NSMenuItemValidation {
    static let shared = AppUpdates()
    @Published private(set) var canCheck = true
    @Published private(set) var automaticChecks = false
    private var controller: SPUStandardUpdaterController?
    private var observations: [NSKeyValueObservation] = []
    private var attemptedStart = false
    private var failureMessage: String?

    /// ja / en / zh-Hans / ko, chosen from the user's first preferred language (others fall back to English).
    func text(_ ja: String, _ en: String, _ zh: String? = nil, _ ko: String? = nil) -> String {
        let language = Locale.preferredLanguages.first ?? ""
        if language.hasPrefix("ja") { return ja }
        if language.hasPrefix("zh"), let zh { return zh }
        if language.hasPrefix("ko"), let ko { return ko }
        return en
    }

    func start() {
        guard !attemptedStart else { return }
        attemptedStart = true
        let info = Bundle.main.infoDictionary ?? [:]
        guard let feed = info["SUFeedURL"] as? String,
              let url = URLComponents(string: feed), url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil,
              let key = info["SUPublicEDKey"] as? String,
              let bytes = Data(base64Encoded: key), bytes.count == 32,
              bytes.contains(where: { $0 != 0 }),
              info["SUVerifyUpdateBeforeExtraction"] as? Bool == true,
              info["SURequireSignedFeed"] as? Bool == true else { return }
        let newController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        do {
            try newController.updater.start()
            controller = newController
            observations = [
                newController.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                    let value = updater.canCheckForUpdates
                    Task { @MainActor [weak self] in self?.canCheck = value }
                },
                newController.updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                    let value = updater.automaticallyChecksForUpdates
                    Task { @MainActor [weak self] in self?.automaticChecks = value }
                }
            ]
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    @objc func checkForUpdates(_ sender: Any? = nil) {
        start()
        if let controller {
            guard controller.updater.canCheckForUpdates else { return }
            controller.checkForUpdates(sender)
        } else {
            let alert = NSAlert()
            alert.messageText = text("更新配布の準備中", "Updates are not configured", "尚未配置更新", "업데이트가 설정되지 않음")
            alert.informativeText = failureMessage ?? text(
                "このビルドには更新先と検証用公開鍵が設定されていません。自動更新は利用できません。配布元の新しい案内をお待ちください。",
                "This build has no configured update feed and verification key. Automatic updates are unavailable. Please wait for the publisher's release instructions.",
                "此版本未配置更新源和验证公钥，无法自动更新。请等待发布者的新通知。",
                "이 빌드에는 업데이트 주소와 검증용 공개 키가 설정되어 있지 않아 자동 업데이트를 사용할 수 없습니다. 배포자의 새 안내를 기다려 주세요.")
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc func toggleAutomaticChecks(_ sender: Any? = nil) {
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates.toggle()
        automaticChecks = updater.automaticallyChecksForUpdates
    }

    func addMenuItems(to menu: NSMenu) {
        start()
        let check = menu.addItem(withTitle: text("アップデートを確認…", "Check for Updates…", "检查更新…", "업데이트 확인…"), action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        check.target = self
        let automatic = menu.addItem(withTitle: text("アップデートを自動確認", "Automatically Check for Updates", "自动检查更新", "자동으로 업데이트 확인"), action: #selector(toggleAutomaticChecks(_:)), keyEquivalent: "")
        automatic.target = self
        menu.addItem(.separator())
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleAutomaticChecks(_:)) {
            menuItem.state = automaticChecks ? .on : .off
            return controller != nil
        }
        return controller?.updater.canCheckForUpdates ?? true
    }

    var isConfigured: Bool { controller != nil }
}

struct UpdateCommands: Commands {
    @ObservedObject private var updates = AppUpdates.shared
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(updates.text("アップデートを確認…", "Check for Updates…", "检查更新…", "업데이트 확인…")) { updates.checkForUpdates() }
                .disabled(!updates.canCheck)
            Toggle(updates.text("アップデートを自動確認", "Automatically Check for Updates", "自动检查更新", "자동으로 업데이트 확인"), isOn: Binding(
                get: { updates.automaticChecks }, set: { _ in updates.toggleAutomaticChecks() }))
                .disabled(!updates.isConfigured)
        }
    }
}
#endif
