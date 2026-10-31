import AppKit
import SwiftUI
import ImageIO

@MainActor final class OCRModel: ObservableObject {
    @Published var paused = false { didSet { if paused && recognizing { suppressAutomaticCopy = true } } }
    private var suppressAutomaticCopy = false
    @Published var pendingResult = false
    @Published var enabled = UserDefaults.standard.object(forKey: "ocr.enabled") as? Bool ?? true { didSet {
        UserDefaults.standard.set(enabled, forKey: "ocr.enabled")
        onHotkeyChange?()
    } }
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
    // User-specified ⌘⇧1; preserve saved custom shortcuts and explicit clears.
    @Published var combo: KeyCombo? = OCRPreferences.shortcut(in: .standard).map { KeyCombo(code: $0.code, modifiers: $0.modifiers) } { didSet {
        UserDefaults.standard.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "ocr.hotkey")
        onHotkeyChange?()
    } }
    static let sharedKeys: Set<String> = ["ocr.enabled", "ocr.join", "ocr.parens", "ocr.copy"]
    func reloadPreferences() {
        let d = UserDefaults.standard
        let join = d.object(forKey: "ocr.join") as? Bool ?? true
        let parens = d.object(forKey: "ocr.parens") as? Bool ?? true
        let copy = d.object(forKey: "ocr.copy") as? Bool ?? true
        enabled = d.object(forKey: "ocr.enabled") as? Bool ?? true
        joinJapanese = join; fullwidthParens = parens; copyAutomatically = copy
    }
    func recognizeArea() {
        guard enabled, !paused, !recognizing else { return }
        guard !frontExcluded else { status = L("ocr.excluded"); return }
        guard AreaCapture.allowed else {
            status = L("ocr.permission")
            return
        }
        suppressAutomaticCopy = false; pendingResult = false
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
                else if paused || suppressAutomaticCopy { pendingResult = true; status = L("ocr.held") }
                else if enabled && copyAutomatically && NSPasteboard.general.changeCount == clipboardChange { copy(); status = L("ocr.copied") }
                else { status = L("ocr.ready") }
            case .failure(let error): status = L("ocr.failed") + " " + error.localizedDescription
            }
        }
    }
    func copy() {
        guard !text.isEmpty, !paused else { return }
        pendingResult = false
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
    @ObservedObject var owner: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FeatureToggle(title: L("ocr.enable"), enabled: $model.enabled)
                FeatureNotice(model: owner, feature: .ocr)
                if model.pendingResult && !model.paused { Button(L("ocr.copyHeld")) { model.copy(); model.status = L("ocr.copied") } }
                if model.recognizing { ProgressView().controlSize(.small) }
                if !model.status.isEmpty { Text(model.status).textSelection(.enabled) }
                SettingsSection(L("ocr.formatting")) {
                    Toggle(L("ocr.join"), isOn: $model.joinJapanese)
                    Toggle(L("ocr.parens"), isOn: $model.fullwidthParens)
                    Toggle(L("ocr.autoCopy"), isOn: $model.copyAutomatically)
                    HotkeyField(id: "ocr.hotkey", combo: $model.combo, defaultCombo: KeyCombo(code: 18, modifiers: KeyCombo.command | KeyCombo.shift), allowsClear: true, registered: model.hotkeyRegistered, isEnabled: model.enabled)
                }

            }.padding(12)
        }
    }
}

struct ScreenRecordingSection: View {
    @ObservedObject var model: OCRModel
    var body: some View {
        SettingsSection(L("ocr.screenPermission")) {
            Label(AccessibilityText.text(model.screenAllowed ? "allowed" : "denied"), systemImage: model.screenAllowed ? "checkmark.circle.fill" : "minus.circle")
                .foregroundColor(model.screenAllowed ? .green : .secondary)
            if !model.screenAllowed { Text(L("ocr.permission")).fixedSize(horizontal: false, vertical: true) }
            Button(L("ocr.openSettings")) { model.openScreenSettings() }
        }
    }
}
