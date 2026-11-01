import Foundation
import Combine

/// Normalize a private copy before publishing. Never mutate @Published from its own observer.
final class LibraryStore: ObservableObject {
    @Published private(set) var value: Library
    init(_ initial: Library) {
        var normalized = initial
        normalized.reconcileComponents()
        value = normalized
    }
    @discardableResult
    func replace(_ proposed: Library) -> Bool {
        var next = proposed
        next.reconcileComponents(previous: value)
        guard next != value else { return false }
        value = next
        return true
    }
    func update(_ change: (inout Library) -> Void) {
        var next = value
        change(&next)
        replace(next)
    }
}
