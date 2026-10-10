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
        let image = bundledLegacyIcon(for: sourceURL) ?? NSWorkspace.shared.icon(forFile: sourceURL.path)
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

    /// .icnsだけを持つアプリは同梱の.icnsを返す。
    /// macOS 26はこの形式のアイコンをグレーの枠に入れて表示するため、NSWorkspaceを経由すると枠ごと書き出してしまう。
    private static func bundledLegacyIcon(for sourceURL: URL) -> NSImage? {
        guard let bundle = Bundle(url: sourceURL), bundle.bundleURL.pathExtension == "app",
              bundle.object(forInfoDictionaryKey: "CFBundleIconName") == nil,
              var iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
              !iconFile.isEmpty else {
            return nil
        }
        if (iconFile as NSString).pathExtension.isEmpty {
            iconFile += ".icns"
        }
        guard let iconURL = bundle.resourceURL?.appendingPathComponent(iconFile) else {
            return nil
        }
        return NSImage(contentsOf: iconURL)
    }

    private static func largestBitmap(from image: NSImage) throws -> NSBitmapImageRep {
        // 描画は最大の1枚だけにする（全32サイズを描くと1個あたり0.5〜1秒かかる）。
        let largest = image.representations
            .filter { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
            .max { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }

        if let largest {
            if let bitmap = largest as? NSBitmapImageRep {
                return bitmap
            }
            if let rendered = render(representation: largest) {
                return rendered
            }
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
