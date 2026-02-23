import SwiftUI
import SpriteKit

/// The main content view for the DeepLevel game interface.
///
/// Presents the SpriteKit game scene within a NavigationSplitView,
/// providing a sidebar with scoring and trading controls on iPad/Mac
/// and a 4-way directional controller overlay for movement.
///
/// - Since: 1.0.0
struct ContentView: View {
    /// The game economy shared between SwiftUI and SpriteKit.
    @StateObject private var economy = GameEconomy()

    /// The game scene instance, created lazily to prevent recreation on view updates.
    #if os(iOS)
    @State private var scene = GameScene(size: UIScreen.main.bounds.size)
    #else
    @State private var scene = GameScene(size: CGSize(width: 800, height: 600))
    #endif

    /// Controls sidebar visibility on compact size classes.
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            GameSidebar(
                economy: economy,
                onNewGame: {
                    scene.regenerate(seed: nil)
                },
                onCycleAlgorithm: {
                    scene.cycleAlgorithm()
                }
            )
        } detail: {
            gameView
        }
    }

    /// The game scene view with directional controller overlay.
    private var gameView: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: configuredScene(for: geo.size),
                           preferredFramesPerSecond: 60,
                           options: [.ignoresSiblingOrder],
                           debugOptions: [.showsFPS, .showsNodeCount])
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        DirectionalController(
                            onDirection: { dx, dy in
                                scene.movePlayer(dx: dx, dy: dy)
                            },
                            onStop: {
                                scene.stopPlayer()
                            }
                        )
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            scene.economy = economy
        }
    }

    /// Configures the scene for the current view size.
    private func configuredScene(for size: CGSize) -> SKScene {
        if scene.size != size {
            scene.size = size
        }
        scene.scaleMode = .resizeFill
        return scene
    }
}