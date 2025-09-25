// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VisionDaemon",
    platforms: [ .macOS(.v14) ],
    products: [
        .executable(name: "VisionDaemon", targets: ["VisionDaemon"]) 
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0")
    ],
    targets: [
        .executableTarget(
            name: "VisionDaemon",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Sources/VisionDaemon",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
