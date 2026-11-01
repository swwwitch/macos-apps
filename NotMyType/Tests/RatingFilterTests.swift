@main struct RatingFilterTests {
    static func main() {
        let ratings = Array(0...5)
        precondition(ratings.filter { RatingFilter.matches($0, selection: -1) } == ratings)
        precondition(ratings.filter { RatingFilter.matches($0, selection: 0) } == [0])
        for threshold in 1...5 {
            precondition(ratings.filter { RatingFilter.matches($0, selection: threshold) } == Array(threshold...5))
        }
        precondition(ratings.filter { RatingFilter.matches($0, selection: 3) } == [3, 4, 5])
        // Every selected subset: keyboard edits exactly the visible selected cards.
        for threshold in -1...5 {
            let visible = ratings.filter { RatingFilter.matches($0, selection: threshold) }
            for mask in 0..<64 {
                let selected = ratings.filter { mask & (1 << $0) != 0 }
                let keyboard = ratings.filter { RatingFilter.matches($0, selection: threshold) && selected.contains($0) }
                precondition(keyboard == visible.filter { selected.contains($0) })
            }
        }
        print("PASS: all, unrated, every minimum threshold, and three-star acceptance case")
    }
}
