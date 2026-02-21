// swift-tools-version: 5.8

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MovesDiego",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "MovesDiego",
            targets: ["AppModule"],
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .chess),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
