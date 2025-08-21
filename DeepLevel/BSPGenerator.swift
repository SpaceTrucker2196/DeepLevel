import Foundation

final class BSPGenerator: DungeonGenerating {
    private struct Node {
        var rect: Rect
        var left: Int?
        var right: Int?
        var room: Rect?
    }
    
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap {
        var nodes: [Node] = []
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
        func carve(_ room: Rect) {
            for x in room.x..<room.x+room.w {
                for y in room.y..<room.y+room.h {
                    tiles[x + y*config.width].kind = .floor
                }
            }
        }
        for n in nodes {
            if let r = n.room { carve(r) }
        }
        
        // Connect rooms via corridors (connecting sibling leaves)
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
        func findRoom(node: Node) -> Rect? {
            if let r = node.room { return r }
            if let li = node.left { if let r = findRoom(node: nodes[li]) { return r } }
            if let ri = node.right { if let r = findRoom(node: nodes[ri]) { return r } }
            return nil
        }
        func traverse(_ index: Int) {
            let n = nodes[index]
            if let l = n.left, let r = n.right {
                connect(nodes[l], nodes[r])
                traverse(l)
                traverse(r)
            }
        }
        func carveH(_ x1: Int,_ x2: Int,_ y: Int) {
            for x in min(x1,x2)...max(x1,x2) { tiles[x + y*config.width].kind = .floor }
        }
        func carveV(_ y1: Int,_ y2: Int,_ x: Int) {
            for y in min(y1,y2)...max(y1,y2) { tiles[x + y*config.width].kind = .floor }
        }
        traverse(0)
        
        let rooms = nodes.compactMap { $0.room }
        let start = rooms.first?.center ?? (config.width/2, config.height/2)
        return DungeonMap(width: config.width,
                          height: config.height,
                          tiles: tiles,
                          playerStart: start,
                          rooms: rooms)
    }
}