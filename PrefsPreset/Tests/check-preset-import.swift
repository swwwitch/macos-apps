@main
struct PresetImportPolicyTests {
    static func main() {
        // All name keys (including legacy files and mixed-domain custom entries) are excluded.
        precondition(!PresetImportPolicy.canImport(domains: ["ComputerName"]))
        precondition(!PresetImportPolicy.canImport(domains: ["NSGlobalDomain", "ComputerName"]))
        precondition(PresetImportPolicy.canImport(domains: ["NSGlobalDomain"]))
        precondition(PresetImportPolicy.canImport(domains: ["com.apple.finder"]))
        let original: [String: Any] = [
            "format": "PrefsPreset", "host": "private-machine",
            "entries": [
                ["domains": ["ComputerName"], "key": "ComputerName", "value": "private-computer"],
                ["domains": ["ComputerName"], "key": "LocalHostName", "value": "private-local"],
                ["domains": ["ComputerName"], "key": "HostName", "value": "private-host"],
                ["domains": ["NSGlobalDomain", "ComputerName"], "key": "custom"],
                ["domains": ["com.apple.finder"], "key": "ShowPathbar", "value": true]
            ]
        ]
        let shared = PresetExportPolicy.removingMachineNames(from: original)
        precondition(shared["host"] == nil)
        let entries = shared["entries"] as! [[String: Any]]
        precondition(entries.count == 1 && entries[0]["key"] as? String == "ShowPathbar")
        precondition(entries[0]["value"] as? Bool == true)
        precondition((original["entries"] as! [[String: Any]]).count == 5)
        let second = PresetExportPolicy.removingMachineNames(from: shared)
        precondition((second["entries"] as! [[String: Any]]).count == 1)
        print("Preset import/export privacy policy passed")
    }
}
