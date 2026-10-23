import AppKit
import ApplicationServices
import Carbon

enum CommandOutcome {
    case done
    /// Keynote cannot do it now (menu item disabled, typing text): the key goes back to Keynote.
    case passThrough
    /// An AppleScript job finished; the count of objects or slides the command's first script changed.
    case scripted(Int)
    case autoMagicMoveRunning
    case autoMagicMovePartial(changed: Int, error: Int)
    case menuNotFound
    case buttonNotFound
    /// KeynoteSweeper's item is not in Keynote ▸ Services.
    case serviceMissing
    /// The service was started; KeynoteSweeper reports failures itself.
    case serviceStarted
    case eventFailed
    case noDocument
    /// Keynote did not allow Apple events from this app (error -1743).
    case automationDenied
    case scriptFailed(Int)
    case exporting
    case exported(URL)
    case exportNeedsSave
    case exportFailed(Int)
}

/// Runs the steps of one command against the front Keynote. `busy` covers delayed steps and the PNG export.
@MainActor
final class CommandRunner {
    private(set) var busy = false

    func run(_ command: KeynoteCommand, pid: pid_t, bundleID: String, report: @escaping (CommandOutcome) -> Void) {
        guard !busy else { return }
        var remaining = command.steps[...]
        var first = true
        var result = CommandOutcome.done
        busy = true
        func finish(_ outcome: CommandOutcome) { busy = false; report(outcome) }
        func next() {
            while let step = remaining.popFirst() {
                let isFirst = first
                first = false
                switch step {
                case .wait(let seconds):
                    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { next() }
                    return
                case .key(let code, let flags):
                    guard Self.key(code, flags, to: pid) else { return finish(.eventFailed) }
                case .menu(let candidates):
                    switch Self.pressMenu(pid: pid, candidates: candidates) {
                    case .pressed: break
                    // Only the key's own first step hands it back; later a missing item means the command broke.
                    case .disabled: return finish(isFirst ? .passThrough : .eventFailed)
                    case .missing: return finish(.menuNotFound)
                    case .failed: return finish(.eventFailed)
                    }
                case .optionalMenu(let candidates):
                    _ = Self.pressMenu(pid: pid, candidates: candidates)
                case .service(let names):
                    let path: MenuPath = [.any(["Keynote"]), .any(["サービス", "Services", "服务", "서비스"]), .any(names)]
                    switch Self.pressMenu(pid: pid, candidates: [path]) {
                    case .pressed: result = .serviceStarted
                    case .disabled, .missing: return finish(.serviceMissing)
                    case .failed: return finish(.eventFailed)
                    }
                case .expandFill:
                    guard Self.expandFill(pid: pid) else { return finish(.buttonNotFound) }
                case .pressButton(let names):
                    guard Self.pressButton(pid: pid, names: names) else { return finish(.buttonNotFound) }
                case .script(let job):
                    if job == .autoMagicMove {
                        report(.autoMagicMoveRunning)
                        runAutoMagicMove(bundleID: bundleID) { finish($0) }
                        return
                    }
                    switch Self.runScript(job.source(bundleID: bundleID)) {
                    case .success(let text):
                        let count = Int(text) ?? 0
                        if case .done = result { result = .scripted(count) }
                        // Nothing selected: stop before the follow-up menu steps and say why.
                        if count == 0 { return finish(result) }
                    case .failure(let error): return finish(Self.outcome(error))
                    }
                case .exportPNG:
                    report(.exporting)
                    exportCurrentSlide(bundleID: bundleID) { [weak self] outcome in self?.busy = false; report(outcome) }
                    return
                }
            }
            finish(result)
        }
        next()
    }

    /// A document-wide operation runs out of process, leaving menus and busy/quit guards responsive.
    private func runAutoMagicMove(bundleID: String, completion: @escaping (CommandOutcome) -> Void) {
        let source = AutoMagicMoveScript.source(bundleID: bundleID)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.runScriptProcess(source)
            let outcome: CommandOutcome
            switch result {
            case .success(let output):
                switch AutoMagicMoveResult(output: output) {
                case .completed(let count): outcome = .scripted(count)
                case .partial(let count, let error): outcome = .autoMagicMovePartial(changed: count, error: error)
                case nil: outcome = .scriptFailed(-2700)
                }
            case .failure(let error): outcome = Self.outcome(error)
            }
            DispatchQueue.main.async { completion(outcome) }
        }
    }

    nonisolated static func runScriptProcess(_ source: String) -> Result<String, NSError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do { try process.run() }
        catch { return .failure(NSError(domain: "AppleScript", code: -2700)) }
        // Only a short result/error is emitted; document contents never enter these pipes.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus == 0 { return .success(String(data: data, encoding: .utf8) ?? "") }
        let message = String(data: errorData, encoding: .utf8) ?? ""
        var code = Int(process.terminationStatus)
        if let range = message.range(of: #"\((-?\d+)\)\s*$"#, options: .regularExpression),
           let number = Int(message[range].trimmingCharacters(in: CharacterSet(charactersIn: "() \n"))) { code = number }
        return .failure(NSError(domain: "AppleScript", code: code))
    }

    nonisolated static func outcome(_ error: NSError) -> CommandOutcome {
        switch error.code {
        case -1743: return .automationDenied
        case -1728, -1719: return .noDocument
        default: return .scriptFailed(error.code)
        }
    }

    // MARK: PNG export

    /// KM「82)【書き出し】書き出し（PNG）」: the current slide as <document name>-p<NNN>.png next to the document.
    /// Keynote exports every slide into a temporary folder; only the current one is kept. An existing file is never replaced.
    private func exportCurrentSlide(bundleID: String, report: @escaping (CommandOutcome) -> Void) {
        let query = "tell application id \"\(bundleID)\"\nif not (exists front document) then error number -1728\ntell front document\n"
            + "set f to file of it\nif f is missing value then return \"\"\n"
            + "return (id as text) & linefeed & (slide number of current slide as text) & linefeed & POSIX path of (f as alias)\nend tell\nend tell"
        let info: [String]
        switch Self.runScript(query) {
        case .success(let text): info = text.components(separatedBy: "\n")
        case .failure(let error): return report(Self.outcome(error))
        }
        guard info.count == 3, let number = Int(info[1]), number > 0 else { return report(.exportNeedsSave) }
        let documentID = info[0], document = URL(fileURLWithPath: info[2])
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("KeynoteMaestro-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let export = "tell application id \"\(bundleID)\"\nwith timeout of 600 seconds\n"
            + "export (first document whose id is \"\(documentID)\") to (POSIX file \"\(work.path)\") as slide images with properties {image format:PNG, skipped slides:true, all stages:false}\n"
            + "end timeout\nend tell"
        DispatchQueue.global(qos: .userInitiated).async {
            let status = Self.osascript(export)
            let outcome: CommandOutcome
            if status != 0 { outcome = .exportFailed(Int(status)) }
            else if let image = Self.slideImages(in: work).dropFirst(number - 1).first {
                let target = Self.freeName(document.deletingPathExtension().lastPathComponent + String(format: "-p%03d", number),
                                           in: document.deletingLastPathComponent())
                do { try FileManager.default.moveItem(at: image, to: target); outcome = .exported(target) }
                catch { outcome = .exportFailed((error as NSError).code) }
            } else { outcome = .exportFailed(-1) }
            try? FileManager.default.removeItem(at: work)
            DispatchQueue.main.async { report(outcome) }
        }
    }

    /// Slide images in Keynote's order (file names end in .001.png, .002.png …), in subfolders too.
    nonisolated static func slideImages(in folder: URL) -> [URL] {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return files.filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// name.png, or name-2.png, name-3.png … when taken (B10).
    nonisolated static func freeName(_ base: String, in folder: URL) -> URL {
        var candidate = folder.appendingPathComponent(base + ".png")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)-\(index).png"); index += 1
        }
        return candidate
    }

    /// Runs outside the main thread (a long export must not freeze the menus); the exit status, or the AppleScript error number when known.
    nonisolated static func osascript(_ source: String) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return -1 }
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return 0 }
        // osascript prints “… (-1743)” at the end of the message.
        let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if let range = message.range(of: #"\((-?\d+)\)\s*$"#, options: .regularExpression),
           let code = Int32(message[range].trimmingCharacters(in: CharacterSet(charactersIn: "() \n"))) { return code }
        return process.terminationStatus
    }

    /// Returns the result as text, or an NSError whose code is the AppleScript error number.
    static func runScript(_ source: String) -> Result<String, NSError> {
        var info: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return .failure(NSError(domain: "AppleScript", code: -2700)) }
        let result = script.executeAndReturnError(&info)
        if let info { return .failure(NSError(domain: "AppleScript", code: (info[NSAppleScript.errorNumber] as? Int) ?? -2700)) }
        return .success(result.stringValue ?? "")
    }

    // MARK: Accessibility

    enum MenuResult { case pressed, disabled, missing, failed }

    /// Presses the first enabled item among the candidate paths (tried in order).
    static func pressMenu(pid: pid_t, candidates: [MenuPath]) -> MenuResult {
        let app = AXUIElementCreateApplication(pid)
        // A menu item that opens a dialog box may not answer until the dialog closes.
        AXUIElementSetMessagingTimeout(app, 1.0)
        guard let bar = element(app, kAXMenuBarAttribute) else { return .missing }
        var found: [AXUIElement] = []
        for path in candidates { found += items(in: children(bar), path: path[...]) }
        guard !found.isEmpty else { return .missing }
        guard let target = found.first(where: { bool($0, kAXEnabledAttribute) }) else { return .disabled }
        let result = AXUIElementPerformAction(target, kAXPressAction as CFString)
        return result == .success || result == .cannotComplete ? .pressed : .failed
    }

    private static func items(in elements: [AXUIElement], path: ArraySlice<MenuTitle>) -> [AXUIElement] {
        guard let level = path.first else { return [] }
        let matches = elements.filter { level.matches(string($0, kAXTitleAttribute)) }
        if path.count == 1 { return matches }
        return matches.flatMap { item in children(item).flatMap { items(in: children($0), path: path.dropFirst()) } }
    }

    /// A button of the front window by title or description (the inspector is several levels down).
    static func pressButton(pid: pid_t, names: [String]) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let window = element(app, kAXFocusedWindowAttribute) else { return false }
        var queue = [(window, 0)]
        while !queue.isEmpty {
            let (current, depth) = queue.removeFirst()
            if [kAXButtonRole, kAXRadioButtonRole].contains(string(current, kAXRoleAttribute)),
               names.contains(string(current, kAXTitleAttribute)) || names.contains(string(current, kAXDescriptionAttribute)),
               bool(current, kAXEnabledAttribute) {
                return AXUIElementPerformAction(current, kAXPressAction as CFString) == .success
            }
            if depth < 14 { queue += children(current).map { ($0, depth + 1) } }
        }
        return false
    }

    /// Expand the Fill section only when its colour controls are collapsed.
    static func expandFill(pid: pid_t) -> Bool {
        guard let window = element(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute) else { return false }
        var queue = [(window, 0)]
        var disclosure: AXUIElement?
        while !queue.isEmpty {
            let (current, depth) = queue.removeFirst()
            let description = string(current, kAXDescriptionAttribute)
            if ["塗りつぶしプリセットピッカー", "Fill preset picker"].contains(description) { return true }
            let help = string(current, kAXHelpAttribute)
            if string(current, kAXRoleAttribute) == kAXDisclosureTriangleRole,
               help.contains("カラー、グラデーション、画像塗りつぶし") || help.localizedCaseInsensitiveContains("color, gradient, or image fills") { disclosure = current }
            if depth < 14 { queue += children(current).map { ($0, depth + 1) } }
        }
        guard let disclosure else { return false }
        return AXUIElementPerformAction(disclosure, kAXPressAction as CFString) == .success
    }

    /// True while a text box, table cell or field is being typed in; ⌥L or ⇧1 then types its character.
    static func isEditingText(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let focused = element(app, kAXFocusedUIElementAttribute) else { return false }
        return [kAXTextAreaRole, kAXTextFieldRole, kAXComboBoxRole, "AXSearchField"].contains(string(focused, kAXRoleAttribute))
    }

    private static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private static func children(_ parent: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }
    private static func string(_ element: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return "" }
        return (value as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    // MARK: Events

    /// One key straight to the process with explicit flags, so the held keys of the trigger do not leak in.
    static func key(_ code: CGKeyCode, _ flags: CGEventFlags, to pid: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return false }
        down.flags = flags
        up.flags = flags
        down.postToPid(pid)
        up.postToPid(pid)
        return true
    }

    /// The pressed hotkey, sent on to Keynote unchanged (arrow keys with their keypad flags).
    static func passThrough(_ shortcut: Shortcut, to pid: pid_t) {
        var flags: CGEventFlags = (123...126).contains(shortcut.code) ? KeynoteCommand.arrowFlags : []
        if shortcut.modifiers & UInt32(cmdKey) != 0 { flags.insert(.maskCommand) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { flags.insert(.maskAlternate) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { flags.insert(.maskControl) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { flags.insert(.maskShift) }
        _ = key(CGKeyCode(shortcut.code), flags, to: pid)
    }
}
