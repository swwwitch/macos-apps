import AppKit

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition { print("PASS:", message) } else { failures += 1; print("FAIL:", message) }
}

check(Pane.allCases.count == 16, "sixteen panes")
check(Pane.allCases.map(\.defaultKey) == ["1", "", "2", "3", "4", "5", "", "", "", "", "", "6", "7", "8", "9", ""], "⌘1–⌘9 skipping Privacy & Security, Input Monitoring and Automation")
check(Pane.airDrop.url?.absoluteString == "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension", "AirDrop & Handoff URL")
check(Pane.systemSettings.url == nil && !Pane.systemSettings.isSubpane, "System Settings opens the app, not a URL")
check(Pane.privacy.url?.absoluteString == "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" && !Pane.privacy.isSubpane, "Privacy & Security URL")
let expected: [Pane: String] = [.accessibility: "Privacy_Accessibility", .fullDiskAccess: "Privacy_AllFiles",
                                .filesAndFolders: "Privacy_FilesAndFolders", .screenRecording: "Privacy_ScreenCapture", .camera: "Privacy_Camera", .microphone: "Privacy_Microphone", .inputMonitoring: "Privacy_ListenEvent", .automation: "Privacy_Automation"]
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

var layout = PaneLayout()
check(layout.visible == Pane.allCases && layout.key(for: .accessibility) == "2", "default layout shows every pane with the default keys")
layout.assign("2", to: .camera)
check(layout.key(for: .camera) == "2" && layout.key(for: .accessibility) == "" && layout.pane(forKey: "2") == .camera, "assigning a digit takes it from the other pane")
layout.hidden.insert(.camera)
check(layout.key(for: .camera) == "" && layout.pane(forKey: "2") == nil && !layout.visible.contains(.camera), "a hidden pane has no key")
let restored = PaneLayout(hiddenPlist: layout.hiddenPlist, keysPlist: layout.keysPlist)
check(restored.hidden == layout.hidden && Pane.allCases.allSatisfy { restored.keys[$0] == (layout.keys[$0] ?? $0.defaultKey) }, "the layout round-trips through plist values")
check(PaneLayout(hiddenPlist: nil, keysPlist: ["accessibility": "x", "fullDiskAccess": "1"]).key(for: .accessibility) == "2", "invalid stored keys are ignored")
check(PaneLayout(hiddenPlist: nil, keysPlist: ["camera": "1"]).key(for: .systemSettings) == "", "a pane without a stored key gives up a default digit already taken")
var single = PaneLayout(); single.hidden = Set(Pane.allCases.dropFirst())
check(!single.canHide(.systemSettings) && single.canHide(.camera), "the last visible pane cannot be hidden")

print(failures == 0 ? "All tests passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
