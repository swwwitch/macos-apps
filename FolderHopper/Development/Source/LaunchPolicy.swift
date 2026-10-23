enum LaunchPolicy {
    /// The shared startup preference applies to manual and login launches alike.
    /// Explicit file delivery always opens the transfer window.
    static func shouldShowMainWindow(hiddenAtStartup: Bool, hasFiles: Bool) -> Bool {
        !hiddenAtStartup || hasFiles
    }
}
