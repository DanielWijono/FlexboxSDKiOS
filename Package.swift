// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flexbox",
    platforms: [
        .iOS(.v15),
        // macOS floor exists only so `swift test` can run the headless suite on
        // a Mac. macOS is NOT a shipping target (spec §"Batasan tetap").
        .macOS(.v13),
    ],
    products: [
        .library(name: "FlexboxCore", targets: ["FlexboxCore"]),
        .library(name: "FlexboxKit", targets: ["FlexboxKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/facebook/yoga.git", "3.0.0" ..< "4.0.0"),
    ],
    targets: [
        // Internal C shim: re-exports Yoga's C ABI under a single collision-resistant
        // module name. Only Engine/YogaInterop.swift imports it.
        .target(
            name: "CYoga",
            dependencies: [
                .product(name: "yoga", package: "yoga"),
            ],
            path: "Sources/CYoga",
            publicHeadersPath: "include"
        ),
        .target(
            name: "FlexboxCore",
            dependencies: [
                "CYoga",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "FlexboxKit",
            dependencies: [
                "FlexboxCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "FlexboxCoreTestSupport",
            dependencies: [
                "FlexboxCore",
            ],
            path: "Tests/FlexboxCoreTestSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "FlexboxCoreTests",
            dependencies: [
                "FlexboxCore",
                "FlexboxCoreTestSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
