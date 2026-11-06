import Foundation
import PDFKit

/// Extracted text uses UTF-16 offsets, matching Matcher and NSRange.
struct PDFTextSnapshot {
    let text: String
    let pageRanges: [NSRange]
    let emptyPages: Int
    var pageCount: Int { pageRanges.count }

    enum Failure: Error { case unavailable, locked, copyingDenied, noText }

    static func read(_ url: URL) throws -> PDFTextSnapshot {
        guard url.isFileURL, let document = PDFDocument(url: url) else { throw Failure.unavailable }
        guard !document.isLocked else { throw Failure.locked }
        guard document.allowsCopying else { throw Failure.copyingDenied }
        var text = "", ranges: [NSRange] = [], empty = 0
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { throw Failure.unavailable }
            let content = page.string ?? ""
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { empty += 1 }
            // Newlines keep context and matching from spanning page boundaries.
            let start = (text as NSString).length
            text += content
            ranges.append(NSRange(location: start, length: (content as NSString).length))
            text += "\n\n"
        }
        guard empty < document.pageCount else { throw Failure.noText }
        return PDFTextSnapshot(text: text, pageRanges: ranges, emptyPages: empty)
    }

    func page(at offset: Int) -> Int? {
        pageRanges.firstIndex { NSLocationInRange(offset, $0) }.map { $0 + 1 }
    }
}
