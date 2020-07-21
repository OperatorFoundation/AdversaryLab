// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "AdversaryLabSwiftPackage",
    platforms: [.macOS(.v10_15)],
    dependencies: [
         .package(url: "https://github.com/OperatorFoundation/AdversaryLabClientSwift.git", from: "0.0.2"),
         .package(url: "https://github.com/OperatorFoundation/rethink-swift", from: "1.1.0"),
         .package(url: "https://github.com/weichsel/ZIPFoundation/", from: "0.9.10"),
         .package(url: "https://github.com/OperatorFoundation/Song.git", from: "0.0.19"),
         .package(url: "https://github.com/OperatorFoundation/Auburn.git", from: "0.6.2"),
         .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.2"),
         .package(url: "https://github.com/danielgindi/Charts", .upToNextMajor(from: "3.4.0"))
    ],
    targets: [
        .target(
            name: "AdversaryLabSwiftPackage",
            dependencies: ["Auburn", "Datable", "Charts", "Rethink", "ZIPFoundation", "Song", "Symphony", "RawPacket"]),
        .testTarget(
            name: "AdversaryLabSwiftPackageTests",
            dependencies: ["AdversaryLabSwiftPackage"]),
    ]
)
