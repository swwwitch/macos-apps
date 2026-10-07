import Foundation
import CoreGraphics
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// 「ラスター画像」output: PNG or JPEG, chosen in the options.
struct RasterOptions {
    var type = "png"            // "png" | "jpeg" | "heic" | "avif"
    var sizeMode = "ppi"        // "ppi" | "width" | "height"
    var ppi = 144               // vector sources (.ai / PDF); .psd keeps its own pixels
    var width = 1200            // px, sizeMode "width" (every source, .psd included)
    var height = 1200           // px, sizeMode "height"
    var quality = 85            // JPEG / HEIC / AVIF, 0–100
    var transparent = true      // PNG / HEIC / AVIF background; JPEG is always white
    var range = ""              // artboards / pages, e.g. "1,3-5"; empty = all
    static let types: [(id: String, name: String, ext: String, uti: String)] = [
        ("png", "PNG", "png", "public.png"), ("jpeg", "JPEG", "jpg", "public.jpeg"),
        ("heic", "HEIC", "heic", "public.heic"), ("avif", "AVIF", "avif", "public.avif")]
    /// Types this Mac's ImageIO can write (AVIF needs a recent macOS; WebP can only be read).
    static var availableTypes: [(id: String, name: String, ext: String, uti: String)] {
        let writable = Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
        return types.filter { writable.contains($0.uti) }
    }
    private var info: (id: String, name: String, ext: String, uti: String) { Self.types.first { $0.id == type } ?? Self.types[0] }
    var ext: String { info.ext }
    var uti: String { info.uti }
    var isLossy: Bool { type != "png" }
    var keepsAlpha: Bool { type != "jpeg" && transparent }
    /// Scale from points (or source pixels) to output pixels for an item of `size`.
    func scale(for size: CGSize) -> CGFloat {
        switch sizeMode {
        case "width": return size.width > 0 ? CGFloat(width) / size.width : 1
        case "height": return size.height > 0 ? CGFloat(height) / size.height : 1
        default: return CGFloat(ppi) / 72
        }
    }
    /// Resolution written into the file: the chosen ppi, or 72 when the size is given in pixels.
    var recordedPPI: Double { sizeMode == "ppi" ? Double(ppi) : 72 }
}

/// SVG through Illustrator's Export for Screens (ExportForScreensOptionsWebOptimizedSVG).
struct SVGOptions {
    var css = "STYLEATTRIBUTES"     // SVGCSSPropertyLocation: STYLEATTRIBUTES / STYLEELEMENTS / PRESENTATIONATTRIBUTES / ENTITIES
    var font = "SVGFONT"            // SVGFontType: SVGFONT (text stays text) / OUTLINEFONT
    var images = "PRESERVE"         // RasterImageLocation: PRESERVE / EMBED / LINK
    var precision = 3               // coordinate decimal places, 1–7
    var idType = "SVGIDREGULAR"     // SVGIdType: SVGIDREGULAR / SVGIDMINIMAL / SVGIDUNIQUE
    var minify = false
    var responsive = true
}

/// Output filename built from the source file name, artboard/page number and artboard name.
struct FileNaming: Equatable {
    var useFileName = true
    var useNumber = true
    var useLabel = false            // artboard name (Illustrator); PDF pages and the simple .ai method have none
    var delimiter = "-"
    var padNumber = false           // 01, 02… (width of the largest number)
    var singleUsesFileName = true   // one artboard / page only → just the file name
    var groupInFolder = false       // several images → a folder named after the source file

    /// - Parameters: index is 1-based; total is the number of artboards/pages in the source.
    func name(stem: String, index: Int, total: Int, label: String?) -> String {
        if total <= 1 && singleUsesFileName { return Self.sanitize(stem) }
        let width = padNumber ? max(2, String(total).count) : 1
        let number = String(repeating:"0", count:max(0, width - String(index).count)) + String(index)
        var parts: [String] = []
        if useFileName { parts.append(stem) }
        if useNumber { parts.append(number) }
        if useLabel, let label, !label.isEmpty { parts.append(label) }
        if parts.isEmpty || (!useNumber && (label ?? "").isEmpty && total > 1) {
            // Nothing that tells the pages apart: keep the number so outputs never collapse into "name (1)".
            parts = (useFileName ? [stem] : []) + [number]
        }
        return Self.sanitize(parts.joined(separator:delimiter))
    }

    /// Characters that cannot (or should not) appear in a file name become "_".
    static func sanitize(_ name: String) -> String {
        let bad = CharacterSet(charactersIn:"/:\\\0\r\n\t")
        let cleaned = String(name.unicodeScalars.map { bad.contains($0) ? "_" : Character($0) })
        let trimmed = cleaned.trimmingCharacters(in:.whitespaces)
        let safe = trimmed.hasPrefix(".") ? "_" + trimmed.dropFirst() : trimmed
        return safe.isEmpty ? "_" : String(safe.prefix(200))
    }
}

/// "1,3-5" → [1,3,4,5] (1-based, in the given order, duplicates dropped). Empty → all.
enum PageRange {
    static func parse(_ text: String, count: Int) throws -> [Int] {
        let spec = text.replacingOccurrences(of:"\\s", with:"", options:.regularExpression)
            .replacingOccurrences(of:"，", with:",").replacingOccurrences(of:"、", with:",")
            .replacingOccurrences(of:"〜", with:"-").replacingOccurrences(of:"～", with:"-").replacingOccurrences(of:"–", with:"-")
        if spec.isEmpty { return Array(1...max(count, 1)).filter { $0 <= count } }
        var result: [Int] = []
        for token in spec.split(separator:",", omittingEmptySubsequences:true) {
            let bounds = token.split(separator:"-", omittingEmptySubsequences:false).map { Int($0) }
            let numbers: ClosedRange<Int>
            switch bounds.count {
            case 1: guard let a = bounds[0] else { throw invalid(text) }; numbers = a...a
            case 2:
                guard let a = bounds[0] else { throw invalid(text) }
                let b = bounds[1] ?? (token.hasSuffix("-") ? count : nil)   // "3-" = to the end
                guard let b, a <= b else { throw invalid(text) }
                numbers = a...b
            default: throw invalid(text)
            }
            guard numbers.lowerBound >= 1, numbers.upperBound <= count else { throw outOfRange(text, count) }
            for n in numbers where !result.contains(n) { result.append(n) }
        }
        if result.isEmpty { throw invalid(text) }
        return result
    }
    static func invalid(_ text: String) -> NSError {
        NSError(domain:"PandocDesk.Image", code:2, userInfo:[NSLocalizedDescriptionKey:NSLocalizedString("rangeInvalid", comment:"") + " " + text])
    }
    static func outOfRange(_ text: String, _ count: Int) -> NSError {
        NSError(domain:"PandocDesk.Image", code:3, userInfo:[NSLocalizedDescriptionKey:String(format:NSLocalizedString("rangeOutOfBounds", comment:""), text, count)])
    }
}

enum ImageExport {
    static func error(_ key: String, _ detail: String = "") -> NSError {
        NSError(domain:"PandocDesk.Image", code:1, userInfo:[NSLocalizedDescriptionKey:NSLocalizedString(key, comment:"") + detail])
    }
    /// Images larger than this are refused instead of exhausting memory (about 1 GB at 4 bytes per pixel).
    static let maxPixels = 250_000_000

    /// Renders one PDF page (crop box, page rotation applied) at the size `options` gives.
    static func render(page: PDFPage, options: RasterOptions, transparent: Bool) throws -> CGImage {
        let box = page.bounds(for:.cropBox)
        let rotated = abs(page.rotation) % 180 == 90
        let size = rotated ? CGSize(width:box.height, height:box.width) : box.size
        let scale = options.scale(for:size)
        let width = Int((size.width * scale).rounded()), height = Int((size.height * scale).rounded())
        guard width > 0, height > 0 else { throw error("imageRenderFailed") }
        guard width * height <= maxPixels else { throw error("imageTooLarge") }
        guard let context = CGContext(data:nil, width:width, height:height, bitsPerComponent:8, bytesPerRow:0, space:CGColorSpace(name:CGColorSpace.sRGB)!, bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw error("imageTooLarge") }
        if !transparent { context.setFillColor(CGColor(gray:1, alpha:1)); context.fill(CGRect(x:0, y:0, width:width, height:height)) }
        context.interpolationQuality = .high
        context.scaleBy(x:scale, y:scale)
        context.concatenate(page.transform(for:.cropBox))
        page.draw(with:.cropBox, to:context)
        guard let image = context.makeImage() else { throw error("imageRenderFailed") }
        return image
    }

    /// Resamples to width × height (aspect kept by the caller).
    static func resized(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        guard width > 0, height > 0 else { throw error("imageRenderFailed") }
        guard width * height <= maxPixels else { throw error("imageTooLarge") }
        let space = image.colorSpace?.model == .rgb ? image.colorSpace! : CGColorSpace(name:CGColorSpace.sRGB)!
        guard let context = CGContext(data:nil, width:width, height:height, bitsPerComponent:8, bytesPerRow:0, space:space, bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw error("imageTooLarge") }
        context.interpolationQuality = .high
        context.draw(image, in:CGRect(x:0, y:0, width:width, height:height))
        guard let result = context.makeImage() else { throw error("imageRenderFailed") }
        return result
    }

    /// Draws `image` on white (JPEG, or PNG without transparency) or converts a non-RGB image to sRGB.
    static func prepared(_ image: CGImage, opaque: Bool) throws -> CGImage {
        let rgb = image.colorSpace?.model == .rgb
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        if rgb && !(opaque && hasAlpha) { return image }
        let space = rgb ? image.colorSpace! : CGColorSpace(name:CGColorSpace.sRGB)!
        let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data:nil, width:image.width, height:image.height, bitsPerComponent:8, bytesPerRow:0, space:space, bitmapInfo:info)
        else { throw error("imageTooLarge") }
        let rect = CGRect(x:0, y:0, width:image.width, height:image.height)
        if opaque { context.setFillColor(CGColor(gray:1, alpha:1)); context.fill(rect) }
        context.draw(image, in:rect)
        guard let result = context.makeImage() else { throw error("imageRenderFailed") }
        return result
    }

    /// Writes PNG / JPEG / HEIC / AVIF with the resolution recorded in the file.
    static func write(_ image: CGImage, to url: URL, options: RasterOptions, ppi: Double) throws {
        let output = try prepared(image, opaque:!options.keepsAlpha)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, options.uti as CFString, 1, nil) else { throw error("imageWriteFailed") }
        var properties: [CFString: Any] = [kCGImagePropertyDPIWidth: ppi, kCGImagePropertyDPIHeight: ppi]
        if options.isLossy { properties[kCGImageDestinationLossyCompressionQuality] = Double(min(max(options.quality, 0), 100)) / 100 }
        CGImageDestinationAddImage(destination, output, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw error("imageWriteFailed") }
    }

    /// First image of a file ImageIO can read (PSD composite, PNG, JPEG…), upright by its EXIF orientation,
    /// with its resolution (72 if unrecorded).
    static func readImage(_ url: URL) throws -> (image: CGImage, ppi: Double) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
              var image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { throw error("psdInvalid") }
        guard image.width * image.height <= maxPixels else { throw error("imageTooLarge") }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        if let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue, orientation != 1 {
            // A full-size "thumbnail" with the transform applied is ImageIO's way to get the upright pixels.
            let upright: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceThumbnailMaxPixelSize: max(image.width, image.height), kCGImageSourceShouldCacheImmediately: true]
            if let rotated = CGImageSourceCreateThumbnailAtIndex(source, 0, upright as CFDictionary) { image = rotated }
        }
        let ppi = (properties?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 72
        return (image, ppi > 0 ? ppi : 72)
    }

    /// Images as PDF pages, each at its physical size (pixels at its ppi).
    static func writePDF(_ pages: [(CGImage, Double)], to url: URL) throws {
        guard let context = CGContext(url as CFURL, mediaBox:nil, nil) else { throw error("imageWriteFailed") }
        for (image, ppi) in pages {
            var box = CGRect(x:0, y:0, width:Double(image.width) * 72 / ppi, height:Double(image.height) * 72 / ppi)
            context.beginPage(mediaBox:&box)
            context.interpolationQuality = .high
            context.draw(image, in:box)
            context.endPage()
        }
        context.closePDF()
    }

    /// Creates "name", or "name (1)"… when taken, inside `folder`.
    static func makeFolder(in folder: URL, name: String) throws -> URL {
        let fm = FileManager.default
        for index in 0..<10000 {
            let url = folder.appendingPathComponent(name + (index == 0 ? "" : " (\(index))"), isDirectory:true)
            if fm.fileExists(atPath:url.path) { continue }
            do { try fm.createDirectory(at:url, withIntermediateDirectories:false); return url }
            catch { if fm.fileExists(atPath:url.path) { continue }; throw error }
        }
        throw NSError(domain:"PandocDesk", code:1, userInfo:[NSLocalizedDescriptionKey:"No unused folder name"])
    }

    /// Moves a finished file next to the others under an unused "name.ext" / "name (1).ext".
    static func publish(_ file: URL, folder: URL, name: String, ext: String) throws -> URL {
        let fm = FileManager.default
        for index in 0..<10000 {
            let destination = folder.appendingPathComponent(name + (index == 0 ? "" : " (\(index))") + "." + ext)
            if fm.fileExists(atPath:destination.path) { continue }
            do { try fm.moveItem(at:file, to:destination); return destination }
            catch { if fm.fileExists(atPath:destination.path) { continue }; throw error }
        }
        throw NSError(domain:"PandocDesk", code:1, userInfo:[NSLocalizedDescriptionKey:"No unused output filename"])
    }
}
