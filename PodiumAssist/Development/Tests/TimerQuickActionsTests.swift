import Foundation
@main struct TimerQuickActionsTests {
    @MainActor static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        func date(_ hour: Int, _ minute: Int, day: Int = 23) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
        }
        precondition(TimerPanel.nextHour(after: date(17,47), calendar: calendar) == date(18,0))
        precondition(TimerPanel.nextHour(after: date(18,0), calendar: calendar) == date(19,0))
        precondition(TimerPanel.nextHour(after: date(23,59), calendar: calendar) == date(0,0,day:24))
        let start = date(9,15,day:20), now = date(17,47)
        // quickStart uses the user's current calendar, compare against the same combine operation.
        precondition(TimerPanel.quickStart(start, now: now, today: true, currentTime: false) == TimerPanel.combine(day: now,time:start))
        precondition(TimerPanel.quickStart(start, now: now, today: false, currentTime: true) == TimerPanel.combine(day: start,time:now))
        precondition(TimerPanel.quickStart(start, now: now, today: true, currentTime: true) == TimerPanel.combine(day: now,time:now))
        precondition(!PresetStore.syncedKeys.contains("timerEnabled"))
        print("PASS: next hour, exact hour, midnight rollover, normal and Option quick actions, obsolete timer gate not synced")
    }
}
