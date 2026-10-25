import AppKit
import Vision
import ImageIO

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

enum ImageReader {
    static func info(_ url: URL) -> ImageInfo? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let dpi = (props[kCGImagePropertyDPIWidth] as? Double).map { Int($0.rounded()) } ?? 72
        return ImageInfo(width: width, height: height, dpi: dpi)
    }
    static func cgImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

enum TextRecognizer {
    /// Japanese and English text, top to bottom, one line per observation. Runs synchronously; call off the main thread.
    static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

enum FinderComment {
    enum Result { case finder, spotlightOnly, failed(String) }
    /// Sets the comment shown in Finder's Get Info (Apple Events to Finder; macOS asks once for permission).
    /// When Finder cannot be used, the comment is still written for Spotlight (kMDItemFinderComment).
    @MainActor static func set(_ text: String, for url: URL) -> Result {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"Finder\" to set comment of (POSIX file \"\(path)\" as alias) to \"\(escaped)\"")?.executeAndReturnError(&error)
        if error == nil { return .finder }
        let message = error?[NSAppleScript.errorMessage] as? String ?? ""
        if let data = try? PropertyListSerialization.data(fromPropertyList: text, format: .binary, options: 0),
           data.withUnsafeBytes({ setxattr(url.path, "com.apple.metadata:kMDItemFinderComment", $0.baseAddress, data.count, 0, 0) }) == 0 {
            return .spotlightOnly
        }
        return .failed(message)
    }
}

enum AreaCapture {
    /// The system's interactive area selection (screencapture -i). nil when cancelled with Esc.
    /// Off the main thread: it waits until the user finishes selecting.
    static func capture() -> URL? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("ShotSorter-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", file.path]
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
    static var allowed: Bool { CGPreflightScreenCaptureAccess() }
}
