import AppKit

/// Resolution of the main display (the one with the menu bar), with the public CoreGraphics display-mode API.
/// No permission is needed. A preset stores the size in points plus HiDPI, so it also works on another display
/// (e.g. a projector) when that display offers the same mode.
struct DisplayResolution: Codable, Hashable {
    var width: Int
    var height: Int
    var hiDPI: Bool

    /// "2560 × 1080" (HiDPI is the normal case; the low-resolution variant is marked).
    var text: String { "\(width) × \(height)" + (hiDPI ? "" : L("（低解像度）")) }

    init(width: Int, height: Int, hiDPI: Bool) { self.width = width; self.height = height; self.hiDPI = hiDPI }
    init(_ mode: CGDisplayMode) { self.init(width: mode.width, height: mode.height, hiDPI: mode.pixelWidth > mode.width) }

    static var mainDisplay: CGDirectDisplayID { CGMainDisplayID() }

    static var current: DisplayResolution? { CGDisplayCopyDisplayMode(mainDisplay).map(DisplayResolution.init) }

    private static func modes(_ display: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        return ((CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode]) ?? []).filter { $0.isUsableForDesktopGUI() }
    }

    /// Choices for the menus: the HiDPI sizes when the display has them (as System Settings shows), otherwise every size.
    /// Largest first; the current one is always included.
    static var choices: [DisplayResolution] {
        let all = Set(modes(mainDisplay).map(DisplayResolution.init))
        let hiDPI = all.filter(\.hiDPI)
        var list = Set(hiDPI.isEmpty ? all : hiDPI)
        if let current { list.insert(current) }
        return list.sorted { ($0.width, $0.height, $0.hiDPI ? 1 : 0) > ($1.width, $1.height, $1.hiDPI ? 1 : 0) }
    }

    /// Switches the main display; keeps the current refresh rate when that mode offers it. Saved permanently.
    static func set(_ target: DisplayResolution) throws {
        let display = mainDisplay
        let rate = CGDisplayCopyDisplayMode(display)?.refreshRate ?? 0
        let matches = modes(display).filter { DisplayResolution($0) == target }
        guard let mode = matches.first(where: { $0.refreshRate == rate }) ?? matches.first else {
            throw SettingsError(L("このディスプレイでは %@ を使えません。", target.text))
        }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { throw SettingsError(L("解像度を変更できませんでした。")) }
        guard CGConfigureDisplayWithDisplayMode(config, display, mode, nil) == .success,
              CGCompleteDisplayConfiguration(config, .permanently) == .success else {
            CGCancelDisplayConfiguration(config)
            throw SettingsError(L("解像度を変更できませんでした。"))
        }
    }
}
