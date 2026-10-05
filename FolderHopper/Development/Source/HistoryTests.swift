import Foundation
@main struct HistoryTests {
 static func main() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("FileMover-history-tests-" + UUID().uuidString)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    let source = root.appendingPathComponent("source"), target = root.appendingPathComponent("target")
    for url in [source, target] { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
    let store = OperationHistory(url: root.appendingPathComponent("journal/operations.json"))
    let file = source.appendingPathComponent("test.txt")
    try Data("original".utf8).write(to: file)
    var records = [OperationRecord(destination: target, linking: false)]
    let moved = MoveEngine.execute(try MoveEngine.plan([file], into: target)) { pair in
        records[0].remaining.append(pair); records[0].total += 1; try store.write(records)
    }
    precondition(moved.error == nil && moved.done[0].identity != nil)
    // Fresh instance reloads the disk journal, as after application restart.
    var reloaded = try OperationHistory(url: store.url).read()
    precondition(reloaded[0].remaining.count == 1)
    let undone = MoveEngine.undo(reloaded[0].remaining) { pair in
        reloaded[0].remaining.removeAll { $0.to == pair.from }; try store.write(reloaded)
    }
    precondition(undone.error == nil && fm.fileExists(atPath: file.path))
    let empty = try store.read(); precondition(empty[0].remaining.isEmpty)
    let again = MoveEngine.execute(try MoveEngine.plan([file], into: target))
    let movedURL = again.done[0].to
    try fm.moveItem(at: movedURL, to: target.appendingPathComponent("kept-original.txt"))
    try Data("replacement".utf8).write(to: movedURL)
    precondition(MoveEngine.undo(again.done).error != nil)
    let replacement = try String(contentsOf: movedURL, encoding: .utf8); precondition(replacement == "replacement")
    precondition(MoveEngine.availabilityReason(root.appendingPathComponent("missing")) != nil)
    precondition(MoveEngine.availabilityReason(URL(fileURLWithPath: "/Volumes/FileMoverMissing-" + UUID().uuidString + "/folder"))?.contains("未接続") == true)
    let copySource = source.appendingPathComponent("FileMover-copy-test-" + UUID().uuidString + ".txt")
    try Data("copy original".utf8).write(to: copySource)
    let copyResult = MoveEngine.execute(try MoveEngine.plan([copySource], into: target), asCopies: true)
    precondition(copyResult.error == nil && fm.fileExists(atPath: copySource.path))
    let copyText = try String(contentsOf: copyResult.done[0].to, encoding: .utf8)
    precondition(copyText == "copy original")
    var copyRecord = OperationRecord(destination: target, linking: false, copying: true)
    copyRecord.remaining = copyResult.done; copyRecord.total = 1
    try store.write([copyRecord])
    let savedCopies = try store.read()
    precondition(savedCopies[0].copying == true && savedCopies[0].remaining[0].isCopy == true)
    let copyUndo = MoveEngine.undo(savedCopies[0].remaining)
    if let error = copyUndo.error { throw error }
    precondition(copyUndo.done.count == 1 && fm.fileExists(atPath: copySource.path) && !fm.fileExists(atPath: copyResult.done[0].to.path))
    // Older operation JSON omitted copy flags and must remain readable.
    let legacy = "[{\"id\":\"old\",\"date\":0,\"destination\":\"file:///tmp/\",\"linking\":false,\"remaining\":[{\"from\":\"file:///tmp/a\",\"to\":\"file:///tmp/b\",\"isSymbolicLink\":false}],\"total\":1}]"
    let oldRecords = try JSONDecoder().decode([OperationRecord].self, from: Data(legacy.utf8))
    precondition(oldRecords[0].copying == nil && oldRecords[0].remaining[0].isCopy == nil)
    print("PASS: copy preserves source, persisted copy flags, copy undo to Trash, old history compatibility")
    try Data("corrupt".utf8).write(to: store.url)
    do { _ = try store.read(); fatalError("Corrupt history must not be silently replaced") } catch { }
    print("PASS: persistent history, restart undo, checkpoint updates, replacement protection, unavailable destinations, corrupt history")
 }
}
