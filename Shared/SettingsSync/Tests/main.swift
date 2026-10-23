import Foundation
func check(_ condition: Bool, _ name: String) { precondition(condition, name) }
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let app = "test.app"
let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
let initial: NSDictionary = ["one": 1, "two": 2, "list": ["a", "b"]]
let first = try SettingsSyncJournal.synchronize(directory: a, app: app, device: "A", baseline: initial, current: initial, seed: initial)
check(first.values == initial, "migration retains values")
try FileManager.default.copyItem(at: a, to: b)
let before = try FileManager.default.contentsOfDirectory(at: a, includingPropertiesForKeys: nil)
let firstBytes = try Data(contentsOf: before[0])
_ = try SettingsSyncJournal.synchronize(directory: a, app: app, device: "A", baseline: initial,
                                       current: ["one": 10, "two": 2, "list": ["a", "b"]], seed: initial)
_ = try SettingsSyncJournal.synchronize(directory: b, app: app, device: "B", baseline: initial,
                                       current: ["one": 1, "two": 20, "list": ["a", "b"]], seed: initial)
func exchange(_ src: URL, _ dst: URL) throws {
    for file in try FileManager.default.contentsOfDirectory(at: src, includingPropertiesForKeys: nil) {
        let target = dst.appendingPathComponent(file.lastPathComponent)
        if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: file, to: target) }
    }
}
try exchange(a,b); try exchange(b,a)
let merged = try SettingsSyncJournal.read(a, app: app)
check(merged.values["one"] as? Int == 10 && merged.values["two"] as? Int == 20, "offline changes to different keys merge")
check(try Data(contentsOf: before[0]) == firstBytes, "old records never change")
let count = try FileManager.default.contentsOfDirectory(atPath: a.path).count
for _ in 0..<5 {
    _ = try SettingsSyncJournal.synchronize(directory: a, app: app, device: "A", baseline: merged.values, current: merged.values, seed: initial)
}
check(try FileManager.default.contentsOfDirectory(atPath: a.path).count == count, "read/import/poll emits no echo")
// Same-key offline writes have a deterministic winner independent of enumeration order.
_ = try SettingsSyncJournal.synchronize(directory: a, app: app, device: "A", baseline: merged.values, current: ["one": 11,"two":20], seed: initial)
_ = try SettingsSyncJournal.synchronize(directory: b, app: app, device: "B", baseline: merged.values, current: ["one": 12,"two":20], seed: initial)
try exchange(a,b);try exchange(b,a)
let sameA = try SettingsSyncJournal.read(a,app:app), sameB = try SettingsSyncJournal.read(b,app:app)
check(sameA.values == sameB.values, "same-key conflicts converge")
check(sameA.values["list"] == nil,"deletion propagates")
// Restore a deleted setting in a later causal revision.
let restored = try SettingsSyncJournal.synchronize(directory:a,app:app,device:"A",baseline:sameA.values,
                                                  current:["one":42,"two":20,"list":["c"]],seed:initial)
try exchange(a,b)
check(try SettingsSyncJournal.read(b,app:app).values == restored.values,"later restore wins over tombstone")
let dirty = SettingsSyncJournal.overlayEdits(from:["one":1,"two":2],to:["one":99,"two":2],on:["one":1,"two":55])
check(dirty == ["one":99,"two":55],"edits during background read are preserved")
let normalized = SettingsSyncJournal.acceptedBaseline(remote:["one":1,"two":55],captured:["one":1,"two":2],
    beforeApply:["one":99,"two":2],afterApply:["one":99,"two":55,"default":true])
check(normalized == ["one":1,"two":55,"default":true],"app normalization is accepted while in-flight edits remain pending")
let replaced = try SettingsSyncJournal.synchronize(directory:a,app:app,device:"A",baseline:nil,current:["one":7],seed:initial)
check(replaced.values == ["one":7],"explicit import replacement deletes missing remote keys")
// A late bootstrap arriving from an offline Mac cannot outrank a real edit.
try SettingsSyncJournal.append(a,app:app,device:"C",revision:0,values:initial,deleted:[])
check(try SettingsSyncJournal.read(a,app:app).values == replaced.values,"late migration seed cannot resurrect deletions")
let bad = a.appendingPathComponent("incomplete.plist")
try Data("partial".utf8).write(to:bad)
do { _ = try SettingsSyncJournal.read(a,app:app); preconditionFailure("corruption must not clear settings") } catch {}
try FileManager.default.removeItem(at:bad)
let failure = root.appendingPathComponent("not-a-folder");try Data().write(to:failure)
do { _ = try SettingsSyncJournal.synchronize(directory:failure,app:app,device:"A",baseline:initial,current:["one":2],seed:initial);preconditionFailure("write failure must be reported") } catch {}
print("PASS: migration, offline independent edits, no overwrite/echo, deterministic conflicts, deletion/restore, in-flight edits, explicit replacement, late seed, corruption and I/O failure")
