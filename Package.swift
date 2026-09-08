// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kinieta",
    platforms: [
        .iOS(.v17)
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
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/KinietaTests",
            exclude: ["__Snapshots__"]
        )
    ],
    swiftLanguageModes: [.v6]
)
