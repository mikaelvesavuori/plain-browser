// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Plain",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Plain", targets: ["Plain"]),
        .executable(name: "PlainBench", targets: ["PlainBench"]),
        .library(name: "PlainCore", targets: ["PlainCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.4")
    ],
    targets: [
        .executableTarget(
            name: "Plain",
            dependencies: ["PlainCore"]
        ),
        .executableTarget(
            name: "PlainBench",
            dependencies: ["PlainCore"]
        ),
        .target(
            name: "PlainCore",
            dependencies: ["SwiftSoup"]
        ),
        .testTarget(
            name: "PlainCoreTests",
            dependencies: ["PlainCore"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
