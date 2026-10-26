import AppKit
import AVFoundation
import ScreenCaptureKit

enum RecordError: Error {
    case permission
    case noTarget
    case failed(String)
}

/// What to record. The choices come from the main window.
struct RecordOptions {
    enum Target: Equatable { case display(CGDirectDisplayID), window(CGWindowID) }
    var target: Target
    var systemAudio: Bool
    var microphoneID: String?
    var cameraID: String?
    var showCursor: Bool
    var fps: Int
}

/// Host-clock seconds, the clock ScreenCaptureKit and the camera stamp their samples with.
func hostNow() -> Double { CMClockGetTime(CMClockGetHostTimeClock()).seconds }

/// Records the screen (or one window), system audio, the microphone and the camera into one movie:
/// track order screen, camera, system audio, microphone (RecordingInfo relies on it).
/// Sample buffers arrive on `queue`; pausing drops samples and shifts the later ones back by the paused time.
final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let folder: URL
    let options: RecordOptions
    var movieURL: URL { folder.appendingPathComponent("recording.mov") }
    /// Called on the main queue: the stream stopped by itself (display gone, permission withdrawn).
    var onStreamError: ((String) -> Void)?

    private let queue = DispatchQueue(label: "ScreenTake.recorder")
    private var stream: SCStream?
    private var writer: AVAssetWriter!
    private var screenInput: AVAssetWriterInput!
    private var cameraInput: AVAssetWriterInput?
    private var systemInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var camera: AVCaptureSession?
    private(set) var pixelSize = CGSize.zero
    var pixelsPerPoint: Double { area.width > 0 ? Double(pixelSize.width / area.width) : 2 }
    /// Global top-left points of the recorded area, for the pointer.
    private(set) var area = CGRect.zero
    private var windowID: CGWindowID?

    // Touched on `queue` only.
    private var startTime: Double?
    private var lastScreenTime = 0.0
    private var pauses: [Span] = []
    private var pausedSince: Double?
    private var stopping = false
    private var writeError: String?

    init(folder: URL, options: RecordOptions) {
        self.folder = folder; self.options = options
    }

    // MARK: Start and stop

    func start() async throws {
        guard CGPreflightScreenCaptureAccess() else { throw RecordError.permission }
        let content: SCShareableContent
        do { content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
        catch { throw RecordError.permission }
        let config = SCStreamConfiguration()
        let filter: SCContentFilter
        var scale: CGFloat = 2
        switch options.target {
        case .display(let wanted):
            guard let display = content.displays.first(where: { $0.displayID == wanted }) else { throw RecordError.noTarget }
            scale = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID }?.backingScaleFactor ?? 2
            // Leave out ScreenTake's own windows (the recording controls).
            let own = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
            area = display.frame
        case .window(let wanted):
            guard let window = content.windows.first(where: { $0.windowID == wanted }) else { throw RecordError.noTarget }
            scale = NSScreen.screens.first { $0.frame.intersects(Recorder.cocoaRect(window.frame)) }?.backingScaleFactor ?? 2
            filter = SCContentFilter(desktopIndependentWindow: window)
            area = window.frame; windowID = window.windowID
        }
        let width = Int(area.width * scale) & ~1, height = Int(area.height * scale) & ~1
        pixelSize = CGSize(width: width, height: height)
        config.width = width; config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(options.fps))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        // The pointer is recorded as its own layer (PointerLog), so the editor can resize or hide it.
        config.showsCursor = false
        config.queueDepth = 8
        config.capturesAudio = options.systemAudio
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000; config.channelCount = 2
        if let mic = options.microphoneID { config.captureMicrophone = true; config.microphoneCaptureDeviceID = mic }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        writer = try AVAssetWriter(outputURL: movieURL, fileType: .mov)
        // HEVC: Retina displays are wider than H.264's 4096-pixel limit.
        screenInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: max(8_000_000, width * height * options.fps / 12), AVVideoExpectedSourceFrameRateKey: options.fps]])
        screenInput.expectsMediaDataInRealTime = true
        writer.add(screenInput)
        if let cameraID = options.cameraID { try setUpCamera(cameraID) }
        if options.systemAudio { systemInput = audioInput(channels: 2) }
        if options.microphoneID != nil { micInput = audioInput(channels: 1) }
        guard writer.startWriting() else { throw RecordError.failed(writer.error?.localizedDescription ?? "AVAssetWriter") }

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        if options.systemAudio { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue) }
        if options.microphoneID != nil { try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue) }
        self.stream = stream
        camera?.startRunning()
        do { try await stream.startCapture() }
        catch { camera?.stopRunning(); writer.cancelWriting(); throw RecordError.failed(error.localizedDescription) }
    }

    private func audioInput(channels: Int) -> AVAssetWriterInput {
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: channels, AVEncoderBitRateKey: channels == 2 ? 192_000 : 128_000])
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        return input
    }

    private func setUpCamera(_ id: String) throws {
        guard let device = AVCaptureDevice(uniqueID: id) else { throw RecordError.failed("camera") }
        let session = AVCaptureSession()
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw RecordError.failed("camera") }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw RecordError.failed("camera") }
        session.addOutput(output)
        session.commitConfiguration()
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let w = session.sessionPreset == .hd1280x720 ? 1280 : Int(dimensions.width), h = session.sessionPreset == .hd1280x720 ? 720 : Int(dimensions.height)
        let cameraInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        cameraInput.expectsMediaDataInRealTime = true
        writer.add(cameraInput)
        self.cameraInput = cameraInput
        camera = session
    }

    func pause() { let now = hostNow(); queue.async { if self.pausedSince == nil { self.pausedSince = now } } }
    func resume() {
        let now = hostNow()
        queue.async { if let since = self.pausedSince { self.pauses.append(Span(start: since, end: now)); self.pausedSince = nil } }
    }

    /// Stops and closes the movie. Returns the recorded length in seconds.
    func stop() async throws -> Double {
        try? await stream?.stopCapture()
        stream = nil
        camera?.stopRunning(); camera = nil
        let (started, last, error) = queue.sync { () -> (Bool, Double, String?) in
            stopping = true
            if let since = pausedSince { pauses.append(Span(start: since, end: hostNow())); pausedSince = nil }
            return (startTime != nil, lastScreenTime, writeError)
        }
        guard started else { writer.cancelWriting(); throw RecordError.failed(error ?? "no frames") }
        for input in [screenInput, cameraInput, systemInput, micInput].compactMap({ $0 }) { input.markAsFinished() }
        writer.endSession(atSourceTime: CMTime(seconds: last, preferredTimescale: 600))
        await writer.finishWriting()
        if writer.status != .completed { throw RecordError.failed(writer.error?.localizedDescription ?? error ?? "AVAssetWriter") }
        return queue.sync { lastScreenTime - (startTime ?? 0) }
    }

    /// Host seconds → seconds into the movie, or nil while paused/before the start.
    func movieTime(host t: Double) -> Double? {
        queue.sync { shifted(t).map { $0 - (startTime ?? $0) } }
    }

    // MARK: Samples (on `queue`)

    /// Host seconds with the paused time taken out; nil inside a pause.
    private func shifted(_ t: Double) -> Double? {
        if let since = pausedSince, t >= since { return nil }
        var offset = 0.0
        for pause in pauses {
            if t >= pause.end { offset += pause.duration } else if t >= pause.start { return nil }
        }
        return t - offset
    }

    private func append(_ buffer: CMSampleBuffer, to input: AVAssetWriterInput?) {
        guard let input, !stopping, writer.status == .writing, let start = startTime else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        guard let t = shifted(pts), t >= start else { return }
        var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(buffer), presentationTimeStamp: CMTime(seconds: t, preferredTimescale: 1_000_000_000), decodeTimeStamp: .invalid)
        var copy: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: buffer, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &copy) == noErr, let copy else { return }
        if input.isReadyForMoreMediaData, !input.append(copy) { writeError = writer.error?.localizedDescription }
        if input === screenInput { lastScreenTime = max(lastScreenTime, t) }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard buffer.isValid else { return }
        switch type {
        case .screen:
            // Frames without a new picture (nothing changed) carry no image.
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete else { return }
            if startTime == nil, !stopping, pausedSince == nil, let t = shifted(CMSampleBufferGetPresentationTimeStamp(buffer).seconds) {
                startTime = t
                writer.startSession(atSourceTime: CMTime(seconds: t, preferredTimescale: 1_000_000_000))
            }
            append(buffer, to: screenInput)
        case .audio: append(buffer, to: systemInput)
        case .microphone: append(buffer, to: micInput)
        @unknown default: break
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // The camera's clock may differ from the host clock the screen uses.
        guard let session = camera, let clock = session.synchronizationClock else { append(buffer, to: cameraInput); return }
        let pts = CMSyncConvertTime(CMSampleBufferGetPresentationTimeStamp(buffer), from: clock, to: CMClockGetHostTimeClock())
        var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(buffer), presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var copy: CMSampleBuffer?
        if CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: buffer, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &copy) == noErr, let copy {
            append(copy, to: cameraInput)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.onStreamError?(error.localizedDescription) }
    }

    // MARK: Pointer

    /// The recorded area now, in global top-left points (a window may move).
    func currentArea() -> CGRect {
        guard let windowID, let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let bounds = list.first?[kCGWindowBounds as String] as? NSDictionary, let rect = CGRect(dictionaryRepresentation: bounds) else { return area }
        return rect
    }

    static func cocoaRect(_ rect: CGRect) -> CGRect {
        let height = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// Samples the pointer (position and shape) and clicks while recording (host seconds), converted to movie time at the end.
@MainActor final class PointerLog {
    private var samples: [(t: Double, x: Double, y: Double, c: Int)] = []
    private var clicks: [(t: Double, x: Double, y: Double, right: Bool)] = []
    private var timer: Timer?
    private var monitors: [Any] = []
    private var area = CGRect.zero
    private var areaRefresh = 0.0
    private weak var recorder: Recorder?
    // Pointer shapes seen so far: the picture as PNG and its geometry.
    private var shapes: [(shape: CursorShape, png: Data)] = []
    private var lastKey = ""
    private var lastShape = 0
    private var ticks = 0

    func start(_ recorder: Recorder) {
        self.recorder = recorder
        area = recorder.area
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.sample() } }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // Mouse events need no permission (only keys do).
        let handler: (NSEvent) -> Void = { [weak self] event in
            MainActor.assumeIsolated { self?.click(right: event.type == .rightMouseDown) }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handler) { monitors.append(global) }
    }
    private func normalized() -> (Double, Double)? {
        guard let location = CGEvent(source: nil)?.location, area.width > 0, area.height > 0 else { return nil }
        return (Double((location.x - area.minX) / area.width), Double((location.y - area.minY) / area.height))
    }
    /// The id of the pointer shown now. The size and hot spot tell most shapes apart cheaply; the picture is compared twice a second.
    private func currentShape() -> Int {
        guard let cursor = NSCursor.currentSystem else { return lastShape }
        let image = cursor.image
        let key = "\(image.size.width)x\(image.size.height)@\(cursor.hotSpot.x),\(cursor.hotSpot.y)"
        ticks += 1
        if key == lastKey && ticks % 30 != 0 { return lastShape }
        lastKey = key
        var rect = CGRect(x: 0, y: 0, width: image.size.width * 4, height: image.size.height * 4)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return lastShape }
        if let known = shapes.first(where: { $0.png == png }) { lastShape = known.shape.id; return lastShape }
        let shape = CursorShape(id: shapes.count, width: image.size.width, height: image.size.height, hotX: cursor.hotSpot.x, hotY: cursor.hotSpot.y)
        shapes.append((shape, png))
        lastShape = shape.id
        return lastShape
    }
    private func sample() {
        let now = hostNow()
        if now - areaRefresh > 0.5, let recorder { area = recorder.currentArea(); areaRefresh = now }
        let shape = currentShape()
        guard let (x, y) = normalized() else { return }
        if let last = samples.last, last.x == x, last.y == y, last.c == shape, now - last.t < 0.5 { return }
        samples.append((now, x, y, shape))
    }
    private func click(right: Bool) {
        guard let (x, y) = normalized(), (0...1).contains(x), (0...1).contains(y) else { return }
        clicks.append((hostNow(), x, y, right))
    }
    /// Stops, saves the pointer pictures in `folder`/cursors and returns the track and shapes.
    func stop(saveIn folder: URL) -> (CursorTrack, [CursorShape]) {
        timer?.invalidate(); timer = nil
        monitors.forEach(NSEvent.removeMonitor); monitors = []
        guard let recorder else { return (CursorTrack(), []) }
        let directory = folder.appendingPathComponent("cursors", isDirectory: true)
        var saved: [CursorShape] = []
        if (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil {
            for (shape, png) in shapes where (try? png.write(to: directory.appendingPathComponent("\(shape.id).png"))) != nil { saved.append(shape) }
        }
        let track = CursorTrack(samples: samples.compactMap { s in recorder.movieTime(host: s.t).map { CursorSample(t: $0, x: s.x, y: s.y, c: s.c) } },
                                clicks: clicks.compactMap { c in recorder.movieTime(host: c.t).map { ClickSample(t: $0, x: c.x, y: c.y, right: c.right) } })
        return (track, saved)
    }
}
