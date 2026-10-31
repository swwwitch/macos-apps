import AppKit
import SwiftUI

enum InputFeature { case numpad, editing, ocr, modifiers, arrows }
struct FeatureToggle: View {
    let title: String
    @Binding var enabled: Bool
    var body: some View {
        Toggle(title, isOn: $enabled).toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
    }
}
struct FeatureNotice: View {
    @ObservedObject var model: Model
    let feature: InputFeature
    var enabled: Bool {
        switch feature {
        case .numpad: return model.integration.numpadEnabled
        case .editing: return model.enabled
        case .ocr: return model.ocr.enabled
        case .modifiers: return model.symbols.modifiersEnabled
        case .arrows: return model.symbols.arrowsEnabled
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.paused {
                HStack {
                    Label(L("allPaused"), systemImage: "pause.circle.fill")
                    Button(L("resumeAll")) { model.togglePause() }
                }
            } else if enabled {
                if feature != .ocr && !model.trusted {
                    Label(AccessibilityText.text("blocked"), systemImage: "exclamationmark.triangle.fill")
                    Button(L("openPermissions")) { AppDelegate.shared?.openSettingsTab(0) }
                } else if feature == .ocr && !model.ocr.screenAllowed {
                    Label(L("ocr.permission"), systemImage: "exclamationmark.triangle.fill")
                    Button(L("openPermissions")) { AppDelegate.shared?.openSettingsTab(0) }
                } else if (feature == .numpad || feature == .editing || (feature == .arrows && model.symbols.arrowMode == .google)) && !model.tapRunning {
                    Label(L("status.tapFailed"), systemImage: "exclamationmark.triangle.fill")
                }
                if feature == .numpad && model.integration.numpadConflict { Label(L("conflict.numpad"), systemImage: "pause.circle") }
                if feature == .editing && model.integration.controlConflict { Label(L("conflict.control"), systemImage: "pause.circle") }
                if feature == .editing, let failure = model.lastFailure { Label(failure, systemImage: "exclamationmark.circle") }
            }
        }.font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
struct KeyboardDisplayPreferences: View {
    @AppStorage("keyboardLayout") private var layout = "auto"
    var body: some View {
        SettingsSection(L("keyboardDisplay")) {
            Picker(L("kb.layout"), selection: $layout) {
                Text(String(format: L("kb.layoutAuto"), L(KeyboardLayout.detected == .jis ? "kb.jis" : "kb.ansi"))).tag("auto")
                Text(L("kb.ansi")).tag("ansi")
                Text(L("kb.jis")).tag("jis")
            }.fixedSize()
        }
    }
}
