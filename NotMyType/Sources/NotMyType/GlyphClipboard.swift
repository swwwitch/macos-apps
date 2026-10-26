import AppKit
import CoreText

@MainActor
enum GlyphClipboard {
    static func copyText(_ text: String, font: CTFont) {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let rtf = try? attributed.data(from: NSRange(location: 0, length: attributed.length),
                                      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        if let rtf { board.setData(rtf, forType: .rtf) }
        if let pdf = textPDF(attributed) { board.setData(pdf, forType: .pdf) }
    }

    // Draw text rather than paths to preserve font information for PDF-aware apps.
    private static func textPDF(_ attributed: NSAttributedString) -> Data? {
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        var media = CGRect(x: 0, y: 0, width: max(1, width + 16), height: max(1, ascent + descent + 16))
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &media, nil) else { return nil }
        context.beginPDFPage(nil)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: 8, y: 8 + descent)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    static func copyOutline(font: CTFont, glyph: CGGlyph) {
        guard let path = CTFontCreatePathForGlyph(font, glyph, nil), !path.isEmpty else { return }
        let bounds = path.boundingBoxOfPath
        var media = CGRect(x: 0, y: 0, width: max(1, bounds.width + 8), height: max(1, bounds.height + 8))
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &media, nil) else { return }
        context.beginPDFPage(nil)
        context.translateBy(x: 4 - bounds.minX, y: 4 - bounds.minY)
        context.addPath(path)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
        context.endPDFPage()
        context.closePDF()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data as Data, forType: .pdf)
    }
}
