import Foundation

struct FOV {
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
    
    private static func setVisible(_ map: inout DungeonMap, x: Int, y: Int) {
        guard map.inBounds(x,y) else { return }
        let idx = map.index(x: x, y: y)
        map.tiles[idx].visible = true
        map.tiles[idx].explored = true
    }
    
    private static func blocksSight(_ map: DungeonMap, x: Int, y: Int) -> Bool {
        guard map.inBounds(x,y) else { return true }
        return map.tiles[map.index(x: x, y: y)].blocksSight
    }
    
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
}