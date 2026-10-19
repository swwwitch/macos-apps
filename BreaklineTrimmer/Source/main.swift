import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Carbon

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// The open image, the drawn band, the trimming settings and the preview.
@MainActor
final class Model: ObservableObject {
    /// Trimming settings, exported and synced by 「設定の共有」.
    static let sharedKeys: Set<String> = ["maskScale", "maskCrossScale", "maskOffset", "cutStyle", "warpPercent", "jaggedSize", "jaggedRidges",
                             "gap", "addRule", "ruleWidth", "roundCap", "ruleDashed", "dashSegments", "ruleColor", "outputSuffix", "outputLocation", OutputFormat.key, "openAfterSave"]
    static let defaultSuffix = "-breakline"
    /// The preview is rendered at most this many pixels on its long side.
    static let previewPixels: CGFloat = 1600

    private let defaults = UserDefaults.standard
    @Published var settings: TrimSettings {
        didSet {
            let clamped = settings.clamped()
            if clamped != settings { settings = clamped; return }
            if settings != oldValue { saveSettings(); refresh() }
        }
    }
    /// Stay running after the main window is closed. On by default.
    @Published var keepRunning: Bool { didSet { defaults.set(keepRunning, forKey: "keepRunning") } }

    /// Where 「保存」 writes. The fixed folder is a path on this Mac (not exported or synced).
    enum OutputLocation: String, CaseIterable {
        case sameAsSource, desktop, fixedFolder, ask
    }
    @Published var outputLocation: OutputLocation { didSet { defaults.set(outputLocation.rawValue, forKey: "outputLocation") } }
    @Published var outputFolder: URL? { didSet { defaults.set(outputFolder?.path, forKey: "outputFolder") } }
    @Published var outputFormat: OutputFormat { didSet { defaults.set(outputFormat.rawValue, forKey: OutputFormat.key) } }
    /// Open the saved file in its default app. Off by default.
    @Published var openAfterSave: Bool { didSet { defaults.set(openAfterSave, forKey: "openAfterSave") } }
    /// Added to the original name: "photo" → "photo-breakline.png". Characters a file name cannot hold are dropped.
    @Published var outputSuffix: String {
        didSet {
            let cleaned = Self.cleanSuffix(outputSuffix)
            if cleaned != outputSuffix { outputSuffix = cleaned; return }
            defaults.set(outputSuffix, forKey: "outputSuffix")
        }
    }

    @Published private(set) var source: SourceImage?
    @Published private(set) var sourceURL: URL?
    @Published private(set) var sourceName = ""
    @Published private(set) var displayImage: NSImage?
    /// The area to remove, in source pixels (the mask shape drawn in Illustrator).
    @Published var band: CGRect? { didSet { if band != oldValue { refresh() } } }
    @Published private(set) var layout: TrimLayout?
    @Published private(set) var layoutError: TrimLayoutError?
    @Published private(set) var preview: NSImage?
    @Published private(set) var isSaving = false
    /// A short message in the status line (saved, copied, could not open…); cleared by the next change.
    @Published private(set) var notice: (text: String, failed: Bool)?
    private var generation = 0

    init() {
        Self.migrateFromFormerBundleID()
        keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
        outputLocation = UserDefaults.standard.string(forKey: "outputLocation").flatMap(OutputLocation.init(rawValue:)) ?? .sameAsSource
        outputFolder = UserDefaults.standard.string(forKey: "outputFolder").map { URL(fileURLWithPath: $0, isDirectory: true) }
        outputSuffix = Self.cleanSuffix(UserDefaults.standard.string(forKey: "outputSuffix") ?? Self.defaultSuffix)
        outputFormat = Self.storedFormat()
        openAfterSave = UserDefaults.standard.bool(forKey: "openAfterSave")
        settings = Self.storedSettings()
    }

    /// 1.1.0 build 3 changed the Bundle ID (formerly jp.dtp-transit.trimbreakline, the name TrimBreakline).
    /// Copies that domain's settings once, without overwriting anything already set here.
    static let formerBundleID = "jp.dtp-transit.trimbreakline"
    private static func migrateFromFormerBundleID() {
        let defaults = UserDefaults.standard
        let doneKey = "migratedFromTrimBreakline"
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        let former = formerBundleID as CFString
        guard let keys = CFPreferencesCopyKeyList(former, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] else { return }
        for key in keys where defaults.object(forKey: key) == nil {
            guard let value = CFPreferencesCopyAppValue(key as CFString, former) else { continue }
            // Window positions were saved under the former names.
            let renamed = key.replacingOccurrences(of: "TrimBreaklineMain", with: "BreaklineTrimmerMain")
                .replacingOccurrences(of: "TrimBreaklineSettings", with: "BreaklineTrimmerSettings")
            defaults.set(value, forKey: renamed)
        }
    }

    var canExport: Bool { source != nil && layout != nil && !isSaving }
    var axis: CutAxis { layout?.axis ?? .horizontal }

    private static func storedSettings() -> TrimSettings {
        let defaults = UserDefaults.standard
        var value = TrimSettings()
        func number(_ key: String) -> Double? { (defaults.object(forKey: key) as? NSNumber)?.doubleValue }
        func flag(_ key: String) -> Bool? { defaults.object(forKey: key) as? Bool }
        value.maskScale = number("maskScale") ?? value.maskScale
        value.maskCrossScale = number("maskCrossScale") ?? value.maskCrossScale
        value.maskOffset = number("maskOffset") ?? value.maskOffset
        value.cutStyle = defaults.string(forKey: "cutStyle").flatMap(CutStyle.init(rawValue:)) ?? value.cutStyle
        value.warpPercent = number("warpPercent") ?? value.warpPercent
        value.jaggedSize = number("jaggedSize") ?? value.jaggedSize
        value.jaggedRidges = number("jaggedRidges").map { Int($0) } ?? value.jaggedRidges
        value.gap = number("gap") ?? value.gap
        value.addRule = flag("addRule") ?? value.addRule
        value.ruleWidth = number("ruleWidth") ?? value.ruleWidth
        value.roundCap = flag("roundCap") ?? value.roundCap
        value.ruleDashed = flag("ruleDashed") ?? value.ruleDashed
        value.dashSegments = number("dashSegments").map { Int($0) } ?? value.dashSegments
        value.ruleColor = defaults.string(forKey: "ruleColor").flatMap(RuleColor.init(hex:)) ?? value.ruleColor
        return value.clamped()
    }

    private func saveSettings() {
        defaults.set(settings.maskScale, forKey: "maskScale")
        defaults.set(settings.maskCrossScale, forKey: "maskCrossScale")
        defaults.set(settings.maskOffset, forKey: "maskOffset")
        defaults.set(settings.cutStyle.rawValue, forKey: "cutStyle")
        defaults.set(settings.warpPercent, forKey: "warpPercent")
        defaults.set(settings.jaggedSize, forKey: "jaggedSize")
        defaults.set(settings.jaggedRidges, forKey: "jaggedRidges")
        defaults.set(settings.gap, forKey: "gap")
        defaults.set(settings.addRule, forKey: "addRule")
        defaults.set(settings.ruleWidth, forKey: "ruleWidth")
        defaults.set(settings.roundCap, forKey: "roundCap")
        defaults.set(settings.ruleDashed, forKey: "ruleDashed")
        defaults.set(settings.dashSegments, forKey: "dashSegments")
        defaults.set(settings.ruleColor.hex, forKey: "ruleColor")
    }

    /// Settings imported or synced from another Mac.
    func reloadSharedSettings() {
        let stored = Self.storedSettings()
        if stored != settings { settings = stored }
        let suffix = Self.cleanSuffix(defaults.string(forKey: "outputSuffix") ?? Self.defaultSuffix)
        if suffix != outputSuffix { outputSuffix = suffix }
        let location = defaults.string(forKey: "outputLocation").flatMap(OutputLocation.init(rawValue:)) ?? .sameAsSource
        if location != outputLocation { outputLocation = location }
        let format = Self.storedFormat()
        if format != outputFormat { outputFormat = format }
        let open = defaults.bool(forKey: "openAfterSave")
        if open != openAfterSave { openAfterSave = open }
    }

    static func storedFormat() -> OutputFormat {
        UserDefaults.standard.string(forKey: OutputFormat.key).flatMap(OutputFormat.init(rawValue:)) ?? .png
    }

    static func cleanSuffix(_ text: String) -> String {
        String(text.filter { !"/:\n\r\t".contains($0) }.prefix(64))
    }

    func chooseOutputFolder(from window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.title = L("chooseFolderTitle")
        panel.prompt = L("chooseFolderPrompt")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputFolder
        let done: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.outputFolder = url
            self?.outputLocation = .fixedFolder
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: done) } else { done(panel.runModal()) }
    }

    func resetSettings() { settings = TrimSettings() }

    // MARK: Opening

    static func isImage(_ url: URL) -> Bool {
        url.isFileURL && (UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false)
    }

    func open(_ url: URL) {
        guard Self.isImage(url) else { notice = (L("notImage"), true); return }
        do {
            install(try SourceImage.load(url), url: url, name: url.lastPathComponent)
        } catch {
            notice = (String(format: L("cannotOpen"), url.lastPathComponent), true)
        }
    }

    func openPanel(from window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.title = L("openPanelTitle")
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let done: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.open(url)
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: done) } else { done(panel.runModal()) }
    }

    /// An image file or image data on the pasteboard (Finder copy, screenshot to clipboard, browser…).
    static func pasteboardHasImage(_ pasteboard: NSPasteboard = .general) -> Bool {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           urls.contains(where: isImage) { return true }
        return pasteboard.availableType(from: [.png, .tiff]) != nil
    }

    func paste(from pasteboard: NSPasteboard = .general) {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first(where: Self.isImage) {
            open(url); return
        }
        guard let type = pasteboard.availableType(from: [.png, .tiff]), let data = pasteboard.data(forType: type),
              let image = try? SourceImage.load(data: data) else {
            notice = (L("noImageToPaste"), true); return
        }
        install(image, url: nil, name: L("pastedImage"))
    }

    func openDropped(_ providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url else { return }
                Task { @MainActor [weak self] in self?.open(url) }
            }
            return true
        }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let data, let image = try? SourceImage.load(data: data) { self.install(image, url: nil, name: L("droppedImage")) }
                    else { self.notice = (L("notImage"), true) }
                }
            }
            return true
        }
        return false
    }

    private func install(_ image: SourceImage, url: URL?, name: String) {
        source = image
        sourceURL = url
        sourceName = name
        displayImage = NSImage(cgImage: image.image, size: image.size)
        notice = nil
        // Start with a band across the middle so the result shows right away.
        let size = image.size
        let fresh = CGRect(x: 0, y: (size.height * 0.425).rounded(), width: size.width, height: max(1, (size.height * 0.15).rounded()))
        if band == fresh { refresh() } else { band = fresh }
    }

    // MARK: Layout and preview

    func refresh() {
        generation += 1
        let current = generation
        guard let source, let band else { layout = nil; layoutError = nil; preview = nil; return }
        if notice?.failed == false { notice = nil }
        do {
            let newLayout = try TrimLayout.make(imageSize: source.size, band: band, settings: settings)
            layout = newLayout; layoutError = nil
            let image = source.image, settings = settings
            let scale = min(1, Self.previewPixels / max(newLayout.bounds.width, newLayout.bounds.height, 1))
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let rendered = TrimRenderer.render(image, layout: newLayout, settings: settings, scale: scale)
                Task { @MainActor [weak self] in
                    guard let self, self.generation == current else { return }
                    self.preview = rendered.map { NSImage(cgImage: $0, size: newLayout.bounds.size) }
                }
            }
        } catch let error as TrimLayoutError {
            layout = nil; layoutError = error; preview = nil
        } catch {
            layout = nil; layoutError = .noBand; preview = nil
        }
    }

    var statusText: String {
        if let notice { return notice.text }
        guard let source else { return L("statusNoImage") }
        if let layoutError { return Self.message(for: layoutError) }
        guard let layout else { return L("statusDrawBand") }
        let kind = layout.keepsOneSide ? L("keepOneSide") : (layout.axis == .horizontal ? L("splitTopBottom") : L("splitLeftRight"))
        return String(format: L("statusSizes"), Int(source.size.width), Int(source.size.height),
                      Int(layout.bounds.width), Int(layout.bounds.height)) + " · " + kind
    }

    var statusFailed: Bool { notice?.failed ?? (source != nil && layoutError != nil) }

    static func message(for error: TrimLayoutError) -> String {
        switch error {
        case .noBand: return L("statusDrawBand")
        case .coversWholeImage(.horizontal): return L("bandCoversAllY")
        case .coversWholeImage(.vertical): return L("bandCoversAllX")
        }
    }

    // MARK: Output

    /// The full-size result.
    private func renderFull() -> CGImage? {
        guard let source, let layout else { return nil }
        return TrimRenderer.render(source.image, layout: layout, settings: settings, background: PreviewBackground.current.fill)
    }

    /// The background painted into a saved file: the chosen one, or white for a JPEG when it is transparent.
    static func fileBackground(for format: OutputFormat) -> CGColor? {
        PreviewBackground.current.fill ?? (format.keepsTransparency ? nil : PreviewBackground.white.fill)
    }

    /// The name without number: the original name plus the suffix ("image" for pasted or dropped data).
    var outputBase: String {
        (sourceURL?.deletingPathExtension().lastPathComponent ?? "image") + outputSuffix
    }

    /// "name-breakline.png", then "name-breakline 2.png"… in `folder`; never an existing item (so never the original).
    static func freeName(in folder: URL, base: String, extension ext: String) -> String {
        var name = "\(base.isEmpty ? "image" : base).\(ext)"
        var number = 2
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path) {
            name = "\(base.isEmpty ? "image" : base) \(number).\(ext)"; number += 1
        }
        return name
    }

    /// The folder 「保存」 writes to without asking, or nil to show the save panel.
    var directFolder: URL? {
        switch outputLocation {
        case .sameAsSource: return sourceURL?.deletingLastPathComponent()
        case .desktop: return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        case .fixedFolder: return outputFolder
        case .ask: return nil
        }
    }

    /// The save button asks for nothing more when the folder is known.
    var saveTitle: String { String(format: L(directFolder == nil ? "saveButton" : "saveButtonDirect"), outputFormat.name) }
    var saveMenuTitle: String { String(format: L(directFolder == nil ? "saveMenu" : "saveMenuDirect"), outputFormat.name) }

    func save(from window: NSWindow?) {
        guard canExport else { return }
        if let folder = directFolder {
            var isFolder: ObjCBool = false
            if FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue {
                write(into: folder); return
            }
            // A fixed folder that is gone (disconnected drive…): say so and ask instead.
            notice = (String(format: L("folderMissing"), folder.path), true)
        }
        let panel = NSSavePanel()
        panel.title = String(format: L("savePanelTitle"), outputFormat.name)
        panel.allowedContentTypes = [outputFormat.type]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let folder = sourceURL?.deletingLastPathComponent() ?? outputFolder
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        panel.directoryURL = folder
        panel.nameFieldStringValue = Self.freeName(in: folder, base: outputBase, extension: outputFormat.fileExtension)
        let done: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.write(to: url)
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: done) } else { done(panel.runModal()) }
    }

    /// The URL chosen in the save panel (the panel has confirmed any replacement), or a new name in `folder`.
    private func write(to chosen: URL? = nil, into folder: URL? = nil) {
        // The original is never replaced, even when the save panel would allow it.
        if let chosen, let sourceURL, chosen.standardizedFileURL.resolvingSymlinksInPath() == sourceURL.standardizedFileURL.resolvingSymlinksInPath() {
            notice = (L("cannotReplaceOriginal"), true); return
        }
        guard let source, let layout else { return }
        isSaving = true
        notice = (L("saving"), false)
        let image = source.image, properties = source.properties, settings = settings, base = outputBase
        let format = outputFormat, background = Self.fileBackground(for: format)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<(URL, CGSize), Error> = Result {
                guard let rendered = TrimRenderer.render(image, layout: layout, settings: settings, background: background) else { throw TrimImageError.cannotRender }
                let data = try TrimRenderer.fileData(rendered, format: format, properties: properties)
                let size = CGSize(width: rendered.width, height: rendered.height)
                if let chosen {
                    // Encoded first, then written atomically: an interrupted save leaves no broken file.
                    try data.write(to: chosen, options: .atomic)
                    return (chosen, size)
                }
                guard let folder else { throw TrimImageError.cannotWrite }
                // Written beside under a hidden name, then moved to a free name; an existing file is never replaced.
                let temporary = folder.appendingPathComponent(".BreaklineTrimmer-\(UUID().uuidString).\(format.fileExtension)")
                try data.write(to: temporary, options: .atomic)
                defer { try? FileManager.default.removeItem(at: temporary) }
                for _ in 0..<1000 {
                    let target = folder.appendingPathComponent(Self.freeName(in: folder, base: base, extension: format.fileExtension))
                    do { try FileManager.default.moveItem(at: temporary, to: target); return (target, size) }
                    catch CocoaError.fileWriteFileExists { continue }
                }
                throw TrimImageError.cannotWrite
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success(let (url, size)):
                    if self.openAfterSave { NSWorkspace.shared.open(url) }
                    self.notice = (String(format: L("saved"), url.lastPathComponent, Int(size.width), Int(size.height)), false)
                case .failure(let error):
                    self.notice = (String(format: L("saveFailed"), error.localizedDescription), true)
                }
            }
        }
    }

    func copy() {
        guard canExport, let source, let rendered = renderFull() else { return }
        do {
            let png = try TrimRenderer.fileData(rendered, format: .png, properties: source.properties)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(png, forType: .png)
            if let tiff = NSBitmapImageRep(cgImage: rendered).tiffRepresentation { pasteboard.setData(tiff, forType: .tiff) }
            notice = (String(format: L("copied"), rendered.width, rendered.height), false)
        } catch {
            notice = (String(format: L("saveFailed"), error.localizedDescription), true)
        }
    }
}

// MARK: - Views

struct Header: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView {
        let header = appHeader(L("headline"), subtitle: L("subtitle"))
        func unselectable(_ view: NSView) {
            if let field = view as? NSTextField { field.isSelectable = false; field.drawsBackground = false; field.refusesFirstResponder = true }
            view.subviews.forEach(unselectable)
        }
        unselectable(header)
        return header
    }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

/// White rounded box for the source and the preview.
struct Pane<Content: View>: View {
    let title: String
    let detail: String
    /// Controls at the right end of the title row.
    let accessory: AnyView?
    let content: Content
    init(_ title: String, detail: String = "", accessory: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.detail = detail; self.accessory = accessory; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                if let accessory { accessory }
            }
            .frame(height: 20)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// Gray and white squares behind transparent pixels.
struct Checkerboard: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 8
            let light = scheme == .dark ? Color(white: 0.30) : Color.white
            let dark = scheme == .dark ? Color(white: 0.22) : Color(white: 0.86)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(light))
            var squares = Path()
            for row in 0..<Int((size.height / cell).rounded(.up)) {
                for column in 0..<Int((size.width / cell).rounded(.up)) where (row + column) % 2 == 1 {
                    squares.addRect(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            context.fill(squares, with: .color(dark))
        }
        .accessibilityHidden(true)
    }
}

/// The image fitted into `area` (centered, never enlarged past 1 px per point… unless tiny).
func fittedRect(_ imageSize: CGSize, in area: CGSize, inset: CGFloat = 14) -> CGRect {
    let available = CGSize(width: max(1, area.width - inset * 2), height: max(1, area.height - inset * 2))
    let scale = min(available.width / imageSize.width, available.height / imageSize.height)
    let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(x: (area.width - size.width) / 2, y: (area.height - size.height) / 2, width: size.width, height: size.height)
}

struct RectShape: Shape {
    let rect: CGRect
    func path(in _: CGRect) -> Path { Path(rect) }
}

/// What a drag on the source does, decided where it starts.
struct CanvasDrag: Equatable {
    enum Kind { case draw, move, resize }
    var kind: Kind
    /// For resize: the band edges that follow the pointer.
    var top = false, bottom = false, left = false, right = false

    /// Points from a band edge (or guide) that still grab it.
    static let grab: CGFloat = 6

    /// Edges and guides first, then inside the band (move), else a new band.
    static func hit(_ point: CGPoint, band: CGRect?, fit: CGRect, axis: CutAxis) -> CanvasDrag {
        guard let band, !band.isNull else { return CanvasDrag(kind: .draw) }
        let grab = Self.grab
        // The guides across the cut run the full width (or height) of the image, so they grab anywhere along it.
        let alongX = axis == .horizontal ? (fit.minX - grab)...(fit.maxX + grab) : (band.minX - grab)...(band.maxX + grab)
        let alongY = axis == .vertical ? (fit.minY - grab)...(fit.maxY + grab) : (band.minY - grab)...(band.maxY + grab)
        var drag = CanvasDrag(kind: .resize)
        let topDistance = abs(point.y - band.minY), bottomDistance = abs(point.y - band.maxY)
        if alongX.contains(point.x), min(topDistance, bottomDistance) <= grab {
            // A thin band: take the nearer edge.
            if topDistance <= bottomDistance { drag.top = true } else { drag.bottom = true }
        }
        let leftDistance = abs(point.x - band.minX), rightDistance = abs(point.x - band.maxX)
        if alongY.contains(point.y), min(leftDistance, rightDistance) <= grab {
            if leftDistance <= rightDistance { drag.left = true } else { drag.right = true }
        }
        if drag.top || drag.bottom || drag.left || drag.right { return drag }
        return CanvasDrag(kind: band.contains(point) ? .move : .draw)
    }

    var cursor: NSCursor {
        switch kind {
        case .draw: return .crosshair
        case .move: return .openHand
        case .resize: return (top || bottom) && !(left || right) ? .resizeUpDown : (left || right) && !(top || bottom) ? .resizeLeftRight : .crosshair
        }
    }
}

/// The source image. Drag the guides (the band edges) to set the area to remove, drag inside it to move it,
/// or drag elsewhere to draw a new one.
struct SourceCanvas: View {
    @ObservedObject var model: Model
    @State private var bandAtStart: CGRect?
    @State private var drag: CanvasDrag?
    @State private var targeted = false

    var body: some View {
        GeometryReader { geometry in
            if let image = model.displayImage, let source = model.source {
                let fit = fittedRect(source.size, in: geometry.size)
                let scale = fit.width / source.size.width
                ZStack(alignment: .topLeading) {
                    Checkerboard().frame(width: fit.width, height: fit.height).offset(x: fit.minX, y: fit.minY)
                    Image(nsImage: image).resizable().interpolation(.high)
                        .frame(width: fit.width, height: fit.height).offset(x: fit.minX, y: fit.minY)
                        .accessibilityHidden(true)
                    overlay(fit: fit, scale: scale)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(dragGesture(fit: fit, scale: scale, imageSize: source.size))
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        (drag ?? CanvasDrag.hit(point, band: viewRect(model.band, fit: fit, scale: scale), fit: fit, axis: model.axis)).cursor.set()
                    case .ended:
                        NSCursor.arrow.set()
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(L("canvasLabel"))
                .accessibilityHint(L("canvasHint"))
            } else {
                placeholder.frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: targeted ? 3 : 0))
        .onDrop(of: [.fileURL, .image], isTargeted: $targeted) { model.openDropped($0) }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.plus").font(.system(size: 40)).foregroundColor(.accentColor)
            Text(L("dropHere")).font(.system(size: 14, weight: .semibold))
            Text(L("dropHint")).font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button(L("openImageButton")) { model.openPanel(from: delegate.mainWindow) }
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    private func viewRect(_ band: CGRect?, fit: CGRect, scale: CGFloat) -> CGRect? {
        band.map { CGRect(x: fit.minX + $0.minX * scale, y: fit.minY + $0.minY * scale, width: $0.width * scale, height: $0.height * scale) }
    }

    @ViewBuilder private func overlay(fit: CGRect, scale: CGFloat) -> some View {
        let toView = { (point: CGPoint) in CGPoint(x: fit.minX + point.x * scale, y: fit.minY + point.y * scale) }
        if let layout = model.layout {
            // Dim what goes away: the image minus the kept parts.
            Path { path in
                path.addRect(fit)
                for part in layout.parts { path.addLines(part.outline.map(toView)); path.closeSubpath() }
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
            .clipShape(RectShape(rect: fit))
            .allowsHitTesting(false)
            Path { path in for line in layout.cutLines { path.addLines(line.map(toView)) } }
                .stroke(Color.red, lineWidth: 1.5)
                .clipShape(RectShape(rect: fit))
                .allowsHitTesting(false)
        }
        if let rect = viewRect(model.band, fit: fit, scale: scale) {
            let color = model.layoutError == nil ? Color.accentColor : Color.red
            let horizontal = model.axis == .horizontal
            // The band's sides along the cut: dashed.
            Path { path in
                if horizontal {
                    path.move(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    path.move(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                } else {
                    path.move(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    path.move(to: CGPoint(x: rect.minX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            .allowsHitTesting(false)
            // The two guides across the image, with a grip in the middle of each.
            Path { path in
                if horizontal {
                    for y in [rect.minY, rect.maxY] { path.move(to: CGPoint(x: fit.minX, y: y)); path.addLine(to: CGPoint(x: fit.maxX, y: y)) }
                } else {
                    for x in [rect.minX, rect.maxX] { path.move(to: CGPoint(x: x, y: fit.minY)); path.addLine(to: CGPoint(x: x, y: fit.maxY)) }
                }
            }
            .stroke(color, lineWidth: 1.5)
            .allowsHitTesting(false)
            ForEach(horizontal ? [rect.minY, rect.maxY] : [rect.minX, rect.maxX], id: \.self) { position in
                Capsule()
                    .fill(color)
                    .overlay(Capsule().stroke(Color.white, lineWidth: 1))
                    .frame(width: horizontal ? 28 : 7, height: horizontal ? 7 : 28)
                    .position(horizontal ? CGPoint(x: rect.midX, y: position) : CGPoint(x: position, y: rect.midY))
                    .allowsHitTesting(false)
            }
        }
    }

    private func dragGesture(fit: CGRect, scale: CGFloat, imageSize: CGSize) -> some Gesture {
        func toImage(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max((point.x - fit.minX) / scale, 0), imageSize.width),
                    y: min(max((point.y - fit.minY) / scale, 0), imageSize.height))
        }
        return DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = toImage(value.startLocation), now = toImage(value.location)
                if drag == nil {
                    bandAtStart = model.band ?? .null
                    drag = CanvasDrag.hit(value.startLocation, band: viewRect(model.band, fit: fit, scale: scale), fit: fit, axis: model.axis)
                }
                guard let drag, let original = bandAtStart else { return }
                switch drag.kind {
                case .move where !original.isNull:
                    // Moving keeps the size and stays inside the image.
                    let x = min(max(original.minX + now.x - start.x, 0), imageSize.width - original.width)
                    let y = min(max(original.minY + now.y - start.y, 0), imageSize.height - original.height)
                    model.band = CGRect(x: x.rounded(), y: y.rounded(), width: original.width, height: original.height)
                case .resize where !original.isNull:
                    // The dragged edge follows the pointer, inside the image and never past the opposite edge.
                    var minX = original.minX, maxX = original.maxX, minY = original.minY, maxY = original.maxY
                    let dx = now.x - start.x, dy = now.y - start.y
                    if drag.top { minY = min(max(original.minY + dy, 0), maxY - 1).rounded() }
                    if drag.bottom { maxY = max(min(original.maxY + dy, imageSize.height), minY + 1).rounded() }
                    if drag.left { minX = min(max(original.minX + dx, 0), maxX - 1).rounded() }
                    if drag.right { maxX = max(min(original.maxX + dx, imageSize.width), minX + 1).rounded() }
                    model.band = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                default:
                    let minX = min(start.x, now.x).rounded(), minY = min(start.y, now.y).rounded()
                    model.band = CGRect(x: minX, y: minY, width: max(start.x, now.x).rounded() - minX, height: max(start.y, now.y).rounded() - minY)
                }
                drag.cursor.set()
            }
            .onEnded { _ in
                // A click or a sliver does not replace the band.
                if drag?.kind == .draw, let band = model.band, band.width < 2 || band.height < 2, let original = bandAtStart {
                    model.band = original.isNull ? nil : original
                }
                bandAtStart = nil
                drag = nil
            }
    }
}

/// What fills the transparent pixels: shown behind the preview and painted into the saved or copied image.
enum PreviewBackground: String, CaseIterable {
    case transparent, white, gray, black
    static let key = "previewBackground"
    static var current: PreviewBackground {
        UserDefaults.standard.string(forKey: key).flatMap(PreviewBackground.init(rawValue:)) ?? .transparent
    }
    var title: String { L("background." + rawValue) }
    /// The color painted under the output; nil keeps it transparent.
    var fill: CGColor? {
        switch self {
        case .transparent: return nil
        case .white: return CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        case .gray: return CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case .black: return CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        }
    }
    @ViewBuilder var view: some View {
        switch self {
        case .transparent: Checkerboard()
        case .white: Color.white
        case .gray: Color(.sRGB, white: 0.5)
        case .black: Color.black
        }
    }
}

struct PreviewBackgroundPicker: View {
    @AppStorage(PreviewBackground.key) private var background = PreviewBackground.transparent
    var body: some View {
        Picker(L("previewBackground"), selection: $background) {
            ForEach(PreviewBackground.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
        .fixedSize()
        .help(L("previewBackgroundHelp"))
        .accessibilityLabel(L("previewBackground"))
    }
}

struct PreviewView: View {
    @ObservedObject var model: Model
    @AppStorage(PreviewBackground.key) private var background = PreviewBackground.transparent
    var body: some View {
        GeometryReader { geometry in
            if let preview = model.preview, let layout = model.layout {
                let fit = fittedRect(layout.bounds.size, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    background.view.frame(width: fit.width, height: fit.height).offset(x: fit.minX, y: fit.minY)
                    Image(nsImage: preview).resizable().interpolation(.high)
                        .frame(width: fit.width, height: fit.height).offset(x: fit.minX, y: fit.minY)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .accessibilityElement()
                .accessibilityLabel(L("previewLabel"))
                .accessibilityValue(String(format: L("pixelSize"), Int(layout.bounds.width), Int(layout.bounds.height)))
            } else {
                Text(model.source == nil ? L("previewEmpty") : model.statusText)
                    .font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center).padding()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

/// One cut-edge style, drawn like the script's icon buttons.
struct CutStyleButton: View {
    let style: CutStyle
    @Binding var selection: CutStyle
    var body: some View {
        let selected = selection == style
        Button { selection = style } label: {
            Canvas { context, size in
                let side: CGFloat = 24
                let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
                let line = Self.cutPoints(style).map { CGPoint(x: origin.x + $0.x * side, y: origin.y + $0.y * side) }
                context.drawLayer { layer in
                    layer.fill(Path(CGRect(origin: origin, size: CGSize(width: side, height: side))),
                               with: .color(selected ? .primary : .secondary))
                    layer.blendMode = .destinationOut
                    var cut = Path(); cut.addLines(line)
                    layer.stroke(cut, with: .color(.black), style: StrokeStyle(lineWidth: 2.5, lineJoin: .miter))
                }
            }
            .frame(width: 36, height: 36)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("style." + style.rawValue) + "：" + L("styleHelp." + style.rawValue))
        .accessibilityLabel(L("style." + style.rawValue))
        .accessibilityHint(L("styleHelp." + style.rawValue))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// The cut line in the icon (0…1, y down), as in getStyleIconCutPoints.
    static func cutPoints(_ style: CutStyle) -> [CGPoint] {
        let steps = 24
        switch style {
        case .flag:
            return (0...steps).map { let x = CGFloat($0) / CGFloat(steps); return CGPoint(x: x, y: 0.5 + 0.16 * sin(x * .pi * 2)) }
        case .rise:
            return (0...steps).map { let x = CGFloat($0) / CGFloat(steps); return CGPoint(x: x, y: 0.68 - 0.36 * (1 - cos(x * .pi)) / 2) }
        case .riseStraight:
            return [CGPoint(x: 0, y: 0.6), CGPoint(x: 1, y: 0.42)]
        case .jagged:
            return (0...6).map { CGPoint(x: CGFloat($0) / 6, y: $0 % 2 == 0 ? 0.44 : 0.56) }
        }
    }
}

/// Label, number field, stepper and unit on one row.
struct NumberRow: View {
    let title: String
    @Binding var value: Double
    let unit: String
    var step: Double = 1
    var range: ClosedRange<Double> = -100_000...100_000
    let help: String
    var body: some View {
        HStack(spacing: 6) {
            Text(title).frame(width: 70, alignment: .trailing)
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Stepper(title, value: $value, in: range, step: step).labelsHidden()
            Text(unit).foregroundColor(.secondary).frame(width: 22, alignment: .leading)
            Spacer(minLength: 0)
        }
        .help(help)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

extension Binding where Value == Int {
    var asDouble: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = Int($0.rounded()) })
    }
}

/// The settings of the script's dialog: mask shape, cut edge and break lines.
struct ControlsSidebar: View {
    @ObservedObject var model: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox(label: Text(L("panelMask")).font(.system(size: 12, weight: .semibold)).help(L("panelMaskHelp"))) {
                    VStack(alignment: .leading, spacing: 6) {
                        if model.axis == .horizontal {
                            NumberRow(title: L("width"), value: $model.settings.maskCrossScale, unit: "%", range: 1...10_000, help: L("maskCrossScaleHelp"))
                            NumberRow(title: L("height"), value: $model.settings.maskScale, unit: "%", range: 1...10_000, help: L("maskScaleHelp"))
                            NumberRow(title: L("offsetY"), value: $model.settings.maskOffset, unit: "px", help: L("offsetYHelp"))
                        } else {
                            NumberRow(title: L("width"), value: $model.settings.maskScale, unit: "%", range: 1...10_000, help: L("maskScaleHelp"))
                            NumberRow(title: L("height"), value: $model.settings.maskCrossScale, unit: "%", range: 1...10_000, help: L("maskCrossScaleHelp"))
                            NumberRow(title: L("offsetX"), value: $model.settings.maskOffset, unit: "px", help: L("offsetXHelp"))
                        }
                    }
                    .padding(6)
                }
                GroupBox(label: Text(L("panelCutEdge")).font(.system(size: 12, weight: .semibold)).help(L("panelCutEdgeHelp"))) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            ForEach(CutStyle.allCases, id: \.self) { CutStyleButton(style: $0, selection: $model.settings.cutStyle) }
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 4)
                        let jagged = model.settings.cutStyle == .jagged
                        NumberRow(title: L("warpAmount"), value: $model.settings.warpPercent, unit: "%",
                                  range: -TrimSettings.maxWarpPercent...TrimSettings.maxWarpPercent, help: L("warpAmountHelp"))
                            .disabled(jagged)
                        NumberRow(title: L("jaggedSize"), value: $model.settings.jaggedSize, unit: "px", range: 0...10_000, help: L("jaggedSizeHelp"))
                            .disabled(!jagged)
                        NumberRow(title: L("jaggedRidges"), value: $model.settings.jaggedRidges.asDouble, unit: "",
                                  range: 0...Double(TrimSettings.maxJaggedRidges), help: L("jaggedRidgesHelp"))
                            .disabled(!jagged)
                        NumberRow(title: L("gap"), value: $model.settings.gap, unit: "px", range: 0...100_000, help: L("gapHelp"))
                            .disabled(model.layout?.keepsOneSide ?? false)
                    }
                    .padding(6)
                }
                GroupBox(label: Text(L("panelBreakLine")).font(.system(size: 12, weight: .semibold)).help(L("panelBreakLineHelp"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(L("addRule"), isOn: $model.settings.addRule).help(L("addRuleHelp"))
                        Group {
                            HStack(spacing: 6) {
                                Text(L("ruleColor")).frame(width: 70, alignment: .trailing)
                                ColorPicker(L("ruleColor"), selection: ruleColorBinding, supportsOpacity: true).labelsHidden()
                                Button(L("ruleColorBlack")) { model.settings.ruleColor = .black }
                                    .disabled(model.settings.ruleColor == .black)
                                Spacer(minLength: 0)
                            }
                            .help(L("ruleColorHelp"))
                            NumberRow(title: L("strokeWidth"), value: $model.settings.ruleWidth, unit: "px", step: 0.5, range: 0...1_000, help: L("strokeWidthHelp"))
                            choiceRow(L("strokeCap"), help: L("strokeCapHelp"), selection: $model.settings.roundCap,
                                      options: [(L("buttCap"), false), (L("roundCap"), true)])
                            choiceRow(L("ruleStyle"), help: L("ruleStyleHelp"), selection: $model.settings.ruleDashed,
                                      options: [(L("solid"), false), (L("dashed"), true)])
                            NumberRow(title: L("dashSegments"), value: $model.settings.dashSegments.asDouble, unit: "",
                                      range: 1...10_000, help: L("dashSegmentsHelp"))
                                .disabled(!model.settings.ruleDashed)
                        }
                        .disabled(!model.settings.addRule)
                    }
                    .toggleStyle(.checkbox)
                    .padding(6)
                }
                GroupBox(label: Text(L("formatSection")).font(.system(size: 12, weight: .semibold)).help(L("formatHint"))) {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker(L("formatSection"), selection: $model.outputFormat) {
                            ForEach(OutputFormat.allCases, id: \.self) { Text($0.name).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.radioGroup)
                        .horizontalRadioGroupLayout()
                        if !model.outputFormat.keepsTransparency {
                            Text(L("jpegFillsWhite")).font(.system(size: 11)).foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .help(L("formatHint"))
                }
                HStack {
                    Spacer()
                    Button(L("resetDefaults")) { model.resetSettings() }.help(L("resetDefaultsHelp"))
                }
            }
            .controlSize(.small)
            .font(.system(size: 12))
            .padding(.trailing, 4)
        }
    }

    /// The color well works in SwiftUI colors; the setting keeps sRGB components.
    private var ruleColorBinding: Binding<Color> {
        Binding(get: { Color(cgColor: model.settings.ruleColor.cgColor) }, set: { color in
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            model.settings.ruleColor = RuleColor(red: srgb.redComponent, green: srgb.greenComponent,
                                                 blue: srgb.blueComponent, alpha: srgb.alphaComponent)
        })
    }

    private func choiceRow(_ title: String, help: String, selection: Binding<Bool>, options: [(String, Bool)]) -> some View {
        HStack(spacing: 6) {
            Text(title).frame(width: 70, alignment: .trailing)
            Picker(title, selection: selection) {
                ForEach(options, id: \.1) { Text($0.0).tag($0.1) }
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            Spacer(minLength: 0)
        }
        .help(help)
    }
}

struct ContentView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header().frame(height: 66)
            HStack(alignment: .top, spacing: 14) {
                HStack(spacing: 12) {
                    Pane(L("sourceTitle"), detail: model.sourceName) { SourceCanvas(model: model) }
                    Pane(L("previewTitle"), detail: model.layout.map { String(format: L("pixelSize"), Int($0.bounds.width), Int($0.bounds.height)) } ?? "",
                         accessory: AnyView(PreviewBackgroundPicker())) {
                        PreviewView(model: model)
                    }
                }
                ControlsSidebar(model: model).frame(width: 290)
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: 10) {
                Button(L("settingsButton")) { delegate.showPreferences() }
                Label {
                    Text(model.statusText).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: model.statusFailed ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundColor(model.statusFailed ? .orange : .secondary)
                }
                .font(.system(size: 11))
                .foregroundColor(model.statusFailed ? .primary : .secondary)
                .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                Button(L("openImageButton")) { model.openPanel(from: delegate.mainWindow) }
                Button(L("copyButton")) { model.copy() }.disabled(!model.canExport).help(L("copyHelp"))
                Button(model.saveTitle) { model.save(from: delegate.mainWindow) }
                    .disabled(!model.canExport)
                    .buttonStyle(.borderedProminent)
                    .help(L("saveHelp"))
            }
        }
        .padding(20)
        .frame(minWidth: 1000, minHeight: 640)
        .background(Color(nsColor: AppSurface.color))
    }
}

/// 「出力」: where 「保存」 writes, what happens after and how the file is named (the format is in the sidebar).
struct OutputSettings: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("outputLocationSection")) {
                Picker(L("outputLocationSection"), selection: $model.outputLocation) {
                    Text(L("locationSame")).tag(Model.OutputLocation.sameAsSource)
                    Text(L("locationDesktop")).tag(Model.OutputLocation.desktop)
                    Text(L("locationFixed")).tag(Model.OutputLocation.fixedFolder)
                    Text(L("locationAsk")).tag(Model.OutputLocation.ask)
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                HStack(spacing: 8) {
                    Image(systemName: "folder").foregroundColor(.secondary)
                    Text(model.outputFolder?.path ?? L("folderNotSet"))
                        .foregroundColor(model.outputFolder == nil ? .secondary : .primary)
                        .lineLimit(1).truncationMode(.middle)
                    Button(L("chooseFolderButton")) { model.chooseOutputFolder(from: delegate.preferences) }
                }
                .padding(.leading, 20)
                .disabled(model.outputLocation != .fixedFolder)
                Text(L("outputLocationHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(L("afterSaveSection")) {
                Toggle(L("openAfterSave"), isOn: $model.openAfterSave)
                Text(L("openAfterSaveHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(L("fileNameSection")) {
                HStack(spacing: 8) {
                    Text(L("suffixLabel"))
                    TextField(Model.defaultSuffix, text: $model.outputSuffix).frame(width: 180)
                    Button(L("restoreDefault")) { model.outputSuffix = Model.defaultSuffix }
                        .disabled(model.outputSuffix == Model.defaultSuffix)
                }
                Text(String(format: L("suffixExample"), "photo" + model.outputSuffix + "." + model.outputFormat.fileExtension))
                    .font(.caption).foregroundColor(.secondary)
                Text(L("suffixHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct Preferences: View {
    @ObservedObject var model: Model
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    // LoginAtLaunchView already includes 起動時にメインウインドウを表示しない.
                    LoginAtLaunchView()
                    Toggle(L("keepRunning"), isOn: $model.keepRunning)
                    Text(L("keepRunningHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    MenuBarPresenceView()
                }
            })),
            (L("outputTab"), AnyView(OutputSettings(model: model))),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(12)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = MainActor.assumeIsolated { Model() }
    var mainWindow: NSWindow!
    var preferences: NSWindow?
    var helpWindow: NSWindow?
    /// Files handed over before the window exists (Open With / Dock drop at launch).
    private var openedAtLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let loginLaunch = Self.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        installMenus()
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        mainWindow.title = ""; mainWindow.titleVisibility = .hidden; mainWindow.isReleasedWhenClosed = false; mainWindow.delegate = self
        mainWindow.contentView = NSHostingView(rootView: ContentView(model: model)); mainWindow.minSize = NSSize(width: 1000, height: 640)
        mainWindow.center(); mainWindow.setFrameAutosaveName("BreaklineTrimmerMain")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(mainWindow.frame) }) { mainWindow.center() }
        MainActor.assumeIsolated {
            MenuBarPresence.shared.install(name: "BreaklineTrimmer", symbol: "scissors",
                show: { [weak self] in self?.showMain() },
                settings: { [weak self] in self?.showPreferences() },
                help: { [weak self] in self?.showHelp() })
            SettingsSync.shared.onImport = { [weak self] in self?.model.reloadSharedSettings() }
            SettingsSync.shared.start(.init(keys: Model.sharedKeys, prefixes: [],
                note: StartupWindow.text("切り口・省略線・マスク用の図形の設定を書き出し・同期します。画像と描いた範囲は含みません。",
                                         "Exports and syncs the cut edge, break line and mask shape settings. Images and drawn areas are not included.",
                                         "导出并同步切口、省略线和遮罩形状的设置。不包含图像和绘制的范围。",
                                         "절단면, 생략선, 마스크 도형 설정을 내보내고 동기화합니다. 이미지와 그린 범위는 포함하지 않습니다."),
                perMac: StartupWindow.text("ログイン時の起動・常駐・メニューバーの表示はMacごとに設定します。",
                                           "Open at login, keep running and the menu bar icon are set on each Mac.",
                                           "登录时启动、保持运行和菜单栏图标在每台 Mac 上分别设置。",
                                           "로그인 시 실행, 계속 실행, 메뉴 막대 아이콘은 Mac마다 설정합니다.")))
        }
        // A login launch stays quiet; files handed over at launch still show the window.
        if openedAtLaunch || (!loginLaunch && !StartupWindow.hidden) { showMain() }
    }

    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func installMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        func submenu(_ name: String) -> NSMenu { let item = NSMenuItem(); let menu = NSMenu(title: name); item.submenu = menu; bar.addItem(item); return menu }
        func add(_ menu: NSMenu, _ title: String, _ selector: Selector, _ key: String = "", _ target: AnyObject? = nil) {
            let item = menu.addItem(withTitle: title, action: selector, keyEquivalent: key); item.target = target ?? self
        }
        let app = submenu("BreaklineTrimmer")
        add(app, L("about"), #selector(about)); app.addItem(.separator())
        // MenuBarPresence inserts メニューバー設定… at index 2, between these separators.
        add(app, L("settings"), #selector(showPreferences), ",")
        app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        MainActor.assumeIsolated { AppUpdates.shared.addMenuItems(to: app) }
        #endif
        let services = NSMenu(title: L("services")); app.addItem(withTitle: L("services"), action: nil, keyEquivalent: "").submenu = services; NSApp.servicesMenu = services
        app.addItem(.separator())
        add(app, L("hideApp"), #selector(NSApplication.hide(_:)), "h", NSApp)
        add(app, L("hideOthers"), #selector(NSApplication.hideOtherApplications(_:)), "h", NSApp); app.items.last?.keyEquivalentModifierMask = [.command, .option]
        add(app, L("showAll"), #selector(NSApplication.unhideAllApplications(_:)), "", NSApp); app.addItem(.separator())
        add(app, L("quit"), #selector(NSApplication.terminate(_:)), "q", NSApp)
        let file = submenu(L("file"))
        add(file, L("openMainWindow"), #selector(showMain), "0")
        file.addItem(.separator())
        add(file, L("openImageMenu"), #selector(openImage), "o")
        add(file, String(format: L("saveMenu"), "PNG"), #selector(savePNG), "s")
        add(file, L("copyResultMenu"), #selector(copyResult), "C")
        file.addItem(.separator())
        add(file, L("resetDefaults"), #selector(resetSettings))
        file.addItem(.separator())
        add(file, L("close"), #selector(NSWindow.performClose(_:)), "w"); file.items.last?.target = nil
        let edit = submenu(L("edit"))
        for (key, selector, letter) in [("undo", "undo:", "z"), ("redo", "redo:", "Z"), ("cut", "cut:", "x"), ("copy", "copy:", "c"), ("paste", "paste:", "v"), ("selectAll", "selectAll:", "a")] {
            let item = edit.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: letter); item.target = nil
            if key == "redo" { edit.addItem(.separator()) }
        }
        let window = submenu(L("window"))
        for (key, selector) in [("minimize", "performMiniaturize:"), ("zoom", "performZoom:")] {
            window.addItem(withTitle: L(key), action: NSSelectorFromString(selector), keyEquivalent: "").target = nil
        }
        window.addItem(.separator())
        window.addItem(withTitle: L("bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "").target = NSApp
        NSApp.windowsMenu = window
        let help = submenu(L("help")); add(help, L("helpItem"), #selector(showHelp), "?")
        MainActor.assumeIsolated { HelpLinks.addNoteItem(to: help) }
        NSApp.helpMenu = help
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        MainActor.assumeIsolated {
            switch item.action {
            case #selector(savePNG):
                item.title = model.saveMenuTitle
                return model.canExport
            case #selector(copyResult), #selector(copy(_:)): return model.canExport
            case #selector(paste(_:)): return Model.pasteboardHasImage()
            case #selector(openImage): return !model.isSaving
            default: return true
            }
        }
    }

    @objc func showMain() {
        guard mainWindow != nil else { return }
        if mainWindow.isMiniaturized { mainWindow.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true); mainWindow.makeKeyAndOrderFront(nil)
    }
    @objc func openImage() { showMain(); MainActor.assumeIsolated { model.openPanel(from: mainWindow) } }
    @objc func savePNG() { showMain(); MainActor.assumeIsolated { model.save(from: mainWindow) } }
    @objc func copyResult() { MainActor.assumeIsolated { model.copy() } }
    @objc func resetSettings() { MainActor.assumeIsolated { model.resetSettings() } }
    /// Edit > Copy / Paste when no text field takes them: the result image, or an image to open.
    @objc func copy(_ sender: Any?) { copyResult() }
    @objc func paste(_ sender: Any?) { showMain(); MainActor.assumeIsolated { model.paste() } }

    /// Files dropped on the Dock icon or opened from Finder.
    func application(_ sender: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: Model.isImage) ?? urls.first else { return }
        MainActor.assumeIsolated { model.open(url) }
        if mainWindow == nil { openedAtLaunch = true } else { showMain() }
    }

    @objc func showPreferences() {
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L("settingsTitle"); window.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: Preferences(model: model))
            host.sizingOptions = [.minSize]
            window.contentView = host; window.center(); window.setFrameAutosaveName("BreaklineTrimmerSettings")
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
            preferences = window
        }
        NSApp.activate(ignoringOtherApps: true); preferences?.makeKeyAndOrderFront(nil)
    }

    /// A file being written is not cut off: quitting waits until it is done.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard MainActor.assumeIsolated({ model.isSaving }) else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = L("quitWhileSavingTitle")
        alert.informativeText = L("quitWhileSavingInfo")
        alert.addButton(withTitle: L("ok"))
        alert.runModal()
        return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    /// With 常駐 off, closing the main window quits.
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        if !MainActor.assumeIsolated({ model.keepRunning }) { DispatchQueue.main.async { NSApp.terminate(nil) } }
    }
    @objc func showHelp() {
        if helpWindow == nil {
            helpWindow = MainActor.assumeIsolated { HelpDocument.makeWindow(windowTitle: L("helpItem"), text: Self.helpText, heading: "BreaklineTrimmer") }
        }
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
    }
    /// Help body from <lang>.lproj/Help.txt, chosen like the UI strings; English is the last resort.
    static var helpText: String {
        let url = Bundle.main.url(forResource: "Help", withExtension: "txt")
            ?? Bundle.main.url(forResource: "Help", withExtension: "txt", subdirectory: nil, localization: "en")
        if let url, let text = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Help is not available. Reinstall the app."
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: L("support"))]) }
}

// Bundle identity, rather than the bundle path or build number, defines one app.
@MainActor
private enum SingleInstanceLaunch {
    static func enforce() {
        let current = NSRunningApplication.current
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        var candidates = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).filter { !$0.isTerminated }
        if !candidates.contains(where: { $0.processIdentifier == current.processIdentifier }) { candidates.append(current) }
        candidates.sort {
            let left = $0.launchDate ?? .distantPast, right = $1.launchDate ?? .distantPast
            return left == right ? $0.processIdentifier < $1.processIdentifier : left < right
        }
        guard let existing = candidates.first, existing.processIdentifier != current.processIdentifier else { return }
        existing.activate(options: [.activateAllWindows])
        if let url = existing.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in exit(0) }
            // Allow the reopen Apple event to reach the running app.
            RunLoop.main.run(until: Date().addingTimeInterval(2))
        }
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
// Tests/snapshot.sh compiles this file without the block below to render the views offscreen.
#if !SNAPSHOT
MainActor.assumeIsolated { SingleInstanceLaunch.enforce() }
app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
#endif
