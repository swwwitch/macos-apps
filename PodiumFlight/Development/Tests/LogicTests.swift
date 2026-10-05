import Foundation

@main
struct LogicTests {
    @MainActor static func main() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var plan = TimerPlan(start: start, minutes: 30)
        precondition(plan.end == start.addingTimeInterval(1800))
        plan.start = start.addingTimeInterval(3600)
        precondition(plan.end == start.addingTimeInterval(5400))
        plan.minutes = 45
        precondition(plan.end == plan.start.addingTimeInterval(2700))
        plan.setEnd(plan.start.addingTimeInterval(600))
        precondition(plan.minutes == 10)
        precondition(Countdown.display(plan, now: plan.start.addingTimeInterval(-30)) == "開始まで 00:30")
        precondition(Countdown.display(plan, now: plan.start) == "10:00")
        precondition(Countdown.display(plan, now: plan.end.addingTimeInterval(-1)) == "00:01")
        precondition(Countdown.display(plan, now: plan.end) == "00:00")
        precondition(Countdown.display(plan, now: plan.end.addingTimeInterval(300)) == "00:00")
        plan.minutes = 90
        precondition(Countdown.display(plan, now: plan.start) == "1:30:00")
        let restoredPlan = try JSONDecoder().decode(TimerPlan.self, from: JSONEncoder().encode(plan))
        precondition(restoredPlan == plan)
        var preset = Preset()
        preset.name = "セミナー"
        preset.hideDock = true
        preset.killDock = false
        preset.timerMinutes = 45
        let restored = try JSONDecoder().decode(Preset.self, from: JSONEncoder().encode(preset))
        precondition(restored.id == preset.id && restored.name == "セミナー")
        precondition(restored.hideDock == true && restored.killDock == false)
        precondition(restored.clock == nil && restored.notificationsOff == nil && restored.timerMinutes == 45)
        print("PASS: linked times, scheduled countdown, expiry, serialization, selective presets")
    }
}
