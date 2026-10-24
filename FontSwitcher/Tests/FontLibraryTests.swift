// Harness: swiftc Sources/FontSwitcher/FontLibrary.swift Sources/FontSwitcher/Localization.swift Tests/FontLibraryTests.swift
// Run with a folder of test fonts that are not installed. Activates them for the session and deactivates them again.
import Foundation

@main
struct FontLibraryTests {
    static func check(_ condition: Bool, _ label: String) {
        print((condition ? "PASS " : "FAIL ") + label)
        if !condition { exit(1) }
    }
    static func main() {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let urls = FontScanner.fontURLs(in: [folder])
        check(!urls.isEmpty, "scan finds fonts in subfolders (\(urls.count))")
        let files = urls.compactMap(FontScanner.read)
        check(files.count == urls.count, "every font is readable")
        var data = LibraryData()
        check(data.add(files) == files.count, "add all")
        check(data.add(files) == 0, "same paths are not added twice")
        let duplicates = data.duplicateFileIDs
        print("  duplicates:", duplicates.count, "families:", data.families(of: data.files).map(\.name))
        for file in files where !duplicates.contains(file.id) {
            check(FontActivation.state(of: file) == .inactive, "\(file.fileName) starts inactive")
            check(FontActivation.activate(file) == nil, "activate \(file.fileName)")
            check(FontActivation.activate(file) == nil, "activating twice is not an error")
            check(FontActivation.state(of: file) == .active, "\(file.fileName) is active")
            check(FontActivation.deactivate(file) == nil, "deactivate \(file.fileName)")
            check(FontActivation.deactivate(file) == nil, "deactivating twice is not an error")
            check(FontActivation.state(of: file) == .inactive, "\(file.fileName) is inactive again")
        }
        var missing = files[0]
        missing.path += ".gone"
        check(FontActivation.state(of: missing) == .missing, "moved file is missing")
        data.sets.append(FontSet(name: "S", files: [files[0].id]))
        data.active.insert(files[0].id)
        data.remove([files[0].id])
        check(data.sets[0].files.isEmpty && data.active.isEmpty, "remove clears sets and active")
        // Portable paths: Dropbox (inside home) wins over ~, and an unknown account stays as is.
        let roots = ["business": "/Users/a/sw Dropbox/a b", "personal": "/Users/a/Dropbox"]
        let home = "/Users/a"
        let inDropbox = "/Users/a/sw Dropbox/a b/fonts/X.otf"
        check(PortablePath.encode(inDropbox, roots: roots, home: home) == "$DROPBOX-business/fonts/X.otf", "encode Dropbox path")
        check(PortablePath.decode("$DROPBOX-business/fonts/X.otf", roots: ["business": "/Users/b/Dropbox (Team)"], home: "/Users/b")
              == "/Users/b/Dropbox (Team)/fonts/X.otf", "decode on another Mac")
        check(PortablePath.encode("/Users/a/Library/Fonts/Y.otf", roots: roots, home: home) == "~/Library/Fonts/Y.otf", "encode home path")
        check(PortablePath.decode("~/Library/Fonts/Y.otf", roots: roots, home: "/Users/b") == "/Users/b/Library/Fonts/Y.otf", "decode home path")
        check(PortablePath.encode("/Volumes/Fonts/Z.otf", roots: roots, home: home) == "/Volumes/Fonts/Z.otf", "other paths unchanged")
        check(PortablePath.decode("$DROPBOX-personal/Z.otf", roots: [:], home: home) == "$DROPBOX-personal/Z.otf", "unknown account unchanged")

        // Merge: same path keeps one id, sets merge by name, active and favorites are combined.
        let a = FontFile(path: "/f/A.otf", faces: [FontFace(postScriptName: "A", family: "A", style: "", fullName: "A")])
        let b = FontFile(path: "/f/B.otf", faces: [FontFace(postScriptName: "B", family: "B", style: "", fullName: "B")])
        var a2 = a; a2.id = UUID()
        var mine = LibraryData(); mine.files = [a]; mine.sets = [FontSet(name: "S", files: [a.id])]; mine.favorites = ["A"]
        var theirs = LibraryData(); theirs.files = [a2, b]; theirs.sets = [FontSet(name: "S", files: [a2.id, b.id]), FontSet(name: "T", files: [b.id])]
        theirs.active = [a2.id, b.id]; theirs.favorites = ["B"]
        check(mine.merge(theirs) == 1, "merge adds only the new path")
        check(mine.files.count == 2 && mine.sets.count == 2 && mine.sets[0].files == [a.id, b.id], "merge sets by name with mapped ids")
        check(mine.active == [a.id, b.id] && mine.favorites == ["A", "B"], "merge active and favorites")

        // Files from 1.0/1.1 have no favorites key.
        let old = #"{"active":[],"files":[],"sets":[]}"#.data(using: .utf8)!
        check((try? JSONDecoder().decode(LibraryData.self, from: old))?.favorites == [], "old library file decodes")
        print("ALL PASS")
    }
}
