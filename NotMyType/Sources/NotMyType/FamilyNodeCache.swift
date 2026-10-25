/// One revision only: bounded storage, invalidated by LibraryStore.listVersion.
struct FamilyNodeCache {
    private var version: Int?
    private var cached: [FamilyNode] = []

    mutating func nodes(for families: [FontFamily], version: Int) -> [FamilyNode] {
        if self.version != version {
            cached = FamilyNode.nodes(families)
            self.version = version
        }
        return cached
    }
}
