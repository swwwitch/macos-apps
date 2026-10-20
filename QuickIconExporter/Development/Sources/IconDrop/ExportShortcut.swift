import AppKit
import Carbon

/// 「書き出すホットキー」. Stored as shortcutEnabled / shortcutKey / shortcutModifiers (Carbon values);
/// registered through the shared HotkeySet, which steps aside while the settings field records a key.
@MainActor final class ExportShortcut: ObservableObject {
    static let shared = ExportShortcut()
    /// ⌃⌥⌘I
    nonisolated static let defaultCombo = KeyCombo(code: UInt32(kVK_ANSI_I), modifiers: UInt32(controlKey | optionKey | cmdKey))
    @Published private(set) var enabled = UserDefaults.standard.object(forKey: "shortcutEnabled") as? Bool ?? true
    @Published private(set) var combo = ExportShortcut.storedCombo(key: UserDefaults.standard.object(forKey: "shortcutKey") as? Int,
                                                                   modifiers: UserDefaults.standard.object(forKey: "shortcutModifiers") as? Int)
    @Published private(set) var registrationSucceeded = true
    var action: (() -> Void)?
    private let hotkeys = HotkeySet(signature: "QIEx")
    private var activation: NSObjectProtocol?
    private init() {
        hotkeys.action = { [weak self] _ in self?.action?() }
        // Another of our apps may claim this key for the app in front (SpreadsheetHelper's ⌃⌥⌘I in Excel):
        // step aside there, so the key reaches it (HotkeyManifest.claimedByOtherApp).
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.register() }
        }
    }
    /// Saved Carbon key code and modifiers → KeyCombo; missing values fall back to the initial key.
    nonisolated static func storedCombo(key: Int?, modifiers: Int?) -> KeyCombo {
        KeyCombo(code: UInt32(key ?? Int(defaultCombo.code)), modifiers: UInt32(modifiers ?? Int(defaultCombo.modifiers)))
    }
    func restore() {
        register()
        publish()
    }
    /// Saves even when registration fails, so the field shows the key with the shared failure message.
    func save(enabled: Bool, combo: KeyCombo) {
        self.enabled = enabled; self.combo = combo
        UserDefaults.standard.set(enabled, forKey: "shortcutEnabled")
        UserDefaults.standard.set(Int(combo.code), forKey: "shortcutKey")
        UserDefaults.standard.set(Int(combo.modifiers), forKey: "shortcutModifiers")
        register()
        publish()
    }
    private func register() {
        let yielded = HotkeyManifest.claimedByOtherApp(keyCode: Int(combo.code), modifiers: Int(combo.modifiers), front: NSWorkspace.shared.frontmostApplication)
        if enabled && !yielded { registrationSucceeded = hotkeys.register(1, combo) == noErr }
        else { hotkeys.unregister(1); if !enabled { registrationSucceeded = true } }
    }
    /// Declares the hotkey to HotkeyHound (Shared/HotkeyManifest). `enabled` is the setting, not whether registration succeeded.
    private func publish() {
        HotkeyManifest.publish([HotkeyManifest.Item(id: "shortcut", title: L("選択したファイルのアイコンを書き出す"), keyCode: Int(combo.code), modifiers: Int(combo.modifiers), enabled: enabled)])
    }
}

#if !APP_STORE_BUILD
/// Reads the selection of the frontmost Finder or Path Finder with Apple Events (asks for Automation once).
enum FileBrowserSelection {
    enum Result { case notFileBrowser, files([URL]), denied, failed }
    private static let finder = "com.apple.finder"
    private static let pathFinders: Set<String> = ["com.cocoatech.PathFinder", "com.cocoatech.PathFinder-setapp"]

    static func selectedFiles() -> Result {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              bundleID == finder || pathFinders.contains(bundleID) else { return .notFileBrowser }
        // Finder items convert through alias; Path Finder's fsItem has its own POSIX path. Empty selection gives "".
        let item = bundleID == finder ? "POSIX path of (anItem as alias)" : "POSIX path of anItem"
        let source = """
        tell application id "\(bundleID)"
            set out to ""
            try
                repeat with anItem in (get selection)
                    set out to out & (\(item)) & linefeed
                end repeat
            end try
            return out
        end tell
        """
        var error: NSDictionary?
        guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
            // -1743: not allowed in Automation.
            return (error?[NSAppleScript.errorNumber] as? Int) == -1743 ? .denied : .failed
        }
        let paths = (output.stringValue ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return .files(paths.map { URL(fileURLWithPath: $0) })
    }
}
#endif
