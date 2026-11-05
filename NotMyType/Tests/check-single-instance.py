"""Exercise the production launch guard with real flock/processes and stubbed LaunchServices.

No user library, preferences, fonts, or running app is touched. This does not replace UI QA.
"""
from pathlib import Path
import os
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[2]
stub = r'''
import Foundation
import Darwin
let environment = ProcessInfo.processInfo.environment
let testDirectory = URL(fileURLWithPath: environment["TEST_DIRECTORY"]!)
func mark(_ name: String) {
    FileManager.default.createFile(atPath: testDirectory.appendingPathComponent(name).path, contents: Data())
}
@MainActor final class NSRunningApplication {
    struct Options: OptionSet { let rawValue: Int
        static let activateAllWindows = Options(rawValue: 1)
        static let activateIgnoringOtherApps = Options(rawValue: 2)
    }
    static let current = NSRunningApplication(pid: getpid(), finished: false)
    let processIdentifier: Int32
    let isFinishedLaunching: Bool
    let isTerminated = false
    let launchDate: Date?
    var bundleURL: URL? { testDirectory }
    init(pid: Int32, finished: Bool) {
        processIdentifier = pid; isFinishedLaunching = finished
        // Direct executable launches can initially have a nil launchDate.
        launchDate = pid == getpid() ? nil : Date(timeIntervalSince1970: 1)
    }
    static func runningApplications(withBundleIdentifier: String) -> [NSRunningApplication] {
        var apps = [current]
        if let scenario = environment["SCENARIO"], scenario != "empty" {
            apps.append(NSRunningApplication(pid: -1, finished: scenario == "existing"))
        }
        return apps
    }
    func activate(options: Options) { mark("activated") }
}
@MainActor final class NSWorkspace {
    static let shared = NSWorkspace()
    final class OpenConfiguration { var activates = false; var createsNewApplicationInstance = true }
    func openApplication(at: URL, configuration: OpenConfiguration, completionHandler: (Int?, Int?) -> Void) {
        precondition(configuration.activates && !configuration.createsNewApplicationInstance)
        mark("reopened"); completionHandler(nil, nil)
    }
}
'''
main = r'''
@main struct Test {
    @MainActor static func main() {
        SingleInstanceLaunch.enforce()
        mark("continued-\(getpid())")
        sleep(UInt32(environment["HOLD"] ?? "0")!)
    }
}
'''

def wait_for(predicate, timeout=10):
    deadline = time.monotonic() + timeout
    while not predicate():
        if time.monotonic() > deadline:
            raise AssertionError("Timed out waiting for test process")
        time.sleep(0.02)

for app, target in [("NotMyType", "NotMyType"), ("NotMyType Lite", "NotMyTypeLite")]:
    source = (root / app / "Sources" / target / "NotMyTypeApp.swift").read_text()
    assert source.index("SingleInstanceLaunch.enforce()") < source.index("NotMyTypeApp.main()") < source.index("var body: some Scene")
    if "LegacyMigration.run()" in source:
        assert source.index("SingleInstanceLaunch.enforce()") < source.index("LegacyMigration.run()")
    guard = source[source.index("@MainActor\nprivate enum SingleInstanceLaunch"):]
    guard = guard.replace("Bundle.main.bundleIdentifier", 'environment["TEST_IDENTIFIER"]')
    guard = guard.replace("FileManager.default.homeDirectoryForCurrentUser", "testDirectory")
    with tempfile.TemporaryDirectory(prefix="nmt-single-instance-") as directory:
        folder = Path(directory)
        swift = folder / "Guard.swift"
        swift.write_text(stub + guard + main)
        binary = folder / "guard"
        subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-module-cache-path",
                        str(folder / "cache"), str(swift), "-o", str(binary)], check=True)
        env = dict(os.environ, TEST_DIRECTORY=directory, TEST_IDENTIFIER=target, SCENARIO="pending", HOLD="30")
        processes = []
        try:
            # Every contender sees an older process which is still in App.init.
            processes = [subprocess.Popen([str(binary)], env=env) for _ in range(12)]
            wait_for(lambda: len(list(folder.glob("continued-*"))) > 0)
            wait_for(lambda: sum(p.poll() is None for p in processes) == 1)
            assert len(list(folder.glob("continued-*"))) == 1
            assert not (folder / "reopened").exists()
            owner = next(p for p in processes if p.poll() is None)
            assert all(p.returncode == 0 for p in processes if p is not owner)
            # Another edition must use an independent lock.
            subprocess.run([str(binary)], env=dict(env, TEST_IDENTIFIER=target+"-other", HOLD="0"), check=True, timeout=10)
            assert len(list(folder.glob("continued-*"))) == 2
            owner.kill(); owner.wait(timeout=5)
            # Crash recovery: the OS releases flock without unlinking the file.
            subprocess.run([str(binary)], env=dict(env, HOLD="0"), check=True, timeout=10)
            assert len(list(folder.glob("continued-*"))) == 3
            subprocess.run([str(binary)], env=dict(env, SCENARIO="existing", HOLD="0"), check=True, timeout=10)
            assert (folder / "reopened").exists() and (folder / "activated").exists()
            assert len(list(folder.glob("continued-*"))) == 3
            print(f"PASS {app}: 12 simultaneous contenders / one owner, pending-app race, edition isolation, crash recovery, legacy reopen")
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill(); process.wait()
