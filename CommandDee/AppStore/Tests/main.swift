import Foundation
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let source = root.appendingPathComponent("Document.txt")
try Data("original".utf8).write(to: source)
let existing = try Duplicator.versionDestination(source).url
try Data("keep".utf8).write(to: existing)
let output = try StoreFileOperations.renameVersion(source)
precondition(output != source && output != existing)
precondition(!FileManager.default.fileExists(atPath: source.path))
let outputText = try String(contentsOf: output)
precondition(outputText == "original")
let existingText = try String(contentsOf: existing)
precondition(existingText == "keep")
do { _ = try StoreFileOperations.renameVersion(source); fatalError("missing source accepted") } catch {}
print("PASS: Store version rename keeps content, skips existing versions, preserves existing file and reports a missing source")
