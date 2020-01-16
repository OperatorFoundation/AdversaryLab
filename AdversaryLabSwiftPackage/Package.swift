// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "AdversaryLabSwiftPackage",
    dependencies: [
         .package(url: "https://github.com/OperatorFoundation/Auburn.git", from: "0.6.0"),
         .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "1.0.5"),
         .package(url: "https://github.com/danielgindi/Charts", .upToNextMajor(from: "3.4.0"))
    ],
    targets: [
        .target(
            name: "AdversaryLabSwiftPackage",
            dependencies: ["Auburn", "Datable", "Charts"]),
        .testTarget(
            name: "AdversaryLabSwiftPackageTests",
            dependencies: ["AdversaryLabSwiftPackage"]),
    ]
)
