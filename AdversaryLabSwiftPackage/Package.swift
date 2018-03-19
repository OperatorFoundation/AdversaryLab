// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "AdversaryLabSwiftPackage",
    dependencies: [
         .package(url: "https://github.com/OperatorFoundation/Auburn.git", from: "0.1.8"),
    ],
    targets: [
        .target(
            name: "AdversaryLabSwiftPackage",
            dependencies: ["Auburn"]),
        .testTarget(
            name: "AdversaryLabSwiftPackageTests",
            dependencies: ["AdversaryLabSwiftPackage", "Auburn"]),
    ]
)
