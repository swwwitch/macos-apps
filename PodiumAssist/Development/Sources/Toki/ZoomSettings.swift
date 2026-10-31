import AppKit
@preconcurrency import ApplicationServices

/// System Settings → Accessibility → Zoom.
/// com.apple.universalaccess can be read, but writes are refused without Full Disk Access (measured), so the shortcut switch,
/// the zoom style menu and the maximum zoom slider are operated in System Settings by AXIdentifier (measured on macOS 26).
/// The slider ignores AXValue writes and AXIncrement moves 3.9 at a time, so the knob is dragged with mouse events.
/// The keyboard shortcuts are system symbolic hot keys (15 toggle, 17 zoom in), which the app can write.
enum ZoomSettings {
    /// closeViewZoomMode values (measured by choosing each item in System Settings).
    enum Style: Int, CaseIterable {
        case fullScreen = 0, pictureInPicture = 1, splitScreen = 2

        /// The order of the System Settings menu, which the menu item is chosen by.
        static let menuOrder: [Style] = [.fullScreen, .splitScreen, .pictureInPicture]

        var title: String {
            switch self {
            case .fullScreen: L("フルスクリーン")
            case .splitScreen: L("分割した画面に表示")
            case .pictureInPicture: L("ピクチャインピクチャ")
            }
        }
    }

    /// A shortcut: "key code,modifiers" as in com.apple.symbolichotkeys, or "off".
    struct Shortcut {
        let id: String
        /// macOS's own value while the entry is absent.
        let defaultValue: String
        /// 8388608 is fn (function keys), 1572864 is ⌥⌘.
        let choices: [(value: String, title: String)]
    }

    static let toggleShortcut = Shortcut(id: "15", defaultValue: "28,1572864",
                                         choices: [("122,8388608", "F1"), ("120,8388608", "F2"), ("28,1572864", "⌥⌘8")])
    static let zoomInShortcut = Shortcut(id: "17", defaultValue: "24,1572864",
                                         choices: [("120,8388608", "F2"), ("122,8388608", "F1"), ("24,1572864", "⌥⌘=")])
    static let zoomOutShortcut = Shortcut(id: "19", defaultValue: "27,1572864",
                                          choices: [("99,8388608", "F3"), ("27,1572864", "⌥⌘−")])
    static let maxFactorRange: ClosedRange<Double> = 1...40

    /// Use logical display height (for example 945), not Retina backing pixels.
    static func automaticFactors(height: Double) -> (min: Double, max: Double)? {
        guard height.isFinite, height > 0 else { return nil }
        let minimum = min(max(height / 500, 1), maxFactorRange.upperBound / 2)
        return (minimum, minimum * 2)
    }

    private static let pane = "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Zoom"
    private static let domain = "com.apple.universalaccess" as CFString
    private static let hotkeysDomain = "com.apple.symbolichotkeys" as CFString
    private static let hotkeysKey = "AppleSymbolicHotKeys" as CFString
    /// Character codes of the keys in the choices (key code → ASCII); keys without a character use 65535.
    private static let characters: [Int: Int] = [28: 56, 24: 61, 27: 45]

    // MARK: - Reading

    private static func value(_ key: String) -> NSNumber? {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key as CFString, domain) as? NSNumber
    }

    static var hotkeysEnabled: Bool { value("closeViewHotkeysEnabled")?.boolValue ?? false }
    static var style: Style { value("closeViewZoomMode").flatMap { Style(rawValue: $0.intValue) } ?? .fullScreen }
    /// nil until the slider has been moved once.
    static var minFactor: Double? { value("closeViewFarPoint")?.doubleValue }

    static var maxFactor: Double? { value("closeViewNearPoint")?.doubleValue }

    static func text(_ factor: Double) -> String { String(format: "%.2f", factor) }

    static func current(_ shortcut: Shortcut) -> String {
        CFPreferencesAppSynchronize(hotkeysDomain)
        guard let all = CFPreferencesCopyAppValue(hotkeysKey, hotkeysDomain) as? [String: Any],
              let entry = all[shortcut.id] as? [String: Any] else { return shortcut.defaultValue }
        if (entry["enabled"] as? Bool) == false { return "off" }
        guard let value = entry["value"] as? [String: Any], let parameters = value["parameters"] as? [Int],
              parameters.count == 3 else { return shortcut.defaultValue }
        return "\(parameters[1]),\(parameters[2])"
    }

    // MARK: - Writing

    /// Replaces only this shortcut and makes the window server reload the table. Returns false when it did not take.
    @discardableResult
    static func setShortcut(_ shortcut: Shortcut, to value: String) -> Bool {
        CFPreferencesAppSynchronize(hotkeysDomain)
        var all = CFPreferencesCopyAppValue(hotkeysKey, hotkeysDomain) as? [String: Any] ?? [:]
        func entry(_ text: String, enabled: Bool) -> [String: Any]? {
            let numbers = text.split(separator: ",").compactMap { Int($0) }
            guard numbers.count == 2 else { return nil }
            return ["enabled": enabled,
                    "value": ["type": "standard", "parameters": [characters[numbers[0]] ?? 65535, numbers[0], numbers[1]]]]
        }
        if value == "off" {
            var off = all[shortcut.id] as? [String: Any] ?? entry(shortcut.defaultValue, enabled: false) ?? [:]
            off["enabled"] = false
            all[shortcut.id] = off
        } else {
            guard let on = entry(value, enabled: true) else { return false }
            all[shortcut.id] = on
        }
        CFPreferencesSetAppValue(hotkeysKey, all as CFPropertyList, hotkeysDomain)
        CFPreferencesAppSynchronize(hotkeysDomain)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings")
        process.arguments = ["-u"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return current(shortcut) == value
    }

    /// Changes the given items in one visit to the Zoom pane; nil leaves an item as it is. Requires the Accessibility permission.
    @MainActor
    static func apply(hotkeys: Bool?, style: Style?, maxFactor: Double?, minFactor: Double? = nil) async throws {
        try await SystemSettingsSwitch.withPane(pane) { root in
            if let hotkeys {
                try await SystemSettingsSwitch.press(SystemSettingsSwitch.waitFor("AX_ZOOM_ENABLE_HOTKEYS", in: root), to: hotkeys)
            }
            if let style { try await choose(style, in: root) }
            if minFactor != nil || maxFactor != nil {
                if SystemSettingsSwitch.find("AX_ZOOM_MAX_FACTOR", in: root) == nil {
                    AXUIElementPerformAction(try await SystemSettingsSwitch.waitFor("AX_ZOOM_ADVANCED", in: root), kAXPressAction as CFString)
                }
                _ = try await SystemSettingsSwitch.waitFor("AX_ZOOM_MAX_FACTOR", in: root)
            }
            var committed = false
            defer {
                if !committed, minFactor != nil || maxFactor != nil,
                   let cancel = SystemSettingsSwitch.find("AX_CANCEL", in: root) {
                    AXUIElementPerformAction(cancel, kAXPressAction as CFString)
                }
            }
            // Raise the upper limit first when the new lower limit exceeds the old upper limit.
            if let minFactor, let maxFactor, minFactor > (Self.maxFactor ?? 1) {
                try await setFactor(maxFactor, minimum: false, in: root)
                try await setFactor(minFactor, minimum: true, in: root)
            } else {
                if let minFactor { try await setFactor(minFactor, minimum: true, in: root) }
                if let maxFactor { try await setFactor(maxFactor, minimum: false, in: root) }
            }
            if minFactor != nil || maxFactor != nil {
                let ok = try await SystemSettingsSwitch.waitFor("AX_OK", in: root)
                guard AXUIElementPerformAction(ok, kAXPressAction as CFString) == .success else {
                    throw SettingsError(L("システム設定を変更できませんでした。"))
                }
                committed = true
                // The sheet's AX value alone is not proof that the preferences were saved.
                for _ in 0..<20 {
                    if savedFactorsMatch(minimum: minFactor, maximum: maxFactor) { return }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                throw SettingsError(L("システム設定を変更できませんでした。"))
            }
        }
    }

    private static func savedFactorsMatch(minimum: Double?, maximum: Double?) -> Bool {
        (minimum.map { abs((minFactor ?? 1) - $0) < 0.05 } ?? true)
            && (maximum.map { abs((maxFactor ?? 1) - $0) < 0.05 } ?? true)
    }

    @MainActor
    private static func choose(_ style: Style, in root: AXUIElement) async throws {
        let popup = try await SystemSettingsSwitch.waitFor("AX_ZOOM_STYLE_POPUP", in: root)
        guard Self.style != style else { return }
        guard let index = Style.menuOrder.firstIndex(of: style) else { return }
        // The menu appears as the pop-up button's child after the press.
        for _ in 0..<3 {
            AXUIElementPerformAction(popup, kAXPressAction as CFString)
            try await Task.sleep(nanoseconds: 500_000_000)
            if let menu = (SystemSettingsSwitch.attribute(kAXChildrenAttribute, of: popup) as? [AXUIElement])?.first,
               let items = SystemSettingsSwitch.attribute(kAXChildrenAttribute, of: menu) as? [AXUIElement], items.count > index {
                AXUIElementPerformAction(items[index], kAXPressAction as CFString)
                try await Task.sleep(nanoseconds: 500_000_000)
                break
            }
        }
        guard Self.style == style else { throw SettingsError(L("ズーム方法を変更できませんでした。")) }
    }

    /// Drags the requested zoom knob in the open advanced sheet (the slider is linear).
    /// The pointer moves for a moment and is put back.
    @MainActor
    private static func setFactor(_ target: Double, minimum: Bool, in root: AXUIElement) async throws {
        let identifier = minimum ? "AX_ZOOM_MIN_FACTOR" : "AX_ZOOM_MAX_FACTOR"
        let failure = minimum ? L("最小拡大率を変更できませんでした。") : L("最大拡大率を変更できませんでした。")
        let target = min(max(target, maxFactorRange.lowerBound), maxFactorRange.upperBound)
        let slider = try await SystemSettingsSwitch.waitFor(identifier, in: root)
        func number(_ name: String) -> Double? { (SystemSettingsSwitch.attribute(name, of: slider) as? NSNumber)?.doubleValue }
        guard let low = number(kAXMinValueAttribute), let high = number(kAXMaxValueAttribute), high > low
        else { throw SettingsError(failure) }
        if let value = number(kAXValueAttribute), abs(value - target) < 0.05 { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: SystemSettingsSwitch.settingsBundleID).first?.activate()
        try await Task.sleep(nanoseconds: 300_000_000)
        try await reveal(slider, failure: failure)
        let pointer = CGEvent(source: nil)?.location
        defer { if let pointer { post(.mouseMoved, pointer) } }
        for _ in 0..<3 {
            guard let value = number(kAXValueAttribute), let track = frame(of: slider),
                  let knob = (SystemSettingsSwitch.attribute(kAXChildrenAttribute, of: slider) as? [AXUIElement])?.first(where: {
                      SystemSettingsSwitch.attribute(kAXRoleAttribute, of: $0) as? String == kAXValueIndicatorRole
                  }), let start = frame(of: knob), track.width > start.width,
                  visible(track, in: viewport(of: slider)) else { break }
            if abs(value - target) < 0.05 { break }
            // The knob's center runs from half its width inside each end of the track.
            let span = track.width - start.width
            let from = CGPoint(x: start.midX, y: start.midY)
            let to = CGPoint(x: start.midX + (target - value) / (high - low) * span, y: start.midY)
            post(.leftMouseDown, from)
            try await Task.sleep(nanoseconds: 80_000_000)
            for step in 1...8 {
                post(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * Double(step) / 8, y: from.y))
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            post(.leftMouseUp, to)
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        guard let value = number(kAXValueAttribute), abs(value - target) < 0.05 else {
            throw SettingsError(failure)
        }
    }

    /// AX can expose offscreen controls. Never send mouse events until the track is inside its scroll viewport.
    static func visible(_ track: CGRect, in viewport: CGRect?) -> Bool {
        guard let viewport, track.width > 0, track.height > 0 else { return false }
        return viewport.insetBy(dx: -1, dy: -1).contains(track)
    }

    private static func scrollArea(of element: AXUIElement) -> AXUIElement? {
        var current = element
        for _ in 0..<30 {
            guard let parent = SystemSettingsSwitch.attribute(kAXParentAttribute, of: current),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            current = unsafeBitCast(parent, to: AXUIElement.self)
            if SystemSettingsSwitch.attribute(kAXRoleAttribute, of: current) as? String == kAXScrollAreaRole { return current }
        }
        return nil
    }

    private static func viewport(of element: AXUIElement) -> CGRect? {
        scrollArea(of: element).flatMap { frame(of: $0) }
    }

    @MainActor
    private static func reveal(_ slider: AXUIElement, failure: String) async throws {
        AXUIElementPerformAction(slider, "AXScrollToVisible" as CFString)
        for _ in 0..<8 {
            try await Task.sleep(nanoseconds: 150_000_000)
            guard let track = frame(of: slider), let area = scrollArea(of: slider), let viewport = frame(of: area) else { break }
            if visible(track, in: viewport) { return }
            let action = track.midY > viewport.midY ? "AXScrollDownByPage" : "AXScrollUpByPage"
            guard AXUIElementPerformAction(area, action as CFString) == .success else { break }
        }
        throw SettingsError(failure)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = SystemSettingsSwitch.attribute(kAXPositionAttribute, of: element),
              let size = SystemSettingsSwitch.attribute(kAXSizeAttribute, of: element) else { return nil }
        var origin = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: origin, size: extent)
    }

    private static func post(_ type: CGEventType, _ point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}
