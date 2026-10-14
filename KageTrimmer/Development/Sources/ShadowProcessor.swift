import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

enum ShadowError: LocalizedError {
    case cannotRead, cannotRender, cannotWrite, noShadow
    var errorDescription: String? {
        switch self {
        case .noShadow: L("影がないためスキップしました")
        case .cannotRead: L("画像を読み込めませんでした")
        case .cannotRender: L("画像を処理できませんでした")
        case .cannotWrite: L("画像を書き出せませんでした")
        }
    }
}

struct ProcessingResult { let output: URL; let hadShadow: Bool }

private final class RelatedOutputPresenter: NSObject, NSFilePresenter {
    let primaryPresentedItemURL: URL?
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    init(primary: URL, related: URL) {
        primaryPresentedItemURL = primary
        presentedItemURL = related
    }
}

enum ShadowProcessor {
    static func defaultOutputSuffix(shadowSize: Int) -> String {
        switch shadowSize {
        case 0: return "-no-shadow"
        case 10: return "-xs"
        case 112: return "-l"
        default: return "-s"
        }
    }

    /// The suffix chosen in Settings, or the default when it is unset or empty.
    static func outputSuffix(shadowSize: Int) -> String {
        let saved = sanitizedSuffix(UserDefaults.standard.string(forKey: suffixKey(shadowSize: shadowSize)) ?? "")
        return saved.isEmpty ? defaultOutputSuffix(shadowSize: shadowSize) : saved
    }

    static func suffixKey(shadowSize: Int) -> String { "outputSuffix.\(shadowSize)" }

    /// "/" and ":" would leave the source folder or be shown as "/" in Finder; line breaks and outer spaces are dropped.
    static func sanitizedSuffix(_ suffix: String) -> String {
        suffix.components(separatedBy: CharacterSet(charactersIn: "/:").union(.newlines)).joined()
            .trimmingCharacters(in: .whitespaces)
    }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    static func process(url: URL, addBorderWhenMissing: Bool, shadowSize: Int = 27) throws -> ProcessingResult {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: true] as CFDictionary) else {
            throw ShadowError.cannotRead
        }
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let detection = detectContent(in: image)
        if shadowSize == 0 && !detection.hadShadow { throw ShadowError.noShadow }
        let contentImage: CGImage
        if detection.hadShadow, let cropped = image.cropping(to: detection.contentRect) {
            // A rectangular crop still contains pieces of the old shadow in rounded corners.
            // Remove them first on a slightly larger area: the shadow beside the edge is measured from the pixels outside.
            let rect = detection.contentRect
            let margin = rect.insetBy(dx: -4, dy: -4).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            if let wider = image.cropping(to: margin), let stripped = stripExistingShadow(from: wider),
               let trimmed = stripped.cropping(to: rect.offsetBy(dx: -margin.minX, dy: -margin.minY)) {
                contentImage = trimmed
            } else {
                contentImage = cropped
            }
        } else {
            contentImage = image
        }
        guard let rendered = render(contentImage, border: !detection.hadShadow && addBorderWhenMissing, shadowSize: shadowSize) else {
            throw ShadowError.cannotRender
        }
        var output = availableOutput(for: url, suffix: outputSuffix(shadowSize: shadowSize))
        var outputProperties: [CFString: Any] = [kCGImagePropertyPNGDictionary: [:] as CFDictionary]
        // Preserve Retina/DPI metadata exactly. Rendering is always 1:1 in pixel dimensions;
        // only transparent shadow padding is added, so no source pixels are resampled.
        if let dpi = sourceProperties?[kCGImagePropertyDPIWidth] { outputProperties[kCGImagePropertyDPIWidth] = dpi }
        if let dpi = sourceProperties?[kCGImagePropertyDPIHeight] { outputProperties[kCGImagePropertyDPIHeight] = dpi }
        if let profile = sourceProperties?[kCGImagePropertyProfileName] { outputProperties[kCGImagePropertyProfileName] = profile }

        // Coordinate the related output after the UI has obtained access to the
        // source folder when needed. File access alone doesn't authorize a sibling.
        let presenter = RelatedOutputPresenter(primary: url, related: output)
        NSFileCoordinator.addFilePresenter(presenter)
        defer { NSFileCoordinator.removeFilePresenter(presenter) }
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        var coordinationError: NSError?
        let pngData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(pngData, UTType.png.identifier as CFString, 1, nil) else { throw ShadowError.cannotWrite }
        CGImageDestinationAddImage(destination, rendered, outputProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ShadowError.cannotWrite }
        var writeError: Error?
        // Never replace an existing file: if the free name was taken in the meantime, try the next number.
        for _ in 0..<100 {
            writeError = nil
            coordinator.coordinate(writingItemAt: output, options: [], error: &coordinationError) { coordinatedOutput in
                // Encoded above, so only complete PNG data is written.
                do { try (pngData as Data).write(to: coordinatedOutput, options: .withoutOverwriting) }
                catch { writeError = error }
            }
            if let coordinationError { throw coordinationError }
            guard let error = writeError as NSError?, error.domain == NSCocoaErrorDomain, error.code == NSFileWriteFileExistsError else { break }
            output = availableOutput(for: url, suffix: outputSuffix(shadowSize: shadowSize))
        }
        if let writeError { throw writeError }
        return ProcessingResult(output: output, hadShadow: detection.hadShadow)
    }

    /// "name-s.png", then "name-s 2.png", "name-s 3.png"… beside the source. Never an existing item.
    static func availableOutput(for url: URL, suffix: String) -> URL {
        let folder = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent + suffix
        var candidate = folder.appendingPathComponent(base + ".png")
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) || candidate.standardizedFileURL == url.standardizedFileURL {
            candidate = folder.appendingPathComponent("\(base) \(number).png")
            number += 1
        }
        return candidate
    }

    /// Removes the old shadow but keeps the window's own antialiased edge (and its thin dark outline).
    /// A fringe pixel is the window composited over a black shadow, so its premultiplied colour is the
    /// window's alone and only the alpha mixes: a = w + s(1 - w). The shadow alpha s is the strongest
    /// pure-shadow pixel (2 px or more from the window) within 3 px, which changes smoothly along the
    /// edge, and w = (a - s) / (1 - s) is kept. Opaque pixels stay byte-for-byte; nothing is blurred.
    private static func stripExistingShadow(from image: CGImage) -> CGImage? {
        let width = image.width, height = image.height, bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let drewImage = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drewImage else { return nil }
        let original = pixels
        func isOpaque(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < width && y >= 0 && y < height && original[y * bytesPerRow + x * 4 + 3] >= 245
        }
        // Past the antialiasing (no opaque pixel closer than 2 px) only the shadow remains.
        var pureShadow = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width where !isOpaque(x, y) {
                var nearWindow = isOpaque(x - 2, y) || isOpaque(x + 2, y) || isOpaque(x, y - 2) || isOpaque(x, y + 2)
                for nearbyY in (y - 1)...(y + 1) where !nearWindow {
                    for nearbyX in (x - 1)...(x + 1) where isOpaque(nearbyX, nearbyY) { nearWindow = true; break }
                }
                pureShadow[y * width + x] = !nearWindow
            }
        }
        let radius = 3
        for y in 0..<height {
            for x in 0..<width where !isOpaque(x, y) {
                let offset = y * bytesPerRow + x * 4
                if pureShadow[y * width + x] {
                    pixels[offset] = 0; pixels[offset + 1] = 0; pixels[offset + 2] = 0; pixels[offset + 3] = 0
                    continue
                }
                var shadow = -1.0
                for nearbyY in max(0, y - radius)...min(height - 1, y + radius) {
                    for nearbyX in max(0, x - radius)...min(width - 1, x + radius) where pureShadow[nearbyY * width + nearbyX] {
                        shadow = max(shadow, Double(original[nearbyY * bytesPerRow + nearbyX * 4 + 3]))
                    }
                }
                // Surrounded by the window (a translucent spot inside it): not shadow, keep as-is.
                guard shadow >= 0 else { continue }
                let alpha = Double(original[offset + 3])
                shadow = min(alpha, shadow)
                let windowAlpha = shadow < 255 ? (alpha - shadow) / (1 - shadow / 255) : 0
                // A few levels of leftover estimate error would show as a faint ring around the window.
                guard windowAlpha >= 6 else {
                    pixels[offset] = 0; pixels[offset + 1] = 0; pixels[offset + 2] = 0; pixels[offset + 3] = 0
                    continue
                }
                let newAlpha = UInt8(min(255, windowAlpha.rounded()))
                for channel in 0..<3 { pixels[offset + channel] = min(original[offset + channel], newAlpha) }
                pixels[offset + 3] = newAlpha
            }
        }
        return pixels.withUnsafeMutableBytes { storage in
            guard let cleaned = CGContext(data: storage.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
            return cleaned.makeImage()
        }
    }

    /// macOS window captures have an opaque rectangular window surrounded by translucent shadow pixels.
    static func detectContent(in image: CGImage) -> (hadShadow: Bool, contentRect: CGRect) {
        guard image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast else {
            return (false, CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let bytesPerRow = image.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let scan = CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                   bytesPerRow: bytesPerRow, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            return (false, CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        scan.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        var minX = image.width, minY = image.height, maxX = -1, maxY = -1
        var translucent = 0
        // Inspect every pixel so a one-pixel window edge is never skipped on odd coordinates.
        for y in 0..<image.height {
            for x in 0..<image.width {
                let a = Int(pixels[y * bytesPerRow + x * 4 + 3])
                if a >= 245 { minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y) }
                else if a >= 5 { translucent += 1 }
            }
        }
        guard maxX >= minX, maxY >= minY else { return (false, CGRect(x: 0, y: 0, width: image.width, height: image.height)) }
        let inset = minX > 2 || minY > 2 || maxX < image.width - 3 || maxY < image.height - 3
        let hadShadow = inset && translucent > 16
        guard hadShadow else { return (false, CGRect(x: 0, y: 0, width: image.width, height: image.height)) }
        let rect = CGRect(x: max(0, minX - 1), y: max(0, minY - 1),
                          width: min(image.width - minX + 1, maxX - minX + 3),
                          height: min(image.height - minY + 1, maxY - minY + 3))
        return (true, rect)
    }

    static func render(_ content: CGImage, border: Bool, shadowSize requestedShadowSize: Int = 27) -> CGImage? {
        if requestedShadowSize == 0 { return content }
        // The reference uses a 27 px shadow area on every side (510×990 → about 563×1043).
        let shadowSize = max(1, min(112, requestedShadowSize))
        let outW = content.width + shadowSize * 2
        let outH = content.height + shadowSize * 2
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let canvas = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8,
                                     bytesPerRow: 0, space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let contentRect = CGRect(x: shadowSize, y: shadowSize, width: content.width, height: content.height)

        canvas.saveGState()
        canvas.setShadow(offset: .zero, blur: CGFloat(shadowSize), color: CGColor(gray: 0, alpha: 0.27))
        // Drawing the source with a CGContext shadow follows its alpha mask, so transparent
        // parts of the input and the surrounding canvas remain transparent.
        canvas.draw(content, in: contentRect)
        canvas.restoreGState()
        if border {
            // Draw the hairline *inside* the source alpha mask. The former outer-edge
            // technique expanded the mask by about one pixel; at rounded corners that
            // expansion combined with the shadow and could make the window look square.
            // This edge never paints a pixel outside the original silhouette.
            if let edge = makeInnerBorder(from: content) {
                canvas.draw(edge, in: contentRect)
            }
        }
        return canvas.makeImage()
    }

    private static func makeInnerBorder(from image: CGImage) -> CGImage? {
        let width = image.width, height = image.height, bytesPerRow = width * 4
        var source = [UInt8](repeating: 0, count: bytesPerRow * height)
        var edge = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let drewImage = source.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drewImage else { return nil }
        func alpha(_ x: Int, _ y: Int) -> UInt8 {
            guard x >= 0, x < width, y >= 0, y < height else { return 0 }
            return source[y * bytesPerRow + x * 4 + 3]
        }
        for y in 0..<height {
            for x in 0..<width {
                let center = Int(alpha(x, y))
                guard center > 0 else { continue }
                // A one-pixel Euclidean-radius kernel contains only the four
                // cardinal neighbours. The previous 3x3 square also included
                // diagonals (distance sqrt(2)), which made rounded corners two
                // pixels thick in places and produced a visible staircase.
                // Keeping the source alpha values here preserves the original
                // subpixel coverage as antialiasing for the inner hairline.
                let innerAlpha = min(
                    center,
                    Int(alpha(x - 1, y)),
                    Int(alpha(x + 1, y)),
                    Int(alpha(x, y - 1)),
                    Int(alpha(x, y + 1))
                )
                let coverage = max(0, center - innerAlpha)
                let lineAlpha = UInt8(min(255, Int((Double(coverage) * 0.30).rounded())))
                guard lineAlpha > 0 else { continue }
                let offset = y * bytesPerRow + x * 4
                let gray = UInt8((Double(lineAlpha) * 0.18).rounded())
                edge[offset] = gray
                edge[offset + 1] = gray
                edge[offset + 2] = gray
                edge[offset + 3] = lineAlpha
            }
        }
        return edge.withUnsafeMutableBytes { storage in
            guard let context = CGContext(data: storage.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
            return context.makeImage()
        }
    }
}
