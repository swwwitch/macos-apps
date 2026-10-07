import Foundation
import PDFKit

/// Image outputs (ラスター画像 / SVG), image-like inputs and subtitles.
///   .ai   → PNG/JPEG/HEIC/AVIF/SVG: Illustrator exports each artboard; the simple method rasterizes the embedded PDF (no SVG).
///   .psd  → image / PDF: the composite image (ImageIO), or a copy saved by Photoshop.
///   .indd → image / PDF: InDesign exports (InDesign required).
///   PDF   → image: PDFKit renders each page.
///   PNG/JPEG/TIFF/HEIC/WebP/GIF/BMP → image (format change, resize) / PDF (one page; several can be combined).
///   .srt  → CSV / TSV (SRTConverter).
extension ConversionRunner {
    /// A finished file in the scratch folder, waiting for its final name.
    private struct Pending { let file: URL; let name: String; let ext: String }

    /// Every output of one input. Image formats give one file per artboard / page.
    func convertFiles(engine: URL, input: URL, folder: URL, options: ConversionOptions) throws -> [URL] {
        if isCancelled { throw CancellationError() }
        if let reason = options.format.unsupportedReason(for:[input]) { throw ImageExport.error(reason) }
        let ext = input.pathExtension.lowercased()
        if options.format.id == "csv" { return [try SRTConverter.convert(input:input, folder:folder, delimiter:options.csvDelimiter)] }
        if options.format.isImage { return try convertImage(input:input, folder:folder, options:options) }
        if options.format.id == "pdf" && OutputFormat.imageOnlyInputs.contains(ext) { return [try convertToPDF(input:input, folder:folder, options:options)] }
        return [try convert(engine:engine, input:input, folder:folder, options:options)]
    }

    /// Hidden scratch folder beside the outputs, so finished files are published by a same-volume move.
    private func scratchFolder(in folder: URL) throws -> URL {
        let temp = folder.appendingPathComponent(".PandocDesk-" + UUID().uuidString, isDirectory:true)
        try FileManager.default.createDirectory(at:temp, withIntermediateDirectories:false)
        return temp
    }

    private func report(_ notes: [IllustratorBridge.Note], for input: URL, app: String = "ai") {
        let name = input.lastPathComponent + ": "
        if notes.contains(.unsaved) { addWarning(name + NSLocalizedString(app + "ExportedUnsaved", comment:"")) }
        else if notes.contains(.open) { addWarning(name + NSLocalizedString(app + "ExportedOpen", comment:"")) }
        if notes.contains(.links) { addWarning(name + NSLocalizedString("aiBrokenLinksImage", comment:"")) }
    }

    /// Several outputs go into a folder named after the source when 「フォルダーにまとめる」 is on.
    private func publish(_ pending: [Pending], folder: URL, stem: String, options: ConversionOptions) throws -> [URL] {
        let target = options.naming.groupInFolder && pending.count > 1 ? try ImageExport.makeFolder(in:folder, name:FileNaming.sanitize(stem)) : folder
        return try pending.map { try ImageExport.publish($0.file, folder:target, name:$0.name, ext:$0.ext) }
    }

    private func convertImage(input: URL, folder: URL, options: ConversionOptions) throws -> [URL] {
        let ext = input.pathExtension.lowercased()
        let svg = options.format.id == "svg"
        let temp = try scratchFolder(in:folder)
        defer { try? FileManager.default.removeItem(at:temp) }
        let stem = input.deletingPathExtension().lastPathComponent
        let pending: [Pending]
        switch ext {
        case "ai" where svg || options.aiMethod == "illustrator":
            pending = try exportWithIllustrator(input:input, stem:stem, temp:temp, options:options)
        case "ai":
            let pdf = temp.appendingPathComponent("embedded.pdf")
            let result = try AIImporter.writePDF(from:input, to:pdf, cancelled:{ self.isCancelled })
            if result.withoutPDFContent { addWarning(input.lastPathComponent + ": " + NSLocalizedString("aiWithoutPDF", comment:"")) }
            pending = try rasterize(pdf:pdf, stem:stem, temp:temp, options:options)
        case "pdf":
            pending = try rasterize(pdf:input, stem:stem, temp:temp, options:options)
        case "indd":
            pending = try exportWithInDesign(input:input, stem:stem, temp:temp, options:options)
        default:   // .psd and raster images: one image
            let (image, ppi) = try sourceImage(input:input, temp:temp, options:options)
            if isCancelled { throw CancellationError() }
            let file = temp.appendingPathComponent("image." + options.raster.ext)
            try ImageExport.write(image, to:file, options:options.raster, ppi:ppi)
            pending = [Pending(file:file, name:options.naming.name(stem:stem, index:1, total:1, label:nil), ext:options.raster.ext)]
        }
        if isCancelled { throw CancellationError() }
        return try publish(pending, folder:folder, stem:stem, options:options)
    }

    /// An image from Illustrator / InDesign (PNG at the requested size): PNG stays as is, other types are re-encoded.
    private func encodeExported(_ png: URL, as name: String, temp: URL, options: ConversionOptions) throws -> Pending {
        guard options.raster.type != "png" else { return Pending(file:png, name:name, ext:"png") }
        let (image, ppi) = try ImageExport.readImage(png)
        let file = temp.appendingPathComponent(UUID().uuidString + "." + options.raster.ext)
        try ImageExport.write(image, to:file, options:options.raster, ppi:ppi)
        return Pending(file:file, name:name, ext:options.raster.ext)
    }

    /// Illustrator writes PNG (transparent or white) or SVG per artboard; other image types are encoded here,
    /// because Export for Screens has no quality setting for them.
    private func exportWithIllustrator(input: URL, stem: String, temp: URL, options: ConversionOptions) throws -> [Pending] {
        guard let app = options.illustratorApp ?? IllustratorBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("illustratorMissing") }
        let svg = options.format.id == "svg"
        let work = temp.appendingPathComponent("export", isDirectory:true)
        try FileManager.default.createDirectory(at:work, withIntermediateDirectories:false)
        let exported = try IllustratorBridge.exportImages(from:input, into:work, kind:svg ? "svg" : "png", raster:options.raster,
                                                          transparent:options.raster.keepsAlpha, svg:options.svg, app:app, isCancelled:{ self.isCancelled })
        report(exported.notes, for:input)
        return try exported.artboards.map { artboard in
            if isCancelled { throw CancellationError() }
            let name = options.naming.name(stem:stem, index:artboard.number, total:artboard.total, label:artboard.name)
            return svg ? Pending(file:artboard.file, name:name, ext:"svg") : try encodeExported(artboard.file, as:name, temp:temp, options:options)
        }
    }

    private func exportWithInDesign(input: URL, stem: String, temp: URL, options: ConversionOptions) throws -> [Pending] {
        guard let app = options.indesignApp ?? InDesignBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("indesignMissing") }
        let work = temp.appendingPathComponent("export", isDirectory:true)
        try FileManager.default.createDirectory(at:work, withIntermediateDirectories:false)
        let exported = try InDesignBridge.export(from:input, into:work, kind:"png", raster:options.raster, transparent:options.raster.keepsAlpha,
                                                 preset:"", app:app, isCancelled:{ self.isCancelled })
        report(exported.notes, for:input, app:"indesign")
        return try exported.pages.map { page in
            if isCancelled { throw CancellationError() }
            return try encodeExported(page.file, as:options.naming.name(stem:stem, index:page.number, total:page.total, label:page.name), temp:temp, options:options)
        }
    }

    private func rasterize(pdf: URL, stem: String, temp: URL, options: ConversionOptions) throws -> [Pending] {
        guard let document = PDFDocument(url:pdf), document.pageCount > 0 else { throw ImageExport.error("pdfInputInvalid") }
        guard !document.isLocked else { throw ImageExport.error("pdfInputLocked") }
        let pages = try PageRange.parse(options.raster.range, count:document.pageCount)
        return try pages.map { number in
            if isCancelled { throw CancellationError() }
            guard let page = document.page(at:number - 1) else { throw ImageExport.error("pdfInputInvalid") }
            let image = try ImageExport.render(page:page, options:options.raster, transparent:options.raster.keepsAlpha)
            let file = temp.appendingPathComponent("page\(number)." + options.raster.ext)
            try ImageExport.write(image, to:file, options:options.raster, ppi:options.raster.recordedPPI)
            return Pending(file:file, name:options.naming.name(stem:stem, index:number, total:document.pageCount, label:nil), ext:options.raster.ext)
        }
    }

    /// The image of a .psd (directly or from a PNG copy saved by Photoshop) or of a raster file, resized for
    /// 幅 / 高さ; 解像度 keeps the source pixels and resolution.
    private func sourceImage(input: URL, temp: URL, options: ConversionOptions) throws -> (CGImage, Double) {
        var (image, ppi) = try photoshopImage(input:input, temp:temp, options:options)
        let raster = options.raster
        guard raster.sizeMode != "ppi" else { return (image, ppi) }
        let scale = raster.scale(for:CGSize(width:image.width, height:image.height))
        image = try ImageExport.resized(image, width:max(1, Int((CGFloat(image.width) * scale).rounded())), height:max(1, Int((CGFloat(image.height) * scale).rounded())))
        ppi = raster.recordedPPI
        return (image, ppi)
    }

    private func photoshopImage(input: URL, temp: URL, options: ConversionOptions) throws -> (CGImage, Double) {
        guard input.pathExtension.lowercased() == "psd", options.psdMethod == "photoshop" else { return try ImageExport.readImage(input) }
        guard let app = options.photoshopApp ?? PhotoshopBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("photoshopMissing") }
        let png = temp.appendingPathComponent("photoshop.png")
        report(try PhotoshopBridge.saveCopy(from:input, to:png, kind:"png", app:app, isCancelled:{ self.isCancelled }), for:input, app:"psd")
        return try ImageExport.readImage(png)
    }

    /// .psd / .indd / raster image → PDF.
    private func convertToPDF(input: URL, folder: URL, options: ConversionOptions) throws -> URL {
        let temp = try scratchFolder(in:folder)
        defer { try? FileManager.default.removeItem(at:temp) }
        var pdf = temp.appendingPathComponent("result.pdf")
        switch input.pathExtension.lowercased() {
        case "indd":
            guard let app = options.indesignApp ?? InDesignBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("indesignMissing") }
            let work = temp.appendingPathComponent("export", isDirectory:true)
            try FileManager.default.createDirectory(at:work, withIntermediateDirectories:false)
            report(try InDesignBridge.export(from:input, into:work, kind:"pdf", raster:RasterOptions(), transparent:false, preset:options.indesignPreset,
                                             app:app, isCancelled:{ self.isCancelled }).notes, for:input, app:"indesign")
            pdf = work.appendingPathComponent("result.pdf")
        case "psd" where options.psdMethod == "photoshop":
            guard let app = options.photoshopApp ?? PhotoshopBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("photoshopMissing") }
            report(try PhotoshopBridge.saveCopy(from:input, to:pdf, kind:"pdf", app:app, isCancelled:{ self.isCancelled }), for:input, app:"psd")
        default:
            let (image, ppi) = try ImageExport.readImage(input)
            try ImageExport.writePDF([(image, ppi)], to:pdf)
        }
        if isCancelled { throw CancellationError() }
        return try ImageExport.publish(pdf, folder:folder, name:input.deletingPathExtension().lastPathComponent, ext:"pdf")
    }

    /// Raster images → one PDF, a page per image in the given order, named after the first file.
    func combineImagesToPDF(_ inputs: [URL], folder: URL) throws -> URL {
        var pages: [(CGImage, Double)] = []
        for input in inputs {
            if isCancelled { throw CancellationError() }
            pages.append(try ImageExport.readImage(input))
        }
        let temp = try scratchFolder(in:folder)
        defer { try? FileManager.default.removeItem(at:temp) }
        let pdf = temp.appendingPathComponent("result.pdf")
        try ImageExport.writePDF(pages, to:pdf)
        if isCancelled { throw CancellationError() }
        return try ImageExport.publish(pdf, folder:folder, name:inputs[0].deletingPathExtension().lastPathComponent, ext:"pdf")
    }
}
