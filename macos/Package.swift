// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodexAuth",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CodexAuthApp",
            path: "Sources/CodexAuthApp"
        )
    ]
)
