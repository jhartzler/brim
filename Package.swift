// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Brim",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "BrimLib",
            path: "Sources/Brim",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Brim",
            dependencies: ["BrimLib"],
            path: "Sources/BrimApp"
        ),
        .testTarget(
            name: "BrimTests",
            dependencies: ["BrimLib"],
            path: "Tests/BrimTests"
        )
    ]
)
