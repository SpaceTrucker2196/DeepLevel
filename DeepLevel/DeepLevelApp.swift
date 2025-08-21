import SwiftUI

/// The main entry point for the DeepLevel application.
///
/// Defines the app structure and initial scene configuration using SwiftUI's
/// declarative app lifecycle. Sets up the main window with content that
/// ignores safe areas for full-screen game presentation.
///
/// - Since: 1.0.0
@main
struct DeepLevelApp: App {
    /// The app's main scene configuration.
    ///
    /// Creates a window group containing the main content view with
    /// safe area constraints disabled for immersive game experience.
    ///
    /// - Returns: A scene containing the app's user interface
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea() // So the scene fills the screen
        }
    }
}
