import SwiftUI

/// Settings of the image outputs, kept in UserDefaults (the views below bind to the same keys).
extension ConversionOptions {
    mutating func loadImageSettings() {
        let d = UserDefaults.standard
        let type = d.string(forKey:"rasterType") ?? "png"
        raster.type = RasterOptions.availableTypes.contains { $0.id == type } ? type : "png"
        raster.sizeMode = ["ppi","width","height"].contains(d.string(forKey:"rasterSizeMode") ?? "") ? d.string(forKey:"rasterSizeMode")! : "ppi"
        raster.ppi = min(max(d.object(forKey:"rasterPPI") as? Int ?? 144, 1), 2400)
        raster.width = min(max(d.object(forKey:"rasterWidth") as? Int ?? 1200, 1), 30000)
        raster.height = min(max(d.object(forKey:"rasterHeight") as? Int ?? 1200, 1), 30000)
        raster.quality = min(max(d.object(forKey:"rasterQuality") as? Int ?? 85, 0), 100)
        raster.transparent = d.object(forKey:"rasterTransparent") as? Bool ?? true
        raster.range = d.string(forKey:"rasterRange") ?? ""
        svg.css = d.string(forKey:"svgCSS") ?? svg.css
        svg.font = d.string(forKey:"svgFont") ?? svg.font
        svg.images = d.string(forKey:"svgImages") ?? svg.images
        svg.precision = min(max(d.object(forKey:"svgPrecision") as? Int ?? svg.precision, 1), 7)
        svg.idType = d.string(forKey:"svgID") ?? svg.idType
        svg.minify = d.bool(forKey:"svgMinify")
        svg.responsive = d.object(forKey:"svgResponsive") as? Bool ?? true
        naming = FileNaming.load()
        psdMethod = d.string(forKey:"psdMethod") ?? "simple"
        if let path = d.string(forKey:"photoshopPath"), !path.isEmpty, FileManager.default.fileExists(atPath:path) { photoshopApp = URL(fileURLWithPath:path) }
        if let path = d.string(forKey:"indesignPath"), !path.isEmpty, FileManager.default.fileExists(atPath:path) { indesignApp = URL(fileURLWithPath:path) }
        indesignPreset = d.string(forKey:"inddPDFPreset") ?? ""
        csvDelimiter = d.string(forKey:"csvDelimiter") == "tab" ? "\t" : ","
    }
}

extension FileNaming {
    static func load() -> FileNaming {
        let d = UserDefaults.standard
        var n = FileNaming()
        n.useFileName = d.object(forKey:"nameFile") as? Bool ?? n.useFileName
        n.useNumber = d.object(forKey:"nameNumber") as? Bool ?? n.useNumber
        n.useLabel = d.object(forKey:"nameLabel") as? Bool ?? n.useLabel
        n.delimiter = d.string(forKey:"nameDelimiter") ?? n.delimiter
        n.padNumber = d.bool(forKey:"namePad")
        n.singleUsesFileName = d.object(forKey:"nameSingle") as? Bool ?? n.singleUsesFileName
        n.groupInFolder = d.bool(forKey:"nameGroupFolder")
        return n
    }
}

/// 「ラスター画像」: PNG / JPEG / HEIC / AVIF, size (resolution, width or height), quality, background, artboards / pages.
struct RasterOptionsView: View {
    @AppStorage("rasterType") var type = "png"
    @AppStorage("rasterSizeMode") var sizeMode = "ppi"
    @AppStorage("rasterWidth") var width = 1200
    @AppStorage("rasterHeight") var height = 1200
    @AppStorage("rasterPPI") var ppi = 144
    @AppStorage("rasterQuality") var quality = 85
    @AppStorage("rasterTransparent") var transparent = true
    @AppStorage("rasterRange") var range = ""
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Picker(L("rasterType"),selection:$type) { ForEach(RasterOptions.availableTypes,id:\.id) { Text($0.name).tag($0.id) } }.pickerStyle(.segmented)
            Picker(L("rasterSize"),selection:$sizeMode) { Text(L("rasterPPI")).tag("ppi"); Text(L("rasterWidth")).tag("width"); Text(L("rasterHeight")).tag("height") }.pickerStyle(.segmented)
            HStack(spacing:6) {
                switch sizeMode {
                case "width": TextField("",value:$width,format:.number).frame(width:64).multilineTextAlignment(.trailing); Text("px").foregroundColor(.secondary)
                case "height": TextField("",value:$height,format:.number).frame(width:64).multilineTextAlignment(.trailing); Text("px").foregroundColor(.secondary)
                default:
                    TextField("",value:$ppi,format:.number).frame(width:64).multilineTextAlignment(.trailing)
                    Text("ppi").foregroundColor(.secondary)
                    Menu("") { ForEach([72,96,144,150,300,350,600],id:\.self) { value in Button("\(value) ppi") { ppi = value } } }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel(L("rasterPPIPresets"))
                }
            }
            if type != "png" {
                HStack(spacing:6) {
                    Text(L("rasterQuality"))
                    Slider(value:Binding(get:{ Double(quality) },set:{ quality = Int($0.rounded()) }),in:0...100,step:1)
                    Text("\(quality)").monospacedDigit().frame(width:28,alignment:.trailing)
                }
            }
            if type != "jpeg" { Toggle(L("rasterTransparent"),isOn:$transparent) }
            HStack(spacing:6) {
                Text(L("rasterRange"))
                TextField(L("rasterRangeAll"),text:$range).frame(maxWidth:.infinity)
            }
            Text(L("rasterRangeHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// SVG options of Illustrator's Export for Screens (same choices as its SVG settings).
struct SVGOptionsView: View {
    @AppStorage("svgCSS") var css = "STYLEATTRIBUTES"
    @AppStorage("svgFont") var font = "SVGFONT"
    @AppStorage("svgImages") var images = "PRESERVE"
    @AppStorage("svgPrecision") var precision = 3
    @AppStorage("svgID") var idType = "SVGIDREGULAR"
    @AppStorage("svgMinify") var minify = false
    @AppStorage("svgResponsive") var responsive = true
    @AppStorage("rasterRange") var range = ""
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Picker(L("svgCSS"),selection:$css) {
                Text(L("svgCSSAttributes")).tag("STYLEATTRIBUTES")
                Text(L("svgCSSElements")).tag("STYLEELEMENTS")
                Text(L("svgCSSPresentation")).tag("PRESENTATIONATTRIBUTES")
                Text(L("svgCSSEntities")).tag("ENTITIES")
            }
            Picker(L("svgFont"),selection:$font) { Text(L("svgFontText")).tag("SVGFONT"); Text(L("svgFontOutline")).tag("OUTLINEFONT") }
            Picker(L("svgImages"),selection:$images) {
                Text(L("svgImagesPreserve")).tag("PRESERVE")
                Text(L("svgImagesEmbed")).tag("EMBED")
                Text(L("svgImagesLink")).tag("LINK")
            }
            Picker(L("svgID"),selection:$idType) {
                Text(L("svgIDRegular")).tag("SVGIDREGULAR")
                Text(L("svgIDMinimal")).tag("SVGIDMINIMAL")
                Text(L("svgIDUnique")).tag("SVGIDUNIQUE")
            }
            Picker(L("svgPrecision"),selection:$precision) { ForEach(1...7,id:\.self) { Text("\($0)").tag($0) } }
            Toggle(L("svgMinify"),isOn:$minify)
            Toggle(L("svgResponsive"),isOn:$responsive)
            HStack(spacing:6) {
                Text(L("rasterRange"))
                TextField(L("rasterRangeAll"),text:$range).frame(maxWidth:.infinity)
            }
            Text(L("svgRangeHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// Output filename: file name / artboard number / artboard name, delimiter, zero padding, with a preview.
struct FileNamingView: View {
    var svg: Bool
    @AppStorage("rasterType") var type = "png"
    @AppStorage("nameFile") var useFileName = true
    @AppStorage("nameNumber") var useNumber = true
    @AppStorage("nameLabel") var useLabel = false
    @AppStorage("nameDelimiter") var delimiter = "-"
    @AppStorage("namePad") var pad = false
    @AppStorage("nameSingle") var single = true
    @AppStorage("nameGroupFolder") var group = false
    var naming: FileNaming { FileNaming(useFileName:useFileName, useNumber:useNumber, useLabel:useLabel, delimiter:delimiter, padNumber:pad, singleUsesFileName:single) }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Text(L("nameTitle")).fontWeight(.medium)
            Toggle(L("nameFile"),isOn:$useFileName)
            Toggle(L("nameNumber"),isOn:$useNumber)
            Toggle(L("nameLabel"),isOn:$useLabel)
            Picker(L("nameDelimiter"),selection:$delimiter) { Text("-").tag("-"); Text("_").tag("_"); Text(L("nameSpace")).tag(" ") }.pickerStyle(.segmented)
            Toggle(L("namePad"),isOn:$pad).disabled(!useNumber)
            Toggle(L("nameSingle"),isOn:$single)
            Toggle(L("nameGroupFolder"),isOn:$group)
            let ext = svg ? "svg" : RasterOptions(type:type).ext
            let example = naming.name(stem:L("nameSampleFile"), index:2, total:3, label:L("nameSampleArtboard")) + "." + ext
            Text(String(format:L("namePreview"), example)).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
            Text(L("nameHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// .psd conversion method (main window and Settings › Photoshop).
struct PSDOptionsView: View {
    @AppStorage("psdMethod") var method = "simple"
    var compact = true
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            if compact { Text(L("psdTitle")).fontWeight(.medium) }
            Picker(L("psdMethod"),selection:$method) {
                Text(L("psdSimple")).tag("simple")
                Text(L("psdPhotoshop")).tag("photoshop")
            }.pickerStyle(.radioGroup).labelsHidden()
            Text(L(method == "photoshop" ? "psdPhotoshopHint" : "psdSimpleHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// Settings › Photoshop: method and which Photoshop.
struct PhotoshopSettingsView: View {
    @AppStorage("photoshopPath") var path = ""
    private let installations = PhotoshopBridge.installations()
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            PSDOptionsView(compact:false)
            Divider()
            if installations.isEmpty {
                Label(L("photoshopMissing"),systemImage:"exclamationmark.triangle").foregroundColor(.secondary)
            } else {
                Picker(L("psdApp"),selection:$path) {
                    Text(L("aiAppNewest") + " (" + (installations.first?.name ?? "") + ")").tag("")
                    ForEach(installations) { Text($0.name + "  " + $0.version).tag($0.url.path) }
                }
            }
        }
    }
}

/// .srt → CSV: separator (comma writes .csv, tab writes .tsv).
struct CSVOptionsView: View {
    @AppStorage("csvDelimiter") var delimiter = "comma"
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Picker(L("csvDelimiter"),selection:$delimiter) { Text(L("csvComma")).tag("comma"); Text(L("csvTab")).tag("tab") }.pickerStyle(.radioGroup)
            Text(L("csvHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// PDF from several raster images: one PDF per image, or all of them in one PDF.
struct CombineImagesView: View {
    @AppStorage("pdfCombineImages") var combine = false
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            Toggle(L("pdfCombineImages"),isOn:$combine)
            Text(L("pdfCombineImagesHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// .indd conversion (InDesign only) and its PDF preset (main window and Settings › InDesign).
struct InDesignOptionsView: View {
    @AppStorage("inddPDFPreset") var preset = ""
    @AppStorage("inddPDFPresetList") var presetList = ""
    var showPreset = true
    var compact = true
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            if compact { Text(L("inddTitle")).fontWeight(.medium) }
            if showPreset {
                Picker(L("aiPreset"),selection:$preset) {
                    Text(L("inddPresetDefault")).tag("")
                    ForEach(presetList.components(separatedBy:"\n").filter { !$0.isEmpty },id:\.self) { Text($0).tag($0) }
                    if !preset.isEmpty && !presetList.components(separatedBy:"\n").contains(preset) { Text(preset).tag(preset) }
                }
            }
            Text(L("inddHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
        }
    }
}

/// Settings › InDesign: which InDesign, PDF preset (loaded from InDesign).
struct InDesignSettingsView: View {
    @AppStorage("indesignPath") var path = ""
    @AppStorage("inddPDFPresetList") var presetList = ""
    @State private var loading = false
    @State private var message = ""
    private let installations = InDesignBridge.installations()
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            InDesignOptionsView(compact:false)
            Divider()
            if installations.isEmpty {
                Label(L("indesignMissing"),systemImage:"exclamationmark.triangle").foregroundColor(.secondary)
            } else {
                Picker(L("inddApp"),selection:$path) {
                    Text(L("aiAppNewest") + " (" + (installations.first?.name ?? "") + ")").tag("")
                    ForEach(installations) { Text($0.name + "  " + $0.version).tag($0.url.path) }
                }
                HStack {
                    Button(L("inddLoadPresets")) { loadPresets() }.disabled(loading)
                    if loading { ProgressView().controlSize(.small) }
                }
                Text(message.isEmpty ? L("inddLoadPresetsHint") : message).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)
            }
        }
    }
    private func loadPresets() {
        let app = path.isEmpty ? installations.first?.url : URL(fileURLWithPath:path)
        guard let app else { return }
        loading = true; message = L("inddLoadingPresets")
        DispatchQueue.global(qos:.userInitiated).async {
            let result = Result { try InDesignBridge.presets(in:app) }
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
