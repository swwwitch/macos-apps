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

    private var japanese: Bool { Locale.preferredLanguages.first?.hasPrefix("ja") == true }
    func text(_ ja: String, _ en: String) -> String { japanese ? ja : en }

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
            alert.messageText = text("更新配布の準備中", "Updates are not configured")
            alert.informativeText = failureMessage ?? text(
                "このビルドには更新先と検証用公開鍵が設定されていません。自動更新は利用できません。配布元の新しい案内をお待ちください。",
                "This build has no configured update feed and verification key. Automatic updates are unavailable. Please wait for the publisher's release instructions.")
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
        let check = menu.addItem(withTitle: text("アップデートを確認…", "Check for Updates…"), action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        check.target = self
        let automatic = menu.addItem(withTitle: text("アップデートを自動確認", "Automatically Check for Updates"), action: #selector(toggleAutomaticChecks(_:)), keyEquivalent: "")
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
            Button(updates.text("アップデートを確認…", "Check for Updates…")) { updates.checkForUpdates() }
                .disabled(!updates.canCheck)
            Toggle(updates.text("アップデートを自動確認", "Automatically Check for Updates"), isOn: Binding(
                get: { updates.automaticChecks }, set: { _ in updates.toggleAutomaticChecks() }))
                .disabled(!updates.isConfigured)
        }
    }
}
#endif
