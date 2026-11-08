// swift-tools-version:6.0
// Temporary validation manifest only; not the app's dependency manifest.
import Foundation
import PackageDescription
let logboard: Package.Dependency = if let path = ProcessInfo.processInfo.environment["STREAM14_LOGBOARD_PATH"] {
    .package(path: path)
} else {
    .package(url: "https://github.com/shogo4405/Logboard.git", exact: "2.6.0")
}
let package = Package(
    name: "F6PatchValidation",
    platforms: [.macOS(.v15)],
    products: [.library(name: "RTMPHaishinKit", targets: ["RTMPHaishinKit"])],
    dependencies: [logboard],
    targets: [
        .target(name: "HaishinKit", dependencies: ["Logboard"], path: "HaishinKit/Sources",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .target(name: "RTMPHaishinKit", dependencies: ["HaishinKit"], path: "RTMPHaishinKit/Sources",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .testTarget(name: "RTMPHaishinKitTests", dependencies: ["RTMPHaishinKit"], path: "RTMPHaishinKit/Tests",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")])
    ], swiftLanguageModes: [.v6])
