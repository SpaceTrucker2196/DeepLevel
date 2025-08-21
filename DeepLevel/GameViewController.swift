import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func loadView() {
        self.view = SKView()
    }

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let skView = view as? SKView,
           let scene = skView.scene {
            scene.size = skView.bounds.size
        }
    }

    override var prefersStatusBarHidden: Bool { true }
}
