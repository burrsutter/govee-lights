// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoveeMenuBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GoveeMenuBar",
            path: "GoveeMenuBar"
        ),
        .executableTarget(
            name: "GoveeLoginLauncher",
            path: "GoveeLoginLauncher"
        ),
        .testTarget(
            name: "GoveeMenuBarTests",
            dependencies: ["GoveeMenuBar"],
            path: "Tests/GoveeMenuBarTests"
        )
    ]
)
