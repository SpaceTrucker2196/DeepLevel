# Dungeon Generation Algorithms

Understand the different algorithms available for creating varied dungeon layouts.

## Overview

DeepLevel offers three distinct algorithms for dungeon generation, each producing unique characteristics and gameplay experiences. Understanding these algorithms helps you choose the right approach for your game's needs.

## Room-and-Corridor Algorithm

The traditional approach that creates rectangular rooms connected by L-shaped corridors.

### Characteristics
- **Structure**: Clean, architectural layouts with distinct rooms
- **Connectivity**: Guaranteed connectivity between all areas
- **Doors**: Automatic door placement at room entrances
- **Secret Rooms**: Optional hidden areas with secret doors

### Best For
- Traditional dungeon crawlers
- Grid-based movement games
- Games requiring predictable room layouts

### Configuration
```swift
var config = DungeonConfig()
config.algorithm = .roomsCorridors
config.maxRooms = 20
config.roomMinSize = 4
config.roomMaxSize = 10
config.secretRoomChance = 0.08
```

## Binary Space Partitioning (BSP)

Recursively divides space into smaller regions, creating more organic room arrangements.

### Characteristics
- **Structure**: Varied room sizes with natural clustering
- **Layout**: Tree-based connectivity following partition hierarchy
- **Flexibility**: Adapts to different space constraints
- **Organic Feel**: Less rigid than room-and-corridor

### Best For
- Exploration-focused games
- Varied pacing with different room densities
- More realistic architectural layouts

### Configuration
```swift
var config = DungeonConfig()
config.algorithm = .bsp
config.bspMaxDepth = 5
config.roomMinSize = 4
config.roomMaxSize = 10
```

## Cellular Automata

Creates cave-like structures using iterative smoothing rules.

### Characteristics
- **Structure**: Organic, natural cave systems
- **Connectivity**: Single large connected area
- **Irregularity**: No geometric patterns or straight lines
- **Realism**: Resembles natural cave formations

### Best For
- Cave exploration games
- Organic, natural environments
- Survival or mining games

### Configuration
```swift
var config = DungeonConfig()
config.algorithm = .cellular
config.cellularFillProb = 0.45  // Initial wall density
config.cellularSteps = 5        // Smoothing iterations
```

## Algorithm Comparison

| Feature | Room-Corridor | BSP | Cellular |
|---------|---------------|-----|----------|
| Room Definition | Explicit rectangular rooms | Varied organic rooms | Open cave areas |
| Connectivity | Corridor network | Hierarchical tree | Single large space |
| Predictability | High | Medium | Low |
| Navigation | Grid-friendly | Moderate complexity | Freeform |
| Doors | Automatic placement | Possible | Not applicable |

## Performance Considerations

- **Room-Corridor**: O(width × height + maxRooms²)
- **BSP**: O(width × height + 2^maxDepth)
- **Cellular**: O(width × height × cellularSteps)

## Combining Algorithms

You can create hybrid approaches by:
1. Generating base structure with one algorithm
2. Post-processing with elements from another
3. Using different algorithms for different dungeon levels

## Next Steps

Learn how these algorithms integrate into the overall system architecture in <doc:Game-Architecture>.