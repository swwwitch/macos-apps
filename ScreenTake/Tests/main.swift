import AVFoundation
import AppKit

// Timeline math, then an end-to-end export of a generated movie (no screen recording needed).
setvbuf(stdout, nil, _IONBF, 0)
var failures = 0
func check(_ ok: Bool, _ name: String, file: StaticString = #file, line: UInt = #line) {
    if !ok { failures += 1; print("FAIL \(name) (line \(line))") }
}
func near(_ a: Double, _ b: Double, _ e: Double = 1e-6) -> Bool { abs(a - b) < e }

// MARK: Timeline
let kept = Timeline.kept(duration: 10, removed: [Span(start: 2, end: 3), Span(start: 2.5, end: 4), Span(start: 9, end: 12)])
check(kept == [Span(start: 0, end: 2), Span(start: 4, end: 9)], "kept merges and clips")
check(near(Timeline.outputDuration(kept), 7), "output duration")
check(near(Timeline.toSource(1, kept: kept), 1), "toSource first piece")
check(near(Timeline.toSource(2.5, kept: kept), 4.5), "toSource second piece")
check(Timeline.toOutput(3, kept: kept) == nil, "inside a cut")
check(near(Timeline.toOutputClamped(3, kept: kept), 2), "clamped to the cut")
check(near(Timeline.toOutput(5, kept: kept)!, 3), "toOutput")
check(Timeline.sourceSpans(output: Span(start: 1, end: 3), kept: kept) == [Span(start: 1, end: 2), Span(start: 4, end: 5)], "range across a cut")
check(Timeline.kept(duration: 5, removed: [Span(start: 0, end: 4.98)]).isEmpty, "slivers are dropped")
check(Timeline.kept(duration: 5, removed: []) == [Span(start: 0, end: 5)], "no cuts")

let zoom = ZoomSpan(start: 1, end: 3, scale: 2, followCursor: false, centerX: 0.9, centerY: 0.1)
check(near(Timeline.zoomAmount(zoom, at: 0.5), 0), "zoom off before")
check(near(Timeline.zoomAmount(zoom, at: 2), 1), "zoom full in the middle")
let rect = Timeline.visibleRect(at: 2, zooms: [zoom], cursor: CursorTrack())
check(near(rect.w, 0.5) && near(rect.x, 0.5) && near(rect.y, 0), "zoom stays inside the picture")
let none = Timeline.visibleRect(at: 5, zooms: [zoom], cursor: CursorTrack())
check(none == (0, 0, 1, 1), "no zoom")
let track = CursorTrack(samples: [CursorSample(t: 0, x: 0, y: 0), CursorSample(t: 1, x: 1, y: 0.5)], clicks: [ClickSample(t: 1, x: 0.5, y: 0.5)])
check(near(track.position(at: 0.5)!.x, 0.5), "pointer interpolates")
check(Timeline.activeClicks(at: 1.2, cursor: track).count == 1 && Timeline.activeClicks(at: 2, cursor: track).isEmpty, "click ring lifetime")

check(Timeline.subtract([Span(start: 2, end: 3)], from: [Span(start: 1, end: 5)]) == [Span(start: 1, end: 2), Span(start: 3, end: 5)], "subtract splits")
let shaped = CursorTrack(samples: [CursorSample(t: 0, x: 0, y: 0, c: 0), CursorSample(t: 1, x: 0, y: 0, c: 1)])
check(shaped.shape(at: 0.5) == 0 && shaped.shape(at: 1) == 1 && shaped.shape(at: 3) == 1, "pointer shape by time")
let old = try! JSONDecoder().decode(EditDecision.self, from: Data(#"{"removed":[],"zooms":[],"highlightClicks":true}"#.utf8))
check(old.showCursor && old.cursorScale == 1 && old.cursorHidden.isEmpty, "older project.json still opens")

// MARK: Export of a generated recording
let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ScreenTakeTest-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: dir) }

/// 4 s, 640×360 screen (frame number shade) + 320×180 camera + a silent stereo track, like the recorder writes.
func makeMovie(_ url: URL) throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    func video(_ w: Int, _ h: Int) -> (AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor) {
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        return (input, AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h]))
    }
    let screen = video(640, 360), camera = video(320, 180)
    let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128000])
    audio.expectsMediaDataInRealTime = true
    writer.add(audio)
    // 4 s of silence in 1024-frame packets.
    var format: CMAudioFormatDescription?
    var asbd = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                           mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
    CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
    var nextPacket = 0
    func appendAudio(until seconds: Double) {
        while nextPacket < 48000 * 4 / 1024 && Double(nextPacket * 1024) / 48000 < seconds {
            let packet = nextPacket; nextPacket += 1
            var block: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: 1024 * 8, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: 1024 * 8, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block)
            CMBlockBufferFillDataBytes(with: 0, blockBuffer: block!, offsetIntoDestination: 0, dataLength: 1024 * 8)
            var sample: CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block!, formatDescription: format!, sampleCount: 1024,
                                                                 presentationTimeStamp: CMTime(value: CMTimeValue(packet * 1024), timescale: 48000), packetDescriptions: nil, sampleBufferOut: &sample)
            while !audio.isReadyForMoreMediaData { usleep(1000) }
            audio.append(sample!)
        }
    }
    writer.startWriting(); writer.startSession(atSourceTime: .zero)
    for frame in 0..<120 {
        let time = CMTime(value: CMTimeValue(frame), timescale: 30)
        appendAudio(until: Double(frame + 1) / 30)
        for (input, adaptor) in [screen, camera] {
            while !input.isReadyForMoreMediaData { usleep(1000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            CVPixelBufferLockBaseAddress(buffer!, [])
            memset(CVPixelBufferGetBaseAddress(buffer!), Int32(frame * 2), CVPixelBufferGetDataSize(buffer!))
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            adaptor.append(buffer!, withPresentationTime: time)
        }
    }
    appendAudio(until: 5)
    [screen.0, camera.0, audio].forEach { $0.markAsFinished() }
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    guard writer.status == .completed else { throw writer.error ?? RecordError.failed("writer") }
}

let movie = dir.appendingPathComponent("recording.mov")
print("making movie"); try! makeMovie(movie); print("movie made")
var info = RecordingInfo(duration: 4, width: 640, height: 360, fps: 30, hasCamera: true, hasSystemAudio: true, hasMicrophone: false,
                         cursor: CursorTrack(samples: [CursorSample(t: 0, x: 0.2, y: 0.2), CursorSample(t: 4, x: 0.8, y: 0.8)], clicks: [ClickSample(t: 0.5, x: 0.5, y: 0.5)]))
info.edits.removed = [Span(start: 1, end: 2)]
// A pointer layer: one 16×24 pt shape, scaled 2× and hidden for part of the movie.
try! FileManager.default.createDirectory(at: dir.appendingPathComponent("cursors"), withIntermediateDirectories: true)
let arrow = NSImage(size: NSSize(width: 64, height: 96), flipped: false) { r in NSColor.red.setFill(); r.fill(); return true }
try! NSBitmapImageRep(data: arrow.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("cursors/0.png"))
info.cursorShapes = [CursorShape(id: 0, width: 16, height: 24, hotX: 1, hotY: 1)]
info.pixelsPerPoint = 2
info.cursor.samples = info.cursor.samples.map { var s = $0; s.c = 0; return s }
info.edits.cursorScale = 2
info.edits.cursorHidden = [Span(start: 3, end: 3.5)]
info.edits.zooms = [ZoomSpan(start: 2, end: 3.5)]

Task {
    do {
        let mp4 = dir.appendingPathComponent("out.mp4")
        try await Exporter.export(movie: movie, info: info, options: ExportOptions(format: .mp4, size: .original), to: mp4) { _ in }
        let asset = AVURLAsset(url: mp4)
        let duration = try await asset.load(.duration).seconds
        check(abs(duration - 3) < 0.15, "mp4 is 3 s after a 1 s cut (got \(duration))")
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let size = try await tracks.first!.load(.naturalSize)
        check(size == CGSize(width: 640, height: 360), "mp4 keeps the size (got \(size))")
        check(try await asset.loadTracks(withMediaType: .audio).count == 1, "mp4 has the audio")
        // The pointer layer: red where the scaled pointer is, at 0.1 s (pointer near 0.215, 0.215; 4 px per point).
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        let (frame, _) = try await generator.image(at: CMTime(value: 1, timescale: 10))
        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int) {
            let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(frame, in: CGRect(x: -x, y: y - frame.height + 1, width: frame.width, height: frame.height))
            let p = context.data!.assumingMemoryBound(to: UInt8.self)
            return (Int(p[0]), Int(p[1]))
        }
        let inside = pixel(Int(0.215 * 640) + 20, Int(0.215 * 360) + 40), outside = pixel(Int(0.215 * 640) + 120, Int(0.215 * 360) + 140)
        check(inside.r > 180 && inside.g < 80, "pointer drawn (got \(inside))")
        check(!(outside.r > 180 && outside.g < 80), "nothing red away from the pointer (got \(outside))")

        print("mp4 done")
        let small = dir.appendingPathComponent("small.mov")
        info.edits.showCamera = false
        try await Exporter.export(movie: movie, info: info, options: ExportOptions(format: .mov, size: .p720), to: small) { _ in }
        check(FileManager.default.fileExists(atPath: small.path), "mov written")

        print("mov done")
        let gif = dir.appendingPathComponent("out.gif")
        try await Exporter.export(movie: movie, info: info, options: ExportOptions(format: .gif, gifWidth: 320, gifFPS: 10), to: gif) { _ in }
        let source = CGImageSourceCreateWithURL(gif as CFURL, nil)!
        check(CGImageSourceGetCount(source) == 30, "gif has 3 s × 10 frames (got \(CGImageSourceGetCount(source)))")
        let first = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        check(first.width == 320 && first.height == 180, "gif size")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix(".") }
        check(leftovers.isEmpty, "no temporary files left")
    } catch {
        failures += 1; print("FAIL export threw \(error)")
    }
    print(failures == 0 ? "PASS: timeline and export tests" : "\(failures) failure(s)")
    exit(failures == 0 ? 0 : 1)
}
dispatchMain()
