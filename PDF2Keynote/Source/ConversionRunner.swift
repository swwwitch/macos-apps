import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// One PDF → one Keynote presentation via the shared KeynoteExporter, with a cancel flag.
final class ConversionRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private let bridge: KeynoteBridge

    init(bridge: KeynoteBridge = KeynoteBridge()) { self.bridge = bridge }

    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }

    func convert(input: URL, folder: URL, options: KeynoteOptions, progress: (Int, Int) -> Void) throws -> URL {
        try KeynoteExporter.export(pdf: input, destination: { KeynoteLayout.uniqueURL(folder: folder, base: input.deletingPathExtension().lastPathComponent, ext: "key") },
                                   options: options, bridge: bridge, isCancelled: { self.isCancelled }, progress: progress)
    }
}
