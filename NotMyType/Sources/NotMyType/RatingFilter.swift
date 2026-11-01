enum RatingFilter {
    static func matches(_ rating: Int, selection: Int) -> Bool {
        if selection < 0 { return true }
        if selection == 0 { return rating == 0 }
        return rating >= selection
    }
}
