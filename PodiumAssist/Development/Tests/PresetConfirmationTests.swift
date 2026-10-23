import Foundation
@main struct PresetConfirmationTests {
    @MainActor static func main() throws {
        let a = QuitAppTarget(id: "a", name: "A", path: "/a.app")
        let b = QuitAppTarget(id: "b", name: "B", path: "/b.app")
        let c = QuitAppTarget(id: "c", name: "C", path: "/c.app")
        var preset = Preset(); preset.launchApps = [a]; preset.quitAppTargets = [a,b,c]
        let selected = PresetAppConfirmation.selection(preset, skippedLaunch: ["a"], skippedQuit: ["b"])
        precondition(selected.launchApps?.isEmpty == true)
        precondition(selected.quitAppTargets?.map(\.id) == ["c"])
        precondition(preset.launchApps?.count == 1 && preset.quitAppTargets?.count == 3)
        let all = PresetAppConfirmation.selection(preset, skippedLaunch: [], skippedQuit: [])
        precondition(all.launchApps?.map(\.id) == ["a"])
        precondition(all.quitAppTargets?.map(\.id) == ["b","c"])
        let suite = "PodiumAssist-confirmation-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode([preset]), forKey: "presets")
        let store = PresetStore(defaults: defaults)
        precondition(store.items.count == 3 && store.items[0].id == preset.id)
        precondition(PresetStore(defaults: defaults).items.count == 3)
        store.remove(Preset.fullSet.id)
        precondition(PresetStore(defaults: defaults).items.count == 2)
        precondition(Preset.macOSDefault.timerEnabled == nil && Preset.fullSet.timerMinutes == nil)
        precondition(Preset.macOSDefault.hideDesktop == false && Preset.fullSet.hideDesktop == true)
        print("PASS: per-run selections, overlap protection, original lists unchanged, built-in migration/deletion, timer independence")
    }
}
