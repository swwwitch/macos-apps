import AppKit

/// Decides which folder was used from successive looks at Default Folder X. It has no "folder opened" event,
/// so each poll passes whether a file dialog is open, the folder it shows, and the top of Recent Folders.
/// - A dialog counts once when it closes, for the last folder it showed (a cancelled dialog counts too).
/// - Otherwise a new folder at the top of Recent Folders counts once (Finder, menus). The same folder used
///   again in a row does not move the list, so it is not counted.
struct UsageCounter {
    private var dialogOpen = false
    private var dialogFolder: String?
    private var recentTop: String?
    private var started = false

    /// Returns the paths to count for this poll (zero or one).
    mutating func step(dialogOpen open: Bool, currentFolder: String?, recentTop top: String?) -> [String] {
        defer { started = true }
        if open {
            if let currentFolder { dialogFolder = currentFolder }
            dialogOpen = true
            recentTop = top ?? recentTop      // the dialog may move Recent Folders; that is not a second use
            return []
        }
        if dialogOpen {
            dialogOpen = false
            let used = dialogFolder; dialogFolder = nil
            recentTop = top ?? recentTop
            return used.map { [$0] } ?? []
        }
        guard let top else { return [] }
        defer { recentTop = top }
        return started && recentTop != nil && top != recentTop ? [top] : []
    }
}

/// Apple events to Default Folder X (codes from its scripting dictionary): IsDialogOpen, GetCurrentFolder, GetRecentFolders.
enum DFXEvents {
    enum Failure: Error { case notPermitted, notRunning, other(Int) }
    private static func code(_ s: String) -> FourCharCode { s.utf8.reduce(0) { $0 << 8 | FourCharCode($1) } }

    static func send(_ id: String, to bundleID: String) -> Result<NSAppleEventDescriptor?, Failure> {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        let event = NSAppleEventDescriptor(eventClass: code("DFDX"), eventID: code(id), targetDescriptor: target,
                                           returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        do {
            let reply = try event.sendEvent(options: [.waitForReply], timeout: 3)
            return .success(reply.paramDescriptor(forKeyword: keyDirectObject))
        } catch let error as NSError {
            switch error.code {
            case -1743: return .failure(.notPermitted)            // errAEEventNotPermitted (Automation denied)
            case -600, -609: return .failure(.notRunning)         // procNotFound, connectionInvalid
            default: return .failure(.other(error.code))
            }
        }
    }
    static func path(_ descriptor: NSAppleEventDescriptor?) -> String? {
        guard let url = descriptor?.coerce(toDescriptorType: typeFileURL)?.fileURLValue ?? descriptor?.fileURLValue else { return nil }
        return url.standardizedFileURL.path
    }

    /// One look at Default Folder X. Runs off the main thread (the events wait for a reply).
    static func poll(_ bundleID: String) -> Result<(open: Bool, folder: String?, top: String?), Failure> {
        let open: Bool
        switch send("actv", to: bundleID) {
        case .success(let reply): open = reply?.booleanValue ?? false
        case .failure(let failure): return .failure(failure)
        }
        let folder = open ? (try? send("gCfl", to: bundleID).get()).flatMap { path($0) } : nil
        let list = (try? send("gRfo", to: bundleID).get()) ?? nil
        let top = list.flatMap { $0.numberOfItems > 0 ? path($0.atIndex(1)) : nil }
        return .success((open, folder, top))
    }
}
