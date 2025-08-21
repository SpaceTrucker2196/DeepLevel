import SpriteKit

/// Defines the categories of entities that can exist in the game world.
///
/// Used to classify different types of game objects for behavior and rendering.
///
/// - Since: 1.0.0
enum EntityKind {
    /// Represents the player character.
    case player
    
    /// Represents an enemy or hostile creature.
    case monster
    
    /// Represents an interactive object or collectible.
    case item
}

/// Base class for all game entities that exist on the dungeon grid.
///
/// Provides core functionality for positioning, movement, and basic properties
/// shared by all interactive game objects. Inherits from SpriteKit's sprite node
/// for rendering capabilities.
///
/// - Since: 1.0.0
class Entity: SKSpriteNode {
    /// Unique identifier for this entity instance.
    let id = UUID()
    
    /// The type of entity determining its behavior and appearance.
    let kind: EntityKind
    
    /// Current X coordinate on the dungeon grid.
    var gridX: Int
    
    /// Current Y coordinate on the dungeon grid.
    var gridY: Int
    
    /// Indicates whether this entity prevents other entities from occupying the same space.
    var blocksMovement: Bool = true
    
    /// Current health points of the entity.
    var hp: Int = 1
    
    /// Creates a new entity with specified properties.
    ///
    /// - Parameters:
    ///   - kind: The type of entity being created
    ///   - gridX: Initial X coordinate on the dungeon grid
    ///   - gridY: Initial Y coordinate on the dungeon grid
    ///   - color: The color used for rendering this entity
    ///   - size: The size of the sprite in points
    init(kind: EntityKind, gridX: Int, gridY: Int, color: SKColor, size: CGSize) {
        self.kind = kind
        self.gridX = gridX
        self.gridY = gridY
        super.init(texture: nil, color: color, size: size)
        self.position = .zero
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.zPosition = 50
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    /// Moves the entity to a new grid position.
    ///
    /// Updates both the logical grid coordinates and the visual sprite position.
    /// Optionally animates the movement for smooth visual transitions.
    ///
    /// - Parameters:
    ///   - gridX: Target X coordinate on the dungeon grid
    ///   - gridY: Target Y coordinate on the dungeon grid
    ///   - tileSize: Size of each tile in points for position calculation
    ///   - animated: Whether to animate the movement transition
    func moveTo(gridX: Int, gridY: Int, tileSize: CGFloat, animated: Bool = true) {
        self.gridX = gridX
        self.gridY = gridY
        let target = CGPoint(x: CGFloat(gridX)*tileSize + tileSize/2,
                             y: CGFloat(gridY)*tileSize + tileSize/2)
        if animated {
            let animationDuration: TimeInterval = 0.12
            run(SKAction.move(to: target, duration: animationDuration))
        } else {
            position = target
        }
    }
}

/// Represents an enemy entity with pathfinding capabilities.
///
/// Extends the base Entity class with AI behavior including path planning
/// and movement tracking for pursuing the player or patrolling areas.
///
/// - Since: 1.0.0
final class Monster: Entity {
    
    // MARK: - Constants
    private enum MonsterConstants {
        static let defaultHealth: Int = 3
        static let entitySizeRatio: CGFloat = 0.8
    }
    
    /// The calculated path as a sequence of grid coordinates.
    var lastPath: [(Int,Int)] = []
    
    /// Current position in the path sequence.
    var pathIndex: Int = 0
    
    /// Indicates whether the path needs to be recalculated.
    var pathNeedsUpdate: Bool = true
    
    /// Creates a new monster entity at the specified grid position.
    ///
    /// Initializes with default monster properties including health and appearance.
    ///
    /// - Parameters:
    ///   - gridX: Initial X coordinate on the dungeon grid
    ///   - gridY: Initial Y coordinate on the dungeon grid
    ///   - tileSize: Size of tiles for sprite sizing
    init(gridX: Int, gridY: Int, tileSize: CGFloat) {
        super.init(kind: .monster, 
                  gridX: gridX, 
                  gridY: gridY, 
                  color: .systemGreen, 
                  size: CGSize(width: tileSize*MonsterConstants.entitySizeRatio, 
                              height: tileSize*MonsterConstants.entitySizeRatio))
        hp = MonsterConstants.defaultHealth
    }
    required init?(coder: NSCoder) { fatalError() }
}