import AppKit

final class ApplicationDropNSView: NSView, NSDraggingSource {
    var clicked: () -> Void = {}
    var choose: (Application) -> Void = { _ in }
    var hover: (Bool) -> Void = { _ in }
    var enabled = true
    var requiredClickCount = 1
    var dragSource: Application?
    private var pressLocation: NSPoint?
    private var dragging = false
    private var pending: Application?
    private var modifiedClick = false

    override func mouseDown(with event: NSEvent) {
        pressLocation = convert(event.locationInWindow, from: nil)
        dragging = false
        modifiedClick = !event.modifierFlags.intersection([.command, .control]).isEmpty
        if enabled, !modifiedClick, event.clickCount < 2, let app = dragSource, let point = pressLocation {
            let iconRect = NSRect(x: 169, y: (bounds.height - 32) / 2, width: 32, height: 32)
            if iconRect.contains(point) {
                dragging = true
                let item = NSDraggingItem(pasteboardWriter: app.url as NSURL)
                item.setDraggingFrame(iconRect, contents: app.icon)
                beginDraggingSession(with: [item], event: event, source: self)
            }
        }
    }
    override func mouseUp(with event: NSEvent) {
        if enabled && !dragging && pressLocation != nil && (event.clickCount >= requiredClickCount || modifiedClick) { clicked() }
        pressLocation = nil
        modifiedClick = false
    }
    override func rightMouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { mouseDown(with: event) }
    }
    override func rightMouseUp(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { mouseUp(with: event) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard enabled, !dragging, let start = pressLocation, let app = dragSource else { return }
        let iconRect = NSRect(x: 169, y: (bounds.height - 32) / 2, width: 32, height: 32)
        let point = convert(event.locationInWindow, from: nil)
        guard iconRect.insetBy(dx: -8, dy: -8).contains(start), hypot(point.x - start.x, point.y - start.y) > 3 else { return }
        dragging = true
        let item = NSDraggingItem(pasteboardWriter: app.url as NSURL)
        item.setDraggingFrame(iconRect, contents: app.icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        pending = enabled ? Self.application(from: sender.draggingPasteboard) : nil
        hover(pending != nil)
        return pending == nil ? [] : .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return enabled && pending != nil ? .copy : []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { clearHighlight() }
    override func draggingEnded(_ sender: NSDraggingInfo) { clearHighlight() }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return enabled && pending != nil
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard enabled, let app = Self.application(from: sender.draggingPasteboard) else {
            clearHighlight()
            return false
        }
        clearHighlight()
        choose(app)
        return true
    }
    private func clearHighlight() {
        pending = nil
        hover(false)
    }
    static func application(from pasteboard: NSPasteboard) -> Application? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            guard urls.count == 1 else { return nil }
            return Application.dropped(at: urls[0])
        }
        if let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String], !paths.isEmpty {
            guard paths.count == 1 else { return nil }
            return Application.dropped(at: URL(fileURLWithPath: paths[0]))
        }
        guard let value = pasteboard.string(forType: .fileURL) ?? pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .string),
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return Application.dropped(at: url)
    }
}
