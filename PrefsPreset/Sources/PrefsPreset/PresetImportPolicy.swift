/// セットを別のMacへ移しても、そのMacの識別名を保持する。
enum PresetImportPolicy {
    static func canImport(domains: [String]) -> Bool {
        !domains.contains("ComputerName")
    }
}
