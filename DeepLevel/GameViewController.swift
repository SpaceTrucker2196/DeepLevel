import UIKit
import SpriteKit
import GameplayKit

/// View controller for presenting the game using UIKit and SpriteKit.
///
/// Manages the SpriteKit view presentation in a UIKit context, handling
/// scene setup, view lifecycle, and debug display options. Provides an
/// alternative presentation method to the SwiftUI ContentView.
///
/// - Since: 1.0.0
class GameViewController: UIViewController {

    /// Creates the root view as a SpriteKit view.
    ///
    /// Overrides the default view creation to ensure the root view
    /// is properly configured as an SKView for game presentation.
    override func loadView() {
        self.view = SKView()
    }

    /// Sets up the game scene and view configuration after view loading.
    ///
    /// Initializes the game scene with appropriate size and scale mode,
    /// then configures debug options for development monitoring.
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else {
            print("Root view is not SKView!")
            return
        }
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    /// Handles view layout changes and updates scene size accordingly.
    ///
    /// Ensures the game scene stays properly sized when the view bounds
    /// change due to device rotation or other layout updates.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let skView = view as? SKView,
           let scene = skView.scene {
            scene.size = skView.bounds.size
        }
    }

    /// Indicates whether the status bar should be hidden.
    ///
    /// - Returns: Always `true` for immersive game experience
    override var prefersStatusBarHidden: Bool { true }
}
