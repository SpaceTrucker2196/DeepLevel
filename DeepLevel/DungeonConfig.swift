import Foundation

/// Defines the available dungeon generation algorithms.
///
/// Each algorithm produces dungeons with different characteristics and layouts,
/// allowing for varied gameplay experiences and map types.
///
/// - Since: 1.0.0
enum GenerationAlgorithm {
    /// Traditional room-and-corridor generation with rectangular rooms.
    case roomsCorridors
    
    /// Binary space partitioning for more organic room layouts.
    case bsp
    
    /// Cellular automata for cave-like organic structures.
    case cellular
    
    /// City map generation with urban districts, streets, and detailed neighborhoods.
    case cityMap
}

/// Configuration parameters for dungeon generation algorithms.
///
/// Contains all settings that control how dungeons are generated, including
/// size constraints, algorithm-specific parameters, and randomization options.
/// Provides sensible defaults for immediate use while allowing full customization.
///
/// - Since: 1.0.0
struct DungeonConfig {
    /// Width of the generated dungeon in tiles.
    var width: Int = 180
    
    /// Height of the generated dungeon in tiles.
    var height: Int = 90
    
    /// Maximum number of rooms to attempt during generation.
    var maxRooms: Int = 20
    
    /// Minimum size for room dimensions.
    var roomMinSize: Int = 4
    
    /// Maximum size for room dimensions.
    var roomMaxSize: Int = 10
    
    /// Optional seed for deterministic generation. If nil, uses random seed.
    var seed: UInt64? = nil
    
    /// The generation algorithm to use.
    var algorithm: GenerationAlgorithm = .roomsCorridors
    
    /// Initial fill probability for cellular automata algorithm (0.0 to 1.0).
    var cellularFillProb: Double = 0.45
    
    /// Number of smoothing iterations for cellular automata algorithm.
    var cellularSteps: Int = 5
    
    /// Maximum recursion depth for binary space partitioning algorithm.
    var bspMaxDepth: Int = 5
    
    /// Probability of generating secret rooms (0.0 to 1.0).
    var secretRoomChance: Double = 0.08
    
    /// Whether to add 1-tile thick wall borders around rooms like sidewalks.
    var roomBorders: Bool = true
    
    /// Whether to generate city layout with 6x6 blocks and 4-tile wide streets.
    var cityLayout: Bool = true
    
    /// Width of city streets in tiles (only used when cityLayout is true).
    var streetWidth: Int = 4
    
    /// Size of city blocks in tiles (only used when cityLayout is true).
    var cityBlockSize: Int = 6
    
    // MARK: - City Map Algorithm Configuration
    
    /// Width of streets for city map algorithm (in tiles).
    var cityMapStreetWidth: Int = 2
    
    /// Size of city blocks for city map algorithm (in tiles).
    var cityMapBlockSize: Int = 10
    
    /// Frequency of park districts (0.0 to 1.0).
    var parkFrequency: Double = 0.15
    
    /// Frequency of residential districts (0.0 to 1.0).
    var residentialFrequency: Double = 0.35
    
    /// Frequency of urban districts (0.0 to 1.0).
    var urbanFrequency: Double = 0.25
    
    /// Frequency of red light districts (0.0 to 1.0).
    var redLightFrequency: Double = 0.1
    
    /// Frequency of retail districts (0.0 to 1.0).
    var retailFrequency: Double = 0.15
}
