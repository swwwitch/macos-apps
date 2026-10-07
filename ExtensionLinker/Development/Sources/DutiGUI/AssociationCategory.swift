import Foundation

enum AssociationCategory: String, CaseIterable, Identifiable {
    case all = "すべて"
    case design = "デザイン"
    case business = "ビジネス"
    case text = "テキスト"
    case development = "開発"
    case other = "その他"

    var id: String { rawValue }
    var displayName: String { L(rawValue) }

    static func category(for ext: String) -> Self {
        switch AssociationService.canonicalExtension(ext.lowercased()) {
        case "ai", "eps", "svg", "psd", "psb", "indd", "idml", "afdesign", "afphoto", "afpub",
             "gif", "jpg", "png", "webp", "tif", "heic", "heif", "avif", "bmp", "ico", "raw", "dng":
            return .design
        case "csv", "tsv", "xls", "xlsx", "xlsm", "numbers", "doc", "docx", "pages",
             "ppt", "pptx", "key", "pdf", "odt", "ods", "odp":
            return .business
        case "txt", "rtf", "md":
            return .text
        case "html", "css", "scss", "sass", "less", "js", "jsx", "ts", "tsx", "json", "xml",
             "yaml", "yml", "swift", "py", "rb", "php", "sh", "c", "h", "cpp", "rs", "go":
            return .development
        default:
            return .other
        }
    }
}
