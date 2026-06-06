// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WibeOS",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WibeOS",
            path: "Sources/WibeOS",
            resources: [.copy("Resources/shell.html")]
        )
    ]
)
