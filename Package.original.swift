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
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.0.0")
    ],
    targets: [
        .target(
            name: "VirtualRunningCompanion",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "VirtualRunningCompanion"
        ),
        .testTarget(
            name: "VirtualRunningCompanionTests",
            dependencies: ["VirtualRunningCompanion"],
            path: "Tests/VirtualRunningCompanionTests"
        ),
    ]
)