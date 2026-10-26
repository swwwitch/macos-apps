import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Codable { case mp4, mov, gif }
enum ExportSize: Int, CaseIterable, Codable {
    case original = 0, p2160 = 2160, p1440 = 1440, p1080 = 1080, p720 = 720
    var maxHeight: Int? { self == .original ? nil : rawValue }
}

struct ExportOptions {
    var format = ExportFormat.mp4
    var size = ExportSize.p1080
    /// HEVC for MP4/MOV; H.264 otherwise (plays everywhere).
    var hevc = false
    var gifWidth = 800
    var gifFPS = 10
}

enum Exporter {
    /// Writes the edited movie to `url`. A hidden file is written first and renamed at the end, so a failed or
    /// canceled export leaves nothing broken behind (and an existing file is replaced only on success).
    static func export(movie movieURL: URL, info: RecordingInfo, options: ExportOptions, to url: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString)-\(url.lastPathComponent)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let asset = AVURLAsset(url: movieURL)
        if options.format == .gif {
            let height = Int((Double(options.gifWidth) * Double(info.height) / Double(info.width)).rounded())
            let movie = try await EditedMovie.build(asset: asset, info: info, renderSize: EditedMovie.even(CGSize(width: options.gifWidth, height: max(2, height))))
            try await writeGIF(movie, fps: options.gifFPS, to: temporary, progress: progress)
        } else {
            let movie = try await EditedMovie.build(asset: asset, info: info, renderSize: EditedMovie.renderSize(info, maxHeight: options.size.maxHeight))
            let preset = options.hevc ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
            guard let session = AVAssetExportSession(asset: movie.composition, presetName: preset) else { throw RecordError.failed("AVAssetExportSession") }
            session.videoComposition = movie.videoComposition
            session.audioMix = movie.audioMix
            let watcher = Task {
                for await state in session.states(updateInterval: 0.2) {
                    if case .exporting(let p) = state { progress(p.fractionCompleted) }
                }
            }
            defer { watcher.cancel() }
            try await session.export(to: temporary, as: options.format == .mov ? .mov : .mp4)
        }
        try Task.checkCancellation()
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        progress(1)
    }

    private static func writeGIF(_ movie: EditedMovie, fps: Int, to url: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let count = max(1, Int(movie.duration * Double(fps)))
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, count, nil) else { throw RecordError.failed("GIF") }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let generator = AVAssetImageGenerator(asset: movie.composition)
        generator.videoComposition = movie.videoComposition
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
        let frame = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / Double(fps)]] as CFDictionary
        let times = (0..<count).map { CMTime(seconds: Double($0) / Double(fps), preferredTimescale: 600) }
        var done = 0
        for await result in generator.images(for: times) {
            try Task.checkCancellation()
            if let image = try? result.image { CGImageDestinationAddImage(destination, image, frame) }
            done += 1
            progress(Double(done) / Double(count))
        }
        guard CGImageDestinationFinalize(destination) else { throw RecordError.failed("GIF") }
    }
}
