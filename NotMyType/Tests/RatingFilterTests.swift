@main struct RatingFilterTests {
    static func main() {
        let ratings = Array(0...5)
        precondition(ratings.filter { RatingFilter.matches($0, selection: -1) } == ratings)
        precondition(ratings.filter { RatingFilter.matches($0, selection: 0) } == [0])
        for threshold in 1...5 {
            precondition(ratings.filter { RatingFilter.matches($0, selection: threshold) } == Array(threshold...5))
        }
        precondition(ratings.filter { RatingFilter.matches($0, selection: 3) } == [3, 4, 5])
        print("PASS: all, unrated, every minimum threshold, and three-star acceptance case")
    }
}
