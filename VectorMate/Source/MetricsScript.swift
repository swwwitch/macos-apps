import Foundation

/// The ExtendScript run in Illustrator after a click or key in it, and the reading of its answer (no AppKit, so it is testable).
/// Proportional metrics is turned on only when a selection that was not Metrics becomes Metrics (and, with `turnOff`,
/// off when Metrics becomes another method), so changing it by hand afterwards is respected.
enum MetricsScript {
    /// What the previous check saw: the selection (percent-encoded by the script) and one letter per text range
    /// ("A" = Metrics / AutoKernType.AUTO, "O" = anything else).
    struct Snapshot: Equatable {
        var signature: String
        var kinds: String
    }

    enum Answer: Equatable {
        /// No document, or no text selected.
        case noText
        case checked(Snapshot, turnedOn: Int, turnedOff: Int)
        case unreadable(String)
    }

    /// Ranges beyond this are not looked at (a huge selection would make every click slow).
    static let maxRanges = 200

    static func source(previous: Snapshot?, turnOff: Bool) -> String {
        let signature = previous.map { jsString($0.signature) } ?? "\"\""
        let kinds = previous.map { jsString($0.kinds) } ?? "\"\""
        return """
        (function (prevSig, prevKinds, turnOff) {
            /* position (the bounds) moves when kerning changes the width; the anchor (start of the baseline) does not */
            function frameKey(frame) {
                var p;
                try { p = frame.anchor; } catch (e) {}
                if (!p) { try { p = frame.position; } catch (e2) { return "?"; } }
                return Math.round(p[0] * 100) + "," + Math.round(p[1] * 100);
            }
            if (app.documents.length === 0) return "none";
            var doc = app.activeDocument;
            var sel = doc.selection;
            var ranges = [], keys = [];
            if (sel && sel.typename === "TextRange") {
                ranges.push(sel);
                var story = "?";
                try { story = frameKey(sel.story.textFrames[0]); } catch (e) {}
                keys.push("r" + sel.characterOffset + ":" + sel.length + "@" + story);
            } else if (sel) {
                for (var i = 0; i < sel.length && ranges.length < \(maxRanges); i++) {
                    if (sel[i].typename === "TextFrame") { ranges.push(sel[i].textRange); keys.push("f" + frameKey(sel[i])); }
                }
            }
            if (ranges.length === 0) return "none";
            var sig = encodeURIComponent(doc.name + "|" + keys.join(";"));
            var kinds = "", turnedOn = 0, turnedOff = 0;
            for (var j = 0; j < ranges.length; j++) {
                var attributes = ranges[j].characterAttributes;
                var metrics = String(attributes.kerningMethod) === "AutoKernType.AUTO";
                kinds += metrics ? "A" : "O";
                if (sig !== prevSig) continue;
                try {
                    if (metrics && prevKinds.charAt(j) === "O" && !attributes.proportionalMetrics) { attributes.proportionalMetrics = true; turnedOn++; }
                    else if (turnOff && !metrics && prevKinds.charAt(j) === "A" && attributes.proportionalMetrics) { attributes.proportionalMetrics = false; turnedOff++; }
                } catch (e) {}
            }
            return "ok\\n" + sig + "\\n" + kinds + "\\n" + turnedOn + "\\n" + turnedOff;
        })(\(signature), \(kinds), \(turnOff))
        """
    }

    static func parse(_ output: String) -> Answer {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if text == "none" { return .noText }
        let lines = text.components(separatedBy: "\n")
        guard lines.count == 5, lines[0] == "ok", let on = Int(lines[3]), let off = Int(lines[4]),
              lines[2].allSatisfy({ $0 == "A" || $0 == "O" }) else { return .unreadable(text) }
        return .checked(Snapshot(signature: lines[1], kinds: lines[2]), turnedOn: on, turnedOff: off)
    }

    /// A double-quoted JavaScript literal.
    static func jsString(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            default:
                if scalar.value < 0x20 || scalar.value == 0x2028 || scalar.value == 0x2029 { out += String(format: "\\u%04x", scalar.value) }
                else { out.unicodeScalars.append(scalar) }
            }
        }
        return out + "\""
    }

    /// `tell application "<path>" to do javascript "<js>"` for osascript's standard input.
    static func appleScript(appPath: String, javascript: String, timeout: Int) -> String {
        """
        with timeout of \(timeout) seconds
            tell application \(quoted(appPath)) to do javascript \(quoted(javascript))
        end timeout
        """
    }
    /// An AppleScript string literal.
    static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
