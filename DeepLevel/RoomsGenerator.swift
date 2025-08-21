import Foundation

/// Generates dungeons using the traditional room-and-corridor algorithm.
///
/// Creates dungeons by placing non-overlapping rectangular rooms and connecting
/// them with L-shaped corridors. Includes door placement logic and optional
/// secret room generation for enhanced gameplay variety.
///
/// - Since: 1.0.0
final class RoomsGenerator: DungeonGenerating {
    /// Generates a complete dungeon using room-and-corridor methodology.
    ///
    /// Creates a dungeon by iteratively placing rectangular rooms, connecting
    /// them with corridors, adding doors at appropriate locations, and optionally
    /// placing secret rooms with hidden entrances.
    ///
    /// - Parameters:
    ///   - config: Configuration parameters for generation
    ///   - rng: Random number generator for placement decisions
    /// - Returns: A complete dungeon map with rooms, corridors, and doors
    /// - Complexity: O(width * height + maxRooms²)
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap {
        var tiles = Array(repeating: Tile(kind: .wall), count: config.width * config.height)
        var rooms: [Rect] = []
        
        // Generate rooms and corridors
        generateRoomsAndCorridors(config: config, rng: &rng, tiles: &tiles, rooms: &rooms)
        
        // Place doors at room boundaries
        placeDoors(rooms: rooms, config: config, tiles: &tiles)
        
        // Generate secret rooms
        generateSecretRooms(config: config, rng: &rng, tiles: &tiles, rooms: &rooms)
        
        // Determine player start location
        let start = determinePlayerStart(rooms: rooms, config: config)
        
        var map = DungeonMap(width: config.width, height: config.height, tiles: tiles.map { Tile(kind: $0.kind) }, playerStart: start, rooms: rooms)
        return map
    }
    
    /// Determines if a wall tile is a suitable location for a door.
    ///
    /// Checks if the tile connects a room to a corridor by examining
    /// adjacent tiles for the appropriate floor-wall pattern.
    ///
    /// - Parameters:
    ///   - x: X coordinate to check
    ///   - y: Y coordinate to check
    ///   - tiles: The current tile array
    ///   - width: Map width for bounds checking
    ///   - height: Map height for bounds checking
    /// - Returns: `true` if the location is suitable for a door
    /// - Complexity: O(1)
    private func isPotentialDoor(x: Int, y: Int, tiles: [Tile], width: Int, height: Int) -> Bool {
        guard inBounds(x,y,width,height) else { return false }
        let idx = x + y*width
        if tiles[idx].kind != .wall { return false }
        // If floor on opposite sides horizontally and walls vertically (or vice versa)
        let hasFloorLeftRight = floorAt(x-1,y,tiles,width,height) && floorAt(x+1,y,tiles,width,height)
        let wallsAboveBelow = wallOrOut(x,y-1,tiles,width,height) && wallOrOut(x,y+1,tiles,width,height)
        let hasFloorUpDown = floorAt(x,y-1,tiles,width,height) && floorAt(x,y+1,tiles,width,height)
        let wallsLeftRight = wallOrOut(x-1,y,tiles,width,height) && wallOrOut(x+1,y,tiles,width,height)
        return (hasFloorLeftRight && wallsAboveBelow) || (hasFloorUpDown && wallsLeftRight)
    }
    
    /// Checks if the specified coordinate contains a floor tile.
    ///
    /// - Parameters:
    ///   - x: X coordinate to check
    ///   - y: Y coordinate to check
    ///   - tiles: The tile array to examine
    ///   - w: Map width for bounds checking
    ///   - h: Map height for bounds checking
    /// - Returns: `true` if the coordinate contains a floor tile
    /// - Complexity: O(1)
    private func floorAt(_ x: Int, _ y: Int, _ tiles: [Tile], _ w: Int, _ h: Int) -> Bool {
        guard inBounds(x,y,w,h) else { return false }
        let k = tiles[x + y*w].kind
        return k == .floor
    }
    
    /// Checks if the specified coordinate contains a wall or is out of bounds.
    ///
    /// - Parameters:
    ///   - x: X coordinate to check
    ///   - y: Y coordinate to check
    ///   - tiles: The tile array to examine
    ///   - w: Map width for bounds checking
    ///   - h: Map height for bounds checking
    /// - Returns: `true` if the coordinate contains a wall or is out of bounds
    /// - Complexity: O(1)
    private func wallOrOut(_ x: Int, _ y: Int, _ tiles: [Tile], _ w: Int, _ h: Int) -> Bool {
        guard inBounds(x,y,w,h) else { return true }
        return tiles[x + y*w].kind == .wall
    }
    
    /// Checks if coordinates are within map bounds.
    ///
    /// - Parameters:
    ///   - x: X coordinate to check
    ///   - y: Y coordinate to check
    ///   - w: Map width
    ///   - h: Map height
    /// - Returns: `true` if coordinates are within bounds
    /// - Complexity: O(1)
    private func inBounds(_ x: Int,_ y: Int,_ w: Int,_ h: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h }
    
    /// Counts the number of adjacent floor tiles to a given position.
    ///
    /// Examines the four cardinal directions to count floor tiles,
    /// used for secret door placement validation.
    ///
    /// - Parameters:
    ///   - x: X coordinate to examine
    ///   - y: Y coordinate to examine
    ///   - tiles: The tile array to examine
    ///   - width: Map width for bounds checking
    ///   - height: Map height for bounds checking
    /// - Returns: Number of adjacent floor tiles (0-4)
    /// - Complexity: O(1)
    private func countAdjacentFloors(x: Int, y: Int, tiles: [Tile], width: Int, height: Int) -> Int {
        let dirs = [(-1,0),(1,0),(0,-1),(0,1)]
        return dirs.reduce(0) { acc, d in
            let nx = x + d.0, ny = y + d.1
            guard inBounds(nx,ny,width,height) else { return acc }
            return acc + (tiles[nx + ny*width].kind == .floor ? 1 : 0)
        }
    }
    
    /// Generates the perimeter coordinates of a rectangle.
    ///
    /// Returns all coordinates that form the outer boundary of the given
    /// rectangle, used for secret door placement analysis.
    ///
    /// - Parameter r: The rectangle to generate perimeter for
    /// - Returns: Array of coordinate tuples forming the perimeter
    /// - Complexity: O(perimeter)
    private func perimeter(of r: Rect) -> [(Int,Int)] {
        var pts: [(Int,Int)] = []
        for x in r.x..<(r.x+r.w) {
            pts.append((x, r.y - 1))
            pts.append((x, r.y + r.h))
        }
        for y in r.y..<(r.y+r.h) {
            pts.append((r.x - 1, y))
            pts.append((r.x + r.w, y))
        }
        return pts
    }
    
    /// Carves out floor tiles for a rectangular room.
    ///
    /// - Parameters:
    ///   - room: The rectangular area to carve as floor
    ///   - tiles: The tile array to modify
    ///   - width: Map width for coordinate calculation
    /// - Complexity: O(room area)
    private func carveRoom(_ room: Rect, into tiles: inout [Tile], width: Int) {
        for x in room.x..<room.x+room.w {
            for y in room.y..<room.y+room.h {
                tiles[x + y*width].kind = .floor
            }
        }
    }
    
    /// Carves a horizontal corridor between two x coordinates.
    ///
    /// - Parameters:
    ///   - x1: Starting x coordinate
    ///   - x2: Ending x coordinate
    ///   - y: Y coordinate of the corridor
    ///   - tiles: The tile array to modify
    ///   - width: Map width for coordinate calculation
    /// - Complexity: O(|x2-x1|)
    private func carveHorizontalCorridor(from x1: Int, to x2: Int, at y: Int, into tiles: inout [Tile], width: Int) {
        let a = min(x1,x2), b = max(x1,x2)
        for x in a...b {
            tiles[x + y*width].kind = .floor
        }
    }
    
    /// Carves a vertical corridor between two y coordinates.
    ///
    /// - Parameters:
    ///   - y1: Starting y coordinate
    ///   - y2: Ending y coordinate
    ///   - x: X coordinate of the corridor
    ///   - tiles: The tile array to modify
    ///   - width: Map width for coordinate calculation
    /// - Complexity: O(|y2-y1|)
    private func carveVerticalCorridor(from y1: Int, to y2: Int, at x: Int, into tiles: inout [Tile], width: Int) {
        let a = min(y1,y2), b = max(y1,y2)
        for y in a...b {
            tiles[x + y*width].kind = .floor
        }
    }
    
    /// Generates the main rooms and connecting corridors.
    ///
    /// Places non-overlapping rectangular rooms and connects them with
    /// L-shaped corridors to create the primary dungeon structure.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: Tile array to modify
    ///   - rooms: Room array to populate
    /// - Complexity: O(maxRooms * room area)
    private func generateRoomsAndCorridors(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: inout [Rect]) {
        for _ in 0..<config.maxRooms {
            let w = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let h = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let x = Int.random(in: 1..<(config.width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(config.height - h - 1), using: &rng)
            let room = Rect(x: x, y: y, w: w, h: h)
            if rooms.contains(where: { $0.intersects(room) }) { continue }
            carveRoom(room, into: &tiles, width: config.width)
            if let prev = rooms.last {
                let (px, py) = prev.center
                let (cx, cy) = room.center
                if Bool.random(using: &rng) {
                    carveHorizontalCorridor(from: px, to: cx, at: py, into: &tiles, width: config.width)
                    carveVerticalCorridor(from: py, to: cy, at: cx, into: &tiles, width: config.width)
                } else {
                    carveVerticalCorridor(from: py, to: cy, at: px, into: &tiles, width: config.width)
                    carveHorizontalCorridor(from: px, to: cx, at: cy, into: &tiles, width: config.width)
                }
            }
            rooms.append(room)
        }
    }
    
    /// Places doors at appropriate room boundary locations.
    ///
    /// Analyzes room perimeters to identify suitable door placement
    /// locations where corridors connect to rooms.
    ///
    /// - Parameters:
    ///   - rooms: Array of rooms to process
    ///   - config: Generation configuration for dimensions
    ///   - tiles: Tile array to modify
    /// - Complexity: O(rooms * perimeter)
    private func placeDoors(rooms: [Rect], config: DungeonConfig, tiles: inout [Tile]) {
        for room in rooms {
            // Check perimeter tiles; if floor inside and corridor outside narrow, place door
            for x in room.x..<(room.x+room.w) {
                for yEdge in [room.y - 1, room.y + room.h] {
                    if yEdge < 0 || yEdge >= config.height { continue }
                    if isPotentialDoor(x: x, y: yEdge, tiles: tiles, width: config.width, height: config.height) {
                        tiles[x + yEdge*config.width].kind = .doorClosed
                    }
                }
            }
            for y in room.y..<(room.y+room.h) {
                for xEdge in [room.x - 1, room.x + room.w] {
                    if xEdge < 0 || xEdge >= config.width { continue }
                    if isPotentialDoor(x: xEdge, y: y, tiles: tiles, width: config.width, height: config.height) {
                        tiles[xEdge + y*config.width].kind = .doorClosed
                    }
                }
            }
        }
    }
    
    /// Generates secret rooms with hidden entrances.
    ///
    /// Creates small rooms with secret doors that are only accessible
    /// through hidden passages, adding discovery elements to gameplay.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: Tile array to modify
    ///   - rooms: Room array to append to
    /// - Complexity: O(secretRoomCount * perimeter)
    private func generateSecretRooms(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: inout [Rect]) {
        for _ in 0..<Int(Double(config.maxRooms) * config.secretRoomChance) {
            let w = Int.random(in: 3...5, using: &rng)
            let h = Int.random(in: 3...5, using: &rng)
            let x = Int.random(in: 1..<(config.width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(config.height - h - 1), using: &rng)
            let secret = Rect(x: x, y: y, w: w, h: h)
            if rooms.contains(where: { $0.intersects(secret) }) { continue }
            carveRoom(secret, into: &tiles, width: config.width)
            
            // Replace one perimeter wall tile adjacent to corridor or floor with secret door
            let candidates = perimeter(of: secret).filter { (tx,ty) in
                countAdjacentFloors(x: tx, y: ty, tiles: tiles, width: config.width, height: config.height) == 1
            }
            if let (dx,dy) = candidates.randomElement(using: &rng) {
                tiles[dx + dy*config.width].kind = .doorSecret
            }
            rooms.append(secret)
        }
    }
    
    /// Determines the optimal player starting position.
    ///
    /// Selects the center of the first room if available, otherwise
    /// defaults to the center of the map for fallback positioning.
    ///
    /// - Parameters:
    ///   - rooms: Array of generated rooms
    ///   - config: Generation configuration for map dimensions
    /// - Returns: Player starting coordinates as (x, y) tuple
    /// - Complexity: O(1)
    private func determinePlayerStart(rooms: [Rect], config: DungeonConfig) -> (Int, Int) {
        if let first = rooms.first {
            return first.center
        } else {
            return (config.width / 2, config.height / 2)
        }
    }
}