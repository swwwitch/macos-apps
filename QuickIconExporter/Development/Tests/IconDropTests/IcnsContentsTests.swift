import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import QuickIconExporter

struct IcnsContentsTests {
    /// Writes a .icns holding a single 256×256 image.
    private func makeIcns(at url: URL) throws {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8, samplesPerPixel: 4,
                                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 256, height: 256).fill()
        NSGraphicsContext.restoreGraphicsState()
        let image = try #require(bitmap.cgImage)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.icns.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    @Test func exportsImageInsideIcnsInsteadOfFileIcon() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Sample.icns")
        try makeIcns(at: source)
        let rules = FilenameRules(prefix: "", iconNamePosition: .beforeFilename, separator: .hyphen, spaceReplacement: .keep, removesUnwantedCharacters: false)
        let result = try IconExporter.exportIcon(for: source, to: root, rules: rules)
        #expect(result.pixelWidth == 256 && result.pixelHeight == 256)
        let png = try #require(NSBitmapImageRep(data: Data(contentsOf: result.outputURL)))
        let color = try #require(png.colorAt(x: 128, y: 128)?.usingColorSpace(.sRGB))
        #expect(color.redComponent > 0.8 && color.greenComponent < 0.4)
    }

    @Test func unreadableIcnsFallsBackToFileIcon() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Broken.icns")
        try Data("not an icon".utf8).write(to: source)
        #expect(IconExporter.icnsContents(of: source) == nil)
        let rules = FilenameRules(prefix: "", iconNamePosition: .beforeFilename, separator: .hyphen, spaceReplacement: .keep, removesUnwantedCharacters: false)
        let result = try IconExporter.exportIcon(for: source, to: root, rules: rules)
        #expect(result.pixelWidth > 0)
    }
}
