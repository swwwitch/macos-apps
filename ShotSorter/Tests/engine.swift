// Appends to Model/Engine in a temporary test executable; never launches the installed app.
let testRoot = FileManager.default.temporaryDirectory.appendingPathComponent("ShotSorter-engine-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: testRoot) }
let testDomain = ProcessInfo.processInfo.processName
let oldDefaults = UserDefaults.standard.persistentDomain(forName: testDomain)
defer {
    UserDefaults.standard.removePersistentDomain(forName: testDomain)
    if let oldDefaults { UserDefaults.standard.setPersistentDomain(oldDefaults, forName: testDomain) }
}
var testFailures = 0
func verify(_ ok: Bool, _ message: String) {
    if !ok { print("FAIL:", message); testFailures += 1 }
}
func waitUntil(_ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(15)
    while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
}
func makePNG(_ url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 120, pixelsHigh: 80, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
MainActor.assumeIsolated {
    let model = Model()
    model.notify = false; model.ocrComment = false; model.ocrClipboard = false
    model.shotEnabled = true; model.nameTemplate = "custom-{width}-{height}"
    let a = testRoot.appendingPathComponent("a"), b = testRoot.appendingPathComponent("b")
    try! FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
    try! FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
    let existing = a.appendingPathComponent("existing.png")
    try! makePNG(existing)
    model.shotFolders = [a.path, b.path]
    let engine = Engine(model: model)
    engine.refreshWatchers()
    try! makePNG(a.appendingPathComponent("same.png"))
    try! makePNG(b.appendingPathComponent("same.png"))
    waitUntil { model.activity.count >= 2 }
    verify(model.activity.count == 2, "both folders processed once with a custom name lacking ss-")
    verify(FileManager.default.fileExists(atPath: existing.path), "preexisting file untouched")
    verify(FileManager.default.fileExists(atPath: a.appendingPathComponent("custom-120-80.png").path), "first watch folder")
    verify(FileManager.default.fileExists(atPath: b.appendingPathComponent("custom-120-80.png").path), "second watch folder, same output name")
    // Give watcher feedback enough time to expose a rename loop.
    RunLoop.main.run(until: Date().addingTimeInterval(2))
    verify(model.activity.count == 2, "produced names do not feed back into watchers")
    model.shotEnabled = false; engine.refreshWatchers()
    engine.dropFiles([existing, existing])
    waitUntil { model.activity.count >= 3 }
    verify(model.activity.count == 3, "manual drop works with watching off; duplicate input processed once")
    verify(FileManager.default.fileExists(atPath: a.appendingPathComponent("custom-120-80 2.png").path), "collision gets suffix without overwriting")
    // Exercise real Vision and clipboard output; restore every pasteboard type afterwards.
    let board = NSPasteboard.general
    let savedItems = (board.pasteboardItems ?? []).map { item in
        item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
    }
    defer {
        board.clearContents()
        let items = savedItems.map { entries in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { board.writeObjects(items) }
    }
    let image = NSImage(size: NSSize(width: 900, height: 300))
    image.lockFocus()
    NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 900, height: 300).fill()
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 40), .foregroundColor: NSColor.black]
    ("First line" as NSString).draw(at: NSPoint(x: 40, y: 210), withAttributes: attributes)
    ("Second line" as NSString).draw(at: NSPoint(x: 40, y: 100), withAttributes: attributes)
    image.unlockFocus()
    let imageFile = a.appendingPathComponent("ocr.png")
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try! bitmap.representation(using: .png, properties: [:])!.write(to: imageFile)
    model.ocrClipboard = true
    engine.dropFiles([imageFile])
    waitUntil { model.activity.count >= 4 }
    let recognized = board.string(forType: .string) ?? ""
    verify(recognized.contains("First line") && recognized.contains("Second line") && recognized.contains("\n"), "Vision text copied with line breaks")
    verify(model.lastOCR == recognized, "visible result matches clipboard")
    engine.stop()
}
if testFailures > 0 { exit(1) }
print("PASS: engine, two watch folders, no feedback loop, manual drop, duplicate protection, collision handling")
