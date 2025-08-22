import Testing
@testable import DeepLevel

/// Tests for the enhanced fog of war system.
struct FogOfWarTests {
    
    @Test func testFogOfWarInitialization() async throws {
        // Test that fog of war initializes with correct dimensions
        let fogOfWar = FogOfWar(mapWidth: 10, mapHeight: 10, tileSize: 32.0)
        
        #expect(fogOfWar.children.count == 100) // 10x10 = 100 tiles
    }
    
    @Test func testFogUpdateWithVisibility() async throws {
        let fogOfWar = FogOfWar(mapWidth: 3, mapHeight: 3, tileSize: 32.0)
        
        // Create a simple 3x3 map
        var tiles = Array(repeating: Tile(kind: .floor), count: 9)
        
        // Make center tile visible and explored
        tiles[4].visible = true
        tiles[4].explored = true
        
        // Make adjacent tile explored but not visible
        tiles[1].visible = false
        tiles[1].explored = true
        
        // Leave corner tiles unexplored and invisible
        tiles[0].visible = false
        tiles[0].explored = false
        
        let map = DungeonMap(width: 3, height: 3, tiles: tiles, playerStart: (1, 1), rooms: [])
        
        // Update fog based on map state
        fogOfWar.updateFog(for: map)
        
        // Verify fog tile states
        let fogTiles = fogOfWar.children.compactMap { $0 as? SKSpriteNode }
        
        // Center tile (index 4) should be fully visible (alpha 0.0)
        #expect(abs(fogTiles[4].alpha - 0.0) < 0.01)
        
        // Adjacent tile (index 1) should be dimmed (alpha 0.5)
        #expect(abs(fogTiles[1].alpha - 0.5) < 0.01)
        
        // Corner tile (index 0) should be fully fogged (alpha 1.0)
        #expect(abs(fogTiles[0].alpha - 1.0) < 0.01)
    }
}