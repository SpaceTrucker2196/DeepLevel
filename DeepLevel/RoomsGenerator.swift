import Foundation

/// Generates dungeons using the traditional room-and-corridor algorithm.
///
/// Creates dungeons by placing non-overlapping rectangular rooms and connecting
/// them with L-shaped corridors. Includes door placement logic and optional
/// secret room generation for enhanced gameplay variety.
///
/// - Since: 1.0.0
final class RoomsGenerator: DungeonGenerating {
    
    // MARK: - Constants
    private enum GeneratorConstants {
        static let secretRoomMinSize: Int = 3
        static let secretRoomMaxSize: Int = 5
        static let requiredAdjacentFloorsForSecret: Int = 1
        static let doorDetectionOffset: Int = 1
    }
    
    // MARK: - Public Interface
    
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
        
        let corridorFunctions = createCorridorFunctions(tiles: &tiles, config: config)
        rooms = generateRoomsAndCorridors(config: config, rng: &rng, tiles: &tiles, corridorFunctions: corridorFunctions)
        addDoorsToRooms(rooms: rooms, tiles: &tiles, config: config)
        addSecretRooms(to: &rooms, tiles: &tiles, config: config, rng: &rng)
        
        let playerStart = determinePlayerStart(from: rooms, config: config)
        return DungeonMap(width: config.width, height: config.height, tiles: tiles.map { Tile(kind: $0.kind) }, playerStart: playerStart, rooms: rooms)
    }
    
    // MARK: - Room and Corridor Generation
    
    /// Creates the corridor creation functions with tile array access.
    ///
    /// - Parameters:
    ///   - tiles: Reference to the tile array
    ///   - config: Configuration for bounds checking
    /// - Returns: Tuple of corridor creation functions
    private func createCorridorFunctions(tiles: inout [Tile], config: DungeonConfig) -> (
        createFloorArea: (Rect) -> Void,
        createHorizontalCorridor: (Int, Int, Int) -> Void,
        createVerticalCorridor: (Int, Int, Int) -> Void
    ) {
        
        /// Creates floor tiles for a rectangular room area.
        ///
        /// - Parameter r: The rectangular area to carve as floor
        func createFloorArea(_ r: Rect) {
            for x in r.x..<r.x+r.w {
                for y in r.y..<r.y+r.h {
                    tiles[x + y*config.width].kind = .floor
                }
            }
        }
        
        /// Creates a horizontal corridor between two x coordinates.
        ///
        /// - Parameters:
        ///   - x1: Starting x coordinate
        ///   - x2: Ending x coordinate
        ///   - y: Y coordinate of the corridor
        func createHorizontalCorridor(from x1: Int, to x2: Int, at y: Int) {
            let a = min(x1,x2), b = max(x1,x2)
            for x in a...b {
                tiles[x + y*config.width].kind = .floor
            }
        }
        
        /// Creates a vertical corridor between two y coordinates.
        ///
        /// - Parameters:
        ///   - y1: Starting y coordinate
        ///   - y2: Ending y coordinate
        ///   - x: X coordinate of the corridor
        func createVerticalCorridor(from y1: Int, to y2: Int, at x: Int) {
            let a = min(y1,y2), b = max(y1,y2)
            for y in a...b {
                tiles[x + y*config.width].kind = .floor
            }
        }
        
        return (createFloorArea, createHorizontalCorridor, createVerticalCorridor)
    }
    
    /// Generates rooms and connects them with corridors.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: Tile array to modify
    ///   - corridorFunctions: Functions for creating floors and corridors
    /// - Returns: Array of generated rooms
    private func generateRoomsAndCorridors(
        config: DungeonConfig, 
        rng: inout RandomNumberGenerator, 
        tiles: inout [Tile],
        corridorFunctions: (createFloorArea: (Rect) -> Void, createHorizontalCorridor: (Int, Int, Int) -> Void, createVerticalCorridor: (Int, Int, Int) -> Void)
    ) -> [Rect] {
        var rooms: [Rect] = []
        
        for _ in 0..<config.maxRooms {
            let w = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let h = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let x = Int.random(in: 1..<(config.width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(config.height - h - 1), using: &rng)
            let room = Rect(x: x, y: y, w: w, h: h)
            if rooms.contains(where: { $0.intersects(room) }) { continue }
            corridorFunctions.createFloorArea(room)
            if let prev = rooms.last {
                connectRooms(previous: prev, current: room, rng: &rng, corridorFunctions: corridorFunctions)
            }
            rooms.append(room)
        }
        
        return rooms
    }
    
    /// Connects two rooms with L-shaped corridors.
    ///
    /// - Parameters:
    ///   - previous: The previous room to connect from
    ///   - current: The current room to connect to
    ///   - rng: Random number generator for corridor direction choice
    ///   - corridorFunctions: Functions for creating corridors
    private func connectRooms(
        previous: Rect, 
        current: Rect, 
        rng: inout RandomNumberGenerator,
        corridorFunctions: (createFloorArea: (Rect) -> Void, createHorizontalCorridor: (Int, Int, Int) -> Void, createVerticalCorridor: (Int, Int, Int) -> Void)
    ) {
        let (px, py) = previous.center
        let (cx, cy) = current.center
        if Bool.random(using: &rng) {
            corridorFunctions.createHorizontalCorridor(px, cx, py)
            corridorFunctions.createVerticalCorridor(py, cy, cx)
        } else {
            corridorFunctions.createVerticalCorridor(py, cy, px)
            corridorFunctions.createHorizontalCorridor(px, cx, cy)
        }
    }
    
    // MARK: - Door Generation
    
    /// Adds doors at room boundaries.
    ///
    /// - Parameters:
    ///   - rooms: Array of rooms to add doors to
    ///   - tiles: Tile array to modify
    ///   - config: Configuration for bounds checking
    private func addDoorsToRooms(rooms: [Rect], tiles: inout [Tile], config: DungeonConfig) {
        for room in rooms {
            // Check perimeter tiles; if floor inside and corridor outside narrow, place door
            for x in room.x..<(room.x+room.w) {
                for yEdge in [room.y - GeneratorConstants.doorDetectionOffset, room.y + room.h] {
                    if yEdge < 0 || yEdge >= config.height { continue }
                    if isPotentialDoor(x: x, y: yEdge, tiles: tiles, width: config.width, height: config.height) {
                        tiles[x + yEdge*config.width].kind = .doorClosed
                    }
                }
            }
            for y in room.y..<(room.y+room.h) {
                for xEdge in [room.x - GeneratorConstants.doorDetectionOffset, room.x + room.w] {
                    if xEdge < 0 || xEdge >= config.width { continue }
                    if isPotentialDoor(x: xEdge, y: y, tiles: tiles, width: config.width, height: config.height) {
                        tiles[xEdge + y*config.width].kind = .doorClosed
                    }
                }
            }
        }
    }
    
    // MARK: - Secret Room Generation
    
    /// Adds secret rooms to the dungeon.
    ///
    /// - Parameters:
    ///   - rooms: Array of existing rooms to add to
    ///   - tiles: Tile array to modify
    ///   - config: Configuration parameters
    ///   - rng: Random number generator
    private func addSecretRooms(to rooms: inout [Rect], tiles: inout [Tile], config: DungeonConfig, rng: inout RandomNumberGenerator) {
        for _ in 0..<Int(Double(config.maxRooms) * config.secretRoomChance) {
            let w = Int.random(in: GeneratorConstants.secretRoomMinSize...GeneratorConstants.secretRoomMaxSize, using: &rng)
            let h = Int.random(in: GeneratorConstants.secretRoomMinSize...GeneratorConstants.secretRoomMaxSize, using: &rng)
            let x = Int.random(in: 1..<(config.width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(config.height - h - 1), using: &rng)
            let secret = Rect(x: x, y: y, w: w, h: h)
            if rooms.contains(where: { $0.intersects(secret) }) { continue }
            createSecretRoom(secret, in: &tiles, rooms: &rooms, config: config, rng: &rng)
        }
    }
    
    /// Creates a single secret room with appropriate entrance.
    ///
    /// - Parameters:
    ///   - room: The room rectangle to create
    ///   - tiles: Tile array to modify
    ///   - rooms: Rooms array to add to
    ///   - config: Configuration parameters
    ///   - rng: Random number generator
    private func createSecretRoom(_ room: Rect, in tiles: inout [Tile], rooms: inout [Rect], config: DungeonConfig, rng: inout RandomNumberGenerator) {
        // Create floor area
        for x in room.x..<room.x+room.w {
            for y in room.y..<room.y+room.h {
                tiles[x + y*config.width].kind = .floor
            }
        }
        
        // Replace one perimeter wall tile adjacent to corridor or floor with secret door
        let candidates = perimeter(of: room).filter { (tx,ty) in
            countAdjacentFloors(x: tx, y: ty, tiles: tiles, width: config.width, height: config.height) == GeneratorConstants.requiredAdjacentFloorsForSecret
        }
        if let (dx,dy) = candidates.randomElement(using: &rng) {
            tiles[dx + dy*config.width].kind = .doorSecret
        }
        rooms.append(room)
    }
    
    /// Determines the player starting position.
    ///
    /// - Parameters:
    ///   - rooms: Array of generated rooms
    ///   - config: Configuration for fallback position
    /// - Returns: Player starting coordinates
    private func determinePlayerStart(from rooms: [Rect], config: DungeonConfig) -> (Int, Int) {
        if let first = rooms.first {
            return first.center
        } else {
            return (config.width / 2, config.height / 2)
        }
    }
    
    // MARK: - Helper Methods
    
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
        guard isWithinBounds(x,y,width,height) else { return false }
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
        guard isWithinBounds(x,y,w,h) else { return false }
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
        guard isWithinBounds(x,y,w,h) else { return true }
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
    private func isWithinBounds(_ x: Int,_ y: Int,_ w: Int,_ h: Int) -> Bool { 
        x >= 0 && y >= 0 && x < w && y < h 
    }
    
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
            guard isWithinBounds(nx,ny,width,height) else { return acc }
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
}