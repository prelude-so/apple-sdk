// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Prelude",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "Prelude",
            targets: ["Prelude", "PreludeCore"]
        ),
    ],
    targets: [
        .target(
            name: "Prelude",
            dependencies: ["PreludeCore"]
        ),
        .binaryTarget(
            name: "PreludeCore",
            url: "https://prelude-public.s3.amazonaws.com/sdk/releases/apple/core/0.3.2/PreludeCore-0.3.2.xcframework.zip",
            checksum: "5007a9635b8238c0ac92fd637f78ee45f88701e637442c83664c30202c55f45e"
        ),
    ]
)
