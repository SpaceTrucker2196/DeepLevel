import SpriteKit

final class HUD: SKNode {
    private let seedLabel = SKLabelNode(fontNamed: "Menlo")
    private let hpLabel = SKLabelNode(fontNamed: "Menlo")
    private let algoLabel = SKLabelNode(fontNamed: "Menlo")
    
    override init() {
        super.init()
        [seedLabel, hpLabel, algoLabel].forEach {
            $0.fontSize = 12
            $0.horizontalAlignmentMode = .left
            $0.verticalAlignmentMode = .top
            addChild($0)
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func update(seed: UInt64?, hp: Int, algo: GenerationAlgorithm, size: CGSize, safeInset: CGFloat = 8) {
        seedLabel.text = "Seed: \(seed.map(String.init) ?? "random")"
        hpLabel.text = "HP: \(hp)"
        algoLabel.text = "Algo: \(algoName(algo))"
        
        // Layout stack at top-left of the camera’s coordinate space
        let labels = [seedLabel, hpLabel, algoLabel]
        for (i, lbl) in labels.enumerated() {
            lbl.position = CGPoint(
                x: -size.width/2 + safeInset,
                y: size.height/2 - safeInset - CGFloat(i) * (lbl.fontSize + 4)
            )
        }
    }
    
    private func algoName(_ a: GenerationAlgorithm) -> String {
        switch a {
        case .roomsCorridors: return "Rooms"
        case .bsp: return "BSP"
        case .cellular: return "Cellular"
        }
    }
}