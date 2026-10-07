import Foundation

struct OutputFormat: Identifiable, Equatable {
    let id: String
    let name: String
    let ext: String
    static let all = [
        OutputFormat(id:"pdf", name:"PDF", ext:"pdf"),
        OutputFormat(id:"plain", name:"Plain text", ext:"txt"),
        OutputFormat(id:"idml", name:"InDesign (IDML)", ext:"idml"),
        OutputFormat(id:"html5", name:"HTML", ext:"html"),
        OutputFormat(id:"gfm", name:"Markdown", ext:"md"),
        OutputFormat(id:"pptx", name:"PowerPoint", ext:"pptx"),
        OutputFormat(id:"keynote", name:"Keynote", ext:"key"),
        OutputFormat(id:"docx", name:"Word", ext:"docx"),
        OutputFormat(id:"epub3", name:"EPUB", ext:"epub"),
        OutputFormat(id:"rtf", name:"RTF", ext:"rtf"),
        OutputFormat(id:"latex", name:"LaTeX", ext:"tex"),
        OutputFormat(id:"odt", name:"OpenDocument", ext:"odt")]
    static var defaultFormat: OutputFormat { all.first { $0.id == "docx" }! }
    var supportsTOC: Bool { ["docx","html5","epub3","odt","rtf","latex","pdf"].contains(id) }
    var supportsNumbers: Bool { ["html5","latex","pdf"].contains(id) }
}
struct ConversionOptions {
    var format = OutputFormat.defaultFormat
    var reader = "auto"
    var standalone = true
    var toc = false
    var numbers = false
    var wrap = "auto"
    var pdfEngine = "typst"
    var htmlFormatting = HTMLFormatting.standard
    var keynote = KeynoteOptions()
    /// Plain text with 「構造を保持」: converted by MarkdownToText instead of pandoc's plain writer.
    var markdownText: MarkdownTextOptions?
    /// .ai input: "simple" reads the embedded PDF; "illustrator" saves through Illustrator with a PDF preset.
    var aiMethod = "simple"
    var aiPreset = ""
    var illustratorApp: URL?
    func arguments(input: URL, output: URL) -> [String] {
        var args = ["--output", output.path]
        if format.id == "pdf" {
            args += ["--pdf-engine", ConversionRunner.pdfExecutable(pdfEngine)?.path ?? pdfEngine]
            if pdfEngine == "typst" { args += ["--to", "typst", "--variable", "mainfont=Hiragino Sans"] }
            else { args += ["--variable", "CJKmainfont=Hiragino Sans"] }
        }
        else { args += ["--to", format.id] }
        if reader != "auto" { args += ["--from",reader] }
        if standalone { args.append("--standalone") }
        if toc && format.supportsTOC { args.append("--toc") }
        if numbers && format.supportsNumbers { args.append("--number-sections") }
        if ["gfm","plain","latex"].contains(format.id) { args += ["--wrap",wrap] }
        return args + [input.path]
    }
}
final class ConversionRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    /// Replaceable for tests; the app uses the bundled Keynote.scpt.
    var keynoteBridge = KeynoteBridge()
    /// Non-fatal notes for the finished conversion (e.g. an .ai saved without PDF compatibility).
    private var notes: [String] = []
    var warnings: [String] { lock.lock(); defer { lock.unlock() }; return notes }
    private func addWarning(_ text: String) { lock.lock(); notes.append(text); lock.unlock() }
    func cancel() {
        lock.lock(); cancelled = true; let p = process; lock.unlock()
        if let p, p.isRunning { p.terminate() }
    }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    static func engine() -> URL? {
        let custom = UserDefaults.standard.string(forKey:"pandocPath") ?? ""
        if !custom.isEmpty { return FileManager.default.isExecutableFile(atPath:custom) ? URL(fileURLWithPath:custom) : nil }
        let managed = UserDefaults.standard.string(forKey:"managedPandocPath") ?? ""
        let paths = [managed, Bundle.main.url(forResource:"pandoc", withExtension:nil, subdirectory:"bin")?.path ?? "", "/opt/homebrew/bin/pandoc", "/usr/local/bin/pandoc"]
        return paths.first(where: { !$0.isEmpty && FileManager.default.isExecutableFile(atPath:$0) }).map { URL(fileURLWithPath:$0) }
    }
    static let searchPath = "/opt/homebrew/bin:/usr/local/bin:/Library/TeX/texbin:/usr/bin:/bin"
    static func pdfExecutable(_ name: String) -> URL? {
        guard ["typst", "xelatex", "lualatex"].contains(name) else { return nil }
        var paths = searchPath.split(separator:":").map { String($0)+"/"+name }
        if name == "typst", let managed = UserDefaults.standard.string(forKey:"managedTypstPath"), !managed.isEmpty { paths.insert(managed, at:0) }
        return paths.first(where: { FileManager.default.isExecutableFile(atPath:$0) }).map { URL(fileURLWithPath:$0) }
    }
    static func pdfAvailable(_ name: String) -> Bool { pdfExecutable(name) != nil }
    static func isPDF(_ url: URL) -> Bool { url.pathExtension.lowercased() == "pdf" }
    /// PDFs go straight to Keynote; other documents are typeset to PDF first with the selected PDF engine.
    private func convertToKeynote(engine: URL, input: URL, folder: URL, options: ConversionOptions) throws -> URL {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("PandocDesk-keynote-" + UUID().uuidString, isDirectory:true)
        try fm.createDirectory(at:temp, withIntermediateDirectories:true)
        defer { try? fm.removeItem(at:temp) }
        var pdf = input
        if !Self.isPDF(input) {
            var pdfOptions = options
            pdfOptions.format = OutputFormat.all.first { $0.id == "pdf" }!
            pdf = try convert(engine:engine, input:input, folder:temp, options:pdfOptions)
        }
        let stem = input.deletingPathExtension().lastPathComponent
        return try KeynoteExporter.export(pdf:pdf, destination:{ Self.unusedURL(folder:folder, stem:stem, ext:"key") ?? folder.appendingPathComponent(UUID().uuidString + ".key") }, options:options.keynote, bridge:keynoteBridge, isCancelled:{ self.isCancelled })
    }
    /// .ai (simple version): the embedded PDF becomes the input. PDF output is that PDF itself
    /// (not re-typeset); other formats continue as if a PDF had been given.
    private func convertIllustrator(engine: URL, input: URL, folder: URL, options: ConversionOptions) throws -> URL {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("PandocDesk-ai-" + UUID().uuidString, isDirectory:true)
        try fm.createDirectory(at:temp, withIntermediateDirectories:true)
        defer { try? fm.removeItem(at:temp) }
        let stem = input.deletingPathExtension().lastPathComponent
        let pdf = temp.appendingPathComponent(stem + ".pdf")
        if options.aiMethod == "illustrator" {
            guard let app = options.illustratorApp ?? IllustratorBridge.defaultInstallation()?.url else { throw IllustratorBridge.error("illustratorMissing") }
            let notes = try IllustratorBridge.exportPDF(from:input, to:pdf, preset:options.aiPreset, app:app, isCancelled:{ self.isCancelled })
            if notes.contains(.unsaved) { addWarning(input.lastPathComponent + ": " + NSLocalizedString("aiExportedUnsaved", comment:"")) }
            else if notes.contains(.open) { addWarning(input.lastPathComponent + ": " + NSLocalizedString("aiExportedOpen", comment:"")) }
            if notes.contains(.links) { addWarning(input.lastPathComponent + ": " + NSLocalizedString("aiBrokenLinks", comment:"")) }
        } else {
            let result = try AIImporter.writePDF(from:input, to:pdf, cancelled:{ self.isCancelled })
            if result.withoutPDFContent { addWarning(input.lastPathComponent + ": " + NSLocalizedString("aiWithoutPDF", comment:"")) }
        }
        if isCancelled { throw CancellationError() }
        guard options.format.id == "pdf" else { return try convert(engine:engine, input:pdf, folder:folder, options:options) }
        guard let destination = Self.unusedURL(folder:folder, stem:stem, ext:"pdf") else {
            throw NSError(domain:"PandocDesk",code:1,userInfo:[NSLocalizedDescriptionKey:"No unused output filename"])
        }
        try fm.copyItem(at:pdf, to:destination)
        return destination
    }
    static let markdownExtensions: Set<String> = ["md","markdown","mdown","mkd","txt"]
    /// 「構造を保持」: Markdown is read as is; other documents go through pandoc → GitHub Markdown first.
    private func convertStructuredText(engine: URL, input: URL, folder: URL, options: ConversionOptions, textOptions: MarkdownTextOptions) throws -> URL {
        let markdownReaders: Set<String> = ["auto","markdown","gfm"]
        var markdown: String
        if Self.markdownExtensions.contains(input.pathExtension.lowercased()) && markdownReaders.contains(options.reader) {
            markdown = try String(contentsOf:input, encoding:.utf8)
        } else {
            let fm = FileManager.default
            let temp = fm.temporaryDirectory.appendingPathComponent("PandocDesk-text-" + UUID().uuidString, isDirectory:true)
            try fm.createDirectory(at:temp, withIntermediateDirectories:true)
            defer { try? fm.removeItem(at:temp) }
            var gfmOptions = options
            gfmOptions.format = OutputFormat.all.first { $0.id == "gfm" }!
            gfmOptions.markdownText = nil; gfmOptions.wrap = "none"; gfmOptions.standalone = false
            let intermediate = try convert(engine:engine, input:input, folder:temp, options:gfmOptions)
            markdown = try String(contentsOf:intermediate, encoding:.utf8)
        }
        if isCancelled { throw CancellationError() }
        let text = MarkdownToText.convert(markdown, options:textOptions) + "\n"
        guard let destination = Self.unusedURL(folder:folder, stem:input.deletingPathExtension().lastPathComponent, ext:"txt") else {
            throw NSError(domain:"PandocDesk",code:1,userInfo:[NSLocalizedDescriptionKey:"No unused output filename"])
        }
        try Data(text.utf8).write(to:destination, options:.withoutOverwriting)
        return destination
    }
    /// "name.ext", then "name (1).ext"… the first name not in use.
    static func unusedURL(folder: URL, stem: String, ext: String) -> URL? {
        for index in 0..<10000 {
            let url = folder.appendingPathComponent(stem + (index == 0 ? "" : " (\(index))") + "." + ext)
            if !FileManager.default.fileExists(atPath:url.path) { return url }
        }
        return nil
    }
    func convert(engine: URL, input: URL, folder: URL, options: ConversionOptions) throws -> URL {
        if isCancelled { throw CancellationError() }
        if input.pathExtension.lowercased() == "ai" { return try convertIllustrator(engine:engine, input:input, folder:folder, options:options) }
        if options.format.id == "keynote" { return try convertToKeynote(engine:engine, input:input, folder:folder, options:options) }
        if options.format.id == "plain", let textOptions = options.markdownText { return try convertStructuredText(engine:engine, input:input, folder:folder, options:options, textOptions:textOptions) }
        let fm = FileManager.default
        let temp = folder.appendingPathComponent(".PandocDesk-" + UUID().uuidString, isDirectory:true)
        try fm.createDirectory(at:temp, withIntermediateDirectories:false)
        defer { try? fm.removeItem(at:temp) }
        let output = temp.appendingPathComponent("result." + options.format.ext)
        let log = temp.appendingPathComponent("stderr")
        fm.createFile(atPath:log.path, contents:nil)
        let handle = try FileHandle(forWritingTo:log)
        defer { try? handle.close() }
        let p = Process(); p.executableURL = engine
        var effectiveOptions = options
        var effectiveInput = input
        if input.pathExtension.lowercased() == "idml" || options.reader == "idml" {
            effectiveInput = temp.appendingPathComponent("idml-import.html")
            try IDMLImporter.html(from:input,cancelled:{ self.isCancelled }).write(to:effectiveInput,atomically:true,encoding:.utf8)
            effectiveOptions.reader = "html"
        }
        if input.pathExtension.lowercased() == "pdf" || options.reader == "pdf" {
            effectiveInput = temp.appendingPathComponent("pdf-import.html")
            try PDFImporter.html(from:input,cancelled:{ self.isCancelled }).write(to:effectiveInput,atomically:true,encoding:.utf8)
            effectiveOptions.reader = "html"
        }
        if input.pathExtension.lowercased() == "xlsx" || options.reader == "xlsx" {
            effectiveInput = temp.appendingPathComponent("xlsx-import.html")
            try XLSXImporter.html(from:input,cancelled:{ self.isCancelled }).write(to:effectiveInput,atomically:true,encoding:.utf8)
            effectiveOptions.reader = "html"
        }
        let intermediate = temp.appendingPathComponent("idml-text.txt")
        if options.format.id == "idml" { effectiveOptions.format = OutputFormat.all.first { $0.id == "plain" }!; effectiveOptions.wrap = "none" }
        p.arguments = effectiveOptions.arguments(input:effectiveInput, output:options.format.id == "idml" ? intermediate : output)
        p.currentDirectoryURL = input.deletingLastPathComponent()
        var env = ProcessInfo.processInfo.environment; env["PATH"] = Self.searchPath; p.environment = env
        p.standardOutput = FileHandle.nullDevice; p.standardError = handle
        p.standardInput = FileHandle.nullDevice
        lock.lock()
        if cancelled { lock.unlock(); throw CancellationError() }
        process = p
        do { try p.run() } catch { process = nil; lock.unlock(); throw error }
        lock.unlock()
        p.waitUntilExit()
        lock.lock(); process = nil; let stopped = cancelled; lock.unlock()
        if stopped { throw CancellationError() }
        if p.terminationStatus != 0 {
            let reader = try FileHandle(forReadingFrom:log); defer { try? reader.close() }
            let data = try reader.read(upToCount:8192) ?? Data()
            throw NSError(domain:"PandocDesk", code:Int(p.terminationStatus), userInfo:[NSLocalizedDescriptionKey:String(data:data,encoding:.utf8) ?? "pandoc error"])
        }
        if options.format.id == "idml" {
            try IDMLExporter.write(text:String(contentsOf:intermediate,encoding:.utf8),to:output,in:temp,cancelled:{ self.isCancelled })
        }
        if options.format.id == "html5", options.htmlFormatting != .standard {
            let html = try String(contentsOf:output,encoding:.utf8)
            try options.htmlFormatting.apply(to:html).write(to:output,atomically:true,encoding:.utf8)
        }
        if isCancelled { throw CancellationError() }
        // A same-filesystem move publishes only completed output and never replaces an existing file.
        let stem = input.deletingPathExtension().lastPathComponent
        for index in 0..<10000 {
            let name = stem + (index == 0 ? "" : " (\(index))") + "." + options.format.ext
            let destination = folder.appendingPathComponent(name)
            if fm.fileExists(atPath:destination.path) { continue }
            do { try fm.moveItem(at:output,to:destination); return destination }
            catch { if fm.fileExists(atPath:destination.path) { continue }; throw error }
        }
        throw NSError(domain:"PandocDesk",code:1,userInfo:[NSLocalizedDescriptionKey:"No unused output filename"])
    }
}
