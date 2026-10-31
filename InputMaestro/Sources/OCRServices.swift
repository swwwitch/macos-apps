import AppKit
import Vision
import ImageIO
enum TextRecognizer {
    /// Japanese and English text, top to bottom, one line per observation. Runs synchronously; call off the main thread.
    static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

enum AreaCapture {
    /// The system's interactive area selection (screencapture -i). nil when cancelled with Esc.
    /// Off the main thread: it waits until the user finishes selecting.
    static func capture() -> URL? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("InputMaestro-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", file.path]
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
    static var allowed: Bool { CGPreflightScreenCaptureAccess() }
}
