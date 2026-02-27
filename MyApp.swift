
import SwiftUI
import UIKit
import AVFoundation

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Landscape Hosting Controller
// Overrides supportedInterfaceOrientations at the UIKit level — the ONLY
// approach that is 100% reliable on all iPadOS versions.
// ═══════════════════════════════════════════════════════════════════════════

private final class LandscapeHostingController: UIHostingController<AnyView> {
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
// Creates the window using LandscapeHostingController instead of the default
// UIHostingController that SwiftUI would normally use.
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
    // Belt-and-suspenders: also lock at the application level
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }

    // Tell the system to use our SceneDelegate (which sets up LandscapeHostingController)
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
// MARK: - Entry Point
// WindowGroup is declared here but the actual window is managed by SceneDelegate.
// SwiftUI detects that the scene delegate already created a window and defers.
// ═══════════════════════════════════════════════════════════════════════════

@main
struct MOVESApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView() // SceneDelegate owns the real window; this is a fallback
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - enforceLandscape() helper (kept for requestGeometryUpdate on iOS 16+)
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
