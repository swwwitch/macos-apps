import AppKit

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// The System Settings panes the app opens, in display order.
/// `anchor` is the Privacy & Security subpane; nil opens the pane itself (or the app for `.systemSettings`).
enum Pane: String, CaseIterable {
    case systemSettings, privacy, accessibility, fullDiskAccess, filesAndFolders, screenRecording, camera, microphone, inputMonitoring, automation, security, loginItems, defaultBrowser, keyboardShortcuts, airDrop

    static let settingsBundleID = "com.apple.systempreferences"

    var anchor: String? {
        switch self {
        case .systemSettings, .privacy, .loginItems, .defaultBrowser, .keyboardShortcuts, .airDrop: return nil
        case .accessibility: return "Privacy_Accessibility"
        case .fullDiskAccess: return "Privacy_AllFiles"
        case .filesAndFolders: return "Privacy_FilesAndFolders"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .camera: return "Privacy_Camera"
        case .microphone: return "Privacy_Microphone"
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
    var listsApps: Bool { [.accessibility, .fullDiskAccess, .screenRecording, .camera, .microphone, .inputMonitoring].contains(self) }
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
        case .camera: return "camera"
        case .microphone: return "mic"
        case .loginItems: return "power"
        case .defaultBrowser: return "globe"
        case .keyboardShortcuts: return "keyboard"
        case .inputMonitoring: return "eye"
        case .automation: return "gearshape.2"
        case .security: return "lock.shield"
        case .airDrop: return "dot.radiowaves.left.and.right"
        }
    }
    /// Panes without a ⌘ key by default (the user's choice); ⌘ plus a digit only reaches nine.
    static let unkeyed: Set<Pane> = [.privacy, .camera, .microphone, .inputMonitoring, .automation, .security]
    /// The default ⌘1–⌘9 in display order, skipping `unkeyed` (""). Settings › Items can change them.
    var defaultKey: String {
        guard !Pane.unkeyed.contains(self) else { return "" }
        let keyed = Pane.allCases.filter { !Pane.unkeyed.contains($0) }
        return String((keyed.firstIndex(of: self) ?? 0) + 1)
    }
    /// The main window draws a divider between groups: System Settings, Privacy & Security with its subpanes, the rest.
    var group: Int { self == .systemSettings ? 0 : self == .privacy || isSubpane ? 1 : 2 }
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

/// Which panes are shown and the digit each one opens with (⌘ plus the digit, or the digit alone in the main window).
/// Stored as plist values so 設定の共有 can carry them.
struct PaneLayout: Equatable {
    var hidden: Set<Pane> = []
    /// Pane → "1"–"9" or "" (no key). Missing panes fall back to their default key.
    var keys: [Pane: String] = [:]

    var visible: [Pane] { Pane.allCases.filter { !hidden.contains($0) } }
    /// A hidden pane has no key.
    func key(for pane: Pane) -> String { hidden.contains(pane) ? "" : keys[pane] ?? pane.defaultKey }
    /// The visible pane a digit opens, if any.
    func pane(forKey digit: String) -> Pane? { visible.first { !digit.isEmpty && key(for: $0) == digit } }
    /// Gives `pane` the digit and takes it from any other pane, so one digit opens one pane.
    mutating func assign(_ digit: String, to pane: Pane) {
        if !digit.isEmpty { for other in Pane.allCases where other != pane && (keys[other] ?? other.defaultKey) == digit { keys[other] = "" } }
        keys[pane] = digit
    }
    /// At least one pane stays visible so the main window is never empty.
    func canHide(_ pane: Pane) -> Bool { hidden.contains(pane) || visible.count > 1 }

    var hiddenPlist: [String] { hidden.map(\.rawValue).sorted() }
    var keysPlist: [String: String] { Dictionary(uniqueKeysWithValues: Pane.allCases.map { ($0.rawValue, key(ignoringHidden: $0)) }) }
    private func key(ignoringHidden pane: Pane) -> String { keys[pane] ?? pane.defaultKey }
    init() {}
    init(hiddenPlist: Any?, keysPlist: Any?) {
        hidden = Set((hiddenPlist as? [String] ?? []).compactMap(Pane.init(rawValue:)))
        for (name, digit) in keysPlist as? [String: String] ?? [:] {
            if let pane = Pane(rawValue: name), digit.isEmpty || (digit.count == 1 && ("1"..."9").contains(digit)) { keys[pane] = digit }
        }
        // A pane added in a later version starts without a key when its default digit is already taken.
        let taken = Set(keys.values)
        for pane in Pane.allCases where keys[pane] == nil && taken.contains(pane.defaultKey) { keys[pane] = "" }
    }
}
