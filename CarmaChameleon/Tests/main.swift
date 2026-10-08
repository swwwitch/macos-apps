import Foundation
import PDFKit
import CoreText
import ImageIO
setbuf(stdout, nil)
func L(_ key: String) -> String { key }
let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("PandocDesk-tests-"+UUID().uuidString)
try fm.createDirectory(at:root,withIntermediateDirectories:true)
defer { try? fm.removeItem(at:root) }
let engine = URL(fileURLWithPath:CommandLine.arguments[1])
let input = root.appendingPathComponent("日本語 sample.md")
let original = "# 日本語タイトル\n\nHello **world**.\n\n## Second\n\n- First\n- Second\n"
try original.write(to:input,atomically:true,encoding:.utf8)
func check(_ value:Bool,_ message:String) { if !value { fatalError(message) }; print("PASS: " + message) }
var options = ConversionOptions()
for format in OutputFormat.all where !["pdf","keynote","csv"].contains(format.id) && !format.isImage {
    options.format = format
    let output = try ConversionRunner().convert(engine:engine,input:input,folder:root,options:options)
    check(fm.fileExists(atPath:output.path),"output \(format.id)")
    check((try fm.attributesOfItem(atPath:output.path)[.size] as! NSNumber).intValue > 0,"nonempty \(format.id)")
}
check(try String(contentsOf:input) == original,"source remains intact")
// Tables: CSV / TSV via pandoc; XLSX via XLSXImporter (integers without ".0", dates as yyyy/MM/dd, formula results).
let fixtures = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Tests/Fixtures")
var gfm = ConversionOptions(); gfm.format = OutputFormat.all.first { $0.id == "gfm" }!
for name in ["sample.csv","sample.tsv","sample.xlsx"] {
    let copy = root.appendingPathComponent(name); try? fm.removeItem(at:copy); try fm.copyItem(at:fixtures.appendingPathComponent(name),to:copy)
    let text = try String(contentsOf:try ConversionRunner().convert(engine:engine,input:copy,folder:root,options:gfm),encoding:.utf8)
    check(text.contains("| りんご") && text.contains("|---"),"\(name) → Markdown table")
    if name.hasSuffix("xlsx") {
        check(text.contains("| 120 ") && !text.contains("120.0") && text.contains("12.5") && text.contains("360") && text.contains("250"),"xlsx numbers and formula results as shown in Excel")
        check(text.contains("2026/10/07") && text.contains("2026/10/08 12:00"),"xlsx dates from cell format")
        check(text.contains("売上"),"xlsx sheet name as heading")
        var docx = ConversionOptions(); docx.format = OutputFormat.all.first { $0.id == "docx" }!
        check(fm.fileExists(atPath:try ConversionRunner().convert(engine:engine,input:copy,folder:root,options:docx).path),"xlsx → Word")
        var structuredTable = ConversionOptions(); structuredTable.format = OutputFormat.all.first { $0.id == "plain" }!; var tableOptions = MarkdownTextOptions(); tableOptions.tableMode = .ascii; structuredTable.markdownText = tableOptions
        let boxed = try String(contentsOf:try ConversionRunner().convert(engine:engine,input:copy,folder:root,options:structuredTable),encoding:.utf8)
        check(boxed.contains("+--") && boxed.contains("| りんご"),"xlsx → structured text with bordered table")
    }
}
// Illustrator (.ai), simple version: the embedded PDF is rewritten; a notice page (no PDF compatibility) gives a warning.
func makeAI(_ name: String, text: String) -> URL {
    let url = root.appendingPathComponent(name)
    var box = CGRect(x:0,y:0,width:900,height:300)
    let ctx = CGContext(url as CFURL, mediaBox:&box, nil)!
    ctx.beginPDFPage(nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string:text, attributes:[NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("Helvetica" as CFString, 18, nil)]))
    ctx.textPosition = CGPoint(x:20,y:150); CTLineDraw(line, ctx)
    ctx.endPDFPage(); ctx.closePDF()
    return url
}
var pdfOut = ConversionOptions(); pdfOut.format = OutputFormat.all.first { $0.id == "pdf" }!
let artwork = makeAI("artwork.ai", text:"Artwork sample")
let aiRunner = ConversionRunner()
let aiPDF = try aiRunner.convert(engine:engine,input:artwork,folder:root,options:pdfOut)
check(aiPDF.lastPathComponent == "artwork.pdf" && PDFDocument(url:aiPDF)?.string?.contains("Artwork sample") == true,".ai → PDF keeps the artwork (not re-typeset)")
check(aiRunner.warnings.isEmpty,"PDF-compatible .ai has no warning")
let notice = makeAI("notice.ai", text:"This is an Adobe Illustrator File that was saved without PDF Content.")
let noticeRunner = ConversionRunner()
_ = try noticeRunner.convert(engine:engine,input:notice,folder:root,options:pdfOut)
check(noticeRunner.warnings.count == 1 && noticeRunner.warnings[0].hasPrefix("notice.ai"),".ai without PDF compatibility is converted with a warning")
let aiText = try String(contentsOf:try ConversionRunner().convert(engine:engine,input:artwork,folder:root,options:gfm),encoding:.utf8)
check(aiText.contains("Artwork sample"),".ai → Markdown via the embedded PDF text")
// Opt-in: official .ai → PDF through Illustrator (CARMA_ILLUSTRATOR_TEST=1; launches Illustrator).
if ProcessInfo.processInfo.environment["CARMA_ILLUSTRATOR_TEST"] == "1", let app = IllustratorBridge.defaultInstallation() {
    IllustratorBridge.scriptsDirectory = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
    let presets = try IllustratorBridge.presets(in:app.url)
    print("INFO: \(app.name) \(app.version) presets:", presets.joined(separator:" / "))
    check(!presets.isEmpty,"Illustrator PDF presets listed")
    let sample = URL(fileURLWithPath:"/Applications/Adobe Illustrator (Beta)/Scripting.localized/Sample Scripts.localized/AppleScript.localized/Analyze Documents.localized/Documents to Analyze.localized/GradientTestFile.ai")
    let copy = root.appendingPathComponent("IllustratorExport.ai"); try? fm.removeItem(at:copy); try fm.copyItem(at:sample,to:copy)
    var official = pdfOut; official.aiMethod = "illustrator"; official.aiPreset = presets.last!; official.illustratorApp = app.url
    let out = try ConversionRunner().convert(engine:engine,input:copy,folder:root,options:official)
    check(out.lastPathComponent == "IllustratorExport.pdf" && (PDFDocument(url:out)?.pageCount ?? 0) > 0,"Illustrator saved the .ai as PDF with preset \(presets.last!)")
    // A document already open in Illustrator is exported as it is, stays open, and gives a notice.
    _ = try IllustratorBridge.run("app.open(new File(arguments[0])); 'OK'", arguments:[copy.path], in:app.url)
    let openRunner = ConversionRunner()
    let openOut = try openRunner.convert(engine:engine,input:copy,folder:root,options:official)
    let stillOpen = try IllustratorBridge.run("var r='no'; for (var i=0;i<app.documents.length;i++) { if (app.documents[i].fullName.fsName==new File(arguments[0]).fsName) { r='yes'; app.documents[i].close(SaveOptions.DONOTSAVECHANGES); break; } } r", arguments:[copy.path], in:app.url)
    check((PDFDocument(url:openOut)?.pageCount ?? 0) > 0 && stillOpen == "yes" && openRunner.warnings.count == 1,"open Illustrator document exported, kept open, with a notice")
}
// Image outputs: file naming, ranges, PDF → PNG / JPEG, simple .ai and .psd (no Adobe apps needed).
do {
    var n = FileNaming()
    check(n.name(stem:"a", index:2, total:3, label:"Cover") == "a-2","naming: file + number")
    check(n.name(stem:"a", index:1, total:1, label:"Cover") == "a","naming: single image keeps the file name")
    n.useLabel = true; n.padNumber = true; n.delimiter = "_"
    check(n.name(stem:"a", index:2, total:12, label:"Cover/表紙") == "a_02_Cover_表紙","naming: number, padding, artboard name, sanitized")
    n.useNumber = false; n.useFileName = false
    check(n.name(stem:"a", index:2, total:3, label:"Cover") == "Cover","naming: artboard name only")
    check(n.name(stem:"a", index:2, total:3, label:nil) == "02","naming: falls back to the number without a name")
    check(try PageRange.parse("", count:3) == [1,2,3] && (try PageRange.parse(" 3, 1-2，2 ", count:5)) == [3,1,2] && (try PageRange.parse("4-", count:6)) == [4,5,6],"range parsing")
    check((try? PageRange.parse("5", count:3)) == nil && (try? PageRange.parse("2-1", count:3)) == nil && (try? PageRange.parse("a", count:3)) == nil,"invalid ranges rejected")
}
func makePDF(_ name: String, pages: [CGSize]) -> URL {
    let url = root.appendingPathComponent(name)
    let ctx = CGContext(url as CFURL, mediaBox:nil, nil)!
    for size in pages {
        var box = CGRect(origin:.zero, size:size)
        ctx.beginPage(mediaBox:&box)
        ctx.setFillColor(CGColor(red:1, green:0, blue:0, alpha:1)); ctx.fill(CGRect(x:10, y:10, width:20, height:20))
        ctx.endPage()
    }
    ctx.closePDF()
    return url
}
func imageInfo(_ url: URL) -> (w: Int, h: Int, dpi: Double, alpha: Bool) {
    let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    return ((p[kCGImagePropertyPixelWidth] as! NSNumber).intValue, (p[kCGImagePropertyPixelHeight] as! NSNumber).intValue,
            (p[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 0, ![.none, .noneSkipFirst, .noneSkipLast].contains(img.alphaInfo))
}
let imageFolder = root.appendingPathComponent("images"); try fm.createDirectory(at:imageFolder, withIntermediateDirectories:true)
let threePages = makePDF("pages.pdf", pages:[CGSize(width:100, height:50), CGSize(width:200, height:100), CGSize(width:72, height:72)])
var raster = ConversionOptions(); raster.format = OutputFormat.all.first { $0.id == "image" }!; raster.raster.ppi = 144
let pngs = try ConversionRunner().convertFiles(engine:engine, input:threePages, folder:imageFolder, options:raster)
check(pngs.map(\.lastPathComponent) == ["pages-1.png","pages-2.png","pages-3.png"],"PDF → one PNG per page")
let first = imageInfo(pngs[0]); check(first.w == 200 && first.h == 100 && first.dpi == 144 && first.alpha,"PNG at 144 ppi, transparent, resolution recorded")
raster.raster.type = "jpeg"; raster.raster.range = "2"; raster.naming.padNumber = true
let jpgs = try ConversionRunner().convertFiles(engine:engine, input:threePages, folder:imageFolder, options:raster)
let second = imageInfo(jpgs[0]); check(jpgs.map(\.lastPathComponent) == ["pages-02.jpg"] && second.w == 400 && !second.alpha,"PDF page range → JPEG on white, padded number")
check(((try? ConversionRunner().convertFiles(engine:engine, input:input, folder:imageFolder, options:raster)) == nil),"Markdown → raster image is refused")
var svgOut = ConversionOptions(); svgOut.format = OutputFormat.all.first { $0.id == "svg" }!
check(((try? ConversionRunner().convertFiles(engine:engine, input:threePages, folder:imageFolder, options:svgOut)) == nil),"PDF → SVG is refused")
raster.raster = RasterOptions(); raster.naming = FileNaming()
let aiPNG = try ConversionRunner().convertFiles(engine:engine, input:artwork, folder:imageFolder, options:raster)
check(aiPNG.map(\.lastPathComponent) == ["artwork.png"] && imageInfo(aiPNG[0]).w == 1800,".ai (simple) → PNG from the embedded PDF")
let psd = root.appendingPathComponent("sample.psd"); try fm.copyItem(at:fixtures.appendingPathComponent("sample.psd"), to:psd)
let psdPNG = try ConversionRunner().convertFiles(engine:engine, input:psd, folder:imageFolder, options:raster)
let psdInfo = imageInfo(psdPNG[0]); check(psdPNG.map(\.lastPathComponent) == ["sample.png"] && psdInfo.w == 300 && psdInfo.dpi == 150 && psdInfo.alpha,".psd (simple) → PNG keeps pixels, resolution and transparency")
let psdPDF = try ConversionRunner().convertFiles(engine:engine, input:psd, folder:imageFolder, options:pdfOut)
let psdBox = PDFDocument(url:psdPDF[0])!.page(at:0)!.bounds(for:.mediaBox)
check(psdBox.width == 144 && psdBox.height == 96,".psd (simple) → PDF at its physical size")
check(((try? ConversionRunner().convertFiles(engine:engine, input:psd, folder:imageFolder, options:gfm)) == nil),".psd → Markdown is refused")
// Size by width / height, HEIC / AVIF, grouping into a folder.
var sized = ConversionOptions(); sized.format = OutputFormat.all.first { $0.id == "image" }!
sized.raster.sizeMode = "width"; sized.raster.width = 300
let widthPNG = try ConversionRunner().convertFiles(engine:engine, input:threePages, folder:imageFolder, options:{ var o = sized; o.raster.range = "2"; return o }())
check(imageInfo(widthPNG[0]).w == 300 && imageInfo(widthPNG[0]).h == 150 && imageInfo(widthPNG[0]).dpi == 72,"PDF → PNG by width (300 px)")
sized.raster.sizeMode = "height"; sized.raster.height = 60; sized.naming.groupInFolder = true
let grouped = try ConversionRunner().convertFiles(engine:engine, input:threePages, folder:imageFolder, options:sized)
check(grouped.count == 3 && grouped.allSatisfy { $0.deletingLastPathComponent().lastPathComponent == "pages" } && imageInfo(grouped[0]).h == 60,"several images grouped in a folder named after the source, by height")
let single = try ConversionRunner().convertFiles(engine:engine, input:artwork, folder:imageFolder, options:sized)
check(single[0].deletingLastPathComponent().path == imageFolder.path,"a single image is not put in a folder")
for type in RasterOptions.availableTypes where type.id != "png" {
    var o = ConversionOptions(); o.format = sized.format; o.raster.type = type.id; o.raster.range = "1"
    let out = try ConversionRunner().convertFiles(engine:engine, input:threePages, folder:imageFolder, options:o)
    check(out[0].pathExtension == type.ext && imageInfo(out[0]).w == 200,"PDF → \(type.name)")
}
// Raster image inputs: format change and resize, upright by EXIF orientation; images → PDF, one or combined.
func makeJPEG(_ name: String, width: Int, height: Int, orientation: Int) -> URL {
    let url = root.appendingPathComponent(name)
    let ctx = CGContext(data:nil, width:width, height:height, bitsPerComponent:8, bytesPerRow:0, space:CGColorSpace(name:CGColorSpace.sRGB)!, bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(CGColor(red:0, green:0, blue:1, alpha:1)); ctx.fill(CGRect(x:0, y:0, width:width, height:height))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyOrientation: orientation, kCGImagePropertyDPIWidth: 300, kCGImagePropertyDPIHeight: 300] as CFDictionary)
    CGImageDestinationFinalize(dest)
    return url
}
let photo = makeJPEG("photo.jpg", width:400, height:200, orientation:6)   // stored landscape, shown portrait
var toPNG = ConversionOptions(); toPNG.format = sized.format
let photoPNG = try ConversionRunner().convertFiles(engine:engine, input:photo, folder:imageFolder, options:toPNG)
let photoInfo = imageInfo(photoPNG[0]); check(photoPNG[0].lastPathComponent == "photo.png" && photoInfo.w == 200 && photoInfo.h == 400 && photoInfo.dpi == 300,"JPEG → PNG upright, pixels and resolution kept")
toPNG.raster.sizeMode = "width"; toPNG.raster.width = 100
check(imageInfo(try ConversionRunner().convertFiles(engine:engine, input:photo, folder:imageFolder, options:toPNG)[0]).h == 200,"image resized by width")
let photo2 = makeJPEG("photo2.jpg", width:600, height:300, orientation:1)
let onePDF = try ConversionRunner().convertFiles(engine:engine, input:photo2, folder:imageFolder, options:pdfOut)
check(PDFDocument(url:onePDF[0])!.page(at:0)!.bounds(for:.mediaBox).width == 144,"image → PDF at its physical size")
let combined = try ConversionRunner().combineImagesToPDF([photo2, photo], folder:imageFolder)
check(combined.lastPathComponent == "photo2 (1).pdf" && PDFDocument(url:combined)?.pageCount == 2 && PDFDocument(url:combined)!.page(at:1)!.bounds(for:.mediaBox).height == 96,"images combined into one PDF in order")
// Which formats each input can become.
let fmt = { (id: String) in OutputFormat.all.first { $0.id == id }! }
check(fmt("docx").unsupportedReason(for:[photo]) == "documentFormatUnsupported" && fmt("pdf").unsupportedReason(for:[photo, psd]) == nil && fmt("image").unsupportedReason(for:[photo, input]) == "imageInputUnsupported" && fmt("svg").unsupportedReason(for:[artwork]) == nil && fmt("svg").unsupportedReason(for:[psd]) == "svgInputUnsupported" && fmt("docx").unsupportedReason(for:[input]) == nil,"format compatibility by input")
// Subtitles → CSV / TSV.
let srt = root.appendingPathComponent("chat.srt")
try "\u{FEFF}1\r\n00:00:05,120 --> 00:00:07,000\r\nalice: hello, world\r\n\r\n2\r\n01:02:03,000 --> 01:02:04,000\r\nbob: a: b\r\nsecond line\r\n\r\n3\r\n00:10:00,000 --> 00:10:01,000\r\nno handle here\r\n".write(to:srt, atomically:true, encoding:.utf8)
var csvOut = ConversionOptions(); csvOut.format = fmt("csv")
let csv = try String(contentsOf:try ConversionRunner().convertFiles(engine:engine, input:srt, folder:imageFolder, options:csvOut)[0], encoding:.utf8)
check(csv == "#,srtTime,srtHandle,srtComment\n1,00:00:05,alice,\"hello, world\"\n2,01:02:03,bob,a: b second line\n3,00:10:00,,no handle here\n","SRT → CSV (quoted, handle at the first \": \", multi-line joined)")
csvOut.csvDelimiter = "\t"
let tsv = try ConversionRunner().convertFiles(engine:engine, input:srt, folder:imageFolder, options:csvOut)[0]
check(try tsv.pathExtension == "tsv" && (String(contentsOf:tsv, encoding:.utf8)).contains("1\t00:00:05\talice\thello, world"),"SRT → TSV")
check(fmt("docx").unsupportedReason(for:[srt]) == "srtFormatUnsupported" && fmt("csv").unsupportedReason(for:[input]) == "csvInputUnsupported","SRT only to CSV")
// Opt-in: InDesign pages → PNG / PDF (CARMA_INDESIGN_TEST=1; launches InDesign).
if ProcessInfo.processInfo.environment["CARMA_INDESIGN_TEST"] == "1", let app = InDesignBridge.defaultInstallation() {
    IllustratorBridge.scriptsDirectory = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
    let indd = root.appendingPathComponent("ページ.indd")
    _ = try IllustratorBridge.run("""
    var level = app.scriptPreferences.userInteractionLevel; app.scriptPreferences.userInteractionLevel = UserInteractionLevels.NEVER_INTERACT;
    var unit = app.scriptPreferences.measurementUnit; app.scriptPreferences.measurementUnit = MeasurementUnits.POINTS;
    var d = app.documents.add(false); d.documentPreferences.facingPages = false; d.documentPreferences.pagesPerDocument = 3;
    d.documentPreferences.pageWidth = 200; d.documentPreferences.pageHeight = 300;
    var r = d.pages[1].rectangles.add(); r.geometricBounds = [10, 10, 50, 50]; r.fillColor = d.swatches.itemByName("Black");
    d.save(new File(arguments[0])); d.close(SaveOptions.NO);
    app.scriptPreferences.userInteractionLevel = level; app.scriptPreferences.measurementUnit = unit; 'OK'
    """, arguments:[indd.path], in:app.url, terms:InDesignBridge.bundleID)
    let presets = try InDesignBridge.presets(in:app.url)
    check(!presets.isEmpty,"InDesign PDF presets listed")
    var o = ConversionOptions(); o.format = fmt("image"); o.indesignApp = app.url; o.raster.ppi = 144; o.raster.range = "2-3"
    let pages = try ConversionRunner().convertFiles(engine:engine, input:indd, folder:imageFolder, options:o)
    check(pages.map(\.lastPathComponent) == ["ページ-2.png","ページ-3.png"] && imageInfo(pages[0]).w == 400 && imageInfo(pages[0]).h == 600,"InDesign → PNG per page at 144 ppi")
    o.raster.type = "jpeg"; o.raster.sizeMode = "width"; o.raster.width = 100; o.raster.range = "1"
    let jpg = try ConversionRunner().convertFiles(engine:engine, input:indd, folder:imageFolder, options:o)
    check(jpg[0].pathExtension == "jpg" && abs(imageInfo(jpg[0]).w - 100) <= 1,"InDesign → JPEG by width")
    var p = ConversionOptions(); p.format = pdfOut.format; p.indesignApp = app.url; p.indesignPreset = presets[0]
    let pdf = try ConversionRunner().convertFiles(engine:engine, input:indd, folder:imageFolder, options:p)
    check(PDFDocument(url:pdf[0])?.pageCount == 3,"InDesign → PDF with preset \(presets[0])")
}
// Opt-in: Illustrator per-artboard PNG / JPEG / SVG (CARMA_ILLUSTRATOR_TEST=1; launches Illustrator).
if ProcessInfo.processInfo.environment["CARMA_ILLUSTRATOR_TEST"] == "1", let app = IllustratorBridge.defaultInstallation() {
    IllustratorBridge.scriptsDirectory = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
    let boards = root.appendingPathComponent("アートボード.ai")
    _ = try IllustratorBridge.run("""
    var level = app.userInteractionLevel; app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS;
    var d = app.documents.add(DocumentColorSpace.RGB, 200, 100); d.artboards.add([300, 0, 400, -50]); d.artboards.add([500, 0, 600, -100]);
    d.artboards[0].name = "Cover/表紙"; d.artboards[1].name = "Back"; d.artboards[2].name = "Third";
    d.pathItems.rectangle(-10, 10, 50, 50); d.textFrames.pointText([310, -30]).contents = "Text";
    d.saveAs(new File(arguments[0]), new IllustratorSaveOptions()); d.close(SaveOptions.DONOTSAVECHANGES); app.userInteractionLevel = level; 'OK'
    """, arguments:[boards.path], in:app.url)
    var official = raster; official.aiMethod = "illustrator"; official.illustratorApp = app.url; official.raster.ppi = 144
    official.naming.useLabel = true
    let out = try ConversionRunner().convertFiles(engine:engine, input:boards, folder:imageFolder, options:official)
    check(out.map(\.lastPathComponent) == ["アートボード-1-Cover_表紙.png","アートボード-2-Back.png","アートボード-3-Third.png"],"Illustrator → PNG per artboard with names: \(out.map(\.lastPathComponent))")
    let b2 = imageInfo(out[1]); check(b2.w == 200 && b2.h == 100 && b2.dpi == 144 && b2.alpha,"Illustrator PNG at 144 ppi, transparent")
    official.raster.type = "jpeg"; official.raster.range = "3,1"; official.raster.quality = 60
    let jpeg = try ConversionRunner().convertFiles(engine:engine, input:boards, folder:imageFolder, options:official)
    check(jpeg.map(\.lastPathComponent) == ["アートボード-3-Third.jpg","アートボード-1-Cover_表紙.jpg"] && !imageInfo(jpeg[0]).alpha && imageInfo(jpeg[0]).dpi == 144,"Illustrator → JPEG in range order, on white")
    var byWidth = official; byWidth.raster.type = "png"; byWidth.raster.sizeMode = "width"; byWidth.raster.width = 300; byWidth.raster.range = "1"; byWidth.naming.groupInFolder = true
    let widthOut = try ConversionRunner().convertFiles(engine:engine, input:boards, folder:imageFolder, options:byWidth)
    check(imageInfo(widthOut[0]).w == 300 && imageInfo(widthOut[0]).h == 150 && widthOut[0].deletingLastPathComponent().path == imageFolder.path,"Illustrator → PNG by width (300 px), single image not grouped")
    official.raster.range = "9"
    check(((try? ConversionRunner().convertFiles(engine:engine, input:boards, folder:imageFolder, options:official)) == nil),"Illustrator range beyond the artboards is refused")
    var svgAI = official; svgAI.format = OutputFormat.all.first { $0.id == "svg" }!; svgAI.raster.range = "2"; svgAI.svg.font = "OUTLINEFONT"; svgAI.naming.useLabel = false
    let svgs = try ConversionRunner().convertFiles(engine:engine, input:boards, folder:imageFolder, options:svgAI)
    let svgText = try String(contentsOf:svgs[0], encoding:.utf8)
    check(svgs.map(\.lastPathComponent) == ["アートボード-2.svg"] && svgText.contains("<svg") && !svgText.contains("<text"),"Illustrator → SVG of one artboard, text outlined")
}
// Opt-in: Photoshop copy as PNG / PDF (CARMA_PHOTOSHOP_TEST=1; launches Photoshop).
if ProcessInfo.processInfo.environment["CARMA_PHOTOSHOP_TEST"] == "1", let app = PhotoshopBridge.defaultInstallation() {
    IllustratorBridge.scriptsDirectory = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
    var official = raster; official.psdMethod = "photoshop"; official.photoshopApp = app.url
    let png = try ConversionRunner().convertFiles(engine:engine, input:psd, folder:imageFolder, options:official)
    let info = imageInfo(png[0]); check(info.w == 300 && info.dpi == 150 && info.alpha,"Photoshop → PNG")
    official.format = pdfOut.format
    let pdf = try ConversionRunner().convertFiles(engine:engine, input:psd, folder:imageFolder, options:official)
    check((PDFDocument(url:pdf[0])?.pageCount ?? 0) == 1,"Photoshop → PDF")
    // CMYK cannot be saved as PNG: a converted duplicate is saved and the user's document is left as it was.
    let cmyk = root.appendingPathComponent("cmyk.psd")
    _ = try IllustratorBridge.run("""
    var dialogs = app.displayDialogs; app.displayDialogs = DialogModes.NO; var units = app.preferences.rulerUnits; app.preferences.rulerUnits = Units.PIXELS;
    var d = app.documents.add(120, 80, 300, "cmyk", NewDocumentMode.CMYK, DocumentFill.WHITE);
    d.saveAs(new File(arguments[0]), new PhotoshopSaveOptions(), true); d.close(SaveOptions.DONOTSAVECHANGES);
    app.preferences.rulerUnits = units; app.displayDialogs = dialogs; 'OK'
    """, arguments:[cmyk.path], in:app.url, terms:PhotoshopBridge.bundleID)
    official.format = raster.format
    let cmykPNG = try ConversionRunner().convertFiles(engine:engine, input:cmyk, folder:imageFolder, options:official)
    check(imageInfo(cmykPNG[0]).w == 120 && imageInfo(cmykPNG[0]).dpi == 300,"Photoshop → PNG from a CMYK document")
}
// Real Illustrator sample (Adobe's bundled script samples), when installed.
let adobeSample = URL(fileURLWithPath:"/Applications/Adobe Illustrator (Beta)/Scripting.localized/Sample Scripts.localized/AppleScript.localized/Analyze Documents.localized/Documents to Analyze.localized/PlacedItemTest.ai")
if fm.fileExists(atPath:adobeSample.path) {
    let copy = root.appendingPathComponent("PlacedItemTest.ai"); try? fm.removeItem(at:copy); try fm.copyItem(at:adobeSample,to:copy)
    let out = try ConversionRunner().convert(engine:engine,input:copy,folder:root,options:pdfOut)
    let data = try Data(contentsOf:out)
    let original = try Data(contentsOf:copy)
    check(data.range(of:Data("AIPrivateData".utf8)) == nil && data.count < original.count,"real .ai → PDF without Illustrator private data")
} else { print("SKIP: Adobe sample .ai not installed") }
// 「構造を保持」: Markdown goes straight through MarkdownToText; other input via pandoc → gfm.
var structured = ConversionOptions(); structured.format = OutputFormat.all.first { $0.id == "plain" }!; structured.markdownText = MarkdownTextOptions()
let structuredText = try String(contentsOf:try ConversionRunner().convert(engine:engine,input:input,folder:root,options:structured),encoding:.utf8)
check(structuredText == MarkdownToText.convert(original) + "\n","structured text equals MarkdownToText output")
check(structuredText.contains("■ Second") && structuredText.contains("・First"),"structured text keeps heading mark and bullet")
let docxForStructure = try ConversionRunner().convert(engine:engine,input:input,folder:root,options:{ var o = ConversionOptions(); o.format = OutputFormat.all.first { $0.id == "docx" }!; return o }())
let fromDocx = try String(contentsOf:try ConversionRunner().convert(engine:engine,input:docxForStructure,folder:root,options:structured),encoding:.utf8)
check(fromDocx.contains("■ Second") && fromDocx.contains("・First") && !fromDocx.contains("**"),"Word → structured text via pandoc gfm")
options.format = OutputFormat.all.first { $0.id == "html5" }!
let conflict = root.appendingPathComponent("日本語 sample.html")
let before = try Data(contentsOf:conflict)
let numbered = try ConversionRunner().convert(engine:engine,input:input,folder:root,options:options)
check(numbered.lastPathComponent == "日本語 sample (1).html","collision numbering")
check(try Data(contentsOf:conflict) == before,"existing output remains intact")
options.reader = "docx"
do { _ = try ConversionRunner().convert(engine:engine,input:input,folder:root,options:options); fatalError("expected failure") } catch { print("PASS: invalid input fails") }
check(try fm.contentsOfDirectory(atPath:root.path).allSatisfy { !$0.hasPrefix(".PandocDesk-") },"temporary output removed after failure")
let cancelled = ConversionRunner(); cancelled.cancel()
do { _ = try cancelled.convert(engine:engine,input:input,folder:root,options:options); fatalError("expected cancellation") } catch is CancellationError { print("PASS: prelaunch cancellation") }
// Cancel an active process, ensuring partial output never becomes a user file.
let fake = root.appendingPathComponent("slow-pandoc")
try "#!/bin/sh\nexec /bin/sleep 15\n".write(to:fake,atomically:true,encoding:.utf8)
try fm.setAttributes([.posixPermissions:0o755],ofItemAtPath:fake.path)
let running = ConversionRunner()
DispatchQueue.global().asyncAfter(deadline:.now()+0.25) { running.cancel() }
let started = Date()
do { _ = try running.convert(engine:fake,input:input,folder:root,options:options); fatalError("expected cancellation") } catch is CancellationError { print("PASS: active cancellation") }
check(Date().timeIntervalSince(started) < 5,"cancel returns promptly")
check(try fm.contentsOfDirectory(atPath:root.path).allSatisfy { !$0.hasPrefix(".PandocDesk-") },"cancel cleanup")
// Round trip ensures Japanese content survives Word's binary container.
options.reader = "docx"; options.format = OutputFormat.all.first { $0.id == "gfm" }!
let word = root.appendingPathComponent("日本語 sample.docx")
let roundtrip = try ConversionRunner().convert(engine:engine,input:word,folder:root,options:options)
check(try String(contentsOf:roundtrip).contains("日本語タイトル"),"Japanese DOCX roundtrip")
print("All conversion tests passed.")

if CommandLine.arguments.count > 2 {
    let typst = CommandLine.arguments[2]
    UserDefaults.standard.setVolatileDomain(["managedTypstPath":typst],forName:UserDefaults.argumentDomain)
    check(ConversionRunner.pdfExecutable("typst")?.path == typst,"managed Typst path selected")
    check(!ConversionRunner.pdfAvailable("invalid-engine"),"unknown PDF engine rejected")
    options = ConversionOptions()
    options.format = OutputFormat.all.first { $0.id == "pdf" }!
    options.pdfEngine = "typst"; options.toc = true; options.numbers = true
    let pdf = try ConversionRunner().convert(engine:engine,input:input,folder:root,options:options)
    let document = PDFDocument(url:pdf)!
    check(document.pageCount > 0,"Typst produced PDF pages")
    check(document.string?.contains("日本語タイトル") == true,"Japanese text survives PDF conversion")
    // Opt-in: drives the real Keynote (Automation permission for the terminal is required).
    if ProcessInfo.processInfo.environment["PANDOCDESK_KEYNOTE_TEST"] == "1" {
        let bridge = KeynoteBridge(script:URL(fileURLWithPath:ProcessInfo.processInfo.environment["PANDOCDESK_KEYNOTE_SCRIPT"]!))
        var keynote = ConversionOptions(); keynote.format = OutputFormat.all.first { $0.id == "keynote" }!; keynote.pdfEngine = "typst"; keynote.keynote.openAfter = false
        let runner = ConversionRunner(); runner.keynoteBridge = bridge
        let fromMarkdown = try runner.convert(engine:engine,input:input,folder:root,options:keynote)
        check(fromMarkdown.lastPathComponent == "日本語 sample.key" && fm.fileExists(atPath:fromMarkdown.path),"Markdown → PDF → Keynote saved beside source")
        let fromPDF = try runner.convert(engine:engine,input:pdf,folder:root,options:keynote)
        check(fromPDF.lastPathComponent == "日本語 sample (1).key","PDF → Keynote saved; same stem numbered")
        let again = try runner.convert(engine:engine,input:input,folder:root,options:keynote)
        check(again.lastPathComponent == "日本語 sample (2).key","Keynote name collision numbered again")
        check(try String(contentsOf:input) == original,"source intact after Keynote export")
        let cancelled = ConversionRunner(); cancelled.keynoteBridge = bridge; cancelled.cancel()
        do { _ = try cancelled.convert(engine:engine,input:pdf,folder:root,options:keynote); check(false,"cancelled Keynote export writes nothing") }
        catch is CancellationError { check(!fm.fileExists(atPath:root.appendingPathComponent("日本語 sample (3).key").path),"cancelled Keynote export writes nothing") }
    }
    check(document.string?.contains("Second") == true,"PDF body retained")
    let saved = URL(fileURLWithPath:CommandLine.arguments[3])
    try fm.createDirectory(at:saved,withIntermediateDirectories:true)
    let evidence = saved.appendingPathComponent("Japanese-PDF.pdf")
    if fm.fileExists(atPath:evidence.path) { try fm.removeItem(at:evidence) }
    try fm.copyItem(at:pdf,to:evidence)
    let page = document.page(at:0)!
    let image = page.thumbnail(of:NSSize(width:800,height:1100),for:.mediaBox)
    let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
    try bitmap.representation(using:.png,properties:[:])!.write(to:saved.appendingPathComponent("Japanese-PDF.png"))
    // A missing managed binary falls back to known installed system paths instead of a stale path.
    UserDefaults.standard.setVolatileDomain(["managedTypstPath":"/nonexistent/typst"],forName:UserDefaults.argumentDomain)
    check(ConversionRunner.pdfExecutable("typst")?.path != "/nonexistent/typst","stale managed path is ignored")
}
let fixture = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Tests/Fixtures/sample.idml")
let fixtureData = try Data(contentsOf:fixture)
let html = try IDMLImporter.html(from:fixture)
check(html.contains("<h1>IDML 日本語見出し</h1>"),"IDML heading")
check(html.contains("<strong>最初の段落 &amp; &lt;安全&gt;</strong>"),"IDML bold and XML escaping")
check(html.range(of:"最初の段落")!.lowerBound < html.range(of:"最後のストーリー")!.lowerBound,"IDML designmap story order")
check(html.range(of:">左<")!.lowerBound < html.range(of:">右<")!.lowerBound,"IDML table cell order")
check(html.contains("colspan=\"2\""),"IDML merged cell span")
check(!html.contains("<p><table>"),"IDML table has valid block nesting")
for name in ["invalid.idml","empty.idml"] {
 do { _ = try IDMLImporter.html(from:fixture.deletingLastPathComponent().appendingPathComponent(name)); fatalError("expected IDML rejection") }
 catch { print("PASS: rejected \(name)") }
}
options = ConversionOptions(); options.format = OutputFormat.all.first { $0.id == "gfm" }!
let idmlMarkdown = try ConversionRunner().convert(engine:engine,input:fixture,folder:root,options:options)
let markdown = try String(contentsOf:idmlMarkdown,encoding:.utf8)
check(markdown.contains("# IDML 日本語見出し") && markdown.contains("最後のストーリー") && markdown.contains("結合セル"),"IDML to Markdown end to end")
options.format = OutputFormat.all.first { $0.id == "docx" }!
let idmlWord = try ConversionRunner().convert(engine:engine,input:fixture,folder:root,options:options)
options.reader = "docx"; options.format = OutputFormat.all.first { $0.id == "gfm" }!
let idmlRoundtrip = try ConversionRunner().convert(engine:engine,input:idmlWord,folder:root,options:options)
check(try String(contentsOf:idmlRoundtrip,encoding:.utf8).contains("結合セル"),"IDML to DOCX preserves table text")
if CommandLine.arguments.count > 2 {
 UserDefaults.standard.setVolatileDomain(["managedTypstPath":CommandLine.arguments[2]],forName:UserDefaults.argumentDomain)
 options = ConversionOptions(); options.format = OutputFormat.all.first { $0.id == "pdf" }!
 let pdf = try ConversionRunner().convert(engine:engine,input:fixture,folder:root,options:options)
 check(PDFDocument(url:pdf)?.string?.contains("IDML 日本語見出し") == true,"IDML to Japanese PDF")
}
check(try Data(contentsOf:fixture) == fixtureData,"IDML original unchanged")
if CommandLine.arguments.count > 2 {
    let evidenceFolder = URL(fileURLWithPath:CommandLine.arguments[3])
    let textPDF = evidenceFolder.appendingPathComponent("Japanese-PDF.pdf")
    let extracted = try PDFImporter.html(from:textPDF,cancelled:{false})
    check(extracted.contains("日本語タイトル"),"PDF text layer import")
    options = ConversionOptions(); options.format = OutputFormat.all.first { $0.id == "docx" }!
    let pdfWord = try ConversionRunner().convert(engine:engine,input:textPDF,folder:root,options:options)
    check(fm.fileExists(atPath:pdfWord.path),"PDF to DOCX end to end")
    options.format = OutputFormat.all.first { $0.id == "idml" }!
    let pdfIDML = try ConversionRunner().convert(engine:engine,input:textPDF,folder:root,options:options)
    let importAgain = try IDMLImporter.html(from:pdfIDML)
    check(importAgain.contains("日本語タイトル"),"PDF to IDML roundtrip")
    let idmlEvidence = evidenceFolder.appendingPathComponent("PDF-to-IDML.idml")
    if fm.fileExists(atPath:idmlEvidence.path) { try fm.removeItem(at:idmlEvidence) }
    try fm.copyItem(at:pdfIDML,to:idmlEvidence)
    let bitmap = NSImage(contentsOf:evidenceFolder.appendingPathComponent("Japanese-PDF.png"))!
    let scanned = PDFDocument(); scanned.insert(PDFPage(image:bitmap)!,at:0)
    let scanURL = root.appendingPathComponent("scanned.pdf"); check(scanned.write(to:scanURL),"create image-only test PDF")
    let ocr = try PDFImporter.html(from:scanURL,cancelled:{false})
    check(ocr.contains("日本語") && ocr.contains("Second"),"Japanese/English scanned PDF OCR")
    let protected = PDFDocument(url:textPDF)!
    let locked = root.appendingPathComponent("locked.pdf")
    check(protected.write(to:locked,withOptions:[.ownerPasswordOption:"owner-test",.userPasswordOption:"read-test"]),"create locked PDF fixture")
    do { _ = try PDFImporter.html(from:locked,cancelled:{false}); fatalError("expected locked PDF rejection") }
    catch { print("PASS: protected PDF rejected") }
    do { _ = try PDFImporter.html(from:textPDF,cancelled:{true}); fatalError("expected PDF cancellation") }
    catch is CancellationError { print("PASS: PDF input cancellation") }
    let longText = (1...125).map { "段落 \($0) 日本語の編集可能な本文" }.joined(separator:"\n")
    let longPackage = root.appendingPathComponent("long.idml")
    try IDMLExporter.write(text:longText,to:longPackage,in:root,cancelled:{false})
    let longHTML = try IDMLImporter.html(from:longPackage)
    check(longHTML.contains("段落 125") && longHTML.contains("段落 1 "),"multi-page IDML retains first and last paragraphs")
}
let htmlFixture = "<div  class=\"sample  text\">\n  <p>Hello <strong>world</strong> <em>again</em>.</p>\n  <pre><code>  a\n    b &lt;c&gt;\n</code></pre>\n  <script>const s = '<p>  x </p>';\n</script>\n  <style>p { white-space: pre; }</style>\n</div>"
let minimized = HTMLFormatting.minify.apply(to:htmlFixture)
let beautiful = HTMLFormatting.beautify.apply(to:minimized)
check(minimized.utf8.count < htmlFixture.utf8.count,"HTML minify reduces output size")
check(minimized.contains("class=\"sample  text\""),"HTML preserves quoted attribute whitespace")
for html in [minimized,beautiful] {
 check(html.contains("<strong>world</strong> <em>again</em>"),"HTML preserves inline word separation")
 check(html.contains("<pre><code>  a\n    b &lt;c&gt;\n</code></pre>"),"HTML preserves code block whitespace")
 check(html.contains("<script>const s = '<p>  x </p>';\n</script>"),"HTML preserves JavaScript")
 check(html.contains("<style>p { white-space: pre; }</style>"),"HTML preserves CSS")
}
check(beautiful.contains("\n  <p>"),"HTML beautify adds readable indentation")
check(HTMLFormatting.beautify.apply(to:beautiful) == beautiful,"HTML beautify is stable")
check(HTMLFormatting.standard.apply(to:htmlFixture) == htmlFixture,"standard HTML remains unchanged")
let htmlSource = root.appendingPathComponent("formatting.md")
try "# Format\n\nHello **world** *again*.\n\n```text\n  a\n    b\n```\n".write(to:htmlSource,atomically:true,encoding:.utf8)
options = ConversionOptions(); options.format = OutputFormat.all.first { $0.id == "html5" }!
options.standalone = false; options.htmlFormatting = .minify
let minifiedURL = try ConversionRunner().convert(engine:engine,input:htmlSource,folder:root,options:options)
options.htmlFormatting = .beautify
let beautifulURL = try ConversionRunner().convert(engine:engine,input:htmlSource,folder:root,options:options)
let minifiedText = try String(contentsOf:minifiedURL,encoding:.utf8)
let beautifulText = try String(contentsOf:beautifulURL,encoding:.utf8)
check(minifiedText != beautifulText,"HTML formatting choice reaches conversion output")
check(minifiedText.contains("  a\n    b") && beautifulText.contains("  a\n    b"),"pandoc code whitespace survives both HTML modes")
