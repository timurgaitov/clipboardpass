// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "clipboardpass",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "clipboardpass",
            path: "Sources/clipboardpass"
        )
    ],
    swiftLanguageVersions: [.v5]
)
