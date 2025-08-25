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
    
    /// Scale factor for the entity (1.0 = normal size, 2.0 = double size)
    var scale: CGFloat = 1.0
    
    /// List of tile types that block movement for this entity
    var blockingTiles: Set<TileKind> = []

    /// Create an entity of a specific kind at a grid location, with color and size.
    /// Loads texture based on EntityKind's rawValue (asset name).
    /// Provides error handling if texture is missing.
    init(kind: EntityKind, gridX: Int, gridY: Int, color: SKColor, size: CGSize, scale: CGFloat = 1.0) {
        self.kind = kind
        self.gridX = gridX
        self.gridY = gridY
        self.scale = scale
        
        // Set default blocking tiles based on entity type
        switch kind {
        case .player:
            blockingTiles = [.wall, .doorClosed, .doorSecret, .driveway]
        case .monster:
            blockingTiles = [.wall, .doorClosed, .doorSecret, .driveway]
        case .charmed:
            blockingTiles = [.wall, .doorClosed, .doorSecret, .driveway]
        case .item:
            blockingTiles = []
        }
        
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
        
        // Apply scaling to the visual representation
        self.setScale(scale)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Move to a grid position, animating if desired.
    func moveTo(gridX: Int, gridY: Int, tileSize: CGFloat, animated: Bool = true) {
        self.gridX = gridX
        self.gridY = gridY
        let target = CGPoint(x: CGFloat(gridX)*tileSize + tileSize/2,
                             y: CGFloat(gridY)*tileSize + tileSize/2)
        if animated {
            run(SKAction.move(to: target, duration: 0.3)) // Increased duration for smoother movement
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
    var lastPlayerSightingTime: TimeInterval = 0  // Track when player was last seen for timeout logic

    init(gridX: Int, gridY: Int, tileSize: CGFloat, scale: CGFloat = 1.0) {
        super.init(kind: .monster,
                   gridX: gridX,
                   gridY: gridY,
                   color: .systemGreen,
                   size: CGSize(width: tileSize*0.8, height: tileSize*0.8),
                   scale: scale)
        hp = 3
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// Charmed entity that moves randomly until charmed, then follows the player.
final class Charmed: Entity {
    var isCharmed: Bool = false
    var roamTarget: (Int, Int)? = nil
    var lastHealTime: TimeInterval = 0
    
    init(gridX: Int, gridY: Int, tileSize: CGFloat, scale: CGFloat = 1.0) {
        super.init(kind: .charmed,
                   gridX: gridX,
                   gridY: gridY,
                   color: .systemPurple,
                   size: CGSize(width: tileSize*0.8, height: tileSize*0.8),
                   scale: scale)
        hp = 1
        blocksMovement = false // Charmed entities don't block movement
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// Player entity controlled by user input.
final class Player: Entity {
    var inventory: [StoredItem] = []
    private var lastHealTime: TimeInterval = 0
    var soilTestResults: [SoilTestResult] = []
    
    init(gridX: Int, gridY: Int, tileSize: CGFloat, scale: CGFloat = 1.0) {
        super.init(kind: .player,
                   gridX: gridX,
                   gridY: gridY,
                   color: .systemBlue,
                   size: CGSize(width: tileSize*0.8, height: tileSize*0.8),
                   scale: scale)
        hp = 10
        
        // Initialize with 3 random items
        initializeStartingInventory(tileSize: tileSize)
    }
    
    /// Heal the player and add visual effects
    func heal(amount: Int = 1) {
        hp = min(hp + amount, 10) // Cap at max HP of 10
        lastHealTime = CACurrentMediaTime()
    }
    
    /// Check if player was recently healed (for effect timing)
    func wasRecentlyHealed() -> Bool {
        return CACurrentMediaTime() - lastHealTime < 10.0 // 10 seconds
    }
    
    /// Check if player has any soil testing equipment
    func hasSoilTestingEquipment() -> Bool {
        return inventory.contains { item in
            ["pH Test Kit", "Moisture Meter", "Soil Thermometer", "Soil Probe", "NPK Test Kit"].contains(item.title)
        }
    }
    
    /// Get available soil testing equipment
    func availableSoilTestingEquipment() -> [StoredItem] {
        return inventory.filter { item in
            Player.soilTestingEquipmentNames.contains(item.title)
        }
    }
    
    /// Get available soil testing equipment
    func availableSoilTestingEquipment() -> [StoredItem] {
        return inventory.filter { item in
            Player.soilTestingEquipmentNames.contains(item.title)
        }
    }
    
    /// Perform a soil test using the first available equipment
    func performSoilTest(at location: (Int, Int), soilProperties: SoilProperties) -> SoilTestResult? {
        guard let equipment = availableSoilTestingEquipment().first else {
            return nil
        }
        
        let result = SoilTestResult(location: location, equipment: equipment.title, soilProperties: soilProperties)
        soilTestResults.append(result)
        return result
    }
    
    /// Perform a soil test using specific equipment
    func performSoilTest(at location: (Int, Int), soilProperties: SoilProperties, using equipmentName: String) -> SoilTestResult? {
        guard inventory.contains(where: { $0.title == equipmentName }) else {
            return nil
        }
        
        let result = SoilTestResult(location: location, equipment: equipmentName, soilProperties: soilProperties)
        soilTestResults.append(result)
        return result
    }
    
    private func initializeStartingInventory(tileSize: CGFloat) {
        // Start with 2 random items and 1 soil testing equipment
        let randomItems = ItemDatabase.randomItems(count: 2)
        let soilTestingItems = ItemDatabase.randomItems(from: .soilTesting, count: 1)
        
        let allStartingItems = randomItems + soilTestingItems
        
        for itemDef in allStartingItems {
            let item = StoredItem(name: itemDef.name,
                                  description: itemDef.description,
                                  gridX: gridX, // Items start at player position conceptually
                                  gridY: gridY,
                                  tileSize: tileSize)
            inventory.append(item)
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

/// Gameplay item entity renamed to StoredItem to avoid clash with Core Data Item.
final class StoredItem: Entity { // formerly: Item
    let title: String
    let descript: String
    
    init(name: String, description: String, gridX: Int, gridY: Int, tileSize: CGFloat) {
        self.title = name
        self.descript = description
        super.init(kind: .item,
                   gridX: gridX,
                   gridY: gridY,
                   color: .systemYellow,
                   size: CGSize(width: tileSize*0.5, height: tileSize*0.5))
        hp = 1
        blocksMovement = false
    }
    required init?(coder: NSCoder) { fatalError() }
}
