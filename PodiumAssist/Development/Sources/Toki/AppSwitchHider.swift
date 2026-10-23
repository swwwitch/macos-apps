import AppKit

/// Event-driven: each activation replaces the pending hide, including a zero-second delay.
@MainActor
final class AppSwitchHider {
    private var activation: NSObjectProtocol?
    private var changes: NSObjectProtocol?
    private var pending: DispatchWorkItem?
    private var generation = 0
    private var lastEnabled = false
    private var lastDelay = 0.0

    static func delay(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 86400) : 0 }

    func start() {
        guard activation == nil else { return }
        lastEnabled = UserDefaults.standard.bool(forKey: "hideOthersOnSwitch")
        lastDelay = Self.delay(UserDefaults.standard.double(forKey: "hideOthersDelay"))
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.schedule(app) }
        }
        changes = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let enabled = UserDefaults.standard.bool(forKey: "hideOthersOnSwitch")
                let delay = Self.delay(UserDefaults.standard.double(forKey: "hideOthersDelay"))
                if enabled != self.lastEnabled || delay != self.lastDelay {
                    self.lastEnabled = enabled
                    self.lastDelay = delay
                    self.cancel()
                }
            }
        }
    }

    private func cancel() { generation += 1; pending?.cancel(); pending = nil }

    private func schedule(_ app: NSRunningApplication?) {
        cancel()
        guard UserDefaults.standard.bool(forKey: "hideOthersOnSwitch"), let app,
              app.activationPolicy == .regular, !ExcludedApps.shared.excludes(app.bundleIdentifier) else { return }
        let token = generation
        let work = DispatchWorkItem { [weak self, weak app] in
            MainActor.assumeIsolated {
                guard let self, self.generation == token, let app, !app.isTerminated,
                      UserDefaults.standard.bool(forKey: "hideOthersOnSwitch"),
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
                      !ExcludedApps.shared.excludes(app.bundleIdentifier) else { return }
                for other in NSWorkspace.shared.runningApplications where other.processIdentifier != app.processIdentifier && other.activationPolicy == .regular && !other.isHidden && !other.isTerminated {
                    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { break }
                    if !ExcludedApps.shared.excludes(other.bundleIdentifier) { other.hide() }
                }
                self.pending = nil
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay(UserDefaults.standard.double(forKey: "hideOthersDelay")), execute: work)
    }

    deinit {
        pending?.cancel()
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        if let changes { NotificationCenter.default.removeObserver(changes) }
    }
}
