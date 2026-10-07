import Foundation

@main struct MoveTests {
 static func main() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("FolderMover-tests-\(UUID().uuidString)")
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    let source = root.appendingPathComponent("source"), target = root.appendingPathComponent("target")
    try fm.createDirectory(at: source, withIntermediateDirectories: true)
    try fm.createDirectory(at: target, withIntermediateDirectories: true)
    func file(_ name: String, in folder: URL, text: String = "original") throws -> URL {
        let url = folder.appendingPathComponent(name); try Data(text.utf8).write(to: url); return url
    }
    func blocked(_ items: [URL], _ destination: URL) throws {
        do { _ = try MoveEngine.plan(items, into: destination); fatalError("Expected preflight to reject move") }
        catch is MoveFailure { }
    }
    let a = try file("日本語 \"quote\"\nfile.txt", in: source)
    precondition(MoveEngine.destinationDisabledReason([a], into: source) != nil)
    precondition(MoveEngine.destinationDisabledReason([a], into: target) == nil)
    precondition(MoveEngine.destinationDisabledReason([], into: target) != nil)
    let sourceAlias = root.appendingPathComponent("source-alias")
    try fm.createSymbolicLink(at: sourceAlias, withDestinationURL: source)
    precondition(MoveEngine.destinationDisabledReason([a], into: sourceAlias) != nil)
    let plan = try MoveEngine.plan([a], into: target)
    let moved = MoveEngine.execute(plan)
    precondition(moved.error == nil && moved.done.count == 1)
    precondition(!fm.fileExists(atPath: a.path))
    let movedText = try String(contentsOf: plan[0].to, encoding: .utf8); precondition(movedText == "original")
    try fm.moveItem(at: plan[0].to, to: a) // Reset fixture.
    let conflict = try file(a.lastPathComponent, in: target, text: "do not overwrite")
    try blocked([a], target)
    let conflictText = try String(contentsOf: conflict, encoding: .utf8); precondition(conflictText == "do not overwrite")
    // Renaming preserves the extension.
    let renamedPlan = try MoveEngine.plan([a], into: target, renameConflicts: true)
    precondition(renamedPlan[0].to.lastPathComponent == a.deletingPathExtension().lastPathComponent + " 2.txt")
    let renamedMove = MoveEngine.execute(renamedPlan)
    precondition(renamedMove.error == nil)
    precondition(fm.fileExists(atPath: renamedPlan[0].to.path))
    try fm.moveItem(at: renamedPlan[0].to, to: a) // Reset fixture.
    // A batch reserves distinct output names and skips existing numbered files.
    let otherSource = root.appendingPathComponent("other")
    try fm.createDirectory(at: otherSource, withIntermediateDirectories: true)
    let first = try file("same.ai", in: source)
    let second = try file("same.ai", in: otherSource)
    _ = try file("same.ai", in: target)
    _ = try file("same 2.ai", in: target)
    let batch = try MoveEngine.plan([first, second], into: target, renameConflicts: true)
    precondition(batch.map { $0.to.lastPathComponent } == ["same 3.ai", "same 4.ai"])
    let batchMove = MoveEngine.execute(batch)
    precondition(batchMove.error == nil && batchMove.done.count == 2)
    precondition(!fm.fileExists(atPath: first.path) && !fm.fileExists(atPath: second.path))
    let dottedFolder = source.appendingPathComponent("project.v2")
    try fm.createDirectory(at: dottedFolder, withIntermediateDirectories: true)
    try fm.createDirectory(at: target.appendingPathComponent("project.v2"), withIntermediateDirectories: true)
    let folderPlan = try MoveEngine.plan([dottedFolder], into: target, renameConflicts: true)
    precondition(folderPlan[0].to.lastPathComponent == "project.v2 2")
    try blocked([], target)
    try blocked([a], source)
    try blocked([a, a], root)
    try blocked([source], source)
    try blocked([source], source.appendingPathComponent("child"))
    try blocked([source, a], target)
    // A collision introduced after planning must not overwrite the other file.
    let b = try file("race.txt", in: source)
    let latePlan = try MoveEngine.plan([b], into: target)
    let lateCollision = try file("race.txt", in: target, text: "keep")
    let late = MoveEngine.execute(latePlan)
    precondition(late.error != nil && late.done.isEmpty && fm.fileExists(atPath: b.path))
    let lateText = try String(contentsOf: lateCollision, encoding: .utf8); precondition(lateText == "keep")
    // Move a symlink itself, not its target.
    let link = source.appendingPathComponent("link")
    try fm.createSymbolicLink(at: link, withDestinationURL: a)
    let linkMove = MoveEngine.execute(try MoveEngine.plan([link], into: target))
    precondition(linkMove.error == nil && fm.fileExists(atPath: a.path))
    let linkPath = try fm.destinationOfSymbolicLink(atPath: target.appendingPathComponent("link").path); precondition(linkPath == a.path)
    // Link creation leaves the original intact.
    let linkSource = try file("リンク元.ai", in: source, text: "keep original")
    let linkPlan = try MoveEngine.plan([linkSource], into: target)
    let createdLinks = MoveEngine.execute(linkPlan, asSymbolicLinks: true)
    precondition(createdLinks.error == nil && createdLinks.done[0].isSymbolicLink)
    let linkDestination = try fm.destinationOfSymbolicLink(atPath: linkPlan[0].to.path)
    precondition(linkDestination == linkSource.path && fm.fileExists(atPath: linkSource.path))
    let originalText = try String(contentsOf: linkSource); precondition(originalText == "keep original")
    let numberedLinkPlan = try MoveEngine.plan([linkSource], into: target, renameConflicts: true)
    let numberedLinks = MoveEngine.execute(numberedLinkPlan, asSymbolicLinks: true)
    precondition(numberedLinks.error == nil && numberedLinkPlan[0].to.lastPathComponent == "リンク元 2.ai")
    // Links into /Applications: an existing link of the same name is overwritten, not numbered.
    let newer = source.appendingPathComponent("newer", isDirectory: true)
    try fm.createDirectory(at: newer, withIntermediateDirectories: true)
    let newerSource = try file("リンク元.ai", in: newer, text: "newer")
    let replacePlan = try MoveEngine.plan([newerSource], into: target, renameConflicts: true, replaceSymbolicLinks: true)
    precondition(replacePlan[0].to.lastPathComponent == "リンク元.ai" && replacePlan[0].replacesLink == true)
    let replaced = MoveEngine.execute(replacePlan, asSymbolicLinks: true)
    let replacedDestination = try fm.destinationOfSymbolicLink(atPath: replacePlan[0].to.path)
    precondition(replaced.error == nil && replacedDestination == newerSource.path && fm.fileExists(atPath: linkSource.path))
    let leftovers = try fm.contentsOfDirectory(atPath: target.path)
    precondition(!leftovers.contains { $0.hasPrefix(".リンク元.ai.") })
    // A real file with the same name is never replaced; it still gets a numbered name.
    _ = try file("real.txt", in: target, text: "keep")
    let realSource = try file("real.txt", in: newer)
    let realPlan = try MoveEngine.plan([realSource], into: target, renameConflicts: true, replaceSymbolicLinks: true)
    precondition(realPlan[0].replacesLink == nil && realPlan[0].to.lastPathComponent == "real 2.txt")
    // Copy leaves the original unchanged and produces the same content.
    let copySource = try file("copy.txt", in: source, text: "copy content")
    let copyPlan = try MoveEngine.plan([copySource], into: target)
    let copied = MoveEngine.execute(copyPlan, asCopies: true)
    precondition(copied.error == nil && copied.done.count == 1 && fm.fileExists(atPath: copySource.path))
    let copyText = try String(contentsOf: copyPlan[0].to)
    precondition(copyText == "copy content")
    // A partial failure reports completed items and preserves remaining sources.
    let partialA = try file("partial-a.txt", in: source)
    let partialB = try file("partial-b.txt", in: source)
    let partialPlan = try MoveEngine.plan([partialA, partialB], into: target)
    _ = try file("partial-b.txt", in: target, text: "keep")
    let partial = MoveEngine.execute(partialPlan)
    precondition(partial.error != nil && partial.done.count == 1)
    precondition(!fm.fileExists(atPath: partialA.path) && fm.fileExists(atPath: partialB.path))
    print("PASS: move, copy, collisions, numbered names, symbolic links, link overwrite, partial failure")
 }
}
