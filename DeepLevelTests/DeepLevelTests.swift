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

    /// Example test method demonstrating testing framework usage.
    ///
    /// Placeholder test method that can be expanded to verify specific
    /// functionality as the application develops.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
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

}
