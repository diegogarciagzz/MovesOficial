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
                .landscapeRight,
                .landscapeLeft
            ],
            capabilities: [
                .outgoingNetworkConnections(),
                .microphone(purposeString: "MOVES needs microphone for voice chess commands"),
                .speechRecognition(purposeString: "MOVES uses voice to enter chess moves like \"e4\""),
                .incomingNetworkConnections()
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ],
    swiftLanguageVersions: [.version("5")]
)
