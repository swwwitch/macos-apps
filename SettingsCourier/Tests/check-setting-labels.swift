import Foundation

func L(_ key: String, _ args: CVarArg...) -> String { key }
enum DockPresence { static let title = "Dock" }

@main enum LabelChecks {
    static func main() throws {
        assert(SettingLabels.resolve(key: "autoExportOnQuit", bundleID: "unrelated.app", bundle: nil) == nil)
        assert(SettingLabels.resolve(key: "autoExportOnQuit", bundleID: "jp.dtp-transit.settingscourier", bundle: nil) != nil)
        assert(SettingLabels.resolve(key: "hideFromDockAndAppSwitcher", bundleID: "unrelated.app", bundle: nil) == nil)
        assert(SettingLabels.resolve(key: "NSWindow Frame Main", bundleID: "any.app", bundle: nil) != nil)
        let value: NSDictionary = ["array": [true, 42, "sample"], "data": Data([0, 1, 255]), "date": Date(timeIntervalSince1970: 123)]
        let xml = SettingLabels.fullValue(value)
        let decoded = try PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil) as! NSDictionary
        assert((decoded["value"] as! NSDictionary).isEqual(value))
        print("PASS: scoped mapping, unknown fallback, internal values, typed nested plist round trip")
    }
}
