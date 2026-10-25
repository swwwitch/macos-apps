import AppKit
import CoreText
import SwiftUI

/// 字形の一覧：選んだファミリーの1書体のすべての字形を格子で並べる。字形番号で描くので、Unicode の無い異体字も出る。
/// クリックで選び、文字のある字形はコピーする。数万字形の書体もあるので、見えている分だけ描く（LazyVGrid）
struct GlyphGridView: View {
    let family: FontFamily
    @State private var faceKey: String?
    @State private var table: GlyphTable?
    @State private var selected: Int?
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var scope = GlyphTable.Scope.all
    @Binding var cellSize: Double

    private var faces: [(key: String, file: FontFile, face: FontFace)] {
        family.files.flatMap { file in file.faces.map { (file.path + "|" + $0.postScriptName, file, $0) } }
    }

    private var current: (key: String, file: FontFile, face: FontFace)? {
        faces.first { $0.key == faceKey } ?? faces.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker(L("書体"), selection: Binding(get: { current?.key ?? "" }, set: { faceKey = $0; selected = nil })) {
                    ForEach(faces, id: \.key) { item in Text(item.face.displayStyle).tag(item.key) }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
                Picker(L("字形"), selection: $scope) {
                    ForEach(GlyphTable.Scope.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                HStack(spacing: 4) {
                    TextField(L("文字・U+XXXX で探す"), text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !query.isEmpty {
                        Button { query = ""; searchFocused = true } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(L("検索を消去"))
                        .accessibilityLabel(L("検索を消去"))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(searchFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                                      lineWidth: searchFocused ? 2 : 1)
                }
            }
            .padding(8)
            Divider()
            if let table, let font = table.font {
                let indices = table.filtered(scope: scope, query: query)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: cellSize), spacing: 2)], spacing: 2) {
                        ForEach(indices, id: \.self) { index in
                            GlyphCell(font: font, glyph: CGGlyph(index), character: table.characters[index], size: cellSize,
                                      selected: selected == index)
                                .onTapGesture { select(index, in: table) }
                        }
                    }
                    .padding(8)
                }
                Divider()
                infoLine(table)
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .task(id: current?.key) { load() }
    }

    private func load() {
        guard let current else { return }
        table = nil
        table = GlyphTable(font: PreviewFonts.font(file: current.file, face: current.face, size: 64))
    }

    private func select(_ index: Int, in table: GlyphTable) {
        selected = index
        if let character = table.characters[index] {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(character), forType: .string)
        }
    }

    private func infoLine(_ table: GlyphTable) -> some View {
        HStack(spacing: 12) {
            if let selected {
                let character = table.characters[selected]
                Text(L("字形番号 %d", selected)).monospacedDigit()
                if let character {
                    Text(verbatim: character.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")).monospacedDigit()
                    Text(L("コピーしました"))
                } else {
                    Text(L("Unicodeなし（異体字など）"))
                }
                if let name = table.name(of: selected) { Text(name).textSelection(.enabled) }
            } else {
                Text(L("%d字形。クリックすると文字をコピーします", table.count))
            }
            Spacer()
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 8).padding(.vertical, 6)
    }
}

/// 字形番号ごとの文字（cmap の逆引き）と名前
struct GlyphTable {
    enum Scope: CaseIterable {
        case all, withUnicode, withoutUnicode
        var title: String {
            switch self {
            case .all: return L("すべての字形")
            case .withUnicode: return L("Unicodeあり")
            case .withoutUnicode: return L("Unicodeなし")
            }
        }
    }

    let font: CTFont?
    let count: Int
    /// 字形番号 → 文字（cmap に無ければ nil）
    let characters: [Character?]

    init(font: CTFont?) {
        self.font = font
        guard let font else { count = 0; characters = []; return }
        count = CTFontGetGlyphCount(font)
        var map = [Character?](repeating: nil, count: count)
        let set = CTFontCopyCharacterSet(font) as CharacterSet
        // 文字の集まりを面ごとに調べ、字形番号に逆引きする（同じ字形に複数の文字があれば先のほう）
        for plane: UInt8 in 0...16 where set.hasMember(inPlane: plane) {
            let start = UInt32(plane) << 16
            for value in start..<(start + 0x10000) {
                guard let scalar = Unicode.Scalar(value), set.contains(scalar) else { continue }
                var units = Array(String(scalar).utf16)
                var glyphs = [CGGlyph](repeating: 0, count: units.count)
                guard CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count), let glyph = glyphs.first,
                      Int(glyph) < count, map[Int(glyph)] == nil else { continue }
                map[Int(glyph)] = Character(scalar)
            }
        }
        characters = map
    }

    func name(of glyph: Int) -> String? {
        guard let font else { return nil }
        return CTFontCopyGraphicsFont(font, nil).name(for: CGGlyph(glyph)) as String?
    }

    func filtered(scope: Scope, query: String) -> [Int] {
        var indices = Array(0..<count)
        switch scope {
        case .all: break
        case .withUnicode: indices = indices.filter { characters[$0] != nil }
        case .withoutUnicode: indices = indices.filter { characters[$0] == nil }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return indices }
        // U+XXXX、または4〜6桁の16進表記（0037など）はUnicodeの完全一致。
        // それ以外は従来どおり文字そのものとして探す。
        let hasPrefix = trimmed.uppercased().hasPrefix("U+")
        let digits = hasPrefix ? String(trimmed.dropFirst(2)) : trimmed
        let isHex = !digits.isEmpty && digits.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (65...70).contains($0.value) || (97...102).contains($0.value)
        }
        if hasPrefix || ((4...6).contains(digits.count) && isHex) {
            guard isHex, let value = UInt32(digits, radix: 16), Unicode.Scalar(value) != nil else { return [] }
            return indices.filter { characters[$0]?.unicodeScalars.first?.value == value }
        }
        let wanted = Set(trimmed)
        return indices.filter { characters[$0].map(wanted.contains) ?? false }
    }
}

/// 1つの字形のます。字形番号で描く
private struct GlyphCell: View {
    let font: CTFont
    let glyph: CGGlyph
    let character: Character?
    let size: Double
    let selected: Bool

    var body: some View {
        VStack(spacing: 1) {
            Canvas { context, canvasSize in
                context.withCGContext { cg in
                    let fontSize = canvasSize.height * 0.72
                    let scaled = CTFontCreateCopyWithAttributes(font, fontSize, nil, nil)
                    var glyphCopy = glyph
                    var advance = CGSize.zero
                    CTFontGetAdvancesForGlyphs(scaled, .horizontal, &glyphCopy, &advance, 1)
                    // 下が原点の座標に直し、送り幅の中央・ベースラインを高さの22%に置く
                    cg.translateBy(x: 0, y: canvasSize.height)
                    cg.scaleBy(x: 1, y: -1)
                    cg.setFillColor(NSColor.labelColor.cgColor)
                    var position = CGPoint(x: (canvasSize.width - advance.width) / 2, y: canvasSize.height * 0.22)
                    CTFontDrawGlyphs(scaled, &glyphCopy, &position, 1, cg)
                }
            }
            .frame(width: size, height: size * 0.82)
            Text(character.map { String(format: "%04X", $0.unicodeScalars.first?.value ?? 0) } ?? "#\(glyph)")
                .font(.system(size: 8).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: 3).fill(selected ? Color.accentColor.opacity(0.25) : Color(nsColor: .controlBackgroundColor)))
        .help(character.map { String($0) } ?? L("Unicodeなし"))
    }
}
