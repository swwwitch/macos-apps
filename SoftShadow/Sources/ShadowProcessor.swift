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
    static func outputSuffix(shadowSize: Int) -> String {
        switch shadowSize {
        case 0: return "-no-shadow"
        case 10: return "-xs"
        case 112: return "-l"
        default: return "-s"
        }
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
            // Remove those translucent shadow pixels before applying the replacement shadow.
            contentImage = stripExistingShadow(from: cropped) ?? cropped
        } else {
            contentImage = image
        }
        guard let rendered = render(contentImage, border: !detection.hadShadow && addBorderWhenMissing, shadowSize: shadowSize) else {
            throw ShadowError.cannotRender
        }
        let base = url.deletingPathExtension().lastPathComponent
        let output = url.deletingLastPathComponent().appendingPathComponent(base + outputSuffix(shadowSize: shadowSize) + ".png")
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
        coordinator.coordinate(writingItemAt: output, options: [], error: &coordinationError) { coordinatedOutput in
            // Encode before touching an existing output. The folder grant permits
            // an atomic replacement without exposing a partially written PNG.
            do { try (pngData as Data).write(to: coordinatedOutput, options: .atomic) }
            catch { writeError = error }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
        return ProcessingResult(output: output, hadShadow: detection.hadShadow)
    }

    /// Keeps the original opaque pixels and their nearby antialiasing fringe exactly as-is.
    /// Everything farther away is the original shadow and is cleared. No corner geometry is
    /// inferred or redrawn, so the source window corners cannot be clipped.
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
        func originalAlpha(_ x: Int, _ y: Int) -> UInt8 { original[y * bytesPerRow + x * 4 + 3] }
        for y in 0..<height {
            for x in 0..<width where originalAlpha(x, y) < 245 {
                var touchesWindow = false
                for nearbyY in max(0, y - 2)...min(height - 1, y + 2) {
                    for nearbyX in max(0, x - 2)...min(width - 1, x + 2) where originalAlpha(nearbyX, nearbyY) >= 245 {
                        touchesWindow = true; break
                    }
                    if touchesWindow { break }
                }
                if !touchesWindow {
                    let offset = y * bytesPerRow + x * 4
                    pixels[offset] = 0; pixels[offset + 1] = 0; pixels[offset + 2] = 0; pixels[offset + 3] = 0
                }
            }
        }
        // The surviving translucent fringe contains the window's hairline and
        // antialiasing. Smooth only that fringe with a tiny 3x3 Gaussian kernel.
        // Fully opaque source pixels remain byte-for-byte unchanged, so the
        // image itself is never resampled; this only removes stair-stepping on
        // the transparent rounded outline left after the old shadow is cleared.
        let cleaned = pixels
        func cleanedAlpha(_ x: Int, _ y: Int) -> UInt8 {
            guard x >= 0, x < width, y >= 0, y < height else { return 0 }
            return cleaned[y * bytesPerRow + x * 4 + 3]
        }
        let gaussianWeights = [
            [1, 2, 1],
            [2, 4, 2],
            [1, 2, 1]
        ]
        for y in 0..<height {
            for x in 0..<width where cleanedAlpha(x, y) < 245 {
                // Only the surviving fringe and its immediately adjacent
                // transparent pixel can receive blur coverage. This keeps the
                // pass proportional to the perimeter instead of searching a
                // wide neighbourhood for every transparent corner pixel.
                var nearCleanedEdge = cleanedAlpha(x, y) > 0
                if !nearCleanedEdge {
                    for nearbyY in max(0, y - 1)...min(height - 1, y + 1) {
                        for nearbyX in max(0, x - 1)...min(width - 1, x + 1)
                        where cleanedAlpha(nearbyX, nearbyY) > 0 {
                            nearCleanedEdge = true
                            break
                        }
                        if nearCleanedEdge { break }
                    }
                }
                guard nearCleanedEdge else { continue }

                let outputOffset = y * bytesPerRow + x * 4
                for channel in 0..<4 {
                    var weightedTotal = 0
                    var totalWeight = 0
                    for kernelY in -1...1 {
                        for kernelX in -1...1 {
                            let sampleX = x + kernelX, sampleY = y + kernelY
                            let weight = gaussianWeights[kernelY + 1][kernelX + 1]
                            totalWeight += weight
                            guard sampleX >= 0, sampleX < width, sampleY >= 0, sampleY < height else { continue }
                            weightedTotal += Int(cleaned[sampleY * bytesPerRow + sampleX * 4 + channel]) * weight
                        }
                    }
                    pixels[outputOffset + channel] = UInt8((weightedTotal + totalWeight / 2) / totalWeight)
                }
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
