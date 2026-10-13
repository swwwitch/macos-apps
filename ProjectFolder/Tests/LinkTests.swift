import Foundation
@main struct LinkTests {
    static func main() {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("projectfolder-link-\(getpid())")
        try? fm.removeItem(at: root)
        let recent = root.appendingPathComponent("AT-Recent"), project = root.appendingPathComponent("ricoh-osaka-20261014")
        try! fm.createDirectory(at: recent, withIntermediateDirectories: true)
        try! fm.createDirectory(at: project, withIntermediateDirectories: true)
        // Missing collection folder: nothing is created.
        guard case .failure(.noFolder) = RecentLink.make(to: project, in: root.appendingPathComponent("none")) else { fatalError("noFolder") }
        // New link, then `ln -s -f`: an old link of the same name is replaced.
        guard case .success(let link) = RecentLink.make(to: project, in: recent) else { fatalError("make") }
        precondition(try! fm.destinationOfSymbolicLink(atPath: link.path) == project.path)
        guard case .success = RecentLink.make(to: project, in: recent) else { fatalError("replace") }
        // A real folder with that name is never removed (B10).
        try! fm.removeItem(at: link); try! fm.createDirectory(at: link, withIntermediateDirectories: false)
        guard case .failure(.occupied) = RecentLink.make(to: project, in: recent) else { fatalError("occupied") }
        precondition(fm.fileExists(atPath: link.path))
        try? fm.removeItem(at: root)
        print("PASS: AT-Recent link created, replaced like ln -sf, real items kept")
    }
}
