// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DutiGUI",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "DutiGUI", targets: ["DutiGUI"])],
    targets: [
        .executableTarget(name: "DutiGUI"),
        .testTarget(name: "DutiGUITests", dependencies: ["DutiGUI"])
    ]
)
