// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "GoMarketMe",
    platforms: [
        .iOS(.v13)  // This ensures all dependencies are built with iOS in mind
    ],
    products: [
        .library(
            name: "GoMarketMe",
            targets: ["GoMarketMe"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.4.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.13.3"),
        .package(url: "https://github.com/ashleymills/Reachability.swift.git", from: "5.0.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.0"),
        .package(url: "https://github.com/devicekit/DeviceKit.git", .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
        .target(
            name: "GoMarketMe",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "PromiseKit",
                .product(name: "Reachability", package: "Reachability.swift"),
                "CryptoSwift",
                .product(name: "DeviceKit", package: "DeviceKit")
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
