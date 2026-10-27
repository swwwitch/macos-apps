import AppKit
import SwiftUI
import CoreText

struct FocusedFontCard: Identifiable {
    let file: FontFile
    let family: FontFamily
    let sample: String
    let size: Double
    let cardScale: Double
    var id: UUID { file.id }
}

@MainActor
final class FontCardPresentation: ObservableObject {
    static let shared = FontCardPresentation()
    @Published var card: FocusedFontCard?
    var opening = false
}

struct CardFlipEffect: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .opacity(abs(angle) >= 89 ? 0 : 1)
    }
}

struct FontCardDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showControls = true
    let family: FontFamily
    @State var sample: String
    @State var size: Double
    @State var cardScale: Double
    @State private var textMode = 2
    @State private var lineHeight = 1.0
    @State private var paragraphSpacing = 0.0
    @State private var columns = 1
    @State private var palt = false
    @State private var scheme = PreviewStyle.Scheme.blackOnWhite
    @State private var customForeground = Color.black
    @State private var customBackground = Color.white

    private var foreground: Color {
        switch scheme {
        case .blackOnWhite: return .black
        case .whiteOnBlack: return .white
        case .custom: return customForeground
        }
    }

    private var background: Color {
        switch scheme {
        case .blackOnWhite: return .white
        case .whiteOnBlack: return .black
        case .custom: return customBackground
        }
    }

    private var text: String {
        switch textMode {
        case 0: return "文字を並べると、言葉の表情が見えてきます。形の違いだけでなく、余白や行の流れにも目を向けてみましょう。読みやすさは、小さな工夫の積み重ねから生まれます。\n朝の光が窓辺に届き、机の上の本を照らしています。ページをめくるたびに、新しい考えや風景に出会います。静かな時間の中で、文字は読む人の想像を広げていきます。\n見出しには力強さを、本文には穏やかなリズムを。用途に合う書体を選び、文字の大きさと行間を調整すると、文章の印象も変わります。数字0123456789、記号や括弧「」も一緒に確認できます。"
        case 1: return "A typeface gives a voice to every word. Look closely at the shapes, the spaces between letters, and the rhythm of each line. Small differences can change the character of an entire page.\nMorning light reaches the desk beside the window. An open book invites us to explore unfamiliar places and consider a new idea. Clear typography makes room for the reader to pause, imagine, and continue.\nCompare a strong heading with a quiet paragraph. Adjust the size and line spacing to discover a comfortable pace. Numbers 0123456789 and punctuation bring another useful perspective to the comparison."
        default: return sample
        }
    }

    private func close() {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3)) {
            FontCardPresentation.shared.card = nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) { Label(L("一覧に戻る"), systemImage: "chevron.left") }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button { showControls.toggle() } label: {
                    Label(L("プレビューのオプション"), systemImage: "slider.horizontal.3")
                }
            }.buttonStyle(.borderless).padding(16)
            HStack(spacing: 0) {
            if let file = family.files.first, let face = file.faces.first,
               let font = PreviewFonts.font(file: file, face: face, size: size) {
                GeometryReader { geometry in
                    FontParagraphView(text: text, font: font, columns: columns, lineHeight: lineHeight,
                                      width: max(100, geometry.size.width - 16), foreground: NSColor(foreground), background: NSColor(background), palt: palt, paragraphSpacing: paragraphSpacing)
                }.padding(24).background(background)
            } else {
                Text(L("プレビューできません")).foregroundStyle(foreground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(background)
            }
            if showControls {
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(family.displayName).font(.headline)
                        if let face = family.files.first?.faces.first {
                            Text(face.displayStyle).font(.subheadline).foregroundStyle(.secondary)
                            Text(face.postScriptName).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.textSelection(.enabled)
                    Picker(L("テキスト"), selection: $textMode) {
                        Text(L("日本語")).tag(0)
                        Text(L("英語")).tag(1)
                        Text(L("カスタム")).tag(2)
                    }.pickerStyle(.segmented).labelsHidden()
                    if textMode == 2 {
                        TextEditor(text: $sample).frame(height: 140)
                            .border(Color.secondary.opacity(0.3))
                            .accessibilityLabel(L("比較するサンプルテキスト"))
                    }
                    Picker(L("配色"), selection: $scheme) {
                        ForEach(PreviewStyle.Scheme.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.radioGroup)
                    if scheme == .custom {
                        ColorPicker(L("文字の色"), selection: $customForeground, supportsOpacity: false)
                        ColorPicker(L("背景の色"), selection: $customBackground, supportsOpacity: false)
                    }
                    Text(L("文字サイズ") + "：\(Int(size)) pt")
                    Slider(value: $size, in: 12...96, step: 1).accessibilityLabel(L("文字サイズ"))
                    Toggle(L("プロポーショナルメトリクス（palt）"), isOn: $palt)
                    Text(L("行間") + "：" + String(format: "%.1f", lineHeight))
                    Slider(value: $lineHeight, in: 0.5...2.5, step: 0.1).accessibilityLabel(L("行間"))
                    Text(L("段落間のアキ") + "：\(Int(paragraphSpacing)) pt")
                    Slider(value: $paragraphSpacing, in: 0...96, step: 1).accessibilityLabel(L("段落間のアキ"))
                    Picker(L("カラム数"), selection: $columns) {
                        ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
                    }.pickerStyle(.segmented)
                }.padding(16)
            }.frame(width: 240)
            }
        }
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: AppSurface.color))
        .onExitCommand(perform: close)
        .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
    }
}

private struct FontParagraphView: NSViewRepresentable {
    let text: String
    let font: CTFont
    let columns: Int
    let lineHeight: Double
    let width: CGFloat
    let foreground: NSColor
    let background: NSColor
    let palt: Bool
    let paragraphSpacing: Double

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.documentView = FontParagraphCanvas()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let canvas = scroll.documentView as? FontParagraphCanvas else { return }
        let result = FontParagraphLayout.make(text: text, font: font, width: width, columns: columns, lineHeight: lineHeight, foreground: foreground, palt: palt, paragraphBefore: 0, paragraphAfter: paragraphSpacing)
        scroll.drawsBackground = true
        scroll.backgroundColor = background
        canvas.frames = result.frames
        canvas.frame.size = CGSize(width: width, height: result.height)
        canvas.setAccessibilityElement(true)
        canvas.setAccessibilityRole(.staticText)
        canvas.setAccessibilityValue(text)
        canvas.needsDisplay = true
    }
}

private final class FontParagraphCanvas: NSView {
    var frames: [CTFrame] = []
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        for frame in frames { CTFrameDraw(frame, context) }
        context.restoreGState()
    }
}
