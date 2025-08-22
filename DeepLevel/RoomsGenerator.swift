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
        
        // Place hiding areas
        placeHidingAreas(config: config, rng: &rng, tiles: &tiles, rooms: rooms)
        
        // Validate connectivity and fix if needed
        validateAndFixConnectivity(config: config, tiles: &tiles, rooms: rooms)
        
        // Determine player start
        let start: (Int, Int)
        if let first = rooms.first {
            start = first.center
        } else {
            start = (config.width / 2, config.height / 2)
        }
        
        let map = DungeonMap(width: config.width, height: config.height, tiles: tiles.map { Tile(kind: $0.kind) }, playerStart: start, rooms: rooms)
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
    /// - Returns: `true` if the coordinate contains a floor tile or sidewalk
    /// - Complexity: O(1)
    private func floorAt(_ x: Int, _ y: Int, _ tiles: [Tile], _ w: Int, _ h: Int) -> Bool {
        guard inBounds(x,y,w,h) else { return false }
        let k = tiles[x + y*w].kind
        return k == .floor || k == .sidewalk
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
            let kind = tiles[nx + ny*width].kind
            return acc + ((kind == .floor || kind == .sidewalk) ? 1 : 0)
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
    ///   - config: Configuration to determine if room borders should be added
    /// - Complexity: O(room area)
    private func carveRoom(_ room: Rect, into tiles: inout [Tile], width: Int, config: DungeonConfig) {
        if config.roomBorders {
            // Carve interior only, leaving 1-tile border as walls
            for x in (room.x+1)..<(room.x+room.w-1) {
                for y in (room.y+1)..<(room.y+room.h-1) {
                    tiles[x + y*width].kind = .floor
                }
            }
        } else {
            // Carve entire room area as floor (original behavior)
            for x in room.x..<room.x+room.w {
                for y in room.y..<room.y+room.h {
                    tiles[x + y*width].kind = .floor
                }
            }
        }
    }
    
    /// Carves a horizontal corridor between two x coordinates.
    ///
    /// For city layout, creates wide streets with sidewalk borders.
    /// For traditional layout, creates single-tile corridors.
    ///
    /// - Parameters:
    ///   - x1: Starting x coordinate
    ///   - x2: Ending x coordinate
    ///   - y: Y coordinate of the corridor
    ///   - tiles: The tile array to modify
    ///   - width: Map width for coordinate calculation
    ///   - config: Configuration to determine corridor style
    /// - Complexity: O(|x2-x1| * corridor_width)
    private func carveHorizontalCorridor(from x1: Int, to x2: Int, at y: Int, into tiles: inout [Tile], width: Int, config: DungeonConfig) {
        let a = min(x1,x2), b = max(x1,x2)
        
        if config.cityLayout {
            // Create wide street with sidewalk borders
            let streetWidth = config.streetWidth
            let totalWidth = streetWidth + 2 // street + sidewalks on both sides
            let startY = y - totalWidth / 2
            
            for x in a...b {
                for dy in 0..<totalWidth {
                    let currentY = startY + dy
                    if currentY >= 0 && currentY < tiles.count / width {
                        let idx = x + currentY * width
                        if idx >= 0 && idx < tiles.count {
                            if dy == 0 || dy == totalWidth - 1 {
                                // Sidewalk borders
                                tiles[idx].kind = .sidewalk
                            } else {
                                // Street interior
                                tiles[idx].kind = .floor
                            }
                        }
                    }
                }
            }
        } else {
            // Traditional single-tile corridor
            for x in a...b {
                tiles[x + y*width].kind = .floor
            }
        }
    }
    
    /// Carves a vertical corridor between two y coordinates.
    ///
    /// For city layout, creates wide streets with sidewalk borders.
    /// For traditional layout, creates single-tile corridors.
    ///
    /// - Parameters:
    ///   - y1: Starting y coordinate
    ///   - y2: Ending y coordinate
    ///   - x: X coordinate of the corridor
    ///   - tiles: The tile array to modify
    ///   - width: Map width for coordinate calculation
    ///   - config: Configuration to determine corridor style
    /// - Complexity: O(|y2-y1| * corridor_width)
    private func carveVerticalCorridor(from y1: Int, to y2: Int, at x: Int, into tiles: inout [Tile], width: Int, config: DungeonConfig) {
        let a = min(y1,y2), b = max(y1,y2)
        
        if config.cityLayout {
            // Create wide street with sidewalk borders
            let streetWidth = config.streetWidth
            let totalWidth = streetWidth + 2 // street + sidewalks on both sides
            let startX = x - totalWidth / 2
            
            for y in a...b {
                for dx in 0..<totalWidth {
                    let currentX = startX + dx
                    if currentX >= 0 && currentX < width {
                        let idx = currentX + y * width
                        if idx >= 0 && idx < tiles.count {
                            if dx == 0 || dx == totalWidth - 1 {
                                // Sidewalk borders
                                tiles[idx].kind = .sidewalk
                            } else {
                                // Street interior
                                tiles[idx].kind = .floor
                            }
                        }
                    }
                }
            }
        } else {
            // Traditional single-tile corridor
            for y in a...b {
                tiles[x + y*width].kind = .floor
            }
        }
    }
    
    /// Generates the main rooms and connecting corridors.
    ///
    /// Places non-overlapping rectangular rooms and connects them with
    /// L-shaped corridors to create the primary dungeon structure.
    /// For city layout, creates a grid of 6x6 blocks with wide streets.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: Tile array to modify
    ///   - rooms: Room array to populate
    /// - Complexity: O(maxRooms * room area)
    private func generateRoomsAndCorridors(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: inout [Rect]) {
        if config.cityLayout {
            // Generate city blocks in a grid layout
            generateCityGrid(config: config, rng: &rng, tiles: &tiles, rooms: &rooms)
        } else {
            // Traditional room generation
            generateTraditionalRooms(config: config, rng: &rng, tiles: &tiles, rooms: &rooms)
        }
    }
    
    /// Generates city blocks in a regular grid with streets between them.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: Tile array to modify
    ///   - rooms: Room array to populate
    private func generateCityGrid(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: inout [Rect]) {
        let blockSize = config.cityBlockSize
        let streetWidth = config.streetWidth + 2 // include sidewalks
        let gridSpacing = blockSize + streetWidth
        
        // Calculate how many blocks fit in each dimension
        let blocksX = (config.width - streetWidth) / gridSpacing
        let blocksY = (config.height - streetWidth) / gridSpacing
        
        // Generate city blocks
        for gridX in 0..<blocksX {
            for gridY in 0..<blocksY {
                let x = gridX * gridSpacing + streetWidth / 2
                let y = gridY * gridSpacing + streetWidth / 2
                let cityBlock = Rect(x: x, y: y, w: blockSize, h: blockSize)
                
                // Ensure the block fits within bounds
                if x + blockSize < config.width && y + blockSize < config.height {
                    carveRoom(cityBlock, into: &tiles, width: config.width, config: config)
                    rooms.append(cityBlock)
                }
            }
        }
        
        // Generate horizontal streets
        for gridY in 0...blocksY {
            let streetCenterY = gridY * gridSpacing
            if streetCenterY >= 0 && streetCenterY < config.height {
                carveHorizontalCorridor(from: 0, to: config.width - 1, at: streetCenterY, into: &tiles, width: config.width, config: config)
            }
        }
        
        // Generate vertical streets
        for gridX in 0...blocksX {
            let streetCenterX = gridX * gridSpacing
            if streetCenterX >= 0 && streetCenterX < config.width {
                carveVerticalCorridor(from: 0, to: config.height - 1, at: streetCenterX, into: &tiles, width: config.width, config: config)
            }
        }
    }
    
    /// Generates rooms using traditional random placement algorithm.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: Tile array to modify
    ///   - rooms: Room array to populate
    private func generateTraditionalRooms(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: inout [Rect]) {
        for _ in 0..<config.maxRooms {
            let w = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let h = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let x = Int.random(in: 1..<(config.width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(config.height - h - 1), using: &rng)
            let room = Rect(x: x, y: y, w: w, h: h)
            if rooms.contains(where: { $0.intersects(room) }) { continue }
            carveRoom(room, into: &tiles, width: config.width, config: config)
            if let prev = rooms.last {
                let (px, py) = prev.center
                let (cx, cy) = room.center
                if Bool.random(using: &rng) {
                    carveHorizontalCorridor(from: px, to: cx, at: py, into: &tiles, width: config.width, config: config)
                    carveVerticalCorridor(from: py, to: cy, at: cx, into: &tiles, width: config.width, config: config)
                } else {
                    carveVerticalCorridor(from: py, to: cy, at: px, into: &tiles, width: config.width, config: config)
                    carveHorizontalCorridor(from: px, to: cx, at: cy, into: &tiles, width: config.width, config: config)
                }
            }
            rooms.append(room)
        }
    }
    
    /// Places doors at appropriate room boundary locations.
    ///
    /// Analyzes room perimeters to identify suitable door placement
    /// locations where corridors connect to rooms. For city layout,
    /// places driveways connecting city blocks to streets.
    /// Ensures every room has at least one door to prevent player trapping.
    ///
    /// - Parameters:
    ///   - rooms: Array of rooms to process
    ///   - config: Generation configuration for dimensions
    ///   - tiles: Tile array to modify
    /// - Complexity: O(rooms * perimeter)
    private func placeDoors(rooms: [Rect], config: DungeonConfig, tiles: inout [Tile]) {
        var roomsWithDoors = Set<Int>()
        
        // First pass: place doors using standard criteria
        for (roomIndex, room) in rooms.enumerated() {
            var hasPlacedDoor = false
            
            // Check perimeter tiles; if floor inside and corridor outside narrow, place door
            for x in room.x..<(room.x+room.w) {
                for yEdge in [room.y - 1, room.y + room.h] {
                    if yEdge < 0 || yEdge >= config.height { continue }
                    if isPotentialDoor(x: x, y: yEdge, tiles: tiles, width: config.width, height: config.height) {
                        let doorType: TileKind = config.cityLayout ? .driveway : .doorClosed
                        tiles[x + yEdge*config.width].kind = doorType
                        hasPlacedDoor = true
                    }
                }
            }
            for y in room.y..<(room.y+room.h) {
                for xEdge in [room.x - 1, room.x + room.w] {
                    if xEdge < 0 || xEdge >= config.width { continue }
                    if isPotentialDoor(x: xEdge, y: y, tiles: tiles, width: config.width, height: config.height) {
                        let doorType: TileKind = config.cityLayout ? .driveway : .doorClosed
                        tiles[xEdge + y*config.width].kind = doorType
                        hasPlacedDoor = true
                    }
                }
            }
            
            if hasPlacedDoor {
                roomsWithDoors.insert(roomIndex)
            }
        }
        
        // Second pass: ensure rooms without doors get at least one door
        for (roomIndex, room) in rooms.enumerated() {
            if !roomsWithDoors.contains(roomIndex) {
                forcePlaceDoor(for: room, config: config, tiles: &tiles)
            }
        }
    }
    
    /// Forces placement of a door for a room that doesn't have one.
    ///
    /// Uses more lenient criteria to ensure every room has at least one entrance.
    /// Prioritizes locations adjacent to corridors or other passable areas.
    ///
    /// - Parameters:
    ///   - room: The room that needs a door
    ///   - config: Generation configuration for dimensions
    ///   - tiles: Tile array to modify
    /// - Complexity: O(perimeter)
    private func forcePlaceDoor(for room: Rect, config: DungeonConfig, tiles: inout [Tile]) {
        let doorType: TileKind = config.cityLayout ? .driveway : .doorClosed
        var candidates: [(Int, Int, Int)] = [] // (x, y, priority)
        
        // Collect all perimeter wall tiles with adjacent floors, prioritizing by adjacency count
        for x in room.x..<(room.x+room.w) {
            for yEdge in [room.y - 1, room.y + room.h] {
                if yEdge >= 0 && yEdge < config.height {
                    let idx = x + yEdge * config.width
                    if tiles[idx].kind == .wall {
                        let adjacentFloors = countAdjacentFloors(x: x, y: yEdge, tiles: tiles, width: config.width, height: config.height)
                        if adjacentFloors > 0 {
                            candidates.append((x, yEdge, adjacentFloors))
                        }
                    }
                }
            }
        }
        
        for y in room.y..<(room.y+room.h) {
            for xEdge in [room.x - 1, room.x + room.w] {
                if xEdge >= 0 && xEdge < config.width {
                    let idx = xEdge + y * config.width
                    if tiles[idx].kind == .wall {
                        let adjacentFloors = countAdjacentFloors(x: xEdge, y: y, tiles: tiles, width: config.width, height: config.height)
                        if adjacentFloors > 0 {
                            candidates.append((xEdge, y, adjacentFloors))
                        }
                    }
                }
            }
        }
        
        // Sort by priority (higher adjacency count first) and place door at best location
        if let best = candidates.max(by: { $0.2 < $1.2 }) {
            tiles[best.0 + best.1 * config.width].kind = doorType
        } else {
            // Fallback: place door at any perimeter wall tile
            for x in room.x..<(room.x+room.w) {
                for yEdge in [room.y - 1, room.y + room.h] {
                    if yEdge >= 0 && yEdge < config.height {
                        let idx = x + yEdge * config.width
                        if tiles[idx].kind == .wall {
                            tiles[idx].kind = doorType
                            return
                        }
                    }
                }
            }
            
            for y in room.y..<(room.y+room.h) {
                for xEdge in [room.x - 1, room.x + room.w] {
                    if xEdge >= 0 && xEdge < config.width {
                        let idx = xEdge + y * config.width
                        if tiles[idx].kind == .wall {
                            tiles[idx].kind = doorType
                            return
                        }
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
            carveRoom(secret, into: &tiles, width: config.width, config: config)
            
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
    
    /// Validates that all accessible areas are connected and fixes connectivity issues.
    ///
    /// Performs a connectivity check from the player start position and identifies
    /// any isolated floor areas. Creates emergency connections if needed to ensure
    /// no areas are unreachable.
    ///
    /// - Parameters:
    ///   - config: Generation configuration for dimensions
    ///   - tiles: Tile array to analyze and potentially modify
    ///   - rooms: Array of rooms for reference
    /// - Complexity: O(width * height)
    private func validateAndFixConnectivity(config: DungeonConfig, tiles: inout [Tile], rooms: [Rect]) {
        guard let firstRoom = rooms.first else { return }
        let start = firstRoom.center
        
        // Find all floor tiles and mark which are reachable
        var reachable = Array(repeating: false, count: config.width * config.height)
        var toVisit = [(start.0, start.1)]
        var visitIndex = 0
        
        // Flood fill from start position
        while visitIndex < toVisit.count {
            let (x, y) = toVisit[visitIndex]
            visitIndex += 1
            
            let idx = x + y * config.width
            if reachable[idx] { continue }
            reachable[idx] = true
            
            // Check 4 directions
            for (dx, dy) in [(-1,0), (1,0), (0,-1), (0,1)] {
                let nx = x + dx, ny = y + dy
                if inBounds(nx, ny, config.width, config.height) {
                    let nidx = nx + ny * config.width
                    let tile = tiles[nidx]
                    if !reachable[nidx] && (tile.kind == .floor || tile.kind == .sidewalk) {
                        toVisit.append((nx, ny))
                    }
                }
            }
        }
        
        // Find isolated floor areas and create connections
        for (roomIndex, room) in rooms.enumerated() {
            var roomReachable = false
            
            // Check if any part of the room is reachable
            for x in room.x..<(room.x + room.w) {
                for y in room.y..<(room.y + room.h) {
                    let idx = x + y * config.width
                    if tiles[idx].kind == .floor && reachable[idx] {
                        roomReachable = true
                        break
                    }
                }
                if roomReachable { break }
            }
            
            // If room is not reachable, create an emergency connection
            if !roomReachable {
                createEmergencyConnection(room: room, config: config, tiles: &tiles, reachable: reachable)
            }
        }
    }
    
    /// Creates an emergency connection from an isolated room to the main network.
    ///
    /// Finds the shortest path from the isolated room to any reachable area
    /// and carves a corridor to establish connectivity.
    ///
    /// - Parameters:
    ///   - room: The isolated room that needs connection
    ///   - config: Generation configuration for dimensions
    ///   - tiles: Tile array to modify
    ///   - reachable: Array indicating which positions are reachable from start
    /// - Complexity: O(width * height)
    private func createEmergencyConnection(room: Rect, config: DungeonConfig, tiles: inout [Tile], reachable: [Bool]) {
        let roomCenter = room.center
        var shortestDistance = Int.max
        var bestTarget: (Int, Int)?
        
        // Find the closest reachable floor tile
        for y in 0..<config.height {
            for x in 0..<config.width {
                let idx = x + y * config.width
                if reachable[idx] && (tiles[idx].kind == .floor || tiles[idx].kind == .sidewalk) {
                    let distance = abs(x - roomCenter.0) + abs(y - roomCenter.1)
                    if distance < shortestDistance {
                        shortestDistance = distance
                        bestTarget = (x, y)
                    }
                }
            }
        }
        
        // Create a simple L-shaped corridor to the target
        if let target = bestTarget {
            let (tx, ty) = target
            let (rx, ry) = roomCenter
            
            // Horizontal segment
            let startX = min(rx, tx), endX = max(rx, tx)
            for x in startX...endX {
                let idx = x + ry * config.width
                if tiles[idx].kind == .wall {
                    tiles[idx].kind = .floor
                }
            }
            
            // Vertical segment
            let startY = min(ry, ty), endY = max(ry, ty)
            for y in startY...endY {
                let idx = tx + y * config.width
                if tiles[idx].kind == .wall {
                    tiles[idx].kind = .floor
                }
            }
            
            // Ensure there's a door to the room if needed
            let doorType: TileKind = config.cityLayout ? .driveway : .doorClosed
            
            // Find a good spot for the room entrance along the new corridor
            for x in room.x..<(room.x + room.w) {
                for yEdge in [room.y - 1, room.y + room.h] {
                    if yEdge >= 0 && yEdge < config.height {
                        let idx = x + yEdge * config.width
                        if tiles[idx].kind == .wall {
                            let adjacentFloors = countAdjacentFloors(x: x, y: yEdge, tiles: tiles, width: config.width, height: config.height)
                            if adjacentFloors > 0 {
                                tiles[idx].kind = doorType
                                return
                            }
                        }
                    }
                }
            }
            
            for y in room.y..<(room.y + room.h) {
                for xEdge in [room.x - 1, room.x + room.w] {
                    if xEdge >= 0 && xEdge < config.width {
                        let idx = xEdge + y * config.width
                        if tiles[idx].kind == .wall {
                            let adjacentFloors = countAdjacentFloors(x: xEdge, y: y, tiles: tiles, width: config.width, height: config.height)
                            if adjacentFloors > 0 {
                                tiles[idx].kind = doorType
                                return
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Places 2x2 hiding areas in rooms and corridors.
    ///
    /// Creates hiding areas that provide concealment from monsters while
    /// still allowing movement. Places them in suitable locations within
    /// rooms and corridors.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: The tile array to modify
    ///   - rooms: Array of generated rooms
    private func placeHidingAreas(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: [Rect]) {
        let maxHidingAreas = max(2, rooms.count / 3) // Roughly one hiding area per 3 rooms
        var placedAreas = 0
        
        for _ in 0..<100 { // Try up to 100 placements
            guard placedAreas < maxHidingAreas else { break }
            
            let x = Int.random(in: 1..<(config.width - 2), using: &rng)
            let y = Int.random(in: 1..<(config.height - 2), using: &rng)
            
            // Check if we can place a 2x2 hiding area here
            var canPlace = true
            for dx in 0..<2 {
                for dy in 0..<2 {
                    let checkX = x + dx
                    let checkY = y + dy
                    let idx = checkX + checkY * config.width
                    
                    // Must be floor tiles and not too close to other hiding areas
                    if tiles[idx].kind != .floor {
                        canPlace = false
                        break
                    }
                }
                if !canPlace { break }
            }
            
            // Ensure we're not placing too close to existing hiding areas
            if canPlace {
                for dx in -1...2 {
                    for dy in -1...2 {
                        let checkX = x + dx
                        let checkY = y + dy
                        if checkX >= 0 && checkX < config.width && 
                           checkY >= 0 && checkY < config.height {
                            let idx = checkX + checkY * config.width
                            if tiles[idx].kind == .hidingArea {
                                canPlace = false
                                break
                            }
                        }
                    }
                    if !canPlace { break }
                }
            }
            
            if canPlace {
                // Place 2x2 hiding area
                for dx in 0..<2 {
                    for dy in 0..<2 {
                        let idx = (x + dx) + (y + dy) * config.width
                        tiles[idx].kind = .hidingArea
                    }
                }
                placedAreas += 1
            }
        }
    }
}
