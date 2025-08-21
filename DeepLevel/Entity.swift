import SpriteKit

enum EntityKind {
    case player
    case monster
    case item
}

class Entity: SKSpriteNode {
    let id = UUID()
    let kind: EntityKind
    var gridX: Int
    var gridY: Int
    var blocksMovement: Bool = true
    var hp: Int = 1

    /// Extended initializer to allow a texture name
    init(kind: EntityKind, gridX: Int, gridY: Int, textureName: String? = nil, color: SKColor, size: CGSize) {
        self.kind = kind
        self.gridX = gridX
        self.gridY = gridY
        let texture = textureName != nil ? SKTexture(imageNamed: textureName!) : nil
        super.init(texture: texture, color: color, size: size)
        self.position = .zero
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.zPosition = 50
    }

    required init?(coder: NSCoder) { fatalError() }

    func moveTo(gridX: Int, gridY: Int, tileSize: CGFloat, animated: Bool = true) {
        self.gridX = gridX
        self.gridY = gridY
        let target = CGPoint(x: CGFloat(gridX)*tileSize + tileSize/2,
                             y: CGFloat(gridY)*tileSize + tileSize/2)
        if animated {
            run(SKAction.move(to: target, duration: 0.12))
        } else {
            position = target
        }
    }
}

final class Monster: Entity {
    var lastPath: [(Int,Int)] = []
    var pathIndex: Int = 0
    var pathNeedsUpdate: Bool = true

    /// Pass the texture name for Ursa
    init(gridX: Int, gridY: Int, tileSize: CGFloat, textureName: String? = "Ursa") {
        super.init(kind: .monster, gridX: gridX, gridY: gridY, textureName: textureName, color: .systemGreen, size: CGSize(width: tileSize*0.8, height: tileSize*0.8))
        hp = 3
    }
    required init?(coder: NSCoder) { fatalError() }
}
