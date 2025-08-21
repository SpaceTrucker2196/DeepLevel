# Game Architecture

Understand the overall system design and component interactions.

## Overview

DeepLevel is built with a modular architecture that separates concerns between generation, rendering, gameplay, and persistence. This design enables flexibility and maintainability while supporting real-time gameplay.

## Core Architecture

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

## Layer Responsibilities

### Presentation Layer
- **SwiftUI Views**: App structure and UI integration
- **SpriteKit Rendering**: Game visuals and animations
- **Input Handling**: Touch and keyboard input processing

### Game Logic Layer
- **GameScene**: Main game coordinator and update loop
- **Entity System**: Player, monsters, and item management
- **HUD**: User interface and information display

### Systems Layer
- **Pathfinding**: A* algorithm for AI movement
- **Field of View**: Visibility and exploration tracking
- **Physics**: Collision detection and movement validation

### Generation Layer
- **DungeonGenerator**: Algorithm coordination and post-processing
- **Generation Algorithms**: Room-corridor, BSP, cellular automata
- **TileSetBuilder**: Texture and tile group creation

### Persistence Layer
- **Core Data**: Local data storage and object management
- **CloudKit**: Cross-device synchronization
- **Configuration**: Settings and preferences

## Data Flow

### Generation Phase
1. **Configuration** → `DungeonConfig` defines parameters
2. **Algorithm Selection** → `DungeonGenerator` chooses implementation
3. **Generation** → Algorithm creates `DungeonMap`
4. **Post-Processing** → Floor variants and optimizations
5. **Tile Building** → `TileSetBuilder` creates visual assets

### Gameplay Phase
1. **Input** → User actions create movement requests
2. **Validation** → `DungeonMap` checks movement legality
3. **Entity Update** → Positions and states change
4. **AI Processing** → `Pathfinder` calculates monster movement
5. **Visibility** → `FOV` updates visible tiles
6. **Rendering** → SpriteKit draws current state

### Update Loop
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

## Component Interactions

### Entity-Map Interaction
- Entities query `DungeonMap` for movement validation
- Map provides collision and visibility information
- Entities update their grid positions through map constraints

### Generation-Rendering Bridge
- `TileSetBuilder` converts logical tiles to visual assets
- `TileRefs` provides efficient access to tile groups
- Texture caching optimizes memory usage

### AI-Systems Integration
- `Pathfinder` uses map data for navigation
- `FOV` tracks exploration state
- Monster AI combines pathfinding with visibility data

## Performance Optimizations

### Memory Management
- Texture caching in `TileSetBuilder`
- Object pooling for frequently created entities
- Lazy loading of visual assets

### Computational Efficiency
- A* pathfinding with early termination
- Incremental FOV updates
- Batch tile updates for rendering

### Scalability
- Configurable complexity parameters
- Adaptive quality based on device performance
- Modular algorithm implementations

## Extension Points

The architecture supports extension through:

### Custom Algorithms
Implement `DungeonGenerating` protocol for new generation methods

### Additional Entities
Extend `Entity` class hierarchy for new game objects

### New Systems
Add processing systems that operate on game state

### Rendering Enhancements
Extend `TileSetBuilder` for visual effects and animations

## Testing Strategy

- **Unit Tests**: Algorithm correctness and edge cases
- **Integration Tests**: Component interaction validation
- **UI Tests**: User flow and screenshot regression
- **Performance Tests**: Generation time and memory usage

This architecture ensures maintainability while supporting the complex requirements of real-time dungeon exploration gameplay.