import Foundation

@main struct ExcludedAppsTests {
    static func main() {
        let suite = "ExcludedAppsTests-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var list = ExcludedAppList(ownID: "jp.local.TextPalette", defaults: defaults)
        precondition(list.ids.isEmpty)
        precondition(list.add("com.apple.Terminal") == .added)
        precondition(list.add("com.apple.Terminal") == .duplicate)
        precondition(list.add("COM.APPLE.terminal") == .duplicate) // Bundle IDs are case-insensitive
        precondition(list.add("jp.local.TextPalette") == .own)
        precondition(list.add(nil) == .invalid && list.add("  ") == .invalid)
        precondition(list.add("com.adobe.illustrator") == .added)
        precondition(list.ids == ["com.apple.Terminal", "com.adobe.illustrator"])
        list.save(defaults)
        var restored = ExcludedAppList(ownID: "jp.local.TextPalette", defaults: defaults) // relaunch
        precondition(restored.ids == list.ids)
        precondition(defaults.stringArray(forKey: ExcludedAppList.key) == list.ids)
        // Front-app decision: excluded or self releases hotkeys; others and unknown keep them.
        precondition(restored.blocksHotkeys(bundleID: "com.apple.Terminal", pid: 20, ownPID: 10))
        precondition(restored.blocksHotkeys(bundleID: "jp.local.TextPalette", pid: 20, ownPID: 10))
        precondition(restored.blocksHotkeys(bundleID: nil, pid: 10, ownPID: 10))
        precondition(!restored.blocksHotkeys(bundleID: "com.apple.TextEdit", pid: 20, ownPID: 10))
        precondition(!restored.blocksHotkeys(bundleID: nil, pid: nil, ownPID: 10))
        precondition(restored.excludes("com.adobe.illustrator") && !restored.excludes("jp.local.TextPalette") && !restored.excludes(nil))
        restored.remove("com.apple.terminal")
        restored.save(defaults)
        let afterRemove = ExcludedAppList(ownID: "jp.local.TextPalette", defaults: defaults)
        precondition(afterRemove.ids == ["com.adobe.illustrator"])
        precondition(!afterRemove.blocksHotkeys(bundleID: "com.apple.Terminal", pid: 20, ownPID: 10))
        print("Passed duplicate/self rejection, persistence round-trip, removal and front-app exclusion decisions")
    }
}
