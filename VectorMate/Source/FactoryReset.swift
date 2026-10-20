import AppKit
import SwiftUI

/// その他 → Illustratorの設定を初期化: quits the running Illustrator, moves its cache and the Application Support and
/// settings folders of its version to the Trash (so they can be put back), then launches the same Illustrator again.
enum FactoryReset {
    /// How long Illustrator may take to quit (the user may be asked to save documents).
    static let quitTimeout: TimeInterval = 120

    struct Done {
        var trashed: [URL]
        var launched: Bool
    }

    static func major(of bundle: URL) -> Int? {
        (Bundle(url: bundle)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?.split(separator: ".").first.flatMap { Int($0) }
    }
    /// The folders moved to the Trash for that major version; the cache only with `includeCache`.
    static func targets(major: Int, includeCache: Bool) -> [URL] {
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        return (includeCache ? [library.appendingPathComponent("Caches/com.adobe.illustrator")] : [])
            + [library.appendingPathComponent("Application Support/Adobe/Adobe Illustrator \(major)"),
               library.appendingPathComponent("Preferences/Adobe Illustrator \(major) Settings")]
    }

    /// Blocking: call off the main thread. Nothing is moved when Illustrator does not quit.
    static func run(includeCache: Bool) -> Result<Done, SettingsFailure> {
        // The version follows the running Illustrator: without one there is nothing to go by.
        guard let app = runningIllustrator() else { return .failure(.notRunning) }
        guard let bundle = app.bundleURL, let major = major(of: bundle) else { return .failure(.message(L("reset.noVersion"))) }
        DispatchQueue.main.sync { _ = app.terminate() }
        let deadline = Date().addingTimeInterval(quitTimeout)
        while !app.isTerminated && Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
        guard app.isTerminated else { return .failure(.message(L("reset.notQuit"))) }
        Thread.sleep(forTimeInterval: 1)   // let it finish writing its files
        var done = Done(trashed: [], launched: false)
        var failure: SettingsFailure?
        for folder in targets(major: major, includeCache: includeCache) where FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
                done.trashed.append(folder)
            } catch {
                failure = failure ?? .message(String(format: L("reset.trashFailed"), folder.path, error.localizedDescription))
            }
        }
        // Launched again even when something could not be moved, so Illustrator is back as it was asked.
        let opened = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: bundle, configuration: NSWorkspace.OpenConfiguration()) { app, _ in
            done.launched = app != nil
            opened.signal()
        }
        _ = opened.wait(timeout: .now() + 30)
        if let failure { return .failure(failure) }
        return .success(done)
    }
}

/// その他 → Illustratorの設定を初期化, confirmed before it runs.
struct FactoryResetSection: View {
    @ObservedObject var model: Model
    @State private var confirming = false

    var body: some View {
        let targets = Illustrator.running?.bundleURL.flatMap(FactoryReset.major).map { FactoryReset.targets(major: $0, includeCache: model.resetIncludesCache) } ?? []
        GroupTitle(text: L("reset.title")).padding(.top, 8)
        HStack {
            Button(L("reset.button")) { confirming = true }.disabled(model.busy || targets.isEmpty)
                .confirmationDialog(L(model.resetIncludesCache ? "reset.confirmCache" : "reset.confirm"), isPresented: $confirming) {
                    Button(L("reset.run"), role: .destructive) { model.factoryReset() }
                } message: {
                    Text(L("reset.confirmDetail"))
                }
        }
        Toggle(L("reset.includeCache"), isOn: $model.resetIncludesCache)
        // The folders that go, as the only explanation here (the rest is in the help).
        Note(text: targets.isEmpty ? L("reset.needsRunning") : targets.map { ($0.path as NSString).abbreviatingWithTildeInPath }.joined(separator: "\n"))
        ResultRow(result: model.resetResult)
    }
}
