import AppKit

@main enum EditingChecks {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "CourierEditTest-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let file = root.appendingPathComponent("labels.json")
        let store = CustomSettingLabels(file: file, defaults: defaults)
        try store.save(" Label A ", bundleID: "a", key: "enabled")
        try store.save("Label B", bundleID: "b", key: "enabled")
        assert(store.title(bundleID: "a", key: "enabled") == "Label A")
        let reopened = CustomSettingLabels(file: file, defaults: defaults)
        assert(reopened.title(bundleID: "b", key: "enabled") == "Label B")
        try reopened.save(" \n", bundleID: "a", key: "enabled")
        assert(reopened.title(bundleID: "a", key: "enabled") == nil)
        assert(reopened.title(bundleID: "b", key: "enabled") == "Label B")
        let bad = root.appendingPathComponent("bad.json")
        try Data("invalid".utf8).write(to: bad)
        defaults.removeObject(forKey: "courierLabelLocalMigrationV1")
        do {
            try CustomSettingLabels(file: bad, defaults: defaults).save("New", bundleID: "a", key: "k")
            fatalError("Corrupt original must not be overwritten")
        } catch {}
        let unchanged = try String(contentsOf: bad, encoding: .utf8)
        assert(unchanged == "invalid")
        assert(ScreenshotLabels.uniqueLines([" A ", "A", "", "B"]) == ["A", "B"])
        let image = NSImage(size: NSSize(width: 900, height: 220))
        image.lockFocus()
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 900, height: 220).fill()
        ("Show menu bar" as NSString).draw(at: NSPoint(x: 40, y: 100), withAttributes: [
            .font: NSFont.systemFont(ofSize: 44), .foregroundColor: NSColor.black
        ])
        image.unlockFocus()
        let png = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        let screenshot = root.appendingPathComponent("settings.png")
        try png.write(to: screenshot)
        let recognized = try ScreenshotLabels.recognize(screenshot)
        assert(recognized.lines.contains { $0.contains("Show menu bar") })
        assert(!recognized.preview.isEmpty)
        do {
            _ = try ScreenshotLabels.recognize(bad)
            fatalError("Invalid image must fail")
        } catch {}
        print("PASS: app/key isolation, persistence, removal, corrupt-file protection, OCR image, invalid image")
    }
}
