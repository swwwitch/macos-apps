import Foundation

/// One live window and at most one outstanding creation request per document.
/// A hidden/minimized window still owns its document until it actually closes.
final class DocumentWindowRegistry<Window: AnyObject> {
    private final class Entry {
        weak var window: Window?
        init(_ window: Window) { self.window = window }
    }
    private var windows: [String: Entry] = [:]
    private var pending: Set<String> = []

    func window(for id: String) -> Window? { windows[id]?.window }

    func request(_ id: String) -> Bool {
        guard window(for: id) == nil else { return false }
        return pending.insert(id).inserted
    }

    @discardableResult
    func attach(_ window: Window, to id: String) -> Bool {
        if let owner = self.window(for: id), owner !== window { return false }
        windows[id] = Entry(window)
        pending.remove(id)
        return true
    }

    @discardableResult
    func detach(_ window: Window, from id: String) -> Bool {
        guard self.window(for: id) === window else { return false }
        windows.removeValue(forKey: id)
        pending.remove(id)
        return true
    }
}

enum DocumentFileIdentity {
    static func matches(_ lhs: URL, _ rhs: URL) -> Bool {
        let left = lhs.standardizedFileURL.resolvingSymlinksInPath()
        let right = rhs.standardizedFileURL.resolvingSymlinksInPath()
        if left.path == right.path { return true }
        // Also recognize hard links and case variants on case-insensitive volumes.
        let keys: Set<URLResourceKey> = [.fileResourceIdentifierKey, .volumeIdentifierKey]
        guard let a = try? left.resourceValues(forKeys: keys),
              let b = try? right.resourceValues(forKeys: keys),
              let af = a.fileResourceIdentifier as? NSObject,
              let bf = b.fileResourceIdentifier as? NSObject,
              let av = a.volumeIdentifier as? NSObject,
              let bv = b.volumeIdentifier as? NSObject else { return false }
        return av.isEqual(bv) && af.isEqual(bf)
    }
}
