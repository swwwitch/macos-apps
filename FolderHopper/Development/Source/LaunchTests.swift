@main struct LaunchTests {
    static func main() {
        precondition(LaunchPolicy.shouldShowMainWindow(hiddenAtStartup: false, hasFiles: false))
        precondition(!LaunchPolicy.shouldShowMainWindow(hiddenAtStartup: true, hasFiles: false))
        precondition(LaunchPolicy.shouldShowMainWindow(hiddenAtStartup: true, hasFiles: true))
        precondition(LaunchPolicy.shouldShowMainWindow(hiddenAtStartup: false, hasFiles: true))
        print("PASS: shared startup preference and explicit file delivery")
    }
}
