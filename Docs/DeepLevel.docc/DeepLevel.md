# ``DeepLevel``

A comprehensive dungeon generation and exploration game built with SpriteKit.

## Overview

DeepLevel is a sophisticated dungeon generation system that provides multiple algorithms for creating diverse and engaging underground environments. The game features real-time exploration with field-of-view calculations, pathfinding AI, and interactive gameplay elements.

The system supports three distinct generation algorithms:
- **Room-and-Corridor**: Traditional rectangular rooms connected by passages
- **Binary Space Partitioning (BSP)**: Organic room layouts through recursive space division  
- **Cellular Automata**: Cave-like structures with natural, irregular formations

## Topics

### Essentials

- ``GameScene``
- ``DungeonMap``
- ``Entity``
- ``TileKind``

### Dungeon Generation

- ``DungeonGenerating``
- ``DungeonGenerator``
- ``RoomsGenerator``
- ``BSPGenerator``
- ``CellularAutomataGenerator``
- ``DungeonConfig``

### Game Systems

- ``Pathfinder``
- ``FOV``
- ``TileSetBuilder``
- ``HUD``

### Core Types

- ``Tile``
- ``Rect``
- ``SeededGenerator``

### Advanced

- ``Monster``
- ``PersistenceController``

## Articles

- <doc:Getting-Started>
- <doc:Dungeon-Algorithms>
- <doc:Game-Architecture>