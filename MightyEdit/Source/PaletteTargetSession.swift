import Foundation

struct PaletteTargetSession {
    let ownPID: Int32
    private(set) var lastExternalPID: Int32?
    private(set) var targetPID: Int32?

    mutating func departed(_ pid: Int32, frontPID: Int32?) {
        guard pid != ownPID, frontPID == ownPID else { return }
        lastExternalPID = pid
    }
    mutating func activated(_ pid: Int32) -> Bool {
        guard pid != ownPID else { return false }
        lastExternalPID = pid
        return targetPID.map { $0 != pid } ?? false
    }
    mutating func bind(frontPID: Int32?) {
        if let pid = frontPID, pid != ownPID { lastExternalPID = pid }
        targetPID = lastExternalPID
    }
}
