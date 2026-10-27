import AppKit
import CoreText
@main struct FontParagraphLayoutTests {
    static func main() {
        let text = String(repeating: "日本語 ABC 0123。読みやすい文章を確認します。\n\n", count: 60)
        let font = CTFontCreateWithName("Helvetica" as CFString, 32, nil)
        for columns in 1...3 {
            for width: CGFloat in [280, 900] {
                for spacing in [1.0, 2.5] {
                    let result = FontParagraphLayout.make(text: text, font: font, width: width, columns: columns, lineHeight: spacing)
                    var end = 0
                    for frame in result.frames {
                        let range = CTFrameGetVisibleStringRange(frame)
                        precondition(range.location == end)
                        end += range.length
                    }
                    precondition(end == (text as NSString).length)
                    precondition(result.frames.count <= columns)
                }
            }
        }
        for multiplier in [0.5, 1.0, 1.5, 2.5] {
            let result = FontParagraphLayout.make(text: "ABC\nDEF\nGHI", font: font, width: 500, columns: 1, lineHeight: multiplier)
            let frame = result.frames[0]
            let count = CFArrayGetCount(CTFrameGetLines(frame))
            precondition(count == 3)
            var origins = [CGPoint](repeating: .zero, count: count)
            CTFrameGetLineOrigins(frame, CFRange(location: 0, length: count), &origins)
            for index in 1..<count {
                precondition(abs(origins[index - 1].y - origins[index].y - 32 * multiplier) < 0.1)
            }
        }
        for gaps in [(0.0, 0.0), (8.0, 0.0), (0.0, 12.0), (8.0, 12.0)] {
            let result = FontParagraphLayout.make(text: "ABC\u{2028}DEF\nGHI\u{2028}JKL", font: font, width: 500, columns: 1, lineHeight: 1,
                                                 paragraphBefore: gaps.0, paragraphAfter: gaps.1)
            let frame = result.frames[0]
            precondition(CFArrayGetCount(CTFrameGetLines(frame)) == 4)
            var origins = [CGPoint](repeating: .zero, count: 4)
            CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 4), &origins)
            precondition(abs(origins[0].y - origins[1].y - 32) < 0.1)
            precondition(abs(origins[1].y - origins[2].y - (32 + gaps.0 + gaps.1)) < 0.1)
            precondition(abs(origins[2].y - origins[3].y - 32) < 0.1)
        }
        precondition(FontParagraphLayout.make(text: "", font: font, width: 300, columns: 3, lineHeight: 1.5).frames.isEmpty)
        print("PASS: continuous Japanese/English text, 1–3 columns, narrow/wide layouts, line spacing, empty text")
    }
}
