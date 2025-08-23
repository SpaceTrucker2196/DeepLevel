import Foundation

/// Generates urban city maps with districts, streets, and detailed neighborhoods.
///
/// Creates complex urban environments with different district types including parks,
/// residential areas, urban zones, red light districts, and retail areas. Features
/// 2-tile wide streets with sidewalk borders, 10x10 city blocks, and advanced
/// lighting effects including shadows and red light district illumination.
///
/// - Since: 1.0.0
final class CityMapGenerator: DungeonGenerating {
    
    /// District types available for city blocks.
    private enum DistrictType: CaseIterable {
        case park
        case residential1, residential2, residential3, residential4
        case urban1, urban2, urban3
        case redLight
        case retail
        
        /// Convert district type to corresponding tile kind.
        var tileKind: TileKind {
            switch self {
            case .park: return .park
            case .residential1: return .residential1
            case .residential2: return .residential2
            case .residential3: return .residential3
            case .residential4: return .residential4
            case .urban1: return .urban1
            case .urban2: return .urban2
            case .urban3: return .urban3
            case .redLight: return .redLight
            case .retail: return .retail
            }
        }
        
        /// Get the frequency setting for this district type from config.
        func frequency(from config: DungeonConfig) -> Double {
            switch self {
            case .park: return config.parkFrequency
            case .residential1, .residential2, .residential3, .residential4:
                return config.residentialFrequency / 4.0 // Split equally among 4 types
            case .urban1, .urban2, .urban3:
                return config.urbanFrequency / 3.0 // Split equally among 3 types
            case .redLight: return config.redLightFrequency
            case .retail: return config.retailFrequency
            }
        }
    }
    
    /// Generates a complete city map using the configured parameters.
    ///
    /// Creates a grid-based urban environment with different district types,
    /// 2-tile wide streets bordered by varied sidewalks, and lighting effects.
    ///
    /// - Parameters:
    ///   - config: Configuration parameters for generation
    ///   - rng: Random number generator for deterministic generation
    /// - Returns: A complete city map ready for gameplay
    /// - Complexity: O(width * height)
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap {
        let width = config.width
        let height = config.height
        
        // Initialize map with walls
        var tiles = Array(repeating: Tile(kind: .wall), count: width * height)
        var rooms: [Rect] = []
        
        generateCityGrid(config: config, rng: &rng, tiles: &tiles, rooms: &rooms)
        generateStreetsAndSidewalks(config: config, rng: &rng, tiles: &tiles, width: width, height: height)
        applyShadowEffects(config: config, tiles: &tiles, rooms: rooms, width: width, height: height)
        applyRedLightEffects(config: config, tiles: &tiles, width: width, height: height)
        
        // Find a suitable player start position
        let playerStart = findPlayerStart(tiles: tiles, width: width, height: height)
        
        return DungeonMap(
            width: width,
            height: height,
            tiles: tiles,
            playerStart: playerStart,
            rooms: rooms
        )
    }
    
    /// Generates the city grid with different district types.
    ///
    /// Creates 10x10 city blocks arranged in a grid pattern, assigning district
    /// types based on configured frequencies.
    ///
    /// - Parameters:
    ///   - config: Generation configuration
    ///   - rng: Random number generator
    ///   - tiles: Tile array to modify
    ///   - rooms: Room array to populate
    private func generateCityGrid(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: inout [Rect]) {
        let baseBlockSize = config.cityMapBlockSize
        let streetWidth = config.cityMapStreetWidth + 1 // include one sidewalk on top
        let gridSpacing = baseBlockSize + streetWidth
        
        // Calculate how many blocks fit in each dimension
        let blocksX = (config.width - streetWidth) / gridSpacing
        let blocksY = (config.height - streetWidth) / gridSpacing
        
        // Create weighted district selection based on frequencies
        let districtWeights = createDistrictWeights(config: config)
        
        // Generate city blocks
        for gridX in 0..<blocksX {
            for gridY in 0..<blocksY {
                let x = gridX * gridSpacing + streetWidth / 2
                let y = gridY * gridSpacing + streetWidth / 2
                
                // Determine block size based on position (top half vs bottom half)
                let isTopHalf = gridY < blocksY / 2
                let blockSize = isTopHalf ? config.cityMapBlockSizeTop : config.cityMapBlockSizeBottom
                
                let cityBlock = Rect(x: x, y: y, w: blockSize, h: blockSize)
                
                // Ensure the block fits within bounds
                if x + blockSize < config.width && y + blockSize < config.height {
                    let districtType = selectDistrictType(weights: districtWeights, rng: &rng)
                    carveDistrict(cityBlock, districtType: districtType, into: &tiles, width: config.width, config: config, rng: &rng)
                    rooms.append(cityBlock)
                }
            }
        }
    }
    
    /// Creates weighted array for district selection based on frequencies.
    private func createDistrictWeights(config: DungeonConfig) -> [(DistrictType, Double)] {
        return DistrictType.allCases.map { district in
            (district, district.frequency(from: config))
        }.filter { $0.1 > 0 } // Remove districts with 0 frequency
    }
    
    /// Selects a district type based on weighted probabilities.
    private func selectDistrictType(weights: [(DistrictType, Double)], rng: inout RandomNumberGenerator) -> DistrictType {
        let totalWeight = weights.reduce(0.0) { $0 + $1.1 }
        let random = Double.random(in: 0..<totalWeight, using: &rng)
        
        var accumulatedWeight = 0.0
        for (district, weight) in weights {
            accumulatedWeight += weight
            if random < accumulatedWeight {
                return district
            }
        }
        
        // Fallback to first district if something goes wrong
        return weights.first?.0 ?? .park
    }
    
    /// Carves a city block with the specified district type.
    private func carveDistrict(_ block: Rect, districtType: DistrictType, into tiles: inout [Tile], width: Int, config: DungeonConfig, rng: inout RandomNumberGenerator) {
        let tileKind = districtType.tileKind
        
        for y in block.y..<(block.y + block.h) {
            for x in block.x..<(block.x + block.w) {
                if x >= 0 && x < width && y >= 0 && y < tiles.count / width {
                    let idx = y * width + x
                    tiles[idx].kind = tileKind
                    
                    // Add hiding spots to parks
                    if districtType == .park && Double.random(in: 0..<1, using: &rng) < 0.15 {
                        tiles[idx].kind = .hidingArea
                    }
                }
            }
        }
    }
    
    /// Generates streets and sidewalks between city blocks.
    /// Sidewalks only appear on the bottom border of city blocks (top part of horizontal streets).
    /// Vertical streets have no sidewalks.
    private func generateStreetsAndSidewalks(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], width: Int, height: Int) {
        let blockSize = config.cityMapBlockSize
        let streetWidth = config.cityMapStreetWidth
        let totalWidth = streetWidth + 1 // street + one sidewalk on top only
        let gridSpacing = blockSize + totalWidth
        
        let blocksX = (width - totalWidth) / gridSpacing
        let blocksY = (height - totalWidth) / gridSpacing
        
        // Generate horizontal streets with sidewalk only on top (bottom border of city blocks)
        for gridY in 0...blocksY {
            let streetCenterY = gridY * gridSpacing
            let streetStartY = streetCenterY - totalWidth / 2
            
            for y in streetStartY..<(streetStartY + totalWidth) {
                if y >= 0 && y < height {
                    for x in 0..<width {
                        let idx = y * width + x
                        
                        // Determine tile type based on position within street area
                        let offsetFromStart = y - streetStartY
                        if offsetFromStart == 0 {
                            // Sidewalk only on the top (bottom border of city blocks above)
                            tiles[idx].kind = chooseSidewalkType(rng: &rng)
                        } else {
                            // Street interior
                            tiles[idx].kind = .street
                        }
                    }
                }
            }
        }
        
        // Generate vertical streets with no sidewalks
        for gridX in 0...blocksX {
            let streetCenterX = gridX * gridSpacing
            let streetStartX = streetCenterX - streetWidth / 2
            
            for x in streetStartX..<(streetStartX + streetWidth) {
                if x >= 0 && x < width {
                    for y in 0..<height {
                        let idx = y * width + x
                        
                        // Skip if already processed as horizontal street or sidewalk
                        if tiles[idx].kind == .street || tiles[idx].kind.isSidewalk {
                            continue
                        }
                        
                        // Vertical streets have no sidewalks, only street tiles
                        tiles[idx].kind = .street
                    }
                }
            }
        }
    }
    
    /// Chooses a sidewalk type with variation (normal, tree, fire hydrant).
    private func chooseSidewalkType(rng: inout RandomNumberGenerator) -> TileKind {
        let random = Double.random(in: 0..<1, using: &rng)
        if random < 0.1 {
            return .sidewalkTree
        } else if random < 0.15 {
            return .sidewalkHydrant
        } else {
            return .sidewalk
        }
    }
    
    /// Applies shadow effects from city blocks to adjacent streets and sidewalks.
    private func applyShadowEffects(config: DungeonConfig, tiles: inout [Tile], rooms: [Rect], width: Int, height: Int) {
        for room in rooms {
            // Apply shadow to tiles adjacent to city blocks
            for y in (room.y - 1)...(room.y + room.h) {
                for x in (room.x - 1)...(room.x + room.w) {
                    if x >= 0 && x < width && y >= 0 && y < height {
                        let idx = y * width + x
                        
                        // Only apply shadow to street and sidewalk tiles
                        if tiles[idx].kind == .street || tiles[idx].kind.isSidewalk {
                            tiles[idx].colorCast = -0.3 // Shadow effect
                        }
                    }
                }
            }
        }
    }
    
    /// Applies red light effects from red light districts to adjacent tiles.
    private func applyRedLightEffects(config: DungeonConfig, tiles: inout [Tile], width: Int, height: Int) {
        // First pass: find all red light district tiles
        var redLightTiles: [(Int, Int)] = []
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if tiles[idx].kind == .redLight {
                    redLightTiles.append((x, y))
                }
            }
        }
        
        // Second pass: apply red light effect to adjacent tiles
        for (redX, redY) in redLightTiles {
            for dy in -1...1 {
                for dx in -1...1 {
                    let x = redX + dx
                    let y = redY + dy
                    
                    if x >= 0 && x < width && y >= 0 && y < height {
                        let idx = y * width + x
                        
                        // Apply red light effect (positive color cast for light)
                        if tiles[idx].kind != .redLight {
                            tiles[idx].colorCast += 0.4 // Red light effect
                        }
                    }
                }
            }
        }
    }
    
    /// Finds a suitable player start position on a walkable tile.
    private func findPlayerStart(tiles: [Tile], width: Int, height: Int) -> (Int, Int) {
        // Try to find a street or sidewalk tile
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if tiles[idx].kind == .street || tiles[idx].kind.isSidewalk {
                    return (x, y)
                }
            }
        }
        
        // Fallback to any walkable tile
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if !tiles[idx].blocksMovement {
                    return (x, y)
                }
            }
        }
        
        // Ultimate fallback
        return (1, 1)
    }
}

// MARK: - TileKind Extensions

private extension TileKind {
    /// Returns true if this tile kind is a sidewalk variant.
    var isSidewalk: Bool {
        switch self {
        case .sidewalk, .sidewalkTree, .sidewalkHydrant:
            return true
        default:
            return false
        }
    }
}
