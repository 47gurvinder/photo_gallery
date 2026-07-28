// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "photo_gallery_gdx_plus",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(
            name: "photo-gallery-gdx-plus",
            targets: ["photo_gallery_gdx_plus"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "photo_gallery_gdx_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
