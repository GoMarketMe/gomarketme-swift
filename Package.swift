// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoMarketMe",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "GoMarketMe",
            targets: ["GoMarketMe"]
        )
    ],
    targets: [
        .target(
            name: "GoMarketMe",
            dependencies: ["GoMarketMeAppleCoreKit"],
            path: "Sources/GoMarketMe"
        ),
        .binaryTarget(
            name: "GoMarketMeAppleCoreKit",
            path: "Frameworks/GoMarketMeAppleCoreKit.xcframework"
        ),
        .testTarget(
            name: "GoMarketMeTests",
            dependencies: ["GoMarketMe"],
            path: "Tests/GoMarketMeTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
