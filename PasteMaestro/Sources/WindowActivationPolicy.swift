import AppKit

// Canonical source: Shared/AppStandards/WindowActivationPolicy.swift.
/// Menu-bar apps appear in ⌘Tab (and the Dock) only while a regular window is open.
/// Panels such as palettes and the About panel do not count; a hidden app (⌘H) stays listed so it can come back.
/// AppSwitcherWindowReveal uses the app-owned main-window action on activation (⌘Tab sends no reopen event).
enum WindowActivationPolicy {
    nonisolated(unsafe) private static var observers: [NSObjectProtocol] = []
    static func install() {
        guard observers.isEmpty else { return }
        DockPresence.usualPolicy = usualPolicy
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didUpdateNotification, object: nil, queue: .main) { _ in update() })
        // Closing the last window may not be followed by another update pass while the app is inactive.
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.async { update() }
        })
        update()
    }
    static func restoreMinimized() {
        let windows = NSApp.windows.filter { !($0 is NSPanel) && ($0.canBecomeMain || $0.isMiniaturized) && $0.styleMask.contains(.titled) }
        guard !windows.contains(where: { $0.isVisible }), let window = windows.first(where: { $0.isMiniaturized }) else { return }
        window.deminiaturize(nil)
    }
    /// DockPresence keeps menus available while regular windows exist, including minimized ones.
    static func update() { DockPresence.apply() }
    private static func usualPolicy() -> NSApplication.ActivationPolicy {
        NSApp.isHidden || NSApp.windows.contains(where: counts) ? .regular : .accessory
    }
    private static func counts(_ window: NSWindow) -> Bool {
        DockPresence.counts(window)
    }
}
