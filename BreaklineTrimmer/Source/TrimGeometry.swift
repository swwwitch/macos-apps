import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Port of TrimWithBreakLine.jsx (Illustrator) to bitmaps. The drawn band is the part to remove; the image is
// cut at its two edges with a shaped cut edge, the parts are closed up to the gap, and break lines are drawn
// along the cut edges. Lengths are pixels of the source image (Illustrator's points become pixels).

/// The shape of the cut edge (WARP_STYLES in the script).
enum CutStyle: String, CaseIterable {
    case flag, rise, riseStraight, jagged
}

/// Everything the dialog of the script set. Defaults match the script's user settings.
struct TrimSettings: Equatable {
    static let maxWarpPercent = 100.0
    static let maxJaggedRidges = 100

    /// Size of the area to remove along the cut direction (%, 100 = the drawn band).
    var maskScale = 100.0
    /// Size the image is trimmed to along the cut edge (%, 100 = the drawn band).
    var maskCrossScale = 100.0
    /// Moves the band: positive is down (horizontal cut) or right (vertical cut).
    var maskOffset = 0.0
    var cutStyle = CutStyle.flag
    /// How much the edge bends (-100…100 %); for the straight style, how much it slants.
    var warpPercent = 3.0
    var jaggedSize = 3.0
    var jaggedRidges = 10
    /// Distance between the two parts after closing up (unused when one side is kept).
    var gap = 8.0
    var addRule = true
    var ruleWidth = 1.0
    var roundCap = false
    var ruleDashed = false
    /// Number of dashes; dash and gap are equal and both ends finish with a dash.
    var dashSegments = 20
    /// Break line color (sRGB, 0…1). Black by default, like the script's 100% gray.
    var ruleColor = RuleColor.black

    /// The values the script's clamp functions allow.
    func clamped() -> TrimSettings {
        var value = self
        func finite(_ number: Double, _ fallback: Double) -> Double { number.isFinite ? number : fallback }
        value.maskScale = max(1, finite(maskScale, 100))
        value.maskCrossScale = max(1, finite(maskCrossScale, 100))
        value.maskOffset = finite(maskOffset, 0)
        value.warpPercent = min(Self.maxWarpPercent, max(-Self.maxWarpPercent, finite(warpPercent, 3)))
        value.jaggedSize = max(0, finite(jaggedSize, 3))
        value.jaggedRidges = min(Self.maxJaggedRidges, max(0, jaggedRidges))
        value.gap = max(0, finite(gap, 0))
        value.ruleWidth = max(0, finite(ruleWidth, 1))
        value.dashSegments = max(1, dashSegments)
        return value
    }
}

/// An sRGB color, stored as "#RRGGBBAA".
struct RuleColor: Equatable {
    var red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0
    static let black = RuleColor()
    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
    var hex: String {
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X%02X", byte(red), byte(green), byte(blue), byte(alpha))
    }
    init(red: Double = 0, green: Double = 0, blue: Double = 0, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
    /// "#RRGGBB" or "#RRGGBBAA"; nil for anything else.
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt32(text, radix: 16) else { return nil }
        let full = text.count == 6 ? (value << 8) | 0xFF : value
        self.init(red: Double((full >> 24) & 0xFF) / 255, green: Double((full >> 16) & 0xFF) / 255,
                  blue: Double((full >> 8) & 0xFF) / 255, alpha: Double(full & 0xFF) / 255)
    }
}

/// Which way the image is cut: a wide band cuts it into top and bottom parts, a tall band into left and right.
enum CutAxis {
    /// The cut edge runs left to right (AXIS_Y in the script).
    case horizontal
    /// The cut edge runs top to bottom (AXIS_X in the script).
    case vertical
}

enum TrimLayoutError: Error, Equatable {
    /// No band, or one thinner than a pixel.
    case noBand
    /// The band reaches both ends of the image along the cut direction.
    case coversWholeImage(CutAxis)
}

/// Where everything goes. Coordinates are source pixels with the origin at the top left (y grows downward).
struct TrimLayout {
    struct Part {
        /// The area of the source kept by this part.
        var outline: [CGPoint]
        /// Whole pixels the part moves by, so it is never resampled.
        var offset: CGVector
    }

    var axis: CutAxis
    /// The band covers one end: that side alone is kept and there is no gap.
    var keepsOneSide: Bool
    var parts: [Part]
    /// Break lines, already moved with their parts (output space before `bounds` is subtracted).
    var rules: [[CGPoint]]
    /// The cut edges on the source, before the parts move (for the overlay).
    var cutLines: [[CGPoint]]
    /// The output canvas in the same space as `rules`; whole pixels.
    var bounds: CGRect

    static let bandTolerance: CGFloat = 0.5
    /// MIN_BAND_MARGIN: the cut stays this far inside the image.
    static let cutMargin: CGFloat = 1

    static func make(imageSize: CGSize, band drawnBand: CGRect, settings rawSettings: TrimSettings) throws -> TrimLayout {
        let settings = rawSettings.clamped()
        let imageRect = CGRect(origin: .zero, size: imageSize)
        let band = drawnBand.standardized.intersection(imageRect)
        guard !band.isNull, band.width >= 1, band.height >= 1 else { throw TrimLayoutError.noBand }

        // Cut across whichever direction the band spans more of the image (not the band's own aspect).
        let axis: CutAxis = band.width / imageSize.width >= band.height / imageSize.height ? .horizontal : .vertical
        let isHorizontal = axis == .horizontal
        let axisSize = isHorizontal ? imageSize.height : imageSize.width
        let bandMin = isHorizontal ? band.minY : band.minX
        let bandMax = isHorizontal ? band.maxY : band.maxX
        let bandCrossMin = isHorizontal ? band.minX : band.minY
        let bandCrossMax = isHorizontal ? band.maxX : band.maxY

        // A band reaching one end keeps that side only and trims the rest away.
        let coversStart = bandMin <= bandTolerance
        let coversEnd = bandMax >= axisSize - bandTolerance
        if coversStart && coversEnd { throw TrimLayoutError.coversWholeImage(axis) }

        func clampCut(_ value: CGFloat) -> CGFloat { min(max(value, cutMargin), axisSize - cutMargin) }
        let bandCenter = (bandMin + bandMax) / 2 + settings.maskOffset
        let bandHalf = (bandMax - bandMin) * settings.maskScale / 200
        let cutLow = clampCut(bandCenter - bandHalf)
        let cutHigh = clampCut(bandCenter + bandHalf)

        let crossCenter = (bandCrossMin + bandCrossMax) / 2
        let crossHalf = (bandCrossMax - bandCrossMin) * settings.maskCrossScale / 200
        let crossMin = crossCenter - crossHalf
        let crossMax = crossCenter + crossHalf

        let profile = edgeProfile(settings, crossLength: crossMax - crossMin, axisSize: axisSize)
        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            isHorizontal ? CGPoint(x: across, y: along) : CGPoint(x: along, y: across)
        }
        // Both parts use the same edge, so the cut edges always mesh whatever the style.
        func edge(at cut: CGFloat) -> [CGPoint] {
            profile.map { point(cut + $0.offset, crossMin + $0.ratio * (crossMax - crossMin)) }
        }
        func startPart(cut: CGFloat) -> [CGPoint] { [point(0, crossMin)] + edge(at: cut) + [point(0, crossMax)] }
        func endPart(cut: CGFloat) -> [CGPoint] { [point(axisSize, crossMin)] + edge(at: cut) + [point(axisSize, crossMax)] }

        var parts: [Part] = []
        var rules: [[CGPoint]] = []
        var cutLines: [[CGPoint]] = []
        if coversStart || coversEnd {
            // Cut at the band edge on the side it does not cover.
            let cut = coversStart ? cutHigh : cutLow
            parts = [Part(outline: coversStart ? startPart(cut: cut) : endPart(cut: cut), offset: .zero)]
            cutLines = [edge(at: cut)]
            if settings.addRule { rules = cutLines }
        } else {
            // Close up to the gap: the top (or left) part stays, the other one moves.
            let shift = -((cutHigh - cutLow) - settings.gap).rounded()
            let offset = isHorizontal ? CGVector(dx: 0, dy: shift) : CGVector(dx: shift, dy: 0)
            parts = [Part(outline: startPart(cut: cutLow), offset: .zero),
                     Part(outline: endPart(cut: cutHigh), offset: offset)]
            cutLines = [edge(at: cutLow), edge(at: cutHigh)]
            if settings.addRule {
                rules = [cutLines[0], cutLines[1].map { CGPoint(x: $0.x + offset.dx, y: $0.y + offset.dy) }]
            }
        }

        var bounds = CGRect.null
        for part in parts {
            let visible = polygonBounds(part.outline).intersection(imageRect)
            if !visible.isNull { bounds = bounds.union(visible.offsetBy(dx: part.offset.dx, dy: part.offset.dy)) }
        }
        if settings.ruleWidth > 0 {
            for rule in rules {
                var painted = strokedPath(rule, settings: settings).boundingBoxOfPath
                // A butt cap ends at the band edge; a slanted end segment must not widen the canvas there.
                if !settings.roundCap {
                    let crossRect = isHorizontal
                        ? CGRect(x: crossMin, y: -.greatestFiniteMagnitude / 2, width: crossMax - crossMin, height: .greatestFiniteMagnitude)
                        : CGRect(x: -.greatestFiniteMagnitude / 2, y: crossMin, width: .greatestFiniteMagnitude, height: crossMax - crossMin)
                    painted = painted.intersection(crossRect)
                }
                if !painted.isNull { bounds = bounds.union(painted) }
            }
        }
        if bounds.isNull { throw TrimLayoutError.noBand }
        let minX = bounds.minX.rounded(.down), minY = bounds.minY.rounded(.down)
        bounds = CGRect(x: minX, y: minY, width: bounds.maxX.rounded(.up) - minX, height: bounds.maxY.rounded(.up) - minY)
        return TrimLayout(axis: axis, keepsOneSide: coversStart || coversEnd, parts: parts, rules: rules,
                          cutLines: cutLines, bounds: bounds)
    }

    /// The cut edge as offsets from the cut along the band (ratio 0…1), centered so the cut runs through the
    /// middle of the curve (alignCutEdge in the script). Positive offsets point down (or right).
    static func edgeProfile(_ settings: TrimSettings, crossLength: CGFloat, axisSize: CGFloat) -> [(ratio: CGFloat, offset: CGFloat)] {
        let straight: [(ratio: CGFloat, offset: CGFloat)] = [(0, 0), (1, 0)]
        let bend = settings.warpPercent / 100
        var points: [(ratio: CGFloat, offset: CGFloat)]
        switch settings.cutStyle {
        case .flag, .rise:
            if bend == 0 { return straight }
            let steps = max(48, min(2000, Int(crossLength / 2)))
            points = (0...steps).map { index in
                let ratio = CGFloat(index) / CGFloat(steps)
                // Flag: one period of a wave. Rise: an S-curve that climbs toward the far side.
                let offset = settings.cutStyle == .flag
                    ? bend * axisSize / 2 * sin(ratio * .pi * 2)
                    : -bend * axisSize * (1 - cos(ratio * .pi)) / 2
                return (ratio, offset)
            }
        case .riseStraight:
            if bend == 0 { return straight }
            points = [(0, 0), (1, -bend * axisSize)]
        case .jagged:
            let ridges = settings.jaggedRidges
            if settings.jaggedSize == 0 || ridges == 0 { return straight }
            // Zig Zag with absolute size and corner points: the ends stay, the points between alternate.
            points = (0...(ridges + 1)).map { index in
                let isEnd = index == 0 || index == ridges + 1
                return (CGFloat(index) / CGFloat(ridges + 1), isEnd ? 0 : (index % 2 == 1 ? settings.jaggedSize : -settings.jaggedSize))
            }
        }
        let offsets = points.map(\.offset)
        let middle = ((offsets.min() ?? 0) + (offsets.max() ?? 0)) / 2
        return points.map { ($0.ratio, $0.offset - middle) }
    }

    static func polygonBounds(_ points: [CGPoint]) -> CGRect {
        let path = CGMutablePath()
        path.addLines(between: points)
        return path.boundingBoxOfPath
    }

    static func polylineLength(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

    /// n dashes and n-1 gaps fill the whole rule.
    static func dashLength(_ points: [CGPoint], segments: Int) -> CGFloat {
        polylineLength(points) / CGFloat(max(1, segments) * 2 - 1)
    }

    /// The painted area of a break line, for the output bounds (caps and miter joins included).
    static func strokedPath(_ rule: [CGPoint], settings: TrimSettings) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: rule)
        return path.copy(strokingWithWidth: settings.ruleWidth, lineCap: settings.roundCap ? .round : .butt,
                         lineJoin: .miter, miterLimit: 10)
    }
}

enum TrimImageError: LocalizedError {
    case cannotRead, cannotRender, cannotWrite
}

/// A source image read with its orientation applied, plus what the PNG keeps (resolution).
struct SourceImage {
    let image: CGImage
    let properties: [CFString: Any]

    var size: CGSize { CGSize(width: image.width, height: image.height) }

    static func load(_ url: URL) throws -> SourceImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw TrimImageError.cannotRead }
        return try load(source)
    }

    static func load(data: Data) throws -> SourceImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw TrimImageError.cannotRead }
        return try load(source)
    }

    private static func load(_ source: CGImageSource) throws -> SourceImage {
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let orientation = (sourceProperties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let image: CGImage?
        if orientation == 1 {
            // Upright: keep the pixels, bit depth and color space as they are.
            image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: true] as CFDictionary)
        } else {
            // A rotated photo is turned upright so the band is drawn on what is shown.
            let width = (sourceProperties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
            let height = (sourceProperties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height, 1),
                kCGImageSourceShouldCache: true,
            ] as CFDictionary)
        }
        guard let image, image.width > 0, image.height > 0 else { throw TrimImageError.cannotRead }
        var kept: [CFString: Any] = [:]
        for key in [kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight] {
            if let value = sourceProperties[key] { kept[key] = value }
        }
        return SourceImage(image: image, properties: kept)
    }
}

/// The file formats 「保存」 writes.
enum OutputFormat: String, CaseIterable {
    case png, jpeg, psd
    static let key = "outputFormat"
    static let jpegQuality = 0.9
    var type: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .psd: return UTType("com.adobe.photoshop-image") ?? .image
        }
    }
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .psd: return "psd"
        }
    }
    var name: String { rawValue.uppercased() }
    /// JPEG cannot hold transparency: a transparent background is saved as white.
    var keepsTransparency: Bool { self != .jpeg }
}

enum TrimRenderer {
    /// Draws the parts and break lines on a transparent canvas, or on `background` when given. `scale` below 1 makes a smaller preview.
    static func render(_ image: CGImage, layout: TrimLayout, settings rawSettings: TrimSettings, scale: CGFloat = 1,
                       background: CGColor? = nil) -> CGImage? {
        let settings = rawSettings.clamped()
        let width = max(1, Int((layout.bounds.width * scale).rounded(.up)))
        let height = max(1, Int((layout.bounds.height * scale).rounded(.up)))
        let colorSpace = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let bitsPerComponent = image.bitsPerComponent > 8 ? 16 : 8
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        if let background {
            context.setFillColor(background)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        // Top-left origin in source pixels, like the layout.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -layout.bounds.minX, y: -layout.bounds.minY)
        // Whole-pixel offsets at full size copy pixels as they are; a preview is scaled smoothly.
        context.interpolationQuality = scale == 1 ? .none : .high
        let imageHeight = CGFloat(image.height)
        for part in layout.parts {
            context.saveGState()
            context.translateBy(x: part.offset.dx, y: part.offset.dy)
            context.addLines(between: part.outline)
            context.closePath()
            context.clip()
            // CGContext draws images bottom-up; flip locally inside the clip.
            context.translateBy(x: 0, y: imageHeight)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: imageHeight))
            context.restoreGState()
        }
        if settings.ruleWidth > 0 {
            context.setStrokeColor(settings.ruleColor.cgColor)
            context.setLineWidth(settings.ruleWidth)
            context.setLineCap(settings.roundCap ? .round : .butt)
            context.setLineJoin(.miter)
            context.setMiterLimit(10)
            for rule in layout.rules where rule.count > 1 {
                if settings.ruleDashed {
                    let dash = TrimLayout.dashLength(rule, segments: settings.dashSegments)
                    context.setLineDash(phase: 0, lengths: [dash, dash])
                } else {
                    context.setLineDash(phase: 0, lengths: [])
                }
                context.addLines(between: rule)
                context.strokePath()
            }
        }
        return context.makeImage()
    }

    /// File data with the source resolution; PNG and PSD keep the transparency, JPEG has none.
    static func fileData(_ image: CGImage, format: OutputFormat, properties: [CFString: Any]) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil) else {
            throw TrimImageError.cannotWrite
        }
        var properties = properties
        if format == .jpeg { properties[kCGImageDestinationLossyCompressionQuality] = OutputFormat.jpegQuality }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw TrimImageError.cannotWrite }
        return data as Data
    }
}
