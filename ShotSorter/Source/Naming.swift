import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Pixel size and resolution of an image file.
struct ImageInfo: Equatable {
    var width: Int
    var height: Int
    var dpi: Int
}

enum ShotNaming {
    static let defaultTemplate = "ss-{width}-{height}-{dpi}-{date}"
    static let dateFormat = "yyyyMMdd-HHmmss"

    /// New screenshots: PNG files whose name does not contain "ss-" (already renamed ones do).
    static func isCandidate(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".png") && !lower.contains("ss-") && !name.hasPrefix(".")
    }

    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    /// File name (with .png) from the template. Characters a file name cannot hold become "-".
    static func name(template: String, info: ImageInfo, date: Date) -> String {
        var base = template.isEmpty ? defaultTemplate : template
        for (token, value) in [("{width}", "\(info.width)"), ("{height}", "\(info.height)"), ("{dpi}", "\(info.dpi)"), ("{date}", format(date))] {
            base = base.replacingOccurrences(of: token, with: value)
        }
        base = base.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-").trimmingCharacters(in: .whitespaces)
        return (base.isEmpty ? "ss" : base) + ".png"
    }

    /// CommentScreen QR code screenshots: text that starts with "QRCode" and holds "QRCode #sw-12345678".
    static func qrCodeName(ocr: String) -> String? {
        let text = ocr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: "QRCode", options: [.anchored, .caseInsensitive]) != nil,
              let match = text.range(of: #"QRCode #sw-(\d{8})"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let digits = text[match].suffix(8)
        return "CommentScreen-QRCode-\(digits).png"
    }

    /// A free URL in `folder`: "name.ext", then "name 2.ext", "name 3.ext", …
    static func unique(_ name: String, in folder: URL, exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name), number = 2
        while exists(candidate) {
            candidate = folder.appendingPathComponent("\(base) \(number)" + (ext.isEmpty ? "" : ".\(ext)"))
            number += 1
        }
        return candidate
    }
}

enum OCRText {
    /// Removes spaces and line breaks between two Japanese (non-ASCII) characters.
    static func joinJapanese(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?<=[^\x00-\x7E])[ \t　\n]+(?=[^\x00-\x7E])"#, with: "", options: .regularExpression)
    }
    static func fullwidthParens(_ text: String) -> String {
        text.replacingOccurrences(of: "(", with: "（").replacingOccurrences(of: ")", with: "）")
    }
    static func clean(_ text: String, join: Bool, parens: Bool) -> String {
        var out = text
        if join { out = joinJapanese(out) }
        if parens { out = fullwidthParens(out) }
        return out
    }
}

/// Files still being written are skipped until they settle.
enum PartialFile {
    static let suffixes = [".download", ".crdownload", ".part", ".partial", ".tmp", ".opdownload"]
    static func isPartial(_ name: String) -> Bool {
        let lower = name.lowercased()
        return name.hasPrefix(".") || suffixes.contains { lower.hasSuffix($0) }
    }
}
