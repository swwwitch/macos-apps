import AppKit

struct BrowserState {
    let id: String
    let name: String
    var files: [URL] = []
    var destinations: [Destination] = []
    var error: String?
}
enum BrowserReader {
    static func bringDestinationForward(_ destination: Destination, preferredID: String?) -> String? {
        let running = apps()
        let id: String
        if destination.origin.hasPrefix("Path Finder") {
            id = running.first { $0.bundleIdentifier?.hasPrefix("com.cocoatech.PathFinder") == true }?.bundleIdentifier ?? "com.apple.finder"
        } else if destination.origin.hasPrefix("Finder") {
            id = "com.apple.finder"
        } else {
            id = running.first { $0.bundleIdentifier == preferredID }?.bundleIdentifier ?? "com.apple.finder"
        }
        func quoted(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let path = destination.url.standardizedFileURL.path
        let target = id == "com.apple.finder" ? "POSIX path of (target of Finder window n as alias)" : "POSIX path of (target of Finder window n)"
        let restore = id == "com.apple.finder" ? "set collapsed of Finder window n to false" : "set visible of Finder window n to true"
        let source = """
        with timeout of 10 seconds
          tell application id \(quoted(id))
            repeat with n from 1 to (count Finder windows)
              try
                set folderPath to \(target)
                if folderPath is \(quoted(path)) or folderPath is \(quoted(path + "/")) then
                  \(restore)
                  set index of Finder window n to 1
                  activate
                  return
                end if
              end try
            end repeat
            open (POSIX file \(quoted(path)) as alias)
            activate
          end tell
        end timeout
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return L("移動先を表示する処理を作成できませんでした。") }
        script.executeAndReturnError(&error)
        return error.map { L("ファイルの移動は完了しましたが、移動先を表示できませんでした。\n%@", String(describing: $0[NSAppleScript.errorMessage] ?? $0)) }
    }
    static func read(_ app: NSRunningApplication) -> BrowserState {
        let id = app.bundleIdentifier ?? ""
        let isFinder = id == "com.apple.finder"
        let name = isFinder ? "Finder" : "Path Finder"
        var state = BrowserState(id: id, name: name)
        let selection = isFinder ? "POSIX path of (f as alias)" : "POSIX path of f"
        let target = isFinder ? "POSIX path of (target of Finder window windowNumber as alias)" : "POSIX path of (target of Finder window windowNumber)"
        let selectionRead = isFinder ? """
            try
              set selectedItems to selection as alias list
            on error messageText number errorNumber
              if errorNumber is not -2763 and errorNumber is not -1728 then error messageText number errorNumber
              set selectedItems to {}
            end try
        """ : """
            set selectedItems to (get selection)
            if selectedItems is missing value then set selectedItems to {}
        """
        let script = """
        with timeout of 15 seconds
          tell application id "\(id)"
            set chosenFiles to {}
            \(selectionRead)
            repeat with f in selectedItems
              set end of chosenFiles to \(selection)
            end repeat
            set destinationPaths to {}
            set windowErrors to {}
            repeat with windowNumber from 1 to (count Finder windows)
              try
                set end of destinationPaths to \(target)
              on error messageText
                set end of windowErrors to messageText
              end try
            end repeat
            return {chosenFiles, destinationPaths, windowErrors}
          end tell
        end timeout
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { state.error = L("%@: スクリプトを生成できません。", String(describing: name)); return state }
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            state.error = code == -1743 ? L("%@の操作が許可されていません。システム設定 → プライバシーとセキュリティ → オートメーションを確認してください。", String(describing: name)) : "\(name): \(error[NSAppleScript.errorMessage] ?? error)"
            return state
        }
        func strings(_ descriptor: NSAppleEventDescriptor?) -> [URL] {
            guard let descriptor, descriptor.numberOfItems > 0 else { return [] }
            return (1...descriptor.numberOfItems).compactMap { descriptor.atIndex($0)?.stringValue }.filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0) }
        }
        if let warnings = result.atIndex(3), warnings.numberOfItems > 0 {
            state.error = name + ": " + ((1...warnings.numberOfItems).compactMap { warnings.atIndex($0)?.stringValue }).joined(separator: "; ")
        }
        state.files = strings(result.atIndex(1))
        state.destinations = strings(result.atIndex(2)).compactMap {
            let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            #if APP_STORE
            // Browser targets can be outside the sandbox until the user grants access.
            // Preserve these paths so selecting a destination can request permission.
            if values == nil { return Destination(url: $0, origin: name) }
            #endif
            return values?.isDirectory == true && values?.isPackage != true ? Destination(url: $0, origin: name) : nil
        }
        return state
    }
    static func apps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            ["com.apple.finder", "com.cocoatech.PathFinder", "com.cocoatech.PathFinder-setapp"].contains($0.bundleIdentifier ?? "")
        }.sorted { ($0.bundleIdentifier ?? "") < ($1.bundleIdentifier ?? "") }
    }
}
