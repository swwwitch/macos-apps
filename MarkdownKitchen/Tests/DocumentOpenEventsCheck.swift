import AppKit
import Carbon

@main
struct DocumentOpenEventsCheck {
    @MainActor static func main() {
        func event(_ values: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
            let result = NSAppleEventDescriptor.appleEvent(withEventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEOpenDocuments), targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
            let list = NSAppleEventDescriptor.list()
            for (index, value) in values.enumerated() { list.insert(value, at: index + 1) }
            result.setParam(list, forKeyword: keyDirectObject)
            return result
        }
        let urls = [URL(fileURLWithPath: "/tmp/日本語 原稿.md"), URL(fileURLWithPath: "/tmp/second.md")]
        let descriptors = urls.map { NSAppleEventDescriptor(descriptorType: typeFileURL, data: Data($0.absoluteString.utf8))! }
        precondition(DocumentOpenEvents.fileURLs(in: event(descriptors)) == urls)
        precondition(DocumentOpenEvents.fileURLs(in: event([descriptors[0], descriptors[0]])) == [urls[0], urls[0]])
        precondition(DocumentOpenEvents.fileURLs(in: event([])) == nil)
        precondition(DocumentOpenEvents.fileURLs(in: event([NSAppleEventDescriptor(int32: 42)])) == nil)
        let remote = NSAppleEventDescriptor(descriptorType: typeFileURL, data: Data("https://example.com/a.md".utf8))!
        precondition(DocumentOpenEvents.fileURLs(in: event([remote])) == nil)
        print("DocumentOpenEvents: all checks passed")
    }
}
