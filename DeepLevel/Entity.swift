import SpriteKit

/// Enum representing different entity types in the game, with raw values for texture names.
enum EntityKind: String {
    case player = "Foxy"
    case monster = "Stedenko"
    case charmed = "CoolBear"
    case item // Add more kinds as needed, with rawValue as the asset name if you use them
}

/// Base class for all grid-based entities (player, monster, item) in the dungeon.
class Entity: SKSpriteNode {
    let id = UUID()
    let kind: EntityKind
    var gridX: Int
    var gridY: Int
    var blocksMovement: Bool = true
    var hp: Int = 1
    var currentlySeen: Bool = false

    /// Create an entity of a specific kind at a grid location, with color and size.
    /// Loads texture based on EntityKind's rawValue (asset name).
    /// Provides error handling if texture is missing.
    init(kind: EntityKind, gridX: Int, gridY: Int, color: SKColor, size: CGSize) {
        self.kind = kind
        self.gridX = gridX
        self.gridY = gridY
        let texture = SKTexture(imageNamed: kind.rawValue)
        // Error handling: SpriteKit returns a 1x1 transparent texture if asset is missing.
        if texture.size() == CGSize(width: 1, height: 1) {
            print("⚠️ [Entity] Texture '\(kind.rawValue)' not found in asset catalog. Using fallback color.")
            super.init(texture: nil, color: color, size: size)
        } else {
            super.init(texture: texture, color: color, size: size)
        }
        self.position = .zero
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.zPosition = 50
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Move to a grid position, animating if desired.
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

/// Monster entity, always uses the "Ursa" texture.
final class Monster: Entity {
    var lastPath: [(Int,Int)] = []
    var pathIndex: Int = 0
    var pathNeedsUpdate: Bool = true
    var roamTarget: (Int, Int)? = nil
    var lastPlayerPosition: (Int, Int)? = nil

    init(gridX: Int, gridY: Int, tileSize: CGFloat) {
        super.init(kind: .monster,
                   gridX: gridX,
                   gridY: gridY,
                   color: .systemGreen,
                   size: CGSize(width: tileSize*0.8, height: tileSize*0.8))
        hp = 3
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// Charmed entity that moves randomly until charmed, then follows the player.
final class Charmed: Entity {
    var isCharmed: Bool = false
    var roamTarget: (Int, Int)? = nil
    var lastHealTime: TimeInterval = 0
    
    init(gridX: Int, gridY: Int, tileSize: CGFloat) {
        super.init(kind: .charmed,
                   gridX: gridX,
                   gridY: gridY,
                   color: .systemPurple,
                   size: CGSize(width: tileSize*0.8, height: tileSize*0.8))
        hp = 1
        blocksMovement = false // Charmed entities don't block movement
    }
    required init?(coder: NSCoder) { fatalError() }
}
