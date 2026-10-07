import Foundation
import PDFKit
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
for format in OutputFormat.all where !["pdf","keynote"].contains(format.id) {
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
