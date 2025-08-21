# DeepLevel

A comprehensive dungeon generation and exploration game built with SpriteKit.

## Overview

DeepLevel is a sophisticated dungeon generation system that provides multiple algorithms for creating diverse and engaging underground environments. The game features real-time exploration with field-of-view calculations, pathfinding AI, and interactive gameplay elements.

The system supports three distinct generation algorithms:
- **Room-and-Corridor**: Traditional rectangular rooms connected by passages
- **Binary Space Partitioning (BSP)**: Organic room layouts through recursive space division  
- **Cellular Automata**: Cave-like structures with natural, irregular formations

## Features Implemented

1. **Procedural Generation Algorithms**
   - Rooms & corridors (with doors + secret rooms)
   - BSP partitioning
   - Cellular Automata caves
2. **SKTileMapNode** for efficient tile rendering
3. **Field of View / Fog of War** (symmetric shadowcasting)
4. **Entity system** (Player + Monsters)
5. **A* pathfinding** for monsters (periodically recomputed)
6. **Floor biome / variation** via Perlin noise (tile variants)
7. **Seeded generation** (press T for timestamp seed; R for random)
8. **Camera smoothing** (lerp)
9. **Doors & secret doors** (open when walked into)
10. **Simple combat** (move into monster = attack; space to let monsters take a turn)

## Getting Started

Learn how to integrate and use the DeepLevel dungeon generation system.

### Basic Usage

#### Creating a Dungeon

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

#### Rendering with SpriteKit

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

#### Field of View Calculation

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

## Controls (macOS)

- **Movement**: WASD or Arrow Keys
- **R**: Regenerate with random seed
- **T**: Regenerate with deterministic seed (current timestamp)
- **F**: Cycle generation algorithm
- **Space**: Skip turn (monsters path toward you)
- **Move into closed/secret door**: Opens it
- **Move into monster**: Attack it

## Dungeon Generation Algorithms

DeepLevel offers three distinct algorithms for dungeon generation, each producing unique characteristics and gameplay experiences. Understanding these algorithms helps you choose the right approach for your game's needs.

### Room-and-Corridor Algorithm

The traditional approach that creates rectangular rooms connected by L-shaped corridors.

#### Characteristics
- **Structure**: Clean, architectural layouts with distinct rooms
- **Connectivity**: Guaranteed connectivity between all areas
- **Doors**: Automatic door placement at room entrances
- **Secret Rooms**: Optional hidden areas with secret doors

#### Best For
- Traditional dungeon crawlers
- Grid-based movement games
- Games requiring predictable room layouts

#### Configuration
```swift
var config = DungeonConfig()
config.algorithm = .roomsCorridors
config.maxRooms = 20
config.roomMinSize = 4
config.roomMaxSize = 10
config.secretRoomChance = 0.08
```

### Binary Space Partitioning (BSP)

Recursively divides space into smaller regions, creating more organic room arrangements.

#### Characteristics
- **Structure**: Varied room sizes with natural clustering
- **Layout**: Tree-based connectivity following partition hierarchy
- **Flexibility**: Adapts to different space constraints
- **Organic Feel**: Less rigid than room-and-corridor

#### Best For
- Exploration-focused games
- Varied pacing with different room densities
- More realistic architectural layouts

#### Configuration
```swift
var config = DungeonConfig()
config.algorithm = .bsp
config.bspMaxDepth = 5
config.roomMinSize = 4
config.roomMaxSize = 10
```

### Cellular Automata

Creates cave-like structures using iterative smoothing rules.

#### Characteristics
- **Structure**: Organic, natural cave systems
- **Connectivity**: Single large connected area
- **Irregularity**: No geometric patterns or straight lines
- **Realism**: Resembles natural cave formations

#### Best For
- Cave exploration games
- Organic, natural environments
- Survival or mining games

#### Configuration
```swift
var config = DungeonConfig()
config.algorithm = .cellular
config.cellularFillProb = 0.45  // Initial wall density
config.cellularSteps = 5        // Smoothing iterations
```

### Algorithm Comparison

| Feature | Room-Corridor | BSP | Cellular |
|---------|---------------|-----|----------|
| Room Definition | Explicit rectangular rooms | Varied organic rooms | Open cave areas |
| Connectivity | Corridor network | Hierarchical tree | Single large space |
| Predictability | High | Medium | Low |
| Navigation | Grid-friendly | Moderate complexity | Freeform |
| Doors | Automatic placement | Possible | Not applicable |

### Performance Considerations

- **Room-Corridor**: O(width × height + maxRooms²)
- **BSP**: O(width × height + 2^maxDepth)
- **Cellular**: O(width × height × cellularSteps)

### Combining Algorithms

You can create hybrid approaches by:
1. Generating base structure with one algorithm
2. Post-processing with elements from another
3. Using different algorithms for different dungeon levels

## Game Architecture

DeepLevel is built with a modular architecture that separates concerns between generation, rendering, gameplay, and persistence. This design enables flexibility and maintainability while supporting real-time gameplay.

### Core Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Input    │    │   Game Logic    │    │   Rendering     │
│                 │    │                 │    │                 │
│ Touch/Keyboard  │───▶│   GameScene     │───▶│   SpriteKit     │
│ SwiftUI Views   │    │   Entity        │    │   TileMapNode   │
└─────────────────┘    │   HUD           │    │   SKSpriteNode  │
                       └─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Generation    │    │   Game Systems  │    │   Persistence   │
│                 │    │                 │    │                 │
│ DungeonGenerator│◀───│   Pathfinder    │    │   CoreData      │
│ Algorithms      │    │   FOV           │    │   CloudKit      │
│ TileSetBuilder  │    │   Physics       │    │   UserDefaults  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Layer Responsibilities

#### Presentation Layer
- **SwiftUI Views**: App structure and UI integration
- **SpriteKit Rendering**: Game visuals and animations
- **Input Handling**: Touch and keyboard input processing

#### Game Logic Layer
- **GameScene**: Main game coordinator and update loop
- **Entity System**: Player, monsters, and item management
- **HUD**: User interface and information display

#### Systems Layer
- **Pathfinding**: A* algorithm for AI movement
- **Field of View**: Visibility and exploration tracking
- **Physics**: Collision detection and movement validation

#### Generation Layer
- **DungeonGenerator**: Algorithm coordination and post-processing
- **Generation Algorithms**: Room-corridor, BSP, cellular automata
- **TileSetBuilder**: Texture and tile group creation

#### Persistence Layer
- **Core Data**: Local data storage and object management
- **CloudKit**: Cross-device synchronization
- **Configuration**: Settings and preferences

### Data Flow

#### Generation Phase
1. **Configuration** → `DungeonConfig` defines parameters
2. **Algorithm Selection** → `DungeonGenerator` chooses implementation
3. **Generation** → Algorithm creates `DungeonMap`
4. **Post-Processing** → Floor variants and optimizations
5. **Tile Building** → `TileSetBuilder` creates visual assets

#### Gameplay Phase
1. **Input** → User actions create movement requests
2. **Validation** → `DungeonMap` checks movement legality
3. **Entity Update** → Positions and states change
4. **AI Processing** → `Pathfinder` calculates monster movement
5. **Visibility** → `FOV` updates visible tiles
6. **Rendering** → SpriteKit draws current state

#### Update Loop
```swift
override func update(_ currentTime: TimeInterval) {
    // 1. Process input
    handlePendingInput()
    
    // 2. Update game logic
    updateEntities(deltaTime: currentTime - lastUpdateTime)
    
    // 3. AI processing
    updateMonsterAI()
    
    // 4. Visibility calculation
    updateFieldOfView()
    
    // 5. Camera and HUD
    updateCamera()
    updateHUD()
    
    lastUpdateTime = currentTime
}
```

### Component Interactions

#### Entity-Map Interaction
- Entities query `DungeonMap` for movement validation
- Map provides collision and visibility information
- Entities update their grid positions through map constraints

#### Generation-Rendering Bridge
- `TileSetBuilder` converts logical tiles to visual assets
- `TileRefs` provides efficient access to tile groups
- Texture caching optimizes memory usage

#### AI-Systems Integration
- `Pathfinder` uses map data for navigation
- `FOV` tracks exploration state
- Monster AI combines pathfinding with visibility data

### Performance Optimizations

#### Memory Management
- Texture caching in `TileSetBuilder`
- Object pooling for frequently created entities
- Lazy loading of visual assets

#### Computational Efficiency
- A* pathfinding with early termination
- Incremental FOV updates
- Batch tile updates for rendering

#### Scalability
- Configurable complexity parameters
- Adaptive quality based on device performance
- Modular algorithm implementations

### Extension Points

The architecture supports extension through:

#### Custom Algorithms
Implement `DungeonGenerating` protocol for new generation methods

#### Additional Entities
Extend `Entity` class hierarchy for new game objects

#### New Systems
Add processing systems that operate on game state

#### Rendering Enhancements
Extend `TileSetBuilder` for visual effects and animations

### Testing Strategy

- **Unit Tests**: Algorithm correctness and edge cases
- **Integration Tests**: Component interaction validation
- **UI Tests**: User flow and screenshot regression
- **Performance Tests**: Generation time and memory usage

## API Reference

### Essentials

- `GameScene` - Main game coordinator and update loop
- `DungeonMap` - Core dungeon data structure
- `Entity` - Base class for game objects
- `TileKind` - Enumeration of tile types

### Dungeon Generation

- `DungeonGenerating` - Protocol for generation algorithms
- `DungeonGenerator` - Main generation coordinator
- `RoomsGenerator` - Room-and-corridor implementation
- `BSPGenerator` - Binary space partitioning implementation
- `CellularAutomataGenerator` - Cellular automata implementation
- `DungeonConfig` - Configuration parameters

### Game Systems

- `Pathfinder` - A* pathfinding implementation
- `FOV` - Field of view calculations
- `TileSetBuilder` - Texture and tile creation
- `HUD` - User interface management

### Core Types

- `Tile` - Individual map cell data
- `Rect` - Rectangle utility type
- `SeededGenerator` - Deterministic random generation

### Advanced

- `Monster` - AI-controlled entities
- `PersistenceController` - Data persistence management

## Configuration

The `DungeonConfig` class provides comprehensive configuration options:

```swift
var config = DungeonConfig()
config.width = 80                    // Map width
config.height = 50                   // Map height
config.algorithm = .roomsCorridors   // Generation algorithm
config.seed = 12345                  // Random seed
config.maxRooms = 20                 // Maximum rooms (room-corridor)
config.roomMinSize = 4               // Minimum room size
config.roomMaxSize = 10              // Maximum room size
config.secretRoomChance = 0.08       // Secret room probability
config.bspMaxDepth = 5               // BSP recursion depth
config.cellularFillProb = 0.45       // Cellular initial density
config.cellularSteps = 5             // Cellular smoothing iterations
```

## Extension Ideas

- Replace runtime-generated textures with real art (TileSetBuilder)
- Implement granular fog overlay (per-tile alpha) or shader-based masking
- Add inventory & item pickups (EntityKind.item)
- Introduce turn-based scheduling / energy system
- Add ranged FOV (light sources) and lighting colors
- Optimize pathfinding (cache flow fields or use Dijkstra maps)
- Use GKComponent / GKEntity for more complex ECS patterns

## Technical Notes

- Fog layer currently global; for per-tile darkness, maintain an overlay node per tile or a custom shader
- Secret door reveals when the tile is opened (walked into)
- Pathfinding can be throttled further for performance (only some monsters per tick)
- The architecture ensures maintainability while supporting the complex requirements of real-time dungeon exploration gameplay

## License

(Choose a license and add it here.)
