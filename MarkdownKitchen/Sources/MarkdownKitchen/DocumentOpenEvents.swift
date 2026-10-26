import AppKit
import Carbon

/// Own Finder's open-documents event before SwiftUI's delegate can route it to
/// an additional scene. Keep document/window creation outside Apple-event dispatch.
@MainActor
final class DocumentOpenEvents: NSObject {
    static let shared = DocumentOpenEvents()
    private var open: (([URL]) -> Void)?

    func install(open: @escaping ([URL]) -> Void) {
        self.open = open
        NSAppleEventManager.shared().setEventHandler(self,
            andSelector: #selector(handle(_:reply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments))
    }

    @objc private func handle(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let urls = Self.fileURLs(in: event) else {
            reply.setParam(NSAppleEventDescriptor(int32: Int32(paramErr)), forKeyword: keyErrorNumber)
            return
        }
        DispatchQueue.main.async { [weak self] in self?.open?(urls) }
    }

    static func fileURLs(in event: NSAppleEventDescriptor) -> [URL]? {
        guard let list = event.paramDescriptor(forKeyword: keyDirectObject), list.numberOfItems > 0 else { return nil }
        var urls: [URL] = []
        for index in 1...list.numberOfItems {
            guard let item = list.atIndex(index),
                  let url = item.fileURLValue, url.isFileURL else { return nil }
            urls.append(url)
        }
        return urls
    }
}
