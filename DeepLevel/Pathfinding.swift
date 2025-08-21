import Foundation

struct Pathfinder {
    struct Node: Hashable { let x: Int; let y: Int }
    
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
    
    private static func heuristic(_ a: Node, _ b: Node) -> Double {
        Double(abs(a.x - b.x) + abs(a.y - b.y))
    }
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