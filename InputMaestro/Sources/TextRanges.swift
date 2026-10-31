import Foundation

/// One paragraph of a text, in UTF-16 offsets (as the Accessibility API counts).
struct Paragraph: Equatable {
    var start: Int
    /// End of the text, before the break.
    var contentEnd: Int
    /// After the break (contentEnd for the last paragraph).
    var end: Int
}

/// Paragraph ranges for the 段落と行の編集 commands. Ported from the JXA scripts MoveParagraph / SelectParagraph / CutToLineStart.
enum TextRanges {
    /// Breaks are \r\n, \r, \n and U+2029 (paragraph separator).
    static func paragraphs(_ text: NSString) -> [Paragraph] {
        var result: [Paragraph] = []
        var start = 0, index = 0
        let length = text.length
        while index < length {
            let unit = text.character(at: index)
            if unit == 0x0A || unit == 0x0D || unit == 0x2029 {
                let breakLength = (unit == 0x0D && index + 1 < length && text.character(at: index + 1) == 0x0A) ? 2 : 1
                result.append(Paragraph(start: start, contentEnd: index, end: index + breakLength))
                index += breakLength
                start = index
            } else {
                index += 1
            }
        }
        result.append(Paragraph(start: start, contentEnd: length, end: length))
        return result
    }

    /// The paragraph holding an offset: the caret just before a break is in that paragraph, just after it in the next.
    static func index(at offset: Int, in paragraphs: [Paragraph]) -> Int {
        paragraphs.firstIndex { offset <= $0.contentEnd } ?? max(paragraphs.count - 1, 0)
    }

    /// ⌃A / ⌃E: the caret at the start / end of its paragraph. Extending keeps the other end of the selection.
    static func paragraphEdge(_ text: NSString, selection: NSRange, end: Bool, extend: Bool) -> NSRange {
        let list = paragraphs(text)
        if end {
            let target = list[index(at: NSMaxRange(selection), in: list)].contentEnd
            return extend ? NSRange(location: selection.location, length: max(target - selection.location, 0)) : NSRange(location: target, length: 0)
        }
        let target = list[index(at: selection.location, in: list)].start
        return extend ? NSRange(location: target, length: NSMaxRange(selection) - target) : NSRange(location: target, length: 0)
    }

    /// ⌃K: from the caret to the end of its paragraph; at the end, the break itself (as Emacs does).
    /// A selection is killed as it is.
    static func killToLineEnd(_ text: NSString, selection: NSRange) -> NSRange {
        if selection.length > 0 { return selection }
        let list = paragraphs(text)
        let paragraph = list[index(at: selection.location, in: list)]
        let end = selection.location < paragraph.contentEnd ? paragraph.contentEnd : paragraph.end
        return NSRange(location: selection.location, length: end - selection.location)
    }

    /// ⌃X: from the start of the paragraph to the caret (to the end of a selection).
    static func killToLineStart(_ text: NSString, selection: NSRange) -> NSRange {
        let list = paragraphs(text)
        let start = list[index(at: selection.location, in: list)].start
        return NSRange(location: start, length: NSMaxRange(selection) - start)
    }

    /// ⌃S: whole paragraphs, break included, from the one holding the selection start to the one holding its end.
    static func paragraphSelection(_ text: NSString, selection: NSRange) -> NSRange {
        let list = paragraphs(text)
        let first = index(at: selection.location, in: list)
        // A selection ending right after a break does not take in the next paragraph.
        let lastOffset = selection.length > 0 ? NSMaxRange(selection) - 1 : selection.location
        let last = max(first, index(at: lastOffset, in: list))
        return NSRange(location: list[first].start, length: list[last].end - list[first].start)
    }

    /// The two neighbouring paragraphs to swap for 段落を上へ／下へ, or nil at the top or bottom.
    static func swapPair(_ text: NSString, selection: NSRange, up: Bool) -> (upper: Paragraph, lower: Paragraph, movingIsUpper: Bool)? {
        let list = paragraphs(text)
        let current = index(at: selection.location, in: list)
        let neighbour = current + (up ? -1 : 1)
        guard list.indices.contains(neighbour) else { return nil }
        return (list[min(current, neighbour)], list[max(current, neighbour)], !up)
    }
}
