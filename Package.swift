// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BMPImage",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "BMPImage",
            targets: ["BMPImage"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BMPImage",
            dependencies: [],
            path: "BMPImage",
            publicHeadersPath: ""),
    ]
)
