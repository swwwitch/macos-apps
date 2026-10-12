// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HotkeyHound",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HotkeyHound", targets: ["HotkeyHound"])
    ],
    targets: [
        .executableTarget(
            name: "HotkeyHound",
            path: "Sources/HotkeyHound"
        )
    ]
)
