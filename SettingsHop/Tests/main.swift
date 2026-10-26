import AppKit

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition { print("PASS:", message) } else { failures += 1; print("FAIL:", message) }
}

check(Pane.allCases.count == 13, "thirteen panes")
check(Pane.allCases.map(\.keyEquivalent) == ["1", "", "2", "3", "4", "5", "", "", "", "6", "7", "8", "9"], "⌘1–⌘9 skipping Privacy & Security, Input Monitoring and Automation")
check(Pane.airDrop.url?.absoluteString == "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension", "AirDrop & Handoff URL")
check(Pane.systemSettings.url == nil && !Pane.systemSettings.isSubpane, "System Settings opens the app, not a URL")
check(Pane.privacy.url?.absoluteString == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" && !Pane.privacy.isSubpane, "Privacy & Security URL")
let expected: [Pane: String] = [.accessibility: "Privacy_Accessibility", .fullDiskAccess: "Privacy_AllFiles",
                                .filesAndFolders: "Privacy_FilesAndFolders", .screenRecording: "Privacy_ScreenCapture", .inputMonitoring: "Privacy_ListenEvent", .automation: "Privacy_Automation"]
for (pane, anchor) in expected {
    check(pane.url?.absoluteString == "x-apple.systempreferences:com.apple.preference.security?\(anchor)" && pane.isSubpane, "\(pane.rawValue) URL")
}
check(Pane.loginItems.url?.absoluteString == "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" && !Pane.loginItems.isSubpane, "Login Items URL")
check(Pane.defaultBrowser.url?.absoluteString == "x-apple.systempreferences:com.apple.Desktop-Settings.extension" && !Pane.defaultBrowser.isSubpane, "Desktop & Dock URL")
check(Pane.keyboardShortcuts.url?.absoluteString == "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts", "Keyboard Shortcuts URL")
check(Pane.security.url?.absoluteString == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security" && Pane.security.isSubpane, "Security section URL")
check(Pane.allCases.allSatisfy { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil) != nil }, "every SF Symbol exists on this macOS")
check(NSWorkspace.shared.urlForApplication(withBundleIdentifier: Pane.settingsBundleID) != nil, "System Settings is found by bundle ID")
check(Pane.allCases.allSatisfy { $0.url.map { NSWorkspace.shared.urlForApplication(toOpen: $0) != nil } ?? true }, "every pane URL has a handler")

print(failures == 0 ? "All tests passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
