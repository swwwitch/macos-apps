import AVFoundation
import CoreImage
import AppKit

/// Everything a frame needs besides the source pictures. Preview and export render through the same code.
struct RenderPlan {
    var kept: [Span]
    var edits: EditDecision
    var cursor: CursorTrack
    var renderSize: CGSize
    /// The pointer layer: pictures by shape id, and the recording's height in points.
    var cursorImages: [Int: (image: CIImage, shape: CursorShape)] = [:]
    var recordedPointHeight: Double = 0

    /// The edited picture at edited-movie time t.
    func image(screen: CIImage, camera: CIImage?, at t: Double) -> CIImage {
        let source = Timeline.toSource(t, kept: kept)
        let extent = screen.extent
        let view = Timeline.visibleRect(at: source, zooms: edits.zooms, cursor: cursor)
        // Normalized top-left → Core Image pixels (bottom-left origin).
        let crop = CGRect(x: extent.minX + view.x * extent.width, y: extent.minY + (1 - view.y - view.h) * extent.height,
                          width: view.w * extent.width, height: view.h * extent.height)
        let scaleX = renderSize.width / crop.width, scaleY = renderSize.height / crop.height
        var picture = screen.cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY).concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY)))

        if edits.highlightClicks {
            let unit = renderSize.height / 1080 / view.h
            for (click, progress) in Timeline.activeClicks(at: source, cursor: cursor) {
                let x = (click.x - view.x) / view.w * renderSize.width, y = (1 - (click.y - view.y) / view.h) * renderSize.height
                let diameter = (24 + 56 * progress) * unit
                let ring = RenderPlan.ring(click.right ? RenderPlan.rightClickColor : RenderPlan.clickColor)
                let alpha = 1 - progress
                let placed = ring.transformed(by: CGAffineTransform(scaleX: diameter / ring.extent.width, y: diameter / ring.extent.height)
                                                .concatenating(CGAffineTransform(translationX: x - diameter / 2, y: y - diameter / 2)))
                    .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
                picture = placed.composited(over: picture)
            }
        }

        if edits.showCursor, !cursorImages.isEmpty, recordedPointHeight > 0, !edits.cursorHidden.contains(where: { $0.contains(source) }),
           let id = cursor.shape(at: source), let entry = cursorImages[id],
           let p = edits.smoothCursor ? cursor.smoothedPosition(at: source, window: 0.3) : cursor.position(at: source) {
            // Output pixels per screen point, including the zoom.
            let image = entry.image, shape = entry.shape
            let k = Double(renderSize.height) / recordedPointHeight / view.h * edits.cursorScale
            let x = (p.x - view.x) / view.w * Double(renderSize.width), y = (1 - (p.y - view.y) / view.h) * Double(renderSize.height)
            let w = shape.width * k, h = shape.height * k
            let placed = image.transformed(by: CGAffineTransform(scaleX: w / image.extent.width, y: h / image.extent.height)
                .concatenating(CGAffineTransform(translationX: x - shape.hotX * k, y: y + shape.hotY * k - h)))
            picture = placed.composited(over: picture)
        }

        if edits.showCamera, let camera {
            let size = (renderSize.height * edits.cameraSize).rounded()
            let margin = renderSize.height * 0.03
            let e = camera.extent
            let side = min(e.width, e.height)
            let square = camera.cropped(to: CGRect(x: e.midX - side / 2, y: e.midY - side / 2, width: side, height: side))
            let x = edits.cameraCorner == .topLeft || edits.cameraCorner == .bottomLeft ? margin : renderSize.width - margin - size
            let y = edits.cameraCorner == .bottomLeft || edits.cameraCorner == .bottomRight ? margin : renderSize.height - margin - size
            let placed = square.transformed(by: CGAffineTransform(translationX: -square.extent.minX, y: -square.extent.minY)
                .concatenating(CGAffineTransform(scaleX: size / side, y: size / side))
                .concatenating(CGAffineTransform(translationX: x, y: y)))
            let mask = RenderPlan.mask(edits.cameraShape)
            let fitted = mask.transformed(by: CGAffineTransform(scaleX: size / mask.extent.width, y: size / mask.extent.height).concatenating(CGAffineTransform(translationX: x, y: y)))
            let masked = placed.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: fitted])
            picture = masked.composited(over: picture)
        }
        return picture.cropped(to: CGRect(origin: .zero, size: renderSize)).composited(over: CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: renderSize)))
    }

    // MARK: Drawn pieces, made once

    static let clickColor = NSColor(srgbRed: 1, green: 0.78, blue: 0.1, alpha: 1)
    static let rightClickColor = NSColor(srgbRed: 0.25, green: 0.6, blue: 1, alpha: 1)
    private static var rings: [NSColor: CIImage] = [:]
    private static var masks: [CameraShape: CIImage] = [:]
    private static let lock = NSLock()

    private static func drawn(_ size: Int, _ draw: (CGContext) -> Void) -> CIImage {
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(context)
        return CIImage(cgImage: context.makeImage()!)
    }
    static func ring(_ color: NSColor) -> CIImage {
        lock.lock(); defer { lock.unlock() }
        if let image = rings[color] { return image }
        let image = drawn(256) { context in
            context.setFillColor(color.withAlphaComponent(0.28).cgColor)
            context.fillEllipse(in: CGRect(x: 14, y: 14, width: 228, height: 228))
            context.setStrokeColor(color.cgColor); context.setLineWidth(22)
            context.strokeEllipse(in: CGRect(x: 14, y: 14, width: 228, height: 228))
        }
        rings[color] = image
        return image
    }
    static func mask(_ shape: CameraShape) -> CIImage {
        lock.lock(); defer { lock.unlock() }
        if let image = masks[shape] { return image }
        let image = drawn(512) { context in
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            let rect = CGRect(x: 0, y: 0, width: 512, height: 512)
            if shape == .circle { context.fillEllipse(in: rect) }
            else { context.addPath(CGPath(roundedRect: rect, cornerWidth: 80, cornerHeight: 80, transform: nil)); context.fillPath() }
        }
        masks[shape] = image
        return image
    }
}

final class EditInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let screenTrack: CMPersistentTrackID
    let cameraTrack: CMPersistentTrackID?
    let plan: RenderPlan

    init(timeRange: CMTimeRange, screenTrack: CMPersistentTrackID, cameraTrack: CMPersistentTrackID?, plan: RenderPlan) {
        self.timeRange = timeRange; self.screenTrack = screenTrack; self.cameraTrack = cameraTrack; self.plan = plan
        requiredSourceTrackIDs = ([screenTrack] + (cameraTrack.map { [$0] } ?? [])).map { NSNumber(value: $0) }
    }
}

final class EditCompositor: NSObject, AVVideoCompositing {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    let sourcePixelBufferAttributes: [String: any Sendable]? = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    private let queue = DispatchQueue(label: "ScreenTake.compositor")

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async {
            guard let instruction = request.videoCompositionInstruction as? EditInstruction,
                  let screenBuffer = request.sourceFrame(byTrackID: instruction.screenTrack),
                  let output = request.renderContext.newPixelBuffer() else {
                request.finish(with: NSError(domain: "ScreenTake", code: 1)); return
            }
            let camera = instruction.cameraTrack.flatMap { request.sourceFrame(byTrackID: $0) }.map { CIImage(cvPixelBuffer: $0) }
            let picture = instruction.plan.image(screen: CIImage(cvPixelBuffer: screenBuffer), camera: camera, at: request.compositionTime.seconds)
            EditCompositor.context.render(picture, to: output, bounds: CGRect(origin: .zero, size: instruction.plan.renderSize), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            request.finish(withComposedVideoFrame: output)
        }
    }
    func cancelAllPendingVideoCompositionRequests() {}
}

/// The edited movie as a composition: the kept pieces of every track, the effects, and the volumes.
struct EditedMovie {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let audioMix: AVMutableAudioMix
    let duration: Double

    static func even(_ size: CGSize) -> CGSize { CGSize(width: (Int(size.width) / 2) * 2, height: (Int(size.height) / 2) * 2) }
    /// The recorded size scaled to fit `maxHeight` (nil keeps it).
    static func renderSize(_ info: RecordingInfo, maxHeight: Int?) -> CGSize {
        let size = CGSize(width: info.width, height: info.height)
        guard let maxHeight, CGFloat(maxHeight) < size.height else { return even(size) }
        return even(CGSize(width: size.width * CGFloat(maxHeight) / size.height, height: CGFloat(maxHeight)))
    }

    static func build(asset: AVURLAsset, info: RecordingInfo, renderSize: CGSize) async throws -> EditedMovie {
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audios = try await asset.loadTracks(withMediaType: .audio)
        guard let screen = videos.first else { throw RecordError.failed("no video") }
        let assetDuration = try await asset.load(.duration).seconds
        let kept = Timeline.kept(duration: min(info.duration, assetDuration), removed: info.edits.removed)
        let composition = AVMutableComposition()
        func add(_ track: AVAssetTrack, _ type: AVMediaType) throws -> AVMutableCompositionTrack? {
            guard let target = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
            var at = CMTime.zero
            for span in kept {
                let range = CMTimeRange(start: CMTime(seconds: span.start, preferredTimescale: 600), end: CMTime(seconds: span.end, preferredTimescale: 600))
                // The camera and audio may start or end a little apart from the screen: leave the missing part empty.
                do { try target.insertTimeRange(range, of: track, at: at) }
                catch { target.insertEmptyTimeRange(CMTimeRange(start: at, duration: range.duration)) }
                at = at + range.duration
            }
            return target
        }
        guard let screenTrack = try add(screen, .video) else { throw RecordError.failed("composition") }
        let cameraTrack = info.hasCamera && videos.count > 1 ? try add(videos[1], .video) : nil
        var parameters: [AVMutableAudioMixInputParameters] = []
        var audioIndex = 0
        for (present, volume) in [(info.hasSystemAudio, info.edits.systemVolume), (info.hasMicrophone, info.edits.micVolume)] where present {
            defer { audioIndex += 1 }
            guard audioIndex < audios.count, let track = try add(audios[audioIndex], .audio) else { continue }
            let p = AVMutableAudioMixInputParameters(track: track)
            p.setVolume(Float(volume), at: .zero)
            parameters.append(p)
        }
        let duration = Timeline.outputDuration(kept)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = EditCompositor.self
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, info.fps)))
        videoComposition.renderSize = renderSize
        var plan = RenderPlan(kept: kept, edits: info.edits, cursor: info.cursor, renderSize: renderSize)
        if let shapes = info.cursorShapes, let ppp = info.pixelsPerPoint, ppp > 0 {
            let folder = asset.url.deletingLastPathComponent().appendingPathComponent("cursors")
            for shape in shapes {
                if let image = CIImage(contentsOf: folder.appendingPathComponent("\(shape.id).png")) { plan.cursorImages[shape.id] = (image, shape) }
            }
            plan.recordedPointHeight = Double(info.height) / ppp
        }
        videoComposition.instructions = [EditInstruction(timeRange: CMTimeRange(start: .zero, duration: composition.duration),
                                                         screenTrack: screenTrack.trackID, cameraTrack: cameraTrack?.trackID, plan: plan)]
        let mix = AVMutableAudioMix(); mix.inputParameters = parameters
        return EditedMovie(composition: composition, videoComposition: videoComposition, audioMix: mix, duration: duration)
    }
}
