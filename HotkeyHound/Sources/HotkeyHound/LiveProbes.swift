import AppKit
@preconcurrency import ApplicationServices
import Carbon

/// 起動中のアプリのメニューに付いたホットキー（アクセシビリティで読む）
enum MenuHotkeys {
    struct Target: Sendable { let pid: pid_t; let name: String; let bundleID: String? }

    /// 1本ぶんを読む。メニューの多いアプリでも止まらないよう項目数と待ち時間に上限を設ける
    static func scan(_ target: Target) -> [HotkeyEntry] {
        guard AXIsProcessTrusted() else { return [] }
        let app = AXUIElementCreateApplication(target.pid)
        AXUIElementSetMessagingTimeout(app, 1.0)
        guard let bar = copy(app, kAXMenuBarAttribute) else { return [] }
        let menuBar = bar as! AXUIElement
        var entries: [HotkeyEntry] = []
        var budget = 6000
        let topItems = children(menuBar)
        // 先頭は Apple メニュー（どのアプリでも同じ）なので読まない
        for item in topItems.dropFirst() {
            let title = string(item, kAXTitleAttribute) ?? ""
            for menu in children(item) {
                walk(menu, path: [title], target: target, into: &entries, budget: &budget, depth: 0)
            }
            if budget <= 0 { break }
        }
        return entries
    }

    nonisolated(unsafe) private static let attributes = [kAXTitleAttribute, kAXMenuItemCmdCharAttribute, kAXMenuItemCmdVirtualKeyAttribute,
                                     kAXMenuItemCmdGlyphAttribute, kAXMenuItemCmdModifiersAttribute, kAXChildrenAttribute] as CFArray

    private static func walk(_ menu: AXUIElement, path: [String], target: Target, into entries: inout [HotkeyEntry], budget: inout Int, depth: Int) {
        guard depth < 6 else { return }
        for item in children(menu) {
            budget -= 1
            if budget <= 0 { return }
            var values: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(item, attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values) == .success,
                  let list = values as? [Any], list.count == 6 else { continue }
            let title = list[0] as? String ?? ""
            if let combo = combo(char: list[1] as? String, virtualKey: list[2] as? Int, glyph: list[3] as? Int, modifiers: list[4] as? Int) {
                var entry = HotkeyEntry(source: .menus, combo: combo, title: title.isEmpty ? L("（名前なし）") : title,
                                        group: target.name + " › " + path.joined(separator: " › "),
                                        scope: L("%@が前面のとき", target.name))
                entry.ownerBundleID = target.bundleID
                entry.ownerPID = target.pid
                entries.append(entry)
            }
            if let submenus = list[5] as? [AXUIElement] {
                for submenu in submenus {
                    walk(submenu, path: path + [title], target: target, into: &entries, budget: &budget, depth: depth + 1)
                }
            }
        }
    }

    /// AXMenuItemCmd* から組み合わせを作る。修飾は ⇧1・⌥2・⌃4・⌘なし8
    static func combo(char: String?, virtualKey: Int?, glyph: Int?, modifiers: Int?) -> KeyCombo? {
        let flags = modifiers ?? 0
        var mods: KeyModifiers = []
        if flags & 8 == 0 { mods.insert(.command) }
        if flags & 1 != 0 { mods.insert(.shift) }
        if flags & 2 != 0 { mods.insert(.option) }
        if flags & 4 != 0 { mods.insert(.control) }
        if let glyph, glyph > 0, let code = KeyNames.menuGlyphs[glyph] {
            return KeyCombo(keyCode: code, modifiers: mods)
        }
        if let char, !char.isEmpty, char != "\u{0}" {
            guard let key = KeyNames.keyCode(forCharacter: char, caseImpliesShift: false) else { return nil }
            if key.shift { mods.insert(.shift) }
            return KeyCombo(keyCode: key.keyCode, modifiers: mods)
        }
        // 文字も記号も無い項目はホットキーなし（仮想キーだけが入っていることがあるので見ない）
        _ = virtualKey
        return nil
    }

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }
    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        copy(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }
}

/// キー入力を受け取れるイベントタップを持つプロセス
enum EventTapProbe {
    @MainActor static func interceptors() -> [InterceptorInfo] {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success, count > 0 else { return [] }
        var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        guard CGGetEventTapList(count, &taps, &count) == .success else { return [] }
        let keyMask = UInt64(1) << CGEventType.keyDown.rawValue
        let me = ProcessInfo.processInfo.processIdentifier
        var seen: [pid_t: InterceptorInfo] = [:]
        for tap in taps.prefix(Int(count)) where tap.enabled && tap.eventsOfInterest & keyMask != 0 {
            let pid = pid_t(tap.tappingProcess)
            guard pid != me else { continue }
            let canModify = tap.options == .defaultTap
            guard let app = NSRunningApplication(processIdentifier: pid) else { continue }
            // 監視だけ（listenOnly）のシステム部品は省く
            if !canModify && (app.bundleIdentifier ?? "").hasPrefix("com.apple.") { continue }
            let previous = seen[pid]
            seen[pid] = InterceptorInfo(id: pid, name: app.localizedName ?? app.bundleIdentifier ?? "pid \(pid)",
                                        bundleID: app.bundleIdentifier, canModify: canModify || (previous?.canModify ?? false))
        }
        return seen.values.sorted { ($0.canModify ? 0 : 1, $0.name) < ($1.canModify ? 0 : 1, $1.name) }
    }
}

/// システム（またはほかのアプリ）が専有登録しているかを、同じキーを専有で登録してみて判定する。
/// 共有で登録しているアプリ（多くのランチャー・常駐ツール）はここでは分からない
enum ExclusiveHotkeyProbe {
    @MainActor static func isReserved(_ combo: KeyCombo) -> Bool {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x48484E44), id: 99)
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.carbonFlags, id,
                                         GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref)
        if let ref { UnregisterEventHotKey(ref) }
        return status == OSStatus(eventHotKeyExistsErr)
    }
}
