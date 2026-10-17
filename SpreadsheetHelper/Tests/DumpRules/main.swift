import Foundation
// Prints the rule constants as JSON for Tests/check_km_macro.py.
let output: [String: Any] = [
    "excel": CleanRules.excelPattern,
    "steps": CleanRules.spreadsheetSteps.map { [$0.pattern, $0.template] },
    "apostrophe": [CleanRules.apostrophe, CleanRules.doubleQuote],
    "targets": CleanRules.targets.map { [$0.bundleID, $0.profile.rawValue] }
]
let data = try! JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
