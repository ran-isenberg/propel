// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Propel",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Propel",
            path: "Sources/Propel",
            resources: [
                .copy("Resources/AppIcon.icns")
            ]
        ),
        .testTarget(
            name: "PropelTests",
            dependencies: ["Propel"],
            path: "Tests/PropelTests"
        )
    ]
)
