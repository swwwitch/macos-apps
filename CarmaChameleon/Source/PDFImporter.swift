import Foundation
import PDFKit
import Vision

/// Local PDF text extraction, with OCR only for pages without a usable text layer.
enum PDFImporter {
    static func failure(_ key:String,_ page:Int? = nil) -> NSError {
        let text = NSLocalizedString(key,comment:"") + (page.map { " (\($0))" } ?? "")
        return NSError(domain:"PandocDesk.PDF",code:1,userInfo:[NSLocalizedDescriptionKey:text])
    }
    static func html(from url:URL,cancelled:() -> Bool) throws -> String {
        guard let document = PDFDocument(url:url) else { throw failure("pdfInputInvalid") }
        guard !document.isLocked, document.allowsCopying else { throw failure("pdfInputLocked") }
        guard document.pageCount > 0, document.pageCount <= 500 else { throw failure("pdfInputLimit") }
        var paragraphs: [String] = []; var size = 0
        for index in 0..<document.pageCount {
            if cancelled() { throw CancellationError() }
            guard let page = document.page(at:index) else { throw failure("pdfInputInvalid",index+1) }
            var text = (page.string ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
            if text.isEmpty {
                guard let ref = page.pageRef else { throw failure("pdfInputInvalid",index+1) }
                let rect = page.bounds(for:.cropBox)
                guard rect.width > 0, rect.height > 0 else { throw failure("pdfInputInvalid",index+1) }
                let scale = min(2.5,2400/max(rect.width,rect.height))
                let width = max(1,Int(rect.width*scale)), height = max(1,Int(rect.height*scale))
                guard let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw failure("pdfInputInvalid",index+1) }
                context.setFillColor(CGColor(gray:1,alpha:1)); context.fill(CGRect(x:0,y:0,width:width,height:height))
                context.concatenate(ref.getDrawingTransform(.cropBox,rect:CGRect(x:0,y:0,width:width,height:height),rotate:0,preserveAspectRatio:true)); context.drawPDFPage(ref)
                guard let image = context.makeImage() else { throw failure("pdfInputInvalid",index+1) }
                let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
                request.recognitionLanguages = ["ja-JP","en-US"]; request.usesLanguageCorrection = true
                try VNImageRequestHandler(cgImage:image,options:[:]).perform([request])
                text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator:"\n")
            }
            if cancelled() { throw CancellationError() }
            guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw failure("pdfInputNoText",index+1) }
            size += text.utf8.count
            guard size <= 20*1024*1024 else { throw failure("pdfInputLimit") }
            let lines = text.components(separatedBy:.newlines).map(IDMLImporter.escape).joined(separator:"<br>\n")
            paragraphs.append("<section><p>" + lines + "</p></section>")
        }
        return "<!doctype html><html><head><meta charset=\"utf-8\"></head><body>" + paragraphs.joined(separator:"\n") + "</body></html>"
    }
}
