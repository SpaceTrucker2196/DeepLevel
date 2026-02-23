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
                return config.residentialFrequency / 4.0
            case .urban1, .urban2, .urban3:
                return config.urbanFrequency / 3.0
            case .redLight: return config.redLightFrequency
            case .retail: return config.retailFrequency
            }
        }
    }
    
    /// Generates a complete city map using the configured parameters.
    ///
    /// - Complexity: O(width * height)
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap {
        let width = config.width
        let height = config.height
        
        var tiles = Array(repeating: Tile(kind: .wall), count: width * height)
        var rooms: [Rect] = []
        
        generateCityGrid(config: config, rng: &rng, tiles: &tiles, rooms: &rooms)
        generateStreetsAndSidewalks(config: config, rng: &rng, tiles: &tiles, width: width, height: height)
        applyShadowEffects(config: config, tiles: &tiles, rooms: rooms, width: width, height: height)
        applyRedLightEffects(config: config, tiles: &tiles, width: width, height: height)
        
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
    private func generateCityGrid(config: DungeonConfig, rng: inout RandomNumberGenerator, tiles: inout [Tile], rooms: inout [Rect]) {
        let baseBlockSize = config.cityMapBlockSize
        let streetWidth = config.cityMapStreetWidth + 1 // include one sidewalk on top
        let gridSpacing = baseBlockSize + streetWidth
        
        let blocksX = (config.width - streetWidth) / gridSpacing
        let blocksY = (config.height - streetWidth) / gridSpacing
        
        let districtWeights = createDistrictWeights(config: config)
        
        for gridX in 0..<blocksX {
            for gridY in 0..<blocksY {
                let x = gridX * gridSpacing + streetWidth / 2
                let y = gridY * gridSpacing + streetWidth / 2
                
                let isTopHalf = gridY < blocksY / 2
                var blockWidth = isTopHalf ? config.cityMapBlockSizeTop : config.cityMapBlockSizeBottom
                var blockHeight = isTopHalf ? config.cityMapBlockSizeTop : config.cityMapBlockSizeBottom
                
                if config.enableTileScaling {
                    blockWidth = 4
                    blockHeight = 2
                }
                
                let cityBlock = Rect(x: x, y: y, w: blockWidth, h: blockHeight)
                
                if x + blockWidth < config.width && y + blockHeight < config.height {
                    let districtType = selectDistrictType(weights: districtWeights, rng: &rng)
                    carveDistrict(cityBlock, districtType: districtType, into: &tiles, width: config.width, config: config, rng: &rng)
                    rooms.append(cityBlock)
                }
            }
        }
    }
    
    private func createDistrictWeights(config: DungeonConfig) -> [(DistrictType, Double)] {
        DistrictType.allCases
            .map { ($0, $0.frequency(from: config)) }
            .filter { $0.1 > 0 }
    }
    
    private func selectDistrictType(weights: [(DistrictType, Double)], rng: inout RandomNumberGenerator) -> DistrictType {
        let totalWeight = weights.reduce(0.0) { $0 + $1.1 }
        let random = Double.random(in: 0..<totalWeight, using: &rng)
        var accumulated = 0.0
        for (district, weight) in weights {
            accumulated += weight
            if random < accumulated {
                return district
            }
        }
        return weights.first?.0 ?? .park
    }
    
    private func carveDistrict(_ block: Rect,
                               districtType: DistrictType,
                               into tiles: inout [Tile],
                               width: Int,
                               config: DungeonConfig,
                               rng: inout RandomNumberGenerator) {
        var actualTileKind = districtType.tileKind
        // FIX: Replaced invalid 'if case .urban1 = districtType || ...' that produced a Bool pattern error.
        if districtType == .urban1 || districtType == .urban2 || districtType == .urban3 {
            let urbanTypes: [TileKind] = [.urban1, .urban2, .urban3]
            actualTileKind = urbanTypes.randomElement(using: &rng) ?? .urban1
        }
        
        let shouldScale = config.enableTileScaling && shouldScaleDistrict(districtType)
        let scaleFactor = shouldScale ? config.tileScaleFactor : 1.0
        
        let height = tiles.count / width
        for y in block.y..<(block.y + block.h) {
            for x in block.x..<(block.x + block.w) {
                guard x >= 0, x < width, y >= 0, y < height else { continue }
                let idx = y * width + x
                tiles[idx].kind = actualTileKind
                tiles[idx].scale = scaleFactor
                
                // Add soil properties for park tiles
                if districtType == .park {
                    tiles[idx].soilProperties = SoilProperties()
                }
                
                if districtType == .park && Double.random(in: 0..<1, using: &rng) < 0.5 {
                    tiles[idx].kind = .hidingArea
                    tiles[idx].scale = 1.0
                    // Hiding areas in parks should also have soil properties
                    tiles[idx].soilProperties = SoilProperties()
                }
            }
        }
        
        if districtType == .park && Double.random(in: 0..<1, using: &rng) < 0.25 {
            let truckX = Int.random(in: block.x..<(block.x + block.w), using: &rng)
            let truckY = Int.random(in: block.y..<(block.y + block.h), using: &rng)
            let height = tiles.count / width
            if truckX >= 0, truckX < width, truckY >= 0, truckY < height {
                let idx = truckY * width + truckX
                tiles[idx].kind = .iceCreamTruck
                tiles[idx].scale = 1.0
            }
        }
    }
    
    private func shouldScaleDistrict(_ districtType: DistrictType) -> Bool {
        switch districtType {
        case .urban1, .urban2, .urban3,
             .residential1, .residential2, .residential3, .residential4,
             .redLight, .retail:
            return true
        case .park:
            return false
        }
    }
    
    /// Generates streets and sidewalks between city blocks.
    /// Sidewalks only appear on the top row of each horizontal street (acting as the bottom border of blocks above).
    /// Vertical streets have no sidewalks.
    private func generateStreetsAndSidewalks(config: DungeonConfig,
                                             rng: inout RandomNumberGenerator,
                                             tiles: inout [Tile],
                                             width: Int,
                                             height: Int) {
        let blockSize = config.cityMapBlockSize
        let streetWidth = config.cityMapStreetWidth
        let totalWidth = streetWidth + 1 // street + one sidewalk row
        let gridSpacing = blockSize + totalWidth
        
        let blocksX = (width - totalWidth) / gridSpacing
        let blocksY = (height - totalWidth) / gridSpacing
        
        // Horizontal streets
        for gridY in 0...blocksY {
            let streetCenterY = gridY * gridSpacing
            let streetStartY = streetCenterY - totalWidth / 2
            for y in streetStartY..<(streetStartY + totalWidth) {
                guard y >= 0, y < height else { continue }
                for x in 0..<width {
                    let idx = y * width + x
                    let offset = y - streetStartY
                    if offset == 0 {
                        tiles[idx].kind = chooseSidewalkType(rng: &rng)
                    } else {
                        tiles[idx].kind = .street
                    }
                }
            }
        }
        
        // Vertical streets (no sidewalks)
        for gridX in 0...blocksX {
            let streetCenterX = gridX * gridSpacing
            let streetStartX = streetCenterX - streetWidth / 2
            for x in streetStartX..<(streetStartX + streetWidth) {
                guard x >= 0, x < width else { continue }
                for y in 0..<height {
                    let idx = y * width + x
                    if tiles[idx].kind == .street {
                        tiles[idx].kind = .crosswalk
                        continue
                    }
                    if tiles[idx].kind.isSidewalk {
                        continue
                    }
                    if tiles[idx].kind != .crosswalk {
                        tiles[idx].kind = .street
                    }
                }
            }
        }
    }
    
    private func chooseSidewalkType(rng: inout RandomNumberGenerator) -> TileKind {
        let r = Double.random(in: 0..<1, using: &rng)
        if r < 0.1 { return .sidewalkTree }
        if r < 0.15 { return .sidewalkHydrant }
        return .sidewalk
    }
    
    private func applyShadowEffects(config: DungeonConfig,
                                    tiles: inout [Tile],
                                    rooms: [Rect],
                                    width: Int,
                                    height: Int) {
        for room in rooms {
            for y in (room.y - 1)...(room.y + room.h) {
                for x in (room.x - 1)...(room.x + room.w) {
                    guard x >= 0, x < width, y >= 0, y < height else { continue }
                    let idx = y * width + x
                    if tiles[idx].kind == .street || tiles[idx].kind.isSidewalk {
                        tiles[idx].colorCast = -0.3
                    }
                }
            }
        }
    }
    
    private func applyRedLightEffects(config: DungeonConfig,
                                      tiles: inout [Tile],
                                      width: Int,
                                      height: Int) {
        var redLightTiles: [(Int, Int)] = []
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if tiles[idx].kind == .redLight {
                    redLightTiles.append((x, y))
                }
            }
        }
        for (rx, ry) in redLightTiles {
            for dy in -1...1 {
                for dx in -1...1 {
                    let x = rx + dx
                    let y = ry + dy
                    guard x >= 0, x < width, y >= 0, y < height else { continue }
                    let idx = y * width + x
                    if tiles[idx].kind != .redLight {
                        tiles[idx].colorCast += 0.4
                    }
                }
            }
        }
    }
    
    private func findPlayerStart(tiles: [Tile], width: Int, height: Int) -> (Int, Int) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if tiles[idx].kind == .street || tiles[idx].kind.isSidewalk {
                    return (x, y)
                }
            }
        }
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if !tiles[idx].blocksMovement {
                    return (x, y)
                }
            }
        }
        return (1, 1)
    }
}
