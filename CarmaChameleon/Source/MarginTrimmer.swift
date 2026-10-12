import Foundation
import CoreGraphics

/// 「余白を削除」: YohakuTrimmer's processing (../YohakuTrimmer/Development/Sources/MarginProcessor.swift).
/// Peels off rows and columns of an outer margin color; the crop keeps the source pixels as they are.
/// detectMargins is kept identical to YohakuTrimmer's, so fix it there first and copy it over.
enum MarginTrimmer {
    /// Allowed difference per channel (0–255): 厳密 / 標準 / ゆるめ, as in YohakuTrimmer.
    static let toleranceChoices = [0, 8, 32]
    static let defaultTolerance = 8

    /// Pixels removed from each side, in source pixels.
    struct TrimInsets: Equatable { var top = 0, left = 0, bottom = 0, right = 0 }

    /// The image without its margins; unchanged when there is no margin or the whole image is one color.
    static func apply(_ image: CGImage, tolerance: Int) -> CGImage {
        guard let insets = detectMargins(in: image, tolerance: tolerance), insets != TrimInsets() else { return image }
        let rect = CGRect(x: insets.left, y: insets.top,
                          width: image.width - insets.left - insets.right,
                          height: image.height - insets.top - insets.bottom)
        return image.cropping(to: rect) ?? image
    }

    /// Peels whole rows/columns off each side while the line is that side's margin color (within
    /// `tolerance`). Sides may have different colors; passes repeat until nothing changes, so a strip
    /// on one side no longer blocks the side next to it. Returns nil when every pixel is margin.
    static func detectMargins(in image: CGImage, tolerance: Int) -> TrimInsets? {
        let width = image.width, height = image.height, bytesPerRow = width * 4
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let drew = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return false }
            // Premultiplied: every fully transparent pixel becomes 0,0,0,0 and so counts as one color.
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return TrimInsets() }
        let tol = max(0, tolerance)
        return pixels.withUnsafeBufferPointer { p -> TrimInsets? in
            // Bitmap row 0 is the top of the image, matching CGImage.cropping(to:).
            func matches(_ x: Int, _ y: Int, _ ref: Int) -> Bool {
                let o = y * bytesPerRow + x * 4
                return abs(Int(p[o]) - Int(p[ref])) <= tol && abs(Int(p[o + 1]) - Int(p[ref + 1])) <= tol
                    && abs(Int(p[o + 2]) - Int(p[ref + 2])) <= tol && abs(Int(p[o + 3]) - Int(p[ref + 3])) <= tol
            }
            func uniformRow(_ y: Int, _ x0: Int, _ x1: Int, _ ref: Int) -> Bool {
                for x in x0...x1 where !matches(x, y, ref) { return false }
                return true
            }
            func uniformColumn(_ x: Int, _ y0: Int, _ y1: Int, _ ref: Int) -> Bool {
                for y in y0...y1 where !matches(x, y, ref) { return false }
                return true
            }
            // Margin colors come only from outer edges of the source that are one color end to end, so a
            // shape touching an edge, or a solid shape left after trimming, is not taken for margin, and a
            // gradient is not followed inward. A line is margin when all of it is one of these colors
            // (a gray strip on one side, white on the others: both go).
            var refs: [Int] = []
            let edges = [(0, true), (height - 1, true), (0, false), (width - 1, false)]
            for (index, isRow) in edges {
                let ref = isRow ? index * bytesPerRow : index * 4
                let uniform = isRow ? uniformRow(index, 0, width - 1, ref) : uniformColumn(index, 0, height - 1, ref)
                if uniform, !refs.contains(where: { p[$0] == p[ref] && p[$0 + 1] == p[ref + 1] && p[$0 + 2] == p[ref + 2] && p[$0 + 3] == p[ref + 3] }) {
                    refs.append(ref)
                }
            }
            if refs.isEmpty { return TrimInsets() }
            func rowIsMargin(_ y: Int, _ x0: Int, _ x1: Int) -> Bool { refs.contains { uniformRow(y, x0, x1, $0) } }
            func columnIsMargin(_ x: Int, _ y0: Int, _ y1: Int) -> Bool { refs.contains { uniformColumn(x, y0, y1, $0) } }
            var top = 0, bottom = height - 1, left = 0, right = width - 1
            var changed = true
            while changed {
                changed = false
                while top <= bottom, rowIsMargin(top, left, right) { top += 1; changed = true }
                if top > bottom { return nil }
                while bottom > top, rowIsMargin(bottom, left, right) { bottom -= 1; changed = true }
                while left <= right, columnIsMargin(left, top, bottom) { left += 1; changed = true }
                if left > right { return nil }
                while right > left, columnIsMargin(right, top, bottom) { right -= 1; changed = true }
            }
            return TrimInsets(top: top, left: left, bottom: height - 1 - bottom, right: width - 1 - right)
        }
    }
}
