import AppKit
import Carbon
import PDFKit
import SwiftUI

// Shared PDF → Keynote export (PDF2Keynote, PandocDesk).
// Each PDF page is written as a one-page PDF and placed on its own slide by Keynote,
// so pages stay vector. Requires Keynote.scpt (compiled from Keynote.applescript) in
// the app bundle, NSAppleEventsUsageDescription, and these localized keys in the app:
// matchPDF, box.crop/trim/bleed/media/art, keynoteMissing, automationDenied, locked,
// unreadable, emptyRange, writePage, timeout, keynoteError, permissionWhy, permAllowed,
// permDenied, permUnknown, permAsk, permOpen. The app supplies the global L(_:).

enum KeynoteSlideSize: String, CaseIterable, Identifiable {
    case matchPDF, hd1920, xga1024, hd1280, wsxga1680
    var id: String { rawValue }
    /// nil means "derive from the first page".
    var fixed: (Int, Int)? {
        switch self {
        case .matchPDF: return nil
        case .hd1920: return (1920, 1080)
        case .xga1024: return (1024, 768)
        case .hd1280: return (1280, 720)
        case .wsxga1680: return (1680, 1050)
        }
    }
    var label: String {
        switch self {
        case .matchPDF: return L("matchPDF")
        case .hd1920: return "1920 × 1080 (16:9)"
        case .xga1024: return "1024 × 768 (4:3)"
        case .hd1280: return "1280 × 720 (16:9)"
        case .wsxga1680: return "1680 × 1050 (16:10)"
        }
    }
}

enum KeynotePlacement: String, CaseIterable, Identifiable {
    case fit, fill
    var id: String { rawValue }
}

enum KeynotePageBox: String, CaseIterable, Identifiable {
    case crop, trim, bleed, media, art
    var id: String { rawValue }
    var pdfBox: PDFDisplayBox {
        switch self {
        case .crop: return .cropBox
        case .trim: return .trimBox
        case .bleed: return .bleedBox
        case .media: return .mediaBox
        case .art: return .artBox
        }
    }
    var label: String { L("box." + rawValue) }
}

struct KeynoteOptions {
    var slideSize: KeynoteSlideSize = .matchPDF
    var placement: KeynotePlacement = .fit
    var box: KeynotePageBox = .crop
    /// 1-based inclusive. nil converts every page.
    var pageRange: ClosedRange<Int>?
    var openAfter = true
}

struct KeynoteGeometry: Equatable {
    var x: Int, y: Int, width: Int, height: Int
}

struct KeynotePreparedPage {
    let url: URL
    let geometry: KeynoteGeometry
}

enum KeynoteError: LocalizedError, Equatable {
    case keynoteMissing, automationDenied, locked, unreadable, emptyRange, writePage, timeout
    case keynote(String)
    var errorDescription: String? {
        switch self {
        case .keynoteMissing: return L("keynoteMissing")
        case .automationDenied: return L("automationDenied")
        case .locked: return L("locked")
        case .unreadable: return L("unreadable")
        case .emptyRange: return L("emptyRange")
        case .writePage: return L("writePage")
        case .timeout: return L("timeout")
        case .keynote(let message): return L("keynoteError") + message
        }
    }
}

enum KeynoteLayout {
    /// Long edge of a slide sized from the PDF. Matches Keynote's wide preset.
    static let matchLongEdge: CGFloat = 1920

    /// Page size as displayed, with /Rotate applied.
    static func displaySize(of page: PDFPage, box: PDFDisplayBox) -> CGSize {
        let size = page.bounds(for: box).size
        return ((page.rotation % 360 + 360) % 360) % 180 == 0 ? size : CGSize(width: size.height, height: size.width)
    }

    static func slideSize(_ mode: KeynoteSlideSize, firstPage: CGSize) -> (Int, Int) {
        if let fixed = mode.fixed { return fixed }
        guard firstPage.width > 0, firstPage.height > 0 else { return (1920, 1080) }
        let scale = matchLongEdge / max(firstPage.width, firstPage.height)
        return (max(1, Int((firstPage.width * scale).rounded())), max(1, Int((firstPage.height * scale).rounded())))
    }

    /// Centers the page on the slide. Fill may extend past the slide edges.
    static func place(_ page: CGSize, slide: (Int, Int), placement: KeynotePlacement) -> KeynoteGeometry {
        let slideW = CGFloat(slide.0), slideH = CGFloat(slide.1)
        guard page.width > 0, page.height > 0 else { return KeynoteGeometry(x: 0, y: 0, width: slide.0, height: slide.1) }
        let ratioW = slideW / page.width, ratioH = slideH / page.height
        let scale = placement == .fit ? min(ratioW, ratioH) : max(ratioW, ratioH)
        let width = Int((page.width * scale).rounded()), height = Int((page.height * scale).rounded())
        return KeynoteGeometry(x: Int(((slideW - CGFloat(width)) / 2).rounded()), y: Int(((slideH - CGFloat(height)) / 2).rounded()), width: width, height: height)
    }

    /// Clamps a 1-based range to the document. nil when nothing remains.
    static func pages(_ range: ClosedRange<Int>?, count: Int) -> ClosedRange<Int>? {
        guard count > 0 else { return nil }
        guard let range else { return 1...count }
        let lower = max(1, range.lowerBound), upper = min(count, range.upperBound)
        return lower <= upper ? lower...upper : nil
    }

    /// "name.key", then "name 2.key", "name 3.key"… Never replaces an existing item.
    static func uniqueURL(folder: URL, base: String, ext: String) -> URL {
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(number)").appendingPathExtension(ext)
            number += 1
        }
        return candidate
    }
}

enum KeynotePDFSplitter {
    /// nil for folders and files PDFKit cannot open. Locked PDFs are rejected at conversion.
    static func pageCount(_ url: URL) -> Int? {
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true, let document = PDFDocument(url: url) else { return nil }
        return document.pageCount
    }

    /// Writes each page as a one-page PDF whose MediaBox/CropBox equal the chosen box.
    static func prepare(source: URL, options: KeynoteOptions, into folder: URL, isCancelled: () -> Bool) throws -> (slide: (Int, Int), pages: [KeynotePreparedPage]) {
        guard let document = PDFDocument(url: source) else { throw KeynoteError.unreadable }
        guard !document.isLocked else { throw KeynoteError.locked }
        guard let range = KeynoteLayout.pages(options.pageRange, count: document.pageCount) else { throw KeynoteError.emptyRange }
        let box = options.box.pdfBox
        guard let first = document.page(at: range.lowerBound - 1) else { throw KeynoteError.unreadable }
        let slide = KeynoteLayout.slideSize(options.slideSize, firstPage: KeynoteLayout.displaySize(of: first, box: box))
        var pages: [KeynotePreparedPage] = []
        for number in range {
            if isCancelled() { throw CancellationError() }
            try autoreleasepool {
                guard let page = document.page(at: number - 1), let copy = page.copy() as? PDFPage else { throw KeynoteError.unreadable }
                let rect = page.bounds(for: box)
                copy.setBounds(rect, for: .mediaBox)
                copy.setBounds(rect, for: .cropBox)
                let single = PDFDocument()
                single.insert(copy, at: 0)
                let url = folder.appendingPathComponent(String(format: "page-%04d.pdf", number))
                guard single.write(to: url) else { throw KeynoteError.writePage }
                pages.append(KeynotePreparedPage(url: url, geometry: KeynoteLayout.place(KeynoteLayout.displaySize(of: page, box: box), slide: slide, placement: options.placement)))
            }
        }
        return (slide, pages)
    }
}

/// Drives Keynote through the bundled compiled AppleScript via osascript.
/// The Automation (Apple Events) permission is attributed to the calling app.
struct KeynoteBridge {
    static let bundleID = "com.apple.Keynote"
    static var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil }

    let script: URL

    init(script: URL? = KeynoteBridge.runtimeScript) {
        self.script = script ?? URL(fileURLWithPath: "/nonexistent/Keynote.scpt")
    }

    /// osascript writes a compiled script back to disk after running it, which would
    /// break the app's code signature. Run a per-process copy outside the bundle instead.
    static let runtimeScript: URL? = {
        guard let bundled = Bundle.main.url(forResource: "Keynote", withExtension: "scpt") else { return nil }
        let name = (Bundle.main.bundleIdentifier ?? "app") + "-Keynote-\(ProcessInfo.processInfo.processIdentifier).scpt"
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: copy)
        return (try? FileManager.default.copyItem(at: bundled, to: copy)) != nil ? copy : nil
    }()

    /// Call from applicationWillTerminate.
    static func removeRuntimeScript() {
        if let runtimeScript { try? FileManager.default.removeItem(at: runtimeScript) }
    }

    @discardableResult
    func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [script.path] + arguments
        let output = Pipe(), error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        let outData = output.fileHandleForReading.readDataToEndOfFile()
        let errData = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let result = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw Self.error(from: String(decoding: errData, as: UTF8.self))
        }
        return result
    }

    /// osascript reports "execution error: <message> (<code>)".
    static func error(from message: String) -> KeynoteError {
        if message.contains("(-1743)") || message.contains("(-1744)") { return .automationDenied }
        if message.contains("(-1712)") { return .timeout }
        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "execution error: ") { text = String(text[range.upperBound...]) }
        return .keynote(text)
    }

    enum Permission { case allowed, denied, unknown }

    /// Never prompts unless `ask` is true. Unknown when Keynote is not running.
    static func permission(ask: Bool) -> Permission {
        var target = AEAddressDesc()
        let status: OSStatus = bundleID.withCString { pointer in
            guard AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target) == noErr else { return OSStatus(procNotFound) }
            defer { AEDisposeDesc(&target) }
            return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, ask)
        }
        switch status {
        case noErr: return .allowed
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .unknown
        }
    }

    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
    }

    static func activateKeynote() {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.activate()
    }
}

/// One PDF → one saved Keynote presentation. Cancellation is checked between steps;
/// an unfinished presentation is closed without saving and nothing is written.
enum KeynoteExporter {
    static let chunkSize = 10

    /// `destination` is evaluated right before saving and must name an unused path.
    static func export(pdf: URL, destination: () -> URL, options: KeynoteOptions, bridge: KeynoteBridge = KeynoteBridge(),
                       isCancelled: () -> Bool, progress: (Int, Int) -> Void = { _, _ in }) throws -> URL {
        guard KeynoteBridge.isInstalled else { throw KeynoteError.keynoteMissing }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("KeynoteExport-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let prepared = try KeynotePDFSplitter.prepare(source: pdf, options: options, into: work, isCancelled: isCancelled)
        if isCancelled() { throw CancellationError() }
        progress(0, prepared.pages.count)
        let documentID = try bridge.run(["create", String(prepared.slide.0), String(prepared.slide.1)])
        var output: URL?
        do {
            var done = 0
            while done < prepared.pages.count {
                if isCancelled() { throw CancellationError() }
                let chunk = prepared.pages[done..<min(done + chunkSize, prepared.pages.count)]
                let values = chunk.flatMap { [$0.url.path, String($0.geometry.x), String($0.geometry.y), String($0.geometry.width), String($0.geometry.height)] }
                try bridge.run(["add", documentID, String(done + 1)] + values)
                done += chunk.count
                progress(done, prepared.pages.count)
            }
            if isCancelled() { throw CancellationError() }
            let target = destination()
            output = target
            try bridge.run(["save", documentID, target.path])
        } catch {
            _ = try? bridge.run(["discard", documentID])
            // The name was free before saving, so anything there now is our partial output.
            if let output, FileManager.default.fileExists(atPath: output.path) { try? FileManager.default.removeItem(at: output) }
            throw error
        }
        if !options.openAfter { _ = try? bridge.run(["close", documentID]) }
        return output!
    }
}

/// Settings group content: Automation permission for Keynote, re-checked on activation.
struct KeynotePermissionView: View {
    @State private var permission = KeynoteBridge.Permission.unknown
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color).accessibilityHidden(true)
                Text(label)
            }
            Text(L("permissionWhy")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("permAsk")) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let result = KeynoteBridge.permission(ask: true)
                        DispatchQueue.main.async { permission = result }
                    }
                }
                Button(L("permOpen")) { KeynoteBridge.openAutomationSettings() }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }
    private func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let result = KeynoteBridge.permission(ask: false)
            DispatchQueue.main.async { permission = result }
        }
    }
    private var label: String { permission == .allowed ? L("permAllowed") : permission == .denied ? L("permDenied") : L("permUnknown") }
    private var icon: String { permission == .allowed ? "checkmark.circle.fill" : permission == .denied ? "xmark.octagon.fill" : "questionmark.circle" }
    private var color: Color { permission == .allowed ? .green : permission == .denied ? .red : .secondary }
}
