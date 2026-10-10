import Foundation
@main struct ContinuationSelectionTests {
    static func main() {
        let result = "・りんご🍎\n・みかん"
        precondition(ContinuationSelection.matches(text: result, location: 5, length: result.utf16.count, expected: result, start: 5))
        precondition(!ContinuationSelection.matches(text: result, location: 6, length: result.utf16.count, expected: result, start: 5))
        precondition(!ContinuationSelection.matches(text: "変更済み", location: 5, length: result.utf16.count, expected: result, start: 5))
        precondition(!ContinuationSelection.matches(text: nil, location: 5, length: 0, expected: result, start: 5))
        precondition(!ContinuationSelection.matches(text: result, location: 5, length: result.count, expected: result, start: 5))
        print("PASS selected replacement continuity and stale selection rejection")
    }
}
