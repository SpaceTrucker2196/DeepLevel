import Foundation

final class RoomsGenerator: DungeonGenerating {
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap {
        var tiles = Array(repeating: Tile(kind: .wall), count: config.width * config.height)
        var rooms: [Rect] = []
        
        func carve(_ r: Rect) {
            for x in r.x..<r.x+r.w {
                for y in r.y..<r.y+r.h {
                    tiles[x + y*config.width].kind = .floor
                }
            }
        }
        func carveH(_ x1: Int, _ x2: Int, _ y: Int) {
            let a = min(x1,x2), b = max(x1,x2)
            for x in a...b {
                tiles[x + y*config.width].kind = .floor
            }
        }
        func carveV(_ y1: Int, _ y2: Int, _ x: Int) {
            let a = min(y1,y2), b = max(y1,y2)
            for y in a...b {
                tiles[x + y*config.width].kind = .floor
            }
        }
        
        for _ in 0..<config.maxRooms {
            let w = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let h = Int.random(in: config.roomMinSize...config.roomMaxSize, using: &rng)
            let x = Int.random(in: 1..<(config.width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(config.height - h - 1), using: &rng)
            let room = Rect(x: x, y: y, w: w, h: h)
            if rooms.contains(where: { $0.intersects(room) }) { continue }
            carve(room)
            if let prev = rooms.last {
                let (px, py) = prev.center
                let (cx, cy) = room.center
                if Bool.random(using: &rng) {
                    carveH(px, cx, py)
                    carveV(py, cy, cx)
                } else {
                    carveV(py, cy, px)
                    carveH(px, cx, cy)
                }
            }
            rooms.append(room)
        }
        
        // Doors at room boundaries (simple heuristic)
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
        
        // Secret rooms (small)
        for _ in 0..<Int(Double(config.maxRooms) * config.secretRoomChance) {
            let w = Int.random(in: 3...5, using: &rng)
            let h = Int.random(in: 3...5, using: &rng)
            let x = Int.random(in: 1..<(config.width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(config.height - h - 1), using: &rng)
            let secret = Rect(x: x, y: y, w: w, h: h)
            if rooms.contains(where: { $0.intersects(secret) }) { continue }
            carve(secret)
            // Replace one perimeter wall tile adjacent to corridor or floor with secret door
            let candidates = perimeter(of: secret).filter { (tx,ty) in
                countAdjacentFloors(x: tx, y: ty, tiles: tiles, width: config.width, height: config.height) == 1
            }
            if let (dx,dy) = candidates.randomElement(using: &rng) {
                tiles[dx + dy*config.width].kind = .doorSecret
            }
            rooms.append(secret)
        }
        
        // Determine player start
        let start: (Int, Int)
        if let first = rooms.first {
            start = first.center
        } else {
            start = (config.width / 2, config.height / 2)
        }
        
        var map = DungeonMap(width: config.width, height: config.height, tiles: tiles.map { Tile(kind: $0.kind) }, playerStart: start, rooms: rooms)
        return map
    }
    
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
    
    private func floorAt(_ x: Int, _ y: Int, _ tiles: [Tile], _ w: Int, _ h: Int) -> Bool {
        guard inBounds(x,y,w,h) else { return false }
        let k = tiles[x + y*w].kind
        return k == .floor
    }
    private func wallOrOut(_ x: Int, _ y: Int, _ tiles: [Tile], _ w: Int, _ h: Int) -> Bool {
        guard inBounds(x,y,w,h) else { return true }
        return tiles[x + y*w].kind == .wall
    }
    private func inBounds(_ x: Int,_ y: Int,_ w: Int,_ h: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h }
    
    private func countAdjacentFloors(x: Int, y: Int, tiles: [Tile], width: Int, height: Int) -> Int {
        let dirs = [(-1,0),(1,0),(0,-1),(0,1)]
        return dirs.reduce(0) { acc, d in
            let nx = x + d.0, ny = y + d.1
            guard inBounds(nx,ny,width,height) else { return acc }
            return acc + (tiles[nx + ny*width].kind == .floor ? 1 : 0)
        }
    }
    
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