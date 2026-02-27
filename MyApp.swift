
import SwiftUI
import AVFoundation
import UIKit

// ── Landscape enforcer ────────────────────────────────────────────────────
// Called from every view's .onAppear to guarantee landscape on iPadOS.
// Uses the modern requestGeometryUpdate API (iOS 16+) with a UIDevice
// fallback for older systems.
func enforceLandscape() {
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene }).first else { return }
    if #available(iOS 16.0, *) {
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        scene.windows.first?.rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
    } else {
        UIDevice.current.setValue(
            UIInterfaceOrientation.landscapeRight.rawValue,
            forKey: "orientation"
        )
        UINavigationController.attemptRotationToDeviceOrientation()
    }
}

// ── App Delegate ──────────────────────────────────────────────────────────
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            enforceLandscape()
        }
        return true
    }
}

// ── Entry point ───────────────────────────────────────────────────────────
@main
struct MOVESApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { enforceLandscape() }
        }
    }
}
