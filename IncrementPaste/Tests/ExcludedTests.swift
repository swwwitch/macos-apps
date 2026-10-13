import Foundation

@main
struct ExcludedTests {
    static func main() {
        let defaults = UserDefaults(suiteName: "incrementpaste.tests")!
        defaults.removePersistentDomain(forName: "incrementpaste.tests")
        var list = ExcludedAppList(ownID: "jp.dtp-transit.incrementpaste", defaults: defaults)
        precondition(list.ids == ExcludedAppList.initial)
        precondition(list.excludes("COM.ADOBE.ILLUSTRATOR"))
        precondition(list.add("com.apple.TextEdit") == .added)
        precondition(list.add("com.apple.textedit") == .duplicate)
        precondition(list.add("jp.dtp-transit.incrementpaste") == .own)
        precondition(list.add(" ") == .invalid)
        list.remove("com.adobe.illustrator")
        list.save(defaults)
        let reloaded = ExcludedAppList(ownID: nil, defaults: defaults)
        precondition(!reloaded.excludes("com.adobe.illustrator") && reloaded.excludes("com.apple.TextEdit"))
        // An emptied list stays empty (the defaults are not restored).
        var empty = reloaded; reloaded.ids.forEach { empty.remove($0) }; empty.save(defaults)
        precondition(ExcludedAppList(ownID: nil, defaults: defaults).ids.isEmpty)
        precondition(reloaded.blocksHotkeys(bundleID: "x", pid: 5, ownPID: 5))
        precondition(!reloaded.blocksHotkeys(bundleID: nil, pid: nil, ownPID: 5))
        defaults.removePersistentDomain(forName: "incrementpaste.tests")
        print("PASS: excluded apps: KM defaults, case-insensitive, duplicate/own/invalid, save, empty list kept, own app blocks")
    }
}
