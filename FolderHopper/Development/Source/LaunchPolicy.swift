enum LaunchPolicy {
    /// Only automatic login launch suppresses the main window.
    /// Explicit file delivery always opens the transfer window.
    static func shouldShowMainWindow(hiddenAtStartup: Bool, hasFiles: Bool) -> Bool {
        !hiddenAtStartup || hasFiles
    }
}
