import AppKit
import SwiftUI

/// クイック環境設定 (AiQuickPrefsPalette.jsx): the preferences that take effect when written from JavaScript, as the
/// script writes them. The ruler unit is the exception: it only takes effect through the 単位 pane, as in 単位パレット.
enum QuickPrefs {
    struct State: Equatable {
        var cursorKeyLength: Double      // points
        var rulerType: Int
        var previewBounds: Bool
        var glyphBounds: Bool            // point type and area type together
        var transformPatterns: Bool
        var scaleCorners: Bool           // policyForPreservingCorners 1 = on, 2 = off
        var scaleStroke: Bool
        var realtimeDrawing: Bool
        var pastePlain: Bool
        var pastePreserve: Bool
    }
    enum Item: String, CaseIterable {
        case previewBounds = "includeStrokeInBounds"
        case transformPatterns = "transformPatterns"
        case scaleCorners = "policyForPreservingCorners"
        case scaleStroke = "scaleLineWeight"
        case realtimeDrawing = "LiveEdit_State_Machine"
        case pastePlain = "plugin/FileClipboard/pasteWithoutFormatting"
        case pastePreserve = "layers/pastePreserve"
        case glyphBounds = "EnableActualPointTextSpaceAlign"
        var labelKey: String { "quick." + String(describing: self) }
    }
    /// The units the 一般 popup offers in the palette (AiQuickPrefsPalette.jsx UNIT_POPUP_CODES: in, mm, pt, pica, cm, H, px).
    static let unitCodes = [0, 1, 2, 3, 4, 5, 6]

    static let readScript = """
    (function () { var p = app.preferences; return [
    p.getRealPreference("cursorKeyLength"), p.getIntegerPreference("rulerType"),
    p.getBooleanPreference("includeStrokeInBounds"), p.getBooleanPreference("EnableActualPointTextSpaceAlign"),
    p.getBooleanPreference("transformPatterns"), p.getIntegerPreference("policyForPreservingCorners"),
    p.getBooleanPreference("scaleLineWeight"), p.getBooleanPreference("LiveEdit_State_Machine"),
    p.getBooleanPreference("plugin/FileClipboard/pasteWithoutFormatting"), p.getBooleanPreference("layers/pastePreserve")
    ].join("\\n"); })()
    """
    static func parse(_ text: String) -> State? {
        let v = text.split(separator: "\n").map(String.init)
        guard v.count == 10, let length = Double(v[0]), let ruler = Int(v[1]), let corners = Int(v[5]) else { return nil }
        return State(cursorKeyLength: length, rulerType: ruler, previewBounds: v[2] == "true", glyphBounds: v[3] == "true",
                     transformPatterns: v[4] == "true", scaleCorners: corners == 1, scaleStroke: v[6] == "true",
                     realtimeDrawing: v[7] == "true", pastePlain: v[8] == "true", pastePreserve: v[9] == "true")
    }
    static func read() -> Result<State, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        return evaluate(readScript, in: app).flatMap { text in parse(text).map { .success($0) } ?? .failure(.failed(text)) }
    }
    private static func write(_ statements: String) -> Result<State, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        if case .failure(let failure) = evaluate("(function () { var p = app.preferences; " + statements + " return \"\"; })()", in: app) { return .failure(failure) }
        return read()
    }
    static func set(_ items: [Item], _ value: Bool) -> Result<State, SettingsFailure> {
        write(items.map { item -> String in
            switch item {
            case .scaleCorners: return "p.setIntegerPreference(\"\(item.rawValue)\", \(value ? 1 : 2));"
            // 字形の境界に整列 switches point type and area type together, as the script does.
            case .glyphBounds: return "p.setBooleanPreference(\"EnableActualPointTextSpaceAlign\", \(value)); p.setBooleanPreference(\"EnableActualAreaTextSpaceAlign\", \(value));"
            default: return "p.setBooleanPreference(\"\(item.rawValue)\", \(value));"
            }
        }.joined(separator: " "))
    }
    static func setCursorKeyLength(points: Double) -> Result<State, SettingsFailure> {
        write("p.setRealPreference(\"cursorKeyLength\", \(max(0, points)));")
    }
    /// プレビュー更新: View using GPU twice redraws the GPU preview.
    static func refreshPreview() -> Result<State, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        if case .failure(let failure) = evaluate("try { app.executeMenuCommand(\"View using GPU\"); app.executeMenuCommand(\"View using GPU\"); } catch (e) {} \"\"", in: app) {
            return .failure(failure)
        }
        return read()
    }
    /// The ruler unit through the 単位 pane (only 一般 changes).
    static func setRulerUnit(_ code: Int) -> Result<State, SettingsFailure> {
        switch UnitSettings.applyUnits([code, nil, nil, nil]) {
        case .success: return read()
        case .failure(let failure): return .failure(failure)
        }
    }
}

/// The floating クイック環境設定 palette.
final class QuickPrefsWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { performClose(nil) }
}

@MainActor
final class QuickPrefsPalette: NSObject, NSWindowDelegate {
    private let model: Model
    private var window: QuickPrefsWindow?
    init(model: Model) { self.model = model }
    private lazy var visibility = IllustratorPaletteVisibility { [weak self] in self?.window }
    var isVisible: Bool { window?.isVisible == true }

    func show() {
        _ = visibility
        if window == nil {
            let panel = QuickPrefsWindow(contentRect: NSRect(x: 0, y: 0, width: 280, height: 480),
                                         styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = L("quick.title")
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior.insert(.fullScreenAuxiliary)
            panel.delegate = self
            let hosting = NSHostingView(rootView: QuickPrefsView(model: model))
            hosting.sizingOptions = [.preferredContentSize]
            panel.contentView = hosting
            panel.center()
            panel.setFrameAutosaveName("VectorMateQuickPrefs")
            window = panel
        }
        model.refreshQuickPrefs()
        if let window, !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    func toggle() { isVisible ? window?.performClose(nil) : show() }
    /// Follows changes made in Illustrator (its Settings dialog box and so on) when the palette comes forward, as the script does on activate.
    func windowDidBecomeKey(_ notification: Notification) { model.refreshQuickPrefs() }
}

struct QuickPrefsView: View {
    @ObservedObject var model: Model
    @State private var keyText = ""
    @FocusState private var editing: Bool
    @State private var arrowMonitor: Any?

    private var state: QuickPrefs.State? { model.quickPrefs }
    private var unitPoints: Double {
        let code = state?.rulerType ?? 2
        return UnitSettings.units.indices.contains(code) ? UnitSettings.units[code].points : 1
    }
    private func displayed(_ state: QuickPrefs.State?) -> String {
        guard let state else { return "" }
        return String(format: "%.1f", state.cursorKeyLength / unitPoints)
    }
    private func commit(_ value: Double) {
        guard value >= 0 else { keyText = displayed(state); return }
        keyText = String(format: "%.1f", value)
        model.setQuickKeyLength(points: value * unitPoints)
    }
    /// ∧∨ and ↑↓: to the next whole number; ⇧ to the next multiple of 10; ⌥ by 0.1 (AiQuickPrefsPalette.jsx).
    private func step(_ direction: Double) {
        let current = Double(keyText) ?? 0
        let flags = NSEvent.modifierFlags
        let next: Double
        if flags.contains(.option) { next = ((current + 0.1 * direction) * 10).rounded() / 10 }
        else if flags.contains(.shift) { next = direction > 0 ? (floor(current / 10) + 1) * 10 : (ceil(current / 10) - 1) * 10 }
        else { next = direction > 0 ? floor(current) + 1 : ceil(current) - 1 }
        commit(max(0, next))
    }
    private func toggle(_ item: QuickPrefs.Item, _ value: KeyPath<QuickPrefs.State, Bool>, group: [QuickPrefs.Item]? = nil) -> some View {
        Toggle(L(item.labelKey), isOn: Binding(get: { state?[keyPath: value] ?? false }, set: { on in
            // ⌥-click switches every item of the group (変形オプション) together, as the script does.
            let items = (group != nil && NSEvent.modifierFlags.contains(.option)) ? group! : [item]
            model.setQuick(items, on)
        }))
        .help(L(item.labelKey + "Tip"))
    }

    var body: some View {
        let transformGroup: [QuickPrefs.Item] = [.transformPatterns, .scaleCorners, .scaleStroke]
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(L("quick.keyInput")) {
                HStack(spacing: 6) {
                    VStack(spacing: 0) {
                        Button { step(1) } label: { Image(systemName: "chevron.up").font(.system(size: 8, weight: .semibold)).frame(width: 16, height: 9) }
                        Button { step(-1) } label: { Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).frame(width: 16, height: 9) }
                    }
                    .buttonStyle(.borderless)
                    .help(L("quick.stepTip"))
                    TextField("", text: $keyText)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .focused($editing)
                        .onSubmit { commit(Double(keyText) ?? -1) }
                        .help(L("quick.keyInputTip"))
                    Picker("", selection: Binding(get: { state?.rulerType ?? 2 }, set: { model.setQuickRulerUnit($0) })) {
                        ForEach(QuickPrefs.unitCodes, id: \.self) { code in Text(UnitSettings.label(code: code, popup: 0)).tag(code) }
                    }
                    .labelsHidden().frame(width: 72)
                    .help(L("quick.unitTip"))
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            GroupBox(L("quick.align")) {
                VStack(alignment: .leading, spacing: 6) {
                    toggle(.previewBounds, \.previewBounds)
                    toggle(.glyphBounds, \.glyphBounds)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            GroupBox(L("quick.transform")) {
                VStack(alignment: .leading, spacing: 6) {
                    toggle(.transformPatterns, \.transformPatterns, group: transformGroup)
                    toggle(.scaleCorners, \.scaleCorners, group: transformGroup)
                    toggle(.scaleStroke, \.scaleStroke, group: transformGroup)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            GroupBox(L("quick.copyPaste")) {
                VStack(alignment: .leading, spacing: 6) {
                    toggle(.pastePlain, \.pastePlain)
                    toggle(.pastePreserve, \.pastePreserve)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            GroupBox(L("quick.drawing")) {
                VStack(alignment: .leading, spacing: 6) {
                    toggle(.realtimeDrawing, \.realtimeDrawing)
                    Button(L("quick.refresh")) { model.refreshQuickPreview() }.help(L("quick.refreshTip"))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            if state == nil { Note(text: model.notRunningText) }
            else if let result = model.quickResult, result.isError { Note(text: result.text) }
        }
        .disabled(model.busy || state == nil)
        .padding(16)
        .frame(width: 280)
        .background(Color(nsColor: AppSurface.color))
        .onAppear {
            keyText = displayed(state)
            // ↑↓ in the field step the value (macOS 13 has no onKeyPress).
            arrowMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard editing, event.keyCode == 126 || event.keyCode == 125 else { return event }
                step(event.keyCode == 126 ? 1 : -1)
                return nil
            }
        }
        .onDisappear { if let arrowMonitor { NSEvent.removeMonitor(arrowMonitor) }; arrowMonitor = nil }
        .onChange(of: model.quickPrefs) { new in if !editing { keyText = displayed(new) } }
    }
}
