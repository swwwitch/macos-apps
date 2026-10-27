/// セットを別のMacへ移しても、そのMacの識別名を保持する。
enum PresetImportPolicy {
    static func canImport(domains: [String]) -> Bool {
        !domains.contains("ComputerName")
    }
}

/// 共有可能なプリセットには、このMac固有の名前を保存しない。
enum PresetExportPolicy {
    static func removingMachineNames(from root: [String: Any]) -> [String: Any] {
        var result = root
        result.removeValue(forKey: "host")
        if let entries = result["entries"] as? [[String: Any]] {
            result["entries"] = entries.filter {
                guard let domains = $0["domains"] as? [String] else { return false }
                return PresetImportPolicy.canImport(domains: domains)
            }
        }
        return result
    }
}
