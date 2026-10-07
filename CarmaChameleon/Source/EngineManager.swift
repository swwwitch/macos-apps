import AppKit
import SwiftUI
import CryptoKit

struct PandocRelease: Decodable {
    struct Asset: Decodable { let name: String; let browser_download_url: String; let digest: String? }
    let tag_name: String
    let assets: [Asset]
}
@MainActor final class EngineManager: ObservableObject {
    static let shared = EngineManager()
    @Published var version = ""
    @Published var location = ""
    @Published var latest = ""
    @Published var message = ""
    @Published var busy = false
    private var release: PandocRelease?
    nonisolated static var installRoot: URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("PandocDesk/Engines",isDirectory:true) }
    var updateNeeded: Bool { !latest.isEmpty && (version.isEmpty || version.compare(latest,options:.numeric) == .orderedAscending) }
    var summary: String { version.isEmpty ? L("notInstalled") : latest.isEmpty ? L("notChecked") : updateNeeded ? L("updateAvailable") : L("upToDate") }
    func refresh() {
        let url = ConversionRunner.engine(); location = url?.path ?? L("notInstalled")
        guard let url else { version = ""; return }
        Task {
            let result = await Task.detached { Self.readVersion(url) }.value
            self.version = result ?? ""; if result == nil { self.message = L("engineInvalid") }
        }
    }
    nonisolated static func readVersion(_ url: URL) -> String? {
        let p = Process(); p.executableURL = url; p.arguments = ["--version"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice; p.standardInput = FileHandle.nullDevice
        do {
            try p.run()
            DispatchQueue.global().asyncAfter(deadline:.now()+5) { if p.isRunning { p.terminate() } }
            let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            guard p.terminationStatus == 0, let line = String(data:data,encoding:.utf8)?.components(separatedBy:"\n").first, line.hasPrefix("pandoc ") else { return nil }
            return line.components(separatedBy:" ").dropFirst().first
        } catch { return nil }
    }
    func check() {
        guard !busy else { return }; busy = true; message = L("checking")
        Task {
            defer { busy = false }
            do {
                var request = URLRequest(url:URL(string:"https://api.github.com/repos/jgm/pandoc/releases/latest")!); request.timeoutInterval = 30; request.setValue("PandocDesk",forHTTPHeaderField:"User-Agent")
                let (data,response) = try await URLSession.shared.data(for:request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw failure("networkError") }
                let info = try JSONDecoder().decode(PandocRelease.self,from:data)
                release = info; latest = info.tag_name; message = L("checked"); refresh()
            } catch { message = L("checkFailed") + error.localizedDescription }
        }
    }
    func install() {
        guard !busy, let release else { return }
        guard let asset = release.assets.first(where: { $0.name == "pandoc-\(release.tag_name)-arm64-macOS.zip" }), let digest = asset.digest, digest.hasPrefix("sha256:"), let url = URL(string:asset.browser_download_url), url.scheme == "https", url.host == "github.com", url.path.hasPrefix("/jgm/pandoc/releases/download/") else { message = L("noVerifiedAsset"); return }
        busy = true; message = L("installing")
        Task {
            defer { busy = false }
            do {
                let (download,response) = try await URLSession.shared.download(from:url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw failure("networkError") }
                let expected = String(digest.dropFirst(7)); let tag = release.tag_name
                let installed = try await Task.detached { () throws -> URL in
                    let fm = FileManager.default
                    let data = try Data(contentsOf:download,options:.mappedIfSafe)
                    let actual = SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
                    guard actual == expected else { throw NSError(domain:"PandocDesk",code:2,userInfo:[NSLocalizedDescriptionKey:L("hashMismatch")]) }
                    let stage = fm.temporaryDirectory.appendingPathComponent("PandocDesk-install-"+UUID().uuidString)
                    try fm.createDirectory(at:stage,withIntermediateDirectories:true); defer { try? fm.removeItem(at:stage) }
                    let p = Process(); p.executableURL = URL(fileURLWithPath:"/usr/bin/ditto"); p.arguments = ["-x","-k",download.path,stage.path]; p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice; try p.run(); p.waitUntilExit()
                    guard p.terminationStatus == 0 else { throw NSError(domain:"PandocDesk",code:3,userInfo:[NSLocalizedDescriptionKey:L("extractFailed")]) }
                    let binary = stage.appendingPathComponent("pandoc-\(tag)-arm64/bin/pandoc")
                    guard Self.readVersion(binary) == tag else { throw NSError(domain:"PandocDesk",code:4,userInfo:[NSLocalizedDescriptionKey:L("engineInvalid")]) }
                    let dest = Self.installRoot.appendingPathComponent(tag+"-"+UUID().uuidString,isDirectory:true)
                    try fm.createDirectory(at:dest,withIntermediateDirectories:true)
                    let target = dest.appendingPathComponent("pandoc"); try fm.copyItem(at:binary,to:target)
                    return target
                }.value
                UserDefaults.standard.set(installed.path,forKey:"managedPandocPath")
                UserDefaults.standard.set("",forKey:"pandocPath")
                refresh(); message = L("installed")
            } catch { message = L("installFailed") + error.localizedDescription }
        }
    }
    private func failure(_ key:String) -> NSError { NSError(domain:"PandocDesk",code:1,userInfo:[NSLocalizedDescriptionKey:L(key)]) }
}
struct EngineSettingsView: View {
    @ObservedObject var manager = EngineManager.shared
    @AppStorage("pandocPath") var path = ""
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack { Label(manager.version.isEmpty ? L("notInstalled") : "pandoc " + manager.version,systemImage:manager.version.isEmpty ? "exclamationmark.circle" : "checkmark.circle"); Spacer(); Text(manager.summary).foregroundColor(.secondary) }
            Text(manager.location).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
            if !manager.latest.isEmpty { Text(L("latest") + manager.latest).font(.caption) }
            HStack {
                Button(L("refresh")) { manager.refresh() }
                Button(L("checkLatest")) { manager.check() }
                Button(L(manager.version.isEmpty ? "install" : "installUpdate")) { manager.install() }.disabled(manager.latest.isEmpty || (!manager.updateNeeded && path.isEmpty))
                if manager.busy { ProgressView().controlSize(.small) }
            }.disabled(manager.busy)
            if !manager.message.isEmpty { Text(manager.message).font(.caption).textSelection(.enabled) }
            Text(L("installDetail")).font(.caption).foregroundColor(.secondary)
            Divider()
            HStack { TextField(L("customPath"),text:$path).onSubmit { manager.refresh() }; Button(L("browse")) { let p = NSOpenPanel(); if p.runModal() == .OK { path = p.url!.path; manager.refresh() } } }.disabled(manager.busy)
            Button(L("useBundled")) { path = ""; UserDefaults.standard.removeObject(forKey:"managedPandocPath"); manager.refresh() }.disabled(manager.busy)
        }.onAppear { manager.refresh() }.onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) { _ in manager.refresh() }
    }
}
