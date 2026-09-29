// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kinieta",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Kinieta", targets: ["Kinieta"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "Kinieta",
            path: "Sources/Kinieta",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "KinietaTests",
            dependencies: [
                "Kinieta",
                // Snapshot references are iOS only, and SnapshotTesting 1.19
                // does not compile for Mac Catalyst with Swift 6.3.
                .product(
                    name: "SnapshotTesting",
                    package: "swift-snapshot-testing",
                    condition: .when(platforms: [.iOS])
                ),
            ],
            path: "Tests/KinietaTests",
            exclude: ["__Snapshots__"]
        )
    ],
    swiftLanguageModes: [.v6]
)
