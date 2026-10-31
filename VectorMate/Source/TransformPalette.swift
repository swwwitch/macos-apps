import AppKit
import SwiftUI

/// クイック変形 (QuickTransformPalette.jsx): moves, duplicates, flips and rotates the selection on an icon click.
/// The anchor point, margin and preview bounds are shared by every operation; Option-click duplicates first.
/// Each operation is one `do javascript` (one undo step in Illustrator), run one after another.
enum QuickTransform {
    enum Direction: String { case up, down, left, right, none }
    enum Outcome: Equatable {
        /// The ruler unit read in the same call, for the margin's unit label.
        case done(rulerType: Int)
        case noDocument, noSelection, noBounds
        case failed(SettingsFailure)
    }

    /// Points per unit, by rulerType code (UnitSettings.units).
    private static var unitTable: String { "[" + UnitSettings.units.map { String($0.points) }.joined(separator: ",") + "]" }

    /// Reads the ruler unit and measures the selection, then runs `body` with left / top / right / bottom and `margin` (points).
    private static func script(margin: Double, previewBounds: Bool, body: String) -> String {
        """
        (function () { try {
        var rulerType = app.preferences.getIntegerPreference("rulerType"), units = \(unitTable);
        if (app.documents.length === 0) return "NODOC";
        var doc = app.activeDocument, sel = doc.selection;
        if (!sel || sel.typename || sel.length === 0) return "NOSEL";
        var left = Infinity, top = -Infinity, right = -Infinity, bottom = Infinity, measured = false;
        for (var i = 0; i < sel.length; i++) { try { var b = sel[i].\(previewBounds ? "visibleBounds" : "geometricBounds");
            if (b[0] < left) left = b[0]; if (b[1] > top) top = b[1]; if (b[2] > right) right = b[2]; if (b[3] < bottom) bottom = b[3]; measured = true; } catch (e) {} }
        if (!measured) return "NOBOUNDS";
        var margin = (\(margin)) * (units[rulerType] || 1);
        \(body)
        app.redraw();
        return "OK\\n" + rulerType;
        } catch (e) { return "ERR:" + e; } })()
        """
    }

    /// One step in the direction: the selection's width or height plus the margin (workerApply). `none` duplicates in place.
    /// A copy that was made stays in the new selection even if its move fails.
    static func moveScript(_ direction: Direction, margin: Double, previewBounds: Bool, duplicate: Bool) -> String {
        let offset: String
        switch direction {
        case .up: offset = "dx = 0, dy = (top - bottom) + margin"
        case .down: offset = "dx = 0, dy = -((top - bottom) + margin)"
        case .left: offset = "dx = -((right - left) + margin), dy = 0"
        case .right: offset = "dx = (right - left) + margin, dy = 0"
        case .none: offset = "dx = 0, dy = 0"
        }
        return script(margin: margin, previewBounds: previewBounds, body: """
        var \(offset), targets = [];
        for (var i = 0; i < sel.length; i++) { try { var t = \(duplicate ? "sel[i].duplicate()" : "sel[i]"); targets.push(t); t.translate(dx, dy); } catch (e) {} }
        \(duplicate ? "if (targets.length > 0) { try { doc.selection = targets; } catch (e) {} }" : "")
        """)
    }

    /// One matrix about the anchor point, then the margin away from the center (btTransformSelection).
    /// `matrix` sets the values from anchorX / anchorY.
    private static func transformScript(_ matrix: String, anchor: Int, margin: Double, previewBounds: Bool, duplicate: Bool) -> String {
        let column = anchor % 3, row = anchor / 3
        let anchorX = ["left", "((left + right) / 2)", "right"][column]
        let anchorY = ["top", "((top + bottom) / 2)", "bottom"][row]
        let marginX = [-1, 0, 1][column], marginY = [1, 0, -1][row]
        return script(margin: margin, previewBounds: previewBounds, body: """
        var anchorX = \(anchorX), anchorY = \(anchorY), m = app.getIdentityMatrix();
        \(matrix)
        var targets = [];
        for (var i = 0; i < sel.length; i++) { try { targets.push(\(duplicate ? "sel[i].duplicate()" : "sel[i]")); } catch (e) {} }
        for (var i = 0; i < targets.length; i++) { try { targets[i].transform(m, true, true, true, true, 1, Transformation.DOCUMENTORIGIN); } catch (e) {} }
        var mx = \(marginX) * margin, my = \(marginY) * margin;
        if (mx !== 0 || my !== 0) { for (var i = 0; i < targets.length; i++) { try { targets[i].translate(mx, my); } catch (e) {} } }
        \(duplicate ? "try { doc.selection = targets; } catch (e) {}" : "")
        """)
    }

    /// Numbers written into the script (parenthesized, so a negative never makes "--"; 6e-17 at 90° becomes 0).
    private static func number(_ value: Double) -> String { "(" + String(abs(value) < 1e-12 ? 0 : value) + ")" }

    static func flipScript(horizontal: Bool, anchor: Int, margin: Double, previewBounds: Bool, duplicate: Bool) -> String {
        let a = horizontal ? -1.0 : 1, d = horizontal ? 1.0 : -1
        return transformScript("m.mValueA = \(number(a)); m.mValueD = \(number(d)); m.mValueTX = anchorX * \(number(1 - a)); m.mValueTY = anchorY * \(number(1 - d));",
                               anchor: anchor, margin: margin, previewBounds: previewBounds, duplicate: duplicate)
    }

    /// Positive degrees turn counterclockwise.
    static func rotateScript(degrees: Double, anchor: Int, margin: Double, previewBounds: Bool, duplicate: Bool) -> String {
        let radians = degrees * .pi / 180, c = cos(radians), s = sin(radians)
        return transformScript("""
            m.mValueA = \(number(c)); m.mValueB = \(number(s)); m.mValueC = \(number(-s)); m.mValueD = \(number(c));
            m.mValueTX = anchorX * \(number(1 - c)) + anchorY * \(number(s)); m.mValueTY = anchorY * \(number(1 - c)) - anchorX * \(number(s));
            """, anchor: anchor, margin: margin, previewBounds: previewBounds, duplicate: duplicate)
    }

    static let readRulerScript = "String(app.preferences.getIntegerPreference(\"rulerType\"))"

    static func parse(_ text: String) -> Outcome {
        let lines = text.split(separator: "\n").map(String.init)
        switch lines.first {
        case "OK": return .done(rulerType: lines.count > 1 ? Int(lines[1]) ?? 2 : 2)
        case "NODOC": return .noDocument
        case "NOSEL": return .noSelection
        case "NOBOUNDS": return .noBounds
        default: return .failed(.failed(text))
        }
    }

    static func run(_ source: String) -> Outcome {
        guard let app = runningIllustrator() else { return .failed(.notRunning) }
        switch evaluate(source, in: app) {
        case .success(let text): return parse(text)
        case .failure(let failure): return .failed(failure)
        }
    }
}

/// The palette's settings and the queue its operations run on.
@MainActor
final class QuickTransformState: ObservableObject {
    private let defaults = UserDefaults.standard
    private let model: Model
    /// 0...8, row-major (0 top left, 4 center, 8 bottom right).
    @Published var anchor: Int { didSet { defaults.set(anchor, forKey: "transformAnchor") } }
    @Published var marginText: String { didSet { defaults.set(marginText, forKey: "transformMargin") } }
    @Published var previewBounds: Bool { didSet { defaults.set(previewBounds, forKey: "transformPreviewBounds") } }
    @Published var rulerType: Int?
    @Published var message: String?
    private let queue = DispatchQueue(label: "VectorMate.transform")

    init(model: Model) {
        self.model = model
        anchor = (defaults.object(forKey: "transformAnchor") as? Int).flatMap { (0...8).contains($0) ? $0 : nil } ?? 4
        marginText = defaults.string(forKey: "transformMargin") ?? "0"
        previewBounds = defaults.object(forKey: "transformPreviewBounds") as? Bool ?? true
    }

    var unitLabel: String { UnitSettings.label(code: rulerType ?? 2, popup: 0) }
    /// As parseFloat in the script: the leading number, 0 when there is none. Negative values overlap.
    var margin: Double {
        let text = marginText.trimmingCharacters(in: .whitespaces)
        if let value = Double(text) { return value }
        let prefix = text.prefix { "0123456789.-+".contains($0) }
        return Double(prefix) ?? 0
    }

    func readRuler() {
        queue.async {
            guard let app = runningIllustrator(), case .success(let text) = evaluate(QuickTransform.readRulerScript, in: app), let code = Int(text) else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self.rulerType = code } }
        }
    }

    /// Runs the script made from the current settings; clicks made meanwhile wait their turn.
    func perform(_ make: (_ margin: Double, _ previewBounds: Bool, _ anchor: Int) -> String, completion: (() -> Void)? = nil) {
        let source = make(margin, previewBounds, anchor)
        queue.async {
            let outcome = QuickTransform.run(source)
            DispatchQueue.main.async { MainActor.assumeIsolated { self.report(outcome); completion?() } }
        }
    }

    private func report(_ outcome: QuickTransform.Outcome) {
        switch outcome {
        case .done(let code): rulerType = code; message = nil
        case .noDocument: message = L("fail.noDocument")
        case .noSelection: message = L("transform.noSelection")
        case .noBounds: message = L("transform.noBounds")
        case .failed(let failure):
            if failure == .automationDenied { model.automationDenied = true }
            message = model.failureText(failure)
            if failure != .notRunning { NSSound.beep() }
        }
    }

    func move(_ direction: QuickTransform.Direction) {
        let duplicate = NSEvent.modifierFlags.contains(.option)
        perform { margin, bounds, _ in QuickTransform.moveScript(direction, margin: margin, previewBounds: bounds, duplicate: duplicate) }
    }
    func duplicateInPlace() {
        perform { _, _, _ in QuickTransform.moveScript(.none, margin: 0, previewBounds: false, duplicate: true) }
    }
    func flip(horizontal: Bool) {
        let duplicate = NSEvent.modifierFlags.contains(.option)
        perform { QuickTransform.flipScript(horizontal: horizontal, anchor: $2, margin: $0, previewBounds: $1, duplicate: duplicate) }
    }
    func rotate(_ degrees: Double, duplicate: Bool, completion: (() -> Void)? = nil) {
        perform({ QuickTransform.rotateScript(degrees: degrees, anchor: $2, margin: $0, previewBounds: $1, duplicate: duplicate) }, completion: completion)
    }

    // MARK: Slider

    /// The snapped angle shown next to the slider.
    @Published var sliderAngle = 0
    @Published var sliderValue = 0.0
    /// What has been applied since the drag began; only the difference is rotated, one call at a time.
    private var appliedAngle = 0
    private var rotating = false
    private var released = false

    /// 15° steps, 90° with Shift (-180...180).
    func slide(to value: Double) {
        sliderValue = value
        let step = NSEvent.modifierFlags.contains(.shift) ? 90.0 : 15
        sliderAngle = Int(max(-180, min(180, (value / step).rounded() * step)))
        released = false
        pumpSlider()
    }
    func sliderEditingChanged(_ editing: Bool) {
        guard !editing else { return }
        released = true
        pumpSlider()
    }
    private func pumpSlider() {
        guard !rotating else { return }
        if sliderAngle != appliedAngle {
            let target = sliderAngle
            rotating = true
            rotate(Double(target - appliedAngle), duplicate: false) { [weak self] in
                guard let self else { return }
                self.appliedAngle = target
                self.rotating = false
                self.pumpSlider()
            }
        } else if released {
            // The object keeps its rotation; the slider and the readout go back to 0.
            released = false
            appliedAngle = 0; sliderAngle = 0; sliderValue = 0
        }
    }
}

/// The floating クイック変形 palette. It does not activate VectorMate, so Illustrator stays in front; it becomes key
/// only for the margin field.
final class QuickTransformWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { performClose(nil) }
}

@MainActor
final class QuickTransformPalette: NSObject, NSWindowDelegate {
    private let state: QuickTransformState
    private var window: QuickTransformWindow?
    init(model: Model) { state = QuickTransformState(model: model) }
    private lazy var visibility = IllustratorPaletteVisibility { [weak self] in self?.window }
    var isVisible: Bool { window?.isVisible == true }

    func show() {
        _ = visibility
        if window == nil {
            let panel = QuickTransformWindow(contentRect: NSRect(x: 0, y: 0, width: 240, height: 480),
                                             styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = L("transform.title")
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior.insert(.fullScreenAuxiliary)
            panel.delegate = self
            let hosting = NSHostingView(rootView: QuickTransformView(state: state))
            // The window follows the content's height (a message line comes and goes), with no blank above or below.
            hosting.sizingOptions = [.minSize, .maxSize]
            panel.contentView = hosting
            panel.center()
            panel.setFrameAutosaveName("VectorMateQuickTransform")
            panel.setContentSize(hosting.fittingSize)
            window = panel
        }
        state.readRuler()
        if let window, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        window?.orderFrontRegardless()
    }
    func toggle() { isVisible ? window?.performClose(nil) : show() }
    func windowDidBecomeKey(_ notification: Notification) { state.readRuler() }
}

// MARK: - Views

struct QuickTransformView: View {
    @ObservedObject var state: QuickTransformState
    @FocusState private var editing: Bool
    @State private var arrowMonitor: Any?
    static let iconSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(L("transform.flip")) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        VStack(spacing: 7) {
                            HStack(spacing: 7) {
                                IconButton(glyph: .flipHorizontal, tip: L("transform.flipHTip")) { state.flip(horizontal: true) }
                                IconButton(glyph: .flipVertical, tip: L("transform.flipVTip")) { state.flip(horizontal: false) }
                            }
                            HStack(spacing: 7) {
                                IconButton(glyph: .rotateCCW, tip: L("transform.rotateCCWTip")) { state.rotate(90, duplicate: NSEvent.modifierFlags.contains(.option)) }
                                IconButton(glyph: .rotateCW, tip: L("transform.rotateCWTip")) { state.rotate(-90, duplicate: NSEvent.modifierFlags.contains(.option)) }
                            }
                        }
                        AnchorPicker(index: $state.anchor).help(L("transform.anchorTip"))
                    }
                    HStack(spacing: 6) {
                        Text("\(state.sliderAngle)°").monospacedDigit().frame(width: 40, alignment: .trailing)
                        Slider(value: Binding(get: { state.sliderValue }, set: { state.slide(to: $0) }), in: -180...180,
                               onEditingChanged: { state.sliderEditingChanged($0) })
                            .controlSize(.small)
                    }
                    .help(L("transform.sliderTip"))
                }
                .frame(maxWidth: .infinity).padding(6)
            }
            GroupBox(L("transform.move")) {
                VStack(spacing: 2) {
                    IconButton(glyph: .arrow(.up), tip: L("transform.up") + "  —  " + L("transform.moveTip")) { state.move(.up) }
                    HStack(spacing: 2) {
                        IconButton(glyph: .arrow(.left), tip: L("transform.left") + "  —  " + L("transform.moveTip")) { state.move(.left) }
                        IconButton(glyph: .duplicate, tip: L("transform.duplicateTip")) { state.duplicateInPlace() }
                        IconButton(glyph: .arrow(.right), tip: L("transform.right") + "  —  " + L("transform.moveTip")) { state.move(.right) }
                    }
                    IconButton(glyph: .arrow(.down), tip: L("transform.down") + "  —  " + L("transform.moveTip")) { state.move(.down) }
                }
                .frame(maxWidth: .infinity).padding(6)
            }
            GroupBox(L("transform.options")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text(L("transform.margin"))
                        VStack(spacing: 0) {
                            Button { step(1) } label: { Image(systemName: "chevron.up").font(.system(size: 8, weight: .semibold)).frame(width: 16, height: 9) }
                            Button { step(-1) } label: { Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).frame(width: 16, height: 9) }
                        }
                        .buttonStyle(.borderless)
                        .help(L("quick.stepTip"))
                        TextField("", text: $state.marginText)
                            .frame(width: 56)
                            .multilineTextAlignment(.trailing)
                            .focused($editing)
                            .onSubmit { normalize() }
                        Text(state.unitLabel)
                    }
                    .help(L("transform.marginTip"))
                    Toggle(L("transform.previewBounds"), isOn: $state.previewBounds).help(L("transform.previewBoundsTip"))
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            if let message = state.message { Note(text: message) }
        }
        .padding(16)
        .frame(width: 240)
        .background(Color(nsColor: AppSurface.color))
        .onAppear {
            // ↑↓ in the field step the value (macOS 13 has no onKeyPress).
            arrowMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard editing, event.keyCode == 126 || event.keyCode == 125 else { return event }
                step(event.keyCode == 126 ? 1 : -1)
                return nil
            }
        }
        .onDisappear { if let arrowMonitor { NSEvent.removeMonitor(arrowMonitor) }; arrowMonitor = nil }
        .onChange(of: editing) { focused in if !focused { normalize() } }
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", (value * 1000).rounded() / 1000)
    }
    private func normalize() { state.marginText = format(state.margin) }
    /// ∧∨ and ↑↓: to the next whole number; ⇧ to the next multiple of 10; ⌥ by 0.1 (negative values allowed).
    private func step(_ direction: Double) {
        let current = state.margin
        let flags = NSEvent.modifierFlags
        let next: Double
        if flags.contains(.option) { next = ((current + 0.1 * direction) * 10).rounded() / 10 }
        else if flags.contains(.shift) { next = direction > 0 ? (floor(current / 10) + 1) * 10 : (ceil(current / 10) - 1) * 10 }
        else { next = direction > 0 ? floor(current) + 1 : ceil(current) - 1 }
        state.marginText = format(next)
    }
}

/// The line art of QuickTransformPalette.jsx, drawn in a 30 × 30 box.
enum TransformGlyph: Equatable {
    enum Arrow: Equatable { case up, down, left, right }
    case flipHorizontal, flipVertical, rotateCCW, rotateCW, duplicate
    case arrow(Arrow)

    func draw(_ context: GraphicsContext, size: CGSize, color: Color) {
        let w = size.width, h = size.height, cx = w / 2, cy = h / 2
        let line = StrokeStyle(lineWidth: 1)
        switch self {
        case .flipHorizontal, .flipVertical:
            let vertical = self == .flipVertical
            var axis = Path()
            if vertical { axis.move(to: CGPoint(x: 5, y: cy)); axis.addLine(to: CGPoint(x: w - 5, y: cy)) }
            else { axis.move(to: CGPoint(x: cx, y: 5)); axis.addLine(to: CGPoint(x: cx, y: h - 5)) }
            context.stroke(axis, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [1.5, 1.5]))
            let filled = vertical ? [CGPoint(x: cx - 5, y: 4), CGPoint(x: cx + 5, y: 4), CGPoint(x: cx, y: cy - 2)]
                                  : [CGPoint(x: 4, y: cy - 5), CGPoint(x: 4, y: cy + 5), CGPoint(x: cx - 2, y: cy)]
            let outlined = vertical ? [CGPoint(x: cx - 5, y: h - 4), CGPoint(x: cx + 5, y: h - 4), CGPoint(x: cx, y: cy + 2)]
                                    : [CGPoint(x: w - 4, y: cy - 5), CGPoint(x: w - 4, y: cy + 5), CGPoint(x: cx + 2, y: cy)]
            context.fill(Self.polygon(filled), with: .color(color))
            context.stroke(Self.polygon(outlined), with: .color(color), style: line)
        case .rotateCCW, .rotateCW:
            let mirror: CGFloat = self == .rotateCW ? -1 : 1
            let centerY = cy + 1, radius: CGFloat = 7.5, headDeg: CGFloat = 232
            func point(_ deg: CGFloat) -> CGPoint {
                let rad = deg * .pi / 180
                return CGPoint(x: cx + mirror * radius * cos(rad), y: centerY + radius * sin(rad))
            }
            var arc = Path()
            let segments = 36
            for i in 0...segments {
                let p = point(headDeg + (410 - headDeg) * CGFloat(i) / CGFloat(segments))
                i == 0 ? arc.move(to: p) : arc.addLine(to: p)
            }
            context.stroke(arc, with: .color(color), style: line)
            // Square dots on the lower side.
            var dots = Path()
            for deg in stride(from: CGFloat(50), through: 150, by: 13) {
                let rad = deg * .pi / 180, p = point(deg)
                let tx = mirror * sin(rad) * 0.9, ty = -cos(rad) * 0.9
                dots.move(to: CGPoint(x: p.x - tx, y: p.y - ty)); dots.addLine(to: CGPoint(x: p.x + tx, y: p.y + ty))
            }
            context.stroke(dots, with: .color(color), style: line)
            let rad = headDeg * .pi / 180
            let hx = cx + radius * cos(rad), hy = centerY + radius * sin(rad)
            let tx = sin(rad), ty = -cos(rad), px = -ty, py = tx
            var head = [CGPoint(x: hx + tx * 4, y: hy + ty * 4),
                        CGPoint(x: hx - tx * 2 + px * 4.5, y: hy - ty * 2 + py * 4.5),
                        CGPoint(x: hx - tx * 2 - px * 4.5, y: hy - ty * 2 - py * 4.5)]
            if mirror < 0 { head = head.map { CGPoint(x: 2 * cx - $0.x, y: $0.y) } }
            context.fill(Self.polygon(head), with: .color(color))
        case .duplicate:
            let square = min(w, h) * 0.40, shift = square * 0.36, pair = square + shift
            let left = ((w - pair) / 2).rounded(), top = ((h - pair) / 2).rounded()
            let back = CGRect(x: left + shift + 0.5, y: top + 0.5, width: square, height: square)
            let front = CGRect(x: left + 0.5, y: top + shift + 0.5, width: square, height: square)
            // The back square is hidden behind the front one.
            var hidden = context
            var clip = Path(CGRect(origin: .zero, size: size)); clip.addRect(front)
            hidden.clip(to: clip, style: FillStyle(eoFill: true))
            hidden.stroke(Path(back), with: .color(color), style: line)
            context.stroke(Path(front), with: .color(color), style: line)
        case .arrow(let direction):
            let size = min(w, h), tip = size * 0.32, shaft = size * 0.11, headHalf = size * 0.27, headBase = tip - size * 0.34
            let base: [(CGFloat, CGFloat)] = [(-tip, -shaft), (headBase, -shaft), (headBase, -headHalf), (tip, 0), (headBase, headHalf), (headBase, shaft), (-tip, shaft)]
            let points = base.map { x, y -> CGPoint in
                let p: (CGFloat, CGFloat)
                switch direction {
                case .left: p = (-x, y)
                case .down: p = (-y, x)
                case .up: p = (y, -x)
                case .right: p = (x, y)
                }
                return CGPoint(x: cx + p.0, y: cy + p.1)
            }
            context.stroke(Self.polygon(points), with: .color(color), style: line)
        }
    }

    static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

/// A square icon button with a 1 px frame; the background darkens on hover and while pressed.
struct IconButton: View {
    let glyph: TransformGlyph
    let tip: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Canvas { context, size in glyph.draw(context, size: size, color: .primary.opacity(0.8)) }
                .frame(width: QuickTransformView.iconSize, height: QuickTransformView.iconSize)
        }
        .buttonStyle(IconButtonStyle(hover: hover))
        .onHover { hover = $0 }
        .help(tip)
    }
}

struct IconButtonStyle: ButtonStyle {
    let hover: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : hover ? 0.08 : 0))
            .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// 基準点: the 3 × 3 picker of the ai-scripts anchor widget (outer squares joined by rules, the center alone).
struct AnchorPicker: View {
    @Binding var index: Int
    static let size: CGFloat = 66, cell: CGFloat = 9, gap: CGFloat = 7.5
    static let connections = [(0, 1), (1, 2), (6, 7), (7, 8), (0, 3), (3, 6), (2, 5), (5, 8)]

    var body: some View {
        Canvas { context, size in
            let step = Self.cell + Self.gap, grid = Self.cell * 3 + Self.gap * 2
            let originX = ((size.width - grid) / 2).rounded() + 0.5, originY = ((size.height - grid) / 2).rounded() + 0.5
            let cells = (0..<9).map { CGRect(x: originX + CGFloat($0 % 3) * step, y: originY + CGFloat($0 / 3) * step, width: Self.cell, height: Self.cell) }
            let lineColor = Color.primary.opacity(0.6)
            var rules = Path()
            for (a, b) in Self.connections {
                if b - a == 1 { rules.move(to: CGPoint(x: cells[a].maxX, y: cells[a].midY)); rules.addLine(to: CGPoint(x: cells[b].minX, y: cells[b].midY)) }
                else { rules.move(to: CGPoint(x: cells[a].midX, y: cells[a].maxY)); rules.addLine(to: CGPoint(x: cells[b].midX, y: cells[b].minY)) }
            }
            context.stroke(rules, with: .color(lineColor), lineWidth: 1)
            for (i, rect) in cells.enumerated() {
                if i == index { context.fill(Path(rect), with: .color(.primary.opacity(0.75))) }
                context.stroke(Path(rect), with: .color(lineColor), lineWidth: 1)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
            let column = min(2, max(0, Int(value.location.x / (Self.size / 3))))
            let row = min(2, max(0, Int(value.location.y / (Self.size / 3))))
            index = row * 3 + column
        })
        .accessibilityElement()
        .accessibilityLabel(L("transform.anchorTip"))
    }
}
