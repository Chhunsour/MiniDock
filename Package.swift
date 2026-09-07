// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MiniDock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MiniDock",
            targets: ["MiniDock"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MiniDock",
            dependencies: [],
            path: "Sources/MiniDock"
        ),
        .testTarget(
            name: "MiniDockTests",
            dependencies: ["MiniDock"],
            path: "Tests/MiniDockTests"
        )
    ]
)
