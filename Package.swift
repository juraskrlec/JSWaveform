// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JSWaveform",
    platforms: [
        .iOS(.v17), .visionOS(.v1)
    ],
    products: [
        .library(
            name: "JSWaveform",
            targets: ["JSWaveform"]),
    ],
    targets: [
        .target(
            name: "JSWaveform")
    ]
)
