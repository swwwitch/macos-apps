import Foundation
import Combine

@main struct LibraryStoreTests {
    static func main() throws {
        precondition(ComponentDragPayload.decode(ComponentDragPayload.encode(["A", "B"])) == ["A", "B"])
        precondition(ComponentDragPayload.decode("unrelated:A").isEmpty)
        precondition(ComponentDragPayload.decode(ComponentDragPayload.prefix).isEmpty)
        precondition(ComponentDragPayload.decode(ComponentDragPayload.prefix + String(repeating: "A", count: 131073)).isEmpty)
        let dragProvider = NSItemProvider(object: ComponentDragPayload.encode(["A", "B"]) as NSString)
        precondition(dragProvider.canLoadObject(ofClass: NSString.self))
        precondition(dragProvider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") || dragProvider.hasItemConformingToTypeIdentifier("public.plain-text"), "drag provider advertises a type accepted by the group row")
        let emptyStore = LibraryStore(Library())
        var emptyPublications = 0
        let emptySubscription = emptyStore.$value.dropFirst().sink { _ in emptyPublications += 1 }
        emptyStore.update { $0.components = [Component(name: "Code", step: .code(source: ""))] }
        precondition(emptyPublications == 1 && emptyStore.value.components?.count == 1 && emptyStore.value.scripts.isEmpty, "empty library code registration must publish once")
        withExtendedLifetime(emptySubscription) {}
        let store = LibraryStore(Library())
        var publications = 0
        var snapshots: [Library] = []
        let subscription = store.$value.dropFirst().sink { snapshot in
            publications += 1
            // Every emitted snapshot must already have fully resolved references.
            for action in snapshot.scripts {
                precondition(action.componentIDs?.count == action.actions.count)
            }
            snapshots.append(snapshot)
        }
        let action = ScriptEntry(steps: [.code(source: "initial")], name: "Action")
        store.update { $0.scripts.append(action) }
        precondition(publications == 1, "adding an action publishes exactly once")
        let componentID = store.value.scripts[0].componentIDs![0]
        let original = store.value
        for i in 0..<100 {
            store.update { library in
                let index = library.components!.firstIndex { $0.id == componentID }!
                library.components![index].step = .code(source: "edit \(i)")
            }
        }
        precondition(publications == 101, "editing must not recursively publish")
        precondition(store.value.scripts[0].actions == [.code(source: "edit 99")])
        precondition(store.value.keyRegistrationState == original.keyRegistrationState, "code edits do not re-register keys")
        var categoryActionID: String?
        let beforeCategoryAction = store.value
        store.update { categoryActionID = $0.addComponentAction(componentID, category: "Destination") }
        precondition(store.value.scripts.count == 2 && store.value.scripts.last?.componentIDs == [componentID])
        precondition(store.value.components == beforeCategoryAction.components, "adding to category must not move or edit component")
        let used = store.value.componentsUsed(by: [categoryActionID!])
        precondition(used.map(\.id) == [componentID], "group view filters components through action references")
        precondition(store.value.componentsUsed(by: []).isEmpty)
        precondition(store.value.components == beforeCategoryAction.components, "group browsing is read only")
        let countAfterCategory = publications
        store.update { precondition($0.addComponentAction(componentID, category: "Destination") == categoryActionID) }
        precondition(publications == countAfterCategory, "same component/category action is not duplicated")
        store.replace(beforeCategoryAction) // Undo new category action
        let baseline = publications
        let edited = store.value
        store.update { $0.scripts.removeAll { $0.id == action.id } }
        precondition(publications == baseline + 1 && store.value.scripts.isEmpty)
        let deleted = store.value
        store.replace(edited) // Undo
        precondition(publications == baseline + 2 && store.value.scripts.count == 1)
        store.replace(deleted) // Redo
        precondition(publications == baseline + 3 && store.value.scripts.isEmpty)
        store.replace(deleted)
        precondition(publications == baseline + 3, "unchanged state does not publish")
        store.replace(original)
        var scan = WatchedScripts.Scan()
        scan.files["/watched/new.jsx"] = ["watched"]
        store.update { _ = WatchedScripts.merge(scan, into: &$0, componentsOnly: true) }
        precondition(store.value.scripts.count == 1 && store.value.components?.count == 2)
        let beforeBulk = store.value
        let beforeBulkPublications = publications
        store.update { library in
            for component in library.components ?? [] { library.addComponentAction(component.id, category: "Bulk") }
        }
        precondition(publications == beforeBulkPublications + 1, "bulk registration publishes once")
        precondition(store.value.scripts.filter { $0.category == "Bulk" }.count == 2, "bulk adds a separate action for each component")
        precondition(store.value.components == beforeBulk.components, "bulk registration preserves component categories")
        store.replace(beforeBulk)
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VectorKeys-store-\(UUID().uuidString).json")
        try store.value.save(to: file)
        precondition(Library.load(from: file) == store.value, "resolved state survives saving and reopening")
        try FileManager.default.removeItem(at: file)
        withExtendedLifetime(subscription) {}
        precondition(snapshots.count == publications)
        print("PASS: production Combine LibraryStore add/edit/delete/Undo/Redo/watch/save, finite publications")
    }
}
