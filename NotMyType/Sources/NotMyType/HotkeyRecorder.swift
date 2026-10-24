import AppKit
import Carbon
import SwiftUI

// Canonical source: Shared/HotkeyRecorder/HotkeyRecorder.swift (copied by Shared/HotkeyRecorder/sync.py).
// The shared hotkey field of the settings: one look, one wording and one recording rule in every app.
// Apps keep their own storage and convert to and from KeyCombo.

/// A key combination in Carbon terms (kVK_* key code; cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096).
struct KeyCombo: Codable, Equatable, Hashable {
    var code: UInt32
    var modifiers: UInt32

    static let command = UInt32(cmdKey), shift = UInt32(shiftKey), option = UInt32(optionKey), control = UInt32(controlKey)

    init(code: UInt32, modifiers: UInt32) { self.code = code; self.modifiers = modifiers }

    /// ⌃⌥⇧⌘ in the order macOS menus show them.
    static func symbols(_ m: UInt32) -> String {
        (m & control != 0 ? "⌃" : "") + (m & option != 0 ? "⌥" : "") + (m & shift != 0 ? "⇧" : "") + (m & command != 0 ? "⌘" : "")
    }
    var label: String { Self.symbols(modifiers) + Self.keyName(code) }

    private static let named: [UInt32: String] = [
        UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥", UInt32(kVK_Space): "Space", UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ForwardDelete): "⌦", UInt32(kVK_Escape): "⎋", UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓", UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟", UInt32(kVK_ANSI_KeypadEnter): "⌤",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12", UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16", UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18", UInt32(kVK_F19): "F19", UInt32(kVK_F20): "F20",
        UInt32(kVK_JIS_Eisu): "英数", UInt32(kVK_JIS_Kana): "かな"
    ]
    /// Used only when the current layout types nothing for the key (JIS keys on a US layout).
    private static let fallback: [UInt32: String] = [
        UInt32(kVK_JIS_Yen): "¥", UInt32(kVK_JIS_Underscore): "_", UInt32(kVK_JIS_KeypadComma): ","
    ]

    /// The character the key types on the current keyboard layout, without modifiers (A, 1, ¥, …).
    static func keyName(_ code: UInt32) -> String {
        if let name = named[code] { return name }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return fallback[code] ?? "#\(code)" }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { bytes -> OSStatus in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return fallback[code] ?? "#\(code)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }

    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers & Self.command != 0 { flags.insert(.maskCommand) }
        if modifiers & Self.option != 0 { flags.insert(.maskAlternate) }
        if modifiers & Self.control != 0 { flags.insert(.maskControl) }
        if modifiers & Self.shift != 0 { flags.insert(.maskShift) }
        return flags
    }

    enum Refusal: Error { case needsModifier, needsAnyModifier, standardKey }
    /// ⌘C ⌘V ⌘X ⌘Z ⌘A ⌘Q ⌘W ⌘, and ⌘Tab-like keys stay with the system and the front app.
    static let standardCommandKeys: Set<UInt16> = [0, 6, 7, 8, 9, 12, 13, 43, 48]
    static let functionKeys: Set<UInt16> = Set([kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                                                kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20].map { UInt16($0) })
    /// A key press while recording. ⌘ or ⌃ is required by default: shift alone types a capital, and ⌥ / ⌥⇧ alone
    /// type characters (é, ©). allowsOption admits ⌥ / ⌥⇧ alone for apps whose defaults use them (LinkMaker).
    static func recorded(_ event: NSEvent, allowsOption: Bool = false) -> Result<KeyCombo, Refusal> {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let required: NSEvent.ModifierFlags = allowsOption ? [.command, .option, .control] : [.command, .control]
        // F1–F20 type no characters, so ⇧ alone or no modifier is fine (AiHelper's ⇧F1 / ⇧F2).
        guard !flags.intersection(required).isEmpty || functionKeys.contains(event.keyCode) else { return .failure(allowsOption ? .needsAnyModifier : .needsModifier) }
        if flags == .command && standardCommandKeys.contains(event.keyCode) { return .failure(.standardKey) }
        var m: UInt32 = 0
        if flags.contains(.command) { m |= command }
        if flags.contains(.shift) { m |= shift }
        if flags.contains(.option) { m |= option }
        if flags.contains(.control) { m |= control }
        return .success(KeyCombo(code: UInt32(event.keyCode), modifiers: m))
    }
}

/// Wording shared by every app's hotkey settings.
enum HotkeyText {
    static func text(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String { StartupWindow.text(ja, en, zh, ko) }
    static var enable: String { text("ホットキーを有効にする", "Enable hotkey", "启用快捷键", "단축키 사용") }
    static var change: String { text("変更…", "Change…", "更改…", "변경…") }
    static var cancel: String { text("記録をキャンセル", "Cancel Recording", "取消录制", "기록 취소") }
    static var reset: String { text("初期値に戻す", "Reset to Default", "恢复默认", "기본값으로 되돌리기") }
    static var clear: String { text("割り当てを解除", "Clear", "清除", "지우기") }
    static var unset: String { text("未設定", "None", "未设置", "없음") }
    static var pressKeys: String { text("キーを押す…", "Press keys…", "请按键…", "키를 누르세요…") }
    static var recordingHint: String {
        text("割り当てるキーを押してください。⌘ か ⌃ を含めます。Escで取り消します。",
             "Press the keys to assign, including ⌘ or ⌃. Press Esc to cancel.",
             "请按下要分配的按键，需包含 ⌘ 或 ⌃。按 Esc 取消。",
             "지정할 키를 누르세요. ⌘ 또는 ⌃를 포함해야 합니다. Esc로 취소합니다.")
    }
    static var recordingHintAny: String {
        text("割り当てるキーを押してください。⌘・⌥・⌃ のどれかを含めます。Escで取り消します。",
             "Press the keys to assign, including ⌘, ⌥ or ⌃. Press Esc to cancel.",
             "请按下要分配的按键，需包含 ⌘、⌥ 或 ⌃。按 Esc 取消。",
             "지정할 키를 누르세요. ⌘, ⌥, ⌃ 중 하나를 포함해야 합니다. Esc로 취소합니다.")
    }
    static var needsModifier: String {
        text("⌘ か ⌃ を含めてください（⌥だけ・⌥⇧だけは文字の入力に使われるため割り当てできません）。",
             "Include ⌘ or ⌃ (⌥ or ⌥⇧ alone types characters and cannot be assigned).",
             "请包含 ⌘ 或 ⌃（仅 ⌥ 或 ⌥⇧ 用于输入字符，无法分配）。",
             "⌘ 또는 ⌃를 포함하세요(⌥ 또는 ⌥⇧만으로는 문자 입력에 쓰이므로 지정할 수 없습니다).")
    }
    static var needsAnyModifier: String {
        text("⌘・⌥・⌃ のどれかを含めてください。", "Include ⌘, ⌥ or ⌃.", "请包含 ⌘、⌥ 或 ⌃。", "⌘, ⌥, ⌃ 중 하나를 포함하세요.")
    }
    static var standardKey: String {
        text("このキーはmacOSや各アプリの標準の操作で使われるため割り当てできません。", "This key is used by macOS and apps for standard commands.",
             "此按键用于 macOS 和各应用的标准操作，无法分配。", "이 키는 macOS와 앱의 기본 동작에 쓰이므로 지정할 수 없습니다.")
    }
    static func duplicate(_ label: String, _ owner: String) -> String {
        String(format: text("%@ はすでに「%@」に割り当てられています。", "%@ is already assigned to “%@”.",
                            "%@ 已分配给“%@”。", "%@은(는) 이미 ‘%@’에 지정되어 있습니다."), label, owner)
    }
    static var registerFailed: String {
        text("このキーは登録できませんでした。ほかのアプリが使っている可能性があります。別のキーを選んでください。",
             "This key could not be registered. Another app may be using it. Choose a different key.",
             "无法注册此按键，可能已被其他应用使用。请选择其他按键。",
             "이 키를 등록하지 못했습니다. 다른 앱이 사용 중일 수 있습니다. 다른 키를 선택하세요.")
    }
}

/// Records one hotkey at a time for the whole app. While recording, HotkeySet keeps the app's own hotkeys
/// unregistered so the keystroke reaches the recorder instead of firing an action.
@MainActor
final class HotkeyRecorder: ObservableObject {
    static let shared = HotkeyRecorder()
    @Published private(set) var recordingID: String?
    @Published private(set) var messageID: String?
    @Published private(set) var message = ""
    @Published private(set) var messageIsError = false
    /// Bumped by touch(): AppKit hosts redraw their fields after the app changed a value.
    @Published private(set) var revision = 0
    private var monitor: Any?
    private var commit: ((KeyCombo) -> String?)?
    /// Called when recording starts or ends (apps with their own registration pause and resume their hotkeys).
    var onRecordingChanged: [(Bool) -> Void] = []

    /// commit returns nil when the combo was taken, or the message to show (duplicate, registration failure) and keeps recording.
    func start(_ id: String, allowsOption: Bool = false, commit: @escaping (KeyCombo) -> String?) {
        if recordingID == id { stop(); return }
        stop()
        self.commit = commit
        recordingID = id
        show(id, allowsOption ? HotkeyText.recordingHintAny : HotkeyText.recordingHint, error: false)
        onRecordingChanged.forEach { $0(true) }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // NSEvent is not Sendable: decide from plain values inside the main actor.
            let escape = event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
            let result = KeyCombo.recorded(event, allowsOption: allowsOption)
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, let id = self.recordingID else { return false }
                if escape { self.stop(); return true }
                switch result {
                case .failure(.needsModifier): self.show(id, HotkeyText.needsModifier, error: true)
                case .failure(.needsAnyModifier): self.show(id, HotkeyText.needsAnyModifier, error: true)
                case .failure(.standardKey): self.show(id, HotkeyText.standardKey, error: true)
                case .success(let combo):
                    if let refusal = self.commit?(combo) { self.show(id, refusal, error: true) }
                    else { self.stop() }
                }
                return true
            }
            return consumed ? nil : event
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        commit = nil
        let wasRecording = recordingID != nil
        recordingID = nil
        if messageID != nil && !messageIsError { message = ""; messageID = nil }
        if wasRecording { onRecordingChanged.forEach { $0(false) } }
    }
    /// A message under one field (registration failed after the change, etc.).
    func show(_ id: String, _ text: String, error: Bool) {
        messageID = id; message = text; messageIsError = error
    }
    func clearMessage(_ id: String) { if messageID == id { message = ""; messageID = nil } }
    /// Call after changing a hotkey or its enabled state outside the field, so every field shows it.
    func touch() { revision &+= 1 }
}

/// Several Carbon hotkeys sharing one handler; each is identified by a small number.
/// Registrations are suspended while HotkeyRecorder records, and restored afterwards.
@MainActor
final class HotkeySet {
    var action: ((UInt32) -> Void)?
    private let signature: OSType
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var wanted: [UInt32: KeyCombo] = [:]
    private var handler: EventHandlerRef?
    private var handlerStatus: OSStatus = noErr
    private var suspended = false

    /// signature: four characters unique to the app, e.g. "LkMk".
    init(signature: String) {
        self.signature = signature.utf8.reduce(0) { ($0 << 8) | OSType($1) }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<HotkeySet>.fromOpaque(context).takeUnretainedValue()
            let number = id.id, signature = id.signature
            DispatchQueue.main.async {
                MainActor.assumeIsolated { if signature == owner.signature { owner.action?(number) } }
            }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in self?.setSuspended(recording) }
    }

    var registered: Set<UInt32> { Set(references.keys) }

    /// Registers (or replaces) hotkey `number`. Returns noErr, or the Carbon error (another app holds the key, etc.).
    @discardableResult
    func register(_ number: UInt32, _ combo: KeyCombo) -> OSStatus {
        unregister(number)
        wanted[number] = combo
        guard handlerStatus == noErr else { return handlerStatus }
        if suspended { return noErr }
        return attach(number, combo)
    }
    func unregister(_ number: UInt32) {
        wanted[number] = nil
        detach(number)
    }
    func unregisterAll() { for number in Array(wanted.keys) { unregister(number) } }

    private func attach(_ number: UInt32, _ combo: KeyCombo) -> OSStatus {
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.code, combo.modifiers, EventHotKeyID(signature: signature, id: number), GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference { references[number] = reference }
        return status
    }
    private func detach(_ number: UInt32) {
        if let reference = references.removeValue(forKey: number) { UnregisterEventHotKey(reference) }
    }
    private func setSuspended(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        if value { for number in Array(references.keys) { detach(number) } }
        else { for (number, combo) in wanted { _ = attach(number, combo) } }
    }
}

/// One hotkey row: [key] [変更…] [初期値に戻す] [割り当てを解除], with the message underneath.
/// `others` are the app's other hotkeys (title, combo) so the same key is not assigned twice.
struct HotkeyField: View {
    let id: String
    @Binding var combo: KeyCombo?
    var defaultCombo: KeyCombo? = nil
    var allowsClear = false
    var others: [(String, KeyCombo)] = []
    /// Set after registering: false shows the shared registration-failed message.
    var registered = true
    var isEnabled = true
    /// Admit ⌥ / ⌥⇧ alone (only for apps whose own defaults use them).
    var allowsOption = false
    @ObservedObject private var recorder = HotkeyRecorder.shared

    init(id: String, combo: Binding<KeyCombo?>, defaultCombo: KeyCombo? = nil, allowsClear: Bool = false,
         others: [(String, KeyCombo)] = [], registered: Bool = true, isEnabled: Bool = true, allowsOption: Bool = false) {
        self.id = id; _combo = combo; self.defaultCombo = defaultCombo; self.allowsClear = allowsClear
        self.others = others; self.registered = registered; self.isEnabled = isEnabled; self.allowsOption = allowsOption
    }

    private var recording: Bool { recorder.recordingID == id }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(recording ? HotkeyText.pressKeys : (combo?.label ?? HotkeyText.unset))
                    .font(.system(size: 13, design: .monospaced))
                    // ⌃⌥⌘ run together in the monospaced font; a little tracking keeps each symbol readable.
                    .kerning(recording || combo == nil ? 0 : 2)
                    .foregroundColor(combo == nil && !recording ? .secondary : .primary)
                    .lineLimit(1).fixedSize()
                    .frame(minWidth: 96, alignment: .leading)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(recording ? Color.accentColor : Color.secondary.opacity(0.4)))
                    .accessibilityLabel(combo?.label ?? HotkeyText.unset)
                Button(recording ? HotkeyText.cancel : HotkeyText.change) {
                    recorder.start(id, allowsOption: allowsOption) { candidate in
                        if let owner = others.first(where: { $0.1 == candidate })?.0 { return HotkeyText.duplicate(candidate.label, owner) }
                        combo = candidate
                        recorder.touch()
                        return nil
                    }
                }
                if let defaultCombo {
                    Button(HotkeyText.reset) {
                        recorder.stop()
                        // The default may already be taken by another field.
                        if let owner = others.first(where: { $0.1 == defaultCombo })?.0 {
                            recorder.show(id, HotkeyText.duplicate(defaultCombo.label, owner), error: true); return
                        }
                        recorder.clearMessage(id); combo = defaultCombo; recorder.touch()
                    }
                        .disabled(combo == defaultCombo)
                }
                if allowsClear {
                    Button(HotkeyText.clear) { recorder.stop(); recorder.clearMessage(id); combo = nil; recorder.touch() }.disabled(combo == nil)
                }
            }
            .disabled(!isEnabled && !recording)
            if recorder.messageID == id, !recorder.message.isEmpty {
                Text(recorder.message).font(.caption).foregroundColor(recorder.messageIsError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !registered, combo != nil, isEnabled {
                Text(HotkeyText.registerFailed).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// AppKit form: values are read again on every redraw (after recording, touch(), or a message).
struct HotkeyFieldHost: View {
    let id: String
    let get: () -> KeyCombo?
    let set: (KeyCombo?) -> Void
    var defaultCombo: KeyCombo?
    var allowsClear: Bool
    var others: () -> [(String, KeyCombo)]
    var registered: () -> Bool
    var isEnabled: () -> Bool
    var allowsOption = false
    @ObservedObject private var recorder = HotkeyRecorder.shared
    init(id: String, get: @escaping () -> KeyCombo?, set: @escaping (KeyCombo?) -> Void, defaultCombo: KeyCombo?, allowsClear: Bool,
         others: @escaping () -> [(String, KeyCombo)], registered: @escaping () -> Bool, isEnabled: @escaping () -> Bool, allowsOption: Bool = false) {
        self.id = id; self.get = get; self.set = set; self.defaultCombo = defaultCombo; self.allowsClear = allowsClear
        self.others = others; self.registered = registered; self.isEnabled = isEnabled; self.allowsOption = allowsOption
    }
    var body: some View {
        let _ = recorder.revision
        HotkeyField(id: id, combo: Binding(get: get, set: set), defaultCombo: defaultCombo, allowsClear: allowsClear,
                    others: others(), registered: registered(), isEnabled: isEnabled(), allowsOption: allowsOption)
    }
}

extension HotkeyField {
    /// AppKit form (SettingsUI.group rows). After changing a value elsewhere, call HotkeyRecorder.shared.touch().
    @MainActor static func control(id: String, get: @escaping () -> KeyCombo?, set: @escaping (KeyCombo?) -> Void,
                                   defaultCombo: KeyCombo? = nil, allowsClear: Bool = false,
                                   others: @escaping () -> [(String, KeyCombo)] = { [] },
                                   registered: @escaping () -> Bool = { true }, isEnabled: @escaping () -> Bool = { true },
                                   allowsOption: Bool = false) -> NSView {
        SettingsHostingPage(observing: HotkeyRecorder.shared) {
            HotkeyFieldHost(id: id, get: get, set: set, defaultCombo: defaultCombo, allowsClear: allowsClear,
                            others: others, registered: registered, isEnabled: isEnabled, allowsOption: allowsOption)
        }
    }
}
