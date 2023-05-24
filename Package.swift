// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "Caching",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [.library(name: "Caching", targets: ["Caching"])],
    targets: [
        .target(name: "Caching"),
        .testTarget(
            name: "CachingTests",
            dependencies: ["Caching"]
        )
    ]
)
