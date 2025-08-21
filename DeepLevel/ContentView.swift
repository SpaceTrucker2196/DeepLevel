import SwiftUI
import SpriteKit

/// The main content view for the DeepLevel game interface.
///
/// Presents the SpriteKit game scene within a SwiftUI view hierarchy,
/// handling device orientation changes and providing debug information
/// during development. Acts as the bridge between SwiftUI and SpriteKit.
///
/// - Since: 1.0.0
struct ContentView: View {
    /// The game scene instance, created lazily to prevent recreation on view updates.
    @State private var scene = GameScene(size: UIScreen.main.bounds.size)

    /// The main view body containing the game scene.
    ///
    /// Wraps the SpriteKit scene in a geometry reader to handle dynamic
    /// sizing and provides debug options for development monitoring.
    ///
    /// - Returns: A view containing the configured game scene
    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: configuredScene(for: geo.size),
                       preferredFramesPerSecond: 60,
                       options: [.ignoresSiblingOrder],
                       debugOptions: [.showsFPS, .showsNodeCount])
                .ignoresSafeArea()
        }
    }

    /// Configures the scene for the current view size.
    ///
    /// Handles dynamic resizing when device orientation changes while
    /// maintaining proper scale mode for consistent game presentation.
    ///
    /// - Parameter size: The current view size to configure for
    /// - Returns: The configured scene ready for presentation
    /// - Complexity: O(1)
    private func configuredScene(for size: CGSize) -> SKScene {
        // Resize the scene if device rotates / size changes
        if scene.size != size {
            scene.size = size
        }
        scene.scaleMode = .resizeFill
        return scene
    }
}