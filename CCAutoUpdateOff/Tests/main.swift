import Foundation

var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition { print("ok   " + label) } else { failures += 1; print("FAIL " + label) }
}

let fm = FileManager.default
let base = fm.temporaryDirectory.appendingPathComponent("CCAutoUpdateOffTests-\(UUID().uuidString)", isDirectory: true)
try! fm.createDirectory(at: base, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: base) }

func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
}
/// Same shape as a real com.adobe.accc.apps.<user>.prefs (Creative Cloud 6.x).
func section(global: String?, _ apps: [(String, String?)]) -> String {
    "<autoUpdatePreferences>" + (global.map { "<autoUpdateEnabled>\($0)</autoUpdateEnabled>" } ?? "")
        + "<autoUpdateDialogShown>false</autoUpdateDialogShown><clientVersionsOnboarded/><enableAutoUpdateFreshUser>true</enableAutoUpdateFreshUser>"
        + apps.map { "<app><sapcode>\($0.0)</sapcode>" + ($0.1.map { "<autoUpdatePreference>\($0)</autoUpdatePreference>" } ?? "") + "<migrateAppPrefs>true</migrateAppPrefs></app>" }.joined()
        + "</autoUpdatePreferences>"
}
func inner(_ section: String) -> String {
    "<?xml version=\"1.0\"?><ccmPreferences><globalPref><ccmVersion/></globalPref><prodPref><products><product sapVersion=\"ILST_30.8\" seenUpdate=\"true\"/></products>"
        + section + "</prodPref></ccmPreferences>"
}
func outer(_ inner: String) -> String {
    "<?xml version=\"1.0\"?>\n<prefs>\n\t<property key=\"Apps_Panel_Pref\">" + escape(inner) + "</property>\n\t<property key=\"apps2Layout\">full-view</property>\n</prefs>\n"
}
func state(_ sections: [String]) -> CCState {
    let folder = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! fm.createDirectory(at: folder, withIntermediateDirectories: true)
    for (i, s) in sections.enumerated() {
        try! outer(inner(s)).write(to: folder.appendingPathComponent("com.adobe.accc.apps.U\(i).prefs"), atomically: true, encoding: .utf8)
    }
    return CCAutoUpdate.read(files: CCAutoUpdate.prefsFiles(in: folder))
}

// Parsing.
let sample = inner(section(global: nil, [("ACR", nil), ("IDSN", "false"), ("ILST", "true")]))
check(CCAutoUpdate.innerXML(outer(sample)) == sample, "inner XML extracted")
let parsed = CCAutoUpdate.parse(sample)
check(parsed?.global == .some(nil), "global missing = default")
check(parsed?.apps.map(\.0) == ["ACR", "IDSN", "ILST"], "apps in file order")
check(parsed?.removeOldDefault == false && parsed?.apps.allSatisfy { $0.2 == nil } == true, "removeOld missing")
check(parsed?.apps[0].1 == nil && parsed?.apps[1].1 == false && parsed?.apps[2].1 == true, "app values")
check(CCAutoUpdate.parse("<ccmPreferences><prodPref><app>") == nil, "broken XML rejected")
check(CCAutoUpdate.parse(inner(""))?.apps.isEmpty == true, "no section = nothing set")

// Levels (the four cases seen in Creative Cloud).
check(state([section(global: "false", [("ILST", "true")])]).level == .off, "global off → off")
check(state([section(global: "true", [("ILST", "false"), ("IDSN", "false")])]).level == .caution, "global on, apps off → caution")
check(state([section(global: "true", [])]).level == .caution, "global on, no apps → caution")
let onState = state([section(global: "true", [("ILST", "false"), ("PHSP", "true"), ("ACR", nil)])])
check(onState.level == .on, "global on + app on → on")
check(onState.appsOn.map(\.sapCode) == ["ACR", "PHSP"], "missing app value = on (as Creative Cloud shows it), sorted by name")
let fresh = state([section(global: nil, [("ACR", nil), ("PHSP", nil)])])
check(state([section(global: nil, [("ACR", nil)])]).level == .on, "fresh user (nothing set) → on")
check(state([]).level == .unknown, "no file → unknown")

// Several signed-in users: off only when off everywhere.
let merged = state([section(global: "false", [("ILST", "false")]), section(global: "true", [("ILST", "true")])])
check(merged.global == true && merged.level == .on, "merged: one user on")
check(state([section(global: "false", [("ILST", "false")]), section(global: "false", [("ILST", "false")])]).level == .off, "merged: all off")
let folder = base.appendingPathComponent("broken", isDirectory: true)
try! fm.createDirectory(at: folder, withIntermediateDirectories: true)
try! "<prefs><property key=\"Apps_Panel_Pref\">garbage</property></prefs>".write(to: folder.appendingPathComponent("com.adobe.accc.apps.X.prefs"), atomically: true, encoding: .utf8)
try! "<prefs/>".write(to: folder.appendingPathComponent("com.adobe.accc.apps.default.prefs"), atomically: true, encoding: .utf8)
let broken = CCAutoUpdate.read(files: CCAutoUpdate.prefsFiles(in: folder))
check(broken.files.count == 1 && broken.invalid.count == 1 && broken.level == .unknown, "broken file → unknown, default.prefs ignored")

// Messages and daily mail.
check(CCAutoUpdate.appList(fresh, separator: "、") == "Camera Raw、Photoshop", "app list")
check(CCAutoUpdate.signature(onState) == "ACR,PHSP" && CCAutoUpdate.signature(merged) == "ILST", "signature")
var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 8))!
let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 23, minute: 59))!
let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 0, minute: 1))!
check(CCAutoUpdate.mailDue(onState, lastSent: nil, now: morning, calendar: calendar), "first mail due")
check(!CCAutoUpdate.mailDue(onState, lastSent: morning, now: night, calendar: calendar), "same day not again")
check(CCAutoUpdate.mailDue(onState, lastSent: night, now: tomorrow, calendar: calendar), "next day due")
let nine = 9 * 60
let earlyToday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 7))!
let afterNine = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 9, minute: 5))!
check(!CCAutoUpdate.mailDue(onState, lastSent: nil, minutes: nine, now: morning, calendar: calendar), "before send time → not yet")
check(CCAutoUpdate.mailDue(onState, lastSent: nil, minutes: nine, now: afterNine, calendar: calendar), "after send time → due")
check(CCAutoUpdate.mailDue(onState, lastSent: earlyToday, minutes: nine, now: afterNine, calendar: calendar), "sent before today's time → due again")
check(!CCAutoUpdate.mailDue(onState, lastSent: afterNine, minutes: nine, now: night, calendar: calendar), "sent after today's time → not again")
check(!CCAutoUpdate.mailDue(onState, lastSent: afterNine, minutes: nine, now: tomorrow, calendar: calendar), "next day before time → not yet")
check(CCAutoUpdate.nextMailSlot(minutes: nine, after: morning, calendar: calendar) == calendar.date(bySettingHour: 9, minute: 0, second: 0, of: morning)!, "next slot today")
check(CCAutoUpdate.nextMailSlot(minutes: nine, after: afterNine, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9))!, "next slot tomorrow")
check(!CCAutoUpdate.mailDue(merged.level == .on ? state([section(global: "false", [])]) : merged, lastSent: nil, now: morning, calendar: calendar), "off → no mail")
check(CCAutoUpdate.appleScriptLiteral("a\"b\\c\nd") == "\"a\\\"b\\\\c\" & linefeed & \"d\"", "AppleScript literal")
let script = CCAutoUpdate.mailScript(to: "me@example.com", subject: "件名", body: "1行目\n2行目")
check(script.contains("{address:\"me@example.com\"}") && script.contains("\"1行目\" & linefeed & \"2行目\"") && script.contains("send newMessage"), "mail script")
check(NSAppleScript(source: script) != nil, "mail script compiles as source")
for (address, ok) in [("me@example.com", true), ("a.b+c@sub.example.jp", true), ("", false), ("me", false), ("me@host", false),
                      ("a@b@c.com", false), ("me@example.com, x@y.com", false), ("\"x\"@y.com", false), ("me@.com", false)] {
    check(CCAutoUpdate.isValidAddress(address) == ok, "address \(address.isEmpty ? "(empty)" : address) → \(ok)")
}

// 以前のバージョンを削除 (removeOlderVersions).
func withRemoveOld(_ s: String, _ code: String, _ value: String) -> String {
    s.replacingOccurrences(of: "<sapcode>\(code)</sapcode>", with: "<sapcode>\(code)</sapcode><removeOlderVersions>\(value)</removeOlderVersions>")
}
let offOld = state([withRemoveOld(section(global: "false", [("ACR", "true")]), "ACR", "true")])
check(offOld.appsRemovingOld.isEmpty && !CCAutoUpdate.alerting(offOld, watchRemoveOld: true), "removeOld ignored while global off")
let appOffOld = state([withRemoveOld(section(global: "true", [("ACR", "false")]), "ACR", "true")])
check(appOffOld.appsRemovingOld.isEmpty && !appOffOld.removeOldActive(appOffOld.apps[0]), "removeOld ignored while app auto-update off")
check(!offOld.autoUpdateActive(offOld.apps[0]) && appOffOld.autoUpdateActive(appOffOld.apps[0]), "per-app switch inactive while global off")
let oldState = state([withRemoveOld(withRemoveOld(section(global: "true", [("ACR", "true"), ("IDSN", "false"), ("ILST", "true")]), "ACR", "true"), "ILST", "false")])
check(oldState.level == .on && oldState.appsRemovingOld.map(\.sapCode) == ["ACR"], "removeOld counted while auto-updating")
check(CCAutoUpdate.alerting(oldState, watchRemoveOld: true), "removeOld alerts when watched")
check(CCAutoUpdate.signature(oldState, watchRemoveOld: true) == "ACR,ILST|old:ACR" && CCAutoUpdate.signature(oldState) == "ACR,ILST", "removeOld signature")
check(!CCAutoUpdate.mailDue(offOld, watchRemoveOld: true, lastSent: nil), "no removeOld mail while global off")
let defaultOld = state([section(global: "true", [("IDSN", "true")]).replacingOccurrences(of: "<autoUpdateDialogShown>", with: "<globalAURemoveOld>true</globalAURemoveOld><autoUpdateDialogShown>")])
check(defaultOld.appsRemovingOld.map(\.sapCode) == ["IDSN"], "missing removeOld follows globalAURemoveOld")
check(CCAutoUpdate.removeOldList(oldState, separator: "、") == "Camera Raw", "removeOld list")
check(CCAutoUpdate.signature(onState, watchRemoveOld: true) == "ACR,PHSP", "signature unchanged without removeOld")

print(failures == 0 ? "All tests passed" : "\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
