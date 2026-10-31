import Foundation
import AppKit

// Read-only compatibility guard: the old applications and their settings are never changed.
enum LegacyApps {
    static let identifiers = ["jp.dtp-transit.incrementpaste", "jp.dtp-transit.pasteinarow", "jp.dtp-transit.pastematchstyle"]
    static var running: Bool { NSWorkspace.shared.runningApplications.contains { identifiers.contains($0.bundleIdentifier ?? "") } }
}

// All engines execute on the main queue. Keep asynchronous copies and delayed restores exclusive.
enum ClipboardGate {
    // Briefly allow the destination to read the clipboard before another paste.
    static let pasteHold: TimeInterval = 0.15
    static let lineRestoreDelay: TimeInterval = 0.10
    private static var token: UUID?
    static var busy: Bool { token != nil }
    static func begin(blocked: Bool = LegacyApps.running) -> UUID? {
        guard token == nil, !blocked else { return nil }
        let value = UUID(); token = value; return value
    }
    static func end(_ value: UUID, after delay: TimeInterval = 0) {
        if delay == 0 { if token == value { token = nil }; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { if token == value { token = nil } }
    }
}
