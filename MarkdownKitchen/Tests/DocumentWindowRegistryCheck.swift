import Foundation

@main
struct DocumentWindowRegistryCheck {
    static func main() throws {
        final class Window {}
        let registry = DocumentWindowRegistry<Window>()
        let first = Window(), duplicate = Window(), other = Window()
        precondition(registry.request(""))
        precondition(!registry.request(""), "Repeated open before attachment must coalesce")
        precondition(registry.attach(first, to: ""))
        precondition(registry.attach(first, to: ""), "View updates must remain idempotent")
        precondition(!registry.attach(duplicate, to: ""), "A second scene must not steal ownership")
        precondition(!registry.detach(duplicate, from: ""), "Rejected scene must not discard the document")
        precondition(registry.window(for: "") === first)
        precondition(!registry.request(""), "Existing hidden/minimized windows still own the document")
        precondition(registry.request("other"))
        precondition(registry.attach(other, to: "other"))
        precondition(registry.detach(first, from: ""))
        precondition(registry.request(""), "Closed document windows must be reopenable")
        precondition(registry.attach(duplicate, to: ""))
        precondition(registry.window(for: "other") === other)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("file.md")
        let link = directory.appendingPathComponent("link.md")
        let hardlink = directory.appendingPathComponent("hardlink.md")
        let separate = directory.appendingPathComponent("separate.md")
        try "# Original".write(to: file, atomically: true, encoding: .utf8)
        try "# Original".write(to: separate, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        try FileManager.default.linkItem(at: file, to: hardlink)
        precondition(DocumentFileIdentity.matches(file, link))
        precondition(DocumentFileIdentity.matches(file, hardlink))
        precondition(DocumentFileIdentity.matches(file, directory.appendingPathComponent("./file.md")))
        precondition(!DocumentFileIdentity.matches(file, separate), "Equal contents do not mean the same document")
        print("Document window ownership and file identity: all checks passed")
    }
}
