import AppKit
import Carbon

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// One entry of Default Folder X's Favorites.plist. The dictionary is kept whole so bookmark data,
/// hotkeys and keys this app does not know are written back unchanged.
struct FavoriteItem: Identifiable {
    let id = UUID()
    var raw: [String: Any]

    /// Default Folder X writes a separator as itemType 4 with url "DXMenuSeparator" and no bookmark (measured on 6.3.3).
    static let separatorType = 4
    static let separatorURL = "DXMenuSeparator"
    static let separatorName = "⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯–––––"
    static func separator(date: Date = Date()) -> FavoriteItem {
        FavoriteItem(raw: ["date": date, "itemType": separatorType, "name": separatorName, "url": separatorURL])
    }

    var isSeparator: Bool { raw["itemType"] as? Int == Self.separatorType || raw["url"] as? String == Self.separatorURL }
    var name: String { raw["name"] as? String ?? "" }
    var date: Date? { raw["date"] as? Date }
    var fileURL: URL? { isSeparator ? nil : (raw["url"] as? String).flatMap(URL.init(string:)) }
    var path: String { fileURL?.path ?? "" }
    var exists: Bool { fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? true }
    /// Key for the in-app category name: "top" for the items before the first separator, otherwise the separator's date.
    var categoryKey: String { date.map { String(format: "%.0f", $0.timeIntervalSinceReferenceDate) } ?? "top" }

    /// The hotkey as ⌃⌥⇧⌘ plus the key's unshifted label on the current keyboard layout, or "".
    var hotkeyText: String {
        guard let hotkey = raw["hotkey"] as? [String: Any], let code = hotkey["keyCode"] as? Int else { return "" }
        let flags = NSEvent.ModifierFlags(rawValue: UInt((hotkey["modifierFlags"] as? Int) ?? 0))
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + (Self.keyLabel(code) ?? (hotkey["charactersIgnoringModifiers"] as? String ?? "").uppercased())
    }
    /// keyCode and NSEvent modifier flags (⌃⌥⇧⌘ only) of the hotkey, or nil.
    var hotkey: (code: Int, flags: NSEvent.ModifierFlags)? {
        guard let hotkey = raw["hotkey"] as? [String: Any], let code = hotkey["keyCode"] as? Int else { return nil }
        let flags = NSEvent.ModifierFlags(rawValue: UInt((hotkey["modifierFlags"] as? Int) ?? 0)).intersection([.control, .option, .shift, .command])
        return (code, flags)
    }
    mutating func setHotkey(code: Int, flags: NSEvent.ModifierFlags) { raw["hotkey"] = Self.hotkeyDictionary(code: code, flags: flags) }
    mutating func clearHotkey() { raw["hotkey"] = nil }

    /// Arrow, function and editing keys: NSEvent reports them as private-use characters and adds the function flag.
    static let functionKeyCharacters: [Int: Int] = [
        kVK_UpArrow: 0xF700, kVK_DownArrow: 0xF701, kVK_LeftArrow: 0xF702, kVK_RightArrow: 0xF703,
        kVK_F1: 0xF704, kVK_F2: 0xF705, kVK_F3: 0xF706, kVK_F4: 0xF707, kVK_F5: 0xF708, kVK_F6: 0xF709, kVK_F7: 0xF70A, kVK_F8: 0xF70B,
        kVK_F9: 0xF70C, kVK_F10: 0xF70D, kVK_F11: 0xF70E, kVK_F12: 0xF70F, kVK_F13: 0xF710, kVK_F14: 0xF711, kVK_F15: 0xF712,
        kVK_F16: 0xF713, kVK_F17: 0xF714, kVK_F18: 0xF715, kVK_F19: 0xF716, kVK_F20: 0xF717,
        kVK_ForwardDelete: 0xF728, kVK_Home: 0xF729, kVK_End: 0xF72B, kVK_PageUp: 0xF72C, kVK_PageDown: 0xF72D, kVK_Help: 0xF746,
    ]
    /// The hotkey as Default Folder X writes it: the NSEvent of the key press, i.e. `characters` with every modifier applied
    /// (⌃ gives control characters) and `charactersIgnoringModifiers` with only ⇧ applied, on the current keyboard layout.
    static func hotkeyDictionary(code: Int, flags: NSEvent.ModifierFlags) -> [String: Any] {
        var flags = flags.intersection([.control, .option, .shift, .command])
        let characters: String, ignoring: String
        if let scalar = functionKeyCharacters[code].flatMap(Unicode.Scalar.init) {
            flags.insert(.function)
            characters = String(Character(scalar)); ignoring = characters
        } else {
            var state: UInt32 = 0
            if flags.contains(.shift) { state |= UInt32(shiftKey >> 8) }
            ignoring = translate(code, state: state) ?? ""
            if flags.contains(.option) { state |= UInt32(optionKey >> 8) }
            if flags.contains(.control) { state |= UInt32(controlKey >> 8) }
            if flags.contains(.command) { state |= UInt32(cmdKey >> 8) }
            characters = translate(code, state: state) ?? ignoring
        }
        return ["characters": characters, "charactersIgnoringModifiers": ignoring, "keyCode": code, "modifierFlags": Int(flags.rawValue)]
    }
    /// The character a key types with the given Carbon modifier state (already shifted right by 8) on the current layout.
    static func translate(_ code: Int, state: UInt32, display: Bool = false) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0, length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { bytes in
            UCKeyTranslate(bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress!, UInt16(code), UInt16(display ? kUCKeyActionDisplay : kUCKeyActionDown), state,
                           UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    static func keyLabel(_ code: Int) -> String? {
        let named: [Int: String] = [kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_Escape: "⎋", kVK_ForwardDelete: "⌦",
                                    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
                                    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
                                    kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"]
        return named[code] ?? translate(code, state: 0, display: true)?.uppercased()
    }
}

/// A run of items: before the first separator (no separator) or a separator and the items after it.
struct Category: Identifiable {
    var id: String { key }
    let key: String
    /// Index of the separator in the item list, nil for the first category.
    let separatorIndex: Int?
    /// Indices of the favorites (not the separator).
    let range: Range<Int>
}

enum SortOrder: String, CaseIterable {
    case name, nameDescending, path, newest, oldest
    func areInOrder(_ a: FavoriteItem, _ b: FavoriteItem) -> Bool {
        switch self {
        case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .nameDescending: return a.name.localizedStandardCompare(b.name) == .orderedDescending
        case .path: return a.path.localizedStandardCompare(b.path) == .orderedAscending
        case .newest: return (a.date ?? .distantPast) > (b.date ?? .distantPast)
        case .oldest: return (a.date ?? .distantPast) < (b.date ?? .distantPast)
        }
    }
}

enum Favorites {
    static func categories(_ items: [FavoriteItem]) -> [Category] {
        var result: [Category] = []
        var start = 0, separator: Int? = nil
        for (index, item) in items.enumerated() where item.isSeparator {
            result.append(Category(key: separator.map { items[$0].categoryKey } ?? "top", separatorIndex: separator, range: start..<index))
            separator = index; start = index + 1
        }
        result.append(Category(key: separator.map { items[$0].categoryKey } ?? "top", separatorIndex: separator, range: start..<items.count))
        return result
    }

    /// Sorts the favorites inside each category (or only the categories listed in `only`). Separators stay where they are.
    /// The sort is stable, so equal names keep their current order.
    static func sorted(_ items: [FavoriteItem], by order: SortOrder, only keys: Set<String>? = nil) -> [FavoriteItem] {
        var result = items
        for category in categories(items) where keys?.contains(category.key) ?? true {
            let part = Array(items[category.range]).enumerated().sorted { a, b in
                order.areInOrder(a.element, b.element) || (!order.areInOrder(b.element, a.element) && a.offset < b.offset)
            }.map(\.element)
            result.replaceSubrange(category.range, with: part)
        }
        return result
    }

    /// Moves the given favorites to the end of the category `key`, keeping their order. Separators in `ids` are ignored.
    static func moving(_ ids: Set<UUID>, to key: String, in items: [FavoriteItem]) -> [FavoriteItem] {
        let moved = items.filter { ids.contains($0.id) && !$0.isSeparator }
        var rest = items.filter { !(ids.contains($0.id) && !$0.isSeparator) }
        guard let target = categories(rest).first(where: { $0.key == key }) else { return items }
        rest.insert(contentsOf: moved, at: target.range.upperBound)
        return rest
    }

    /// Moves a whole category (its separator and favorites) one place up or down. The first category has no separator and does not move.
    static func movingCategory(_ key: String, by offset: Int, in items: [FavoriteItem]) -> [FavoriteItem] {
        let all = categories(items)
        guard let index = all.firstIndex(where: { $0.key == key }), let separator = all[index].separatorIndex else { return items }
        let target = index + offset
        guard target >= 1, target < all.count else { return items }
        let block = Array(items[separator..<all[index].range.upperBound])
        var rest = items; rest.removeSubrange(separator..<all[index].range.upperBound)
        // Insert before the target's separator (up) or after the target's favorites (down), measured in `rest`.
        let insertAt: Int
        if offset < 0 { insertAt = all[target].separatorIndex! }
        else { insertAt = all[target].range.upperBound - block.count }
        rest.insert(contentsOf: block, at: insertAt)
        return rest
    }

    static func read(_ url: URL) throws -> [FavoriteItem] {
        let data = try Data(contentsOf: url)
        guard let array = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return array.map { FavoriteItem(raw: $0) }
    }
    static func data(_ items: [FavoriteItem]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: items.map(\.raw), format: .xml, options: 0)
    }
    /// What Default Folder X would show: order, names, targets and hotkeys. Used to tell whether the file changed under us.
    static func fingerprint(_ items: [FavoriteItem]) -> [String] {
        items.map { "\($0.raw["itemType"] ?? "")|\($0.name)|\($0.raw["url"] ?? "")|\($0.hotkeyText)" }
    }
}

/// Dropbox folders on this Mac, from ~/.dropbox/info.json (personal and business accounts). Without it, a top-level
/// home folder named "Dropbox", "… Dropbox" or "Dropbox (…)" and ~/Library/CloudStorage/Dropbox* count.
enum Dropbox {
    static let roots: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if let data = try? Data(contentsOf: URL(fileURLWithPath: home + "/.dropbox/info.json")),
           let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let paths = info.values.compactMap { ($0 as? [String: Any])?["path"] as? String }
            if !paths.isEmpty { return paths }
        }
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: home)) ?? []).filter { $0 == "Dropbox" || $0.hasSuffix(" Dropbox") || $0.hasPrefix("Dropbox (") }
        let cloud = ((try? FileManager.default.contentsOfDirectory(atPath: home + "/Library/CloudStorage")) ?? []).filter { $0.hasPrefix("Dropbox") }
        return names.map { home + "/" + $0 } + cloud.map { home + "/Library/CloudStorage/" + $0 }
    }()
    /// The Dropbox folder that contains `path`, or nil.
    static func root(containing path: String, roots: [String] = roots) -> String? {
        roots.first { path == $0 || path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
    }
}

extension FavoriteItem {
    var dropboxRoot: String? { isSeparator ? nil : Dropbox.root(containing: path) }
    /// The path to show: inside Dropbox relative to its folder (the row carries a Dropbox mark), otherwise with ~.
    var displayPath: String {
        if let root = dropboxRoot { return String(path.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
        return (path as NSString).abbreviatingWithTildeInPath
    }
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        return !isSeparator && words.allSatisfy { name.localizedCaseInsensitiveContains($0) || path.localizedCaseInsensitiveContains($0) }
    }
}
