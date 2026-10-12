import Foundation
import PDFKit
import Vision

/// Local PDF text extraction with pdftotext (poppler / Xpdf), OCR only for pages without a usable text layer.
/// Without pdftotext the text layer is read with PDFKit.
enum PDFImporter {
    /// pdftotext's reading modes: "reading" (default, columns in reading order), "layout" (-layout,
    /// keeps the physical layout with spaces), "raw" (-raw, content stream order).
    static let modes = ["reading","layout","raw"]
    static func failure(_ key:String,_ page:Int? = nil) -> NSError {
        let text = NSLocalizedString(key,comment:"") + (page.map { " (\($0))" } ?? "")
        return NSError(domain:"PandocDesk.PDF",code:1,userInfo:[NSLocalizedDescriptionKey:text])
    }
    /// pdftotext from Homebrew (`brew install poppler` or `xpdf`) or the app bundle.
    static func pdftotext() -> URL? {
        let paths = [Bundle.main.url(forResource:"pdftotext", withExtension:nil, subdirectory:"bin")?.path ?? ""]
            + ConversionRunner.searchPath.split(separator:":").map { String($0)+"/pdftotext" }
        return paths.first(where: { !$0.isEmpty && FileManager.default.isExecutableFile(atPath:$0) }).map { URL(fileURLWithPath:$0) }
    }
    /// One string per page (pdftotext ends each page with a form feed), always UTF-8.
    static func runPDFToText(_ tool:URL, input:URL, pageCount:Int, mode:String, cancelled:() -> Bool) throws -> [String] {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("CarmaChameleon-pdftotext-" + UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at:temp) }
        let p = Process(); p.executableURL = tool
        var args = ["-enc","UTF-8","-eol","unix","-q"]
        if mode == "layout" { args.append("-layout") } else if mode == "raw" { args.append("-raw") }
        p.arguments = args + [input.path, temp.path]
        p.standardInput = FileHandle.nullDevice; p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run()
        while p.isRunning {
            if cancelled() { p.terminate(); p.waitUntilExit(); throw CancellationError() }
            usleep(20_000)
        }
        guard p.terminationStatus == 0, let data = try? Data(contentsOf:temp) else { throw failure("pdfInputInvalid") }
        var pages = String(decoding:data,as:UTF8.self).components(separatedBy:"\u{0C}")
        if pages.count > pageCount, pages.last?.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty == true { pages.removeLast() }
        guard pages.count == pageCount else { throw failure("pdfInputInvalid") }
        return pages
    }
    /// OCR (Japanese / English, on this Mac) of one rendered page.
    static func recognize(_ page:PDFPage, number:Int) throws -> String {
        guard let ref = page.pageRef else { throw failure("pdfInputInvalid",number) }
        let rect = page.bounds(for:.cropBox)
        guard rect.width > 0, rect.height > 0 else { throw failure("pdfInputInvalid",number) }
        let scale = min(2.5,2400/max(rect.width,rect.height))
        let width = max(1,Int(rect.width*scale)), height = max(1,Int(rect.height*scale))
        guard let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw failure("pdfInputInvalid",number) }
        context.setFillColor(CGColor(gray:1,alpha:1)); context.fill(CGRect(x:0,y:0,width:width,height:height))
        context.concatenate(ref.getDrawingTransform(.cropBox,rect:CGRect(x:0,y:0,width:width,height:height),rotate:0,preserveAspectRatio:true)); context.drawPDFPage(ref)
        guard let image = context.makeImage() else { throw failure("pdfInputInvalid",number) }
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP","en-US"]; request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage:image,options:[:]).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator:"\n")
    }
    /// Text of every page. `usedPDFToText` is false when pdftotext was not found (PDFKit was used).
    static func pages(from url:URL, mode:String = "reading", cancelled:() -> Bool) throws -> (pages:[String], usedPDFToText:Bool) {
        guard let document = PDFDocument(url:url) else { throw failure("pdfInputInvalid") }
        guard !document.isLocked, document.allowsCopying else { throw failure("pdfInputLocked") }
        guard document.pageCount > 0, document.pageCount <= 500 else { throw failure("pdfInputLimit") }
        let tool = pdftotext()
        let extracted = try tool.map { try runPDFToText($0,input:url,pageCount:document.pageCount,mode:mode,cancelled:cancelled) }
        var pages: [String] = []; var size = 0
        for index in 0..<document.pageCount {
            if cancelled() { throw CancellationError() }
            guard let page = document.page(at:index) else { throw failure("pdfInputInvalid",index+1) }
            var text = extracted?[index] ?? page.string ?? ""
            // Keep the leading spaces -layout writes; drop only blank lines and trailing whitespace.
            text = text.components(separatedBy:"\n").map { $0.replacingOccurrences(of:"\\s+$",with:"",options:.regularExpression) }.joined(separator:"\n")
                .trimmingCharacters(in:.newlines)
            if text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { text = try recognize(page,number:index+1) }
            if cancelled() { throw CancellationError() }
            guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw failure("pdfInputNoText",index+1) }
            size += text.utf8.count
            guard size <= 20*1024*1024 else { throw failure("pdfInputLimit") }
            pages.append(text)
        }
        return (pages, tool != nil)
    }
    static func html(from url:URL,cancelled:() -> Bool) throws -> String {
        let paragraphs = try pages(from:url,cancelled:cancelled).pages.map { text in
            "<section><p>" + text.components(separatedBy:"\n").map(IDMLImporter.escape).joined(separator:"<br>\n") + "</p></section>"
        }
        return "<!doctype html><html><head><meta charset=\"utf-8\"></head><body>" + paragraphs.joined(separator:"\n") + "</body></html>"
    }
}
