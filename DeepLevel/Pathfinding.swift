import Foundation

/// Provides A* pathfinding algorithm for navigating dungeon maps.
///
/// Implements the A* search algorithm with Manhattan distance heuristic
/// for finding optimal paths between two points while respecting
/// tile passability constraints.
///
/// - Since: 1.0.0
struct Pathfinder {
    /// Represents a position node in the pathfinding graph.
    ///
    /// Simple coordinate wrapper that conforms to Hashable for
    /// efficient storage in collections during pathfinding operations.
    ///
    /// - Since: 1.0.0
    struct Node: Hashable { 
        /// X coordinate of the node.
        let x: Int
        
        /// Y coordinate of the node.
        let y: Int 
    }
    
    /// Finds the optimal path between two points using A* algorithm.
    ///
    /// Calculates the shortest passable path from start to goal using
    /// A* search with Manhattan distance heuristic. Returns an empty
    /// array if no path exists.
    ///
    /// - Parameters:
    ///   - map: The dungeon map to navigate
    ///   - start: Starting coordinates as (x, y) tuple
    ///   - goal: Target coordinates as (x, y) tuple
    ///   - passable: Closure determining which tile types can be traversed
    /// - Returns: Array of coordinate tuples representing the path, or empty if no path exists
    /// - Complexity: O(b^d) where b is branching factor and d is depth
    static func aStar(map: DungeonMap, start: (Int,Int), goal: (Int,Int), passable: (TileKind)->Bool) -> [(Int,Int)] {
        if start == goal { return [start] }
        let startNode = Node(x: start.0, y: start.1)
        let goalNode = Node(x: goal.0, y: goal.1)
        var open: Set<Node> = [startNode]
        var came: [Node: Node] = [:]
        var g: [Node: Double] = [startNode: 0]
        var f: [Node: Double] = [startNode: heuristic(startNode, goalNode)]
        
        while !open.isEmpty {
            guard let current = open.min(by: { (f[$0] ?? 1e9) < (f[$1] ?? 1e9) }) else { break }
            if current == goalNode {
                return reconstruct(came: came, current: current).map { ($0.x, $0.y) }
            }
            open.remove(current)
            for nb in neighbors(of: current, map: map, passable: passable) {
                let tentative = (g[current] ?? 1e9) + 1
                if tentative < (g[nb] ?? 1e9) {
                    came[nb] = current
                    g[nb] = tentative
                    f[nb] = tentative + heuristic(nb, goalNode)
                    open.insert(nb)
                }
            }
        }
        return []
    }
    
    /// Calculates Manhattan distance heuristic between two nodes.
    ///
    /// Provides an admissible heuristic for A* algorithm using
    /// Manhattan (taxicab) distance, suitable for grid-based movement.
    ///
    /// - Parameters:
    ///   - a: First node
    ///   - b: Second node
    /// - Returns: Manhattan distance between the nodes
    /// - Complexity: O(1)
    private static func heuristic(_ a: Node, _ b: Node) -> Double {
        Double(abs(a.x - b.x) + abs(a.y - b.y))
    }
    
    /// Finds all valid neighboring nodes for pathfinding.
    ///
    /// Examines the four cardinal directions from a node and returns
    /// those that are within bounds and passable according to the criteria.
    ///
    /// - Parameters:
    ///   - n: The node to find neighbors for
    ///   - map: The dungeon map for bounds and tile checking
    ///   - passable: Closure determining tile passability
    /// - Returns: Array of valid neighboring nodes
    /// - Complexity: O(1) - checks fixed number of directions
    private static func neighbors(of n: Node, map: DungeonMap, passable: (TileKind)->Bool) -> [Node] {
        var out: [Node] = []
        for d in [(-1,0),(1,0),(0,-1),(0,1)] {
            let nx = n.x + d.0, ny = n.y + d.1
            if map.inBounds(nx, ny), passable(map.tiles[map.index(x: nx, y: ny)].kind) {
                out.append(Node(x: nx, y: ny))
            }
        }
        return out
    }
    
    /// Reconstructs the path from A* search results.
    ///
    /// Traces back through the came-from chain to build the complete
    /// path from start to goal in correct order.
    ///
    /// - Parameters:
    ///   - came: Dictionary mapping nodes to their predecessors
    ///   - current: The goal node reached by A*
    /// - Returns: Array of nodes representing the complete path
    /// - Complexity: O(path length)
    private static func reconstruct(came: [Node:Node], current: Node) -> [Node] {
        var path = [current]
        var cur = current
        while let prev = came[cur] {
            path.append(prev)
            cur = prev
        }
        return path.reversed()
    }
}