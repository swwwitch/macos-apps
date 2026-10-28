import AppKit
import Quartz

/// A responder on the main window's chain owns the standard Quick Look panel.
final class SourcePreviewController: NSResponder, QLPreviewPanelDataSource {
    private var item: NSURL?
    override var acceptsFirstResponder: Bool { true }
    func show(_ url: URL, in window: NSWindow) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        item = url as NSURL
        nextResponder = window
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(self)
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.updateController()
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { item != nil }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = self }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = nil }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { item == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { item }
}
