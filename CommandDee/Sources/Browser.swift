import AppKit

enum Browser {
    static let identifiers = ["com.apple.finder", "com.cocoatech.PathFinder", "com.cocoatech.PathFinder-setapp"]

    static func selection(from id: String) throws -> [URL] {
        guard identifiers.contains(id) else { return [] }
        let expression = id == "com.apple.finder" ? "POSIX path of (f as alias)" : "POSIX path of f"
        let source = """
        with timeout of 10 seconds
          tell application id "\(id)"
            set selectedItems to (get selection)
            if selectedItems is missing value then return {}
            set paths to {}
            repeat with f in selectedItems
              set end of paths to \(expression)
            end repeat
            return paths
          end tell
        end timeout
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)!.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? -1
            let message = code == -1743
                ? "システム設定 → プライバシーとセキュリティ → オートメーションで、CommandDeeによるFinder／Path Finderの操作を許可してください。"
                : String(describing: error[NSAppleScript.errorMessage] ?? "選択ファイルを取得できませんでした。")
            throw NSError(domain: "CommandDee.AppleScript", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard result.numberOfItems > 0 else { return [] }
        return (1...result.numberOfItems).compactMap { result.atIndex($0)?.stringValue }
            .filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0) }
    }
}
