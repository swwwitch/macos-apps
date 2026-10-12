import SwiftUI

/// 「プリセットに保存…」 from the 個別操作 tab: saves the current state into a new or an existing preset.
/// Only ticked items go into the preset; unticked ones stay "unchanged" when it is applied.
/// Overwriting keeps the preset's name, place in the list and app lists, and starts with the items it already had ticked.
struct PresetSaveSheet: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var countdown: Countdown
    @ObservedObject var presets: PresetStore
    let done: () -> Void

    enum Item: CaseIterable, Hashable {
        case clock, showDate, showWeekday, dark, hideDock, killDock, hideDesktop, pointerSize, resolution,
             reduceTransparency, volumeFeedback, notificationsOff, timerEnabled, timerMinutes
    }

    @State private var targetID: UUID?
    @State private var name = L("新しいプリセット")
    @State private var included = Set<Item>()
    /// Notifications have no readable state, so the preset value is chosen here.
    @State private var notificationsOff = true
    /// Resolution: the current size, or "the display's default" (works on any display).
    @State private var resolutionDefault = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("プリセットに保存")).font(.title3.bold())
            Picker(L("保存先"), selection: $targetID) {
                Text(L("新しいプリセット")).tag(UUID?.none)
                Divider()
                ForEach(presets.items) { Text($0.name).tag(Optional($0.id)) }
            }
            .onChange(of: targetID) { select($0) }
            TextField(L("プリセット名"), text: $name)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    row(.clock, L("時計"), settings.analog ? L("アナログ") : L("デジタル"))
                    row(.showDate, L("時計の日付"), settings.showDate ? L("表示する") : L("表示しない"))
                    row(.showWeekday, L("時計の曜日"), settings.showWeekday ? L("表示する") : L("表示しない"))
                    row(.dark, L("外観"), settings.dark ? L("ダーク") : L("ライト"))
                    row(.hideDock, L("Dockを隠す"), onOff(settings.dockHidden))
                    row(.killDock, L("Dockを完全非表示"), onOff(settings.dockKilled))
                    row(.hideDesktop, L("デスクトップ非表示"), onOff(settings.desktopHidden))
                    row(.pointerSize, L("ポインタのサイズ"), PointerSize.text(settings.pointerSize))
                    HStack {
                        Toggle(L("解像度"), isOn: binding(.resolution))
                        Spacer()
                        Picker(L("解像度"), selection: $resolutionDefault) {
                            Text(settings.resolution?.text ?? "–").tag(false)
                            Text(L("ディスプレイの既定")).tag(true)
                        }.labelsHidden().frame(width: 150).disabled(!included.contains(.resolution))
                    }
                    row(.reduceTransparency, L("透明度を下げる"), onOff(settings.reduceTransparency))
                    row(.volumeFeedback, L("音量変更時の音"), onOff(settings.volumeFeedback))
                    HStack {
                        Toggle(L("通知をオフ"), isOn: binding(.notificationsOff))
                        Spacer()
                        Picker(L("通知をオフ"), selection: $notificationsOff) {
                            Text(L("解除")).tag(false); Text(L("抑える")).tag(true)
                        }.labelsHidden().pickerStyle(.segmented).frame(width: 120).disabled(!included.contains(.notificationsOff))
                    }
                    row(.timerEnabled, L("タイマーを使う"), onOff(countdown.enabled))
                    row(.timerMinutes, L("タイマー所要時間"), L("%@分", String(countdown.plan.minutes)))
                }
            }
            .help(L("チェックした項目だけを、今の値でプリセットに保存します。チェックしない項目は、適用しても変わりません。"))
            HStack {
                Spacer()
                Button(L("キャンセル"), role: .cancel, action: done).keyboardShortcut(.cancelAction)
                Button(L("保存"), action: save).keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }
        .padding(20)
        .frame(width: 380, height: 600)
        .onAppear { select(nil) }
    }

    private func onOff(_ value: Bool) -> String { value ? L("オン") : L("オフ") }

    private func binding(_ item: Item) -> Binding<Bool> {
        Binding(get: { included.contains(item) }, set: { if $0 { included.insert(item) } else { included.remove(item) } })
    }

    private func row(_ item: Item, _ title: String, _ value: String) -> some View {
        HStack {
            Toggle(title, isOn: binding(item))
            Spacer()
            Text(value).foregroundStyle(included.contains(item) ? .primary : .secondary).monospacedDigit()
        }
    }

    /// New preset: every item ticked. Existing one: the items it already sets.
    private func select(_ id: UUID?) {
        guard let preset = presets.items.first(where: { $0.id == id }) else {
            name = L("新しいプリセット")
            included = Set(Item.allCases)
            resolutionDefault = false
            return
        }
        name = preset.name
        let has: [Item: Bool] = [
            .clock: preset.clock != nil, .showDate: preset.showDate != nil, .showWeekday: preset.showWeekday != nil,
            .dark: preset.dark != nil, .hideDock: preset.hideDock != nil, .killDock: preset.killDock != nil,
            .hideDesktop: preset.hideDesktop != nil, .pointerSize: preset.pointerSize != nil, .resolution: preset.resolution != nil,
            .reduceTransparency: preset.reduceTransparency != nil, .volumeFeedback: preset.volumeFeedback != nil,
            .notificationsOff: preset.notificationsOff != nil, .timerEnabled: preset.timerEnabled != nil, .timerMinutes: preset.timerMinutes != nil]
        included = Set(has.filter(\.value).map(\.key))
        notificationsOff = preset.notificationsOff ?? true
        resolutionDefault = preset.resolution?.isDisplayDefault ?? false
    }

    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !included.isEmpty }

    private func save() {
        var preset = presets.items.first { $0.id == targetID } ?? Preset()
        preset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        func value<T>(_ item: Item, _ current: T) -> T? { included.contains(item) ? current : nil }
        preset.clock = value(.clock, settings.analog)
        preset.showDate = value(.showDate, settings.showDate)
        preset.showWeekday = value(.showWeekday, settings.showWeekday)
        preset.dark = value(.dark, settings.dark)
        preset.hideDock = value(.hideDock, settings.dockHidden)
        preset.killDock = value(.killDock, settings.dockKilled)
        preset.hideDesktop = value(.hideDesktop, settings.desktopHidden)
        preset.pointerSize = value(.pointerSize, settings.pointerSize)
        preset.resolution = included.contains(.resolution) ? (resolutionDefault ? .displayDefault : settings.resolution) : nil
        preset.reduceTransparency = value(.reduceTransparency, settings.reduceTransparency)
        preset.volumeFeedback = value(.volumeFeedback, settings.volumeFeedback)
        preset.notificationsOff = value(.notificationsOff, notificationsOff)
        preset.timerEnabled = value(.timerEnabled, countdown.enabled)
        preset.timerMinutes = value(.timerMinutes, countdown.plan.minutes)
        let overwriting = targetID != nil
        presets.save(preset)
        settings.error = false
        settings.message = L(overwriting ? "「%@」を上書き保存しました。" : "「%@」を保存しました。", preset.name)
        done()
    }
}
