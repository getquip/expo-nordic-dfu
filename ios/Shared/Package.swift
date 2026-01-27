// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExpoNordicDfuNativeTests",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing", from: "0.10.0")
    ],
    targets: [
        .target(
            name: "ExpoNordicDfuUtils",
            path: ".",
            exclude: ["Tests"],
            sources: [
                "ExpoNordicDfuUtils.swift",
                "ExpoNordicDfuCoordinator.swift"
            ]
        ),
        .testTarget(
            name: "ExpoNordicDfuUtilsTests",
            dependencies: [
                "ExpoNordicDfuUtils",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests"
        )
    ]
)
