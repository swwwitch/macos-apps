import AppKit
import CoreImage

struct GenerationResult {
    var folder: URL
    var written: [String] = []
    var qrCodes: [String] = []
    var storesCopy: String?
    var emptyVariables: [String] = []
    var warnings: [String] = []
}

/// Where things live. The defaults follow the original workflow's Dropbox layout.
struct Locations {
    var root: String          // parent of the event folders
    var eventDoc: String      // EventDoc (Templates, Guide, Footer, …)
    var recent: String        // folder that holds links to recent events ("" = none)

    static var defaults: Locations {
        let shared = NSHomeDirectory() + "/sw Dropbox/takano masahiro/Dropbox-shared"
        return Locations(root: shared, eventDoc: shared + "/EventDoc", recent: shared + "/AT-Recent")
    }
    var templates: URL { URL(fileURLWithPath: eventDoc).appendingPathComponent("Templates") }
    func readDoc(_ relative: String) -> String? {
        try? String(contentsOf: URL(fileURLWithPath: eventDoc).appendingPathComponent(relative), encoding: .utf8)
    }
}

enum Generator {
    /// Template files: visible files with an extension, in name order (subfolders such as backups are skipped).
    static func templates(in folder: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { !$0.hasPrefix(".") && !($0 as NSString).pathExtension.isEmpty }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { folder.appendingPathComponent($0) }
            .filter { var dir: ObjCBool = false; return FileManager.default.fileExists(atPath: $0.path, isDirectory: &dir) && !dir.boolValue }
    }

    static let qrTargets: [(name: String, variable: String, size: Int)] = [
        ("YouTube", "EventYouTubeURL", 800), ("Doorkeeper", "EventDoorkeeper", 500), ("stores", "EventStoresFreelance", 500), ("アンケート", "EventQuestionnaire", 500),
    ]

    static func run(_ event: EventVariables, at places: Locations, makeQR: Bool) throws -> GenerationResult {
        let fm = FileManager.default
        let eventPath = event["EventPath"]
        let folder = URL(fileURLWithPath: places.root).appendingPathComponent(eventPath)
        let docs = folder.appendingPathComponent("docs")
        var result = GenerationResult(folder: folder)
        try fm.createDirectory(at: docs, withIntermediateDirectories: true)

        // Link to this event in the recent-events folder (replacing an older link of the same name only).
        if !places.recent.isEmpty {
            let link = URL(fileURLWithPath: places.recent).appendingPathComponent(eventPath)
            if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil { try? fm.removeItem(at: link) }
            if !fm.fileExists(atPath: link.path) {
                do { try fm.createSymbolicLink(at: link, withDestinationURL: folder) }
                catch { result.warnings.append(String(format: L("warn.link"), error.localizedDescription)) }
            }
        }

        // Templates
        var used: Set<String> = []
        for template in templates(in: places.templates) {
            guard let text = try? String(contentsOf: template, encoding: .utf8) else {
                result.warnings.append(String(format: L("warn.unreadable"), template.lastPathComponent)); continue
            }
            used.formUnion(Tokens.names(in: text))
            try Tokens.expand(text, event.vars).write(to: docs.appendingPathComponent(template.lastPathComponent), atomically: true, encoding: .utf8)
            result.written.append(template.lastPathComponent)
        }
        result.emptyVariables = used.filter { event[$0].isEmpty }.sorted()
        tag(docs.appendingPathComponent("42-問い合わせ.txt"))

        // STORES item text: 99-stores.txt copied as CeeBeeDee-<date>-<title>.txt (an older copy goes to the Trash).
        let stores = docs.appendingPathComponent("99-stores.txt")
        if fm.fileExists(atPath: stores.path) {
            let copy = docs.appendingPathComponent(event["EventDocStores"] + ".txt")
            if fm.fileExists(atPath: copy.path) { try? fm.trashItem(at: copy, resultingItemURL: nil) }
            do { try fm.copyItem(at: stores, to: copy); result.storesCopy = copy.lastPathComponent }
            catch { result.warnings.append(String(format: L("warn.stores"), error.localizedDescription)) }
        }

        if makeQR {
            for target in qrTargets {
                let value = event[target.variable].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, value != "-" else { continue }
                let file = folder.appendingPathComponent("qr-\(target.name)-\(eventPath).png")
                if let png = qrPNG(value, size: target.size) {
                    try png.write(to: file)
                    tag(file); result.qrCodes.append(file.lastPathComponent)
                } else { result.warnings.append(String(format: L("warn.qr"), target.name)) }
            }
        }
        result.warnings += event.missingDocs.map { String(format: L("warn.missingDoc"), $0) }
        return result
    }

    /// Purple Finder tag, as the original workflow marks these files.
    static func tag(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? (url as NSURL).setResourceValue(["パープル"], forKey: .tagNamesKey)
    }

    /// Square QR code PNG: black modules on white with a 40 px margin.
    static func qrPNG(_ text: String, size: Int, margin: Int = 40) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        // The generator adds a one-module quiet zone; crop it so the margin is exactly ours.
        let modules = output.extent.insetBy(dx: 1, dy: 1)
        guard let small = context.createCGImage(output, from: modules) else { return nil }
        let inner = size - margin * 2
        guard inner > 0, let bitmap = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                                 space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        bitmap.setFillColor(CGColor(gray: 1, alpha: 1)); bitmap.fill(CGRect(x: 0, y: 0, width: size, height: size))
        bitmap.interpolationQuality = .none
        bitmap.draw(small, in: CGRect(x: margin, y: margin, width: inner, height: inner))
        guard let image = bitmap.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
