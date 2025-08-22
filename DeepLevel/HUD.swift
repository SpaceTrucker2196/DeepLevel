import SpriteKit

/// Heads-up display (HUD) node for showing game information.
///
/// Provides an overlay interface displaying current game state including
/// generation seed, player health, and active dungeon algorithm. Positions
/// labels in the top-left corner of the camera's view space.
///
/// - Since: 1.0.0
final class HUD: SKNode {
    /// Label displaying the current generation seed.
    private let seedLabel = SKLabelNode(fontNamed: "Menlo")
    
    /// Label displaying the player's current health points.
    private let hpLabel = SKLabelNode(fontNamed: "Menlo")
    
    /// Label displaying the active dungeon generation algorithm.
    private let algoLabel = SKLabelNode(fontNamed: "Menlo")
    
    /// Label displaying the number of charmed entities.
    private let charmedLabel = SKLabelNode(fontNamed: "Menlo")
    
    /// Initializes the HUD with configured label nodes.
    ///
    /// Sets up all labels with consistent font, size, and alignment
    /// properties for uniform appearance in the game interface.
    override init() {
        super.init()
        [seedLabel, hpLabel, algoLabel, charmedLabel].forEach {
            $0.fontSize = 12
            $0.horizontalAlignmentMode = .left
            $0.verticalAlignmentMode = .top
            addChild($0)
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    /// Updates the HUD display with current game information.
    ///
    /// Refreshes all label text and positions based on current game state
    /// and camera view size. Arranges labels in a vertical stack at the
    /// top-left corner with appropriate safe area spacing.
    ///
    /// - Parameters:
    ///   - seed: Current generation seed, or nil for random generation
    ///   - hp: Player's current health points
    ///   - algo: Active dungeon generation algorithm
    ///   - charmedScore: Number of entities charmed by the player
    ///   - size: Camera view size for positioning calculations
    ///   - safeInset: Margin from screen edges for safe positioning
    /// - Complexity: O(1)
    func update(seed: UInt64?, hp: Int, algo: GenerationAlgorithm, charmedScore: Int, size: CGSize, safeInset: CGFloat = 8) {
        seedLabel.text = "Seed: \(seed.map(String.init) ?? "random")"
        hpLabel.text = "HP: \(hp)"
        algoLabel.text = "Algo: \(algoName(algo))"
        charmedLabel.text = "Charmed: \(charmedScore)"
        
        // Layout stack at top-left of the camera's coordinate space
        let labels = [seedLabel, hpLabel, algoLabel, charmedLabel]
        for (i, lbl) in labels.enumerated() {
            lbl.position = CGPoint(
                x: -size.width/2 + safeInset,
                y: size.height/2 - safeInset - CGFloat(i) * (lbl.fontSize + 4)
            )
        }
    }
    
    /// Converts generation algorithm enum to display string.
    ///
    /// Provides user-friendly names for the different dungeon generation
    /// algorithms for display in the HUD interface.
    ///
    /// - Parameter a: The generation algorithm to convert
    /// - Returns: Human-readable algorithm name
    /// - Complexity: O(1)
    private func algoName(_ a: GenerationAlgorithm) -> String {
        switch a {
        case .roomsCorridors: return "Rooms"
        case .bsp: return "BSP"
        case .cellular: return "Cellular"
        case .cityMap: return "CityMap"
        }
    }
}
