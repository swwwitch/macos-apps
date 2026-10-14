import AppKit
import UserNotifications

/// Calls `changed` (debounced) when anything in the OOBE folder changes. Creative Cloud replaces the prefs
/// file as soon as a switch is flipped, so the folder's vnode sees it; no polling.
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private var pending: DispatchWorkItem?
    private let changed: () -> Void

    init(changed: @escaping () -> Void) { self.changed = changed }

    /// Safe to call again (e.g. after the folder appears for the first time).
    func start(_ folder: URL = CCAutoUpdate.folder) {
        guard source == nil else { return }
        descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if source.data.contains(.delete) || source.data.contains(.rename) { stop() }
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.changed() }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
        }
        source.setCancelHandler { [descriptor] in close(descriptor) }
        source.resume()
        self.source = source
    }

    func stop() { source?.cancel(); source = nil }
}

/// macOS notifications. Clicking one opens Creative Cloud.
final class Notifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    @Published private(set) var authorized: Bool?

    func setUp() {
        UNUserNotificationCenter.current().delegate = self
        refreshAuthorization()
    }

    func refreshAuthorization(_ done: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            DispatchQueue.main.async { self.authorized = ok; done?(ok) }
        }
    }

    func post(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.authorized = granted }
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            center.add(UNNotificationRequest(identifier: "ccAutoUpdate", content: content, trigger: nil))
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { Mailer.openCreativeCloud() }
        completionHandler()
    }
}

/// Sends mail through the Mail app (its default account). macOS asks once for permission to control Mail.
enum Mailer {
    /// nil on success, otherwise a message for the status line.
    static func send(to address: String, subject: String, body: String) -> String? {
        guard CCAutoUpdate.isValidAddress(address) else { return L("mailInvalidAddress") }
        var error: NSDictionary?
        NSAppleScript(source: CCAutoUpdate.mailScript(to: address, subject: subject, body: body))?.executeAndReturnError(&error)
        guard let error else { return nil }
        let code = error[NSAppleScript.errorNumber] as? Int ?? 0
        // -1743: the user (or a previous answer) denied controlling Mail.
        if code == -1743 { return L("mailDenied") }
        return L("mailFailed") + (error[NSAppleScript.errorMessage] as? String ?? String(code))
    }

    static func openCreativeCloud() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: CCAutoUpdate.creativeCloudID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
