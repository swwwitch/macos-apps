import Foundation

// Only needed to compile FontLibrary independently; smart-set evaluation is not exercised.
struct SmartSet: Codable, Identifiable, Hashable, Sendable { var id = UUID() }

@main struct FamilyNodeCacheTests {
    @inline(never) static func consume(_ nodes: [FamilyNode]) -> Int {
        nodes.count + (nodes.first?.children?.count ?? 0) + (nodes.last?.id.utf8.count ?? 0)
    }
    static func families(_ fileCount: Int) -> [FontFamily] {
        (0..<(fileCount / 4)).map { index in
            let name = "Family \(index)"
            let files = (0..<4).map { weight in
                FontFile(path: "/test/\(index)-\(weight).otf", faces: [
                    FontFace(postScriptName: "PS-\(index)-\(weight)", family: name, style: "Weight \(weight)", fullName: name)
                ])
            }
            return FontFamily(name: name, files: files)
        }
    }
    static func main() {
        var cache = FamilyNodeCache()
        var input = families(8000)
        let original = FamilyNode.nodes(input)
        let first = cache.nodes(for: input, version: 0)
        precondition(first == original, "row order, identifiers and children must match")
        let again = cache.nodes(for: input, version: 0)
        first.withUnsafeBufferPointer { a in
            again.withUnsafeBufferPointer { b in precondition(a.baseAddress == b.baseAddress, "same revision must reuse storage") }
        }
        input[0].files[0].faces[0].fullName = "Changed"
        let refreshed = cache.nodes(for: input, version: 1)
        precondition(refreshed == FamilyNode.nodes(input) && refreshed != first)
        precondition(cache.nodes(for: [], version: 2).isEmpty)
        precondition(cache.nodes(for: Array(input.reversed()), version: 3) == FamilyNode.nodes(Array(input.reversed())))
        print("PASS node IDs, order, children, storage reuse, metadata refresh, removal and reorder")
        for count in [8000, 40000] {
            let items = families(count)
            let iterations = 100
            var cached = FamilyNodeCache()
            _ = cached.nodes(for: items, version: 0)
            var checksum = 0
            let start = ProcessInfo.processInfo.systemUptime
            for _ in 0..<iterations { checksum &+= consume(FamilyNode.nodes(items)) }
            let uncachedMS = (ProcessInfo.processInfo.systemUptime - start) * 1000
            let cachedStart = ProcessInfo.processInfo.systemUptime
            for _ in 0..<iterations { checksum &+= consume(cached.nodes(for: items, version: 0)) }
            let cachedMS = (ProcessInfo.processInfo.systemUptime - cachedStart) * 1000
            print(String(format: "%d files, %d accesses: rebuild %.3f ms; reuse %.3f ms; checksum %d", count, iterations, uncachedMS, cachedMS, checksum))
        }
    }
}
