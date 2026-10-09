import AppKit

// Canonical source: Shared/AppStandards/WindowActivationPolicy.swift.
/// Menu-bar apps appear in ⌘Tab (and the Dock) only while a regular window is open.
/// Panels such as palettes and the About panel do not count; a hidden app (⌘H) stays listed so it can come back.
enum WindowActivationPolicy {
    nonisolated(unsafe) private static var observers: [NSObjectProtocol] = []
    static func install() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didUpdateNotification, object: nil, queue: .main) { _ in update() })
        // Closing the last window may not be followed by another update pass while the app is inactive.
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.async { update() }
        })
        update()
    }
    static func update() {
        let wanted: NSApplication.ActivationPolicy = NSApp.isHidden || NSApp.windows.contains(where: counts) ? .regular : .accessory
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
    }
    private static func counts(_ window: NSWindow) -> Bool {
        (window.isVisible || window.isMiniaturized) && !(window is NSPanel) && window.canBecomeMain && window.styleMask.contains(.titled)
    }
}
