import Foundation
@main struct DuplicateFolderPriorityTests {
    static func main() {
        let watched = ["/Archive/", "/Users/test/", "/Library/"]
        func rank(_ path: String) -> Int {
            DuplicateFolderPriority.rank(path: path, folderPrefixes: watched, userFontsPrefix: "/Users/test/Library/Fonts/")
        }
        precondition(rank("/Users/test/Library/Fonts/font.otf") == -2)
        precondition(rank("/Users/test/Library/Fonts/MorisawaFonts/font.otf") == -2)
        precondition(rank("/Library/Fonts/oh_my_font/.font.otf") == -1)
        precondition(rank("/Archive/font.otf") == 0)
        precondition(rank("/Users/test/Library/Fonts-old/font.otf") == 1)
        precondition(rank("/Library/Fonts-old/font.otf") == 2)
        precondition(rank("/System/Library/Fonts/font.otf") == 3)
        precondition(rank("/Unknown/font.otf") == 3)
        precondition(rank("/Users/other/Library/Fonts/font.otf") == 3)
        print("PASS: installed folders, nested folders, boundaries, watched order, fallback")
    }
}
