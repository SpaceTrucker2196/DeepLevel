import Foundation

struct DungeonMap {
    var width: Int
    var height: Int
    var tiles: [Tile]   // row-major: x + y*width
    var playerStart: (Int, Int)
    var rooms: [Rect]
    
    func index(x: Int, y: Int) -> Int { x + y * width }
    func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }
    func tile(atX x: Int, y: Int) -> Tile? {
        guard inBounds(x,y) else { return nil }
        return tiles[index(x: x, y: y)]
    }
}

extension DungeonMap {
    mutating func setTile(_ tile: Tile, x: Int, y: Int) {
        guard inBounds(x,y) else { return }
        tiles[index(x: x, y: y)] = tile
    }
    mutating func modifyTile(x: Int, y: Int, _ modify: (inout Tile) -> Void) {
        guard inBounds(x,y) else { return }
        var t = tiles[index(x: x, y: y)]
        modify(&t)
        tiles[index(x: x, y: y)] = t
    }
}