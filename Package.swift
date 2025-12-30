// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftChartSmoothing",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftChartSmoothing",
            targets: ["SwiftChartSmoothing"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftChartSmoothing",
            dependencies: []),
        .testTarget(
            name: "SwiftChartSmoothingTests",
            dependencies: ["SwiftChartSmoothing"]),
    ]
)
