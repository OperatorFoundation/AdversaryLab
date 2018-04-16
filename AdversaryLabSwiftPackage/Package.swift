// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "AdversaryLabSwiftPackage",
    dependencies: [
         .package(url: "https://github.com/OperatorFoundation/Auburn.git", from: "0.1.16"),
         .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "0.0.10"),
    ],
    targets: [
        .target(
            name: "AdversaryLabSwiftPackage",
            dependencies: ["Auburn", "Datable"]),
        .testTarget(
            name: "AdversaryLabSwiftPackageTests",
            dependencies: ["AdversaryLabSwiftPackage", "Auburn"]),
    ]
)
