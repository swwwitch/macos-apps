import AppKit
import Carbon
struct Shortcut: Codable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    static let initial = Shortcut(code: 25, modifiers: UInt32(cmdKey | shiftKey), label: "⇧⌘9")
    static let palette = Shortcut(code: 32, modifiers: UInt32(cmdKey | optionKey | shiftKey), label: "⌥⇧⌘U")
    // Transcribed from the article's palette image (US physical key positions).
    static let articleDefaults: [String: Shortcut] = {
        let full = UInt32(cmdKey | shiftKey)
        let half = UInt32(cmdKey | optionKey | shiftKey)
        let force = UInt32(cmdKey | optionKey | controlKey)
        var result: [String: Shortcut] = [:]
        func add(_ id: String, _ code: UInt32, _ key: String, _ mods: UInt32, _ prefix: String) {
            result[id] = Shortcut(code: code, modifiers: mods, label: prefix + key)
        }
        for (id, code, key) in [("round", UInt32(25), "9"), ("square", 33, "["), ("lenticular", 24, "="),
                                ("angle", 30, "]"), ("doubleAngle", 42, "\\"), ("corner", 41, ";"),
                                ("curly", 29, "0"), ("doubleCorner", 27, "-"), ("smartDouble", 39, "'")] {
            add(id, code, key, full, "⇧⌘")
        }
        for (id, code, key) in [("asciiRound", UInt32(29), "0"), ("asciiSquare", 33, "["),
                                ("asciiCurly", 30, "]"), ("asciiAngle", 47, "."),
                                ("asciiSingle", 41, ";"), ("asciiDouble", 39, "'")] {
            add(id, code, key, half, "⌥⇧⌘")
        }
        for id in ["round", "square", "corner", "angle", "doubleAngle"] {
            let normal = result[id]!
            result["force_" + id] = Shortcut(code: normal.code, modifiers: force, label: "⌃⌥⌘" + String(normal.label.dropFirst(2)))
        }
        add("css", 44, "/", force, "⌃⌥⌘")
        add("html", 29, "0", force, "⌃⌥⌘")
        add("spaces", 49, "Space", full, "⇧⌘")
        add("removeOuter", 51, "Delete", full, "⇧⌘")
        add("removeAll", 51, "Delete", half, "⌥⇧⌘")
        result["palette"] = .palette
        return result
    }()
    static func loadBindings(defaults: UserDefaults = .standard) -> [String: Shortcut] {
        let savedData = defaults.data(forKey: "bracketBindings")
        var bindings = savedData.flatMap { try? JSONDecoder().decode([String: Shortcut].self, from: $0) } ?? [:]
        if defaults.integer(forKey: "articleShortcutRevision") >= 1 { return bindings }
        // The user requested the article layout. Apply once, preserve a recovery copy,
        // and never reapply over later user changes or deliberately cleared shortcuts.
        if let savedData { defaults.set(savedData, forKey: "bindingsBeforeArticle") }
        if let legacy = defaults.data(forKey: "shortcut") { defaults.set(legacy, forKey: "legacyShortcutBeforeArticle") }
        let reserved = Set(articleDefaults.values.map(\.signature))
        bindings = bindings.filter { articleDefaults[$0.key] == nil && !reserved.contains($0.value.signature) }
        bindings.merge(articleDefaults) { _, article in article }
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: "bracketBindings")
            defaults.set(1, forKey: "articleShortcutRevision")
        }
        return bindings
    }
    var signature: String { "\(code):\(modifiers)" }
}
final class HotKey {
    var action: ((String) -> Void)?
    private var references: [EventHotKeyRef] = []
    private var actions: [UInt32: String] = [:]
    private var handler: EventHandlerRef?
    private var handlerStatus: OSStatus = noErr
    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr, id.signature == 0x534B4544 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
            if let action = owner.actions[id.id] { owner.action?(action) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ bindings: [String: Shortcut]) -> [String: OSStatus] {
        references.forEach { UnregisterEventHotKey($0) }; references.removeAll(); actions.removeAll()
        var failures: [String: OSStatus] = [:]; var used = Set<String>()
        for (index, id) in BracketAction.ids.enumerated() {
            guard let shortcut = bindings[id] else { continue }
            guard used.insert(shortcut.signature).inserted else { failures[id] = OSStatus(eventHotKeyExistsErr); continue }
            guard handlerStatus == noErr else { failures[id] = handlerStatus; continue }
            var reference: EventHotKeyRef?
            let number = UInt32(index + 1)
            let status = RegisterEventHotKey(shortcut.code, shortcut.modifiers, EventHotKeyID(signature: 0x534B4544, id: number), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference { references.append(reference); actions[number] = id } else { failures[id] = status }
        }
        return failures
    }
    deinit { references.forEach { UnregisterEventHotKey($0) }; if let handler { RemoveEventHandler(handler) } }
}
