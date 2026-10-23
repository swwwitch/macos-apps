import Foundation

/// One document-wide AppleScript job. Helpers are shared with the headless rule tests.
/// Only the two transition fields requested by this command are written.
enum AutoMagicMoveScript {
    static let body = """
    set slideList to get slides
    set slideCount to count slideList
    if slideCount < 2 then return "OK|0"
    set slideRecords to {}
    repeat with ordinal from 1 to slideCount
        set theSlide to item ordinal of slideList
        set isOmitted to skipped of theSlide
        set signatures to {}
        if isOmitted is false then set signatures to my signaturesForSlide(theSlide)
        set end of slideRecords to {slideOrdinal:ordinal as integer, slideIsSkipped:isOmitted, slideObjectSignatures:signatures}
    end repeat
    set matchingOrdinals to my matchingSlideOrdinals(slideRecords)
    set changedCount to 0
    repeat with ordinal in matchingOrdinals
        try
            set transition properties of (item (contents of ordinal) of slideList) to {transition effect:magic move, transition duration:0.7}
            set changedCount to changedCount + 1
        on error errorMessage number errorCode
            return "PARTIAL|" & changedCount & "|" & errorCode
        end try
    end repeat
    return "OK|" & changedCount
    """

    // Match consecutive *shown* slides, retaining their original ordinals. No slide is modified here.
    static let matchingHandlers = """
    on matchingSlideOrdinals(slideRecords)
        set matchingOrdinals to {}
        set previousShown to missing value
        repeat with recordRef in slideRecords
            set currentRecord to contents of recordRef
            if slideIsSkipped of currentRecord is false then
                if previousShown is not missing value then
                    if my hasCommonSignature(slideObjectSignatures of previousShown, slideObjectSignatures of currentRecord) then
                        set end of matchingOrdinals to slideOrdinal of previousShown
                    end if
                end if
                set previousShown to currentRecord
            end if
        end repeat
        return matchingOrdinals
    end matchingSlideOrdinals

    on hasCommonSignature(signaturesA, signaturesB)
        if signaturesA is {} or signaturesB is {} then return false
        considering case
            repeat with signatureRef in signaturesA
                if signaturesB contains (contents of signatureRef) then return true
            end repeat
        end considering
        return false
    end hasCommonSignature

    on signatureFromProperties(kindName, sourceName, itemText, itemWidth, itemHeight)
        if kindName is "image" or kindName is "movie" or kindName is "audio" then
            if sourceName is missing value then return missing value
            return kindName & "|file|" & (sourceName as text)
        else if kindName is "shape" or kindName is "text" then
            if itemText is not "" then return kindName & "|text|" & itemText
            if kindName is "shape" then
                return kindName & "|size|" & (round itemWidth) & "x" & (round itemHeight)
            end if
        end if
        return missing value
    end signatureFromProperties
    """

    static func source(bundleID: String) -> String {
        """
        tell application id "\(bundleID)"
            with timeout of 600 seconds
                if not (exists front document) then error number -1728
                tell front document
                    \(body)
                end tell
            end timeout
        end tell

        \(matchingHandlers)

        on signaturesForSlide(theSlide)
            set signatures to {}
            tell application id "\(bundleID)"
                repeat with itemRef in (get iWork items of theSlide)
                    set signatureValue to my signatureOfItem(contents of itemRef)
                    if signatureValue is not missing value then set end of signatures to signatureValue
                end repeat
            end tell
            return signatures
        end signaturesForSlide

        on signatureOfItem(theItem)
            tell application id "\(bundleID)"
                try
                    set itemClass to class of theItem
                    if itemClass is image then
                        return my signatureFromProperties("image", file name of theItem, "", 0, 0)
                    else if itemClass is movie then
                        return my signatureFromProperties("movie", file name of theItem, "", 0, 0)
                    else if itemClass is audio clip then
                        return my signatureFromProperties("audio", file name of theItem, "", 0, 0)
                    else if itemClass is shape or itemClass is text item then
                        set itemText to (object text of theItem) as text
                        if itemClass is shape then
                            return my signatureFromProperties("shape", "", itemText, width of theItem, height of theItem)
                        else
                            return my signatureFromProperties("text", "", itemText, 0, 0)
                        end if
                    end if
                on error errorMessage number errorCode
                    -- Unsupported items can be ignored; permissions and a disappearing document cannot.
                    if errorCode is -1743 or errorCode is -1728 then error errorMessage number errorCode
                end try
            end tell
            return missing value
        end signatureOfItem
        """
    }
}

/// Strict protocol: malformed output must never turn into a success with zero slides.
enum AutoMagicMoveResult: Equatable {
    case completed(Int)
    case partial(changed: Int, error: Int)

    init?(output: String) {
        let fields = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count >= 2, let changed = Int(fields[1]), changed >= 0 else { return nil }
        if fields[0] == "OK", fields.count == 2 { self = .completed(changed) }
        else if fields[0] == "PARTIAL", fields.count == 3, let error = Int(fields[2]), error != 0 {
            self = .partial(changed: changed, error: error)
        } else { return nil }
    }
}
