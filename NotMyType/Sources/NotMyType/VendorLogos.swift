import SwiftUI

/// アドビのロゴ（ユーザー指定。adobe.com の mobile-adobe-logo-black.svg のパスを写したもの、viewBox 18×16）。
/// 枠に合わせて縦横比を保って縮める
struct AdobeLogo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 17.5512, y: 15.9999))
        path.addLine(to: CGPoint(x: 13.8827, y: 15.9999))
        path.addCurve(to: CGPoint(x: 13.4326, y: 15.8735), control1: CGPoint(x: 13.7233, y: 16.0027), control2: CGPoint(x: 13.5666, y: 15.9587))
        path.addCurve(to: CGPoint(x: 13.1303, y: 15.5211), control1: CGPoint(x: 13.2987, y: 15.7882), control2: CGPoint(x: 13.1934, y: 15.6656))
        path.addLine(to: CGPoint(x: 9.1476, y: 6.3291))
        path.addCurve(to: CGPoint(x: 9.0854, y: 6.2392), control1: CGPoint(x: 9.1372, y: 6.2933), control2: CGPoint(x: 9.1154, y: 6.2618))
        path.addCurve(to: CGPoint(x: 8.9812, y: 6.2036), control1: CGPoint(x: 9.0555, y: 6.2166), control2: CGPoint(x: 9.0189, y: 6.2041))
        path.addCurve(to: CGPoint(x: 8.876, y: 6.2365), control1: CGPoint(x: 8.9435, y: 6.2032), control2: CGPoint(x: 8.9066, y: 6.2147))
        path.addCurve(to: CGPoint(x: 8.8115, y: 6.3248), control1: CGPoint(x: 8.8455, y: 6.2583), control2: CGPoint(x: 8.8229, y: 6.2893))
        path.addLine(to: CGPoint(x: 6.3295, y: 12.161))
        path.addCurve(to: CGPoint(x: 6.314, y: 12.261), control1: CGPoint(x: 6.3161, y: 12.1925), control2: CGPoint(x: 6.3107, y: 12.2269))
        path.addCurve(to: CGPoint(x: 6.3482, y: 12.3565), control1: CGPoint(x: 6.3172, y: 12.2951), control2: CGPoint(x: 6.329, y: 12.3279))
        path.addCurve(to: CGPoint(x: 6.424, y: 12.4246), control1: CGPoint(x: 6.3674, y: 12.385), control2: CGPoint(x: 6.3934, y: 12.4084))
        path.addCurve(to: CGPoint(x: 6.5234, y: 12.4493), control1: CGPoint(x: 6.4546, y: 12.4408), control2: CGPoint(x: 6.4887, y: 12.4493))
        path.addLine(to: CGPoint(x: 9.2516, y: 12.4493))
        path.addCurve(to: CGPoint(x: 9.484, y: 12.5183), control1: CGPoint(x: 9.3343, y: 12.4493), control2: CGPoint(x: 9.4151, y: 12.4733))
        path.addCurve(to: CGPoint(x: 9.639, y: 12.7026), control1: CGPoint(x: 9.5529, y: 12.5634), control2: CGPoint(x: 9.6068, y: 12.6275))
        path.addLine(to: CGPoint(x: 10.8335, y: 15.3264))
        path.addCurve(to: CGPoint(x: 10.8704, y: 15.5599), control1: CGPoint(x: 10.8652, y: 15.4), control2: CGPoint(x: 10.8778, y: 15.4802))
        path.addCurve(to: CGPoint(x: 10.791, y: 15.7828), control1: CGPoint(x: 10.863, y: 15.6395), control2: CGPoint(x: 10.8357, y: 15.7161))
        path.addCurve(to: CGPoint(x: 10.6142, y: 15.9421), control1: CGPoint(x: 10.7463, y: 15.8495), control2: CGPoint(x: 10.6856, y: 15.9042))
        path.addCurve(to: CGPoint(x: 10.3821, y: 15.9999), control1: CGPoint(x: 10.5429, y: 15.98), control2: CGPoint(x: 10.4631, y: 15.9998))
        path.addLine(to: CGPoint(x: 0.4501, y: 15.9999))
        path.addCurve(to: CGPoint(x: 0.2364, y: 15.9455), control1: CGPoint(x: 0.3754, y: 15.9994), control2: CGPoint(x: 0.302, y: 15.9808))
        path.addCurve(to: CGPoint(x: 0.074, y: 15.7979), control1: CGPoint(x: 0.1707, y: 15.9103), control2: CGPoint(x: 0.115, y: 15.8595))
        path.addCurve(to: CGPoint(x: 0.0017, y: 15.592), control1: CGPoint(x: 0.0331, y: 15.7362), control2: CGPoint(x: 0.0083, y: 15.6655))
        path.addCurve(to: CGPoint(x: 0.0366, y: 15.3769), control1: CGPoint(x: -0.0048, y: 15.5185), control2: CGPoint(x: 0.0072, y: 15.4446))
        path.addLine(to: CGPoint(x: 6.3541, y: 0.5265))
        path.addCurve(to: CGPoint(x: 6.6728, y: 0.1411), control1: CGPoint(x: 6.4187, y: 0.3693), control2: CGPoint(x: 6.5298, y: 0.235))
        path.addCurve(to: CGPoint(x: 7.1562, y: 0.0001), control1: CGPoint(x: 6.8159, y: 0.0472), control2: CGPoint(x: 6.9844, y: -0.002))
        path.addLine(to: CGPoint(x: 10.7999, y: 0.0001))
        path.addCurve(to: CGPoint(x: 11.2835, y: 0.1408), control1: CGPoint(x: 10.9718, y: -0.0022), control2: CGPoint(x: 11.1403, y: 0.0469))
        path.addCurve(to: CGPoint(x: 11.6021, y: 0.5265), control1: CGPoint(x: 11.4266, y: 0.2347), control2: CGPoint(x: 11.5377, y: 0.3692))
        path.addLine(to: CGPoint(x: 17.9633, y: 15.3769))
        path.addCurve(to: CGPoint(x: 17.9983, y: 15.5917), control1: CGPoint(x: 17.9927, y: 15.4445), control2: CGPoint(x: 18.0048, y: 15.5183))
        path.addCurve(to: CGPoint(x: 17.9264, y: 15.7973), control1: CGPoint(x: 17.9919, y: 15.665), control2: CGPoint(x: 17.9672, y: 15.7357))
        path.addCurve(to: CGPoint(x: 17.7646, y: 15.9451), control1: CGPoint(x: 17.8856, y: 15.859), control2: CGPoint(x: 17.83, y: 15.9097))
        path.addCurve(to: CGPoint(x: 17.5512, y: 15.9999), control1: CGPoint(x: 17.6991, y: 15.9804), control2: CGPoint(x: 17.6258, y: 15.9992))
        path.closeSubpath()
        let scale = min(rect.width / 18, rect.height / 16)
        let offset = CGPoint(x: rect.midX - 9 * scale, y: rect.midY - 8 * scale)
        return path.applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: offset.x, y: offset.y)))
    }
}

/// Adobe Fonts のアイコン（ユーザー指定の画像にならう：濃紺の角丸の四角に、白い斜体の「f」）
struct AdobeFontsIcon: View {
    var body: some View {
        Text("f")
            .font(.system(size: 13, design: .serif).italic())
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.006, green: 0.044, blue: 0.146)))
            .accessibilityHidden(true)
    }
}

/// モリサワのアイコン：ロゴ（ユーザー提供の SVG、Assets/VendorLogos/morisawa.svg）の左の記号。青と灰のアーチ2つ（元の座標で幅50.8×高さ38）
struct MorisawaMark: View {
    var body: some View {
        ZStack {
            MorisawaArch(part: .left).fill(Color(red: 0, green: 0.235, blue: 1))
            MorisawaArch(part: .right).fill(Color(red: 0.8, green: 0.8, blue: 0.8))
        }
    }
}

struct MorisawaArch: Shape {
    enum Part { case left, right }
    let part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .left:
            path.move(to: CGPoint(x: 12.666, y: 0))
            path.addLine(to: CGPoint(x: 12.666, y: 0))
            path.addCurve(to: CGPoint(x: 2.146, y: 5.621), control1: CGPoint(x: 8.44, y: -0.002), control2: CGPoint(x: 4.493, y: 2.107))
            path.addCurve(to: CGPoint(x: 0.739, y: 8.762), control1: CGPoint(x: 1.531, y: 6.596), control2: CGPoint(x: 1.057, y: 7.654))
            path.addCurve(to: CGPoint(x: 0.25, y: 11.1), control1: CGPoint(x: 0.521, y: 9.529), control2: CGPoint(x: 0.357, y: 10.31))
            path.addCurve(to: CGPoint(x: -0, y: 16.266), control1: CGPoint(x: 0.06, y: 12.815), control2: CGPoint(x: -0.023, y: 14.54))
            path.addLine(to: CGPoint(x: -0, y: 38))
            path.addLine(to: CGPoint(x: 25.331, y: 38))
            path.addLine(to: CGPoint(x: 25.331, y: 12.666))
            path.addCurve(to: CGPoint(x: 12.666, y: 0), control1: CGPoint(x: 25.331, y: 5.671), control2: CGPoint(x: 19.661, y: 0))
            path.closeSubpath()
        case .right:
            path.move(to: CGPoint(x: 37.993, y: 0))
            path.addLine(to: CGPoint(x: 37.993, y: 0))
            path.addCurve(to: CGPoint(x: 48.513, y: 5.621), control1: CGPoint(x: 42.219, y: -0.002), control2: CGPoint(x: 46.166, y: 2.107))
            path.addCurve(to: CGPoint(x: 49.92, y: 8.762), control1: CGPoint(x: 49.128, y: 6.596), control2: CGPoint(x: 49.602, y: 7.654))
            path.addCurve(to: CGPoint(x: 50.41, y: 11.101), control1: CGPoint(x: 50.139, y: 9.529), control2: CGPoint(x: 50.302, y: 10.311))
            path.addCurve(to: CGPoint(x: 50.66, y: 16.266), control1: CGPoint(x: 50.6, y: 12.816), control2: CGPoint(x: 50.683, y: 14.541))
            path.addLine(to: CGPoint(x: 50.66, y: 38))
            path.addLine(to: CGPoint(x: 25.331, y: 38))
            path.addLine(to: CGPoint(x: 25.331, y: 12.666))
            path.addCurve(to: CGPoint(x: 37.993, y: 0), control1: CGPoint(x: 25.331, y: 5.672), control2: CGPoint(x: 30.999, y: 0.002))
            path.closeSubpath()
        }
        let scale = min(rect.width / 50.8, rect.height / 38)
        let offset = CGPoint(x: rect.midX - 25.4 * scale, y: rect.midY - 19 * scale)
        return path.applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: offset.x, y: offset.y)))
    }
}

/// フォントワークスのアイコン（ユーザー指定の画像を見て描き起こした近似：右上が跳ね上がった赤い旗の形）
struct FontworksLogo: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let points: [(CGFloat, CGFloat)] = [(0.06, 0.18), (0.70, 0.18), (0.96, 0.06), (0.78, 0.52), (0.78, 0.92), (0.06, 0.92)]
        var path = Path()
        path.addLines(points.map { CGPoint(x: origin.x + $0.0 * side, y: origin.y + $0.1 * side) })
        path.closeSubpath()
        return path
    }
}

/// サイドバーのベンダーの行のアイコン（16pt）
struct VendorIcon: View {
    let id: String

    var body: some View {
        Group {
            switch id {
            case "MRSW": MorisawaMark()
            case "FWKS": FontworksLogo().fill(Color(red: 0.86, green: 0.2, blue: 0.13))
            default: AdobeLogo().fill(Color.primary)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
