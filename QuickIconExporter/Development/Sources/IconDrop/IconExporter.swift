import AppKit
import Foundation

struct ExportResult: Sendable {
    let sourceName: String
    let outputURL: URL
    let pixelWidth: Int
    let pixelHeight: Int
}

enum IconExportError: LocalizedError {
    case noBitmapRepresentation
    case cannotCreatePNG

    var errorDescription: String? {
        switch self {
        case .noBitmapRepresentation:
            return L("アイコンの画像データを取得できませんでした。")
        case .cannotCreatePNG:
            return L("PNGデータを作成できませんでした。")
        }
    }
}

enum IconExporter {
    static func exportIcon(
        for sourceURL: URL,
        to directoryURL: URL,
        rules: FilenameRules
    ) throws -> ExportResult {
        let image = NSWorkspace.shared.icon(forFile: sourceURL.path)
        let bitmap = try largestBitmap(from: image)

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw IconExportError.cannotCreatePNG
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let baseName = outputBaseName(for: sourceURL, rules: rules)
        let destination = availableURL(in: directoryURL, baseName: baseName)
        try pngData.write(to: destination, options: .atomic)

        return ExportResult(
            sourceName: sourceURL.lastPathComponent,
            outputURL: destination,
            pixelWidth: bitmap.pixelsWide,
            pixelHeight: bitmap.pixelsHigh
        )
    }

    static func outputBaseName(for sourceURL: URL, rules: FilenameRules) -> String {
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let prefix = rules.prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined: String
        if prefix.isEmpty {
            joined = originalName
        } else {
            switch rules.iconNamePosition {
            case .beforeFilename:
                joined = "\(prefix)\(rules.separator.rawValue)\(originalName)"
            case .afterFilename:
                joined = "\(originalName)\(rules.separator.rawValue)\(prefix)"
            }
        }

        let spaceProcessed: String
        switch rules.spaceReplacement {
        case .keep:
            spaceProcessed = joined
        case .hyphen:
            spaceProcessed = joined.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        case .underscore:
            spaceProcessed = joined.replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
        }

        guard rules.removesUnwantedCharacters else {
            return normalizedFallback(spaceProcessed)
        }

        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_"))
        let cleaned = spaceProcessed.unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
        return normalizedFallback(cleaned)
    }

    private static func normalizedFallback(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return trimmed.isEmpty ? "icon" : trimmed
    }

    private static func largestBitmap(from image: NSImage) throws -> NSBitmapImageRep {
        let bitmapRepresentations = image.representations.compactMap { representation -> NSBitmapImageRep? in
            if let bitmap = representation as? NSBitmapImageRep {
                return bitmap
            }
            guard representation.pixelsWide > 0, representation.pixelsHigh > 0 else {
                return nil
            }
            return render(representation: representation)
        }

        if let largest = bitmapRepresentations.max(by: {
            ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh)
        }) {
            return largest
        }

        if let tiffData = image.tiffRepresentation,
           let fallback = NSBitmapImageRep(data: tiffData) {
            return fallback
        }

        throw IconExportError.noBitmapRepresentation
    }

    private static func render(representation: NSImageRep) -> NSBitmapImageRep? {
        let width = representation.pixelsWide
        let height = representation.pixelsHigh
        guard width > 0, height > 0,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ) else {
            return nil
        }

        bitmap.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        representation.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private static func availableURL(in directory: URL, baseName: String) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension("png")
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName)-\(counter)")
                .appendingPathExtension("png")
            counter += 1
        }
        return candidate
    }
}
