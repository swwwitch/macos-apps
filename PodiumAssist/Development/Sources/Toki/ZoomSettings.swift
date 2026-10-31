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
        diagnostic("begin", ["minimum": minFactor as Any, "maximum": maxFactor as Any], reset: true)
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
                    let result = AXUIElementPerformAction(cancel, kAXPressAction as CFString)
                    diagnostic("cancel", ["result": result.rawValue])
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
                    diagnostic("saved-values", ["minimum": Self.minFactor as Any, "maximum": Self.maxFactor as Any])
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
        let identified = try await SystemSettingsSwitch.waitFor(identifier, in: root)
        diagnostic("identified", ["identifier": identifier, "target": target, "tree": snapshot(identified)])
        // Some OS versions place the identifier on a containing accessibility element.
        guard let slider = descendant(role: kAXSliderRole, in: identified) else {
            diagnostic("failure", ["stage": "slider-role", "identifier": identifier])
            throw SettingsError(failure + " [slider-role]")
        }
        diagnostic("slider", ["tree": snapshot(slider)])
        func number(_ name: String) -> Double? { (SystemSettingsSwitch.attribute(name, of: slider) as? NSNumber)?.doubleValue }
        guard let low = number(kAXMinValueAttribute), let high = number(kAXMaxValueAttribute), high > low
        else {
            diagnostic("failure", ["stage": "value-range"])
            throw SettingsError(failure + " [value-range]")
        }
        if let value = number(kAXValueAttribute), abs(value - target) < 0.05 { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: SystemSettingsSwitch.settingsBundleID).first?.activate()
        try await Task.sleep(nanoseconds: 300_000_000)
        let pointer = CGEvent(source: nil)?.location
        defer { if let pointer { post(.mouseMoved, pointer) } }
        try await reveal(slider, failure: failure)
        for attempt in 0..<3 {
            diagnostic("before-drag", ["attempt": attempt, "tree": snapshot(slider), "viewport": String(describing: viewport(of: slider))])
            guard let value = number(kAXValueAttribute), let track = frame(of: slider),
                  let knob = descendant(role: kAXValueIndicatorRole, in: slider),
                  let start = frame(of: knob), track.width > start.width,
                  visible(track, in: viewport(of: slider)) else {
                diagnostic("failure", ["stage": "knob-geometry"])
                throw SettingsError(failure + " [knob-geometry]")
            }
            if abs(value - target) < 0.05 { break }
            // The knob's center runs from half its width inside each end of the track.
            let span = track.width - start.width
            let from = CGPoint(x: start.midX, y: start.midY)
            let to = CGPoint(x: start.midX + (target - value) / (high - low) * span, y: start.midY)
            diagnostic("drag", ["from": "\(from)", "to": "\(to)", "low": low, "high": high, "value": value])
            post(.leftMouseDown, from)
            try await Task.sleep(nanoseconds: 80_000_000)
            for step in 1...8 {
                post(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * Double(step) / 8, y: from.y))
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            post(.leftMouseUp, to)
            try await Task.sleep(nanoseconds: 300_000_000)
            diagnostic("after-drag", ["value": number(kAXValueAttribute) as Any])
        }
        guard let value = number(kAXValueAttribute), abs(value - target) < 0.05 else {
            diagnostic("failure", ["stage": "drag-result", "value": number(kAXValueAttribute) as Any])
            throw SettingsError(failure + " [drag-result]")
        }
    }

    /// AX can expose offscreen controls. Never send mouse events until the track is inside its scroll viewport.
    static func visible(_ track: CGRect, in viewport: CGRect?) -> Bool {
        guard let viewport, track.width > 0, track.height > 0 else { return false }
        return viewport.insetBy(dx: -1, dy: -1).contains(track)
    }

    /// Move the offscreen track toward the viewport center; bounded pixel scroll, negative means down.
    static func scrollDelta(track: CGRect, viewport: CGRect) -> Int32? {
        guard track.minY.isFinite, track.maxY.isFinite, viewport.minY.isFinite, viewport.maxY.isFinite,
              viewport.height > 0, track.height > 0, !visible(track, in: viewport) else { return nil }
        let distance = viewport.midY - track.midY
        guard distance != 0 else { return nil }
        return Int32((distance < 0 ? -1 : 1) * min(200, max(40, abs(distance))))
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
        let result = AXUIElementPerformAction(slider, "AXScrollToVisible" as CFString)
        diagnostic("scroll-to-visible", ["result": result.rawValue])
        var useWheel = false
        var previousTrack: CGRect?
        for _ in 0..<8 {
            try await Task.sleep(nanoseconds: 300_000_000)
            let area = scrollArea(of: slider)
            diagnostic("visibility", ["slider": snapshot(slider), "area": area.map { snapshot($0) } ?? [], "viewport": String(describing: area.flatMap { frame(of: $0) })])
            guard let track = frame(of: slider), let area, let viewport = frame(of: area) else {
                throw SettingsError(failure + " [scroll-area-frame]")
            }
            if visible(track, in: viewport) { return }
            if previousTrack == track { useWheel = true }
            previousTrack = track
            if !useWheel {
                let action = track.midY > viewport.midY ? "AXScrollDownByPage" : "AXScrollUpByPage"
                let result = AXUIElementPerformAction(area, action as CFString)
                diagnostic("scroll-page", ["action": action, "result": result.rawValue])
                if result == .success { continue }
                useWheel = true
            }
            // macOS 26 can advertise AXScrollDownByPage but return cannotComplete.
            // Use an ordinary wheel event inside the scroll area's left padding, away from controls.
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == SystemSettingsSwitch.settingsBundleID,
                  viewport.width > 16, viewport.height > 16,
                  let delta = scrollDelta(track: track, viewport: viewport) else {
                diagnostic("failure", ["stage": "scroll-wheel-target"])
                throw SettingsError(failure + " [scroll-wheel-target]")
            }
            let point = CGPoint(x: viewport.minX + 4, y: viewport.midY)
            post(.mouseMoved, point)
            try await Task.sleep(nanoseconds: 80_000_000)
            guard let wheel = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                      wheel1: delta, wheel2: 0, wheel3: 0) else {
                throw SettingsError(failure + " [scroll-wheel-create]")
            }
            wheel.location = point
            wheel.flags = []
            diagnostic("scroll-wheel", ["delta": delta, "point": "\(point)", "trackBefore": "\(track)"])
            wheel.post(tap: .cghidEventTap)
        }
        diagnostic("failure", ["stage": "reveal"])
        throw SettingsError(failure + " [reveal]")
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = SystemSettingsSwitch.attribute(kAXPositionAttribute, of: element),
              let size = SystemSettingsSwitch.attribute(kAXSizeAttribute, of: element),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: origin, size: extent)
    }

    private static func descendant(role: String, in root: AXUIElement) -> AXUIElement? {
        var pending = [(root, 0)]
        var visited = 0
        while !pending.isEmpty, visited < 64 {
            let (element, depth) = pending.removeFirst()
            visited += 1
            if SystemSettingsSwitch.attribute(kAXRoleAttribute, of: element) as? String == role { return element }
            if depth < 5, let children = SystemSettingsSwitch.attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] {
                pending.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        return nil
    }

    /// Only zoom control metadata; never record other applications, window titles or user text.
    private static func snapshot(_ root: AXUIElement) -> [[String: String]] {
        var pending = [(root, 0)]
        var rows = [[String: String]]()
        while !pending.isEmpty, rows.count < 24 {
            let (element, depth) = pending.removeFirst()
            var row = ["depth": String(depth), "frame": String(describing: frame(of: element))]
            for key in [kAXRoleAttribute, kAXIdentifierAttribute, kAXValueAttribute, kAXMinValueAttribute, kAXMaxValueAttribute, kAXEnabledAttribute] {
                if let value = SystemSettingsSwitch.attribute(key, of: element) { row[key] = String(describing: value) }
            }
            var actions: CFArray?
            let result = AXUIElementCopyActionNames(element, &actions)
            row["actionsResult"] = String(result.rawValue)
            row["actions"] = String(describing: actions)
            rows.append(row)
            if depth < 3, let children = SystemSettingsSwitch.attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] {
                pending.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        return rows
    }

    private static func diagnostic(_ stage: String, _ values: [String: Any], reset: Bool = false) {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/PodiumAssist")
        let url = folder.appendingPathComponent("zoom-last.jsonl")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Stringify optional numeric values so absent preferences are recorded, not dropped by JSON serialization.
        var record = values.mapValues { String(describing: $0) }
        record["stage"] = stage
        record["time"] = ISO8601DateFormatter().string(from: Date())
        guard var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }
        data.append(10)
        if reset { try? data.write(to: url, options: .atomic); return }
        guard let handle = try? FileHandle(forWritingTo: url) else { try? data.write(to: url); return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    private static func post(_ type: CGEventType, _ point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}
