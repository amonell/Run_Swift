// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VirtualRunningCompanion",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "VirtualRunningCompanion",
            targets: ["VirtualRunningCompanion"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VirtualRunningCompanion",
            dependencies: [],
            path: "Sources/VirtualRunningCompanion"
        ),
        .testTarget(
            name: "VirtualRunningCompanionTests",
            dependencies: ["VirtualRunningCompanion"],
            path: "Tests/VirtualRunningCompanionTests"
        ),
    ]
)