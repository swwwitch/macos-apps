import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement

func L(_ key: String) -> String { NSLocalizedString(key, comment:"") }

@MainActor final class Model: ObservableObject {
    @Published var files: [URL] = []
    @Published var formatID = UserDefaults.standard.string(forKey:"format") ?? "docx" { didSet { UserDefaults.standard.set(formatID,forKey:"format") } }
    @Published var reader = "auto"
    @Published var toc = false
    @Published var numbers = false
    @Published var standalone = true
    @Published var wrap = "auto"
    @Published var htmlFormatting = HTMLFormatting(rawValue:UserDefaults.standard.string(forKey:"htmlFormatting") ?? "standard") ?? .standard { didSet { UserDefaults.standard.set(htmlFormatting.rawValue,forKey:"htmlFormatting") } }
    @Published var pdfEngine = UserDefaults.standard.string(forKey:"pdfEngine") ?? "typst" { didSet { UserDefaults.standard.set(pdfEngine,forKey:"pdfEngine") } }
    @Published var keynoteSlideSize = KeynoteSlideSize(rawValue:UserDefaults.standard.string(forKey:"keynoteSlideSize") ?? "") ?? .matchPDF { didSet { UserDefaults.standard.set(keynoteSlideSize.rawValue,forKey:"keynoteSlideSize") } }
    @Published var keynotePlacement = KeynotePlacement(rawValue:UserDefaults.standard.string(forKey:"keynotePlacement") ?? "") ?? .fit { didSet { UserDefaults.standard.set(keynotePlacement.rawValue,forKey:"keynotePlacement") } }
    @Published var keynoteBox = KeynotePageBox(rawValue:UserDefaults.standard.string(forKey:"keynoteBox") ?? "") ?? .crop { didSet { UserDefaults.standard.set(keynoteBox.rawValue,forKey:"keynoteBox") } }
    @Published var showAutomationHelp = false
    @Published var keepStructure = UserDefaults.standard.bool(forKey:"plainKeepStructure") { didSet { UserDefaults.standard.set(keepStructure,forKey:"plainKeepStructure") } }
    @Published var textOptions = MarkdownTextOptions.load() { didSet { textOptions.save() } }
    @Published var busy = false
    @Published var status = ""
    @Published var details = ""
    @Published var completed = 0
    @Published var results: [URL] = []
    @Published var destinationMode = UserDefaults.standard.string(forKey:"destinationMode") ?? "source" { didSet { UserDefaults.standard.set(destinationMode,forKey:"destinationMode") } }
    @Published var openAfterConversion = UserDefaults.standard.bool(forKey:"openAfterConversion") { didSet { UserDefaults.standard.set(openAfterConversion,forKey:"openAfterConversion") } }
    @Published var folder: URL? = UserDefaults.standard.string(forKey:"outputFolder").map { URL(fileURLWithPath:$0) } { didSet { UserDefaults.standard.set(folder?.path,forKey:"outputFolder") } }
    var runner: ConversionRunner?
    var format: OutputFormat { OutputFormat.all.first { $0.id == formatID } ?? OutputFormat.defaultFormat }
    /// Called when the format list changes in Settings: a hidden format cannot stay selected.
    func ensureVisibleFormat() {
        let visible = FormatPreferences.shared.visible
        if !visible.contains(where: { $0.id == formatID }), let first = visible.first { formatID = first.id }
    }
    func add(_ urls: [URL]) {
        guard !busy else { return }
        let allowed = Set(["md","markdown","txt","html","htm","docx","odt","rtf","epub","tex","rst","org","ipynb","json","csv","tsv","xlsx","pptx","typ","wiki","xml","idml","pdf","ai","psd","indd","srt"]).union(OutputFormat.rasterInputs)
        var rejected = false
        for url in urls {
            guard url.isFileURL, (try? url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile) == true, allowed.contains(url.pathExtension.lowercased()) else { rejected = true; continue }
            let canonical = url.standardizedFileURL
            if !files.contains(canonical) { files.append(canonical) }
        }
        status = rejected ? L("unsupported") : ""
        results = []; details = ""
    }
    func chooseFiles() {
        let p = NSOpenPanel(); p.allowsMultipleSelection = true; p.canChooseDirectories = false
        if p.runModal() == .OK { add(p.urls) }
    }
    func chooseFolder() {
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        p.prompt = L("selectFolder")
        if p.runModal() == .OK { folder = p.url }
    }
    func start() {
        guard !busy, !files.isEmpty else { return }
        if let reason = format.unsupportedReason(for:files) { status = L(reason); return }
        guard let engine = ConversionRunner.engine() else { status = L("engineMissing"); return }
        // .ai / .psd → PDF never typesets, so only other inputs need a PDF engine.
        if formatID == "pdf", files.contains(where: { !OutputFormat.imageOnlyInputs.union(["ai"]).contains($0.pathExtension.lowercased()) }), !ConversionRunner.pdfAvailable(pdfEngine) { status = L("pdfMissing"); return }
        if formatID == "keynote" {
            guard KeynoteBridge.isInstalled else { status = L("keynoteMissing"); return }
            if files.contains(where: { !ConversionRunner.isPDF($0) }), !ConversionRunner.pdfAvailable(pdfEngine) { status = L("keynoteNeedsPDF"); return }
        }
        if destinationMode == "custom", folder == nil { chooseFolder() }
        guard destinationMode == "source" || folder != nil else { return }
        let customFolder = destinationMode == "custom" ? folder : nil
        let shouldOpen = openAfterConversion
        let inputs = files
        var opts = ConversionOptions(format:format,reader:reader,standalone:standalone,toc:toc,numbers:numbers,wrap:wrap,pdfEngine:pdfEngine,htmlFormatting:htmlFormatting)
        // Keynote keeps the finished presentation open instead of reopening the saved file.
        if formatID == "plain" && keepStructure { opts.markdownText = textOptions }
        let defaults = UserDefaults.standard
        opts.aiMethod = defaults.string(forKey:"aiMethod") ?? "simple"
        opts.aiPreset = defaults.string(forKey:"aiPDFPreset") ?? ""
        if let path = defaults.string(forKey:"illustratorPath"), !path.isEmpty, FileManager.default.fileExists(atPath:path) { opts.illustratorApp = URL(fileURLWithPath:path) }
        if opts.aiMethod == "illustrator" || formatID == "svg", files.contains(where: { $0.pathExtension.lowercased() == "ai" }), opts.illustratorApp == nil, IllustratorBridge.defaultInstallation() == nil {
            status = L("illustratorMissing"); return
        }
        opts.loadImageSettings()
        if opts.psdMethod == "photoshop", files.contains(where: { $0.pathExtension.lowercased() == "psd" }), opts.photoshopApp == nil, PhotoshopBridge.defaultInstallation() == nil {
            status = L("photoshopMissing"); return
        }
        if files.contains(where: { $0.pathExtension.lowercased() == "indd" }), opts.indesignApp == nil, InDesignBridge.defaultInstallation() == nil {
            status = L("indesignMissing"); return
        }
        // 「1つのPDFにまとめる」: all raster images become the pages of one PDF.
        let combine = formatID == "pdf" && defaults.bool(forKey:"pdfCombineImages") && files.count > 1 && files.allSatisfy { OutputFormat.rasterInputs.contains($0.pathExtension.lowercased()) }
        opts.keynote = KeynoteOptions(slideSize:keynoteSlideSize, placement:keynotePlacement, box:keynoteBox, pageRange:nil, openAfter:shouldOpen)
        let worker = ConversionRunner(); runner = worker; busy = true; completed = 0; results = []; details = ""; showAutomationHelp = false; status = L("working")
        DispatchQueue.global(qos:.userInitiated).async {
            var outputs: [URL] = []; var errors: [String] = []; var denied = false; var succeeded = 0
            if combine {
                do { outputs.append(try worker.combineImagesToPDF(inputs, folder:customFolder ?? inputs[0].deletingLastPathComponent())); succeeded = inputs.count }
                catch is CancellationError {}
                catch { errors.append(error.localizedDescription) }
            }
            for (index,input) in inputs.enumerated() where !combine {
                if worker.isCancelled { break }
                do { outputs += try worker.convertFiles(engine:engine,input:input,folder:customFolder ?? input.deletingLastPathComponent(),options:opts); succeeded += 1 }
                catch is CancellationError { break }
                catch {
                    errors.append(input.lastPathComponent + ": " + error.localizedDescription)
                    if (error as? KeynoteError) == .automationDenied { denied = true; break }  // Every remaining file would fail the same way.
                }
                DispatchQueue.main.async { self.completed = index + 1 }
            }
            let finalOutputs = outputs; let finalErrors = errors; let finalWarnings = worker.warnings; let finalDenied = denied; let finalSucceeded = succeeded
            DispatchQueue.main.async {
                self.busy = false; self.runner = nil; self.results = finalOutputs
                self.details = (finalErrors + finalWarnings).joined(separator:"\n\n")
                let key = worker.isCancelled ? "cancelled" : finalErrors.isEmpty ? "success" : finalOutputs.isEmpty ? "failed" : "partial"
                self.status = L(key) + " · \(finalSucceeded)/\(inputs.count)" + (finalOutputs.count > finalSucceeded ? " · " + String(format:L("filesWritten"), finalOutputs.count) : "")
                self.showAutomationHelp = finalDenied
                if shouldOpen && !worker.isCancelled {
                    for url in finalOutputs where url.pathExtension.lowercased() != "key" { NSWorkspace.shared.open(url) }
                    if finalOutputs.contains(where: { $0.pathExtension.lowercased() == "key" }) { KeynoteBridge.activateKeynote() }
                }
            }
        }
    }
    func cancel() { runner?.cancel(); status = L("cancelling") }
}

/// Which output formats the main window lists, and in what order (Settings › 変換形式).
@MainActor final class FormatPreferences: ObservableObject {
    static let shared = FormatPreferences()
    @Published var order: [String] { didSet { UserDefaults.standard.set(order,forKey:"formatOrder") } }
    @Published var hidden: Set<String> { didSet { UserDefaults.standard.set(Array(hidden).sorted(),forKey:"hiddenFormats") } }
    private init() {
        let known = OutputFormat.all.map(\.id)
        let saved = (UserDefaults.standard.stringArray(forKey:"formatOrder") ?? []).filter { known.contains($0) }
        order = saved + known.filter { !saved.contains($0) }   // new formats join at the end
        hidden = Set(UserDefaults.standard.stringArray(forKey:"hiddenFormats") ?? []).intersection(known)
    }
    var ordered: [OutputFormat] { order.compactMap { id in OutputFormat.all.first { $0.id == id } } }
    var visible: [OutputFormat] { ordered.filter { !hidden.contains($0.id) } }
    func setVisible(_ id: String, _ on: Bool) {
        if on { hidden.remove(id) } else if visible.count > 1 { hidden.insert(id) }
    }
    func move(_ id: String, by offset: Int) {
        guard let index = order.firstIndex(of:id) else { return }
        let target = index + offset
        guard order.indices.contains(target) else { return }
        order.swapAt(index,target)
    }
    func reset() { order = OutputFormat.all.map(\.id); hidden = [] }
}

struct MainView: View {
    @ObservedObject var model: Model
    @ObservedObject var formats = FormatPreferences.shared
    @ObservedObject var pdfManager = PDFEngineManager.shared
    @State private var targeted = false
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(spacing:12) {
                Image(nsImage:currentAppIcon()).resizable().frame(width:52,height:52).accessibilityHidden(true)
                VStack(alignment:.leading,spacing:4) { Text(L("heading")).font(.system(size:22,weight:.semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
                Text("CARMA CHAMELEON").font(.system(size:10,weight:.semibold,design:.rounded)).tracking(2).foregroundStyle(.secondary)
            }
            HStack(alignment:.top,spacing:16) {
                VStack(alignment:.leading,spacing:12) {
                    heading("01", L("input"))
                    VStack(spacing:12) {
                        Image(systemName:"doc.badge.plus").font(.system(size:32,weight:.light)).foregroundColor(.secondary)
                        Text(L("drop")).font(.headline)
                        Text(L("inputHint")).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("chooseFiles")) { model.chooseFiles() }
                    }.frame(maxWidth:.infinity).frame(height:155)
                    .background(Color(nsColor:.textBackgroundColor)).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(targeted ? Color.accentColor : Color.gray.opacity(0.35),style:StrokeStyle(lineWidth:1.5,dash:[6,4])))
                    .onDrop(of:[UTType.fileURL.identifier],isTargeted:$targeted) { providers in
                        guard !model.busy else { return false }
                        for provider in providers { _ = provider.loadObject(ofClass:URL.self) { url,_ in if let url { DispatchQueue.main.async { model.add([url]) } } } }
                        return true
                    }
                    ScrollView {
                        VStack(spacing:8) {
                            ForEach(model.files,id:\.self) { url in
                                HStack(spacing:8) {
                                    Image(nsImage:NSWorkspace.shared.icon(forFile:url.path)).resizable().frame(width:24,height:24)
                                    Text(url.lastPathComponent).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading).help(url.path)
                                    Button { model.files.removeAll { $0 == url } } label: { Image(systemName:"xmark.circle.fill").foregroundColor(.secondary) }.buttonStyle(.plain).accessibilityLabel(L("remove"))
                                }.padding(9).background(Color(nsColor:.textBackgroundColor)).cornerRadius(7)
                            }
                        }
                    }
                    HStack { Text("\(model.files.count) " + L("files")).font(.caption).foregroundColor(.secondary); Spacer(); Button(L("clear")) { model.files = [] }.disabled(model.files.isEmpty) }
                }.frame(maxWidth:.infinity).disabled(model.busy)
                Divider()
                VStack(alignment:.leading,spacing:12) {
                    heading("02",L("format"))
                    ScrollView {
                        VStack(spacing:6) {
                            ForEach(formats.visible) { format in
                                // Formats the added files cannot become are dimmed; the tooltip gives the reason.
                                let reason = format.unsupportedReason(for:model.files)
                                let selected = model.formatID == format.id
                                Button { model.formatID = format.id } label: {
                                    HStack { VStack(alignment:.leading,spacing:2) { Text(format.name).fontWeight(.medium); Text(format.extLabel).font(.caption).foregroundStyle(.secondary) }; Spacer()
                                        Image(systemName:selected && reason != nil ? "exclamationmark.triangle.fill" : selected ? "checkmark.circle.fill" : "circle").foregroundColor(selected && reason != nil ? .orange : selected ? .accentColor : .gray.opacity(0.4)) }
                                    .padding(.horizontal,12).padding(.vertical,8).background(selected ? Color.accentColor.opacity(0.12) : Color(nsColor:.textBackgroundColor)).cornerRadius(7)
                                    .opacity(reason == nil || selected ? 1 : 0.4)
                                }.buttonStyle(.plain).disabled(reason != nil && !selected).help(reason.map(L) ?? "")
                                .accessibilityLabel(format.name).accessibilityValue(selected ? L("selected") : reason.map(L) ?? "")
                            }
                        }
                    }
                }.frame(width:195).disabled(model.busy)
                Divider()
                VStack(alignment:.leading,spacing:14) {
                    heading("03",L("options"))
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            if let reason = model.format.unsupportedReason(for:model.files) {
                                Label(L(reason),systemImage:"exclamationmark.triangle").font(.caption).foregroundColor(.orange).fixedSize(horizontal:false,vertical:true)
                            }
                            if model.formatID == "csv" {
                                CSVOptionsView()
                                Divider()
                            } else if model.format.isImage {
                                // Image outputs: pandoc's reader and document options do not apply.
                                if model.formatID == "image" { RasterOptionsView() } else { SVGOptionsView() }
                                Divider()
                                FileNamingView(svg:model.formatID == "svg")
                                Text(L(model.formatID == "svg" ? "svgHint" : "imageHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                                Divider()
                            } else {
                            Text(L("readAs")).fontWeight(.medium)
                            Picker("",selection:$model.reader) {
                                Text(L("auto")).tag("auto")
                                ForEach(["markdown","gfm","html","docx","odt","rtf","epub","latex","rst","org","ipynb","csv","tsv","xlsx","idml","pdf"],id:\.self) { Text($0).tag($0) }
                            }.labelsHidden().accessibilityLabel(L("readAs"))
                            Divider()
                            Toggle(L("standalone"),isOn:$model.standalone)
                            Toggle(L("toc"),isOn:$model.toc).disabled(!model.format.supportsTOC)
                            Toggle(L("numbers"),isOn:$model.numbers).disabled(!model.format.supportsNumbers)
                            }
                            if model.formatID == "plain" {
                                Toggle(L("keepStructure"),isOn:$model.keepStructure)
                                Text(L("keepStructureHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                                if model.keepStructure { StructureOptionsView(options:$model.textOptions) }
                            }
                            if ["gfm","plain","latex"].contains(model.formatID) && !(model.formatID == "plain" && model.keepStructure) {
                                Picker(L("wrap"),selection:$model.wrap) { Text(L("auto")).tag("auto"); Text(L("preserve")).tag("preserve"); Text(L("none")).tag("none") }
                            }
                            if model.formatID == "html5" {
                                Picker(L("htmlFormatting"),selection:$model.htmlFormatting) {
                                    Text(L("htmlStandard")).tag(HTMLFormatting.standard)
                                    Text("minify").tag(HTMLFormatting.minify)
                                    Text("beautify").tag(HTMLFormatting.beautify)
                                }.pickerStyle(.radioGroup)
                                Text(L("htmlFormattingHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                            }
                            if model.files.contains(where: { $0.pathExtension.lowercased() == "ai" }) && model.formatID != "svg" { AIOptionsView() }
                            if model.files.contains(where: { $0.pathExtension.lowercased() == "psd" }) { PSDOptionsView() }
                            if model.files.contains(where: { $0.pathExtension.lowercased() == "indd" }) { InDesignOptionsView(showPreset:model.formatID == "pdf") }
                            if model.formatID == "pdf", model.files.filter({ OutputFormat.rasterInputs.contains($0.pathExtension.lowercased()) }).count > 1 { CombineImagesView() }
                            if model.formatID == "keynote" {
                                Picker(L("slideSize"),selection:$model.keynoteSlideSize) { ForEach(KeynoteSlideSize.allCases) { Text($0.label).tag($0) } }
                                Picker(L("placement"),selection:$model.keynotePlacement) { Text(L("fit")).tag(KeynotePlacement.fit); Text(L("fill")).tag(KeynotePlacement.fill) }.pickerStyle(.radioGroup)
                                if model.keynotePlacement == .fill { Text(L("fillHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                                Picker(L("box"),selection:$model.keynoteBox) { ForEach(KeynotePageBox.allCases) { Text($0.label).tag($0) } }
                                Text(L("keynoteHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                            }
                            if (model.formatID == "pdf" && model.files.contains(where: { !OutputFormat.imageOnlyInputs.union(["ai"]).contains($0.pathExtension.lowercased()) })) || (model.formatID == "keynote" && model.files.contains(where: { !ConversionRunner.isPDF($0) })) {
                                Picker(L("pdfEngine"),selection:$model.pdfEngine) { Text("Typst").tag("typst"); Text("XeLaTeX").tag("xelatex"); Text("LuaLaTeX").tag("lualatex") }
                                Label(L(ConversionRunner.pdfAvailable(model.pdfEngine) ? "pdfReady" : "pdfMissing"),systemImage:"info.circle").font(.caption).foregroundColor(.secondary)
                                Button(L("pdfSetup")) { (NSApp.delegate as? Delegate)?.showSettings() }
                            }
                            Divider()
                            Text(L("output")).fontWeight(.medium)
                            Picker(L("output"),selection:$model.destinationMode) {
                                Text(L("sameFolder")).tag("source")
                                Text(L("specifiedFolder")).tag("custom")
                            }.pickerStyle(.radioGroup).labelsHidden()
                            if model.destinationMode == "custom" {
                                Text(model.folder?.path ?? L("chooseOnConvert")).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                                Button(L("selectFolder")) { model.chooseFolder() }
                            }
                            Toggle(L("openAfterConversion"),isOn:$model.openAfterConversion)
                            if model.files.contains(where: { $0.pathExtension.lowercased() == "idml" }) || model.reader == "idml" { Text(L("idmlLimit")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                            if model.formatID != "keynote", !model.format.isImage, model.files.contains(where: { $0.pathExtension.lowercased() == "pdf" }) || model.reader == "pdf" { Text(L("pdfInputHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                            if model.formatID == "idml" { Text(L("idmlOutputHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true) }
                            Text(L("preserveOriginal")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
                        }
                    }
                }.frame(width:260).disabled(model.busy)
            }
            Divider()
            if !model.details.isEmpty { ScrollView { Text(model.details).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(height:64) }
            HStack(spacing:12) {
                if model.busy { ProgressView().controlSize(.small); Text("\(model.completed)/\(model.files.count)").monospacedDigit() }
                Text(model.status.isEmpty ? L("ready") : model.status).font(.callout).lineLimit(2).textSelection(.enabled)
                Spacer()
                if model.showAutomationHelp { Button(L("permOpen")) { KeynoteBridge.openAutomationSettings() } }
                if !model.results.isEmpty { Button(L("reveal")) { NSWorkspace.shared.activateFileViewerSelecting(model.results) } }
                if model.busy { Button(L("cancel")) { model.cancel() }.keyboardShortcut(.cancelAction) }
                Button(L("convert")) { model.start() }.keyboardShortcut(.return,modifiers:.command).buttonStyle(.borderedProminent).controlSize(.large).disabled(model.files.isEmpty || model.busy)
            }
        }.onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) { _ in
            model.pdfEngine = UserDefaults.standard.string(forKey:"pdfEngine") ?? "typst"
        }.onReceive(pdfManager.$version) { _ in
            model.pdfEngine = UserDefaults.standard.string(forKey:"pdfEngine") ?? "typst"
        }.onReceive(FormatPreferences.shared.$hidden) { _ in DispatchQueue.main.async { model.ensureVisibleFormat() } }
        .padding(24).frame(minWidth:990,minHeight:670).background(Color(nsColor:AppSurface.color)).tint(Color(red:0.55,green:0.38,blue:0.04))
    }
    func heading(_ number: String,_ title: String) -> some View {
        HStack(spacing:8) { Text(number).font(.system(size:11,weight:.semibold,design:.rounded)).foregroundColor(.secondary); Text(title).font(.system(size:14,weight:.semibold)) }
    }
}

/// Options of 「構造を保持」 (same choices as cssnite.jp/tool/markdown2text.html).
struct StructureOptionsView: View {
    @Binding var options: MarkdownTextOptions
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Picker(L("mtLinks"),selection:$options.linkMode) {
                Text(L("mtLinkText")).tag(MarkdownTextOptions.LinkMode.text)
                Text(L("mtLinkAngle")).tag(MarkdownTextOptions.LinkMode.angle)
                Text(L("mtLinkParen")).tag(MarkdownTextOptions.LinkMode.paren)
            }
            Toggle(L("mtLinkBelow"),isOn:$options.linkBelow).disabled(options.linkMode == .text)
            HStack { Text(L("mtListMarker")); TextField("・",text:$options.listMarker).frame(width:44) }
            Picker(L("mtNumbers"),selection:$options.numberMode) {
                Text(L("mtNumKeep")).tag(MarkdownTextOptions.NumberMode.keep)
                Text(L("mtNumRenumber")).tag(MarkdownTextOptions.NumberMode.renumber)
                Text(L("mtNumMarker")).tag(MarkdownTextOptions.NumberMode.marker)
            }
            Toggle(L("mtZenkakuIndent"),isOn:$options.zenkakuIndent)
            HStack(spacing:6) {
                Text(L("mtHeadings"))
                ForEach(0..<4,id:\.self) { level in
                    TextField("H\(level+1)",text:Binding(get:{ options.headingPrefixes[level] },set:{ options.headingPrefixes[level] = $0 })).frame(width:34).help("H\(level+1)")
                }
            }
            Picker(L("mtBold"),selection:$options.boldMode) {
                Text(L("mtBoldNone")).tag(MarkdownTextOptions.BoldMode.none)
                Text(L("mtBoldBracket")).tag(MarkdownTextOptions.BoldMode.bracket)
            }
            Picker(L("mtTables"),selection:$options.tableMode) {
                Text(L("mtTableTab")).tag(MarkdownTextOptions.TableMode.tab)
                Text(L("mtTableAscii")).tag(MarkdownTextOptions.TableMode.ascii)
            }
            Picker(L("mtImages"),selection:$options.imageMode) {
                Text(L("mtImageText")).tag(MarkdownTextOptions.ImageMode.text)
                Text(L("mtImageIgnore")).tag(MarkdownTextOptions.ImageMode.ignore)
            }
            Picker(L("mtBlockGap"),selection:$options.blockGap) { ForEach(0...2,id:\.self) { Text(L("mtGap\($0)")).tag($0) } }
            Toggle(L("mtCollapseBlank"),isOn:$options.collapseBlank)
            Toggle(L("mtTrimLeading"),isOn:$options.trimLeading)
            Toggle(L("mtStripHTML"),isOn:$options.stripHTML)
        }.padding(.leading,4)
    }
}

extension MarkdownTextOptions {
    private static let key = "plainStructureOptions"
    static func load() -> MarkdownTextOptions {
        var o = MarkdownTextOptions()
        guard let d = UserDefaults.standard.dictionary(forKey:key) else { return o }
        if let v = d["linkMode"] as? String, let m = LinkMode(rawValue:v) { o.linkMode = m }
        if let v = d["numberMode"] as? String, let m = NumberMode(rawValue:v) { o.numberMode = m }
        if let v = d["boldMode"] as? String, let m = BoldMode(rawValue:v) { o.boldMode = m }
        if let v = d["tableMode"] as? String, let m = TableMode(rawValue:v) { o.tableMode = m }
        if let v = d["imageMode"] as? String, let m = ImageMode(rawValue:v) { o.imageMode = m }
        if let v = d["listMarker"] as? String { o.listMarker = v }
        if let v = d["blockGap"] as? Int { o.blockGap = v }
        for (name, path) in [("linkBelow", \MarkdownTextOptions.linkBelow), ("zenkakuIndent", \.zenkakuIndent), ("collapseBlank", \.collapseBlank), ("trimLeading", \.trimLeading), ("trimBlank", \.trimBlank), ("stripHTML", \.stripHTML)] {
            if let v = d[name] as? Bool { o[keyPath:path] = v }
        }
        if let v = d["headingPrefixes"] as? [String], v.count == 6 { o.headingPrefixes = v }
        return o
    }
    func save() {
        UserDefaults.standard.set(["linkMode":linkMode.rawValue,"numberMode":numberMode.rawValue,"boldMode":boldMode.rawValue,"tableMode":tableMode.rawValue,"imageMode":imageMode.rawValue,"listMarker":listMarker,"blockGap":blockGap,"linkBelow":linkBelow,"zenkakuIndent":zenkakuIndent,"collapseBlank":collapseBlank,"trimLeading":trimLeading,"trimBlank":trimBlank,"stripHTML":stripHTML,"headingPrefixes":headingPrefixes],forKey:Self.key)
    }
}

struct SettingsView: View {
    @AppStorage("resident") var resident = true
    var body: some View {
        SettingsTabs(sections:[
            (SettingsUI.launchTitle, AnyView(VStack(spacing:16) {
                SettingsSection(SettingsUI.launchTitle) {
                    LaunchPresenceSection(title:SettingsUI.launchTitle, loginControl:LoginAtLaunchView(), residentTitle:L("resident"), residentDetail:L("residentDetail"), resident:$resident,
                                          presenceExtra:MenuBarPresenceView(), shortcutTitle:L("launchShortcut"), shortcutButton:L("openShortcuts"), shortcutDetail:L("shortcutDetail")) {
                        NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/Shortcuts.app"))
                    }
                }
                SettingsSection(L("permission")) { KeynotePermissionView() }
            })),
            (L("format"), AnyView(SettingsSection(L("formatsTitle")) { FormatSettingsView() })),
            ("Illustrator", AnyView(SettingsSection(L("aiTitle")) { IllustratorSettingsView() })),
            ("Photoshop", AnyView(SettingsSection(L("psdTitle")) { PhotoshopSettingsView() })),
            ("InDesign", AnyView(SettingsSection(L("inddTitle")) { InDesignSettingsView() })),
            (L("enginesTab"), AnyView(VStack(spacing:16) {
                SettingsSection(L("engine")) { EngineSettingsView() }
                SettingsSection(L("pdfEngineGroup")) { PDFEngineSettingsView() }
            })),
        ]).frame(width:620,height:640)
    }
}

/// .ai conversion method and PDF preset (shared by the main window and Settings › Illustrator).
struct AIOptionsView: View {
    @AppStorage("aiMethod") var method = "simple"
    @AppStorage("aiPDFPreset") var preset = ""
    @AppStorage("aiPDFPresetList") var presetList = ""
    var compact = true
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            if compact { Text(L("aiTitle")).fontWeight(.medium) }   // Settings already shows it as the section title
            Picker(L("aiMethod"),selection:$method) {
                Text(L("aiSimple")).tag("simple")
                Text(L("aiIllustrator")).tag("illustrator")
            }.pickerStyle(.radioGroup).labelsHidden()
            if method == "illustrator" {
                Picker(L("aiPreset"),selection:$preset) {
                    Text(L("aiPresetDefault")).tag("")
                    ForEach(presetList.components(separatedBy:"\n").filter { !$0.isEmpty },id:\.self) { Text($0).tag($0) }
                    if !preset.isEmpty && !presetList.components(separatedBy:"\n").contains(preset) { Text(preset).tag(preset) }
                }
            }
            Text(L(method == "illustrator" ? "aiIllustratorHint" : "aiSimpleHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// Settings › Illustrator: method, which Illustrator, PDF preset (loaded from Illustrator).
struct IllustratorSettingsView: View {
    @AppStorage("illustratorPath") var path = ""
    @AppStorage("aiPDFPresetList") var presetList = ""
    @State private var loading = false
    @State private var message = ""
    private let installations = IllustratorBridge.installations()
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            AIOptionsView(compact:false)
            Divider()
            if installations.isEmpty {
                Label(L("illustratorMissing"),systemImage:"exclamationmark.triangle").foregroundColor(.secondary)
            } else {
                Picker(L("aiApp"),selection:$path) {
                    Text(L("aiAppNewest") + " (" + (installations.first?.name ?? "") + ")").tag("")
                    ForEach(installations) { Text($0.name + "  " + $0.version).tag($0.url.path) }
                }
                HStack {
                    Button(L("aiLoadPresets")) { loadPresets() }.disabled(loading)
                    if loading { ProgressView().controlSize(.small) }
                }
                Text(message.isEmpty ? L("aiLoadPresetsHint") : message).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
            }
        }
    }
    private func loadPresets() {
        let app = path.isEmpty ? installations.first?.url : URL(fileURLWithPath:path)
        guard let app else { return }
        loading = true; message = L("aiLoadingPresets")
        DispatchQueue.global(qos:.userInitiated).async {
            let result = Result { try IllustratorBridge.presets(in:app) }
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let names): presetList = names.joined(separator:"\n"); message = String(format:L("aiPresetsLoaded"), names.count)
                case .failure(let error): message = error.localizedDescription
                }
            }
        }
    }
}

/// Settings › 変換形式: show/hide each output format and change the order (drag or ↑↓).
struct FormatSettingsView: View {
    @ObservedObject var formats = FormatPreferences.shared
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text(L("formatsHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
            List {
                ForEach(formats.ordered) { format in
                    HStack(spacing:10) {
                        Toggle(isOn:Binding(get:{ !formats.hidden.contains(format.id) },set:{ formats.setVisible(format.id,$0) })) {
                            HStack(spacing:6) { Text(format.name); Text(format.extLabel).font(.caption).foregroundColor(.secondary) }
                        }
                        .disabled(!formats.hidden.contains(format.id) && formats.visible.count == 1)
                        Spacer()
                        Button { formats.move(format.id,by:-1) } label: { Image(systemName:"chevron.up") }.buttonStyle(.borderless).disabled(formats.order.first == format.id).accessibilityLabel(L("moveUp") + " " + format.name)
                        Button { formats.move(format.id,by:1) } label: { Image(systemName:"chevron.down") }.buttonStyle(.borderless).disabled(formats.order.last == format.id).accessibilityLabel(L("moveDown") + " " + format.name)
                    }.padding(.vertical,2)
                }
                .onMove { source, destination in formats.order.move(fromOffsets:source,toOffset:destination) }
            }
            .frame(height:400)
            HStack { Spacer(); Button(L("resetFormats")) { formats.reset() } }
        }
    }
}

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var window: NSWindow!
    var settings: NSWindow?
    var helpWindow: NSWindow?
    var statusItem: NSStatusItem?
    var isDuplicate = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults:["resident":true])
        if let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier:id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            isDuplicate = true
            other.activate(options:[.activateAllWindows,.activateIgnoringOtherApps])
            let urls = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }.map { URL(fileURLWithPath:$0) }.filter { FileManager.default.fileExists(atPath:$0.path) }
            if !urls.isEmpty, let app = other.bundleURL { NSWorkspace.shared.open(urls,withApplicationAt:app,configuration:NSWorkspace.OpenConfiguration()) }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { NSApp.terminate(nil) }
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicate else { return }
        buildMenus()
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:1080,height:720),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title = "CarmaChameleon"; window.titleVisibility = .hidden; window.contentView = NSHostingView(rootView:MainView(model:model)); window.delegate = self; window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MainWindow"); window.minSize = NSSize(width:1030,height:710)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName:"doc.on.doc",accessibilityDescription:"CarmaChameleon")
        // Status menu (BASELINE「メニューの共通構成」): help lives in a submenu; Quit is last.
        let menu = NSMenu(); add(menu,L("openMainWindow"),#selector(show),""); add(menu,L("settings"),#selector(showSettings),"")
        let helpSub = NSMenu(title:L("helpMenu")); add(helpSub,L("help"),#selector(showHelp),""); HelpLinks.addNoteItem(to:helpSub)
        menu.setSubmenu(helpSub,for:menu.addItem(withTitle:L("helpMenu"),action:nil,keyEquivalent:""))
        menu.addItem(.separator()); add(menu,L("quit"),#selector(quit),""); statusItem?.menu = menu
        // Shared menu-bar presence keeps this icon and menu; it adds 「メニューバー設定…」 to the app menu and the visibility setting.
        MenuBarPresence.shared.install(name:"CarmaChameleon",symbol:"doc.on.doc",existing:statusItem,show:{ [weak self] in self?.show() },settings:{ [weak self] in self?.showSettings() },help:{ [weak self] in self?.showHelp() })
        let login = LaunchPolicy.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        if !model.files.isEmpty || (!login && !StartupWindow.hidden) { show() }
    }
    @objc func show() { guard let window else { return }; NSApp.activate(ignoringOtherApps:true); if window.isMiniaturized { window.deminiaturize(nil) }; window.makeKeyAndOrderFront(nil) }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool) -> Bool { show(); return true }
    func application(_ sender:NSApplication,open urls:[URL]) {
        if isDuplicate, let id = Bundle.main.bundleIdentifier, let other = NSRunningApplication.runningApplications(withBundleIdentifier:id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }), let app = other.bundleURL { NSWorkspace.shared.open(urls,withApplicationAt:app,configuration:NSWorkspace.OpenConfiguration()); return }
        model.add(urls); show()
    }
    func windowShouldClose(_ sender:NSWindow) -> Bool {
        if sender === window && !UserDefaults.standard.bool(forKey:"resident") { NSApp.terminate(nil); return false }
        return true
    }
    func applicationShouldTerminate(_ sender:NSApplication) -> NSApplication.TerminateReply {
        if EngineManager.shared.busy || PDFEngineManager.shared.busy { let a = NSAlert(); a.messageText = L("installing"); a.informativeText = L("waitInstall"); a.runModal(); return .terminateCancel }
        if model.busy {
            let a = NSAlert(); a.messageText = L("working"); a.informativeText = L("quitBusy"); a.addButton(withTitle:L("ok")); a.runModal(); show(); return .terminateCancel
        }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) { KeynoteBridge.removeRuntimeScript() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func choose() { show(); model.chooseFiles() }
    @objc func showSettings() {
        if settings == nil { settings = NSWindow(contentRect:NSRect(x:0,y:0,width:560,height:450),styleMask:[.titled,.closable],backing:.buffered,defer:false); settings!.title = L("settingsWindow"); settings!.contentView = NSHostingView(rootView:SettingsView()); settings!.isReleasedWhenClosed = false; settings!.center() }
        settings!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func showHelp() {
        if helpWindow == nil {
            let text = Bundle.main.url(forResource:"Help",withExtension:"txt").flatMap { try? String(contentsOf:$0,encoding:.utf8) } ?? L("help")
            helpWindow = HelpDocument.makeWindow(windowTitle:L("help"), text:text, heading:"CarmaChameleon")
        }
        helpWindow!.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"CarmaChameleon",.applicationVersion:"\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))",.credits:NSAttributedString(string:L("aboutDetail"))]) }
    func add(_ menu:NSMenu,_ title:String,_ action:Selector,_ key:String) { let item = menu.addItem(withTitle:title,action:action,keyEquivalent:key); item.target = self }
    func buildMenus() {
        let bar = NSMenu(); NSApp.mainMenu = bar
        let app = NSMenu(); let root = NSMenuItem(); root.submenu = app; bar.addItem(root)
        add(app,L("about"),#selector(about),""); app.addItem(.separator()); add(app,L("settings"),#selector(showSettings),","); app.addItem(.separator())
        #if DIRECT_UPDATES && !APP_STORE
        AppUpdates.shared.addMenuItems(to:app)   // 「アップデートを確認…」「アップデートを自動確認」 + separator
        #endif
        let services = NSMenu(title:L("services")); app.addItem(withTitle:L("services"),action:nil,keyEquivalent:"").submenu = services; NSApp.servicesMenu = services; app.addItem(.separator())
        app.addItem(withTitle:L("hideApp"),action:#selector(NSApplication.hide(_:)),keyEquivalent:"h"); app.addItem(withTitle:L("hideOthers"),action:#selector(NSApplication.hideOtherApplications(_:)),keyEquivalent:"h").keyEquivalentModifierMask = [.command,.option]; app.addItem(withTitle:L("showAll"),action:#selector(NSApplication.unhideAllApplications(_:)),keyEquivalent:""); app.addItem(.separator())
        add(app,L("quit"),#selector(quit),"q")
        let file = NSMenu(title:L("fileMenu")); let f = NSMenuItem(title:L("fileMenu"),action:nil,keyEquivalent:""); f.submenu = file; bar.addItem(f); add(file,L("openMainWindow"),#selector(show),"0"); file.addItem(.separator()); add(file,L("chooseFiles"),#selector(choose),"o"); file.addItem(.separator()); file.addItem(withTitle:L("close"),action:#selector(NSWindow.performClose(_:)),keyEquivalent:"w")
        let edit = NSMenu(title:L("editMenu")); let e = NSMenuItem(title:L("editMenu"),action:nil,keyEquivalent:""); e.submenu = edit; bar.addItem(e)
        for (key,action,shortcut) in [("undo","undo:","z"),("redo","redo:","z"),("cut","cut:","x"),("copy","copy:","c"),("paste","paste:","v"),("selectAll","selectAll:","a")] { edit.addItem(withTitle:L(key),action:Selector(action),keyEquivalent:shortcut) }
        edit.item(at:1)?.keyEquivalentModifierMask = [.command,.shift]   // やり直す ⇧⌘Z
        let win = NSMenu(title:L("windowMenu")); let wi = NSMenuItem(title:L("windowMenu"),action:nil,keyEquivalent:""); wi.submenu = win; bar.addItem(wi)
        win.addItem(withTitle:L("minimize"),action:#selector(NSWindow.performMiniaturize(_:)),keyEquivalent:"")
        win.addItem(withTitle:L("zoom"),action:#selector(NSWindow.performZoom(_:)),keyEquivalent:"")
        win.addItem(.separator())
        win.addItem(withTitle:L("bringAllToFront"),action:#selector(NSApplication.arrangeInFront(_:)),keyEquivalent:"")
        NSApp.windowsMenu = win
        let h = NSMenu(title:L("helpMenu")); let hi = NSMenuItem(title:L("helpMenu"),action:nil,keyEquivalent:""); hi.submenu = h; bar.addItem(hi); add(h,L("help"),#selector(showHelp),"?"); HelpLinks.addNoteItem(to:h); NSApp.helpMenu = h
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
MainActor.assumeIsolated {
    let delegate = Delegate(); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
