import Foundation
import Combine

@main struct AuditRegressionTests {
    static func main() throws {
        var library = Library()
        var scan = WatchedScripts.Scan()
        scan.files["/audit/a.jsx"] = ["One"]
        scan.files["/audit/b.jsx"] = ["One"]
        _ = WatchedScripts.merge(scan, into: &library, componentsOnly: true)
        library.componentCategories = ["One", "Two"]
        let ids = Set(library.components!.map(\.id))
        var ignored: Set<String> = []
        let original = library, originalIgnored = ignored
        let deletedPaths = library.removeComponents(ids)!
        ignored.formUnion(deletedPaths)
        precondition(library.components!.isEmpty)
        precondition(WatchedScripts.merge(scan, into: &library, ignoring: ignored, componentsOnly: true) == 0, "deleted watched components must stay deleted")
        library = original; ignored = originalIgnored // Undo state and suppression together.
        precondition(WatchedScripts.merge(scan, into: &library, ignoring: ignored, componentsOnly: true) == 0 && library.components?.count == 2)
        var legacyIgnored = library
        var changedScan = scan; changedScan.files["/audit/a.jsx"] = ["Updated"]
        _ = WatchedScripts.merge(changedScan, into: &legacyIgnored, ignoring: ["/audit/a.jsx"], componentsOnly: true)
        precondition(legacyIgnored.components!.first { $0.step.scriptPath == "/audit/a.jsx" }!.folderTags!.contains("Updated"), "legacy action suppression must not freeze an existing component")
        let component = library.components![0]
        let actionID = library.addComponentAction(component.id, category: "Actions")!
        let beforeReferencedDelete = library
        precondition(library.removeComponents(ids) == nil && library == beforeReferencedDelete, "mixed referenced batch must not partially delete")
        let targets = library.nameTargets(components: true, ids: ids)
        precondition(targets.count == 2 && !targets.contains { $0.id == actionID })
        let actionBeforeRename = library.scripts
        precondition(library.replaceComponentNames(ids: ids, find: "a", with: "renamed", regex: false, caseSensitive: true) == 1)
        precondition(library.scripts == actionBeforeRename, "component name tools must not edit hidden action selection")
        precondition(library.replaceComponentNames(ids: [actionID], find: "a", with: "wrong", regex: false, caseSensitive: true) == 0)
        precondition(library.components!.first { $0.id == component.id }!.userRenamed == true)
        library.setComponentCategory("Two", ids: ids)
        precondition(library.components!.allSatisfy { $0.category == "Two" } && library.scripts == actionBeforeRename, "bulk category assignment must not move actions")
        let beforeInvalidCategory = library
        library.setComponentCategory("Absent", ids: ids)
        precondition(library == beforeInvalidCategory)
        library.scripts.removeAll { $0.id == actionID }
        precondition(ignored.isEmpty, "removing actions leaves registration suppression alone")
        precondition(library.removeComponents(ids)?.count == 2)

        var order = Library()
        for id in ["a", "other", "b", "c", "d"] {
            var entry = ScriptEntry(id: id, steps: [.code(source: id)], name: id)
            entry.category = id == "other" ? "Other" : "Group"
            entry.runCount = 7; order.scripts.append(entry)
        }
        let originalEntries = Dictionary(uniqueKeysWithValues: order.scripts.map { ($0.id, $0) })
        precondition(order.placeActions(["b", "c"], before: "a", within: ["a", "b", "c", "d"]))
        precondition(order.scripts.map(\.id) == ["b", "other", "c", "a", "d"])
        precondition(order.scripts.allSatisfy { originalEntries[$0.id] == $0 }, "reorder preserves all action data")
        precondition(order.placeActions(["a"], before: nil, within: ["b", "c", "a", "d"]))
        precondition(order.scripts.map(\.id) == ["b", "other", "c", "d", "a"])
        let unchanged = order
        precondition(!order.placeActions(["b"], before: "b", within: ["b", "c", "d", "a"]))
        precondition(!order.placeActions(["b"], before: "other", within: order.scripts.map(\.id)))
        precondition(order == unchanged)
        precondition(ActionDragPayload.decode(ActionDragPayload.encode(["a", "b"])) == ["a", "b"])
        precondition(ActionDragPayload.decode(ComponentDragPayload.encode(["a"])).isEmpty)
        print("PASS: audit regressions: mode-specific names, watch deletion/restore, protected bulk deletion, bulk categories, explicit action reorder and payloads")
    }
}
