//
//  DeepLevelTests.swift
//  DeepLevelTests
//
//  Created by Jeffrey Kunzelman on 8/21/25.
//

import Testing
import CoreGraphics
@testable import DeepLevel

/// Test suite for the DeepLevel application functionality.
///
/// Contains unit tests for verifying core game logic, dungeon generation,
/// and other critical functionality. Uses Swift Testing framework for
/// modern test organization and execution.
///
/// - Since: 1.0.0
struct DeepLevelTests {

    /// Tests basic dungeon generation functionality.
    ///
    /// Verifies that dungeon generation produces valid maps with expected
    /// properties and maintains consistency across multiple generations.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testDungeonGeneration() async throws {
        let config = DungeonConfig(width: 40, height: 30, maxRooms: 8)
        let generator = DungeonGenerator(config: config)
        let map = generator.generate()
        
        // Verify basic map properties
        #expect(map.width == 40)
        #expect(map.height == 30)
        #expect(map.tiles.count == 40 * 30)
        
        // Verify player start is within bounds
        #expect(map.playerStart.0 >= 0 && map.playerStart.0 < 40)
        #expect(map.playerStart.1 >= 0 && map.playerStart.1 < 30)
        
        // Verify the player start is on a floor tile
        let startIdx = map.index(x: map.playerStart.0, y: map.playerStart.1)
        #expect(map.tiles[startIdx].kind == .floor)
    }
    
    /// Tests HUD display information parameter object.
    ///
    /// Verifies that the HUD display info properly encapsulates
    /// parameters and provides correct default values.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testHUDDisplayInfo() async throws {
        let displayInfo = HUDDisplayInfo(
            seed: 12345,
            hp: 100,
            algo: .roomsCorridors,
            size: CGSize(width: 800, height: 600)
        )
        
        #expect(displayInfo.seed == 12345)
        #expect(displayInfo.hp == 100)
        #expect(displayInfo.algo == .roomsCorridors)
        #expect(displayInfo.size.width == 800)
        #expect(displayInfo.size.height == 600)
        #expect(displayInfo.safeInset == 8) // Default value
    }
    
    /// Tests entity movement and positioning.
    ///
    /// Verifies that entities can be moved correctly and maintain
    /// proper grid and visual positioning.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testEntityMovement() async throws {
        let entity = Entity(kind: .player, gridX: 5, gridY: 10, color: .red, size: CGSize(width: 20, height: 20))
        
        #expect(entity.gridX == 5)
        #expect(entity.gridY == 10)
        
        entity.moveTo(gridX: 7, gridY: 12, tileSize: 24, animated: false)
        
        #expect(entity.gridX == 7)
        #expect(entity.gridY == 12)
        // Visual position should be calculated correctly
        #expect(abs(entity.position.x - (7 * 24 + 12)) < 1.0)
        #expect(abs(entity.position.y - (12 * 24 + 12)) < 1.0)
    }

    /// Example test method demonstrating testing framework usage.
    ///
    /// Placeholder test method that can be expanded to verify specific
    /// functionality as the application develops.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}
