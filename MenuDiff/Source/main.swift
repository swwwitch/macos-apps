import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("MenuDiff ヘルプ") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
        }
    }
}

struct MenuDiffApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("MenuDiff", id: "main") {
            MainView()
        }
        .defaultSize(width: 640, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            HelpCommands()
        }
        Window("MenuDiff ヘルプ", id: "help") {
            HelpView()
        }
    }
}

/// 試験用：MenuDiff --capture <アプリのパス> [書き出し先.tsv]
/// 起動していなければ起動して読み、終了させる。保存先には書かない
func runCaptureCommand(_ arguments: [String]) -> Never {
    guard arguments.count >= 3 else {
        FileHandle.standardError.write("usage: MenuDiff --capture <app path> [out.tsv]\n".data(using: .utf8)!)
        exit(2)
    }
    let appURL = URL(fileURLWithPath: arguments[2])
    guard let install = AdobeApp.allCases.flatMap(AppInstall.discover).first(where: { $0.appURL.standardizedFileURL.path == appURL.standardizedFileURL.path }) else {
        FileHandle.standardError.write("not found: \(appURL.path)\n".data(using: .utf8)!)
        exit(2)
    }
    Task {
        do {
            let start = Date()
            let snapshot = try await MenuReader.capture(install) { print($0) }
            if arguments.count >= 4 {
                try snapshot.tsv().write(toFile: arguments[3], atomically: true, encoding: .utf8)
            }
            print("\(snapshot.name): \(snapshot.entries.count) items, \(snapshot.entries.filter { !$0.shortcut.isEmpty }.count) shortcuts, \(String(format: "%.1f", Date().timeIntervalSince(start)))s")
            exit(0)
        } catch {
            FileHandle.standardError.write("error: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(1)
        }
    }
    RunLoop.main.run()
    exit(0)
}

if CommandLine.arguments.count >= 2 && CommandLine.arguments[1] == "--capture" {
    runCaptureCommand(CommandLine.arguments)
}
MenuDiffApp.main()
