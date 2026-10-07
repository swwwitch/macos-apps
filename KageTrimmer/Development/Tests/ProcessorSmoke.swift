import AppKit
import ImageIO

@main
struct ProcessorSmoke {
    static func main() {
        Thread.detachNewThread {
            do { try run(); exit(0) }
            catch { print("FAIL: \(error)"); exit(1) }
        }
        RunLoop.main.run()
    }
    static func run() throws {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: 320, height: 180, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.55, blue: 0.9, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
        let plain = ctx.makeImage()!
        let plainDetected = ShadowProcessor.detectContent(in: plain).hadShadow
        let shadowed = ShadowProcessor.render(plain, border: false)!
        let bigShadow = ShadowProcessor.render(plain, border: false, shadowSize: 112)!
        guard bigShadow.width == plain.width + 224, bigShadow.height == plain.height + 224 else { throw NSError(domain: "Smoke", code: 6) }
        let shadowDetected = ShadowProcessor.detectContent(in: shadowed).hadShadow
        FileHandle.standardError.write(Data("plain=\(plainDetected) shadow=\(shadowDetected) alpha=\(shadowed.alphaInfo.rawValue) bpp=\(shadowed.bitsPerPixel)\n".utf8))
        guard !plainDetected, shadowDetected else { throw NSError(domain: "Smoke", code: 1) }
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let input = root.appendingPathComponent("smoke-input.png")
        let inputDestination = CGImageDestinationCreateWithURL(input as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(inputDestination, shadowed, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
        guard CGImageDestinationFinalize(inputDestination) else { throw NSError(domain: "Smoke", code: 4) }
        let originalData = try Data(contentsOf: input)
        let removed = try ShadowProcessor.process(url: input, addBorderWhenMissing: true, shadowSize: 0)
        let removedSource = CGImageSourceCreateWithURL(removed.output as CFURL, nil)!
        let removedImage = CGImageSourceCreateImageAtIndex(removedSource, 0, nil)!
        guard removed.output.lastPathComponent == "smoke-input-no-shadow.png",
              !ShadowProcessor.detectContent(in: removedImage).hadShadow,
              removedImage.width < shadowed.width, removedImage.height < shadowed.height,
              try Data(contentsOf: input) == originalData else { throw NSError(domain: "NoShadow", code: 1) }
        let plainURL = root.appendingPathComponent("plain.png")
        let plainData = NSBitmapImageRep(cgImage: plain).representation(using: .png, properties: [:])!
        try plainData.write(to: plainURL)
        do {
            _ = try ShadowProcessor.process(url: plainURL, addBorderWhenMissing: true, shadowSize: 0)
            throw NSError(domain: "NoShadow", code: 2)
        } catch ShadowError.noShadow { }
        guard !FileManager.default.fileExists(atPath: root.appendingPathComponent("plain-no-shadow.png").path),
              try Data(contentsOf: plainURL) == plainData else { throw NSError(domain: "NoShadow", code: 3) }
        print("PASS shadow removal and shadowless skip")
        let result = try ShadowProcessor.process(url: input, addBorderWhenMissing: true)
        guard result.hadShadow, FileManager.default.fileExists(atPath: result.output.path) else { throw NSError(domain: "Smoke", code: 2) }
        let firstOutput = try Data(contentsOf: result.output)
        // The default size is S, so "-s.png" already exists: the second S output must get a number.
        for (size, name) in [(10, "smoke-input-xs.png"), (27, "smoke-input-s 2.png"), (112, "smoke-input-l.png"), (27, "smoke-input-s 3.png")] {
            let sized = try ShadowProcessor.process(url: input, addBorderWhenMissing: true, shadowSize: size)
            guard sized.output.lastPathComponent == name,
                  FileManager.default.fileExists(atPath: sized.output.path) else { throw NSError(domain: "Smoke", code: 8) }
            print("PASS output \(name)")
        }
        guard try Data(contentsOf: result.output) == firstOutput else { throw NSError(domain: "Smoke", code: 9, userInfo: [NSLocalizedDescriptionKey: "Existing output was replaced"]) }
        print("PASS existing output kept")
        let outputSource = CGImageSourceCreateWithURL(result.output as CFURL, nil)!
        let outputProperties = CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as! [CFString: Any]
        guard (outputProperties[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue == 144,
              (outputProperties[kCGImagePropertyDPIHeight] as? NSNumber)?.intValue == 144 else { throw NSError(domain: "Smoke", code: 5) }
        let roundedContext = CGContext(data: nil, width: 180, height: 120, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        roundedContext.setFillColor(CGColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1))
        roundedContext.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 180, height: 120), cornerWidth: 18, cornerHeight: 18, transform: nil))
        roundedContext.fillPath()
        let rounded = ShadowProcessor.render(roundedContext.makeImage()!, border: true)!
        let roundedBytesPerRow = rounded.width * 4
        var roundedPixels = [UInt8](repeating: 0, count: roundedBytesPerRow * rounded.height)
        let roundedScan = CGContext(data: &roundedPixels, width: rounded.width, height: rounded.height, bitsPerComponent: 8,
                                    bytesPerRow: roundedBytesPerRow, space: cs,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
        roundedScan.draw(rounded, in: CGRect(x: 0, y: 0, width: rounded.width, height: rounded.height))
        func roundedRGBA(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
            let offset = y * roundedBytesPerRow + x * 4
            return (roundedPixels[offset], roundedPixels[offset + 1], roundedPixels[offset + 2], roundedPixels[offset + 3])
        }
        let contentCorner = roundedRGBA(27, 27)
        guard contentCorner.0 < 24, contentCorner.1 < 24, contentCorner.2 < 24, contentCorner.3 < 96 else {
            throw NSError(domain: "Smoke", code: 7, userInfo: [NSLocalizedDescriptionKey: "Rounded corner was filled by border"])
        }
        let roundedURL = root.appendingPathComponent("rounded-border-check.png")
        try NSBitmapImageRep(cgImage: rounded).representation(using: .png, properties: [:])!.write(to: roundedURL)
        let roundedResult = try ShadowProcessor.process(url: roundedURL, addBorderWhenMissing: true)
        guard roundedResult.hadShadow else { throw NSError(domain: "Smoke", code: 3) }
        print("PASS \(result.output.path)")
    }
}
