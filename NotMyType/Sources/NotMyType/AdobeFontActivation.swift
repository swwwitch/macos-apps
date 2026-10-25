import Foundation
import CoreText

/// Changes matching without moving Adobe's files or importing its cache.
/// Only fonts registered by Creative Cloud, or disabled here, may be enabled.
enum AdobeFontActivation {
    private static let key = "adobeFonts.disabled.v1"

    private static func fingerprint(_ url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize, let date = values.contentModificationDate else { return nil }
        return "\(size):\(date.timeIntervalSince1970)"
    }

    static func wasDisabledHere(_ url: URL) -> Bool {
        guard let fingerprint = fingerprint(url) else { return false }
        return UserDefaults.standard.dictionary(forKey: key)?[url.standardizedFileURL.path] as? String == fingerprint
    }

    static func setEnabled(_ enabled: Bool, url: URL) -> String? {
        guard let stamp = fingerprint(url),
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              !descriptors.isEmpty else { return L("フォントとして読めません") }
        guard CTFontManagerGetScopeForURL(url as CFURL) != .none || wasDisabledHere(url) else {
            return L("Creative Cloudでこのフォントを有効にしてから、もう一度お試しください。")
        }
        CTFontManagerEnableFontDescriptors(descriptors as CFArray, enabled)
        // This API returns no error. Check fresh matching descriptors, not the
        // enabled attribute of file descriptors (it remains true after disabling).
        let matches = descriptors.map { descriptor -> Bool in
            guard let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) else { return false }
            let query = CTFontDescriptorCreateWithAttributes([kCTFontNameAttribute: name] as CFDictionary)
            let required = NSSet(array: [kCTFontNameAttribute]) as CFSet
            let found = CTFontDescriptorCreateMatchingFontDescriptors(query, required) as? [CTFontDescriptor] ?? []
            return found.contains {
                guard let candidate = CTFontDescriptorCopyAttribute($0, kCTFontURLAttribute) as? URL else { return false }
                return candidate.resolvingSymlinksInPath() == url.resolvingSymlinksInPath()
            }
        }
        // Keep recovery information even if only some faces changed.
        var disabled = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        if !enabled { disabled[url.standardizedFileURL.path] = stamp }
        let verified = enabled ? matches.allSatisfy { $0 } : matches.allSatisfy { !$0 }
        if enabled && verified { disabled.removeValue(forKey: url.standardizedFileURL.path) }
        UserDefaults.standard.set(disabled, forKey: key)
        return verified ? nil : L("Adobe Fontsの状態変更を確認できませんでした。Creative Cloudの状態を確認してください。")
    }
}
