import AppKit
import SwiftUI

// Renders the main window and the settings offscreen to PNG files for a visual check (Tests/snapshot.sh).
// usage: Snapshot <output folder> <image>
@main
enum Snapshot {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let model = delegate.model
        func settle(_ seconds: Double = 0.4) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        func waitForPreview() {
            let deadline = Date().addingTimeInterval(5)
            while model.preview == nil && model.layout != nil && Date() < deadline { settle(0.05) }
            settle()
        }
        func snap<V: View>(_ view: V, _ size: NSSize, _ name: String, dark: Bool = false) {
            let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: size.width, height: size.height),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: size)
            window.contentView = host
            window.orderFrontRegardless()
            settle()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent(name + ".png"))
            window.orderOut(nil)
            print("wrote", name)
        }
        let size = NSSize(width: 1180, height: 760)
        snap(ContentView(model: model), size, "0-empty")
        model.open(URL(fileURLWithPath: CommandLine.arguments[2]))
        waitForPreview()
        snap(ContentView(model: model), size, "1-flag")
        snap(ContentView(model: model), size, "2-flag-dark", dark: true)
        model.settings.cutStyle = .jagged
        model.settings.ruleDashed = true
        model.settings.ruleColor = RuleColor(red: 0.9, green: 0.1, blue: 0.1)
        model.settings.ruleWidth = 3
        UserDefaults.standard.set(PreviewBackground.gray.rawValue, forKey: PreviewBackground.key)
        waitForPreview()
        snap(ContentView(model: model), size, "3-jagged-dashed")
        UserDefaults.standard.removeObject(forKey: PreviewBackground.key)
        if let image = model.source?.size {
            model.settings = TrimSettings()
            model.band = CGRect(x: image.width * 0.45, y: 0, width: image.width * 0.1, height: image.height)
            model.settings.cutStyle = .rise
            model.settings.warpPercent = 5
            waitForPreview()
            snap(ContentView(model: model), size, "4-vertical-rise")
            model.band = CGRect(x: 0, y: 0, width: image.width, height: image.height * 0.4)
            model.settings.cutStyle = .riseStraight
            waitForPreview()
            snap(ContentView(model: model), size, "5-keep-top")
            model.band = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            settle()
            snap(ContentView(model: model), size, "6-error")
        }
        snap(Preferences(model: model), NSSize(width: 560, height: 520), "7-settings")
        UserDefaults.standard.set(1, forKey: RememberedTabView.key)
        model.outputLocation = .fixedFolder
        snap(Preferences(model: model), NSSize(width: 560, height: 560), "8-output")
        model.resetSettings()
    }
}
