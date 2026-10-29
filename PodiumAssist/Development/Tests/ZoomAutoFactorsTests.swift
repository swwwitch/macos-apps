import Foundation
@main struct ZoomAutoFactorsTests {
    static func main() {
        for (height, expected) in [(945.0, 1.89), (1080, 2.16), (250, 1), (20000, 20)] {
            let result = ZoomSettings.automaticFactors(height: height)!
            precondition(abs(result.min - expected) < 0.000001)
            precondition(abs(result.max - expected * 2) < 0.000001)
        }
        for height in [0.0, -1, Double.nan, Double.infinity] {
            precondition(ZoomSettings.automaticFactors(height: height) == nil)
        }
        print("PASS: automatic zoom factors, display height, limits, invalid heights")
    }
}
