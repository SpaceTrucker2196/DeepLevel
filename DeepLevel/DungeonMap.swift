import Foundation

/// Represents a complete dungeon map with tiles, rooms, and player spawn information.
///
/// The central data structure containing all spatial information for a generated dungeon,
/// including tile layout, room definitions, and the player's starting position.
/// Uses a row-major array for efficient tile storage and access.
///
/// - Since: 1.0.0
struct DungeonMap {
    /// Width of the dungeon map in tiles.
    var width: Int
    
    /// Height of the dungeon map in tiles.
    var height: Int
    
    /// Array of tiles stored in row-major order (x + y*width).
    var tiles: [Tile]
    
    /// Starting position for the player as (x, y) coordinates.
    var playerStart: (Int, Int)
    
    /// Array of rectangular room areas within the dungeon.
    var rooms: [Rect]
    
    /// Converts 2D coordinates to a 1D array index.
    ///
    /// - Parameters:
    ///   - x: X coordinate in the grid
    ///   - y: Y coordinate in the grid
    /// - Returns: The corresponding index in the tiles array
    /// - Complexity: O(1)
    func index(x: Int, y: Int) -> Int { x + y * width }
    
    /// Checks if the given coordinates are within the map boundaries.
    ///
    /// - Parameters:
    ///   - x: X coordinate to check
    ///   - y: Y coordinate to check
    /// - Returns: `true` if coordinates are within bounds, `false` otherwise
    /// - Complexity: O(1)
    func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }
    
    /// Retrieves the tile at the specified coordinates.
    ///
    /// - Parameters:
    ///   - x: X coordinate of the desired tile
    ///   - y: Y coordinate of the desired tile
    /// - Returns: The tile at the specified position, or `nil` if out of bounds
    /// - Complexity: O(1)
    func tile(atX x: Int, y: Int) -> Tile? {
        guard inBounds(x,y) else { return nil }
        return tiles[index(x: x, y: y)]
    }
}

/// Extension providing tile modification methods for DungeonMap.
///
/// Contains mutating methods for safely updating tiles within the map boundaries.
extension DungeonMap {
    /// Sets a tile at the specified coordinates.
    ///
    /// Only modifies the tile if the coordinates are within map boundaries.
    ///
    /// - Parameters:
    ///   - tile: The new tile to place
    ///   - x: X coordinate where to place the tile
    ///   - y: Y coordinate where to place the tile
    /// - Complexity: O(1)
    mutating func setTile(_ tile: Tile, x: Int, y: Int) {
        guard inBounds(x,y) else { return }
        tiles[index(x: x, y: y)] = tile
    }
    
    /// Modifies a tile at the specified coordinates using a closure.
    ///
    /// Provides safe in-place modification of a tile's properties without
    /// directly exposing the internal array structure.
    ///
    /// - Parameters:
    ///   - x: X coordinate of the tile to modify
    ///   - y: Y coordinate of the tile to modify
    ///   - modify: Closure that receives an inout reference to the tile
    /// - Complexity: O(1)
    mutating func modifyTile(x: Int, y: Int, _ modify: (inout Tile) -> Void) {
        guard inBounds(x,y) else { return }
        var t = tiles[index(x: x, y: y)]
        modify(&t)
        tiles[index(x: x, y: y)] = t
    }
}