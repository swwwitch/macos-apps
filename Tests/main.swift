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
try check(try dated(file("versioned-v5-20200101.txt")).lastPathComponent == "versioned-v5-20261005.txt", "keep version when updating date")
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
var selfCopyFailed = false
do { _ = try dated(dailyCopy) } catch { selfCopyFailed = true }
try check(selfCopyFailed, "already today does not overwrite itself")
let linkDaily = try file("date-link.txt")
let linkDestination = root.appendingPathComponent("date-link-20261005.txt")
try fm.createSymbolicLink(atPath: linkDestination.path, withDestinationPath: "/nonexistent-date-test")
var linkDateFailed = false
do { _ = try dated(linkDaily) } catch { linkDateFailed = true }
try check(linkDateFailed, "dated dangling symlink not overwritten")
let newYear = ISO8601DateFormatter().date(from: "2026-12-31T16:00:00Z")!
try check(try Duplicator.duplicateDated(file("year.txt"), date: newYear, timeZone: jst).lastPathComponent == "year-20270101.txt", "calendar year and local year boundary")
func edited(_ source: URL) throws -> URL {
    try Duplicator.duplicateDated(source, edited: true, date: fixedDate, timeZone: jst)
}
let editSource = try file("edit.txt")
let editCopy = try edited(editSource)
try check(editCopy.lastPathComponent == "edit-edited-20261005.txt", "edited suffix")
try check(try Data(contentsOf: editSource) == Data(contentsOf: editCopy), "edited copy bytes and original")
try check(try edited(file("oldedit-20200101.txt")).lastPathComponent == "oldedit-edited-20261005.txt", "edited replaces date")
try check(try edited(file("marked-edited-20200101.txt")).lastPathComponent == "marked-edited-20261005.txt", "edited does not repeat marker")
try check(try edited(file("noextension")).lastPathComponent == "noextension-edited-20261005", "edited no extension")
try check(try edited(file(".hidden")).lastPathComponent == ".hidden-edited-20261005", "edited dotfile")
try check(try edited(file("日本語-v3.txt")).lastPathComponent == "日本語-v3-edited-20261005.txt", "edited preserves version")
var editCollision = false
do { _ = try edited(editSource) } catch { editCollision = true }
try check(editCollision, "edited collision")
try check(try Data(contentsOf: editCopy) == Data(contentsOf: editSource), "edited collision preserves bytes")
let editedFolder = try edited(datedFolder)
try check(editedFolder.lastPathComponent == "folder.name-edited-20261005", "edited folder")
try check(try String(contentsOf: editedFolder.appendingPathComponent("child.txt"), encoding: .utf8) == "child", "edited folder contents")
try check(try dated(file("short-261001.txt")).lastPathComponent == "short-20261005.txt", "six digit date normalized to today's eight digits")
try check(try edited(file("shortedit-261001.txt")).lastPathComponent == "shortedit-edited-20261005.txt", "edited six digit date")
try check(try edited(file("shortmarked-edited-261001.txt")).lastPathComponent == "shortmarked-edited-20261005.txt", "edited six digit marker does not repeat")
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
prefs.set(Data("invalid".utf8), forKey: "keyboardShortcuts")
try check(Shortcut.load(defaults: prefs) == Shortcut.defaults, "invalid saved shortcut fallback")
let plainKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6)!
try check(Shortcut.capture(plainKey) == nil, "plain typing cannot become shortcut")
let customKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.control, .option], timestamp: 0, windowNumber: 0, context: nil, characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6)!
try check(Shortcut.capture(customKey) == changedShortcuts[1], "capture alternate key and modifier combination")
print("PASS: \(checks) checks")
