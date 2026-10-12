import Foundation

// Pure text rules, transcribed from the Keyboard Maestro macro
// 「コピー時、セル内改行使用時に付加される「"」を削除」 (code points checked with Python).
// No AppKit here, so Tests/RulesTests.swift can compile it alone.

/// How the copied text is cleaned for a target app.
enum CleanProfile: String {
    /// Microsoft Excel: KM "Remove Styles" + one regex, plus unquoting the cells Excel wraps in "".
    case excel
    /// Google Sheets in a browser: KM Else branch (four replacements). Only while a Sheets window is in front.
    case spreadsheet
}

struct TargetApp: Equatable {
    let bundleID: String
    let name: String
    let profile: CleanProfile
}

enum CleanRules {
    /// The four apps of the macro's "Included" targeting, identified by Bundle ID.
    static let targets: [TargetApp] = [
        TargetApp(bundleID: "com.microsoft.Excel", name: "Microsoft Excel", profile: .excel),
        TargetApp(bundleID: "com.google.Chrome", name: "Google Chrome", profile: .spreadsheet),
        TargetApp(bundleID: "com.apple.Safari", name: "Safari", profile: .spreadsheet),
        TargetApp(bundleID: "org.mozilla.firefox", name: "Firefox", profile: .spreadsheet)
    ]

    static func target(for bundleID: String?) -> TargetApp? {
        guard let bundleID else { return nil }
        return targets.first { $0.bundleID == bundleID }
    }

    /// Excel: `(?m)^‑_+\s` where ‑ is U+2011 NON-BREAKING HYPHEN (not U+002D), case-insensitive (KM IgnoreCaseRegEx).
    static let excelPattern = "(?m)^\u{2011}_+\\s"
    /// Browser steps (a)–(c), all KM IgnoreCaseRegEx; (d) is the plain string replacement ' (U+0027) → " (U+0022).
    static let spreadsheetSteps: [(pattern: String, template: String)] = [
        ("(?m)^\"", ""),      // (a) U+0022 at the start of each line → removed
        ("(?m)\"$", ""),      // (b) U+0022 at the end of each line → removed
        ("\"+", "\"")         // (c) a run of U+0022 → one U+0022
    ]
    static let apostrophe = "\u{0027}"
    static let doubleQuote = "\u{0022}"

    /// The macro had no quote step for Excel, so a cell with an in-cell line break kept its "" (user report 2026-10-12).
    static func cleanExcel(_ text: String) -> String {
        replace(unquoteCells(text), pattern: excelPattern, template: "")
    }

    /// Undoes Excel's tab-separated quoting: a cell that starts with " and closes with " right before a tab,
    /// line break or the end loses the outer quotes, and "" inside it becomes ". Any other cell is left as is.
    static func unquoteCells(_ text: String) -> String {
        let quote = UInt16(0x22)
        let separators: Set<UInt16> = [0x09, 0x0A, 0x0D]
        let units = Array(text.utf16)
        var output: [UInt16] = []
        output.reserveCapacity(units.count)
        var index = 0
        var atCellStart = true
        while index < units.count {
            if atCellStart, units[index] == quote, let (content, next) = quotedCell(units, from: index) {
                output += content
                index = next
                atCellStart = false
                continue
            }
            let unit = units[index]
            output.append(unit)
            atCellStart = separators.contains(unit)
            index += 1
        }
        return String(decoding: output, as: UTF16.self)
    }

    /// Reads a quoted cell starting at `start`; nil if it never closes before a separator or the end.
    private static func quotedCell(_ units: [UInt16], from start: Int) -> ([UInt16], Int)? {
        let quote = UInt16(0x22)
        var content: [UInt16] = []
        var index = start + 1
        while index < units.count {
            if units[index] == quote {
                if index + 1 < units.count, units[index + 1] == quote { content.append(quote); index += 2; continue }
                let next = index + 1
                guard next == units.count || [0x09, 0x0A, 0x0D].contains(units[next]) else { return nil }
                return (content, next)
            }
            content.append(units[index])
            index += 1
        }
        return nil
    }

    /// Browser window titles end with the Sheets product name ("… - Google スプレッドシート").
    static let sheetsTitleMarkers = ["Google Sheets", "Google スプレッドシート", "Google 스프레드시트", "Google 表格", "Google 試算表"]
    static func isGoogleSheetsTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        return sheetsTitleMarkers.contains { title.contains($0) }
    }

    /// `replaceApostrophe` is step (d) of the macro (on by default, as in the macro).
    static func cleanSpreadsheet(_ text: String, replaceApostrophe: Bool = true) -> String {
        var result = text
        for step in spreadsheetSteps { result = replace(result, pattern: step.pattern, template: step.template) }
        if replaceApostrophe { result = result.replacingOccurrences(of: apostrophe, with: doubleQuote, options: .caseInsensitive) }
        return result
    }

    static func clean(_ text: String, profile: CleanProfile, replaceApostrophe: Bool = true) -> String {
        switch profile {
        case .excel: return cleanExcel(text)
        case .spreadsheet: return cleanSpreadsheet(text, replaceApostrophe: replaceApostrophe)
        }
    }

    /// Replaces every match (KM "Which: All"). Patterns are constants, so a failure to compile is a programming error.
    private static func replace(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            assertionFailure("Invalid pattern \(pattern)")
            return text
        }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: NSRegularExpression.escapedTemplate(for: template))
    }
}
