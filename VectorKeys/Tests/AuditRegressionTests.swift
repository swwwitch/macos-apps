import Foundation
import Combine

@main struct AuditRegressionTests {
    static func main() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let url = temp.appendingPathComponent("Scripts.json")
        var legacy = Library()
        var entry = ScriptEntry(steps: [.code(source: "42")], name: "Keep action")
        entry.category = "Auto"
        legacy.scripts = [entry]; legacy.categories = ["Manual", "Auto"]
        try legacy.save(to: url)
        let staleBytes = try Data(contentsOf: url)
        var migrated = Library.load(from: url)
        let originalComponents = migrated.components
        try migrated.retireLegacyActionGroups(["Auto"], at: url)
        try migrated.save(to: url)
        precondition(migrated.scripts.count == 1 && migrated.scripts[0].category == nil)
        precondition(migrated.components == originalComponents && migrated.componentCategoryList.contains("Auto"))
        try staleBytes.write(to: url, options: .atomic) // Simulate an old process saving stale data.
        let recovered = Library.load(from: url)
        precondition(!recovered.categoryList.contains("Auto") && recovered.categoryList.contains("Manual"))
        precondition(recovered.scripts[0].id == entry.id && recovered.scripts[0].actions == entry.actions)
        precondition(recovered.components?.map(\.step) == originalComponents?.map(\.step) && recovered.components?.map(\.category) == originalComponents?.map(\.category))
        var recreated = recovered
        recreated.categories = ["Manual", "Auto"]
        recreated.scripts[0].category = "Auto"
        try recreated.save(to: url)
        precondition(Library.load(from: url).scripts[0].category == "Auto", "explicit modern recreation is preserved")
        var valuesLibrary = Library()
        let reusable = Component(name: "Reusable", step: .code(source: "var styleName = arguments[0];"))
        valuesLibrary.components = [reusable]; valuesLibrary.componentCategories = []
        var valuesAction = ScriptEntry(steps: [reusable.step, reusable.step], name: "Two invocations")
        valuesAction.componentIDs = [reusable.id, reusable.id]
        valuesLibrary.scripts = [valuesAction]
        valuesLibrary.scripts[0].setArgument("First", at: 0, slot: 0)
        valuesLibrary.scripts[0].setArgument("Third", at: 1, slot: 2)
        precondition(valuesLibrary.scripts[0].arguments(at: 0) == ["First", "", ""])
        precondition(valuesLibrary.scripts[0].arguments(at: 1) == ["", "", "Third"])
        let sharedBefore = valuesLibrary.components
        valuesLibrary.moveComponentReference(actionID: valuesAction.id, from: 1, by: -1)
        precondition(valuesLibrary.scripts[0].arguments(at: 0) == ["", "", "Third"])
        valuesLibrary.removeComponentReference(actionID: valuesAction.id, at: 1)
        valuesLibrary.reconcileComponents()
        precondition(valuesLibrary.scripts[0].arguments(at: 0) == ["", "", "Third"] && valuesLibrary.scripts[0].actions.count == 1)
        precondition(valuesLibrary.components == sharedBefore)
        let valuesURL = temp.appendingPathComponent("values.json")
        try valuesLibrary.save(to: valuesURL)
        precondition(Library.load(from: valuesURL) == valuesLibrary)
        let valuesStore = LibraryStore(valuesLibrary)
        let valuesUndo = valuesStore.value
        valuesStore.update { $0.scripts[0].setArgument("Changed", at: 0, slot: 0) }
        let valuesRedo = valuesStore.value
        valuesStore.replace(valuesUndo)
        precondition(valuesStore.value.scripts[0].arguments(at: 0) == ["", "", "Third"])
        valuesStore.replace(valuesRedo)
        precondition(valuesStore.value.scripts[0].arguments(at: 0) == ["Changed", "", "Third"])
        valuesStore.update { $0.scripts[0].setArgument("", at: 0, slot: 0); $0.scripts[0].setArgument("", at: 0, slot: 2) }
        precondition(valuesStore.value.scripts[0].componentArguments == nil)
        precondition(ScriptEntry(steps: [reusable.step], name: "Legacy").arguments(at: 0).isEmpty)
        let literal = "a\"b\\c\n日本語, 🙂"
        let codeCall = ScriptText.appleScript(appPath: "/Applications/Illustrator.app", code: "arguments[0]", arguments: [literal, "", "3"])
        let fileCall = ScriptText.appleScript(appPath: "/Applications/Illustrator.app", file: "/a.jsx", arguments: [literal, "", "3"])
        precondition(codeCall.contains(ScriptText.argumentClause([literal, "", "3"])))
        precondition(fileCall.contains(ScriptText.argumentClause([literal, "", "3"])))
        precondition(!ScriptText.appleScript(appPath: "/a.app", code: "42").contains("with arguments"))
        var duplicateLibrary = Library()
        let duplicateComponent = Component(name: "Shared", step: .code(source: "var SW_X = 1;"))
        duplicateLibrary.components = [duplicateComponent]; duplicateLibrary.componentCategories = []
        var originalAction = ScriptEntry(steps: [duplicateComponent.step, duplicateComponent.step], name: "Original", hotkey: Hotkey(code: 0, modifiers: 256))
        originalAction.componentIDs = [duplicateComponent.id, duplicateComponent.id]
        originalAction.category = "Group"; originalAction.kmUID = "KM-source"
        originalAction.runCount = 42; originalAction.lastRun = Date(timeIntervalSince1970: 123)
        originalAction.setArgument("10", at: 1, slot: 2); originalAction.setVariableName("SW_X", at: 1, slot: 2)
        var divider = ScriptEntry(steps: [], name: "Section"); divider.divider = true
        duplicateLibrary.scripts = [originalAction, divider]
        duplicateLibrary.reconcileComponents()
        let beforeDuplicate = duplicateLibrary
        let copied = duplicateLibrary.duplicateActions([originalAction.id, divider.id, "missing"])
        precondition(copied.count == 1 && duplicateLibrary.scripts.count == 3)
        let copy = duplicateLibrary.scripts[1]
        precondition(copy.id != originalAction.id && copy.name != originalAction.name && copy.category == "Group")
        precondition(copy.componentIDs == originalAction.componentIDs && copy.actions == originalAction.actions)
        precondition(copy.componentArguments == originalAction.componentArguments && copy.componentVariableNames == originalAction.componentVariableNames)
        precondition(copy.hotkey == nil && copy.uses == 0 && copy.lastRun == nil && copy.kmUID == nil)
        precondition(duplicateLibrary.scripts[0] == beforeDuplicate.scripts[0] && duplicateLibrary.components == beforeDuplicate.components)
        _ = duplicateLibrary.duplicateActions([originalAction.id, copied[0]])
        precondition(Set(duplicateLibrary.scripts.map(\.name)).count == duplicateLibrary.scripts.count)
        let duplicateURL = temp.appendingPathComponent("duplicates.json")
        try duplicateLibrary.save(to: duplicateURL)
        precondition(Library.load(from: duplicateURL) == duplicateLibrary)
        let duplicateStore = LibraryStore(beforeDuplicate)
        duplicateStore.replace(duplicateLibrary); duplicateStore.replace(beforeDuplicate)
        precondition(duplicateStore.value == beforeDuplicate)
        duplicateStore.replace(duplicateLibrary)
        precondition(duplicateStore.value == duplicateLibrary)
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
