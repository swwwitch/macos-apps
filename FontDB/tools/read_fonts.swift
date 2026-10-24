// フォルダー内のフォントファイル（.otf .ttf .ttc .otc）の名前を CoreText で読み、1書体1行の JSON で書き出す。
// 使い方: swift read_fonts.swift <フォルダー> > fonts.jsonl
import CoreText
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let exts: Set<String> = ["otf", "ttf", "ttc", "otc"]

/// 名前を英語と日本語で取り出す（日本語名が無ければ空）
func names(_ font: CTFont, _ key: CFString) -> (String, String) {
    let en = CTFontCopyName(font, key) as String? ?? ""
    var lang: Unmanaged<CFString>?
    let localized = CTFontCopyLocalizedName(font, key, &lang) as String? ?? ""
    let isJa = (lang?.takeUnretainedValue() as String?)?.hasPrefix("ja") ?? false
    return (en, isJa && localized != en ? localized : "")
}

let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
    .compactMap { $0 as? URL }
    .filter { exts.contains($0.pathExtension.lowercased()) }
    .sorted { $0.path < $1.path }

for url in files {
    guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { continue }
    for d in descs {
        let font = CTFontCreateWithFontDescriptor(d, 12, nil)
        let (family, familyJa) = names(font, kCTFontFamilyNameKey)
        let (style, styleJa) = names(font, kCTFontStyleNameKey)
        let (full, fullJa) = names(font, kCTFontFullNameKey)
        let rec: [String: Any] = [
            "path": url.path.replacingOccurrences(of: root.path + "/", with: ""),
            "fileName": url.lastPathComponent,
            "postScriptName": CTFontCopyPostScriptName(font) as String,
            "family": family, "familyJa": familyJa,
            "style": style, "styleJa": styleJa,
            "fullName": full, "fullNameJa": fullJa,
            "version": CTFontCopyName(font, kCTFontVersionNameKey) as String? ?? "",
            "glyphCount": CTFontGetGlyphCount(font),
        ]
        let data = try! JSONSerialization.data(withJSONObject: rec, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
}
