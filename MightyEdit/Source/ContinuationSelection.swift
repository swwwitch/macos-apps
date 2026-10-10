import Foundation

/// A queued action may only use the still-selected result of the previous action.
enum ContinuationSelection {
    static func matches(text: String?, location: Int, length: Int, expected: String, start: Int) -> Bool {
        !expected.isEmpty && text == expected && location == start && length == expected.utf16.count
    }
}
