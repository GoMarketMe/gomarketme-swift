// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "GoMarketMe",
    platforms: [
        .iOS(.v15)  // This ensures all dependencies are built with iOS in mind
    ],
    products: [
        .library(
            name: "GoMarketMe",
            targets: ["GoMarketMe"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "GoMarketMe",
            dependencies: [
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "GoMarketMeTests",
            dependencies: ["GoMarketMe"],
            path: "Tests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
