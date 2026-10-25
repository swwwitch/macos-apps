import AppKit

/// Reports files that appear in a folder. Event-driven (a kqueue source on the folder); the listing is
/// compared only after the folder changed. Files present when watching starts are never reported.
/// A new file is reported once its size stays the same between two checks (downloads still being written wait).
@MainActor final class FolderWatcher {
    let url: URL
    private var known: Set<String> = []
    private var pending: [String: Int64] = [:]
    private var source: DispatchSourceFileSystemObject?
    private let onNew: (URL) -> Void

    init?(url: URL, onNew: @escaping (URL) -> Void) {
        self.url = url; self.onNew = onNew
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        known = listing()
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.rescan() } }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }
    func stop() { source?.cancel(); source = nil }

    private func listing() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [])
    }
    private func rescan() {
        let current = listing()
        let added = current.subtracting(known)
        known = current
        for name in added where !PartialFile.isPartial(name) && pending[name] == nil {
            pending[name] = -1
            settle(name)
        }
    }
    private func settle(_ name: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.source != nil, let last = self.pending[name] else { return }
                let file = self.url.appendingPathComponent(name)
                guard let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? Int64 else { self.pending[name] = nil; return }
                if size == last && size > 0 { self.pending[name] = nil; self.onNew(file) } else { self.pending[name] = size; self.settle(name) }
            }
        }
    }
}
