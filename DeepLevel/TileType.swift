import SpriteKit

/// Represents different types of tiles that can exist in a dungeon map.
///
/// Defines the basic tile categories used for dungeon generation and rendering.
/// Each tile kind has different properties affecting movement, visibility, and gameplay.
///
/// - Since: 1.0.0
enum TileKind: UInt8 {
    /// Represents a solid wall tile that blocks movement and sight.
    case wall
    
    /// Represents a floor tile that allows movement and sight.
    case floor
    
    /// Represents a closed door that blocks movement and sight but can be opened.
    case doorClosed
    
    /// Represents a secret door that appears as a wall but can be discovered.
    case doorSecret
}

/// Represents a single tile in the dungeon map with its properties and state.
///
/// Contains all information needed to render and interact with a single tile position,
/// including its type, visibility state, and visual variation.
///
/// - Since: 1.0.0
struct Tile {
    /// The type of tile determining its basic properties.
    var kind: TileKind
    
    /// Indicates whether the tile is currently visible to the player.
    var visible: Bool = false
    
    /// Indicates whether the tile has been explored by the player.
    var explored: Bool = false
    
    /// Visual variation index for rendering different floor textures.
    var variant: Int = 0
    
    /// Indicates whether this tile blocks entity movement.
    ///
    /// - Returns: `true` if the tile prevents entities from moving through it.
    var blocksMovement: Bool {
        switch kind {
        case .wall: return true
        case .doorClosed, .doorSecret: return true
        case .floor: return false
        }
    }
    
    /// Indicates whether this tile blocks line of sight.
    ///
    /// - Returns: `true` if the tile prevents seeing through it.
    var blocksSight: Bool {
        switch kind {
        case .wall: return true
        case .doorClosed, .doorSecret: return true
        case .floor: return false
        }
    }
    
    /// Indicates whether this tile is a door type.
    ///
    /// - Returns: `true` if the tile is either a closed door or secret door.
    var isDoor: Bool {
        switch kind {
        case .doorClosed, .doorSecret: return true
        default: return false
        }
    }
}
