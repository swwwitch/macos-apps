import Foundation
import ImageIO
import Vision
import UniformTypeIdentifiers

struct ScreenshotLabelResult: Sendable {
    let preview: Data
    let lines: [String]
}

enum ScreenshotLabels {
    /// Downsample before recognition, never execute or upload the selected file.
    static func recognize(_ url: URL) throws -> ScreenshotLabelResult {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["ja-JP", "en-US", "zh-Hans", "ko-KR"].filter(supported.contains)
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines = uniqueLines((request.results ?? []).compactMap { $0.topCandidates(1).first?.string })
        let preview = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(preview, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileReadCorruptFile) }
        return ScreenshotLabelResult(preview: preview as Data, lines: lines)
    }

    static func uniqueLines(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        return lines.compactMap {
            let text = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !text.isEmpty && seen.insert(text).inserted ? text : nil
        }
    }
}
