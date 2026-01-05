// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LightweightChart",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "LightweightChart",
            targets: ["LightweightChart"]
        )
    ],
    targets: [
        .target(
            name: "LightweightChart",
            resources: [
                .copy("Resources/chart.html"),
                .copy("Resources/chart.css"),
                .copy("Resources/chart.js"),
                .copy("Resources/lightweight-charts.standalone.production.js"),
            ]
        ),
        .testTarget(
            name: "LightweightChartTests",
            dependencies: ["LightweightChart"]
        ),
    ]
)
