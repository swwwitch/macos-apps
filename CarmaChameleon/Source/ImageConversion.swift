import Foundation
import PDFKit

/// Image outputs (ラスター画像 / SVG) and Photoshop input.
///   .ai  → PNG/JPEG/SVG: Illustrator exports each artboard; the simple method rasterizes the embedded PDF (no SVG).
///   .psd → PNG/JPEG/PDF: the composite image (ImageIO), or a copy saved by Photoshop.
///   PDF  → PNG/JPEG: PDFKit renders each page.
extension ConversionRunner {
    static let imageSources: Set<String> = ["ai", "psd", "pdf"]

    /// Every output of one input. Image formats give one file per artboard / page.
    func convertFiles(engine: URL, input: URL, folder: URL, options: ConversionOptions) throws -> [URL] {
        if isCancelled { throw CancellationError() }
        let ext = input.pathExtension.lowercased()
        if options.format.isImage { return try convertImage(input:input, folder:folder, options:options) }
        if ext == "psd" {
            guard options.format.id == "pdf" else { throw ImageExport.error("psdFormatUnsupported") }
            return [try convertPhotoshopPDF(input:input, folder:folder, options:options)]
        }
        return [try convert(engine:engine, input:input, folder:folder, options:options)]
    }

    /// Hidden scratch folder beside the outputs, so finished files are published by a same-volume move.
    private func scratchFolder(in folder: URL) throws -> URL {
        let temp = folder.appendingPathComponent(".PandocDesk-" + UUID().uuidString, isDirectory:true)
        try FileManager.default.createDirectory(at:temp, withIntermediateDirectories:false)
        return temp
    }

    private func report(_ notes: [IllustratorBridge.Note], for input: URL, photoshop: Bool = false) {
        let name = input.lastPathComponent + ": "
        if notes.contains(.unsaved) { addWarning(name + NSLocalizedString(photoshop ? "psdExportedUnsaved" : "aiExportedUnsaved", comment:"")) }
        else if notes.contains(.open) { addWarning(name + NSLocalizedString(photoshop ? "psdExportedOpen" : "aiExportedOpen", comment:"")) }
        if notes.contains(.links) { addWarning(name + NSLocalizedString("aiBrokenLinksImage", comment:"")) }
    }

    private func convertImage(input: URL, folder: URL, options: ConversionOptions) throws -> [URL] {
        let ext = input.pathExtension.lowercased()
        let svg = options.format.id == "svg"
        guard Self.imageSources.contains(ext) else { throw ImageExport.error(svg ? "svgInputUnsupported" : "imageInputUnsupported") }
        if svg && ext != "ai" { throw ImageExport.error("svgInputUnsupported") }
        let fm = FileManager.default
        let temp = try scratchFolder(in:folder)
        defer { try? fm.removeItem(at:temp) }
        let stem = input.deletingPathExtension().lastPathComponent
        switch ext {
        case "ai" where svg || options.aiMethod == "illustrator":
            return try exportWithIllustrator(input:input, stem:stem, folder:folder, temp:temp, options:options)
        case "ai":
            let pdf = temp.appendingPathComponent("embedded.pdf")
            let result = try AIImporter.writePDF(from:input, to:pdf, cancelled:{ self.isCancelled })
            if result.withoutPDFContent { addWarning(input.lastPathComponent + ": " + NSLocalizedString("aiWithoutPDF", comment:"")) }
            return try rasterize(pdf:pdf, stem:stem, folder:folder, temp:temp, options:options)
        case "pdf":
            return try rasterize(pdf:input, stem:stem, folder:folder, temp:temp, options:options)
        default:   // psd
            let (image, ppi) = try photoshopImage(input:input, temp:temp, options:options)
            if isCancelled { throw CancellationError() }
            let file = temp.appendingPathComponent("image." + options.raster.ext)
            try ImageExport.write(image, to:file, options:options.raster, ppi:ppi)
            let name = options.naming.name(stem:stem, index:1, total:1, label:nil)
            return [try ImageExport.publish(file, folder:folder, name:name, ext:options.raster.ext)]
        }
    }

    /// Illustrator writes PNG (transparent or white) or SVG per artboard; JPEG is encoded here from a white PNG,
    /// because Export for Screens has no JPEG quality setting.
    private func exportWithIllustrator(input: URL, stem: String, folder: URL, temp: URL, options: ConversionOptions) throws -> [URL] {
        guard let app = options.illustratorApp ?? IllustratorBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("illustratorMissing") }
        let svg = options.format.id == "svg"
        let jpeg = !svg && options.raster.type == "jpeg"
        let work = temp.appendingPathComponent("export", isDirectory:true)
        try FileManager.default.createDirectory(at:work, withIntermediateDirectories:false)
        let exported = try IllustratorBridge.exportImages(from:input, into:work, kind:svg ? "svg" : "png", range:options.raster.range, ppi:options.raster.ppi,
                                                          transparent:!jpeg && options.raster.transparent, svg:options.svg, app:app, isCancelled:{ self.isCancelled })
        report(exported.notes, for:input)
        var outputs: [URL] = []
        for artboard in exported.artboards {
            if isCancelled { throw CancellationError() }
            let name = options.naming.name(stem:stem, index:artboard.number, total:artboard.total, label:artboard.name)
            if jpeg {
                let file = temp.appendingPathComponent("ab\(artboard.number).jpg")
                try ImageExport.write(try ImageExport.readImage(artboard.file).image, to:file, options:options.raster, ppi:Double(options.raster.ppi))
                outputs.append(try ImageExport.publish(file, folder:folder, name:name, ext:"jpg"))
            } else {
                outputs.append(try ImageExport.publish(artboard.file, folder:folder, name:name, ext:svg ? "svg" : "png"))
            }
        }
        return outputs
    }

    private func rasterize(pdf: URL, stem: String, folder: URL, temp: URL, options: ConversionOptions) throws -> [URL] {
        guard let document = PDFDocument(url:pdf), document.pageCount > 0 else { throw ImageExport.error("pdfInputInvalid") }
        guard !document.isLocked else { throw ImageExport.error("pdfInputLocked") }
        let pages = try PageRange.parse(options.raster.range, count:document.pageCount)
        let opaque = options.raster.type == "jpeg" || !options.raster.transparent
        var outputs: [URL] = []
        for number in pages {
            if isCancelled { throw CancellationError() }
            guard let page = document.page(at:number - 1) else { throw ImageExport.error("pdfInputInvalid") }
            let image = try ImageExport.render(page:page, ppi:options.raster.ppi, transparent:!opaque)
            let file = temp.appendingPathComponent("page\(number)." + options.raster.ext)
            try ImageExport.write(image, to:file, options:options.raster, ppi:Double(options.raster.ppi))
            let name = options.naming.name(stem:stem, index:number, total:document.pageCount, label:nil)
            outputs.append(try ImageExport.publish(file, folder:folder, name:name, ext:options.raster.ext))
        }
        return outputs
    }

    /// The composite image of a .psd, read directly or from a PNG copy saved by Photoshop.
    private func photoshopImage(input: URL, temp: URL, options: ConversionOptions) throws -> (CGImage, Double) {
        guard options.psdMethod == "photoshop" else { return try ImageExport.readImage(input) }
        guard let app = options.photoshopApp ?? PhotoshopBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("photoshopMissing") }
        let png = temp.appendingPathComponent("photoshop.png")
        report(try PhotoshopBridge.saveCopy(from:input, to:png, kind:"png", app:app, isCancelled:{ self.isCancelled }), for:input, photoshop:true)
        return try ImageExport.readImage(png)
    }

    private func convertPhotoshopPDF(input: URL, folder: URL, options: ConversionOptions) throws -> URL {
        let temp = try scratchFolder(in:folder)
        defer { try? FileManager.default.removeItem(at:temp) }
        let pdf = temp.appendingPathComponent("result.pdf")
        if options.psdMethod == "photoshop" {
            guard let app = options.photoshopApp ?? PhotoshopBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("photoshopMissing") }
            report(try PhotoshopBridge.saveCopy(from:input, to:pdf, kind:"pdf", app:app, isCancelled:{ self.isCancelled }), for:input, photoshop:true)
        } else {
            let (image, ppi) = try ImageExport.readImage(input)
            try ImageExport.writePDF(image, ppi:ppi, to:pdf)
        }
        if isCancelled { throw CancellationError() }
        return try ImageExport.publish(pdf, folder:folder, name:input.deletingPathExtension().lastPathComponent, ext:"pdf")
    }
}
