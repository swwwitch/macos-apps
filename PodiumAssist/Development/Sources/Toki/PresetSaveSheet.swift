import SwiftUI

/// 「プリセットに保存…」 from the 「基本設定」/「その他の設定」 tabs: saves the current state into a new or an existing preset.
/// Only ticked items go into the preset; unticked ones stay "unchanged" when it is applied.
/// Overwriting keeps the preset's name, place in the list and app lists, and starts with the items it already had ticked.
struct PresetSaveSheet: View {
    @ObservedObject var settings: MacSettings
    @ObservedObject var countdown: Countdown
    @ObservedObject var presets: PresetStore
    let done: () -> Void

    enum Item: CaseIterable, Hashable {
        case clock, showDate, showWeekday, dark, hideDock, killDock, hideDesktop, pointerSize, resolution,
             keyboardAutomatic, keyboardBrightness, reduceTransparency, reduceMotion, zoomHotkeys, zoomStyle, zoomMinFactor, zoomMaxFactor, zoomToggleShortcut, zoomInShortcut, zoomOutShortcut,
             volumeFeedback, notificationsOff, hideOthers
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
                    row(.hideDock, L("Dock：自動非表示"), onOff(settings.dockHidden))
                    row(.killDock, L("Dock：完全非表示"), onOff(settings.dockKilled))
                    row(.hideOthers, L("アプリ切り替え時にほかを隠す"), onOff(settings.hideOthersOnSwitch) + " / \(settings.hideOthersDelay) " + L("秒後"))
                    row(.hideDesktop, L("デスクトップアイコンを非表示"), onOff(settings.desktopHidden))
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
                    row(.reduceMotion, L("視差効果を減らす"), onOff(settings.reduceMotion))
                    row(.keyboardAutomatic, L("環境光が暗い場合にキーボードの輝度を調整"), settings.keyboardAutomatic.map { $0 ? "ON" : "OFF" } ?? "–")
                    row(.keyboardBrightness, L("キーボードの輝度"), settings.keyboardBrightness.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                    row(.zoomHotkeys, L("キーボードショートカットを使って拡大・縮小"), onOff(settings.zoomHotkeys))
                    row(.zoomStyle, L("ズーム方法"), settings.zoomStyle.title)
                    row(.zoomMinFactor, L("最大縮小率"), settings.zoomMinFactor.map(ZoomSettings.text) ?? "–")
                    row(.zoomMaxFactor, L("最大拡大率"), settings.zoomMaxFactor.map(ZoomSettings.text) ?? "–")
                    row(.zoomToggleShortcut, L("ショートカット：ズーム機能のオン／オフ"), Self.shortcutTitle(ZoomSettings.toggleShortcut, settings.zoomToggleShortcut))
                    row(.zoomInShortcut, L("ショートカット：拡大"), Self.shortcutTitle(ZoomSettings.zoomInShortcut, settings.zoomInShortcut))
                    row(.zoomOutShortcut, L("ショートカット：縮小"), Self.shortcutTitle(ZoomSettings.zoomOutShortcut, settings.zoomOutShortcut))
                    row(.volumeFeedback, L("音量を変更するときにフィードバックを再生"), onOff(settings.volumeFeedback))
                    HStack {
                        Toggle(L("通知"), isOn: binding(.notificationsOff))
                        Spacer()
                        Picker(L("通知"), selection: $notificationsOff) {
                            Text(L("オン")).tag(false); Text(L("オフ")).tag(true)
                        }.labelsHidden().pickerStyle(.segmented).frame(width: 120).disabled(!included.contains(.notificationsOff))
                    }
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

    private static func shortcutTitle(_ shortcut: ZoomSettings.Shortcut, _ value: String) -> String {
        value == "off" ? L("オフ") : shortcut.choices.first { $0.value == value }?.title ?? L("その他")
    }

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
        included = Self.items(of: preset)
        notificationsOff = preset.notificationsOff ?? true
        resolutionDefault = preset.resolution?.isDisplayDefault ?? false
    }

    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !included.isEmpty }

    private func save() {
        var preset = presets.items.first { $0.id == targetID } ?? Preset()
        preset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Self.fill(&preset, included: included, notificationsOff: notificationsOff, resolutionDefault: resolutionDefault,
                  settings: settings, countdown: countdown)
        let overwriting = targetID != nil
        presets.save(preset)
        settings.error = false
        settings.message = L(overwriting ? "「%@」を上書き保存しました。" : "「%@」を保存しました。", preset.name)
        done()
    }

    /// Option-click 「プリセットに保存…」: overwrite without the sheet, keeping the preset's items, notification value
    /// (no readable state) and "display default" resolution.
    static func overwrite(_ preset: Preset, settings: MacSettings, countdown: Countdown, presets: PresetStore) {
        var preset = preset
        fill(&preset, included: items(of: preset), notificationsOff: preset.notificationsOff ?? true,
             resolutionDefault: preset.resolution?.isDisplayDefault ?? false, settings: settings, countdown: countdown)
        presets.save(preset)
        settings.error = false
        settings.message = L("「%@」を上書き保存しました。", preset.name)
    }

    /// The items a preset already sets.
    static func items(of preset: Preset) -> Set<Item> {
        let has: [Item: Bool] = [
            .clock: preset.clock != nil, .showDate: preset.showDate != nil, .showWeekday: preset.showWeekday != nil,
            .dark: preset.dark != nil, .hideDock: preset.hideDock != nil, .killDock: preset.killDock != nil,
            .hideDesktop: preset.hideDesktop != nil, .pointerSize: preset.pointerSize != nil, .resolution: preset.resolution != nil,
            .reduceTransparency: preset.reduceTransparency != nil, .reduceMotion: preset.reduceMotion != nil, .volumeFeedback: preset.volumeFeedback != nil,
            .zoomHotkeys: preset.zoomHotkeys != nil, .zoomStyle: preset.zoomStyle != nil, .keyboardAutomatic: preset.keyboardAutomatic != nil, .keyboardBrightness: preset.keyboardBrightness != nil, .zoomMinFactor: preset.zoomMinFactor != nil, .zoomMaxFactor: preset.zoomMaxFactor != nil,
            .zoomToggleShortcut: preset.zoomToggleShortcut != nil, .zoomInShortcut: preset.zoomInShortcut != nil, .zoomOutShortcut: preset.zoomOutShortcut != nil,
            .notificationsOff: preset.notificationsOff != nil,
            .hideOthers: preset.hideOthersOnSwitch != nil || preset.hideOthersDelay != nil]
        return Set(has.filter(\.value).map(\.key))
    }

    /// Writes the current values of the included items; the others become nil ("unchanged").
    private static func fill(_ preset: inout Preset, included: Set<Item>, notificationsOff: Bool, resolutionDefault: Bool,
                             settings: MacSettings, countdown: Countdown) {
        func value<T>(_ item: Item, _ current: T) -> T? { included.contains(item) ? current : nil }
        preset.hideOthersOnSwitch = value(.hideOthers, settings.hideOthersOnSwitch)
        preset.hideOthersDelay = value(.hideOthers, AppSwitchHider.delay(settings.hideOthersDelay))
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
        preset.reduceMotion = value(.reduceMotion, settings.reduceMotion)
        preset.volumeFeedback = value(.volumeFeedback, settings.volumeFeedback)
        preset.zoomHotkeys = value(.zoomHotkeys, settings.zoomHotkeys)
        preset.zoomStyle = value(.zoomStyle, settings.zoomStyle.rawValue)
        // Not saved while macOS has no value yet (the slider was never moved).
        preset.keyboardAutomatic = included.contains(.keyboardAutomatic) ? settings.keyboardAutomatic : nil
        preset.keyboardBrightness = included.contains(.keyboardBrightness) ? settings.keyboardBrightness : nil
        preset.zoomMinFactor = included.contains(.zoomMinFactor) ? settings.zoomMinFactor : nil
        preset.zoomMaxFactor = included.contains(.zoomMaxFactor) ? settings.zoomMaxFactor : nil
        preset.zoomToggleShortcut = value(.zoomToggleShortcut, settings.zoomToggleShortcut)
        preset.zoomInShortcut = value(.zoomInShortcut, settings.zoomInShortcut)
        preset.zoomOutShortcut = value(.zoomOutShortcut, settings.zoomOutShortcut)
        preset.notificationsOff = value(.notificationsOff, notificationsOff)
    }
}
