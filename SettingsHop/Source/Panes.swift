import AppKit

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// The System Settings panes the app opens, in display order.
/// `anchor` is the Privacy & Security subpane; nil opens the pane itself (or the app for `.systemSettings`).
enum Pane: String, CaseIterable {
    case systemSettings, privacy, accessibility, fullDiskAccess, filesAndFolders, screenRecording, inputMonitoring, automation, security, loginItems, defaultBrowser, keyboardShortcuts, airDrop

    static let settingsBundleID = "com.apple.systempreferences"

    var anchor: String? {
        switch self {
        case .systemSettings, .privacy, .loginItems, .defaultBrowser, .keyboardShortcuts, .airDrop: return nil
        case .accessibility: return "Privacy_Accessibility"
        case .fullDiskAccess: return "Privacy_AllFiles"
        case .filesAndFolders: return "Privacy_FilesAndFolders"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .inputMonitoring: return "Privacy_ListenEvent"
        case .automation: return "Privacy_Automation"
        case .security: return "Security"
        }
    }
    /// nil for `.systemSettings`, which launches the app and keeps whatever pane it last showed.
    var url: URL? {
        switch self {
        case .systemSettings: return nil
        case .privacy: return URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
        // The Security section at the bottom of Privacy & Security (the anchor scrolls there; macOS 26, tried).
        case .security: return URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security")
        case .loginItems: return URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        // Desktop & Dock. Anchors (?Browser etc.) do not scroll to the default web browser row (macOS 26, tried).
        case .defaultBrowser: return URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")
        // Keyboard with the Keyboard Shortcuts sheet open (on the section it showed last).
        case .keyboardShortcuts: return URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts")
        case .airDrop: return URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension")
        default: return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor!)")
        }
    }
    /// A row to scroll to after the pane opens (Accessibility permission needed), when the URL cannot reach it.
    var rowTarget: RowLocator.Target? {
        self == .defaultBrowser ? .init(extensionPath: "/System/Library/ExtensionKit/Extensions/DesktopSettings.appex", labelKey: "Default web browser") : nil
    }
    /// Panes reopened at the top of their list (Accessibility permission needed): the extension that has the pane's title.
    var topExtensionPath: String? { self == .privacy ? "/System/Library/ExtensionKit/Extensions/SecurityPrivacyExtension.appex" : nil }
    /// With an unknown anchor the pane opens on its main list (never a sub-page left open last time), scrolled to the end;
    /// `topExtensionPath` then scrolls it back up (macOS 26, tried).
    var mainListURL: URL? { self == .privacy ? URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy") : nil }
    /// Privacy lists where Option-click selects the previously active app's row.
    var listsApps: Bool { [.accessibility, .fullDiskAccess, .screenRecording, .inputMonitoring].contains(self) }
    /// Subpanes of Privacy & Security are drawn indented under it.
    var isSubpane: Bool { anchor != nil }
    var symbol: String {
        switch self {
        case .systemSettings: return "gearshape"
        case .privacy: return "hand.raised"
        case .accessibility: return "accessibility"
        case .fullDiskAccess: return "internaldrive"
        case .filesAndFolders: return "folder"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .loginItems: return "power"
        case .defaultBrowser: return "globe"
        case .keyboardShortcuts: return "keyboard"
        case .inputMonitoring: return "eye"
        case .automation: return "gearshape.2"
        case .security: return "lock.shield"
        case .airDrop: return "dot.radiowaves.left.and.right"
        }
    }
    /// Panes without a ⌘ key (the user's choice); ⌘ plus a digit only reaches nine.
    static let unkeyed: Set<Pane> = [.privacy, .inputMonitoring, .automation, .security]
    /// ⌘1–⌘9 in display order, skipping `unkeyed` ("").
    var keyEquivalent: String {
        guard !Pane.unkeyed.contains(self) else { return "" }
        let keyed = Pane.allCases.filter { !Pane.unkeyed.contains($0) }
        return String((keyed.firstIndex(of: self) ?? 0) + 1)
    }
    var title: String { L("pane." + rawValue) }

    /// Opens the pane. Returns false when macOS could not hand the URL or app over.
    @discardableResult
    func open(workspace: NSWorkspace = .shared) -> Bool {
        if let url { return workspace.open(url) }
        guard let app = workspace.urlForApplication(withBundleIdentifier: Pane.settingsBundleID) else { return false }
        workspace.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        return true
    }
}
