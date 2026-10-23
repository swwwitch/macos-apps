import Foundation
import AppKit
@main struct TimerIndependenceTests {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let suite = "podium-timer-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PresetStore(defaults: defaults)
        let countdown = Countdown()
        let settings = MacSettings()
        let originalPlan = countdown.plan
        let originalEnabled = countdown.enabled
        let originalRunning = countdown.running
        var legacy = Preset()
        legacy.timerEnabled = !originalEnabled
        legacy.timerMinutes = originalPlan.minutes + 17
        settings.apply(legacy, countdown: countdown)
        precondition(countdown.plan == originalPlan)
        precondition(countdown.enabled == originalEnabled)
        precondition(countdown.running == originalRunning)
        legacy.launchApps = [QuitAppTarget(id: "test.launch", name: "Launch", path: "/Launch.app")]
        legacy.quitAppTargets = [QuitAppTarget(id: "test.quit", name: "Quit", path: "/Quit.app")]
        store.save(legacy)
        PresetSaveSheet.overwrite(legacy, settings: settings, countdown: countdown, presets: store)
        let restored = PresetStore(defaults: defaults).items.first { $0.id == legacy.id }!
        precondition(restored.timerEnabled == legacy.timerEnabled && restored.timerMinutes == legacy.timerMinutes)
        precondition(restored.launchApps?.first?.id == "test.launch")
        precondition(restored.quitAppTargets?.first?.id == "test.quit")
        let fresh = Preset()
        precondition(fresh.timerEnabled == nil && fresh.timerMinutes == nil)
        print("PASS: presets leave timer plan, enabled/running state unchanged; legacy data and app lists survive overwrite")
    }
}
