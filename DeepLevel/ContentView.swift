import SwiftUI
import SpriteKit

struct ContentView: View {
    // Create the scene lazily so it isn’t recreated on every body recompute
    @State private var scene = GameScene(size: UIScreen.main.bounds.size)

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: configuredScene(for: geo.size),
                       preferredFramesPerSecond: 60,
                       options: [.ignoresSiblingOrder],
                       debugOptions: [.showsFPS, .showsNodeCount])
                .ignoresSafeArea()
        }
    }

    private func configuredScene(for size: CGSize) -> SKScene {
        // Resize the scene if device rotates / size changes
        if scene.size != size {
            scene.size = size
        }
        scene.scaleMode = .resizeFill
        return scene
    }
}

