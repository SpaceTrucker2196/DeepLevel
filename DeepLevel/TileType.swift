import SpriteKit

/// Represents soil quality properties for testable tiles.
///
/// Contains measurements and characteristics that can be discovered through soil testing.
/// Values are generated randomly but remain consistent for each tile location.
///
/// - Since: 1.0.0
struct SoilProperties {
    /// Soil pH level (1.0-14.0, with 7.0 being neutral)
    let pH: Float
    
    /// Moisture content percentage (0.0-100.0)
    let moisture: Float
    
    /// Soil temperature in Celsius (-10.0 to 40.0)
    let temperature: Float
    
    /// Nitrogen level (0.0-100.0)
    let nitrogen: Float
    
    /// Phosphorus level (0.0-100.0)
    let phosphorus: Float
    
    /// Potassium level (0.0-100.0)
    let potassium: Float
    
    /// Soil compaction level (0.0-100.0, higher = more compacted)
    let compaction: Float
    
    /// Has this soil been tested by the player?
    var hasBeenTested: Bool = false
    
    /// Initialize with random but realistic soil values
    init() {
        // Generate realistic soil values
        self.pH = Float.random(in: 4.5...8.5)
        self.moisture = Float.random(in: 10.0...80.0)
        self.temperature = Float.random(in: 5.0...25.0)
        self.nitrogen = Float.random(in: 5.0...95.0)
        self.phosphorus = Float.random(in: 3.0...75.0)
        self.potassium = Float.random(in: 8.0...85.0)
        self.compaction = Float.random(in: 15.0...85.0)
    }
    
    /// Initialize with specific values (for testing)
    init(pH: Float, moisture: Float, temperature: Float, nitrogen: Float, phosphorus: Float, potassium: Float, compaction: Float) {
        self.pH = pH
        self.moisture = moisture
        self.temperature = temperature
        self.nitrogen = nitrogen
        self.phosphorus = phosphorus
        self.potassium = potassium
        self.compaction = compaction
    }
    
    /// Get soil quality description based on values
    var qualityDescription: String {
        let avgNutrient = (nitrogen + phosphorus + potassium) / 3.0
        let pHGood = pH >= 6.0 && pH <= 7.5
        let moistureGood = moisture >= 25.0 && moisture <= 65.0
        let compactionGood = compaction <= 50.0
        
        if avgNutrient > 70.0 && pHGood && moistureGood && compactionGood {
            return "Excellent soil quality - ideal for most plants!"
        } else if avgNutrient > 50.0 && pHGood && moistureGood {
            return "Good soil quality - suitable for gardening."
        } else if avgNutrient > 30.0 {
            return "Fair soil quality - may need amendments."
        } else {
            return "Poor soil quality - requires significant improvement."
        }
    }
}

/// Represents different types of tiles that can exist in a dungeon map.
///
/// Defines the basic tile categories used for dungeon generation and rendering.
/// Each tile kind has different properties affecting movement, visibility, and gameplay.
///
/// - Since: 1.0.0
enum TileKind: UInt8 {
    /// Represents a solid wall tile that blocks movement and sight.
    case wall
    
    /// Represents a floor tile that allows movement and sight.
    case floor
    
    /// Represents a closed door that blocks movement and sight but can be opened.
    case doorClosed
    
    /// Represents a secret door that appears as a wall but can be discovered.
    case doorSecret
    
    /// Represents a sidewalk tile that allows movement and sight, borders city streets.
    case sidewalk
    
    /// Represents a driveway that blocks movement and sight but can be opened (renamed from door for city theme).
    case driveway
    
    /// Represents a hiding area that allows movement but provides concealment from monsters.
    case hidingArea
    
    // MARK: - City Map Tile Types
    
    /// Represents a park area (green) that allows movement and may contain hiding spots.
    case park
    
    /// Represents a residential district type 1.
    case residential1
    
    /// Represents a residential district type 2.
    case residential2
    
    /// Represents a residential district type 3.
    case residential3
    
    /// Represents a residential district type 4.
    case residential4
    
    /// Represents an urban district type 1.
    case urban1
    
    /// Represents an urban district type 2.
    case urban2
    
    /// Represents an urban district type 3.
    case urban3
    
    /// Represents a red light district that emits red light to adjacent tiles.
    case redLight
    
    /// Represents a retail district with $ symbol tiles.
    case retail
    
    /// Represents a sidewalk with a tree.
    case sidewalkTree
    
    /// Represents a sidewalk with a fire hydrant.
    case sidewalkHydrant
    
    /// Represents a street tile for 2-tile wide streets.
    case street
    
    /// Represents a crosswalk tile where streets intersect.
    case crosswalk
    
    /// Represents an ice cream truck in parks.
    case iceCreamTruck
}

/// Represents a single tile in the dungeon map with its properties and state.
///
/// Contains all information needed to render and interact with a single tile position,
/// including its type, visibility state, visual variation, scaling information, and soil properties.
///
/// - Since: 1.0.0
struct Tile {
    /// The type of tile determining its basic properties.
    var kind: TileKind
    
    /// Indicates whether the tile is currently visible to the player.
    var visible: Bool = false
    
    /// Indicates whether the tile has been explored by the player.
    var explored: Bool = false
    
    /// Visual variation index for rendering different floor textures.
    var variant: Int = 0
    
    /// Color cast for light/shadow effects (0.0 = no effect, negative = shadow, positive = light).
    var colorCast: Float = 0.0
    
    /// Scale factor for the tile (1.0 = normal size, 2.0 = double size).
    var scale: CGFloat = 1.0
    
    /// Soil properties for park tiles that can be tested
    var soilProperties: SoilProperties?
    
    /// Indicates whether this tile blocks entity movement.
    ///
    /// - Returns: `true` if the tile prevents entities from moving through it.
    var blocksMovement: Bool {
        switch kind {
        case .wall: return true
        case .doorClosed, .doorSecret, .driveway: return true
        case .floor, .sidewalk, .hidingArea: return false
        case .park, .residential1, .residential2, .residential3, .residential4: return false
        case .urban1, .urban2, .urban3, .redLight, .retail: return false
        case .sidewalkTree, .sidewalkHydrant, .street: return false
        case .crosswalk, .iceCreamTruck: return false
        }
    }
    
    /// Indicates whether this tile blocks line of sight.
    ///
    /// - Returns: `true` if the tile prevents seeing through it.
    var blocksSight: Bool {
        switch kind {
        case .wall: return true
        case .doorClosed, .doorSecret, .driveway: return true
        case .floor, .sidewalk, .hidingArea: return false
        case .park, .residential1, .residential2, .residential3, .residential4: return false
        case .urban1, .urban2, .urban3, .redLight, .retail: return false
        case .sidewalkTree, .sidewalkHydrant, .street: return false
        case .crosswalk, .iceCreamTruck: return false
        }
    }
    
    /// Indicates whether this tile provides concealment from monsters.
    ///
    /// - Returns: `true` if the tile hides entities from monster line of sight.
    var providesConcealment: Bool {
        switch kind {
        case .hidingArea, .park: return true
        default: return false
        }
    }
    
    /// Indicates whether this tile is a door type.
    ///
    /// - Returns: `true` if the tile is either a closed door, secret door, or driveway.
    var isDoor: Bool {
        switch kind {
        case .doorClosed, .doorSecret, .driveway: return true
        default: return false
        }
    }
    
    /// Indicates whether this tile can be tested for soil properties.
    ///
    /// - Returns: `true` if the tile represents an area where soil testing makes sense.
    var canTestSoil: Bool {
        switch kind {
        case .park, .hidingArea: return soilProperties != nil
        default: return false
        }
    }
}

/// Represents the results of a soil test performed by the player.
///
/// Contains the measured values and analysis based on the player's available testing equipment.
/// Different equipment reveals different aspects of soil composition.
///
/// - Since: 1.0.0
struct SoilTestResult {
    /// The location where the test was performed
    let gridX: Int
    let gridY: Int
    
    /// Which soil testing equipment was used
    let equipmentUsed: String
    
    /// The measured/revealed properties based on equipment capabilities
    var measuredpH: Float?
    var measuredMoisture: Float?
    var measuredTemperature: Float?
    var measuredNitrogen: Float?
    var measuredPhosphorus: Float?
    var measuredPotassium: Float?
    var measuredCompaction: Float?
    
    /// Overall assessment based on available measurements
    var assessment: String
    
    /// When the test was performed
    let timestamp: Date
    
    init(location: (Int, Int), equipment: String, soilProperties: SoilProperties) {
        self.gridX = location.0
        self.gridY = location.1
        self.equipmentUsed = equipment
        self.timestamp = Date()
        
        // Different equipment reveals different properties
        switch equipment {
        case "pH Test Kit":
            self.measuredpH = soilProperties.pH
            self.assessment = "pH Level: \(String(format: "%.1f", soilProperties.pH)) - \(SoilTestResult.pHDescription(soilProperties.pH))"
            
        case "Moisture Meter":
            self.measuredMoisture = soilProperties.moisture
            self.assessment = "Moisture: \(String(format: "%.1f", soilProperties.moisture))% - \(SoilTestResult.moistureDescription(soilProperties.moisture))"
            
        case "Soil Thermometer":
            self.measuredTemperature = soilProperties.temperature
            self.assessment = "Temperature: \(String(format: "%.1f", soilProperties.temperature))°C - \(SoilTestResult.temperatureDescription(soilProperties.temperature))"
            
        case "Soil Probe":
            self.measuredCompaction = soilProperties.compaction
            self.assessment = "Compaction: \(String(format: "%.1f", soilProperties.compaction))% - \(SoilTestResult.compactionDescription(soilProperties.compaction))"
            
        case "NPK Test Kit":
            self.measuredNitrogen = soilProperties.nitrogen
            self.measuredPhosphorus = soilProperties.phosphorus
            self.measuredPotassium = soilProperties.potassium
            let avgNPK = (soilProperties.nitrogen + soilProperties.phosphorus + soilProperties.potassium) / 3.0
            self.assessment = "NPK - N:\(String(format: "%.0f", soilProperties.nitrogen)) P:\(String(format: "%.0f", soilProperties.phosphorus)) K:\(String(format: "%.0f", soilProperties.potassium)) - \(SoilTestResult.npkDescription(avgNPK))"
            
        default:
            self.assessment = "Basic soil analysis completed."
        }
    }
    
    private static func pHDescription(_ pH: Float) -> String {
        switch pH {
        case 0.0..<6.0: return "Acidic"
        case 6.0..<7.5: return "Ideal for most plants"
        case 7.5..<8.5: return "Slightly alkaline"
        default: return "Highly alkaline"
        }
    }
    
    private static func moistureDescription(_ moisture: Float) -> String {
        switch moisture {
        case 0.0..<20.0: return "Very dry"
        case 20.0..<40.0: return "Dry"
        case 40.0..<70.0: return "Good moisture"
        default: return "Very wet"
        }
    }
    
    private static func temperatureDescription(_ temp: Float) -> String {
        switch temp {
        case ..<10.0: return "Cold"
        case 10.0..<20.0: return "Cool"
        case 20.0..<30.0: return "Warm"
        default: return "Hot"
        }
    }
    
    private static func compactionDescription(_ compaction: Float) -> String {
        switch compaction {
        case 0.0..<30.0: return "Loose, well-aerated"
        case 30.0..<60.0: return "Moderately compact"
        default: return "Highly compacted"
        }
    }
    
    private static func npkDescription(_ avg: Float) -> String {
        switch avg {
        case 0.0..<30.0: return "Low nutrients"
        case 30.0..<60.0: return "Moderate nutrients"
        default: return "High nutrients"
        }
    }
}
