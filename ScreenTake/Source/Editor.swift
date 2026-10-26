import AppKit
import AVFoundation
import AVKit
import SwiftUI

/// One recording opened for editing. Times on the timeline are edited-movie seconds; the project stores recording seconds.
@MainActor final class EditorModel: ObservableObject {
    let folder: URL
    let movieURL: URL
    let asset: AVURLAsset
    let player = AVPlayer()
    let undo = UndoManager()
    @Published private(set) var info: RecordingInfo
    @Published private(set) var kept: [Span] = []
    @Published private(set) var duration = 0.0
    @Published var currentTime = 0.0
    @Published var playing = false
    /// A range dragged on the timeline (edited-movie seconds).
    @Published var selection: Span?
    @Published var selectedZoom: UUID?
    @Published var thumbnails: [(t: Double, image: CGImage)] = []
    /// Peaks per 0.05 s of recording time: system audio, microphone.
    @Published var waveforms: [[Float]] = []
    @Published var pixelsPerSecond: Double = 40

    // Export
    @Published var exportOptions = ExportOptions()
    @Published var exporting = false
    @Published var exportProgress = 0.0
    @Published var status = ""
    @Published var failed = false
    @Published var lastExport: URL?
    private var exportTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var rebuildTask: Task<Void, Never>?
    private var movie: EditedMovie?

    static let waveStep = 0.05
    var projectURL: URL { folder.appendingPathComponent("project.json") }
    var title: String { folder.lastPathComponent }

    init(folder: URL) throws {
        self.folder = folder
        movieURL = folder.appendingPathComponent("recording.mov")
        let data = try Data(contentsOf: folder.appendingPathComponent("project.json"))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        info = try decoder.decode(RecordingInfo.self, from: data)
        asset = AVURLAsset(url: movieURL)
        exportOptions.format = ExportFormat(rawValue: UserDefaults.standard.string(forKey: "exportFormat") ?? "") ?? .mp4
        exportOptions.size = ExportSize(rawValue: UserDefaults.standard.object(forKey: "exportSize") as? Int ?? 1080) ?? .p1080
        exportOptions.hevc = UserDefaults.standard.bool(forKey: "exportHEVC")
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                self.playing = self.player.rate != 0
            }
        }
        rebuild()
        loadWaveforms()
    }
    func close() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        exportTask?.cancel()
    }

    // MARK: Building the preview

    /// Rebuilds the player item after an edit, keeping the place in the recording.
    private func rebuild() {
        let sourceTime = Timeline.toSource(currentTime, kept: kept)
        kept = Timeline.kept(duration: info.duration, removed: info.edits.removed)
        duration = Timeline.outputDuration(kept)
        let info = info, kept = kept
        rebuildTask?.cancel()
        rebuildTask = Task {
            do {
                // Preview at most 1080 lines high: the recording can be 5K.
                let movie = try await EditedMovie.build(asset: asset, info: info, renderSize: EditedMovie.renderSize(info, maxHeight: 1080))
                guard !Task.isCancelled else { return }
                self.movie = movie
                let item = AVPlayerItem(asset: movie.composition)
                item.videoComposition = movie.videoComposition
                item.audioMix = movie.audioMix
                let wasPlaying = player.rate != 0
                player.replaceCurrentItem(with: item)
                let t = Timeline.toOutputClamped(sourceTime, kept: kept)
                await player.seek(to: CMTime(seconds: min(t, max(0, duration - 0.001)), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                if wasPlaying { player.play() }
                makeThumbnails(movie)
            } catch {
                report(String(format: L("openFailed"), error.localizedDescription), failed: true)
            }
        }
    }

    private func makeThumbnails(_ movie: EditedMovie) {
        let generator = AVAssetImageGenerator(asset: movie.composition)
        generator.videoComposition = movie.videoComposition
        generator.maximumSize = CGSize(width: 160, height: 90)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 2)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 2)
        let step = max(0.5, movie.duration / 60)
        let times = stride(from: 0.0, to: max(movie.duration, 0.01), by: step).map { CMTime(seconds: $0, preferredTimescale: 600) }
        Task {
            var images: [(Double, CGImage)] = []
            for await result in generator.images(for: times) {
                if let image = try? result.image { images.append((result.requestedTime.seconds, image)) }
            }
            thumbnails = images
        }
    }

    private func loadWaveforms() {
        let asset = asset, step = EditorModel.waveStep
        Task.detached(priority: .utility) {
            var result: [[Float]] = []
            for track in (try? await asset.loadTracks(withMediaType: .audio)) ?? [] {
                result.append(EditorModel.peaks(asset: asset, track: track, step: step))
            }
            await MainActor.run { self.waveforms = result }
        }
    }
    nonisolated static func peaks(asset: AVAsset, track: AVAssetTrack, step: Double) -> [Float] {
        guard let reader = try? AVAssetReader(asset: asset) else { return [] }
        let rate = 8000.0
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: rate])
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }
        let perBucket = Int(rate * step)
        var peaks: [Float] = [], current: Float = 0, filled = 0
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            var length = 0; var pointer: UnsafeMutablePointer<CChar>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr, let pointer else { continue }
            pointer.withMemoryRebound(to: Float.self, capacity: length / 4) { samples in
                for i in 0..<length / 4 {
                    current = max(current, abs(samples[i])); filled += 1
                    if filled == perBucket { peaks.append(min(1, current)); current = 0; filled = 0 }
                }
            }
        }
        return peaks
    }

    // MARK: Playback

    func seek(_ t: Double) {
        let clamped = min(max(0, t), max(0, duration - 0.001))
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    func togglePlay() {
        if player.rate != 0 { player.pause() }
        else {
            if currentTime >= duration - 0.05 { seek(0) }
            player.play()
        }
        playing = player.rate != 0
    }
    func step(_ frames: Int) {
        player.pause()
        seek(currentTime + Double(frames) / Double(max(1, info.fps)))
    }

    // MARK: Edits (each one can be undone and is saved at once)

    func change(_ name: String, _ mutate: (inout EditDecision) -> Void) {
        let before = info.edits
        var after = before
        mutate(&after)
        guard after != before else { return }
        apply(after, name: name)
    }
    private var lastUndo: (name: String, time: Date)?
    private func apply(_ edits: EditDecision, name: String, undoing: Bool = false) {
        let before = info.edits
        // A slider drag is one step to undo: repeated changes of the same kind within a second share the first undo.
        if undoing || lastUndo?.name != name || Date().timeIntervalSince(lastUndo!.time) > 1 {
            undo.registerUndo(withTarget: self) { model in MainActor.assumeIsolated { model.apply(before, name: name, undoing: true) } }
            undo.setActionName(name)
        }
        lastUndo = undoing ? nil : (name, Date())
        info.edits = edits
        save()
        if before.removed != edits.removed { selection = nil; rebuild() } else { refreshEffects() }
    }
    /// Effects and volumes only: swap the composition settings on the current item (no reload, no flicker).
    private func refreshEffects() {
        guard let movie, let item = player.currentItem, let old = movie.videoComposition.instructions.first as? EditInstruction else { rebuild(); return }
        var plan = old.plan
        plan.kept = kept; plan.edits = info.edits
        let composition = movie.videoComposition.mutableCopy() as! AVMutableVideoComposition
        composition.instructions = [EditInstruction(timeRange: old.timeRange, screenTrack: old.screenTrack, cameraTrack: old.cameraTrack, plan: plan)]
        item.videoComposition = composition
        let volumes = [info.hasSystemAudio ? info.edits.systemVolume : nil, info.hasMicrophone ? info.edits.micVolume : nil].compactMap { $0 }
        let mix = AVMutableAudioMix()
        mix.inputParameters = zip(movie.audioMix.inputParameters, volumes).map { parameters, volume in
            let p = AVMutableAudioMixInputParameters(track: nil); p.trackID = parameters.trackID; p.setVolume(Float(volume), at: .zero); return p
        }
        item.audioMix = mix
        if player.rate == 0 { seek(currentTime) }
    }
    private func save() {
        do {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(info).write(to: projectURL, options: .atomic)
        } catch {
            report(String(format: L("saveFailed"), error.localizedDescription), failed: true)
        }
    }

    var canCut: Bool { (selection?.duration ?? 0) > 0.02 }
    func cutSelection() {
        guard let selection, canCut else { return }
        let spans = Timeline.sourceSpans(output: selection, kept: kept)
        change(L("actionCut")) { $0.removed = Timeline.merge($0.removed + spans) }
        seek(selection.start)
    }
    func trimStart() {
        guard currentTime > 0.02 else { return }
        let spans = Timeline.sourceSpans(output: Span(start: 0, end: currentTime), kept: kept)
        change(L("actionTrimStart")) { $0.removed = Timeline.merge($0.removed + spans) }
        seek(0)
    }
    func trimEnd() {
        guard currentTime < duration - 0.02 else { return }
        let spans = Timeline.sourceSpans(output: Span(start: currentTime, end: duration), kept: kept)
        change(L("actionTrimEnd")) { $0.removed = Timeline.merge($0.removed + spans) }
    }
    var hasCuts: Bool { !info.edits.removed.isEmpty }
    func restoreCuts() { change(L("actionRestoreCuts")) { $0.removed = [] } }

    var canHideCursor: Bool { info.hasCursorLayer && canCut }
    func hideCursorInSelection() {
        guard let selection, canHideCursor else { return }
        let spans = Timeline.sourceSpans(output: selection, kept: kept)
        change(L("actionHideCursor")) { $0.cursorHidden = Timeline.merge($0.cursorHidden + spans) }
    }
    func showCursorInSelection() {
        guard let selection, canHideCursor else { return }
        let spans = Timeline.sourceSpans(output: selection, kept: kept)
        change(L("actionShowCursor")) { $0.cursorHidden = Timeline.subtract(spans, from: $0.cursorHidden) }
    }

    func addZoom() {
        let range = selection.flatMap { $0.duration > 0.3 ? $0 : nil } ?? Span(start: currentTime, end: min(duration, currentTime + 3))
        guard range.duration > 0.3 else { return }
        let start = Timeline.toSource(range.start, kept: kept), end = Timeline.toSource(range.end - 0.001, kept: kept)
        var zoom = ZoomSpan(start: start, end: end)
        if let p = info.cursor.position(at: start) { zoom.centerX = p.x; zoom.centerY = p.y }
        change(L("actionAddZoom")) { edits in
            edits.zooms.removeAll { $0.start < end && $0.end > start }
            edits.zooms.append(zoom); edits.zooms.sort { $0.start < $1.start }
        }
        selectedZoom = zoom.id
    }
    func deleteZoom() {
        guard let id = selectedZoom else { return }
        change(L("actionDeleteZoom")) { $0.zooms.removeAll { $0.id == id } }
        selectedZoom = nil
    }
    func updateZoom(_ name: String, _ mutate: (inout ZoomSpan) -> Void) {
        guard let id = selectedZoom else { return }
        change(name) { edits in
            guard let i = edits.zooms.firstIndex(where: { $0.id == id }) else { return }
            mutate(&edits.zooms[i])
            let z = edits.zooms[i]
            // No overlaps: the moved zoom wins.
            edits.zooms.removeAll { $0.id != id && $0.start < z.end && $0.end > z.start }
            edits.zooms.sort { $0.start < $1.start }
        }
    }
    var zoom: ZoomSpan? { info.edits.zooms.first { $0.id == selectedZoom } }
    /// Moves or resizes a zoom on the timeline (edited-movie seconds in, recording seconds stored).
    func setZoom(_ id: UUID, outputStart: Double, outputEnd: Double) {
        let start = Timeline.toSource(max(0, outputStart), kept: kept), end = Timeline.toSource(min(duration, outputEnd) - 0.001, kept: kept)
        guard end - start > 0.3 else { return }
        selectedZoom = id
        updateZoom(L("actionMoveZoom")) { $0.start = start; $0.end = end }
    }
    func outputRange(_ zoom: ZoomSpan) -> Span {
        Span(start: Timeline.toOutputClamped(zoom.start, kept: kept), end: Timeline.toOutputClamped(zoom.end, kept: kept))
    }

    // MARK: Export

    func export() {
        guard !exporting else { return }
        UserDefaults.standard.set(exportOptions.format.rawValue, forKey: "exportFormat")
        UserDefaults.standard.set(exportOptions.size.rawValue, forKey: "exportSize")
        UserDefaults.standard.set(exportOptions.hevc, forKey: "exportHEVC")
        let panel = NSSavePanel()
        let ext = exportOptions.format.rawValue
        panel.nameFieldStringValue = "\(title).\(ext)"
        panel.allowedContentTypes = [exportOptions.format == .gif ? .gif : exportOptions.format == .mov ? .quickTimeMovie : .mpeg4Movie]
        panel.directoryURL = URL(fileURLWithPath: UserDefaults.standard.string(forKey: "exportFolder") ?? NSHomeDirectory() + "/Movies", isDirectory: true)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: "exportFolder")
        player.pause()
        exporting = true; exportProgress = 0
        report(String(format: L("exporting"), url.lastPathComponent), failed: false)
        let info = info, movieURL = movieURL, options = exportOptions
        exportTask = Task {
            do {
                try await Exporter.export(movie: movieURL, info: info, options: options, to: url) { value in
                    Task { @MainActor in self.exportProgress = value }
                }
                lastExport = url
                report(String(format: L("exported"), url.lastPathComponent), failed: false)
            } catch is CancellationError {
                report(L("exportCanceled"), failed: false)
            } catch {
                report(Task.isCancelled ? L("exportCanceled") : String(format: L("exportFailed"), error.localizedDescription), failed: !Task.isCancelled)
            }
            exporting = false
        }
    }
    func cancelExport() { exportTask?.cancel() }
    func revealExport() { if let lastExport { FileReveal.reveal(lastExport) } }

    func report(_ text: String, failed: Bool) { status = text; self.failed = failed }
}

func timecode(_ t: Double, tenths: Bool = true) -> String {
    let value = max(0, t)
    let minutes = Int(value) / 60, seconds = Int(value) % 60
    return tenths ? String(format: "%02d:%02d.%d", minutes, seconds, Int((value * 10).truncatingRemainder(dividingBy: 10))) : String(format: "%02d:%02d", minutes, seconds)
}

// MARK: - Views

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player; view.controlsStyle = .none; view.videoGravity = .resizeAspect
        view.setAccessibilityLabel(L("preview"))
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) {}
}

struct EditorView: View {
    @ObservedObject var model: EditorModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                PlayerView(player: model.player).background(Color.black).frame(minWidth: 480, minHeight: 270)
                Divider()
                ScrollView { Inspector(model: model).padding(14) }.frame(width: 280)
            }
            Divider()
            TransportBar(model: model).padding(.horizontal, 12).padding(.vertical, 8)
            TimelineView(model: model).frame(height: 236)
            StatusLine(model: model).padding(.horizontal, 12).padding(.vertical, 6)
        }
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
        .frame(minWidth: 900, minHeight: 640)
    }
}

struct TransportBar: View {
    @ObservedObject var model: EditorModel
    var body: some View {
        HStack(spacing: 8) {
            Button { model.togglePlay() } label: { Image(systemName: model.playing ? "pause.fill" : "play.fill").frame(width: 20) }
                .accessibilityLabel(L(model.playing ? "pause" : "play")).help(L(model.playing ? "pause" : "play"))
            Text("\(timecode(model.currentTime)) / \(timecode(model.duration))").monospacedDigit().font(.callout)
            Divider().frame(height: 18)
            Button(L("cutRange")) { model.cutSelection() }.disabled(!model.canCut).help(L("cutHelp"))
            Button(L("trimStart")) { model.trimStart() }.help(L("trimStartHelp"))
            Button(L("trimEnd")) { model.trimEnd() }.help(L("trimEndHelp"))
            Button(L("addZoom")) { model.addZoom() }.help(L("addZoomHelp"))
            Spacer(minLength: 8)
            Image(systemName: "minus.magnifyingglass").foregroundColor(.secondary).accessibilityHidden(true)
            Slider(value: $model.pixelsPerSecond, in: 4...240).frame(width: 110).accessibilityLabel(L("timelineScale"))
            Image(systemName: "plus.magnifyingglass").foregroundColor(.secondary).accessibilityHidden(true)
            Button(L("exportButton")) { model.export() }.keyboardShortcut("e", modifiers: .command).disabled(model.exporting)
        }.controlSize(.regular)
    }
}

struct StatusLine: View {
    @ObservedObject var model: EditorModel
    var body: some View {
        HStack(spacing: 8) {
            if model.failed { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).accessibilityHidden(true) }
            Text(model.status.isEmpty ? " " : model.status).font(.callout).foregroundColor(.secondary).lineLimit(2)
            if model.exporting {
                ProgressView(value: model.exportProgress).frame(width: 160)
                Button(L("cancel")) { model.cancelExport() }.keyboardShortcut(.cancelAction)
            } else if model.lastExport != nil {
                Button(L("revealInFinder")) { model.revealExport() }
            }
            Spacer(minLength: 0)
        }
    }
}

struct Inspector: View {
    @ObservedObject var model: EditorModel
    private func binding<T>(_ name: String, _ path: WritableKeyPath<EditDecision, T>) -> Binding<T> {
        Binding(get: { model.info.edits[keyPath: path] }, set: { value in model.change(name) { $0[keyPath: path] = value } })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("zoomSection")) {
                VStack(alignment: .leading, spacing: 8) {
                    if let zoom = model.zoom {
                        HStack {
                            Text(L("zoomScale"))
                            Slider(value: Binding(get: { zoom.scale }, set: { v in model.updateZoom(L("actionZoomScale")) { $0.scale = v } }), in: 1.2...4)
                            Text(String(format: "%.1f×", zoom.scale)).monospacedDigit().frame(width: 36, alignment: .trailing)
                        }
                        Toggle(L("followCursor"), isOn: Binding(get: { zoom.followCursor }, set: { v in model.updateZoom(L("actionFollow")) { $0.followCursor = v } }))
                        if !zoom.followCursor {
                            HStack { Text(L("zoomCenterX")); Slider(value: Binding(get: { zoom.centerX }, set: { v in model.updateZoom(L("actionZoomCenter")) { $0.centerX = v } }), in: 0...1) }
                            HStack { Text(L("zoomCenterY")); Slider(value: Binding(get: { zoom.centerY }, set: { v in model.updateZoom(L("actionZoomCenter")) { $0.centerY = v } }), in: 0...1) }
                        }
                        Button(L("deleteZoom")) { model.deleteZoom() }
                    } else {
                        Text(L("zoomHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("cursorSection")) {
                VStack(alignment: .leading, spacing: 8) {
                    if model.info.hasCursorLayer {
                        Toggle(L("showCursorLayer"), isOn: binding(L("showCursorLayer"), \.showCursor))
                        HStack {
                            Text(L("cursorScale"))
                            Slider(value: binding(L("cursorScale"), \.cursorScale), in: 0.5...3)
                            Text(String(format: "%.1f×", model.info.edits.cursorScale)).monospacedDigit().frame(width: 36, alignment: .trailing)
                        }
                        Toggle(L("smoothCursor"), isOn: binding(L("smoothCursor"), \.smoothCursor))
                        HStack {
                            Button(L("hideCursorRange")) { model.hideCursorInSelection() }.disabled(!model.canHideCursor)
                            Button(L("showCursorRange")) { model.showCursorInSelection() }.disabled(!model.canHideCursor || model.info.edits.cursorHidden.isEmpty)
                        }
                        Text(L("cursorRangeHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L("cursorBakedIn")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsSection(L("clicksSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("highlightClicks"), isOn: binding(L("highlightClicks"), \.highlightClicks))
                    Text(String(format: L("clickCount"), model.info.cursor.clicks.count)).font(.caption).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.info.hasCamera {
                SettingsSection(L("cameraSection")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(L("showCamera"), isOn: binding(L("showCamera"), \.showCamera))
                        Picker(L("cameraCorner"), selection: binding(L("cameraCorner"), \.cameraCorner)) {
                            ForEach(CameraCorner.allCases, id: \.self) { Text(L("corner." + $0.rawValue)).tag($0) }
                        }
                        Picker(L("cameraShape"), selection: binding(L("cameraShape"), \.cameraShape)) {
                            ForEach(CameraShape.allCases, id: \.self) { Text(L("shape." + $0.rawValue)).tag($0) }
                        }
                        HStack { Text(L("cameraSize")); Slider(value: binding(L("cameraSize"), \.cameraSize), in: 0.12...0.5) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if model.info.hasSystemAudio || model.info.hasMicrophone {
                SettingsSection(L("audioSection")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if model.info.hasSystemAudio { HStack { Text(L("systemAudio")); Slider(value: binding(L("systemVolume"), \.systemVolume), in: 0...2) } }
                        if model.info.hasMicrophone { HStack { Text(L("microphone")); Slider(value: binding(L("micVolume"), \.micVolume), in: 0...2) } }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            SettingsSection(L("exportSection")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(L("exportFormat"), selection: $model.exportOptions.format) {
                        Text("MP4").tag(ExportFormat.mp4); Text("MOV").tag(ExportFormat.mov); Text("GIF").tag(ExportFormat.gif)
                    }
                    if model.exportOptions.format == .gif {
                        Picker(L("gifWidth"), selection: $model.exportOptions.gifWidth) { ForEach([480, 640, 800, 1024, 1280], id: \.self) { Text("\($0) px").tag($0) } }
                        Picker(L("gifFPS"), selection: $model.exportOptions.gifFPS) { ForEach([5, 10, 15, 20], id: \.self) { Text("\($0) fps").tag($0) } }
                    } else {
                        Picker(L("exportSize"), selection: $model.exportOptions.size) {
                            ForEach(ExportSize.allCases, id: \.self) { size in Text(size == .original ? String(format: L("sizeOriginal"), model.info.height) : "\(size.rawValue)p").tag(size) }
                        }
                        Toggle(L("hevc"), isOn: $model.exportOptions.hevc)
                    }
                }.disabled(model.exporting).frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.hasCuts {
                Button(L("restoreCuts")) { model.restoreCuts() }
            }
        }
    }
}

/// Ruler, picture, zooms and audio. Click to move the playhead; drag across the picture to select a range.
struct TimelineView: View {
    @ObservedObject var model: EditorModel
    @State private var dragStart: Double?
    private let rulerHeight: CGFloat = 22, videoHeight: CGFloat = 64, zoomHeight: CGFloat = 26, cursorHeight: CGFloat = 18, audioHeight: CGFloat = 36

    var body: some View {
        GeometryReader { geometry in
            let pps = max(model.pixelsPerSecond, Double(geometry.size.width - 24) / max(model.duration, 0.1))
            let width = CGFloat(model.duration * pps) + 24
            ScrollView(.horizontal) {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Ruler(duration: model.duration, pps: pps).frame(height: rulerHeight)
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onChanged { model.player.pause(); model.seek(Double($0.location.x) / pps) })
                        videoLane(pps: pps).frame(height: videoHeight)
                        zoomLane(pps: pps).frame(height: zoomHeight)
                        if model.info.hasCursorLayer { cursorLane(pps: pps).frame(height: cursorHeight) }
                        ForEach(Array(audioLanes.enumerated()), id: \.offset) { _, lane in
                            Waveform(peaks: lane.peaks, kept: model.kept, pps: pps, label: lane.label).frame(height: audioHeight)
                        }
                    }
                    if let selection = model.selection {
                        Rectangle().fill(Color.accentColor.opacity(0.18)).overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: 1))
                            .frame(width: max(1, CGFloat(selection.duration * pps)), height: videoHeight)
                            .offset(x: CGFloat(selection.start * pps), y: rulerHeight + 4).allowsHitTesting(false)
                    }
                    Rectangle().fill(Color.red).frame(width: 2).frame(maxHeight: .infinity)
                        .offset(x: CGFloat(model.currentTime * pps) - 1).allowsHitTesting(false).accessibilityHidden(true)
                }
                .frame(width: width, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 6)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var audioLanes: [(label: String, peaks: [Float])] {
        var lanes: [(String, [Float])] = []
        var index = 0
        for (present, label) in [(model.info.hasSystemAudio, L("systemAudio")), (model.info.hasMicrophone, L("microphone"))] where present {
            lanes.append((label, index < model.waveforms.count ? model.waveforms[index] : []))
            index += 1
        }
        return lanes
    }

    private func videoLane(pps: Double) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.25))
            ForEach(Array(model.thumbnails.enumerated()), id: \.offset) { _, thumb in
                Image(decorative: thumb.image, scale: 1).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: CGFloat(max(0.5, model.duration / 60) * pps), height: videoHeight).clipped()
                    .offset(x: CGFloat(thumb.t * pps))
            }
            // Where cuts were made.
            ForEach(Array(model.kept.dropLast().enumerated()), id: \.offset) { index, _ in
                let x = model.kept.prefix(index + 1).reduce(0) { $0 + $1.duration } * pps
                Rectangle().fill(Color.orange).frame(width: 2, height: videoHeight).offset(x: CGFloat(x) - 1)
            }
        }
        .frame(width: CGFloat(model.duration * pps), alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                model.player.pause()
                let start = Double(value.startLocation.x) / pps, now = min(max(0, Double(value.location.x) / pps), model.duration)
                if abs(value.translation.width) < 3 { model.selection = nil; model.seek(start) }
                else { model.selection = Span(start: max(0, min(start, now)), end: max(start, now)); model.seek(now) }
            })
        .accessibilityElement().accessibilityLabel(L("videoLane"))
    }

    /// Where the pointer is shown (bar) or hidden (gap).
    private func cursorLane(pps: Double) -> some View {
        let hidden = model.info.edits.cursorHidden.map { model.outputRange(ZoomSpan(start: $0.start, end: $0.end)) }
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(model.info.edits.showCursor ? 0.35 : 0.1)).frame(width: CGFloat(model.duration * pps))
            ForEach(Array(hidden.enumerated()), id: \.offset) { _, span in
                Rectangle().fill(Color(nsColor: .textBackgroundColor)).overlay(Rectangle().strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3])))
                    .frame(width: max(2, CGFloat(span.duration * pps))).offset(x: CGFloat(span.start * pps))
            }
            Image(systemName: "cursorarrow").font(.system(size: 10)).foregroundColor(.secondary).padding(.leading, 4).padding(.top, 2).allowsHitTesting(false)
        }
        .accessibilityElement().accessibilityLabel(L("cursorLane"))
    }

    private func zoomLane(pps: Double) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: CGFloat(model.duration * pps))
            ForEach(model.info.edits.zooms) { zoom in
                ZoomBlock(model: model, zoom: zoom, pps: pps, height: zoomHeight)
            }
        }
    }
}

struct ZoomBlock: View {
    @ObservedObject var model: EditorModel
    let zoom: ZoomSpan
    let pps: Double
    let height: CGFloat
    @State private var shift = 0.0
    @State private var startShift = 0.0
    @State private var endShift = 0.0

    var body: some View {
        let range = model.outputRange(zoom)
        let start = range.start + shift + startShift, end = range.end + shift + endShift
        let selected = model.selectedZoom == zoom.id
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(appTint.opacity(selected ? 0.9 : 0.55))
            Text(String(format: "%.1f×", zoom.scale)).font(.caption2.bold()).foregroundColor(.white).lineLimit(1)
            HStack {
                handle.gesture(DragGesture().onChanged { startShift = Double($0.translation.width) / pps }
                    .onEnded { _ in commit(start, end) })
                Spacer(minLength: 0)
                handle.gesture(DragGesture().onChanged { endShift = Double($0.translation.width) / pps }
                    .onEnded { _ in commit(start, end) })
            }
        }
        .frame(width: max(8, CGFloat((end - start) * pps)), height: height)
        .offset(x: CGFloat(start * pps))
        .gesture(DragGesture(minimumDistance: 2).onChanged { shift = Double($0.translation.width) / pps }.onEnded { _ in commit(start, end) })
        .onTapGesture { model.selectedZoom = zoom.id; model.seek(range.start) }
        .accessibilityElement().accessibilityLabel(String(format: L("zoomBlock"), zoom.scale, timecode(range.start), timecode(range.end)))
        .accessibilityAddTraits(.isButton)
    }
    private var handle: some View {
        Rectangle().fill(Color.white.opacity(0.001)).frame(width: 8).onHover { inside in
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
    }
    private func commit(_ start: Double, _ end: Double) {
        shift = 0; startShift = 0; endShift = 0
        model.setZoom(zoom.id, outputStart: start, outputEnd: end)
    }
}

struct Ruler: View {
    let duration: Double
    let pps: Double
    var body: some View {
        Canvas { context, size in
            let steps = [1.0, 2, 5, 10, 15, 30, 60, 120, 300]
            let step = steps.first { $0 * pps >= 70 } ?? 600
            var t = 0.0
            while t <= duration {
                let x = CGFloat(t * pps)
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: size.height - 8)); $0.addLine(to: CGPoint(x: x, y: size.height)) }, with: .color(.secondary))
                context.draw(Text(timecode(t, tenths: false)).font(.system(size: 10)).foregroundColor(.secondary), at: CGPoint(x: x + 3, y: 6), anchor: .topLeading)
                t += step
            }
        }
        .accessibilityLabel(L("ruler"))
    }
}

/// Recording-time peaks drawn along the edited timeline (cut parts skipped).
struct Waveform: View {
    let peaks: [Float]
    let kept: [Span]
    let pps: Double
    let label: String
    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                guard !peaks.isEmpty else { return }
                let mid = size.height / 2
                var path = Path()
                var offset = 0.0
                for span in kept {
                    let first = Int(span.start / EditorModel.waveStep), last = min(peaks.count, Int(span.end / EditorModel.waveStep))
                    guard first < last else { offset += span.duration; continue }
                    // About one bar per 2 points.
                    let stride = max(1, Int(2 / (EditorModel.waveStep * pps)))
                    for i in Swift.stride(from: first, to: last, by: stride) {
                        let x = CGFloat((offset + Double(i) * EditorModel.waveStep - span.start) * pps)
                        let h = CGFloat(peaks[i]) * (size.height - 4) / 2
                        path.addRect(CGRect(x: x, y: mid - h, width: 1, height: max(1, h * 2)))
                    }
                    offset += span.duration
                }
                context.fill(path, with: .color(.accentColor.opacity(0.75)))
            }
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)))
            Text(label).font(.caption2).foregroundColor(.secondary).padding(.leading, 4).padding(.top, 2)
        }
        .frame(width: CGFloat(Timeline.outputDuration(kept) * pps), alignment: .leading)
        .accessibilityElement().accessibilityLabel(label)
    }
}
