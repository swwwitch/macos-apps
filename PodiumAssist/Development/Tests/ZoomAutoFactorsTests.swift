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
        let viewport = CGRect(x: 100, y: 100, width: 400, height: 300)
        precondition(ZoomSettings.visible(CGRect(x: 120, y: 200, width: 200, height: 24), in: viewport))
        // AX exposes these tracks, but mouse events would hit something outside the scrolling content.
        precondition(!ZoomSettings.visible(CGRect(x: 120, y: 410, width: 200, height: 24), in: viewport))
        precondition(!ZoomSettings.visible(CGRect(x: 120, y: 390, width: 200, height: 24), in: viewport))
        precondition(!ZoomSettings.visible(CGRect(x: 120, y: 90, width: 200, height: 24), in: viewport))
        precondition(!ZoomSettings.visible(.zero, in: viewport))
        precondition(!ZoomSettings.visible(viewport, in: nil))
        let reportedViewport = CGRect(x: 901, y: 193, width: 470, height: 556)
        let reportedTrack = CGRect(x: 1146, y: 816.5, width: 195, height: 16)
        precondition(ZoomSettings.scrollDelta(track: reportedTrack, viewport: reportedViewport) == -200)
        precondition(ZoomSettings.scrollDelta(track: CGRect(x: 1146, y: 100, width: 195, height: 16), viewport: reportedViewport) == 200)
        precondition(ZoomSettings.scrollDelta(track: CGRect(x: 1146, y: 400, width: 195, height: 16), viewport: reportedViewport) == nil)
        print("PASS: automatic zoom factors and fully visible slider geometry")
    }
}
