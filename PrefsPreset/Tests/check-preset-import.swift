@main
struct PresetImportPolicyTests {
    static func main() {
        // Both name keys (including legacy files and mixed-domain custom entries) are excluded.
        precondition(!PresetImportPolicy.canImport(domains: ["ComputerName"]))
        precondition(!PresetImportPolicy.canImport(domains: ["NSGlobalDomain", "ComputerName"]))
        precondition(PresetImportPolicy.canImport(domains: ["NSGlobalDomain"]))
        precondition(PresetImportPolicy.canImport(domains: ["com.apple.finder"]))
        print("Preset import policy passed")
    }
}
