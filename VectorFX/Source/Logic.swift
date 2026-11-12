import Foundation

/// The steps a command takes, for the main window's 「しくみ」 section. `values` are the current effect values.
enum Logic {
    static func steps(for command: Command, values: [String: Double], recorded: (String) -> String?) -> [String] {
        var steps: [String] = []
        let guarded = command.scriptPath == nil
        if guarded { steps.append(L("logic.check")) }
        switch command.action {
        case .menu(let id, let dialog):
            steps.append(String(format: L("logic.menu"), id))
            if dialog { steps.append(L("logic.dialogWait")) }
        case .effect(let kind):
            if command.params.contains(where: { $0.kind == .length }) { steps.append(L("logic.units")) }
            steps.append(String(format: L("logic.effect"), kind.liveEffectName, valueList(command, values)))
            steps.append(String(format: L("logic.effectOption"), kind.dialog))
        case .code(let code):
            steps += L("logic.code." + code.logicKey).components(separatedBy: "¶")
            if case .cap(let cap) = code { steps = steps.map { $0.replacingOccurrences(of: "%CAP%", with: cap) } }
        case .action(let action):
            steps.append(L("logic.tempAction"))
            steps.append(String(format: L("logic.events"), events(in: action.source).joined(separator: " → ")))
        case .namedAction(let set, let name):
            steps.append(String(format: L("logic.namedAction"), set, name))
        case .script:
            steps.append(L("logic.script"))
        }
        steps.append(L(guarded ? "logic.send" : "logic.sendScript"))
        return steps
    }

    private static func valueList(_ command: Command, _ values: [String: Double]) -> String {
        command.params.map { spec in
            let value = values[spec.key] ?? spec.defaultValue
            let text: String
            switch spec.kind {
            case .toggle: text = L(value != 0 ? "logic.on" : "logic.off")
            case .join: text = L(["join.round", "join.bevel", "join.miter"][min(max(Int(value), 0), 2)])
            case .percent: text = ScriptBuilder.number(value) + "%"
            case .length: text = ScriptBuilder.number(value) + " " + L("unit.document")
            case .count: text = ScriptBuilder.number(value)
            }
            return spec.title + " " + text
        }.joined(separator: L("logic.listSeparator"))
    }

    /// The events of an .aia, by their names in the Actions panel; a menu item event shows the menu item.
    static func events(in aia: String) -> [String] {
        let blocks = aia.components(separatedBy: "/event-").dropFirst()
        return blocks.map { block in
            let names = hexNames(in: block)
            // adobe_commandManager: [localizedName, command id, menu name, …] → the menu name.
            if block.contains("(adobe_commandManager)"), names.count >= 3 { return names[2] }
            if block.contains("(ai_plugin_appearance)") || block.contains("(ai_plugin_swatches)"), names.count >= 2 { return names[0] + "：" + names[1] }
            return names.first ?? "?"
        }
    }
    private static func hexNames(in text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: #"\[ \d+\s+([0-9a-f\s]+?)\s*\]"#)
        return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let hex = text[range].filter { !$0.isWhitespace }
            var bytes: [UInt8] = []
            var index = hex.startIndex
            while index < hex.endIndex, let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex), let byte = UInt8(hex[index..<next], radix: 16) {
                bytes.append(byte); index = next
            }
            return String(bytes: bytes, encoding: .utf8)
        }.filter { !$0.isEmpty }
    }
}

extension EffectKind {
    var liveEffectName: String {
        switch self {
        case .dropShadow: return "Adobe Drop Shadow"
        case .offsetPath: return "Adobe Offset Path"
        case .rectangle, .roundedRectangle, .ellipse: return "Adobe Shape Effects"
        case .zigzag: return "Adobe Zigzag"
        case .roughen: return "Adobe Roughen"
        }
    }
}

extension BuiltInCode {
    var logicKey: String {
        switch self {
        case .cap: return "cap"
        case .openPath: return "openPath"
        case .pasteLastStyle: return "pasteLastStyle"
        case .expandUngroup: return "expandUngroup"
        }
    }
}
