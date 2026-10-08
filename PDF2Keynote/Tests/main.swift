import AppKit
import PDFKit

// Usage: tests <work dir> [<Keynote.scpt> <output dir>]
// The second form also runs the Keynote integration test.
var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if condition() { print("PASS:", message) } else { failures += 1; print("FAIL:", message, "(line \(line))") }
}

let work = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.removeItem(at: work)
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

// Fixture: 1) 960×540, 2) A4 portrait, 3) 960×540 rotated 90°, 4) 600×400 with a 500×300 TrimBox.
func makeFixture() -> URL {
    let url = work.appendingPathComponent("fixture.pdf")
    let ctx = CGContext(url as CFURL, mediaBox: nil, nil)!
    for (index, size) in [CGSize(width: 960, height: 540), CGSize(width: 595, height: 842), CGSize(width: 960, height: 540), CGSize(width: 600, height: 400)].enumerated() {
        var box = CGRect(origin: .zero, size: size)
        var info: [CFString: Any] = [kCGPDFContextMediaBox: Data(bytes: &box, count: MemoryLayout<CGRect>.size)]
        if index == 3 {
            var trim = CGRect(x: 50, y: 50, width: 500, height: 300)
            info[kCGPDFContextTrimBox] = Data(bytes: &trim, count: MemoryLayout<CGRect>.size)
        }
        ctx.beginPDFPage(info as CFDictionary)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSColor(calibratedHue: CGFloat(index) / 5, saturation: 0.5, brightness: 0.9, alpha: 1).setFill()
        NSRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40).fill()
        ("Page \(index + 1) ページ" as NSString).draw(at: NSPoint(x: 60, y: size.height / 2), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 48)])
        ctx.endPDFPage()
    }
    ctx.closePDF()
    let document = PDFDocument(url: url)!
    document.page(at: 2)!.rotation = 90
    document.write(to: url)
    return url
}
let fixture = makeFixture()

// Layout
check(KeynoteLayout.slideSize(.matchPDF, firstPage: CGSize(width: 960, height: 540)) == (1920, 1080), "match PDF landscape → 1920×1080")
check(KeynoteLayout.slideSize(.matchPDF, firstPage: CGSize(width: 595, height: 842)) == (1357, 1920), "match PDF portrait keeps ratio, long edge 1920")
check(KeynoteLayout.slideSize(.xga1024, firstPage: CGSize(width: 960, height: 540)) == (1024, 768), "fixed size ignores page")
check(KeynoteLayout.place(CGSize(width: 960, height: 540), slide: (1024, 768), placement: .fit) == KeynoteGeometry(x: 0, y: 96, width: 1024, height: 576), "fit letterboxes 16:9 on 4:3")
check(KeynoteLayout.place(CGSize(width: 960, height: 540), slide: (1024, 768), placement: .fill) == KeynoteGeometry(x: -171, y: 0, width: 1365, height: 768), "fill overflows horizontally, centered")
check(KeynoteLayout.place(CGSize(width: 595, height: 842), slide: (1920, 1080), placement: .fit) == KeynoteGeometry(x: 579, y: 0, width: 763, height: 1080), "portrait page fits by height")
check(KeynoteLayout.pages(nil, count: 5) == 1...5, "no range → all pages")
check(KeynoteLayout.pages(3...99, count: 5) == 3...5, "range clamps to last page")
check(KeynoteLayout.pages(6...9, count: 5) == nil, "range past the end → nil")
check(KeynoteLayout.pages(nil, count: 0) == nil, "empty PDF → nil")

// Unique names never replace existing items.
let names = work.appendingPathComponent("names", isDirectory: true)
try FileManager.default.createDirectory(at: names, withIntermediateDirectories: true)
check(KeynoteLayout.uniqueURL(folder: names, base: "deck", ext: "key").lastPathComponent == "deck.key", "free name kept")
FileManager.default.createFile(atPath: names.appendingPathComponent("deck.key").path, contents: Data())
try FileManager.default.createDirectory(at: names.appendingPathComponent("deck 2.key"), withIntermediateDirectories: true)
check(KeynoteLayout.uniqueURL(folder: names, base: "deck", ext: "key").lastPathComponent == "deck 3.key", "existing file and package both skipped")

// Splitting
check(KeynotePDFSplitter.pageCount(fixture) == 4, "page count")
check(KeynotePDFSplitter.pageCount(work) == nil, "folder rejected")
let split = work.appendingPathComponent("split", isDirectory: true)
try FileManager.default.createDirectory(at: split, withIntermediateDirectories: true)
let all = try KeynotePDFSplitter.prepare(source: fixture, options: KeynoteOptions(), into: split) { false }
check(all.pages.count == 4 && all.slide == (1920, 1080), "4 pages, slide from first page")
check(all.pages.allSatisfy { PDFDocument(url: $0.url)?.pageCount == 1 }, "each output has one page")
check(all.pages[2].geometry == KeynoteGeometry(x: 656, y: 0, width: 608, height: 1080), "rotated page placed as portrait")
check(PDFDocument(url: all.pages[2].url)?.page(at: 0)?.rotation == 90, "rotation preserved")
let trimDir = work.appendingPathComponent("trim", isDirectory: true)
try FileManager.default.createDirectory(at: trimDir, withIntermediateDirectories: true)
var trimOptions = KeynoteOptions(); trimOptions.box = .trim; trimOptions.pageRange = 4...4
let trimmed = try KeynotePDFSplitter.prepare(source: fixture, options: trimOptions, into: trimDir) { false }
let trimmedPage = PDFDocument(url: trimmed.pages[0].url)!.page(at: 0)!
check(trimmed.pages.count == 1 && trimmed.slide == (1920, 1152), "range 4 only; slide from TrimBox 500×300")
check(trimmedPage.bounds(for: .mediaBox).size == CGSize(width: 500, height: 300), "MediaBox size set to TrimBox")
// The fill rectangle spans 20…580 on the 600×400 page, so a correct 50…550 trim has no white margin.
let thumb = trimmedPage.thumbnail(of: CGSize(width: 500, height: 300), for: .mediaBox)
let corner = NSBitmapImageRep(data: thumb.tiffRepresentation!)!.colorAt(x: 3, y: 3)!.usingColorSpace(.sRGB)!
check(corner.brightnessComponent < 0.98 || corner.saturationComponent > 0.1, "trimmed content shifted with the box (no white margin)")
var outOfRange = KeynoteOptions(); outOfRange.pageRange = 9...12
do { _ = try KeynotePDFSplitter.prepare(source: fixture, options: outOfRange, into: trimDir) { false }; check(false, "out-of-range rejected") }
catch KeynoteError.emptyRange { check(true, "out-of-range rejected") }
do { _ = try KeynotePDFSplitter.prepare(source: fixture, options: KeynoteOptions(), into: trimDir) { true }; check(false, "cancellation stops splitting") }
catch is CancellationError { check(true, "cancellation stops splitting") }
let lockedURL = work.appendingPathComponent("locked.pdf")
let lockedDoc = PDFDocument(url: fixture)!
lockedDoc.write(to: lockedURL, withOptions: [.userPasswordOption: "pw", .ownerPasswordOption: "owner"])
do { _ = try KeynotePDFSplitter.prepare(source: lockedURL, options: KeynoteOptions(), into: trimDir) { false }; check(false, "locked PDF rejected") }
catch KeynoteError.locked { check(true, "locked PDF rejected") }
check(KeynoteBridge.error(from: "x.scpt: execution error: Not authorized to send Apple events to Keynote. (-1743)") == .automationDenied, "-1743 → automation denied")
check(KeynoteBridge.error(from: "x.scpt: execution error: Keynote got an error: AppleEvent timed out. (-1712)") == .timeout, "-1712 → timeout")

// Backgrounds, written by hand because CoreGraphics and PDFKit inline Form XObjects when saving.
// Page 1: full-page fill then text. Page 2: a Form XObject in q…Q then text (as InDesign writes
// parent pages). Page 3: text only. The fixture above starts with an inset rectangle: no background.
func makeBackgroundFixture() -> URL {
    let url = work.appendingPathComponent("background.pdf")
    let contents = ["1 0.9 0 rg 0 0 800 450 re f BT /F1 48 Tf 300 200 Td (Slide 1) Tj ET",
                    "q /GS0 gs /Fm0 Do Q BT /F1 48 Tf 300 200 Td (Slide 2) Tj ET",
                    "BT /F1 48 Tf 300 200 Td (Slide 3) Tj ET"]
    let form = "0.2 0.4 0.8 rg 40 40 720 370 re f"
    func stream(_ text: String, _ extra: String = "") -> String { "<< \(extra)/Length \(text.utf8.count) >>\nstream\n\(text)\nendstream" }
    var bodies = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3 >>"]
    let resources = "<< /XObject << /Fm0 9 0 R >> /Font << /F1 10 0 R >> /ExtGState << /GS0 << /CA 1 >> >> >>"
    bodies += (0..<3).map { "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 800 450] /Contents \(6 + $0) 0 R /Resources \(resources) >>" }
    bodies += contents.map { stream($0) }
    bodies += [stream(form, "/Type /XObject /Subtype /Form /BBox [0 0 800 450] "), "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    var pdf = "%PDF-1.4\n", offsets: [Int] = []
    for (index, body) in bodies.enumerated() { offsets.append(pdf.utf8.count); pdf += "\(index + 1) 0 obj\n\(body)\nendobj\n" }
    let xref = pdf.utf8.count
    pdf += "xref\n0 \(bodies.count + 1)\n0000000000 65535 f \n" + offsets.map { String(format: "%010d 00000 n \n", $0) }.joined()
    pdf += "trailer\n<< /Size \(bodies.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
    try! Data(pdf.utf8).write(to: url)
    return url
}
let backgroundPDF = makeBackgroundFixture()
let backgroundDoc = CGPDFDocument(backgroundPDF as CFURL)!
let fillBackground = PDFBackgroundFinder.find(page: backgroundDoc.page(at: 1)!, box: CGRect(x: 0, y: 0, width: 800, height: 450))
check(fillBackground?.signature.hasPrefix("fill:") == true && fillBackground?.colors.count == 1, "full-page fill found as background")
check(PDFBackgroundFinder.find(page: backgroundDoc.page(at: 2)!, box: CGRect(x: 0, y: 0, width: 800, height: 450))?.signature.hasPrefix("form:") == true, "leading Form XObject found as background")
check(PDFBackgroundFinder.find(page: backgroundDoc.page(at: 3)!, box: CGRect(x: 0, y: 0, width: 800, height: 450)) == nil, "text-only page has no background")
check(PDFBackgroundFinder.find(page: CGPDFDocument(fixture as CFURL)!.page(at: 1)!, box: CGRect(x: 0, y: 0, width: 960, height: 540)) == nil, "inset rectangle is not a background")
let summaries = KeynotePDFSplitter.backgrounds(source: backgroundPDF, box: .crop, pageRange: nil)
check(summaries.count == 2 && summaries.allSatisfy { $0.pageCount == 1 }, "two kinds of background summarized")
let stripDir = work.appendingPathComponent("strip", isDirectory: true)
try FileManager.default.createDirectory(at: stripDir, withIntermediateDirectories: true)
var stripOptions = KeynoteOptions(); stripOptions.removeBackground = true; stripOptions.master = "Blank"
stripOptions.masterForBackground = [summaries[0].signature: "Yellow"]
let stripped = try KeynotePDFSplitter.prepare(source: backgroundPDF, options: stripOptions, into: stripDir) { false }
check(stripped.pages.map(\.master) == ["Yellow", "Blank", "Blank"], "master per background, others use the general master")
func pixel(_ url: URL, _ x: Int, _ y: Int) -> NSColor {
    let document = PDFDocument(url: url)!
    let page = document.page(at: 0)!
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 225, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext; ctx.scaleBy(x: 0.5, y: 0.5); page.draw(with: .mediaBox, to: ctx)
    NSGraphicsContext.restoreGraphicsState()
    return withExtendedLifetime(document) { rep.colorAt(x: x, y: y)! }
}
check(pixel(stripped.pages[0].url, 5, 5).alphaComponent < 0.01 && pixel(stripped.pages[1].url, 200, 30).alphaComponent < 0.01, "backgrounds removed (transparent)")
check(["Slide 1", "Slide 2"].enumerated().allSatisfy { PDFDocument(url: stripped.pages[$0.offset].url)?.string?.contains($0.element) == true }, "text kept after removal")
check(PDFDocument(url: stripped.pages[2].url)?.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: 800, height: 450), "page without background written as before")

// Keynote integration
if CommandLine.arguments.count >= 4 {
    let bridge = KeynoteBridge(script: URL(fileURLWithPath: CommandLine.arguments[2]))
    let out = URL(fileURLWithPath: CommandLine.arguments[3])
    try? FileManager.default.removeItem(at: out)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    var options = KeynoteOptions(); options.openAfter = false
    var reported: [(Int, Int)] = []
    let first = try ConversionRunner(bridge: bridge).convert(input: fixture, folder: out, options: options) { reported.append(($0, $1)) }
    let second = try ConversionRunner(bridge: bridge).convert(input: fixture, folder: out, options: options) { _, _ in }
    check(first.lastPathComponent == "fixture.key" && second.lastPathComponent == "fixture 2.key", "Keynote: saved, second run numbered")
    check(reported.last.map { $0 == (4, 4) } ?? false, "Keynote: progress reached 4/4")
    let listing = Process(); let pipe = Pipe()
    listing.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); listing.arguments = ["-Z1", first.path]; listing.standardOutput = pipe
    try listing.run(); let entries = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self); listing.waitUntilExit()
    let embedded = entries.split(separator: "\n").filter { $0.hasPrefix("Data/page-") && $0.hasSuffix(".pdf") }
    check(embedded.count == 4, "Keynote: 4 pages embedded as PDF (vector)")
    let cancelled = ConversionRunner(bridge: bridge); cancelled.cancel()
    do { _ = try cancelled.convert(input: fixture, folder: out, options: options) { _, _ in }; check(false, "Keynote: cancelled run writes nothing") }
    catch is CancellationError { check(!FileManager.default.fileExists(atPath: out.appendingPathComponent("fixture 3.key").path), "Keynote: cancelled run writes nothing") }
    // Theme and masters: the background page gets the last master, the others the first.
    let themes = try bridge.themes(), masters = try bridge.masters(theme: themes[0])
    check(!themes.isEmpty && masters.count >= 2, "Keynote: themes and masters listed")
    var themed = KeynoteOptions(); themed.removeBackground = true; themed.theme = themes[0]; themed.master = masters[0]
    themed.masterForBackground = [summaries[0].signature: masters[masters.count - 1]]
    let themedKey = try ConversionRunner(bridge: bridge).convert(input: backgroundPDF, folder: out, options: themed) { _, _ in }
    let query = Process(); let queryPipe = Pipe(); query.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); query.standardOutput = queryPipe
    query.arguments = ["-e", "tell application id \"com.apple.Keynote\"", "-e", "set d to first document whose name starts with \"\(themedKey.deletingPathExtension().lastPathComponent)\"",
                       "-e", "set AppleScript's text item delimiters to \"|\"", "-e", "set r to (name of base slide of every slide of d) as text", "-e", "close d saving no", "-e", "return r", "-e", "end tell"]
    try query.run(); let bases = String(decoding: queryPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines); query.waitUntilExit()
    check(bases == [masters[masters.count - 1], masters[0], masters[0]].joined(separator: "|"), "Keynote: masters applied per background (\(bases))")
    let script = "tell application id \"com.apple.Keynote\" to count documents"
    let count = Process(); let countPipe = Pipe(); count.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); count.arguments = ["-e", script]; count.standardOutput = countPipe
    try count.run(); let remaining = String(decoding: countPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines); count.waitUntilExit()
    print("INFO: Keynote documents still open:", remaining)
}

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
