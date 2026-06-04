// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UpWhisper",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "UpWhisper",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/UpWhisper",
            exclude: ["Resources/Info.plist"],
            resources: [.copy("Resources/MenuBarMic.png")]
        )
    ]
)
