// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ContextPacket",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ContextPacket", targets: ["ContextPacket"])
    ],
    targets: [
        .target(name: "ContextPacket"),
        .testTarget(name: "ContextPacketTests", dependencies: ["ContextPacket"])
    ]
)
