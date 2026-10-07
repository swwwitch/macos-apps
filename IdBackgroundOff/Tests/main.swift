import Foundation

var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition { print("ok   " + label) } else { failures += 1; print("FAIL " + label) }
}

let fm = FileManager.default
let base = fm.temporaryDirectory.appendingPathComponent("IdBackgroundOffTests-\(UUID().uuidString)", isDirectory: true)
defer { try? fm.removeItem(at: base) }

@discardableResult
func makeBundle(_ folder: String, _ app: String, id: String, version: String = "21.0") -> URL {
    let url = base.appendingPathComponent(folder).appendingPathComponent(app + ".app")
    try! fm.createDirectory(at: url.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    let info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleShortVersionString": version, "CFBundleName": "InDesign", "CFBundlePackageType": "APPL"]
    try! PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url.appendingPathComponent("Contents/Info.plist"))
    return url
}

func sh(_ command: String) -> Int32 {
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", command]
    try! p.run(); p.waitUntilExit(); return p.terminationStatus
}

makeBundle("Adobe InDesign 2025", "Adobe InDesign 2025", id: AsyncExports.bundleID, version: "20.5")
makeBundle("Adobe InDesign 2026", "Adobe InDesign 2026", id: AsyncExports.bundleID, version: "21.6")
makeBundle("Adobe InDesign Server 2026", "Adobe InDesign Server 2026", id: "com.adobe.InDesignServer")
makeBundle("Other", "Adobe InDesign 2026", id: "com.example.fake")
// Shell-hostile names: quote, dollar, backtick, double quote, Japanese.
let odd = makeBundle("Adobe InDesign 'q' $HOME `x` \"d\" 日本語", "Adobe InDesign Odd", id: AsyncExports.bundleID)

let apps = AsyncExports.discover(roots: [base], extra: [base.appendingPathComponent("Adobe InDesign 2026/Adobe InDesign 2026.app")])
check(apps.count == 3, "discovers InDesign only, deduplicated (\(apps.map(\.name)))")
check(apps.first?.name == "Adobe InDesign Odd" || apps.first?.name == "Adobe InDesign 2026", "newest-first ordering")
check(!apps.contains { $0.name.contains("Server") }, "InDesign Server excluded")
check(apps.first { $0.name == "Adobe InDesign 2026" }?.version == "21.6", "version read")
check(AsyncExports.app(at: base.appendingPathComponent("Other/Adobe InDesign 2026.app")) == nil, "other bundle ID rejected")
check(AsyncExports.discover(roots: [base], extra: [base.appendingPathComponent(".Trash/Adobe InDesign 2024.app")]).count == 3, "trash extra ignored")

check(apps.allSatisfy { AsyncExports.state(of: $0) == .on }, "initially on")
check(AsyncExports.targets(apps, turnOff: true).count == 3, "all are turn-off targets")
check(AsyncExports.targets(apps, turnOff: false).isEmpty, "nothing to restore")

// Privileged command, executed here without privileges against the temp tree.
let offCommand = AsyncExports.command(for: apps, turnOff: true)!
check(sh(offCommand) == 0, "turn-off command succeeds")
check(apps.allSatisfy { AsyncExports.state(of: $0) == .off }, "all off after command")
check((try? fm.attributesOfItem(atPath: apps[0].markerFile.path)[.size] as? Int) == 0, "marker file is empty")
check(fm.fileExists(atPath: odd.appendingPathComponent("Contents/MacOS/" + AsyncExports.fileName).path), "hostile path handled literally")
check(!fm.fileExists(atPath: base.appendingPathComponent("Adobe InDesign 'q' ").path), "no path splitting")
check(sh(offCommand) == 0 && apps.allSatisfy { AsyncExports.state(of: $0) == .off }, "turn-off is idempotent")

let onCommand = AsyncExports.command(for: apps, turnOff: false)!
check(sh(onCommand) == 0, "restore command succeeds")
check(apps.allSatisfy { AsyncExports.state(of: $0) == .on }, "all on after restore")
check(sh(onCommand) == 0, "restore is idempotent")

// Non-regular items at the marker path are reported and never touched.
let target = apps[0]
try! fm.createDirectory(at: target.markerFile, withIntermediateDirectories: false)
try! Data("keep".utf8).write(to: target.markerFile.appendingPathComponent("inner"))
check(AsyncExports.state(of: target) == .invalid, "directory at marker path is invalid")
check(AsyncExports.targets([target], turnOff: false).isEmpty && AsyncExports.targets([target], turnOff: true).isEmpty, "invalid is never a target")
_ = sh("{ [ ! -f \(AsyncExports.shellQuote(target.markerFile.path)) ] || /bin/rm -f \(AsyncExports.shellQuote(target.markerFile.path)); }")
check(fm.fileExists(atPath: target.markerFile.appendingPathComponent("inner").path), "rm guard keeps directory")
try! fm.removeItem(at: target.markerFile)
let elsewhere = base.appendingPathComponent("elsewhere.txt"); try! Data("x".utf8).write(to: elsewhere)
try! fm.createSymbolicLink(at: target.markerFile, withDestinationURL: elsewhere)
check(AsyncExports.state(of: target) == .invalid, "symlink at marker path is invalid")
_ = sh(AsyncExports.command(for: [target], turnOff: false)!)
check(fm.fileExists(atPath: elsewhere.path) && (try? fm.destinationOfSymbolicLink(atPath: target.markerFile.path)) != nil, "restore keeps symlink and its target")
try! fm.removeItem(at: target.markerFile)

// Unprivileged path for a writable copy.
check(AsyncExports.changeWithoutPrivileges(target, turnOff: true) && AsyncExports.state(of: target) == .off, "writable copy: off without password")
check(AsyncExports.changeWithoutPrivileges(target, turnOff: false) && AsyncExports.state(of: target) == .on, "writable copy: restore without password")

// Path validation and quoting.
check(!AsyncExports.isMarkerPath("relative/X.app/Contents/MacOS/DisableAsyncExports.txt"), "relative path rejected")
check(!AsyncExports.isMarkerPath("/Applications/X.app/Contents/MacOS/../../../etc/DisableAsyncExports.txt"), "parent traversal rejected")
check(!AsyncExports.isMarkerPath("/Applications/X.app/Contents/MacOS/other.txt"), "other file name rejected")
check(AsyncExports.command(for: [], turnOff: true) == nil, "empty selection has no command")
check(AsyncExports.shellQuote("a'b") == "'a'\\''b'", "single quote escaped")
check(AsyncExports.appleScriptString("a\"b\\c") == "\"a\\\"b\\\\c\"", "AppleScript string escaped")
let script = AsyncExports.appleScript(command: "echo 'x'", prompt: "p")
check(script.hasPrefix("do shell script \"echo 'x'\"") && script.hasSuffix("with administrator privileges"), "AppleScript shape")

// Full AppleScript round trip (without the admin clause) against the hostile path.
let oddApp = AsyncExports.app(at: odd)!
let viaScript = AsyncExports.appleScript(command: AsyncExports.command(for: [oddApp], turnOff: true)!, prompt: "p \"q\"")
    .replacingOccurrences(of: " with administrator privileges", with: "")
let osa = Process(); osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); osa.arguments = ["-e", viaScript]
try! osa.run(); osa.waitUntilExit()
check(osa.terminationStatus == 0 && AsyncExports.state(of: oddApp) == .off, "AppleScript round trip creates marker at hostile path")

print(failures == 0 ? "All tests passed." : "\(failures) failure(s).")
exit(failures == 0 ? 0 : 1)
