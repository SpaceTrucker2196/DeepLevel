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
config.roomBorders = true  // Add 1-tile borders around rooms
config.cityLayout = true   // Enable city layout with 6x6 blocks and wide streets
config.streetWidth = 4     // 4-tile wide streets
config.cityBlockSize = 6   // 6x6 tile city blocks
```

### Room Borders

Enable `roomBorders` to add 1-tile thick wall borders around each room, creating a sidewalk-like effect around rooms similar to city blocks. This feature:

- Provides visual separation between rooms and corridors
- Creates more architectural layouts with defined room boundaries
- Reduces interior room space but maintains the same room placement
- Works with all dungeon generation algorithms

When enabled, a 6x4 room becomes a 4x2 interior with 1-tile walls on all sides.

### City Layout

Enable `cityLayout` to transform the traditional dungeon into a modern city grid. This feature:

- Creates 6x6 tile city blocks instead of variable-sized rooms
- Generates 4-tile wide streets with 1-tile sidewalk borders on each side
- Places driveways instead of doors to connect city blocks to streets
- Uses a regular grid pattern for predictable urban navigation
- Adds new tile types: `sidewalk` for walkable street borders and `driveway` for block entrances

When enabled with default settings, the city uses a regular grid where each city block is 6x6 tiles, separated by 6-tile wide streets (4 tiles of street + 2 tiles of sidewalk borders).

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
config.roomBorders = true  // Add 1-tile borders around rooms
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

| Feature | Room-Corridor | Room-Corridor (City) | BSP | Cellular |
|---------|---------------|---------------------|-----|----------|
| Room Definition | Explicit rectangular rooms | 6x6 city blocks | Varied organic rooms | Open cave areas |
| Connectivity | Corridor network | Grid street system | Hierarchical tree | Single large space |
| Predictability | High | Very High | Medium | Low |
| Navigation | Grid-friendly | City grid navigation | Moderate complexity | Freeform |
| Doors | Automatic placement | Driveways to streets | Possible | Not applicable |
| Street Layout | Single-tile corridors | 4-tile wide streets with sidewalks | Variable corridors | N/A |

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