import AppKit
import CoreText

/// Flow one continuous string across columns; never split by character count.
enum FontParagraphLayout {
    static func make(text: String, font: CTFont, width: CGFloat, columns: Int, lineHeight: Double, foreground: NSColor = .labelColor, palt: Bool = false, paragraphBefore: Double = 0, paragraphAfter: Double = 0) -> (frames: [CTFrame], height: CGFloat) {
        let count = min(3, max(1, columns))
        let gap: CGFloat = 24
        let columnWidth = max(1, (width - gap * CGFloat(count - 1)) / CGFloat(count))
        let paragraph = NSMutableParagraphStyle()
        // The multiplier describes baseline distance, not extra spacing on top of font metrics.
        let baselineDistance = CTFontGetSize(font) * max(0.5, lineHeight)
        paragraph.minimumLineHeight = baselineDistance
        paragraph.maximumLineHeight = baselineDistance
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacing = max(0, paragraphAfter)
        paragraph.paragraphSpacingBefore = max(0, paragraphBefore)
        let feature: [CFString: Any] = [kCTFontOpenTypeFeatureTag: "palt", kCTFontOpenTypeFeatureValue: palt ? 1 : 0]
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFeatureSettingsAttribute: [feature]] as CFDictionary)
        let previewFont = CTFontCreateCopyWithAttributes(font, CTFontGetSize(font), nil, descriptor)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: previewFont, .paragraphStyle: paragraph, .foregroundColor: foreground
        ])
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let total = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil,
            CGSize(width: columnWidth, height: .greatestFiniteMagnitude), nil).height
        let upper = max(80, ceil(total) + CTFontGetSize(font) * 4)
        var height = max(80, ceil(total / CGFloat(count)) + CTFontGetSize(font) * 2)
        var frames: [CTFrame] = []
        for attempt in 0..<10 {
            frames.removeAll()
            var start = 0
            for column in 0..<count where start < attributed.length {
                let rect = CGRect(x: CGFloat(column) * (columnWidth + gap), y: 0, width: columnWidth, height: height)
                let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), CGPath(rect: rect, transform: nil), nil)
                frames.append(frame)
                start += CTFrameGetVisibleStringRange(frame).length
            }
            if start >= attributed.length { break }
            height = attempt == 8 ? upper : min(upper, height * 1.3 + CTFontGetSize(font))
        }
        return (frames, height)
    }
}
