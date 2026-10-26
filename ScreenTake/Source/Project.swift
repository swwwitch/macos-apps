import Foundation

// The saved project: what was recorded and the edits. The recorded movie is never changed; edits live here.

/// A range of seconds.
struct Span: Codable, Equatable {
    var start: Double
    var end: Double
    var duration: Double { end - start }
    func contains(_ t: Double) -> Bool { t >= start && t < end }
}

/// A zoom in source seconds. The picture eases in and out over `Timeline.zoomRamp` at both ends.
struct ZoomSpan: Codable, Equatable, Identifiable {
    var id = UUID()
    var start: Double
    var end: Double
    var scale: Double = 2
    /// Follows the pointer; otherwise stays on `centerX`/`centerY`.
    var followCursor = true
    /// Normalized, top-left origin.
    var centerX = 0.5
    var centerY = 0.5
}

/// Pointer position, normalized to the recorded area (top-left origin), in source seconds.
/// `c`: the pointer shape (CursorShape.id); nil in recordings made before the pointer was a separate layer.
struct CursorSample: Codable, Equatable { var t: Double; var x: Double; var y: Double; var c: Int? = nil }
/// One pointer picture, saved as cursors/<id>.png. Sizes in points; the hot spot from the top left.
struct CursorShape: Codable, Equatable { var id: Int; var width: Double; var height: Double; var hotX: Double; var hotY: Double }
struct ClickSample: Codable, Equatable { var t: Double; var x: Double; var y: Double; var right = false }

struct CursorTrack: Codable, Equatable {
    var samples: [CursorSample] = []
    var clicks: [ClickSample] = []

    /// Index of the first sample at or after t.
    private func lowerBound(_ t: Double) -> Int {
        var low = 0, high = samples.count
        while low < high { let mid = (low + high) / 2; if samples[mid].t < t { low = mid + 1 } else { high = mid } }
        return low
    }
    /// The pointer shape at t (the last sample at or before it).
    func shape(at t: Double) -> Int? {
        guard !samples.isEmpty else { return nil }
        let i = lowerBound(t)
        return i < samples.count && samples[i].t == t ? samples[i].c : samples[max(0, i - 1)].c
    }
    func position(at t: Double) -> (x: Double, y: Double)? {
        guard !samples.isEmpty else { return nil }
        let i = lowerBound(t)
        if i == 0 { return (samples[0].x, samples[0].y) }
        if i == samples.count { return (samples[i - 1].x, samples[i - 1].y) }
        let a = samples[i - 1], b = samples[i]
        let f = b.t > a.t ? (t - a.t) / (b.t - a.t) : 0
        return (a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)
    }
    /// Average over ±window/2 so a zoom that follows the pointer does not shake.
    func smoothedPosition(at t: Double, window: Double = 0.8) -> (x: Double, y: Double)? {
        guard !samples.isEmpty else { return nil }
        let from = lowerBound(t - window / 2), to = lowerBound(t + window / 2)
        guard to > from else { return position(at: t) }
        var x = 0.0, y = 0.0
        for s in samples[from..<to] { x += s.x; y += s.y }
        return (x / Double(to - from), y / Double(to - from))
    }
}

enum CameraCorner: String, Codable, CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }
enum CameraShape: String, Codable, CaseIterable { case circle, rounded }

struct EditDecision: Codable, Equatable {
    /// Source spans left out of the movie (trims and cuts). Kept sorted and merged.
    var removed: [Span] = []
    var zooms: [ZoomSpan] = []
    var highlightClicks = true
    var showCamera = true
    var cameraCorner = CameraCorner.bottomRight
    var cameraShape = CameraShape.circle
    /// Camera diameter as a fraction of the picture height.
    var cameraSize = 0.24
    var systemVolume = 1.0
    var micVolume = 1.0
    // The pointer layer (recordings with cursorShapes).
    var showCursor = true
    /// 1 = as on screen.
    var cursorScale = 1.0
    var smoothCursor = false
    /// Source spans where the pointer is hidden.
    var cursorHidden: [Span] = []

    init() {}
    /// Keys added later may be missing in older project.json files.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = EditDecision()
        removed = try c.decodeIfPresent([Span].self, forKey: .removed) ?? d.removed
        zooms = try c.decodeIfPresent([ZoomSpan].self, forKey: .zooms) ?? d.zooms
        highlightClicks = try c.decodeIfPresent(Bool.self, forKey: .highlightClicks) ?? d.highlightClicks
        showCamera = try c.decodeIfPresent(Bool.self, forKey: .showCamera) ?? d.showCamera
        cameraCorner = try c.decodeIfPresent(CameraCorner.self, forKey: .cameraCorner) ?? d.cameraCorner
        cameraShape = try c.decodeIfPresent(CameraShape.self, forKey: .cameraShape) ?? d.cameraShape
        cameraSize = try c.decodeIfPresent(Double.self, forKey: .cameraSize) ?? d.cameraSize
        systemVolume = try c.decodeIfPresent(Double.self, forKey: .systemVolume) ?? d.systemVolume
        micVolume = try c.decodeIfPresent(Double.self, forKey: .micVolume) ?? d.micVolume
        showCursor = try c.decodeIfPresent(Bool.self, forKey: .showCursor) ?? d.showCursor
        cursorScale = try c.decodeIfPresent(Double.self, forKey: .cursorScale) ?? d.cursorScale
        smoothCursor = try c.decodeIfPresent(Bool.self, forKey: .smoothCursor) ?? d.smoothCursor
        cursorHidden = try c.decodeIfPresent([Span].self, forKey: .cursorHidden) ?? d.cursorHidden
    }
}

/// project.json next to recording.mov.
struct RecordingInfo: Codable {
    var version = 1
    var created = Date()
    var duration: Double
    /// Recorded picture in pixels.
    var width: Int
    var height: Int
    var fps: Int
    /// Tracks in recording.mov, in the order the recorder adds them: screen video, camera video, system audio, microphone.
    var hasCamera: Bool
    var hasSystemAudio: Bool
    var hasMicrophone: Bool
    var cursor = CursorTrack()
    var edits = EditDecision()
    /// Recorded pixels per screen point (2 on Retina).
    var pixelsPerPoint: Double?
    /// Present when the pointer was recorded as its own layer (not in the picture).
    var cursorShapes: [CursorShape]?
    var hasCursorLayer: Bool { !(cursorShapes ?? []).isEmpty }
}

enum Timeline {
    /// Seconds for a zoom to ease in and out.
    static let zoomRamp = 0.45
    /// Shortest piece left between two cuts; shorter remains are removed too so the movie has no flashes.
    static let minimumPiece = 0.05

    /// `spans` with `cut` taken out.
    static func subtract(_ cut: [Span], from spans: [Span]) -> [Span] {
        var result = merge(spans)
        for c in cut {
            result = result.flatMap { s -> [Span] in
                guard c.end > s.start && c.start < s.end else { return [s] }
                return [Span(start: s.start, end: c.start), Span(start: c.end, end: s.end)].filter { $0.duration > 0.001 }
            }
        }
        return result
    }
    static func merge(_ spans: [Span]) -> [Span] {
        var result: [Span] = []
        for span in spans.filter({ $0.end > $0.start }).sorted(by: { $0.start < $1.start }) {
            if let last = result.last, span.start <= last.end + minimumPiece { result[result.count - 1].end = max(last.end, span.end) }
            else { result.append(span) }
        }
        return result
    }
    /// The source spans that stay, in order.
    static func kept(duration: Double, removed: [Span]) -> [Span] {
        var result: [Span] = []
        var cursor = 0.0
        for cut in merge(removed) where cut.end > 0 && cut.start < duration {
            if cut.start - cursor >= minimumPiece { result.append(Span(start: cursor, end: cut.start)) }
            cursor = max(cursor, cut.end)
        }
        if duration - cursor >= minimumPiece { result.append(Span(start: cursor, end: duration)) }
        return result
    }
    static func outputDuration(_ kept: [Span]) -> Double { kept.reduce(0) { $0 + $1.duration } }
    /// Edited-movie seconds → recording seconds.
    static func toSource(_ t: Double, kept: [Span]) -> Double {
        var offset = 0.0
        for span in kept {
            if t < offset + span.duration { return span.start + max(0, t - offset) }
            offset += span.duration
        }
        return kept.last?.end ?? t
    }
    /// Recording seconds → edited-movie seconds; nil inside a cut.
    static func toOutput(_ t: Double, kept: [Span]) -> Double? {
        var offset = 0.0
        for span in kept {
            if t >= span.start && t <= span.end { return offset + t - span.start }
            offset += span.duration
        }
        return nil
    }
    /// Recording seconds → edited-movie seconds; inside a cut, the place where the cut is.
    static func toOutputClamped(_ t: Double, kept: [Span]) -> Double {
        var offset = 0.0
        for span in kept {
            if t <= span.end { return offset + max(0, t - span.start) }
            offset += span.duration
        }
        return offset
    }
    /// An edited-movie range as the recording spans it covers (one per kept piece it touches).
    static func sourceSpans(output range: Span, kept: [Span]) -> [Span] {
        var result: [Span] = []
        var offset = 0.0
        for span in kept {
            let from = max(range.start, offset), to = min(range.end, offset + span.duration)
            if to > from { result.append(Span(start: span.start + from - offset, end: span.start + to - offset)) }
            offset += span.duration
        }
        return result
    }

    static func smoothstep(_ x: Double) -> Double { let c = min(1, max(0, x)); return c * c * (3 - 2 * c) }
    /// 0 outside, 1 in the middle, eased at both ends.
    static func zoomAmount(_ zoom: ZoomSpan, at t: Double) -> Double {
        guard t > zoom.start && t < zoom.end else { return 0 }
        let ramp = min(zoomRamp, (zoom.end - zoom.start) / 2)
        return smoothstep(min((t - zoom.start) / ramp, (zoom.end - t) / ramp))
    }

    /// The part of the recording shown at source time t, normalized with a top-left origin.
    static func visibleRect(at t: Double, zooms: [ZoomSpan], cursor: CursorTrack) -> (x: Double, y: Double, w: Double, h: Double) {
        guard let zoom = zooms.first(where: { t > $0.start && t < $0.end }) else { return (0, 0, 1, 1) }
        let amount = zoomAmount(zoom, at: t)
        let size = 1 / max(1, zoom.scale)
        var center = (x: zoom.centerX, y: zoom.centerY)
        if zoom.followCursor, let p = cursor.smoothedPosition(at: t) { center = p }
        let x = min(max(center.x - size / 2, 0), 1 - size), y = min(max(center.y - size / 2, 0), 1 - size)
        // Grow from the whole picture toward the zoomed part.
        return (x * amount, y * amount, 1 + (size - 1) * amount, 1 + (size - 1) * amount)
    }

    /// Clicks to draw at source time t, with how far each ring has grown (0…1).
    static let clickLength = 0.55
    static func activeClicks(at t: Double, cursor: CursorTrack) -> [(click: ClickSample, progress: Double)] {
        cursor.clicks.compactMap { click in
            let age = t - click.t
            return age >= 0 && age < clickLength ? (click, age / clickLength) : nil
        }
    }
}
