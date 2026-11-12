import AppKit
import Carbon
import SwiftUI

// MARK: - UI（InDesignの表示・UIの明るさ）

/// InDesign's interface: brightness (generalPreferences.uiBrightnessPreference), Application Frame
/// (generalPreferences.useApplicationFrame), the Contextual Task Bar (Window menu action) and the two-column Tools panel
/// (generalPreferences.toolsPanel). Read and written with `do script` in the InDesign in front (or the one running).
/// Ported from VectorMate's 基本UI (Illustrator works through its menus and the Settings dialog box instead).
@MainActor
final class InDesignUI: ObservableObject {
    struct State: Equatable {
        /// Index into `brightnessValues` (暗・やや暗め・やや明るめ・明).
        var brightness: Int
        var frame: Bool
        var taskBar: Bool
        var doubleColumn: Bool
        /// The Contextual Task Bar menu action was found.
        var hasTaskBar: Bool
    }
    /// The values InDesign's color theme presets use; anything between is mapped to the closest one.
    nonisolated static let brightnessValues = [0.0, 0.5, 0.51, 1.0]
    static let brightnessKeys = ["ui.dark", "ui.mediumDark", "ui.mediumLight", "ui.light"]

    /// nil: no InDesign running, or it did not answer.
    @Published var state: State?
    @Published var busy = false
    @Published var status = ""
    private let queue = DispatchQueue(label: "LayoutMate.ui")
    /// Brightness steps pressed while an operation was running; applied together afterwards.
    private var pendingSteps = 0

    /// The InDesign in front, otherwise one that is running.
    static var target: NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier == AsyncExports.bundleID { return front }
        return NSRunningApplication.runningApplications(withBundleIdentifier: AsyncExports.bundleID).first { !$0.isTerminated }
    }

    // The menu action is found by id (InDesign 2027: 148997) and, failing that, by its Japanese or English name.
    nonisolated private static let taskBarJS = "function taskBar(){var t=null;try{t=app.menuActions.itemByID(148997);if(!/タスクバー|Task Bar/i.test(t.name))t=null;}catch(e){t=null;}" +
        "if(!t){var a=app.menuActions.everyItem().getElements();for(var i=0;i<a.length;i++){if(/^(コンテキストタスクバー|Contextual Task Bar)$/i.test(a[i].name)){t=a[i];break;}}}return t;}"
    nonisolated private static let readJS = "function readUI(){var g=app.generalPreferences,t=taskBar();" +
        "return [g.uiBrightnessPreference,g.useApplicationFrame?1:0,t&&t.checked?1:0,g.toolsPanel==ToolsPanelOptions.DOUBLE_COLUMN?1:0,t?1:0].join(',');}"
    nonisolated private static func script(_ body: String) -> String { "(function(){" + taskBarJS + readJS + body + "return readUI();})();" }

    nonisolated static func parse(_ text: String?) -> State? {
        guard let parts = text?.split(separator: ",").map(String.init), parts.count == 5, let value = Double(parts[0]) else { return nil }
        let index = brightnessValues.indices.min { abs(brightnessValues[$0] - value) < abs(brightnessValues[$1] - value) } ?? 3
        return State(brightness: index, frame: parts[1] == "1", taskBar: parts[2] == "1", doubleColumn: parts[3] == "1", hasTaskBar: parts[4] == "1")
    }

    func read() {
        guard let pid = Self.target?.processIdentifier else { state = nil; status = L("ui.notRunning"); return }
        queue.async {
            let result = Self.parse(InDesignScript.run(Self.script(""), pid: pid, timeout: 3))
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.state = result
                    if result == nil { self.status = L("ui.noAnswer") } else if self.status == L("ui.notRunning") || self.status == L("ui.noAnswer") { self.status = "" }
                }
            }
        }
    }

    /// Runs `body` (JavaScript using g = app.generalPreferences and taskBar()), then reads the state again in a separate
    /// call: a menu action's `checked` stays old within the script that invoked it.
    private func change(_ body: String, done: String) {
        guard !busy, let pid = Self.target?.processIdentifier else { if Self.target == nil { status = L("ui.notRunning") }; return }
        busy = true
        queue.async {
            let wrote = InDesignScript.run(Self.script("var g=app.generalPreferences;" + body), pid: pid, timeout: 5)
            let result = Self.parse(InDesignScript.run(Self.script(""), pid: pid, timeout: 3))
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.busy = false
                    self.state = result
                    self.status = wrote == nil ? L("ui.failed") : L(done)
                    if self.pendingSteps != 0 { let steps = self.pendingSteps; self.pendingSteps = 0; self.step(steps) }
                }
            }
        }
    }

    func setBrightness(_ index: Int) {
        let index = min(max(index, 0), Self.brightnessValues.count - 1)
        change("g.uiBrightnessPreference=\(Self.brightnessValues[index]);", done: Self.brightnessKeys[index])
    }
    /// ⇧F2 brighter (+1) / ⇧F1 darker (−1), from the state read right before.
    func step(_ delta: Int) {
        if busy { pendingSteps += delta; return }
        guard let pid = Self.target?.processIdentifier else { return }
        busy = true
        queue.async {
            let current = Self.parse(InDesignScript.run(Self.script(""), pid: pid, timeout: 3))
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.busy = false
                    guard let current else { self.status = L("ui.noAnswer"); return }
                    self.state = current
                    let target = min(max(current.brightness + delta, 0), Self.brightnessValues.count - 1)
                    if target != current.brightness { self.setBrightness(target) }
                }
            }
        }
    }
    func setFrame(_ on: Bool) { change("g.useApplicationFrame=\(on);", done: on ? "ui.frameOn" : "ui.frameOff") }
    func setTaskBar(_ on: Bool) { change("var t=taskBar();if(t&&t.checked!=\(on))t.invoke();", done: on ? "ui.taskBarOn" : "ui.taskBarOff") }
    func setDoubleColumn(_ on: Bool) {
        change("g.toolsPanel=ToolsPanelOptions.\(on ? "DOUBLE_COLUMN" : "SINGLE_COLUMN");", done: on ? "ui.doubleOn" : "ui.doubleOff")
    }
}

/// UIの明るさ・表示 groups above the application bar list.
struct InDesignUIGroups: View {
    @ObservedObject var ui: InDesignUI
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                GroupTitle(text: L("ui.brightnessTitle"))
                Picker("", selection: Binding(get: { ui.state?.brightness ?? -1 }, set: { value in
                    guard let current = ui.state?.brightness, value >= 0, value != current else { return }
                    ui.setBrightness(value)
                })) {
                    ForEach(InDesignUI.brightnessKeys.indices, id: \.self) { Text(L(InDesignUI.brightnessKeys[$0])).tag($0) }
                }.pickerStyle(.radioGroup).labelsHidden().disabled(ui.state == nil || ui.busy)
                Note(text: L("ui.brightnessHotkeys"))
            }
            VStack(alignment: .leading, spacing: 10) {
                GroupTitle(text: L("ui.displayTitle"))
                Group {
                    Toggle(L("ui.frame"), isOn: Binding(get: { ui.state?.frame ?? false }, set: { value in if let state = ui.state, state.frame != value { ui.setFrame(value) } }))
                    Toggle(L("ui.taskBar"), isOn: Binding(get: { ui.state?.taskBar ?? false }, set: { value in if let state = ui.state, state.taskBar != value { ui.setTaskBar(value) } }))
                        .disabled(ui.state?.hasTaskBar == false)
                    Toggle(L("ui.doubleColumn"), isOn: Binding(get: { ui.state?.doubleColumn ?? false }, set: { value in if let state = ui.state, state.doubleColumn != value { ui.setDoubleColumn(value) } }))
                }.disabled(ui.state == nil || ui.busy)
                Text(ui.status).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { ui.read() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in ui.read() }
    }
}
