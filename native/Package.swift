// swift-tools-version: 6.2
import PackageDescription

// Thread for macOS. Builds with the Command Line Tools alone (`swift build`);
// `scripts/build-app.sh` wraps the binary into Thread.app.
let package = Package(
    name: "Thread",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Thread",
            path: "Sources/Thread",
            swiftSettings: [
                // The app is UI code end to end, so everything is main-actor isolated unless marked otherwise.
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
