
import SwiftUI
import UIKit
import AVFoundation

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Landscape Hosting Controller
//
// Subclasses UIHostingController to override orientation at the UIKit level.
// This is the ONLY approach that reliably blocks portrait on all iPadOS versions.
// ═══════════════════════════════════════════════════════════════════════════

final class LandscapeHostingController: UIHostingController<AnyView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
    override var shouldAutorotate: Bool {
        return false
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Scene Delegate
//
// Creates UIWindow with LandscapeHostingController as root view controller.
// Called because AppDelegate.configurationForConnecting returns this class
// AND Info.plist has UIApplicationSceneManifest (required to activate scene lifecycle).
// ═══════════════════════════════════════════════════════════════════════════

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let win = UIWindow(windowScene: windowScene)
        win.rootViewController = LandscapeHostingController(rootView: AnyView(ContentView()))
        self.window = win
        win.makeKeyAndVisible()
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - App Delegate
// ═══════════════════════════════════════════════════════════════════════════

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - App Entry Point
//
// @main is kept here. The WindowGroup content is managed by SceneDelegate —
// SwiftUI detects the scene delegate created a window and defers to it.
// ═══════════════════════════════════════════════════════════════════════════

@main
struct MOVESApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - enforceLandscape() — extra safety layer on iOS 16+
// ═══════════════════════════════════════════════════════════════════════════

func enforceLandscape() {
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene }).first else { return }
    if #available(iOS 16.0, *) {
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        scene.windows.first?.rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
