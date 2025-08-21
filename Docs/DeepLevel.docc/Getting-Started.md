# Getting Started with DeepLevel

Learn how to integrate and use the DeepLevel dungeon generation system.

## Overview

DeepLevel provides a complete solution for procedural dungeon generation in Swift games. This guide will walk you through the basic setup and usage patterns.

## Basic Usage

### Creating a Dungeon

```swift
import DeepLevel

// Configure generation parameters
var config = DungeonConfig()
config.width = 80
config.height = 50
config.algorithm = .roomsCorridors
config.seed = 12345 // For reproducible results

// Generate the dungeon
let generator = DungeonGenerator(config: config)
let dungeon = generator.generate()

// Access the result
print("Generated dungeon with \(dungeon.rooms.count) rooms")
print("Player starts at: \(dungeon.playerStart)")
```

### Rendering with SpriteKit

```swift
// Build tile set for rendering
let (tileSet, tileRefs) = TileSetBuilder.build(tileSize: 24.0)

// Create tile map node
let tileMapNode = SKTileMapNode(
    tileSet: tileSet,
    columns: dungeon.width,
    rows: dungeon.height,
    tileSize: CGSize(width: 24, height: 24)
)

// Apply tiles to the map
for y in 0..<dungeon.height {
    for x in 0..<dungeon.width {
        let tile = dungeon.tiles[dungeon.index(x: x, y: y)]
        let tileGroup: SKTileGroup
        
        switch tile.kind {
        case .floor:
            tileGroup = tileRefs.floorVariants[tile.variant]
        case .wall:
            tileGroup = tileRefs.wall
        case .doorClosed:
            tileGroup = tileRefs.door
        case .doorSecret:
            tileGroup = tileRefs.secretDoor
        }
        
        tileMapNode.setTileGroup(tileGroup, forColumn: x, row: y)
    }
}
```

### Field of View Calculation

```swift
// Update field of view from player position
var mutableDungeon = dungeon
FOV.compute(
    map: &mutableDungeon,
    originX: playerX,
    originY: playerY,
    radius: 8
)

// Check tile visibility
let tile = mutableDungeon.tiles[mutableDungeon.index(x: x, y: y)]
if tile.visible {
    // Tile is currently visible
}
if tile.explored {
    // Tile has been seen before
}
```

## Next Steps

- Explore different generation algorithms in <doc:Dungeon-Algorithms>
- Learn about the system architecture in <doc:Game-Architecture>
- Check out the complete API reference in the Topics section