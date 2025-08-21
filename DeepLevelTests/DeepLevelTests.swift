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
    
    /// Tests that RoomsGenerator produces valid dungeon maps.
    ///
    /// Verifies the refactored RoomsGenerator still generates playable
    /// dungeons with proper dimensions, player starts, and room structures.
    ///
    /// - Throws: Any errors encountered during generation or validation
    @Test func roomsGeneratorProducesValidDungeons() async throws {
        let config = DungeonConfig()
        var rng = SystemRandomNumberGenerator()
        let generator = RoomsGenerator()
        
        let dungeon = generator.generate(config: config, rng: &rng)
        
        // Verify basic properties
        #expect(dungeon.width == config.width)
        #expect(dungeon.height == config.height)
        #expect(dungeon.tiles.count == config.width * config.height)
        
        // Verify player start is within bounds
        #expect(dungeon.playerStart.0 >= 0 && dungeon.playerStart.0 < config.width)
        #expect(dungeon.playerStart.1 >= 0 && dungeon.playerStart.1 < config.height)
        
        // Verify at least some floor tiles were created
        let floorTiles = dungeon.tiles.filter { $0.kind == .floor }
        #expect(floorTiles.count > 0)
        
        // Verify rooms were generated if any
        if !dungeon.rooms.isEmpty {
            #expect(dungeon.rooms.count <= config.maxRooms)
            
            // Verify each room is within bounds
            for room in dungeon.rooms {
                #expect(room.x >= 0 && room.x + room.w <= config.width)
                #expect(room.y >= 0 && room.y + room.h <= config.height)
            }
        }
    }
    
    /// Tests generation with different configurations.
    ///
    /// Verifies the generator handles various configuration parameters
    /// correctly and produces appropriate results for edge cases.
    ///
    /// - Throws: Any errors encountered during generation or validation
    @Test func roomsGeneratorHandlesVariousConfigurations() async throws {
        var rng = SystemRandomNumberGenerator()
        let generator = RoomsGenerator()
        
        // Test with minimal configuration
        var smallConfig = DungeonConfig()
        smallConfig.width = 20
        smallConfig.height = 15
        smallConfig.maxRooms = 3
        
        let smallDungeon = generator.generate(config: smallConfig, rng: &rng)
        #expect(smallDungeon.width == 20)
        #expect(smallDungeon.height == 15)
        #expect(smallDungeon.tiles.count == 300)
        
        // Test with larger configuration
        var largeConfig = DungeonConfig()
        largeConfig.width = 100
        largeConfig.height = 80
        largeConfig.maxRooms = 30
        
        let largeDungeon = generator.generate(config: largeConfig, rng: &rng)
        #expect(largeDungeon.width == 100)
        #expect(largeDungeon.height == 80)
        #expect(largeDungeon.tiles.count == 8000)
    }

}
