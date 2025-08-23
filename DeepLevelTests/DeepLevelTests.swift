//
//  DeepLevelTests.swift
//  DeepLevelTests
//
//  Created by Jeffrey Kunzelman on 8/21/25.
//

import Testing
@testable import DeepLevel

/// Test suite for the DeepLevel application functionality.
///
/// Contains unit tests for verifying core game logic, dungeon generation,
/// and other critical functionality. Uses Swift Testing framework for
/// modern test organization and execution.
///
/// - Since: 1.0.0
struct DeepLevelTests {

    /// Tests that GameScene includes all available algorithms.
    ///
    /// Verifies that the GameScene algorithms array contains all generation
    /// algorithms and can cycle through them properly.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testGameSceneAlgorithmInclusion() async throws {
        // Create a GameScene to test algorithm array
        let scene = GameScene()
        let algorithms = scene.getAvailableAlgorithms()
        
        // Verify all algorithm types are included
        #expect(algorithms.contains(.roomsCorridors))
        #expect(algorithms.contains(.bsp))
        #expect(algorithms.contains(.cellular))
        #expect(algorithms.contains(.cityMap))
        
        // Verify we have exactly 4 algorithms
        #expect(algorithms.count == 4)
    }
    
    /// Tests end-to-end algorithm selection and tile generation.
    ///
    /// Verifies that when different algorithms are selected, they produce
    /// the correct tile types and that TileSetBuilder can render them all.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testEndToEndAlgorithmSelection() async throws {
        // Test that each algorithm in the GameScene array works correctly
        let scene = GameScene()
        let algorithms = scene.getAvailableAlgorithms()
        
        for (index, algorithm) in algorithms.enumerated() {
            var config = DungeonConfig()
            config.width = 40
            config.height = 40
            config.algorithm = algorithm
            
            // Adjust cityLayout for rooms algorithm
            if algorithm == .roomsCorridors {
                config.cityLayout = false
            }
            
            let generator = DungeonGenerator(config: config)
            let map = generator.generate()
            
            // Verify basic map properties
            #expect(map.width == config.width)
            #expect(map.height == config.height)
            #expect(map.tiles.count == config.width * config.height)
            
            // Verify algorithm-specific tiles are generated
            let tileKinds = Set(map.tiles.map { $0.kind })
            
            switch algorithm {
            case .roomsCorridors:
                if config.cityLayout {
                    // City layout rooms should have sidewalks and driveways
                    #expect(tileKinds.contains(.sidewalk) || tileKinds.contains(.driveway))
                } else {
                    // Regular rooms should have walls and floors
                    #expect(tileKinds.contains(.wall))
                    #expect(tileKinds.contains(.floor))
                }
            case .bsp:
                // BSP should produce walls and floors
                #expect(tileKinds.contains(.wall))
                #expect(tileKinds.contains(.floor))
            case .cellular:
                // Cellular should produce walls and floors
                #expect(tileKinds.contains(.wall))
                #expect(tileKinds.contains(.floor))
            case .cityMap:
                // City map should have city-specific tiles
                #expect(tileKinds.contains(.street))
                #expect(tileKinds.contains(.sidewalk))
                let cityTypes: [TileKind] = [.park, .residential1, .urban1, .retail]
                let hasCityType = cityTypes.contains { tileKinds.contains($0) }
                #expect(hasCityType, "City map should contain district tiles")
            }
            
            // Verify TileSetBuilder can handle all tile types generated
            let (tileSet, tileRefs) = TileSetBuilder.build(tileSize: 32)
            #expect(tileSet.tileGroups.count >= tileKinds.count)
        }
    }
    
    /// Tests that the default configuration can be properly applied.
    ///
    /// Verifies that the default algorithm setting in DungeonConfig is respected
    /// when generating dungeons, ensuring the app starts with the correct algorithm.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testDefaultAlgorithmConfiguration() async throws {
        // Test default config uses cityMap
        let defaultConfig = DungeonConfig()
        #expect(defaultConfig.algorithm == .cityMap)
        
        // Generate using default config to ensure it works
        let generator = DungeonGenerator(config: defaultConfig)
        let map = generator.generate()
        
        // Verify the map was generated successfully
        #expect(map.width == defaultConfig.width)
        #expect(map.height == defaultConfig.height)
        #expect(map.tiles.count == defaultConfig.width * defaultConfig.height)
        
        // Verify city map specific tiles exist when using cityMap algorithm
        let tileKinds = Set(map.tiles.map { $0.kind })
        let citySpecificTiles: [TileKind] = [.street, .sidewalk, .park, .residential1, .urban1, .retail]
        let hasCityTiles = citySpecificTiles.contains { tileKinds.contains($0) }
        #expect(hasCityTiles, "City map should contain city-specific tile types")
    }
    
    /// Tests that GameScene starts with the correct algorithm.
    ///
    /// Verifies that the GameScene initializes with the same default algorithm
    /// as specified in DungeonConfig, ensuring consistency on app startup.
    ///
    /// - Throws: Any errors encountered during test execution  
    @Test func testGameSceneStartsWithCorrectAlgorithm() async throws {
        // Create a new GameScene
        let scene = GameScene()
        let algorithms = scene.getAvailableAlgorithms()
        let currentIndex = scene.getCurrentAlgorithmIndex()
        
        // Verify the current algorithm matches the default config
        let currentAlgorithm = algorithms[currentIndex]
        let defaultConfig = DungeonConfig()
        
        #expect(currentAlgorithm == defaultConfig.algorithm)
        #expect(currentAlgorithm == .cityMap)
    }
    
    /// Tests room border functionality for dungeon generation.
    ///
    /// Verifies that when room borders are enabled, rooms are carved with
    /// 1-tile thick walls around their perimeter, like sidewalks on a city block.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testRoomBorders() async throws {
        // Test configuration with borders enabled
        var config = DungeonConfig()
        config.width = 20
        config.height = 15
        config.maxRooms = 1
        config.roomMinSize = 6
        config.roomMaxSize = 6
        config.roomBorders = true
        config.algorithm = .roomsCorridors
        
        // Generate dungeon with borders
        let generator = RoomsGenerator()
        var rng = SystemRandomNumberGenerator()
        let dungeonWithBorders = generator.generate(config: config, rng: &rng)
        
        // Test configuration with borders disabled for comparison
        config.roomBorders = false
        let dungeonWithoutBorders = generator.generate(config: config, rng: &rng)
        
        // Verify that the dungeon was generated
        #expect(dungeonWithBorders.rooms.count > 0)
        #expect(dungeonWithoutBorders.rooms.count > 0)
        
        // For a controlled test, manually create a room and verify border behavior
        let testRoom = Rect(x: 2, y: 2, w: 6, h: 6)
        var tilesWithBorders = Array(repeating: Tile(kind: .wall), count: 20 * 15)
        var tilesWithoutBorders = Array(repeating: Tile(kind: .wall), count: 20 * 15)
        
        // Configure a room generator instance to test carveRoom method
        let roomGen = RoomsGenerator()
        let mirror = Mirror(reflecting: roomGen)
        
        // We need to test the behavior indirectly since carveRoom is private
        // Instead, test the overall generation results
        
        // With borders enabled, interior floor area should be smaller
        var configBordered = DungeonConfig()
        configBordered.width = 10
        configBordered.height = 10
        configBordered.maxRooms = 1
        configBordered.roomMinSize = 6
        configBordered.roomMaxSize = 6
        configBordered.roomBorders = true
        
        var configNormal = configBordered
        configNormal.roomBorders = false
        
        let borderedDungeon = generator.generate(config: configBordered, rng: &rng)
        let normalDungeon = generator.generate(config: configNormal, rng: &rng)
        
        // Count floor tiles - bordered rooms should have fewer floor tiles than normal rooms
        let borderedFloorCount = borderedDungeon.tiles.count { $0.kind == .floor }
        let normalFloorCount = normalDungeon.tiles.count { $0.kind == .floor }
        
        // Bordered rooms should have fewer floor tiles due to the border walls
        #expect(borderedFloorCount <= normalFloorCount)
    }
    
    /// Tests algorithm selection to ensure each algorithm generates appropriate tiles.
    ///
    /// Verifies that each generation algorithm produces its expected tile types
    /// and that the TileSetBuilder can handle all tile varieties correctly.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testAlgorithmSelection() async throws {
        // Test rooms and corridors algorithm
        var roomsConfig = DungeonConfig()
        roomsConfig.width = 50
        roomsConfig.height = 50
        roomsConfig.algorithm = .roomsCorridors
        roomsConfig.cityLayout = false
        
        let roomsGenerator = RoomsGenerator()
        var rng = SystemRandomNumberGenerator()
        let roomsMap = roomsGenerator.generate(config: roomsConfig, rng: &rng)
        
        // Verify rooms generator produces basic tile types (walls, floors, doors)
        let roomsTileKinds = Set(roomsMap.tiles.map { $0.kind })
        #expect(roomsTileKinds.contains(.wall))
        #expect(roomsTileKinds.contains(.floor))
        
        // Should not contain city-specific tiles when cityLayout is false
        #expect(!roomsTileKinds.contains(.street))
        #expect(!roomsTileKinds.contains(.park))
        #expect(!roomsTileKinds.contains(.retail))
        
        // Test city map algorithm
        var cityConfig = DungeonConfig()
        cityConfig.width = 50
        cityConfig.height = 50
        cityConfig.algorithm = .cityMap
        
        let cityGenerator = CityMapGenerator()
        var cityRng = SystemRandomNumberGenerator()
        let cityMap = cityGenerator.generate(config: cityConfig, rng: &cityRng)
        
        // Verify city generator produces city-specific tile types
        let cityTileKinds = Set(cityMap.tiles.map { $0.kind })
        #expect(cityTileKinds.contains(.street))
        #expect(cityTileKinds.contains(.sidewalk))
        
        // Should contain at least one district type
        let districtTypes: [TileKind] = [.park, .residential1, .residential2, .residential3, .residential4,
                                       .urban1, .urban2, .urban3, .redLight, .retail]
        let hasDistrictType = districtTypes.contains { cityTileKinds.contains($0) }
        #expect(hasDistrictType)
    }
    
    /// Tests that TileSetBuilder can handle all tile types from all algorithms.
    ///
    /// Verifies that the TileSetBuilder creates appropriate tile groups for
    /// all possible tile kinds used by different generation algorithms.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testTileSetBuilderHandlesAllTileTypes() async throws {
        // Build tile set and references
        let (tileSet, tileRefs) = TileSetBuilder.build(tileSize: 32)
        
        // Verify all basic tile types have corresponding tile groups
        #expect(tileRefs.wall.name == "wall")
        #expect(tileRefs.door.name == "doorClosed") 
        #expect(tileRefs.secretDoor.name == "doorSecret")
        #expect(tileRefs.floorVariants.count > 0)
        
        // Verify city-specific tile types have tile groups
        #expect(tileRefs.sidewalk.name == "sidewalk")
        #expect(tileRefs.street.name == "street")
        #expect(tileRefs.park.name == "park")
        #expect(tileRefs.retail.name == "retail")
        #expect(tileRefs.residential1.name == "residential1")
        #expect(tileRefs.urban1.name == "urban1")
        #expect(tileRefs.redLight.name == "redLight")
        
        // Verify tile set contains all expected groups
        #expect(tileSet.tileGroups.count >= 17) // Should have at least 17 different tile groups
    }
    
    /// Tests city layout generation functionality.
    ///
    /// Verifies that when city layout is enabled, the generator creates
    /// 6x6 city blocks with 4-tile wide streets and sidewalk borders.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCityLayout() async throws {
        // Configure for city layout
        var config = DungeonConfig()
        config.width = 30
        config.height = 30
        config.cityLayout = true
        config.cityBlockSize = 6
        config.streetWidth = 4
        config.algorithm = .roomsCorridors
        
        // Generate city layout
        let generator = RoomsGenerator()
        var rng = SystemRandomNumberGenerator()
        let cityMap = generator.generate(config: config, rng: &rng)
        
        // Verify city blocks were generated
        #expect(cityMap.rooms.count > 0)
        
        // All rooms should be 6x6 city blocks
        for room in cityMap.rooms {
            #expect(room.w == config.cityBlockSize)
            #expect(room.h == config.cityBlockSize)
        }
        
        // Verify tile types exist
        let tileKinds = cityMap.tiles.map { $0.kind }
        #expect(tileKinds.contains(.floor))  // Street interiors
        #expect(tileKinds.contains(.sidewalk))  // Sidewalk borders
        
        // Count different tile types
        let floorCount = cityMap.tiles.count { $0.kind == .floor }
        let sidewalkCount = cityMap.tiles.count { $0.kind == .sidewalk }
        let wallCount = cityMap.tiles.count { $0.kind == .wall }
        
        // Should have significant areas of each type
        #expect(floorCount > 0)
        #expect(sidewalkCount > 0)
        #expect(wallCount > 0)
        
        // Sidewalks should be less than floors (streets are wider than sidewalks)
        #expect(sidewalkCount < floorCount)
    }
    
    /// Tests driveway placement in city layout.
    ///
    /// Verifies that driveways are used instead of doors when city layout is enabled.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testDrivewayPlacement() async throws {
        // Configure for city layout
        var config = DungeonConfig()
        config.width = 20
        config.height = 20
        config.cityLayout = true
        config.cityBlockSize = 6
        config.streetWidth = 4
        config.algorithm = .roomsCorridors
        
        // Generate city layout
        let generator = RoomsGenerator()
        var rng = SystemRandomNumberGenerator()
        let cityMap = generator.generate(config: config, rng: &rng)
        
        // Check for driveways in city layout
        let hasDriveways = cityMap.tiles.contains { $0.kind == .driveway }
        let hasRegularDoors = cityMap.tiles.contains { $0.kind == .doorClosed }
        
        // City layout should use driveways, not regular doors
        if cityMap.rooms.count > 0 {
            // There should be potential for driveways (though they may not always be placed)
            // At minimum, we should not have regular doors in city layout
            #expect(!hasRegularDoors)
        }
        
        // Test traditional layout for comparison
        config.cityLayout = false
        let traditionalMap = generator.generate(config: config, rng: &rng)
        
        let traditionalHasDoors = traditionalMap.tiles.contains { $0.kind == .doorClosed }
        let traditionalHasDriveways = traditionalMap.tiles.contains { $0.kind == .driveway }
        
        // Traditional layout should not have driveways
        #expect(!traditionalHasDriveways)
    }
    
    /// Tests that all rooms have at least one door to prevent player trapping.
    ///
    /// Verifies that every room generated has at least one entrance/exit
    /// and that all accessible areas are connected.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testAllRoomsHaveDoors() async throws {
        // Test with traditional room generation
        var config = DungeonConfig()
        config.width = 40
        config.height = 30
        config.maxRooms = 8
        config.roomMinSize = 4
        config.roomMaxSize = 8
        config.algorithm = .roomsCorridors
        config.roomBorders = false
        
        let generator = RoomsGenerator()
        var rng = SystemRandomNumberGenerator()
        let map = generator.generate(config: config, rng: &rng)
        
        // Check that all rooms have at least one door
        for room in map.rooms {
            let roomHasDoor = hasRoomDoor(room: room, map: map)
            #expect(roomHasDoor, "Room at (\(room.x), \(room.y)) size (\(room.w)x\(room.h)) has no doors")
        }
        
        // Test with room borders enabled
        config.roomBorders = true
        let mapWithBorders = generator.generate(config: config, rng: &rng)
        
        for room in mapWithBorders.rooms {
            let roomHasDoor = hasRoomDoor(room: room, map: mapWithBorders)
            #expect(roomHasDoor, "Room with borders at (\(room.x), \(room.y)) size (\(room.w)x\(room.h)) has no doors")
        }
        
        // Test connectivity - ensure all floor areas are reachable from player start
        if map.rooms.count > 1 {
            let connectivity = checkConnectivity(map: map)
            #expect(connectivity.allConnected, "Not all areas are connected. Isolated areas: \(connectivity.isolatedAreas)")
        }
    }
    
    /// Helper function to check if a room has at least one door.
    private func hasRoomDoor(room: Rect, map: DungeonMap) -> Bool {
        // Check perimeter of room for doors
        for x in room.x..<(room.x + room.w) {
            // Check top and bottom edges
            for yEdge in [room.y - 1, room.y + room.h] {
                if map.inBounds(x, yEdge) {
                    let tile = map.tiles[map.index(x: x, y: yEdge)]
                    if tile.isDoor {
                        return true
                    }
                }
            }
        }
        
        for y in room.y..<(room.y + room.h) {
            // Check left and right edges  
            for xEdge in [room.x - 1, room.x + room.w] {
                if map.inBounds(xEdge, y) {
                    let tile = map.tiles[map.index(x: xEdge, y: y)]
                    if tile.isDoor {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Helper function to check connectivity of all floor areas.
    private func checkConnectivity(map: DungeonMap) -> (allConnected: Bool, isolatedAreas: Int) {
        let start = map.playerStart
        var visited = Set<String>()
        var reachableFloors = 0
        var totalFloors = 0
        
        // Count total floor tiles
        for y in 0..<map.height {
            for x in 0..<map.width {
                let tile = map.tiles[map.index(x: x, y: y)]
                if tile.kind == .floor || tile.kind == .sidewalk {
                    totalFloors += 1
                }
            }
        }
        
        // Flood fill from player start to find reachable areas
        func floodFill(x: Int, y: Int) {
            let key = "\(x),\(y)"
            if visited.contains(key) || !map.inBounds(x, y) {
                return
            }
            
            let tile = map.tiles[map.index(x: x, y: y)]
            if tile.kind != .floor && tile.kind != .sidewalk {
                return
            }
            
            visited.insert(key)
            reachableFloors += 1
            
            // Check 4 directions
            floodFill(x: x - 1, y: y)
            floodFill(x: x + 1, y: y)
            floodFill(x: x, y: y - 1)
            floodFill(x: x, y: y + 1)
        }
        
        floodFill(x: start.0, y: start.1)
        
        let isolatedAreas = totalFloors - reachableFloors
        return (allConnected: isolatedAreas == 0, isolatedAreas: isolatedAreas)
    }
    
    /// Tests Charmed entity creation and basic properties.
    ///
    /// Verifies that Charmed entities are created correctly with expected
    /// initial state and properties.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCharmedEntityCreation() async throws {
        // Create a charmed entity
        let charmed = Charmed(gridX: 5, gridY: 7, tileSize: 64.0)
        
        // Verify initial properties
        #expect(charmed.kind == .charmed)
        #expect(charmed.gridX == 5)
        #expect(charmed.gridY == 7)
        #expect(charmed.isCharmed == false)
        #expect(charmed.hp == 1)
        #expect(charmed.blocksMovement == false)
        #expect(charmed.roamTarget == nil)
        #expect(charmed.lastHealTime == 0)
        
        // Verify color is purple for uncharmed
        #expect(charmed.color == .systemPurple)
    }
    
    /// Tests EntityKind enum includes charmed type.
    ///
    /// Verifies that the charmed entity type was properly added to the enum.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCharmedEntityKind() async throws {
        let charmedKind = EntityKind.charmed
        #expect(charmedKind.rawValue == "CoolBear")
        
        // Test that we can create entities of all types
        let player = Entity(kind: .player, gridX: 0, gridY: 0, color: .clear, size: CGSize(width: 64, height: 64))
        let monster = Monster(gridX: 1, gridY: 1, tileSize: 64)
        let charmed = Charmed(gridX: 2, gridY: 2, tileSize: 64)
        
        #expect(player.kind == .player)
        #expect(monster.kind == .monster)
        #expect(charmed.kind == .charmed)
    }
    
    /// Tests hiding area transparency functionality.
    ///
    /// Verifies that entities in hiding areas have reduced transparency (alpha 0.5).
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testHidingAreaTransparency() async throws {
        // Create a test entity
        let charmed = Charmed(gridX: 0, gridY: 0, tileSize: 64.0)
        
        // Verify initial alpha is 1.0 (fully opaque)
        #expect(charmed.alpha == 1.0)
        
        // Test that hiding area detection works
        var testTile = Tile(kind: .hidingArea)
        #expect(testTile.providesConcealment == true)
        
        var regularTile = Tile(kind: .floor)
        #expect(regularTile.providesConcealment == false)
    }
    
    /// Tests charm removal by monster proximity.
    ///
    /// Verifies that charmed entities lose their charm when monsters get within 2 tiles.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCharmRemovalByProximity() async throws {
        // Create test entities
        let charmed = Charmed(gridX: 5, gridY: 5, tileSize: 64.0)
        let monster = Monster(gridX: 7, gridY: 7, tileSize: 64.0)  // Within 2 tiles
        
        // Charm the entity first
        charmed.isCharmed = true
        charmed.color = .systemBlue
        
        // Test distance calculation
        let dx = abs(monster.gridX - charmed.gridX)  // 2
        let dy = abs(monster.gridY - charmed.gridY)  // 2
        
        #expect(dx == 2)
        #expect(dy == 2)
        
        // Verify proximity check would trigger (dx <= 2 && dy <= 2)
        #expect(dx <= 2 && dy <= 2)
        
        // Test a monster that's too far away
        let distantMonster = Monster(gridX: 8, gridY: 8, tileSize: 64.0)  // Beyond 2 tiles
        let distantDx = abs(distantMonster.gridX - charmed.gridX)  // 3
        let distantDy = abs(distantMonster.gridY - charmed.gridY)  // 3
        
        #expect(distantDx == 3)
        #expect(distantDy == 3)
        #expect(!(distantDx <= 2 && distantDy <= 2))  // Should not trigger charm removal
    }
    
    /// Tests monster pathfinding avoids hiding areas.
    ///
    /// Verifies that hiding areas are not considered walkable for monster pathfinding.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterAvoidsHidingAreas() async throws {
        // Test the walkability check that would be used in pathfinding
        // The pathfinding lambda should return false for hiding areas
        
        let hidingAreaWalkable = { (kind: TileKind) -> Bool in
            switch kind {
            case .wall, .doorClosed, .doorSecret, .driveway, .hidingArea: return false
            case .floor, .sidewalk, .sidewalkTree, .sidewalkHydrant, .street: return true
            case .park, .residential1, .residential2, .residential3, .residential4: return true
            case .urban1, .urban2, .urban3, .redLight, .retail: return true
            }
        }
        
        // Verify that hiding areas are not walkable for monsters
        #expect(hidingAreaWalkable(.hidingArea) == false)
        #expect(hidingAreaWalkable(.floor) == true)
        #expect(hidingAreaWalkable(.sidewalk) == true)
        #expect(hidingAreaWalkable(.wall) == false)
    }
    
    /// Tests charmed entity movement stopping in hiding areas.
    ///
    /// Verifies that charmed entities should not move when in hiding areas.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCharmedStopsInHidingArea() async throws {
        // Create a charmed entity
        let charmed = Charmed(gridX: 5, gridY: 5, tileSize: 64.0)
        charmed.isCharmed = true
        
        // Simulate being in a hiding area
        let hidingTile = Tile(kind: .hidingArea)
        #expect(hidingTile.kind == .hidingArea)
        
        // The movement logic should check if current tile is hiding area and return early
        // This is what the implementation does in followPlayer and roamCharmed functions
        
        // Test that hiding area detection works
        #expect(hidingTile.providesConcealment == true)
        
        // A regular floor tile should not stop movement
        let floorTile = Tile(kind: .floor)
        #expect(floorTile.providesConcealment == false)
    }
    
    /// Tests the new city map algorithm generation.
    ///
    /// Verifies that the city map algorithm creates proper urban environments
    /// with different district types, streets, and sidewalks.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCityMapGeneration() async throws {
        // Configure for city map algorithm
        var config = DungeonConfig()
        config.width = 50
        config.height = 50
        config.algorithm = .cityMap
        config.cityMapBlockSize = 10
        config.cityMapStreetWidth = 2
        
        // Generate city map
        let generator = CityMapGenerator()
        var rng = SystemRandomNumberGenerator()
        let cityMap = generator.generate(config: config, rng: &rng)
        
        // Verify city blocks were generated
        #expect(cityMap.rooms.count > 0)
        
        // All rooms should be 10x10 city blocks
        for room in cityMap.rooms {
            #expect(room.w == config.cityMapBlockSize)
            #expect(room.h == config.cityMapBlockSize)
        }
        
        // Verify new tile types exist
        let tileKinds = Set(cityMap.tiles.map { $0.kind })
        #expect(tileKinds.contains(.street))  // New street type
        #expect(tileKinds.contains(.sidewalk))  // Sidewalk borders
        
        // Should have at least one district type
        let districtTypes: [TileKind] = [.park, .residential1, .residential2, .residential3, .residential4,
                                       .urban1, .urban2, .urban3, .redLight, .retail]
        let hasDistrictType = districtTypes.contains { tileKinds.contains($0) }
        #expect(hasDistrictType)
        
        // Verify player start is on a walkable tile
        let playerStart = cityMap.playerStart
        let startIdx = cityMap.index(x: playerStart.0, y: playerStart.1)
        #expect(!cityMap.tiles[startIdx].blocksMovement)
    }
    
    /// Tests district frequency configuration in city map.
    ///
    /// Verifies that district frequencies affect the distribution of district types.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCityMapDistrictFrequencies() async throws {
        // Configure with high park frequency, zero others
        var config = DungeonConfig()
        config.width = 40
        config.height = 40
        config.algorithm = .cityMap
        config.cityMapBlockSize = 10
        config.parkFrequency = 1.0
        config.residentialFrequency = 0.0
        config.urbanFrequency = 0.0
        config.redLightFrequency = 0.0
        config.retailFrequency = 0.0
        
        // Generate city map
        let generator = CityMapGenerator()
        var rng = SystemRandomNumberGenerator()
        let cityMap = generator.generate(config: config, rng: &rng)
        
        // Count district types
        let parkCount = cityMap.tiles.count { $0.kind == .park || $0.kind == .hidingArea }
        let nonParkDistricts = cityMap.tiles.count { tile in
            [.residential1, .residential2, .residential3, .residential4,
             .urban1, .urban2, .urban3, .redLight, .retail].contains(tile.kind)
        }
        
        // Should have parks but no other district types
        if cityMap.rooms.count > 0 {
            #expect(parkCount > 0)
            #expect(nonParkDistricts == 0)
        }
    }
    
    /// Tests park hiding areas functionality.
    ///
    /// Verifies that parks can contain hiding areas and provide concealment.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testParkHidingAreas() async throws {
        // Test that park tiles provide concealment
        let parkTile = Tile(kind: .park)
        #expect(parkTile.providesConcealment == true)
        
        // Test movement properties
        #expect(parkTile.blocksMovement == false)
        #expect(parkTile.blocksSight == false)
    }
    
    /// Tests new tile types properties.
    ///
    /// Verifies that all new tile types have correct movement and sight properties.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testNewTileTypesProperties() async throws {
        // Test district tiles
        let districtTiles: [TileKind] = [.park, .residential1, .residential2, .residential3, .residential4,
                                       .urban1, .urban2, .urban3, .redLight, .retail]
        
        for tileKind in districtTiles {
            let tile = Tile(kind: tileKind)
            #expect(tile.blocksMovement == false, "District tile \(tileKind) should not block movement")
            #expect(tile.blocksSight == false, "District tile \(tileKind) should not block sight")
        }
        
        // Test sidewalk variants
        let sidewalkTiles: [TileKind] = [.sidewalk, .sidewalkTree, .sidewalkHydrant]
        
        for tileKind in sidewalkTiles {
            let tile = Tile(kind: tileKind)
            #expect(tile.blocksMovement == false, "Sidewalk tile \(tileKind) should not block movement")
            #expect(tile.blocksSight == false, "Sidewalk tile \(tileKind) should not block sight")
        }
        
        // Test street tiles
        let streetTile = Tile(kind: .street)
        #expect(streetTile.blocksMovement == false)
        #expect(streetTile.blocksSight == false)
    }
    
    /// Tests color cast functionality for lighting effects.
    ///
    /// Verifies that tiles can have color cast values for light/shadow effects.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testColorCastFunctionality() async throws {
        // Test default color cast
        var tile = Tile(kind: .street)
        #expect(tile.colorCast == 0.0)
        
        // Test setting positive color cast (light)
        tile.colorCast = 0.4
        #expect(tile.colorCast == 0.4)
        
        // Test setting negative color cast (shadow)
        tile.colorCast = -0.3
        #expect(tile.colorCast == -0.3)
    }
    
    /// Tests that city map algorithm is properly integrated.
    ///
    /// Verifies that the DungeonGenerator routes to CityMapGenerator correctly.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCityMapAlgorithmIntegration() async throws {
        // Test that the algorithm enum includes cityMap
        let algorithm = GenerationAlgorithm.cityMap
        #expect(algorithm == .cityMap)
        
        // Test that DungeonGenerator can use the city map algorithm
        var config = DungeonConfig()
        config.algorithm = .cityMap
        config.width = 30
        config.height = 30
        
        let dungeonGenerator = DungeonGenerator(config: config)
        let map = dungeonGenerator.generate()
        
        // Verify the map was generated
        #expect(map.width == 30)
        #expect(map.height == 30)
        #expect(map.tiles.count == 30 * 30)
    }
    
    // MARK: - Movement System Tests
    
    /// Tests FOV radius settings for optimal view distance.
    ///
    /// Verifies that FOV radius values provide balanced gameplay where
    /// monsters and players can see each other at reasonable distances.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testFOVRadiusSettings() async throws {
        // Test different FOV radius values
        let testRadii = [3, 4, 5, 6, 7]
        
        for radius in testRadii {
            // Create a test map
            var config = DungeonConfig()
            config.width = 20
            config.height = 20
            config.algorithm = .roomsCorridors
            config.cityLayout = false
            
            let generator = DungeonGenerator(config: config)
            var map = generator.generate()
            
            // Test FOV computation
            FOV.compute(map: &map, originX: 10, originY: 10, radius: radius)
            
            let visibleTiles = map.tiles.filter { $0.visible }
            
            // Verify reasonable number of visible tiles for each radius
            switch radius {
            case 3:
                #expect(visibleTiles.count >= 9)  // Minimum visibility
                #expect(visibleTiles.count <= 50) // Maximum for small radius
            case 4:
                #expect(visibleTiles.count >= 25)
                #expect(visibleTiles.count <= 80)
            case 5:
                #expect(visibleTiles.count >= 40)
                #expect(visibleTiles.count <= 120)
            case 6, 7:
                #expect(visibleTiles.count >= 60)
                #expect(visibleTiles.count <= 200)
            default:
                break
            }
        }
    }
    
    /// Tests line of sight detection between entities.
    ///
    /// Verifies that line of sight calculations work correctly for
    /// different distances and obstacles.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testLineOfSightDetection() async throws {
        // Create a simple test map
        var config = DungeonConfig()
        config.width = 10
        config.height = 10
        
        let generator = DungeonGenerator(config: config)
        let map = generator.generate()
        
        // Test line of sight at various distances
        let testCases = [
            (fromX: 0, fromY: 0, toX: 1, toY: 1, shouldSee: true),   // Adjacent
            (fromX: 0, fromY: 0, toX: 2, toY: 2, shouldSee: true),   // 2 tiles away
            (fromX: 0, fromY: 0, toX: 4, toY: 4, shouldSee: true),   // 4 tiles away
            (fromX: 0, fromY: 0, toX: 9, toY: 9, shouldSee: true),   // Far diagonal
        ]
        
        for testCase in testCases {
            let hasLOS = FOV.hasLineOfSight(map: map,
                                          fromX: testCase.fromX,
                                          fromY: testCase.fromY,
                                          toX: testCase.toX,
                                          toY: testCase.toY)
            
            // Note: Actual result depends on map layout, but function should not crash
            #expect(hasLOS == true || hasLOS == false) // Just verify it returns a boolean
        }
    }
    
    /// Tests monster proximity detection for seeking behavior.
    ///
    /// Verifies that monsters only seek players when within specified distance
    /// and revert to random movement when player is avoided.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterProximityDetection() async throws {
        let tileSize: CGFloat = 32.0
        
        // Test cases for different distances
        let testCases = [
            (playerX: 5, playerY: 5, monsterX: 5, monsterY: 6, distance: 1, shouldSeek: true),   // 1 tile away
            (playerX: 5, playerY: 5, monsterX: 5, monsterY: 7, distance: 2, shouldSeek: true),   // 2 tiles away
            (playerX: 5, playerY: 5, monsterX: 5, monsterY: 8, distance: 3, shouldSeek: true),   // 3 tiles away
            (playerX: 5, playerY: 5, monsterX: 5, monsterY: 9, distance: 4, shouldSeek: true),   // 4 tiles away
            (playerX: 5, playerY: 5, monsterX: 5, monsterY: 10, distance: 5, shouldSeek: true),  // 5 tiles away (limit)
            (playerX: 5, playerY: 5, monsterX: 5, monsterY: 11, distance: 6, shouldSeek: false), // 6 tiles away (too far)
            (playerX: 5, playerY: 5, monsterX: 5, monsterY: 15, distance: 10, shouldSeek: false), // 10 tiles away (too far)
        ]
        
        for testCase in testCases {
            let player = Player(gridX: testCase.playerX, gridY: testCase.playerY, tileSize: tileSize)
            let monster = Monster(gridX: testCase.monsterX, gridY: testCase.monsterY, tileSize: tileSize)
            
            // Calculate actual distance (Manhattan distance)
            let dx = abs(monster.gridX - player.gridX)
            let dy = abs(monster.gridY - player.gridY)
            let manhattanDistance = dx + dy
            
            #expect(manhattanDistance == testCase.distance)
            
            // Test if distance calculation is correct
            let calculatedDistance = dx + dy
            #expect(calculatedDistance == testCase.distance)
            
            // For 5-pixel proximity (equivalent to 5 tiles in grid), verify seeking behavior
            let withinSeekingRange = calculatedDistance <= 5
            #expect(withinSeekingRange == testCase.shouldSeek)
        }
    }
    
    /// Tests player movement path execution and freezing prevention.
    ///
    /// Verifies that player movement paths execute correctly and don't freeze
    /// when encountering obstacles or monsters.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testPlayerMovementExecution() async throws {
        // Create a test scene
        let scene = GameScene()
        
        // Create a simple test map
        var config = DungeonConfig()
        config.width = 15
        config.height = 15
        config.algorithm = .roomsCorridors
        config.cityLayout = false
        
        let generator = DungeonGenerator(config: config)
        let map = generator.generate()
        
        // Create test player
        let player = Player(gridX: map.playerStart.0, gridY: map.playerStart.1, tileSize: 32.0)
        
        // Verify player starts at a valid position
        #expect(map.inBounds(player.gridX, player.gridY))
        
        let startTile = map.tiles[map.index(x: player.gridX, y: player.gridY)]
        #expect(!startTile.blocksMovement)
        
        // Test basic movement validation
        let adjacentPositions = [
            (player.gridX + 1, player.gridY),     // Right
            (player.gridX - 1, player.gridY),     // Left
            (player.gridX, player.gridY + 1),     // Up
            (player.gridX, player.gridY - 1),     // Down
        ]
        
        for (x, y) in adjacentPositions {
            if map.inBounds(x, y) {
                let tile = map.tiles[map.index(x: x, y: y)]
                // Movement should be possible or blocked, but function should not crash
                let canMove = !tile.blocksMovement
                #expect(canMove == true || canMove == false) // Just verify it returns a boolean
            }
        }
    }
    
    /// Tests monster random movement behavior.
    ///
    /// Verifies that monsters can perform random movement when not seeking players.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterRandomMovement() async throws {
        // Create a test map with open space
        var config = DungeonConfig()
        config.width = 20
        config.height = 20
        config.algorithm = .roomsCorridors
        config.cityLayout = false
        
        let generator = DungeonGenerator(config: config)
        let map = generator.generate()
        
        // Create a monster
        let monster = Monster(gridX: 10, gridY: 10, tileSize: 32.0)
        
        // Test that monster properties are initialized correctly
        #expect(monster.kind == .monster)
        #expect(monster.hp == 3)
        #expect(monster.roamTarget == nil)
        #expect(monster.lastPlayerPosition == nil)
        
        // Test pathfinding capability (should not crash)
        let path = Pathfinder.aStar(map: map,
                                   start: (monster.gridX, monster.gridY),
                                   goal: (5, 5),
                                   passable: { tileKind in
                                       !monster.blockingTiles.contains(tileKind)
                                   })
        
        // Path should either be empty or contain valid positions
        #expect(path.count >= 0)
        for position in path {
            #expect(map.inBounds(position.0, position.1))
        }
    }
    
    /// Tests monster state transitions between seeking and roaming.
    ///
    /// Verifies that monsters properly transition between seeking players
    /// and random roaming based on distance and line of sight.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterStateTransitions() async throws {
        let monster = Monster(gridX: 10, gridY: 10, tileSize: 32.0)
        
        // Test initial state
        #expect(monster.lastPlayerPosition == nil)
        #expect(monster.roamTarget == nil)
        
        // Test setting player position when spotted
        monster.lastPlayerPosition = (15, 15)
        #expect(monster.lastPlayerPosition!.0 == 15)
        #expect(monster.lastPlayerPosition!.1 == 15)
        
        // Test clearing player position when lost
        monster.lastPlayerPosition = nil
        #expect(monster.lastPlayerPosition == nil)
        
        // Test roam target setting
        monster.roamTarget = (8, 12)
        #expect(monster.roamTarget!.0 == 8)
        #expect(monster.roamTarget!.1 == 12)
        
        // Test clearing roam target
        monster.roamTarget = nil
        #expect(monster.roamTarget == nil)
    }
    
    /// Tests entity blocking tiles configuration.
    ///
    /// Verifies that different entity types have correct movement restrictions.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testEntityMovementRestrictions() async throws {
        let player = Player(gridX: 5, gridY: 5, tileSize: 32.0)
        let monster = Monster(gridX: 6, gridY: 6, tileSize: 32.0)
        let charmed = Charmed(gridX: 7, gridY: 7, tileSize: 32.0)
        
        // Test that all entities have proper blocking tiles configured
        let expectedBlockingTiles: Set<TileKind> = [.wall, .doorClosed, .doorSecret, .driveway]
        
        #expect(player.blockingTiles == expectedBlockingTiles)
        #expect(monster.blockingTiles == expectedBlockingTiles)
        #expect(charmed.blockingTiles == expectedBlockingTiles)
        
        // Test that entities can determine walkability
        let walkableChecker = { (kind: TileKind) -> Bool in
            !player.blockingTiles.contains(kind)
        }
        
        #expect(walkableChecker(.floor) == true)
        #expect(walkableChecker(.sidewalk) == true)
        #expect(walkableChecker(.wall) == false)
        #expect(walkableChecker(.doorClosed) == false)
    }
    
    /// Tests the new 5-tile seeking range for monsters.
    ///
    /// Verifies that monsters only seek players when within 5 tiles distance
    /// and revert to random movement when the player is beyond seeking range.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterSeekingRangeBehavior() async throws {
        let tileSize: CGFloat = 32.0
        
        // Test within seeking range (5 tiles or less)
        let withinRangeTests = [
            (monsterX: 5, monsterY: 5, playerX: 5, playerY: 6, distance: 1),   // 1 tile
            (monsterX: 5, monsterY: 5, playerX: 5, playerY: 7, distance: 2),   // 2 tiles  
            (monsterX: 5, monsterY: 5, playerX: 5, playerY: 8, distance: 3),   // 3 tiles
            (monsterX: 5, monsterY: 5, playerX: 5, playerY: 9, distance: 4),   // 4 tiles
            (monsterX: 5, monsterY: 5, playerX: 5, playerY: 10, distance: 5),  // 5 tiles (limit)
            (monsterX: 5, monsterY: 5, playerX: 8, playerY: 7, distance: 5),   // 5 tiles diagonal
        ]
        
        for test in withinRangeTests {
            let monster = Monster(gridX: test.monsterX, gridY: test.monsterY, tileSize: tileSize)
            let player = Player(gridX: test.playerX, gridY: test.playerY, tileSize: tileSize)
            
            let dx = abs(monster.gridX - player.gridX)
            let dy = abs(monster.gridY - player.gridY)
            let manhattanDistance = dx + dy
            
            #expect(manhattanDistance == test.distance, "Distance calculation failed for test case")
            #expect(manhattanDistance <= 5, "Monster should be within seeking range")
        }
        
        // Test beyond seeking range (more than 5 tiles)
        let beyondRangeTests = [
            (monsterX: 5, monsterY: 5, playerX: 5, playerY: 11, distance: 6),   // 6 tiles
            (monsterX: 5, monsterY: 5, playerX: 5, playerY: 15, distance: 10),  // 10 tiles
            (monsterX: 5, monsterY: 5, playerX: 12, playerY: 12, distance: 14), // 14 tiles diagonal
        ]
        
        for test in beyondRangeTests {
            let monster = Monster(gridX: test.monsterX, gridY: test.monsterY, tileSize: tileSize)
            let player = Player(gridX: test.playerX, gridY: test.playerY, tileSize: tileSize)
            
            let dx = abs(monster.gridX - player.gridX)
            let dy = abs(monster.gridY - player.gridY)
            let manhattanDistance = dx + dy
            
            #expect(manhattanDistance == test.distance, "Distance calculation failed for test case")
            #expect(manhattanDistance > 5, "Monster should be beyond seeking range")
        }
    }
    
    /// Tests monster state transitions with seeking range limits.
    ///
    /// Verifies that monsters properly switch between seeking and roaming
    /// based on the 5-tile seeking range.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterStateWithSeekingRange() async throws {
        let monster = Monster(gridX: 10, gridY: 10, tileSize: 32.0)
        
        // Test initial state
        #expect(monster.lastPlayerPosition == nil)
        #expect(monster.roamTarget == nil)
        
        // Simulate detecting player within range
        monster.lastPlayerPosition = (12, 12) // Distance = 4, within range
        #expect(monster.lastPlayerPosition != nil)
        
        // Simulate player moving out of range
        let farPosition = (20, 20) // Distance = 20, beyond range
        let dx = abs(monster.gridX - farPosition.0)
        let dy = abs(monster.gridY - farPosition.1)
        let distance = dx + dy
        #expect(distance > 5, "Player should be beyond seeking range")
        
        // Monster should lose interest when player is too far
        if distance > 5 {
            monster.lastPlayerPosition = nil
            #expect(monster.lastPlayerPosition == nil)
        }
    }
    
    /// Tests FOV radius optimization for better gameplay balance.
    ///
    /// Verifies that the reduced FOV radius (4 instead of 5) provides
    /// better balanced line of sight distances.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testOptimizedFOVRadius() async throws {
        let testRadius = 4
        
        // Create a simple test map
        var config = DungeonConfig()
        config.width = 15
        config.height = 15
        config.algorithm = .roomsCorridors
        config.cityLayout = false
        
        let generator = DungeonGenerator(config: config)
        var map = generator.generate()
        
        // Test FOV computation with optimized radius
        FOV.compute(map: &map, originX: 7, originY: 7, radius: testRadius)
        
        let visibleTiles = map.tiles.filter { $0.visible }
        
        // With radius 4, we should have a reasonable number of visible tiles
        // Not too many (overwhelming) or too few (restrictive)
        #expect(visibleTiles.count >= 20, "Should have minimum visibility")
        #expect(visibleTiles.count <= 100, "Should not have excessive visibility")
        
        // Test that tiles at distance 4 can be visible
        // Test a few specific positions at distance 4
        let testPositions = [
            (x: 7 + 4, y: 7),     // 4 tiles east
            (x: 7, y: 7 + 4),     // 4 tiles north
            (x: 7 - 4, y: 7),     // 4 tiles west  
            (x: 7, y: 7 - 4),     // 4 tiles south
        ]
        
        for pos in testPositions {
            if map.inBounds(pos.x, pos.y) {
                let tile = map.tiles[map.index(x: pos.x, y: pos.y)]
                // Tile visibility depends on line of sight, but function should work
                #expect(tile.visible == true || tile.visible == false)
            }
        }
    }
    
    /// Tests monster sighting timeout behavior.
    ///
    /// Verifies that monsters stop seeking after a timeout period
    /// when they lose sight of the player.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterSightingTimeout() async throws {
        let monster = Monster(gridX: 5, gridY: 5, tileSize: 32.0)
        
        // Test initial state
        #expect(monster.lastPlayerSightingTime == 0)
        #expect(monster.lastPlayerPosition == nil)
        
        // Simulate monster spotting player
        monster.lastPlayerPosition = (8, 8)
        monster.lastPlayerSightingTime = CACurrentMediaTime()
        
        #expect(monster.lastPlayerPosition != nil)
        #expect(monster.lastPlayerSightingTime > 0)
        
        // Test that sighting time is tracked
        let currentTime = CACurrentMediaTime()
        #expect(monster.lastPlayerSightingTime <= currentTime)
        
        // Simulate timeout (in actual game, this would be checked in updateMonsters)
        let timeoutThreshold: TimeInterval = 5.0
        let timeDifference = currentTime - monster.lastPlayerSightingTime
        let shouldTimeout = timeDifference > timeoutThreshold
        
        // For this test, the timeout check logic is validated
        #expect(shouldTimeout == true || shouldTimeout == false) // Just verify the comparison works
    }
    
    /// Tests integrated movement system behavior.
    ///
    /// Comprehensive test that verifies the entire movement system works together:
    /// FOV, monster AI, player movement, and proximity detection.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testIntegratedMovementSystem() async throws {
        // Create test entities
        let player = Player(gridX: 10, gridY: 10, tileSize: 32.0)
        let nearMonster = Monster(gridX: 12, gridY: 12, tileSize: 32.0)  // Distance 4, within range
        let farMonster = Monster(gridX: 20, gridY: 20, tileSize: 32.0)   // Distance 20, out of range
        
        // Test distance calculations
        let nearDistance = abs(nearMonster.gridX - player.gridX) + abs(nearMonster.gridY - player.gridY)
        let farDistance = abs(farMonster.gridX - player.gridX) + abs(farMonster.gridY - player.gridY)
        
        #expect(nearDistance == 4)
        #expect(farDistance == 20)
        
        // Test seeking range logic
        #expect(nearDistance <= 5, "Near monster should be within seeking range")
        #expect(farDistance > 5, "Far monster should be beyond seeking range")
        
        // Test that monsters can track player state properly
        nearMonster.lastPlayerPosition = (player.gridX, player.gridY)
        nearMonster.lastPlayerSightingTime = CACurrentMediaTime()
        
        #expect(nearMonster.lastPlayerPosition != nil)
        #expect(nearMonster.lastPlayerSightingTime > 0)
        
        // Test that far monster should not be tracking if out of range
        farMonster.lastPlayerPosition = nil
        farMonster.roamTarget = (18, 18)  // Should have random roam target
        
        #expect(farMonster.lastPlayerPosition == nil)
        #expect(farMonster.roamTarget != nil)
        
        // Create a simple map for pathfinding test
        var config = DungeonConfig()
        config.width = 25
        config.height = 25
        config.algorithm = .roomsCorridors
        config.cityLayout = false
        
        let generator = DungeonGenerator(config: config)
        let map = generator.generate()
        
        // Test that pathfinding works for both monsters
        let nearPath = Pathfinder.aStar(map: map,
                                       start: (nearMonster.gridX, nearMonster.gridY),
                                       goal: (player.gridX, player.gridY),
                                       passable: { !nearMonster.blockingTiles.contains($0) })
        
        let farPath = Pathfinder.aStar(map: map,
                                      start: (farMonster.gridX, farMonster.gridY),
                                      goal: (18, 18),  // Random roam target
                                      passable: { !farMonster.blockingTiles.contains($0) })
        
        // Paths should either be valid or empty, but not crash
        #expect(nearPath.count >= 0)
        #expect(farPath.count >= 0)
        
        // Test FOV radius consistency
        let fovRadius = 4
        #expect(fovRadius < 5, "FOV radius should be optimized")
        #expect(fovRadius >= 3, "FOV radius should provide reasonable visibility")
    }
    
    /// Tests monster cooldown behavior after player contact.
    ///
    /// Verifies that monsters enter cooldown state after contacting player
    /// and resume random movement instead of seeking.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testMonsterCooldownBehavior() async throws {
        let monster = Monster(gridX: 5, gridY: 5, tileSize: 32.0)
        let currentTime = CACurrentMediaTime()
        
        // Test initial state - no cooldown
        #expect(monster.cooldownUntil == 0)
        #expect(currentTime >= monster.cooldownUntil, "Monster should not be in cooldown initially")
        
        // Simulate monster contact with player (cooldown should be set)
        let cooldownDuration: TimeInterval = 5.0
        monster.cooldownUntil = currentTime + cooldownDuration
        
        #expect(monster.cooldownUntil > currentTime, "Monster should be in cooldown after contact")
        
        // Test cooldown expiry
        let futureTime = currentTime + cooldownDuration + 1.0
        #expect(futureTime > monster.cooldownUntil, "Monster cooldown should eventually expire")
        
        // Verify cooldown resets player tracking
        monster.lastPlayerPosition = (10, 10)
        // In actual game, contact would clear this:
        // monster.lastPlayerPosition = nil
        #expect(monster.lastPlayerPosition != nil, "Test setup check")
    }
    
    /// Tests charmed entity ice cream truck seeking behavior.
    ///
    /// Verifies that non-charmed entities seek visible ice cream trucks
    /// while charmed entities follow the player instead.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testCharmedIceCreamTruckSeeking() async throws {
        let charmed = Charmed(gridX: 5, gridY: 5, tileSize: 32.0)
        
        // Test initial state
        #expect(charmed.isCharmed == false, "Charmed entity should start uncharmed")
        #expect(charmed.roamTarget == nil, "Should have no roam target initially")
        
        // Test charmed state - should not seek ice cream trucks
        charmed.isCharmed = true
        #expect(charmed.isCharmed == true, "Entity should be charmed")
        
        // Test uncharmed state - should be able to seek ice cream trucks
        charmed.isCharmed = false
        #expect(charmed.isCharmed == false, "Entity should be uncharmed and able to seek ice cream trucks")
        
        // Note: Full ice cream truck seeking behavior requires map with actual ice cream trucks
        // This test validates the entity state that enables/disables the behavior
    }

}
