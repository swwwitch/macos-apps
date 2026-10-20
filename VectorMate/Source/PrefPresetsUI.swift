import AppKit
import SwiftUI

extension PrefPresets {
    static func read(_ app: NSRunningApplication) -> Result<PrefValues, SettingsFailure> {
        evaluate(readScript, in: app).flatMap { text in parse(text).map { .success($0) } ?? .failure(.failed(text)) }
    }
    /// Blocking: call off the main thread.
    static func read() -> Result<PrefValues, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        return read(app)
    }
    struct Applied {
        var values: PrefValues
        /// The File Handling checkboxes after applying; nil when unknown (the dialog box could not be operated).
        var files: FileHandling.State?
        /// ガイドをロック after applying; nil when unknown (no document).
        var guideLock: Bool?
        /// Label keys of the items not set because no document is open.
        var skipped: [String] = []
        /// The first dialog-box item that failed.
        var problem: SettingsFailure?
        var ignoring: [WritableKeyPath<PrefValues, Bool>] { PrefValues.unknownPaths(files: files, guideLock: guideLock) }
    }

    /// Blocking: writes the JavaScript values, sets brightness, File Handling, ガイドをロック and the Shape Builder color only
    /// where they differ, then reads everything back. `confirmedFiles`: the checkboxes as read in the dialog box or set by
    /// VectorMate in this session; nil (or values read from the preference files, which can be stale) opens the dialog box.
    static func apply(_ values: PrefValues, confirmedFiles: FileHandling.State?) -> Result<Applied, SettingsFailure> {
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        let written = evaluate(writeScript(values), in: app).flatMap { text in parse(text).map { .success($0) } ?? .failure(.failed(text)) }
        guard case .success(let before) = written else { return written.map { Applied(values: $0) } }
        var applied = Applied(values: before, files: confirmedFiles)
        func failed(_ failure: SettingsFailure) { applied.problem = applied.problem ?? failure }
        if before.uiBrightness != values.uiBrightness, case .failure(let failure) = UIBrightness.change(level: values.uiBrightness) { failed(failure) }
        let wanted = values.fileHandling
        if confirmedFiles != wanted {
            switch FileHandling.apply(wanted) {
            case .success: applied.files = wanted
            case .failure(let failure): failed(failure)
            }
        }
        // ガイドをロック and the Shape Builder color need a document: without one, a new document is made for them
        // and closed again without saving.
        let lockBefore = GuideLock.read(app)
        let needsDocument = (lockBefore != nil && lockBefore != values.lockGuides) || before.shapeSwatches != values.shapeSwatches
        let temporary = needsDocument ? TemporaryDocument.open(in: app) : nil
        defer { temporary.map { TemporaryDocument.close($0, in: app) } }
        switch GuideLock.set(values.lockGuides, in: app) {
        case .success: break
        case .failure(.noDocument): applied.skipped.append("prefsets.lockGuides")
        case .failure(let failure): failed(failure)
        }
        if before.shapeSwatches != values.shapeSwatches {
            // Setting it selects the Shape Builder tool: the tool in use is selected again afterwards.
            let tool = try? evaluate("String(app.getSelectedToolName())", in: app).get()
            switch ShapeBuilderColor.set(values.shapeSwatches ? .swatches : .artwork) {
            case .success:
                if let tool, !tool.isEmpty { _ = evaluate("app.selectTool(\(MetricsScript.jsString(tool))); \"\"", in: app) }
            case .failure(.noDocument): applied.skipped.append("prefsets.shapeColorName")
            case .failure(let failure): failed(failure)
            }
        }
        if case .success(let after) = read(app) { applied.values = after }
        applied.guideLock = GuideLock.read(app)
        applied.values = applied.values.overlaid(files: applied.files, guideLock: applied.guideLock)
        return .success(applied)
    }
}

/// A document made only so that document-only settings can be changed, closed without saving afterwards.
enum TemporaryDocument {
    /// The new document's name, or nil when a document is already open (or it could not be made).
    static func open(in app: NSRunningApplication) -> String? {
        guard case .success(let text) = evaluate("app.documents.length > 0 ? \"\" : String(app.documents.add().name)", in: app), !text.isEmpty else { return nil }
        return text
    }
    static func close(_ name: String, in app: NSRunningApplication) {
        _ = evaluate("try { app.documents.getByName(\(MetricsScript.jsString(name))).close(SaveOptions.DONOTSAVECHANGES); } catch (e) {} \"\"", in: app)
    }
}

extension PrefValues {
    /// The values JavaScript cannot read, as far as they are known.
    func overlaid(files: FileHandling.State?, guideLock: Bool?) -> PrefValues {
        var values = files.map { withFiles($0) } ?? self
        if let guideLock { values.lockGuides = guideLock }
        return values
    }
    /// What is not compared when matching a set: the values that could not be read.
    static func unknownPaths(files: FileHandling.State?, guideLock: Bool?) -> [WritableKeyPath<PrefValues, Bool>] {
        (files == nil ? fileHandlingPaths : []) + (guideLock == nil ? [\.lockGuides] : [])
    }
    var fileHandling: FileHandling.State { [.export: backgroundExport, .save: backgroundSave, .recovery: recoverySave] }
    func withFiles(_ state: FileHandling.State) -> PrefValues {
        var values = self
        values.backgroundExport = state[.export] ?? backgroundExport
        values.backgroundSave = state[.save] ?? backgroundSave
        values.recoverySave = state[.recovery] ?? recoverySave
        return values
    }
}

/// メインウインドウ → 環境設定: only switching between the sets (they are edited in 設定 → 環境設定セット).
struct PrefPresetsPage: View {
    @ObservedObject var model: Model
    var body: some View {
        let current = PrefPresets.matching(model.currentPrefValues, ignoring: PrefValues.unknownPaths(files: model.fileHandling, guideLock: model.guideLock),
                                           in: model.prefPresets)
        FeaturePage(title: L("prefsets.title")) {
            Picker("", selection: Binding(get: { current ?? "" }, set: { model.applyPrefPreset($0) })) {
                ForEach(model.prefPresets) { set in Text(set.name.isEmpty ? L("sets.untitled") : set.name).tag(set.id) }
            }
            .pickerStyle(.radioGroup).labelsHidden()
            .disabled(model.busy || model.prefValues == nil)
            if model.prefValues == nil { Note(text: model.notRunningText) } else if current == nil { Note(text: L("prefsets.noMatch")) }
            HStack {
                Button(L("prefsets.edit")) { (NSApp.delegate as? AppDelegate)?.openPreferences(tab: L("prefsets.tab")) }
            }.padding(.top, 4)
            Note(text: L("prefsets.detail"))
            ResultRow(result: model.prefResult)
            // バックグラウンド (formerly its own tab): the File Handling checkboxes, set through the dialog box.
            GroupTitle(text: L("file.title")).padding(.top, 8)
            ForEach(FileHandling.Item.allCases, id: \.self) { item in
                Toggle(L("file." + item.rawValue), isOn: Binding(get: { model.fileHandling?[item] ?? false }, set: { model.setFileHandling(item, $0) }))
                    .disabled(model.busy)
            }
            HStack {
                Button(L("file.check")) { model.checkFileHandling() }.disabled(model.busy)
                if model.fileHandling == nil { Text(L("file.unchecked")).font(.caption).foregroundColor(.secondary) }
            }
            Note(text: L("file.detail"))
            ResultRow(result: model.fileResult)
        }
    }
}

/// 設定 → 環境設定セット: add, delete, reorder and edit the sets. Edits are a draft until ［上書き］ saves them
/// (［元に戻す］ discards them); nothing is written to Illustrator.
struct PrefPresetsEditor: View {
    @ObservedObject var model: Model
    @State private var selection: String?
    @State private var confirmReset = false

    private var index: Int? { model.editingPrefPresets.firstIndex { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("prefsets.setsTitle")) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        List(selection: $selection) {
                            ForEach(model.editingPrefPresets) { set in Text(set.name.isEmpty ? L("sets.untitled") : set.name).tag(set.id) }
                                .onMove { model.editingPrefPresets.move(fromOffsets: $0, toOffset: $1) }
                        }
                        .frame(width: 180, height: 220)
                        HStack(spacing: 4) {
                            Button { add() } label: { ListButtonLabel(symbol: "plus") }.help(L("sets.add"))
                            Button { remove() } label: { ListButtonLabel(symbol: "minus") }.help(L("sets.remove")).disabled(index == nil || model.editingPrefPresets.count <= 1)
                            Button { move(-1) } label: { ListButtonLabel(symbol: "chevron.up") }.help(L("sets.up")).disabled((index ?? 0) == 0)
                            Button { move(1) } label: { ListButtonLabel(symbol: "chevron.down") }.help(L("sets.down")).disabled(index.map { $0 >= model.editingPrefPresets.count - 1 } ?? true)
                        }
                        .controlSize(.small)
                    }
                    if let index { editor(index) } else { Text(L("sets.choose")).foregroundColor(.secondary) }
                }
                HStack {
                    Button(L("sets.reset")) { confirmReset = true }
                    Spacer()
                    if model.prefDraft != nil { Text(L("prefsets.unsaved")).font(.caption).foregroundColor(.secondary) }
                    Button(L("prefsets.revert")) { model.revertPrefDraft(); keepSelection() }.disabled(model.prefDraft == nil)
                    Button(L("prefsets.save")) { model.savePrefDraft() }.disabled(model.prefDraft == nil)
                }
                Text(L("prefsets.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { if selection == nil { selection = model.editingPrefPresets.first?.id } }
        .confirmationDialog(L("prefsets.resetConfirm"), isPresented: $confirmReset) {
            Button(L("sets.reset"), role: .destructive) { model.editingPrefPresets = PrefPreset.defaults; selection = model.editingPrefPresets.first?.id }
        }
    }

    private func binding<T>(_ index: Int, _ path: WritableKeyPath<PrefValues, T>) -> Binding<T> {
        Binding(get: { model.editingPrefPresets[index].values[keyPath: path] }, set: { model.editingPrefPresets[index].values[keyPath: path] = $0 })
    }
    private func toggle(_ index: Int, _ path: WritableKeyPath<PrefValues, Bool>) -> some View {
        Toggle(L(PrefPresets.flag(path).label), isOn: binding(index, path))
    }
    private func category<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold))
            content()
        }
        .padding(.top, 4)
    }
    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
            content()
        }
    }
    /// A number field with ∧∨, clamped to the range.
    private func number(_ index: Int, _ path: WritableKeyPath<PrefValues, Int>, _ range: ClosedRange<Int>) -> some View {
        let value = Binding(get: { model.editingPrefPresets[index].values[keyPath: path] },
                            set: { model.editingPrefPresets[index].values[keyPath: path] = min(max($0, range.lowerBound), range.upperBound) })
        return HStack(spacing: 2) {
            TextField("", value: value, format: .number.grouping(.never)).frame(width: 56).multilineTextAlignment(.trailing)
            Stepper("", value: value, in: range).labelsHidden()
        }
    }

    @ViewBuilder private func editor(_ index: Int) -> some View {
        let set = model.editingPrefPresets[index]
        VStack(alignment: .leading, spacing: 10) {
            row(L("sets.name")) { TextField("", text: Binding(get: { model.editingPrefPresets[index].name }, set: { model.editingPrefPresets[index].name = $0 })).frame(width: 200) }
            HStack(spacing: 8) {
                Button(L("prefsets.capture")) { model.capturePrefs(into: set.id) }.disabled(model.busy)
                if model.busy { ProgressView().controlSize(.small) }
            }
            category(L("prefsets.cat.general")) {
                toggle(index, \.richToolTips)
                toggle(index, \.homeScreen).help(L("prefsets.homeScreenTip"))
                toggle(index, \.legacyNewDoc).help(L("prefsets.legacyNewDocTip"))
                toggle(index, \.printBleedWidget)
            }
            category(L("prefsets.cat.selection")) {
                toggle(index, \.zoomToSelection)
                toggle(index, \.unlockOnCanvas).help(L("prefsets.unlockOnCanvasTip"))
                toggle(index, \.objectPathOnly)
                toggle(index, \.textPathOnly)
                row(L("prefsets.anchorSize")) {
                    Picker("", selection: binding(index, \.anchorSize)) {
                        ForEach(Array(PrefPresets.anchorSizes.enumerated()), id: \.element) { step, size in Text("\(step + 1)").tag(size) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                .help(L("prefsets.anchorSizeTip"))
            }
            category(L("prefsets.cat.artboard")) {
                toggle(index, \.moveLockedArt)
                toggle(index, \.showArtboardName)
                row(L("prefsets.artboardColor")) {
                    Picker("", selection: binding(index, \.artboardColor)) {
                        ForEach(PrefPresets.artboardColors.indices, id: \.self) { color in Text(L(PrefPresets.artboardColors[color].label)).tag(color) }
                    }
                    .labelsHidden().fixedSize()
                    let rgb = PrefPresets.artboardColors[min(max(set.values.artboardColor, 0), PrefPresets.artboardColors.count - 1)].rgb
                    RoundedRectangle(cornerRadius: 3).fill(Color(.sRGB, red: rgb[0], green: rgb[1], blue: rgb[2]))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.5), lineWidth: 0.5))
                        .frame(width: 18, height: 14).accessibilityHidden(true)
                }
                row(L("prefsets.artboardStrokeWidth")) {
                    Picker("", selection: binding(index, \.artboardStrokeWidth)) {
                        ForEach(PrefPresets.strokeWidths, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            }
            category(L("prefsets.cat.text")) {
                toggle(index, \.autoSizeAreaText)
                HStack(spacing: 8) {
                    Toggle(L("prefsets.recentFonts"), isOn: binding(index, \.recentFontsEnabled))
                    number(index, \.recentFontsCount, PrefPresets.recentFontsRange).disabled(!set.values.recentFontsEnabled)
                }
                .help(L("prefsets.recentFontsTip"))
                toggle(index, \.missingGlyphProtection)
                toggle(index, \.alternateGlyph)
            }
            category(L("prefsets.cat.interface")) {
                row(L("prefsets.brightness")) {
                    Picker("", selection: binding(index, \.uiBrightness)) {
                        ForEach(UIBrightness.levels.indices, id: \.self) { level in Text(L("bright.level." + UIBrightness.levels[level].key)).tag(level) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                .help(L("prefsets.dialogTip"))
                row(L("prefsets.canvasColor")) {
                    Picker("", selection: binding(index, \.canvasWhite)) {
                        Text(L("prefsets.canvasMatch")).tag(false)
                        Text(L("prefsets.canvasWhite")).tag(true)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
            }
            category(L("prefsets.cat.guides")) {
                Toggle(L("prefsets.lockGuides"), isOn: binding(index, \.lockGuides)).help(L("prefsets.lockGuidesTip"))
                row(L("prefsets.guideColor")) {
                    Picker("", selection: binding(index, \.guideLightBlue)) {
                        Text(L("prefsets.color.cyan")).tag(false)
                        Text(L("prefsets.color.lightBlue")).tag(true)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                row(L("prefsets.guideStyle")) {
                    Picker("", selection: binding(index, \.guideDots)) {
                        Text(L("prefsets.guideLines")).tag(false)
                        Text(L("prefsets.guideDots")).tag(true)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
            }
            category(L("prefsets.cat.smartGuides")) {
                toggle(index, \.objectHighlighting)
            }
            category(L("prefsets.cat.shapeBuilder")) {
                row(L("prefsets.shapeColor")) {
                    Picker("", selection: binding(index, \.shapeSwatches)) {
                        Text(L("shape.swatches")).tag(true)
                        Text(L("shape.artwork")).tag(false)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                .help(L("prefsets.shapeTip"))
            }
            category(L("prefsets.cat.performance")) {
                toggle(index, \.animatedZoom)
                row(L("prefsets.historyStates")) { number(index, \.historyStates, PrefPresets.historyRange) }
                toggle(index, \.realTimeDrawing)
            }
            category(L("prefsets.cat.file")) {
                toggle(index, \.editOriginalSystemDefault)
                toggle(index, \.autoActivateFonts)
                row(L("prefsets.saveLocation")) {
                    Picker("", selection: binding(index, \.saveToCloud)) {
                        Text(L("prefsets.saveComputer")).tag(false)
                        Text(L("prefsets.saveCloud")).tag(true)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                row(L("prefsets.updateLinks")) {
                    Picker("", selection: binding(index, \.updateLinks)) {
                        Text(L("prefsets.linksAuto")).tag(0)
                        Text(L("prefsets.linksManual")).tag(1)
                        Text(L("prefsets.linksAsk")).tag(2)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                Toggle(L("file.export"), isOn: binding(index, \.backgroundExport)).help(L("prefsets.dialogTip"))
                Toggle(L("file.save"), isOn: binding(index, \.backgroundSave)).help(L("prefsets.dialogTip"))
                Toggle(L("file.recovery"), isOn: binding(index, \.recoverySave)).help(L("prefsets.dialogTip"))
            }
            category(L("prefsets.cat.clipboard")) {
                toggle(index, \.includeSvgCode)
            }
            category(L("prefsets.cat.scripts")) {
                toggle(index, \.allowScripts).help(L("prefsets.allowScriptsTip"))
            }
        }
    }

    /// After ［元に戻す］ the selected set may be gone.
    private func keepSelection() {
        if !model.editingPrefPresets.contains(where: { $0.id == selection }) { selection = model.editingPrefPresets.first?.id }
    }
    private func add() {
        var new = model.editingPrefPresets.first(where: { $0.id == selection }) ?? PrefPreset.defaults[0]
        new.id = UUID().uuidString
        new.name = String(format: L("sets.copyName"), new.name)
        model.editingPrefPresets.append(new)
        selection = new.id
    }
    private func remove() {
        guard let index, model.editingPrefPresets.count > 1 else { return }
        model.editingPrefPresets.remove(at: index)
        selection = model.editingPrefPresets[min(index, model.editingPrefPresets.count - 1)].id
    }
    private func move(_ step: Int) {
        guard let index, model.editingPrefPresets.indices.contains(index + step) else { return }
        model.editingPrefPresets.swapAt(index, index + step)
    }
}
