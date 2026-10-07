import Foundation
import PDFKit

/// Illustrator (.ai) → PDF, simple version (no Illustrator needed).
/// An .ai saved with 「PDF互換ファイルを作成」 carries a PDF representation of the artwork (Adobe's documented
/// purpose of that option); PDFKit reads it and rewrites a plain PDF, which drops Illustrator's private
/// editing data (AIPrivateData). Without PDF compatibility the readable page is Adobe's notice page;
/// it is still converted as is, and the caller reports a warning.
/// The Illustrator-based (official) conversion will be added separately.
enum AIImporter {
    struct Result { let pages: Int; let withoutPDFContent: Bool }

    static func error(_ key: String) -> NSError {
        NSError(domain:"PandocDesk.AI",code:1,userInfo:[NSLocalizedDescriptionKey:NSLocalizedString(key,comment:"")])
    }

    /// Notice text Illustrator writes when PDF compatibility is off (English and Japanese builds).
    static func isNoticePage(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return compact.localizedCaseInsensitiveContains("saved without PDF Content")
            || compact.contains("PDF 互換ファイルを作成せずに") || compact.contains("PDF互換ファイルを作成せずに")
    }

    static func writePDF(from ai: URL, to destination: URL, cancelled: () -> Bool) throws -> Result {
        guard let document = PDFDocument(url: ai), document.pageCount > 0 else { throw error("aiInvalid") }
        guard !document.isLocked else { throw error("locked") }
        if cancelled() { throw CancellationError() }
        let withoutPDF = isNoticePage(document.page(at: 0)?.string ?? "")
        guard document.write(to: destination) else { throw error("aiWriteFailed") }
        return Result(pages: document.pageCount, withoutPDFContent: withoutPDF)
    }
}
