import Foundation

enum GenerationAlgorithm {
    case roomsCorridors
    case bsp
    case cellular
}

struct DungeonConfig {
    var width: Int = 80
    var height: Int = 50
    var maxRooms: Int = 20
    var roomMinSize: Int = 4
    var roomMaxSize: Int = 10
    var seed: UInt64? = nil
    var algorithm: GenerationAlgorithm = .roomsCorridors
    
    // Cellular automata params
    var cellularFillProb: Double = 0.45
    var cellularSteps: Int = 5
    
    // BSP depth
    var bspMaxDepth: Int = 5
    
    // Secret room probability
    var secretRoomChance: Double = 0.08
}