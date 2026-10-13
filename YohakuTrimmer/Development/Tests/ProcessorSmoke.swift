import AppKit
import ImageIO

/// Build: swiftc -parse-as-library Sources/MarginProcessor.swift Sources/Localization.swift Tests/ProcessorSmoke.swift
/// Run with a scratch directory as the only argument; nothing outside it is touched.
@main
struct ProcessorSmoke {
    static func main() {
        do { try run(); print("PASS all"); exit(0) }
        catch { print("FAIL: \(error)"); exit(1) }
    }

    struct Failure: Error, CustomStringConvertible { let description: String }
    static func check(_ condition: Bool, _ message: String) throws { if !condition { throw Failure(description: message) } }

    /// Draws on a top-left origin canvas (y grows downward, like the bitmap rows).
    static func image(_ width: Int, _ height: Int, background: CGColor?, draw: (CGContext) -> Void = { _ in }) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
        if let background { ctx.setFillColor(background); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height)) }
        draw(ctx)
        return ctx.makeImage()!
    }
    static let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let red = CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)

    static func run() throws {
        // 1. Solid shape on white: exactly the shape remains (a later pass must not eat the solid shape).
        let boxed = image(200, 120, background: white) { $0.setFillColor(red); $0.fill(CGRect(x: 30, y: 10, width: 100, height: 70)) }
        try check(MarginProcessor.detectMargins(in: boxed, tolerance: 0) == TrimInsets(top: 10, left: 30, bottom: 40, right: 70), "solid shape on white")
        print("PASS solid shape")

        // 2. Different color per side: a gray strip on the left, white elsewhere.
        let gray = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let strips = image(200, 120, background: white) {
            $0.setFillColor(gray); $0.fill(CGRect(x: 0, y: 0, width: 15, height: 120))
            $0.setFillColor(red); $0.fill(CGRect(x: 50, y: 20, width: 60, height: 60))
        }
        try check(MarginProcessor.detectMargins(in: strips, tolerance: 0) == TrimInsets(top: 20, left: 50, bottom: 40, right: 90), "per-side colors")
        print("PASS per-side colors")

        // 3. Transparent margin around a translucent-edged shape.
        let clear = image(100, 100, background: nil) { $0.setFillColor(red); $0.fill(CGRect(x: 20, y: 25, width: 40, height: 30)) }
        try check(MarginProcessor.detectMargins(in: clear, tolerance: 0) == TrimInsets(top: 25, left: 20, bottom: 45, right: 40), "transparent margin")
        print("PASS transparent margin")

        // 4. No margin, and 5. a single color.
        // A red pixel in each corner: no edge is one color end to end. (A one-colored frame would be margin.)
        let noMargin = image(50, 50, background: white) { ctx in ctx.setFillColor(red); for (x, y) in [(0, 0), (49, 0), (0, 49), (49, 49)] { ctx.fill(CGRect(x: x, y: y, width: 1, height: 1)) } }
        // A shape touching the top edge: the top is not margin, the other three sides are.
        let touching = image(100, 80, background: white) { $0.setFillColor(red); $0.fill(CGRect(x: 30, y: 0, width: 40, height: 50)) }
        try check(MarginProcessor.detectMargins(in: touching, tolerance: 0) == TrimInsets(top: 0, left: 30, bottom: 30, right: 30), "shape touching an edge")
        try check(MarginProcessor.detectMargins(in: noMargin, tolerance: 0) == TrimInsets(), "no margin")
        try check(MarginProcessor.detectMargins(in: image(40, 30, background: white), tolerance: 32) == nil, "single color")
        print("PASS no margin / single color")

        // 6. Noisy margin: tolerance 0 stops at the noise, 8 trims through it.
        let noisy = image(120, 80, background: white) {
            $0.setFillColor(CGColor(red: 0.985, green: 0.985, blue: 0.985, alpha: 1)); $0.fill(CGRect(x: 60, y: 2, width: 1, height: 1))
            $0.setFillColor(red); $0.fill(CGRect(x: 40, y: 20, width: 40, height: 40))
        }
        try check(MarginProcessor.detectMargins(in: noisy, tolerance: 0)!.top == 2, "tolerance 0 stops at noise")
        try check(MarginProcessor.detectMargins(in: noisy, tolerance: 8) == TrimInsets(top: 20, left: 40, bottom: 20, right: 40), "tolerance 8 trims noise")
        print("PASS tolerance")

        // 7. Files: -trim.png, numbered when taken, original untouched, DPI kept, skips write nothing.
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let input = root.appendingPathComponent("smoke.png")
        let destination = CGImageDestinationCreateWithURL(input as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, boxed, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
        try check(CGImageDestinationFinalize(destination), "write input")
        let original = try Data(contentsOf: input)
        let first = try MarginProcessor.process(url: input, tolerance: 0)
        let second = try MarginProcessor.process(url: input, tolerance: 0)
        try check(first.output.lastPathComponent == "smoke-trim.png" && second.output.lastPathComponent == "smoke-trim 2.png", "output names")
        try check(try Data(contentsOf: input) == original, "original unchanged")
        let source = CGImageSourceCreateWithURL(first.output as CFURL, nil)!
        let trimmed = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        try check(trimmed.width == 100 && trimmed.height == 70, "trimmed size \(trimmed.width)×\(trimmed.height)")
        try check((properties[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue == 144, "DPI kept")
        try check(MarginProcessor.detectMargins(in: trimmed, tolerance: 0) == nil, "only the solid red shape is left")
        print("PASS files")

        let flatURL = root.appendingPathComponent("flat.png")
        try NSBitmapImageRep(cgImage: image(30, 30, background: white)).representation(using: .png, properties: [:])!.write(to: flatURL)
        do { _ = try MarginProcessor.process(url: flatURL); throw Failure(description: "flat image was written") } catch MarginError.onlyMargin {}
        let fullURL = root.appendingPathComponent("full.png")
        try NSBitmapImageRep(cgImage: noMargin).representation(using: .png, properties: [:])!.write(to: fullURL)
        do { _ = try MarginProcessor.process(url: fullURL); throw Failure(description: "no-margin image was written") } catch MarginError.noMargin {}
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("flat-") || $0.hasPrefix("full-") }
        try check(leftovers.isEmpty, "skips wrote \(leftovers)")
        print("PASS skips")

        // 8. Speed on a large image (12 MP).
        let big = image(4000, 3000, background: white) { $0.setFillColor(red); $0.fill(CGRect(x: 500, y: 400, width: 3000, height: 2200)) }
        let start = Date()
        try check(MarginProcessor.detectMargins(in: big, tolerance: 8) == TrimInsets(top: 400, left: 500, bottom: 400, right: 500), "big image")
        print(String(format: "PASS 12MP in %.2fs", Date().timeIntervalSince(start)))
    }
}
