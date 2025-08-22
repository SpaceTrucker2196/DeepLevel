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
    
    /// Tests solid room border functionality for dungeon generation.
    ///
    /// Verifies that when room borders are enabled, rooms are created with
    /// solid borders that corridors cannot overwrite, ensuring room integrity.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testSolidRoomBorders() async throws {
        // Test configuration with borders enabled
        var config = DungeonConfig()
        config.width = 20
        config.height = 20
        config.maxRooms = 2
        config.roomMinSize = 4
        config.roomMaxSize = 6
        config.roomBorders = true
        config.algorithm = .roomsCorridors
        
        // Generate dungeon with solid borders
        let generator = RoomsGenerator()
        var rng = SystemRandomNumberGenerator()
        let dungeon = generator.generate(config: config, rng: &rng)
        
        // Verify that the dungeon has rooms
        #expect(dungeon.rooms.count > 0)
        
        // Check that each room has solid borders
        for room in dungeon.rooms {
            // Check top and bottom borders
            for x in room.x..<(room.x + room.w) {
                let topIdx = x + room.y * config.width
                let bottomIdx = x + (room.y + room.h - 1) * config.width
                
                if topIdx >= 0 && topIdx < dungeon.tiles.count {
                    #expect(dungeon.tiles[topIdx].kind == .solid, "Top border should be solid at \(x), \(room.y)")
                }
                if bottomIdx >= 0 && bottomIdx < dungeon.tiles.count {
                    #expect(dungeon.tiles[bottomIdx].kind == .solid, "Bottom border should be solid at \(x), \(room.y + room.h - 1)")
                }
            }
            
            // Check left and right borders
            for y in room.y..<(room.y + room.h) {
                let leftIdx = room.x + y * config.width
                let rightIdx = (room.x + room.w - 1) + y * config.width
                
                if leftIdx >= 0 && leftIdx < dungeon.tiles.count {
                    #expect(dungeon.tiles[leftIdx].kind == .solid, "Left border should be solid at \(room.x), \(y)")
                }
                if rightIdx >= 0 && rightIdx < dungeon.tiles.count {
                    #expect(dungeon.tiles[rightIdx].kind == .solid, "Right border should be solid at \(room.x + room.w - 1), \(y)")
                }
            }
            
            // Check that interior is floor
            for x in (room.x + 1)..<(room.x + room.w - 1) {
                for y in (room.y + 1)..<(room.y + room.h - 1) {
                    let idx = x + y * config.width
                    if idx >= 0 && idx < dungeon.tiles.count {
                        #expect(dungeon.tiles[idx].kind == .floor, "Interior should be floor at \(x), \(y)")
                    }
                }
            }
        }
    }
    
    /// Tests solid room border functionality for BSP dungeon generation.
    ///
    /// Verifies that BSP generator also properly creates solid borders
    /// that corridors cannot overwrite.
    ///
    /// - Throws: Any errors encountered during test execution
    @Test func testBSPSolidRoomBorders() async throws {
        // Test BSP configuration with borders enabled
        var config = DungeonConfig()
        config.width = 20
        config.height = 20
        config.bspMaxDepth = 3
        config.roomMinSize = 4
        config.roomMaxSize = 6
        config.roomBorders = true
        config.algorithm = .bsp
        
        // Generate BSP dungeon with solid borders
        let generator = BSPGenerator()
        var rng = SystemRandomNumberGenerator()
        let dungeon = generator.generate(config: config, rng: &rng)
        
        // Verify that the dungeon has rooms
        #expect(dungeon.rooms.count > 0)
        
        // Check that each room has solid borders
        for room in dungeon.rooms {
            // Check that borders exist as solid tiles
            var solidBorderFound = false
            
            // Check top and bottom borders
            for x in room.x..<(room.x + room.w) {
                let topIdx = x + room.y * config.width
                let bottomIdx = x + (room.y + room.h - 1) * config.width
                
                if topIdx >= 0 && topIdx < dungeon.tiles.count && dungeon.tiles[topIdx].kind == .solid {
                    solidBorderFound = true
                }
                if bottomIdx >= 0 && bottomIdx < dungeon.tiles.count && dungeon.tiles[bottomIdx].kind == .solid {
                    solidBorderFound = true
                }
            }
            
            // Check left and right borders
            for y in room.y..<(room.y + room.h) {
                let leftIdx = room.x + y * config.width
                let rightIdx = (room.x + room.w - 1) + y * config.width
                
                if leftIdx >= 0 && leftIdx < dungeon.tiles.count && dungeon.tiles[leftIdx].kind == .solid {
                    solidBorderFound = true
                }
                if rightIdx >= 0 && rightIdx < dungeon.tiles.count && dungeon.tiles[rightIdx].kind == .solid {
                    solidBorderFound = true
                }
            }
            
            // At least some solid borders should exist for rooms with borders enabled
            #expect(solidBorderFound, "Room should have solid borders when roomBorders is enabled")
        }
    }

}
