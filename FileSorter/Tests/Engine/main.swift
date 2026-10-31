import AppKit
@MainActor final class Model {
 var sortEnabled = true
 var shotEnabled = true
 var shotFolders: [String] = []
 var nameTemplate = "custom-{width}-{height}-{dpi}"
 var rules: [SortRule] = []
 var errors: [String] = []
 func log(_ symbol: String, _ text: String, error: Bool = false) { if error { errors.append(text) } }
}
// ENGINE_SOURCE
MainActor.assumeIsolated {
 let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
 defer { try? FileManager.default.removeItem(at: folder) }
 let model = Model(); model.shotFolders = [folder.path]
 let engine = Engine(model: model)
 let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 12, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
 let png = bitmap.representation(using: .png, properties: [:])!
 let input = folder.appendingPathComponent("Screenshot.png")
 try! png.write(to: input)
 engine.refreshWatchers()
 RunLoop.main.run(until: Date().addingTimeInterval(2))
 precondition(FileManager.default.fileExists(atPath: input.path), "existing file must not be renamed")
 let first = engine.renameShot(input)!
 precondition(first.lastPathComponent.hasPrefix("custom-12-8-"))
 let next = folder.appendingPathComponent("Screenshot2.png"); try! png.write(to: next)
 RunLoop.main.run(until: Date().addingTimeInterval(4))
 let names = try! FileManager.default.contentsOfDirectory(atPath: folder.path)
 precondition(names.count == 2 && names.contains(where: { $0.contains(" 2.png") }), "collision and no rename loop")
 precondition(!names.contains("Screenshot2.png"))
 engine.stop()
 precondition(model.errors.isEmpty)
 print("PASS: real PNG metadata, manual rename, automatic watch, existing-file protection, collision and custom-template loop prevention")
}
