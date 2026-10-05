import AppKit

@main
struct SmokeTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let updates = AppUpdates.shared
        updates.start()
        precondition(!updates.isConfigured, "Unconfigured bundles must not start Sparkle")
        let menu = NSMenu()
        updates.addMenuItems(to: menu)
        precondition(menu.items.count == 3)
        precondition(updates.validateMenuItem(menu.items[0]), "Manual action must explain unavailable updates")
        precondition(!updates.validateMenuItem(menu.items[1]), "Automatic checking must remain disabled")
        updates.toggleAutomaticChecks()
        precondition(!updates.automaticChecks)
        print("PASS: no updater for missing configuration; manual action available; automatic checks disabled")
    }
}
