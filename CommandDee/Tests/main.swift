import Foundation
import AppKit

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("CommandDee-tests-" + UUID().uuidString)
try fm.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: root) }
var checks = 0
func check(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
    guard try condition() else { fatalError(label) }
    checks += 1
}
func file(_ name: String) throws -> URL {
    let url = root.appendingPathComponent(name)
    try Data("original:\(name)".utf8).write(to: url)
    return url
}
let original = try file("aaa.txt")
let v2 = try Duplicator.duplicate(original)
try check(v2.lastPathComponent == "aaa-v2.txt", "v2")
let v3 = try Duplicator.duplicate(original)
try check(v3.lastPathComponent == "aaa-v3.txt", "collision")
try check(try Duplicator.duplicate(v2).lastPathComponent == "aaa-v4.txt", "versioned source collision")
try check(try Data(contentsOf: original) == Data(contentsOf: v2), "preserve original bytes")
try check(try Duplicator.duplicate(file("README")).lastPathComponent == "README-v2", "no extension")
try check(try Duplicator.duplicate(file(".env")).lastPathComponent == ".env-v2", "dotfile")
try check(try Duplicator.duplicate(file("日本語 資料.txt")).lastPathComponent == "日本語 資料-v2.txt", "unicode")
try check(try Duplicator.duplicate(file("foo-v9.txt")).lastPathComponent == "foo-v10.txt", "two digits")
let folder = root.appendingPathComponent("folder.name")
try fm.createDirectory(at: folder, withIntermediateDirectories: true)
try Data("nested".utf8).write(to: folder.appendingPathComponent("nested.txt"))
let folderCopy = try Duplicator.duplicate(folder)
try check(folderCopy.lastPathComponent == "folder.name-v2", "folder with dot")
try check(try String(contentsOf: folderCopy.appendingPathComponent("nested.txt"), encoding: .utf8) == "nested", "recursive copy")
let linkSource = try file("link.txt")
try fm.createSymbolicLink(atPath: root.appendingPathComponent("link-v2.txt").path, withDestinationPath: "/nonexistent-commanddee-test")
try check(try Duplicator.duplicate(linkSource).lastPathComponent == "link-v3.txt", "dangling collision")
try check(try fm.destinationOfSymbolicLink(atPath: root.appendingPathComponent("link-v2.txt").path) == "/nonexistent-commanddee-test", "keep symlink")
var missingFailed = false
do { _ = try Duplicator.duplicate(root.appendingPathComponent("missing.txt")) } catch { missingFailed = true }
try check(missingFailed, "missing file error")
let gap = try file("gap.txt")
_ = try file("gap-v2.txt")
_ = try file("gap-v9.txt")
_ = try file("gap-v20.txt")
_ = try file("gap-v999.png")
_ = try file("gap-other-v888.txt")
_ = try file("gap-v777-extra.txt")
try check(try Duplicator.duplicate(gap).lastPathComponent == "gap-v21.txt", "maximum numeric version, ignoring gaps and unrelated names")
try check(try Duplicator.duplicate(root.appendingPathComponent("gap-v2.txt")).lastPathComponent == "gap-v22.txt", "older version uses directory maximum")
let onlyHigh = try file("only.txt")
_ = try file("only-v8.txt")
try check(try Duplicator.duplicate(onlyHigh).lastPathComponent == "only-v9.txt", "missing v2 stays missing")
_ = try file("special[1]-v7.txt")
try check(try Duplicator.duplicate(file("special[1].txt")).lastPathComponent == "special[1]-v8.txt", "literal regex characters")
try fm.createDirectory(at: root.appendingPathComponent("folder.name-v10"), withIntermediateDirectories: true)
try check(try Duplicator.duplicate(folder).lastPathComponent == "folder.name-v11", "folder maximum")
try check(try Duplicator.duplicate(file("first-v1.txt")).lastPathComponent == "first-v2.txt", "v1 source")
_ = try file("huge-v999999999999999999999999999999.txt")
var overflowFailed = false
do { _ = try Duplicator.duplicate(file("huge.txt")) } catch { overflowFailed = true }
try check(overflowFailed, "oversized version fails safely instead of filling gaps")
let jst = TimeZone(identifier: "Asia/Tokyo")!
let trace = try file("線パネルのトレース-v3-edited-20261006.ai")
let traceCopy = try Duplicator.duplicate(trace)
try check(traceCopy.lastPathComponent == "線パネルのトレース-edited-20261006-v4.ai", "increment version before edited date")
try check(try Data(contentsOf: traceCopy) == Data(contentsOf: trace), "edited version copy preserves bytes")
_ = try file("線パネルのトレース-v9-edited-20261006.ai")
_ = try file("線パネルのトレース-v99-edited-20261005.ai")
try check(try Duplicator.duplicate(trace).lastPathComponent == "線パネルのトレース-edited-20261006-v10.ai", "edited version ignores gaps and different dates")
try check(try Duplicator.duplicate(file("draft-v3-20261006.ai")).lastPathComponent == "draft-20261006-v4.ai", "version before date only")
try check(try Duplicator.duplicate(file("draft-v3-edited-261006.ai")).lastPathComponent == "draft-edited-261006-v4.ai", "six digit date preserved")
try check(try Duplicator.duplicate(file("draft-v3-edited.ai")).lastPathComponent == "draft-edited-v4.ai", "edited marker without date")
try check(try Duplicator.duplicate(file("new-edited-20261006.ai")).lastPathComponent == "new-edited-20261006-v2.ai", "insert first version before metadata")
try check(try Duplicator.duplicate(file("middle-v3-notes.ai")).lastPathComponent == "middle-v3-notes-v2.ai", "unrecognized suffix remains literal")
let versionedEditedFolder = root.appendingPathComponent("folder-v3-edited-20261006")
try fm.createDirectory(at: versionedEditedFolder, withIntermediateDirectories: true)
try Data("nested".utf8).write(to: versionedEditedFolder.appendingPathComponent("child.txt"))
let versionedEditedFolderCopy = try Duplicator.duplicate(versionedEditedFolder)
try check(versionedEditedFolderCopy.lastPathComponent == "folder-edited-20261006-v4", "folder metadata preserved")
try check(try Data(contentsOf: versionedEditedFolderCopy.appendingPathComponent("child.txt")) == Data("nested".utf8), "folder version retains contents")
let fixedDate = ISO8601DateFormatter().date(from: "2026-10-04T16:00:00Z")!
func dated(_ source: URL) throws -> URL {
    try Duplicator.duplicateDated(source, date: fixedDate, timeZone: jst)
}
let daily = try file("daily.txt")
let dailyCopy = try dated(daily)
try check(dailyCopy.lastPathComponent == "daily-20261005.txt", "date uses local day, not UTC")
try check(try Data(contentsOf: daily) == Data(contentsOf: dailyCopy), "date copy preserves contents")
let oldDaily = try file("older-20200101.txt")
try check(try dated(oldDaily).lastPathComponent == "older-20261005.txt", "replace trailing date")
try check(fm.fileExists(atPath: oldDaily.path), "dated original retained")
try check(try dated(file("datedREADME")).lastPathComponent == "datedREADME-20261005", "date without extension")
try check(try dated(file(".dailyenv")).lastPathComponent == ".dailyenv-20261005", "date dotfile")
try check(try dated(file("途中-20200101-資料.txt")).lastPathComponent == "途中-20200101-資料-20261005.txt", "only trailing date changes")
try check(try dated(file("versioned-v5-20200101.txt")).lastPathComponent == "versioned-20261005-v5.txt", "keep version when updating date")
let datedFolder = root.appendingPathComponent("folder.name-20200101")
try fm.createDirectory(at: datedFolder, withIntermediateDirectories: true)
try Data("child".utf8).write(to: datedFolder.appendingPathComponent("child.txt"))
let datedFolderCopy = try dated(datedFolder)
try check(datedFolderCopy.lastPathComponent == "folder.name-20261005", "folder date replacement")
try check(try String(contentsOf: datedFolderCopy.appendingPathComponent("child.txt"), encoding: .utf8) == "child", "dated folder contents")
var dateCollisionFailed = false
do { _ = try dated(daily) } catch { dateCollisionFailed = true }
try check(dateCollisionFailed, "same date collision fails")
try check(try Data(contentsOf: dailyCopy) == Data(contentsOf: daily), "date collision keeps existing bytes")
try check(try dated(dailyCopy) == dailyCopy, "already today skips without error")
let linkDaily = try file("date-link.txt")
let linkDestination = root.appendingPathComponent("date-link-20261005.txt")
try fm.createSymbolicLink(atPath: linkDestination.path, withDestinationPath: "/nonexistent-date-test")
var linkDateFailed = false
do { _ = try dated(linkDaily) } catch { linkDateFailed = true }
try check(linkDateFailed, "dated dangling symlink not overwritten")
let newYear = ISO8601DateFormatter().date(from: "2026-12-31T16:00:00Z")!
try check(try Duplicator.duplicateDated(file("year.txt"), date: newYear, timeZone: jst).lastPathComponent == "year-20270101.txt", "calendar year and local year boundary")
func edited(_ source: URL) throws -> URL {
    try Duplicator.duplicateEdited(source)
}
let editSource = try file("edit.txt")
let editCopy = try edited(editSource)
try check(editCopy.lastPathComponent == "edit-edited.txt", "edited suffix without date")
try check(try Data(contentsOf: editSource) == Data(contentsOf: editCopy), "edited copy bytes and original")
try check(try edited(file("oldedit-20200101.txt")).lastPathComponent == "oldedit-edited-20200101.txt", "edited keeps the date")
try check(try edited(file("marked-edited-20200101.txt")).lastPathComponent == "marked-edited-20200101.txt", "already edited is skipped")
try check(try edited(file("noextension")).lastPathComponent == "noextension-edited", "edited no extension")
try check(try edited(file(".hidden")).lastPathComponent == ".hidden-edited", "edited dotfile")
try check(try edited(file("日本語-v3.txt")).lastPathComponent == "日本語-edited-v3.txt", "edited preserves version")
var editCollision = false
do { _ = try edited(editSource) } catch { editCollision = true }
try check(editCollision, "edited collision")
try check(try Data(contentsOf: editCopy) == Data(contentsOf: editSource), "edited collision preserves bytes")
let editedFolder = try edited(datedFolder)
try check(editedFolder.lastPathComponent == "folder.name-edited-20200101", "edited folder keeps date")
try check(try String(contentsOf: editedFolder.appendingPathComponent("child.txt"), encoding: .utf8) == "child", "edited folder contents")
try check(try dated(file("short-261001.txt")).lastPathComponent == "short-20261005.txt", "six digit date normalized to today's eight digits")
try check(try edited(file("shortedit-261001.txt")).lastPathComponent == "shortedit-edited-261001.txt", "edited keeps six digit date")
try check(try edited(file("shortmarked-edited-261001.txt")).lastPathComponent == "shortmarked-edited-261001.txt", "edited six digit marker is skipped")
try check(try dated(file("shortREADME-261001")).lastPathComponent == "shortREADME-20261005", "six digit date without extension")
try check(try dated(file("middle-261001-notes.txt")).lastPathComponent == "middle-261001-notes-20261005.txt", "six digits only replaced at end")
try check(try dated(file("seven-1234567.txt")).lastPathComponent == "seven-1234567-20261005.txt", "seven digit suffix left unchanged")
let shortFolder = root.appendingPathComponent("short.folder-261001")
try fm.createDirectory(at: shortFolder, withIntermediateDirectories: true)
try check(try dated(shortFolder).lastPathComponent == "short.folder-20261005", "six digit folder date")
let shortCollisionSource = try file("short-260930.txt")
var shortCollision = false
do { _ = try dated(shortCollisionSource) } catch { shortCollision = true }
try check(shortCollision, "six digit normalized name collision protected")
let parentTestFolder = root.appendingPathComponent("親フォルダー [A].test")
try fm.createDirectory(at: parentTestFolder, withIntermediateDirectories: true)
func parentFile(_ name: String) throws -> URL {
    let url = parentTestFolder.appendingPathComponent(name)
    try Data("parent toggle".utf8).write(to: url)
    return url
}
let parentSource = try parentFile("sample.txt")
try check(try Duplicator.parentToggleDestination(parentSource).lastPathComponent == "sample-親フォルダー [A].test.txt", "parent name appended literally before extension")
let parentTagged = try parentFile("tagged-親フォルダー [A].test.txt")
try check(try Duplicator.parentToggleDestination(parentTagged).lastPathComponent == "tagged.txt", "parent name removed literally")
try check(try Duplicator.parentToggleDestination(parentFile("middle-親フォルダー [A].test-notes.txt")).lastPathComponent == "middle-親フォルダー [A].test-notes-親フォルダー [A].test.txt", "only trailing parent suffix toggled")
try check(try Duplicator.parentToggleDestination(parentFile("README")).lastPathComponent == "README-親フォルダー [A].test", "parent suffix on extensionless file")
try check(try Duplicator.parentToggleDestination(parentFile(".env")).lastPathComponent == ".env-親フォルダー [A].test", "parent suffix on dotfile")
let parentChildFolder = parentTestFolder.appendingPathComponent("folder.name")
try fm.createDirectory(at: parentChildFolder, withIntermediateDirectories: true)
try check(try Duplicator.parentToggleDestination(parentChildFolder).lastPathComponent == "folder.name-親フォルダー [A].test", "parent suffix on dotted folder")
var emptyToggleFailed = false
do { _ = try Duplicator.parentToggleDestination(parentFile("-親フォルダー [A].test.txt")) } catch { emptyToggleFailed = true }
try check(emptyToggleFailed, "empty resulting stem rejected")
try check(try Duplicator.parentToggleDestination(parentFile("README-親フォルダー [A].test")).lastPathComponent == "README", "remove dotted parent on extensionless file")
try check(try Duplicator.parentToggleDestination(parentFile(".env-親フォルダー [A].test")).lastPathComponent == ".env", "remove dotted parent on dotfile")
try check(try Duplicator.parentToggleDestination(parentSource, separator: "_").lastPathComponent == "sample_親フォルダー [A].test.txt", "underscore parent appended")
try check(try Duplicator.parentToggleDestination(parentFile("u_親フォルダー [A].test.txt"), separator: "-").lastPathComponent == "u.txt", "underscore parent removed with hyphen setting")
try check(try Duplicator.parentToggleDestination(parentTagged, separator: "_").lastPathComponent == "tagged.txt", "hyphen parent removed with underscore setting")
let originalID = try fm.attributesOfItem(atPath: parentSource.path)[.systemFileNumber] as! NSNumber
let renamedParent = try Duplicator.renameParentToggled(parentSource)
try check(!fm.fileExists(atPath: parentSource.path), "rename removes old path")
try check(try String(contentsOf: renamedParent, encoding: .utf8) == "parent toggle", "rename preserves bytes")
try check(try fm.attributesOfItem(atPath: renamedParent.path)[.systemFileNumber] as? NSNumber == originalID, "rename preserves file identity")
let restoredParent = try Duplicator.renameParentToggled(renamedParent)
try check(restoredParent == parentSource && !fm.fileExists(atPath: renamedParent.path), "second toggle restores original name without copies")
let blockedPath = try Duplicator.parentToggleDestination(parentSource)
try Data("existing destination".utf8).write(to: blockedPath)
var parentCollision = false
do { _ = try Duplicator.renameParentToggled(parentSource) } catch { parentCollision = true }
try check(parentCollision, "rename collision rejected")
try check(try String(contentsOf: parentSource, encoding: .utf8) == "parent toggle", "rename collision preserves source")
try check(try String(contentsOf: blockedPath, encoding: .utf8) == "existing destination", "rename collision preserves destination")
let linkRenameSource = try parentFile("symlink-collision.txt")
let linkRenameTarget = try Duplicator.parentToggleDestination(linkRenameSource)
try fm.createSymbolicLink(atPath: linkRenameTarget.path, withDestinationPath: "/nonexistent-parent-toggle")
var linkRenameFailed = false
do { _ = try Duplicator.renameParentToggled(linkRenameSource) } catch { linkRenameFailed = true }
try check(linkRenameFailed && fm.fileExists(atPath: linkRenameSource.path), "rename protects dangling target and source")
try Data("nested parent".utf8).write(to: parentChildFolder.appendingPathComponent("child.txt"))
let renamedParentFolder = try Duplicator.renameParentToggled(parentChildFolder)
try check(!fm.fileExists(atPath: parentChildFolder.path), "folder renamed not copied")
try check(try String(contentsOf: renamedParentFolder.appendingPathComponent("child.txt"), encoding: .utf8) == "nested parent", "folder rename retains contents")
try check(try Duplicator.renameParentToggled(renamedParentFolder) == parentChildFolder, "folder toggle round trip")
let project = root.appendingPathComponent("projectA")
let userFolder = project.appendingPathComponent("takano")
let repeatedUserFolder = userFolder.appendingPathComponent("takano")
try fm.createDirectory(at: repeatedUserFolder, withIntermediateDirectories: true)
func projectFile(_ folder: URL, _ name: String) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try Data("project content".utf8).write(to: url)
    return url
}
let directProject = try projectFile(project, "aaa.txt")
let nestedProject = try projectFile(userFolder, "aaa.txt")
try check(try Duplicator.parentToggleDestination(directProject, skipping: "takano").lastPathComponent == "aaa-projectA.txt", "direct parent not skipped")
try check(try Duplicator.parentToggleDestination(nestedProject, skipping: "takano") == userFolder.appendingPathComponent("aaa-projectA.txt"), "skip parent without moving file")
try check(try Duplicator.parentToggleDestination(projectFile(repeatedUserFolder, "deep.txt"), skipping: "takano").lastPathComponent == "deep-projectA.txt", "consecutive matching parents skipped")
try check(try Duplicator.parentToggleDestination(nestedProject, skipping: "").lastPathComponent == "aaa-takano.txt", "empty setting disables skip")
try check(try Duplicator.parentToggleDestination(nestedProject, skipping: "taka").lastPathComponent == "aaa-takano.txt", "exact match not substring")
let skippedRename = try Duplicator.renameParentToggled(nestedProject, skipping: "takano")
try check(skippedRename == userFolder.appendingPathComponent("aaa-projectA.txt") && !fm.fileExists(atPath: nestedProject.path), "rename in original directory with skipped ancestor")
try check(try Duplicator.renameParentToggled(skippedRename, skipping: "takano") == nestedProject, "skipped parent toggle restores original")
let childInUser = userFolder.appendingPathComponent("assets")
try fm.createDirectory(at: childInUser, withIntermediateDirectories: true)
try check(try Duplicator.renameParentToggled(childInUser, skipping: "takano").path == userFolder.appendingPathComponent("assets-projectA").path, "folder rename uses skipped ancestor")
let suiteName = "CommandDee.tests." + UUID().uuidString
let prefs = UserDefaults(suiteName: suiteName)!
defer { prefs.removePersistentDomain(forName: suiteName) }
try check(ParentFolderSettings.skippedName(defaults: prefs) == NSUserName(), "default is login username")
prefs.set("custom", forKey: ParentFolderSettings.key)
try check(ParentFolderSettings.skippedName(defaults: prefs) == "custom", "custom preference")
prefs.set("", forKey: ParentFolderSettings.key)
try check(ParentFolderSettings.skippedName(defaults: prefs).isEmpty, "explicit empty preference persists")
prefs.removeObject(forKey: ParentFolderSettings.key)
try check(ParentFolderSettings.skippedName(defaults: prefs) == NSUserName(), "reset to login username")
try check(Shortcut.load(defaults: prefs) == Shortcut.defaults, "shortcut defaults")
var changedShortcuts = Shortcut.defaults
changedShortcuts[1] = Shortcut(keyCode: 6, modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue, label: "⌃⌥Z")
Shortcut.save(changedShortcuts, defaults: prefs)
try check(Shortcut.load(defaults: prefs) == changedShortcuts, "custom shortcut round trip persistence")
prefs.set(Data("invalid".utf8), forKey: Shortcut.storageKey)
try check(Shortcut.load(defaults: prefs) == Shortcut.defaults, "invalid saved shortcut fallback")
let plainKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6)!
try check(Shortcut.capture(plainKey) == nil, "plain typing cannot become shortcut")
let customKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.control, .option], timestamp: 0, windowNumber: 0, context: nil, characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6)!
try check(Shortcut.capture(customKey) == changedShortcuts[1], "capture alternate key and modifier combination")

// All six orders read existing metadata in any order and retain version families.
for (index, order) in NamingSettings.orders.enumerated() {
    let base = "ordered\(index)"
    let source = try file(base + "-v3-edited-20261005.txt")
    let high = try file(base + "-20261005-v8-edited.txt")
    let tokens = ["version": "-v9", "edited": "-edited", "date": "-20261005"]
    let expected = base + order.map { tokens[$0]! }.joined() + ".txt"
    let output = try Duplicator.duplicate(source, order: order)
    try check(output.lastPathComponent == expected, "permutation version maximum")
    try check(fm.fileExists(atPath: high.path), "higher sibling retained")
    try check(try Duplicator.duplicateDated(source, date: fixedDate, timeZone: jst, order: order) == source, "today skips despite order change")
    let datedSource = try file(base + "fresh-20200101-edited-v4.txt")
    let dateTokens = ["version": "-v4", "edited": "-edited", "date": "-20261005"]
    try check(try Duplicator.duplicateDated(datedSource, date: fixedDate, timeZone: jst, order: order).lastPathComponent == base + "fresh" + order.map { dateTokens[$0]! }.joined() + ".txt", "date output order")
}
// Underscore separator: only "_" suffixes are read; "-" stays part of the base name.
let underscored = try file("under_v2_edited.txt")
try check(try Duplicator.duplicate(underscored, order: ["version", "edited", "date"], separator: "_").lastPathComponent == "under_v3_edited.txt", "underscore version")
try check(try Duplicator.duplicateDated(file("snap-v2.txt"), date: fixedDate, timeZone: jst, order: ["version", "date", "edited"], separator: "_").lastPathComponent == "snap-v2_20261005.txt", "underscore leaves hyphen tokens in base")
try check(try Duplicator.duplicateEdited(file("IMG_20200101.txt"), order: ["edited", "date", "version"], separator: "_").lastPathComponent == "IMG_edited_20200101.txt", "underscore reads date")
try check(try Duplicator.duplicateEdited(file("IMG_20200102.txt"), order: ["edited", "date", "version"]).lastPathComponent == "IMG_20200102-edited.txt", "hyphen keeps underscore date in base")
try check(NamingSettings.label(["version", "edited", "date"], separator: "_") == "_v4_edited_20261006", "underscore label")
let prefsSeparator = UserDefaults(suiteName: "CommandDeeSeparatorTests")!
prefsSeparator.removePersistentDomain(forName: "CommandDeeSeparatorTests")
try check(NamingSettings.separator(defaults: prefsSeparator) == "-", "separator default")
prefsSeparator.set("_", forKey: NamingSettings.separatorKey)
try check(NamingSettings.separator(defaults: prefsSeparator) == "_", "separator preference")
prefsSeparator.set(".", forKey: NamingSettings.separatorKey)
try check(NamingSettings.separator(defaults: prefsSeparator) == "-", "invalid separator fallback")
prefsSeparator.removePersistentDomain(forName: "CommandDeeSeparatorTests")
let crossOrder = try file("rename-v3-edited-20261005.txt")
_ = try file("rename-edited-20261005-v8.txt")
try check(try Duplicator.duplicate(crossOrder).lastPathComponent == "rename-edited-20261005-v9.txt", "version uses maximum across orders")
try check(fm.fileExists(atPath: crossOrder.path), "version duplicate keeps the original")
try check(try edited(editCopy) == editCopy, "today edited skips")
try check(try dated(file("today-short-261005.txt")).lastPathComponent == "today-short-261005.txt", "short today skips")
try check(try edited(file("today-new-marker-20261005.txt")).lastPathComponent == "today-new-marker-edited-20261005.txt", "today-dated item can get edited")
prefs.set(["date", "edited", "version"], forKey: NamingSettings.key)
try check(NamingSettings.order(defaults: prefs) == ["date", "edited", "version"], "order preference")
prefs.set(["date", "date", "version"], forKey: NamingSettings.key)
try check(NamingSettings.order(defaults: prefs) == NamingSettings.defaultOrder, "invalid order fallback")

let swapA = try file("DoSomething-v16.jsx")
let swapB = try file("DoSomething-.jsx")
let bytesA = try Data(contentsOf: swapA), bytesB = try Data(contentsOf: swapB)
let beforeA = try fm.attributesOfItem(atPath: swapA.path)
_ = try Duplicator.swapNames([swapA, swapB])
try check(try Data(contentsOf: swapA) == bytesB && Data(contentsOf: swapB) == bytesA, "swap content follows name exchange")
try check(try fm.attributesOfItem(atPath: swapB.path)[.systemFileNumber] as? NSNumber == beforeA[.systemFileNumber] as? NSNumber, "swap retains identity")
try check(try fm.attributesOfItem(atPath: swapB.path)[.modificationDate] as? Date == beforeA[.modificationDate] as? Date, "swap retains modification date")
_ = try Duplicator.swapNames([swapA, swapB])
try check(try Data(contentsOf: swapA) == bytesA, "repeat swap restores")
for invalid in [[swapA], [swapA, swapA], [swapA, swapB, original], [swapA, root.appendingPathComponent("missing")], [swapA, folder]] {
    var rejected = false
    do { _ = try Duplicator.swapNames(invalid) } catch { rejected = true }
    try check(rejected, "invalid swap rejected")
    try check(try Data(contentsOf: swapA) == bytesA && Data(contentsOf: swapB) == bytesB, "failed swap preserves both")
}
_ = try Duplicator.swapNames([folder, folderCopy])
try check(fm.fileExists(atPath: folder.appendingPathComponent("nested.txt").path), "swap folders")

// ⌃D: add the date to the item itself (no copy); ⌃⌘D: duplicate with the date.
let renameSource = try file("rename-me.txt")
let renamedDated = try Duplicator.duplicateDated(renameSource, rename: true, date: fixedDate, timeZone: jst)
try check(renamedDated.lastPathComponent == "rename-me-20261005.txt" && !fm.fileExists(atPath: renameSource.path), "date rename moves the item")
try check(try Duplicator.duplicateDated(renamedDated, rename: true, date: fixedDate, timeZone: jst) == renamedDated, "date rename skips today")
let renameBlocked = try file("blocked.txt"); _ = try file("blocked-20261005.txt")
var renameCollision = false
do { _ = try Duplicator.duplicateDated(renameBlocked, rename: true, date: fixedDate, timeZone: jst) } catch { renameCollision = true }
try check(renameCollision && fm.fileExists(atPath: renameBlocked.path), "date rename never replaces")

// Settings saved by 1.8.12 and earlier (version, date, edited, parent, renameVersion (removed), swapNames).
func legacyLoad(_ values: [Shortcut]) -> [Shortcut] {
    prefs.removeObject(forKey: Shortcut.storageKey)
    prefs.set(try! JSONEncoder().encode(values), forKey: Shortcut.legacyKey)
    return Shortcut.load(defaults: prefs)
}
try check(legacyLoad(Shortcut.legacyDefaults) == Shortcut.defaults, "old default layout moves to the new layout")
try check(Shortcut.load(defaults: prefs) == Shortcut.defaults, "migrated layout is saved")
var customLegacy = Shortcut.legacyDefaults
customLegacy[0] = Shortcut(keyCode: 2, modifiers: NSEvent.ModifierFlags.control.rawValue, label: "⌃D")   // version moved to ⌃D
customLegacy[5] = Shortcut(keyCode: 15, modifiers: NSEvent.ModifierFlags.control.rawValue, label: "⌃R")  // swap customized
let carried = legacyLoad(customLegacy)
try check(carried[0].label == "⌃D" && carried[5].label == "⌃R", "customized keys carry over")
// 1.8.13 saved 7 keys (連番だけ更新 at index 5); 1.8.14 drops that slot.
var sevenKeys = Shortcut.defaults; sevenKeys.insert(Shortcut.unset, at: 5)
prefs.set(try JSONEncoder().encode(sevenKeys), forKey: Shortcut.storageKey)
try check(Shortcut.load(defaults: prefs) == Shortcut.defaults, "1.8.13 seven-key settings drop the removed action")
// Stored former defaults ⌃P (parent) and ⌃S (swap) move to ⌃F / ⌃⌘S unless that key is taken.
var formerDefaults = Shortcut.defaults
formerDefaults[4] = Shortcut(keyCode: 35, modifiers: NSEvent.ModifierFlags.control.rawValue, label: "⌃P")
formerDefaults[5] = Shortcut(keyCode: 1, modifiers: NSEvent.ModifierFlags.control.rawValue, label: "⌃S")
prefs.set(try JSONEncoder().encode(formerDefaults), forKey: Shortcut.storageKey)
try check(Shortcut.load(defaults: prefs) == Shortcut.defaults, "former ⌃P / ⌃S defaults move to ⌃F / ⌃⌘S")
var takenSwap = formerDefaults; takenSwap[0] = Shortcut.defaults[5]
prefs.set(try JSONEncoder().encode(takenSwap), forKey: Shortcut.storageKey)
try check(Shortcut.load(defaults: prefs)[5] == formerDefaults[5], "⌃S stays when ⌃⌘S is assigned elsewhere")
try check(carried[1].keyCode == UInt16.max, "new ⌃D rename starts unset when a custom key holds ⌃D")
try check(carried[2] == Shortcut.defaults[2] && carried[4] == Shortcut.defaults[4], "untouched keys take the new layout")
try check(legacyLoad(Array(Shortcut.legacyDefaults.prefix(4))) == Shortcut.defaults, "four-key settings migrate")

print("PASS: \(checks) checks")
