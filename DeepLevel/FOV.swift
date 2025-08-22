import Foundation

/// Implements field of view (FOV) calculation using symmetrical shadowcasting.
///
/// Provides efficient visibility calculation for dungeon exploration games,
/// determining which tiles are visible from a given position while respecting
/// line-of-sight blocking by walls and other obstacles.
///
/// - Since: 1.0.0
struct FOV {
    /// Computes field of view from a given origin point.
    ///
    /// Uses symmetrical shadowcasting algorithm to calculate which tiles
    /// are visible from the origin within the specified radius. Updates
    /// both visibility and exploration status of affected tiles.
    ///
    /// - Parameters:
    ///   - map: The dungeon map to update with visibility information
    ///   - originX: X coordinate of the viewing position
    ///   - originY: Y coordinate of the viewing position
    ///   - radius: Maximum viewing distance in tiles
    /// - Complexity: O(radius²) with good average-case performance
    static func compute(map: inout DungeonMap, originX: Int, originY: Int, radius: Int) {
        // Reset visibility
        for i in 0..<map.tiles.count {
            map.tiles[i].visible = false
        }
        setVisible(&map, x: originX, y: originY)
        // 8 octants using symmetrical shadowcasting
        for oct in 0..<8 {
            castLight(map: &map,
                      originX: originX,
                      originY: originY,
                      radius: radius,
                      row: 1,
                      startSlope: 1.0,
                      endSlope: 0.0,
                      octant: oct)
        }
    }
    
    /// Marks a tile as visible and explored.
    ///
    /// Sets both visibility flags for a tile if it's within map bounds,
    /// tracking both current sight and permanent exploration state.
    ///
    /// - Parameters:
    ///   - map: The map to modify
    ///   - x: X coordinate of the tile
    ///   - y: Y coordinate of the tile
    /// - Complexity: O(1)
    private static func setVisible(_ map: inout DungeonMap, x: Int, y: Int) {
        guard map.inBounds(x,y) else { return }
        let idx = map.index(x: x, y: y)
        map.tiles[idx].visible = true
        map.tiles[idx].explored = true
    }
    
    /// Checks if a tile blocks line of sight.
    ///
    /// Determines whether the tile at the given coordinates prevents
    /// seeing through it, treating out-of-bounds as blocking.
    ///
    /// - Parameters:
    ///   - map: The map to check
    ///   - x: X coordinate of the tile
    ///   - y: Y coordinate of the tile
    /// - Returns: `true` if the tile blocks sight or is out of bounds
    /// - Complexity: O(1)
    private static func blocksSight(_ map: DungeonMap, x: Int, y: Int) -> Bool {
        guard map.inBounds(x,y) else { return true }
        return map.tiles[map.index(x: x, y: y)].blocksSight
    }
    
    /// Recursively casts light rays using shadowcasting algorithm.
    ///
    /// Implements the core shadowcasting logic for one octant, handling
    /// light propagation and shadow generation from blocking obstacles.
    /// Uses slope-based calculations to determine visibility boundaries.
    ///
    /// - Parameters:
    ///   - map: The dungeon map being processed
    ///   - originX: X coordinate of the light source
    ///   - originY: Y coordinate of the light source
    ///   - radius: Maximum light radius
    ///   - row: Current distance from origin
    ///   - startSlope: Starting slope of the light beam
    ///   - endSlope: Ending slope of the light beam
    ///   - octant: Which of the 8 octants is being processed (0-7)
    /// - Complexity: O(radius) per recursive call
    private static func castLight(map: inout DungeonMap,
                                  originX: Int,
                                  originY: Int,
                                  radius: Int,
                                  row: Int,
                                  startSlope: Double,
                                  endSlope: Double,
                                  octant: Int) {
        if startSlope < endSlope { return }
        var nextStart = startSlope
        var blocked = false
        var depth = row
        while depth <= radius && !blocked {
            var dx = -depth
            while dx <= 0 {
                let dy = -dx
                let lSlope = (Double(dx) - 0.5) / (Double(dy) + 0.5)
                let rSlope = (Double(dx) + 0.5) / (Double(dy) - 0.5)
                if lSlope < endSlope {
                    dx += 1
                    continue
                } else if rSlope > startSlope {
                    dx += 1
                    continue
                }
                let (mx,my) = translateOctant(dx: dx, dy: dy, ox: originX, oy: originY, oct: octant)
                if mx < 0 || my < 0 || mx >= map.width || my >= map.height {
                    dx += 1
                    continue
                }
                let dist = hypot(Double(dx), Double(dy))
                if dist <= Double(radius) {
                    setVisible(&map, x: mx, y: my)
                }
                if !blocked {
                    if blocksSight(map, x: mx, y: my) && dist <= Double(radius) {
                        blocked = true
                        castLight(map: &map,
                                  originX: originX,
                                  originY: originY,
                                  radius: radius,
                                  row: depth + 1,
                                  startSlope: nextStart,
                                  endSlope: lSlope,
                                  octant: octant)
                        nextStart = rSlope
                    }
                } else {
                    if !blocksSight(map, x: mx, y: my) {
                        blocked = false
                        nextStart = rSlope
                    }
                }
                dx += 1
            }
            depth += 1
        }
    }
    
    /// Translates relative coordinates to absolute coordinates for a specific octant.
    ///
    /// Converts local dx,dy coordinates relative to an origin into absolute
    /// map coordinates, handling the rotation and reflection for each of the
    /// 8 octants used in shadowcasting.
    ///
    /// - Parameters:
    ///   - dx: Relative X displacement
    ///   - dy: Relative Y displacement
    ///   - ox: Origin X coordinate
    ///   - oy: Origin Y coordinate
    ///   - oct: Octant number (0-7)
    /// - Returns: Absolute (x, y) coordinates on the map
    /// - Complexity: O(1)
    private static func translateOctant(dx: Int, dy: Int, ox: Int, oy: Int, oct: Int) -> (Int,Int) {
        switch oct {
        case 0: return (ox + dy, oy - dx)
        case 1: return (ox + dx, oy - dy)
        case 2: return (ox - dx, oy - dy)
        case 3: return (ox - dy, oy - dx)
        case 4: return (ox - dy, oy + dx)
        case 5: return (ox - dx, oy + dy)
        case 6: return (ox + dx, oy + dy)
        case 7: return (ox + dy, oy + dx)
        default: return (ox,oy)
        }
    }
    
    /// Checks if there is a clear line of sight between two positions.
    ///
    /// Uses a simple ray-casting algorithm to determine if one entity can see another,
    /// taking into account hiding areas that provide concealment.
    ///
    /// - Parameters:
    ///   - map: The dungeon map to check
    ///   - fromX: X coordinate of the viewing position
    ///   - fromY: Y coordinate of the viewing position  
    ///   - toX: X coordinate of the target position
    ///   - toY: Y coordinate of the target position
    /// - Returns: `true` if there is clear line of sight between positions
    /// - Complexity: O(distance between points)
    static func hasLineOfSight(map: DungeonMap, fromX: Int, fromY: Int, toX: Int, toY: Int) -> Bool {
        // If target is in a hiding area, they cannot be seen
        if map.inBounds(toX, toY) {
            let targetTile = map.tiles[map.index(x: toX, y: toY)]
            if targetTile.providesConcealment {
                return false
            }
        }
        
        // Use Bresenham's line algorithm to check line of sight
        let dx = abs(toX - fromX)
        let dy = abs(toY - fromY)
        let sx = fromX < toX ? 1 : -1
        let sy = fromY < toY ? 1 : -1
        var err = dx - dy
        
        var x = fromX
        var y = fromY
        
        while x != toX || y != toY {
            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
            
            // Check if this position blocks sight
            if blocksSight(map, x: x, y: y) {
                return false
            }
        }
        
        return true
    }
}