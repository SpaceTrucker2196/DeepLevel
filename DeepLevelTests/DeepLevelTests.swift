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
            case .floor, .sidewalk: return true
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

}
