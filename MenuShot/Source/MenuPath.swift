import AppKit
import ApplicationServices

enum MenuPathReader {
    static func read() -> String? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
            var result: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success ? result : nil
        }
        func children(_ element: AXUIElement) -> [AXUIElement] {
            value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        guard let raw = value(application, kAXMenuBarAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let bar = unsafeBitCast(raw, to: AXUIElement.self)
        var budget = 400
        func selectedPath(_ element: AXUIElement, depth: Int) -> [String]? {
            guard depth < 15, budget > 0 else { return nil }
            budget -= 1
            let selected = value(element, kAXSelectedChildrenAttribute) as? [AXUIElement] ?? []
            let items = children(element)
            for child in selected + items.filter({ item in
                (value(item, kAXSelectedAttribute) as? Bool == true) || children(item).contains { value($0, kAXRoleAttribute) as? String == kAXMenuRole }
            }) {
                let title = value(child, kAXTitleAttribute) as? String ?? ""
                let descendants = selectedPath(child, depth: depth + 1)
                if let descendants { return (title.isEmpty ? [] : [title]) + descendants }
                if !title.isEmpty && (selected.contains(where: { CFEqual($0, child) }) || value(child, kAXSelectedAttribute) as? Bool == true) { return [title] }
            }
            // Menu containers themselves have no title; follow their selected children.
            for child in items where value(child, kAXRoleAttribute) as? String == kAXMenuRole {
                if let path = selectedPath(child, depth: depth + 1) { return path }
            }
            return nil
        }
        return selectedPath(bar, depth: 0)?.joined(separator: "→")
    }
}

enum MenuPathFormat {
    static func render(_ input: [String], style: Int, appendClick: Bool = false) -> String {
        let parts = input.map { item -> String in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.precomposedStringWithCanonicalMapping
        }
        let base = format(parts, style: style)
        return base.isEmpty ? "" : base + (appendClick ? "をクリック" : "")
    }
    private static func format(_ parts: [String], style: Int) -> String {
        guard let first = parts.first else { return "" }
        if parts.count == 1 && style == 0 { return "［" + first + "］" }
        if parts.count == 1 && style == 1 { return "「" + first + "」" }
        switch style {
        case 0: return "［" + first + "］メニューの" + parts.dropFirst().map { "［" + $0 + "］" }.joined(separator: "→")
        case 1: return "「" + first + "」メニューの" + parts.dropFirst().map { "「" + $0 + "」" }.joined(separator: "→")
        case 2: return parts.map { "「" + $0 + "」" }.joined(separator: " > ")
        case 3: return parts.map { "「" + $0 + "」" }.joined(separator: "＞")
        case 4: return parts.joined(separator: " > ")
        case 6: return parts.joined(separator: "／")
        default: return parts.joined(separator: "＞")
        }
    }
}
