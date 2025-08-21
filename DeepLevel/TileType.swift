import SpriteKit

enum TileKind: UInt8 {
    case wall
    case floor
    case doorClosed
    case doorSecret
}

struct Tile {
    var kind: TileKind
    var visible: Bool = false
    var explored: Bool = false
    var variant: Int = 0     // For floor variation
    var blocksMovement: Bool {
        switch kind {
        case .wall: return true
        case .doorClosed, .doorSecret: return true
        case .floor: return false
        }
    }
    var blocksSight: Bool {
        switch kind {
        case .wall: return true
        case .doorClosed, .doorSecret: return true
        case .floor: return false
        }
    }
    var isDoor: Bool {
        switch kind {
        case .doorClosed, .doorSecret: return true
        default: return false
        }
    }
}
