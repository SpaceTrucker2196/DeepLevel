import Foundation

/// Generates dungeons using binary space partitioning algorithm.
///
/// Creates dungeons by recursively dividing the space into smaller regions
/// and placing rooms within leaf nodes. Connects rooms with corridors that
/// follow the partition tree structure for more organic layouts.
///
/// - Since: 1.0.0
final class BSPGenerator: DungeonGenerating {
    /// Represents a node in the binary space partition tree.
    ///
    /// Each node contains a rectangular region and optional child references
    /// for the partition tree structure, plus an optional room for leaf nodes.
    ///
    /// - Since: 1.0.0
    private struct Node {
        /// The rectangular area this node represents.
        var rect: Rect
        
        /// Index of the left child node in the nodes array.
        var left: Int?
        
        /// Index of the right child node in the nodes array.
        var right: Int?
        
        /// The room placed within this node's area (for leaf nodes).
        var room: Rect?
    }
    
    /// Generates a complete dungeon using binary space partitioning.
    ///
    /// Recursively divides the dungeon space into smaller regions, places
    /// rooms in leaf partitions, then connects them with corridors following
    /// the partition tree hierarchy for natural connectivity.
    ///
    /// - Parameters:
    ///   - config: Configuration parameters for generation
    ///   - rng: Random number generator for partition decisions
    /// - Returns: A complete dungeon map with organically connected rooms
    /// - Complexity: O(width * height + 2^maxDepth)
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap {
        var nodes: [Node] = []
        
        /// Recursively splits a node into two child partitions.
        ///
        /// Divides the node's area either horizontally or vertically,
        /// creating two child nodes and continuing recursion up to max depth.
        ///
        /// - Parameters:
        ///   - nodeIndex: Index of the node to split
        ///   - depth: Current recursion depth
        func split(nodeIndex: Int, depth: Int) {
            if depth >= config.bspMaxDepth { return }
            var node = nodes[nodeIndex]
            let horizontal = Bool.random(using: &rng)
            if horizontal {
                if node.rect.h < config.roomMinSize * 2 + 4 { return }
                let cut = Int.random(in: (node.rect.y+config.roomMinSize+2)..<(node.rect.y+node.rect.h-config.roomMinSize-2), using: &rng)
                let top = Rect(x: node.rect.x, y: node.rect.y, w: node.rect.w, h: cut - node.rect.y)
                let bottom = Rect(x: node.rect.x, y: cut, w: node.rect.w, h: node.rect.y + node.rect.h - cut)
                node.left = nodes.count
                node.right = nodes.count + 1
                nodes[nodeIndex] = node
                nodes.append(Node(rect: top, left: nil, right: nil, room: nil))
                nodes.append(Node(rect: bottom, left: nil, right: nil, room: nil))
                split(nodeIndex: node.left!, depth: depth+1)
                split(nodeIndex: node.right!, depth: depth+1)
            } else {
                if node.rect.w < config.roomMinSize * 2 + 4 { return }
                let cut = Int.random(in: (node.rect.x+config.roomMinSize+2)..<(node.rect.x+node.rect.w-config.roomMinSize-2), using: &rng)
                let leftR = Rect(x: node.rect.x, y: node.rect.y, w: cut - node.rect.x, h: node.rect.h)
                let rightR = Rect(x: cut, y: node.rect.y, w: node.rect.x + node.rect.w - cut, h: node.rect.h)
                node.left = nodes.count
                node.right = nodes.count + 1
                nodes[nodeIndex] = node
                nodes.append(Node(rect: leftR, left: nil, right: nil, room: nil))
                nodes.append(Node(rect: rightR, left: nil, right: nil, room: nil))
                split(nodeIndex: node.left!, depth: depth+1)
                split(nodeIndex: node.right!, depth: depth+1)
            }
        }
        
        nodes.append(Node(rect: Rect(x: 1, y: 1, w: config.width - 2, h: config.height - 2), left: nil, right: nil, room: nil))
        split(nodeIndex: 0, depth: 0)
        
        // Assign rooms at leaves
        for i in 0..<nodes.count {
            if nodes[i].left == nil && nodes[i].right == nil {
                let r = nodes[i].rect
                if r.w >= config.roomMinSize && r.h >= config.roomMinSize {
                    let w = Int.random(in: config.roomMinSize...min(config.roomMaxSize, r.w), using: &rng)
                    let h = Int.random(in: config.roomMinSize...min(config.roomMaxSize, r.h), using: &rng)
                    let x = Int.random(in: r.x...(r.x + r.w - w), using: &rng)
                    let y = Int.random(in: r.y...(r.y + r.h - h), using: &rng)
                    nodes[i].room = Rect(x: x, y: y, w: w, h: h)
                }
            }
        }
        
        var tiles = Array(repeating: Tile(kind: .wall), count: config.width * config.height)
        
        /// Carves out floor tiles for a rectangular room.
        ///
        /// - Parameter room: The rectangular area to carve as floor
        func carve(_ room: Rect) {
            if config.roomBorders {
                // Carve interior only, leaving 1-tile border as walls
                for x in (room.x+1)..<(room.x+room.w-1) {
                    for y in (room.y+1)..<(room.y+room.h-1) {
                        tiles[x + y*config.width].kind = .floor
                    }
                }
            } else {
                // Carve entire room area as floor (original behavior)
                for x in room.x..<room.x+room.w {
                    for y in room.y..<room.y+room.h {
                        tiles[x + y*config.width].kind = .floor
                    }
                }
            }
        }
        for n in nodes {
            if let r = n.room { carve(r) }
        }
        
        /// Connects two nodes by creating corridors between their rooms.
        ///
        /// - Parameters:
        ///   - a: First node to connect
        ///   - b: Second node to connect
        func connect(_ a: Node, _ b: Node) {
            guard let ar = findRoom(node: a), let br = findRoom(node: b) else { return }
            let (ax, ay) = ar.center
            let (bx, by) = br.center
            if Bool.random(using: &rng) {
                carveH(ax, bx, ay)
                carveV(ay, by, bx)
            } else {
                carveV(ay, by, ax)
                carveH(ax, bx, by)
            }
        }
        
        /// Finds the first room in a node or its descendants.
        ///
        /// - Parameter node: The node to search for a room
        /// - Returns: The first room found, or nil if none exists
        /// - Complexity: O(log n) average case
        func findRoom(node: Node) -> Rect? {
            if let r = node.room { return r }
            if let li = node.left { if let r = findRoom(node: nodes[li]) { return r } }
            if let ri = node.right { if let r = findRoom(node: nodes[ri]) { return r } }
            return nil
        }
        
        /// Traverses the partition tree to connect sibling nodes.
        ///
        /// - Parameter index: Index of the current node to process
        func traverse(_ index: Int) {
            let n = nodes[index]
            if let l = n.left, let r = n.right {
                connect(nodes[l], nodes[r])
                traverse(l)
                traverse(r)
            }
        }
        
        /// Carves a horizontal corridor between two x coordinates.
        ///
        /// - Parameters:
        ///   - x1: Starting x coordinate
        ///   - x2: Ending x coordinate
        ///   - y: Y coordinate of the corridor
        func carveH(_ x1: Int,_ x2: Int,_ y: Int) {
            for x in min(x1,x2)...max(x1,x2) { tiles[x + y*config.width].kind = .floor }
        }
        
        /// Carves a vertical corridor between two y coordinates.
        ///
        /// - Parameters:
        ///   - y1: Starting y coordinate
        ///   - y2: Ending y coordinate
        ///   - x: X coordinate of the corridor
        func carveV(_ y1: Int,_ y2: Int,_ x: Int) {
            for y in min(y1,y2)...max(y1,y2) { tiles[x + y*config.width].kind = .floor }
        }
        traverse(0)
        
        // Place hiding areas
        placeHidingAreas(config: config, rng: &rng, tiles: &tiles, rooms: rooms)
        
        let rooms = nodes.compactMap { $0.room }
        let start = rooms.first?.center ?? (config.width/2, config.height/2)
        return DungeonMap(width: config.width,
                          height: config.height,
                          tiles: tiles,
                          playerStart: start,
                          rooms: rooms)
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