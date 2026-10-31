import AppKit
import SwiftUI
import ImageIO

@MainActor final class OCRModel: ObservableObject {
    @Published var screenAllowed = AreaCapture.allowed
    var frontExcluded: Bool { ExcludedApps.shared.excludes(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
    @Published var text = ""
    @Published var status = ""
    @Published var recognizing = false
    @Published var joinJapanese = UserDefaults.standard.object(forKey: "ocr.join") as? Bool ?? true { didSet { UserDefaults.standard.set(joinJapanese, forKey: "ocr.join") } }
    @Published var fullwidthParens = UserDefaults.standard.object(forKey: "ocr.parens") as? Bool ?? true { didSet { UserDefaults.standard.set(fullwidthParens, forKey: "ocr.parens") } }
    @Published var copyAutomatically = UserDefaults.standard.object(forKey: "ocr.copy") as? Bool ?? true { didSet { UserDefaults.standard.set(copyAutomatically, forKey: "ocr.copy") } }
    @Published var hotkeyRegistered = true
    var onHotkeyChange: (() -> Void)?
    // Unassigned at first to avoid ShotSorter's ⌘⇧1 while both apps remain installed.
    @Published var combo: KeyCombo? = Model.readCombo("ocr.hotkey") { didSet {
        UserDefaults.standard.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "ocr.hotkey")
        onHotkeyChange?()
    } }
    static let sharedKeys: Set<String> = ["ocr.join", "ocr.parens", "ocr.copy"]
    func reloadPreferences() {
        let d = UserDefaults.standard
        let join = d.object(forKey: "ocr.join") as? Bool ?? true
        let parens = d.object(forKey: "ocr.parens") as? Bool ?? true
        let copy = d.object(forKey: "ocr.copy") as? Bool ?? true
        joinJapanese = join; fullwidthParens = parens; copyAutomatically = copy
    }
    func recognizeArea() {
        guard !recognizing else { return }
        guard !frontExcluded else { status = L("ocr.excluded"); return }
        guard AreaCapture.allowed else {
            status = L("ocr.permission")
            return
        }
        recognizing = true; status = L("ocr.working")
        let join = joinJapanese, parens = fullwidthParens
        let clipboardChange = NSPasteboard.general.changeCount
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<String?, Error> in
                guard let url = AreaCapture.capture() else { return .success(nil) }
                defer { try? FileManager.default.removeItem(at: url) }
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    return .failure(NSError(domain: "InputMaestro.OCR", code: 1, userInfo: [NSLocalizedDescriptionKey: L("ocr.imageFailed")]))
                }
                do { return .success(OCRText.clean(try TextRecognizer.recognize(image), join: join, parens: parens)) }
                catch { return .failure(error) }
            }.value
            recognizing = false
            switch result {
            case .success(nil): status = L("ocr.cancelled")
            case .success(let output?):
                text = output
                if output.isEmpty { status = L("ocr.none") }
                else if frontExcluded { status = L("ocr.excluded") }
                else if copyAutomatically && NSPasteboard.general.changeCount == clipboardChange { copy(); status = L("ocr.copied") }
                else { status = L("ocr.ready") }
            case .failure(let error): status = L("ocr.failed") + " " + error.localizedDescription
            }
            AppDelegate.shared?.showMainWindow()
        }
    }
    func copy() {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    func openScreenSettings() {
        // Permission is requested only in response to this explicit button.
        CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
    }
}
struct OCRPage: View {
    @ObservedObject var model: OCRModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSection(L("ocrTab")) {
                    Button(L("recognizeButton")) { model.recognizeArea() }.disabled(model.recognizing)
                    if model.recognizing { ProgressView().controlSize(.small) }
                    if !model.status.isEmpty { Text(model.status).textSelection(.enabled) }
                    TextEditor(text: $model.text).frame(minHeight: 130).accessibilityLabel(L("ocr.result"))
                    Button(L("ocr.copyButton")) { model.copy() }.disabled(model.text.isEmpty)
                    DisclosureGroup(L("explanation")) { Text(L("ocr.explanation")) }
                }
                SettingsSection(L("ocr.formatting")) {
                    Toggle(L("ocr.join"), isOn: $model.joinJapanese)
                    Toggle(L("ocr.parens"), isOn: $model.fullwidthParens)
                    Toggle(L("ocr.autoCopy"), isOn: $model.copyAutomatically)
                    HotkeyField(id: "ocr.hotkey", combo: $model.combo, allowsClear: true, registered: model.hotkeyRegistered)
                }
                SettingsSection(L("ocr.screenPermission")) {
                    Text(model.screenAllowed ? AccessibilityText.text("allowed") : L("ocr.permission"))
                    Button(L("ocr.openSettings")) { model.openScreenSettings() }
                }
            }.padding(12)
        }
    }
}
