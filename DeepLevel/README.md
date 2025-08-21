# deeplevel – Advanced SpriteKit Dungeon Crawler Starter

This expanded template adds multiple procedural generation algorithms, fog-of-war, an entity system, pathfinding, and more.

## Features Implemented
1. Procedural Generation Algorithms
   - Rooms & corridors (with doors + secret rooms)
   - BSP partitioning
   - Cellular Automata caves
2. SKTileMapNode for efficient tile rendering.
3. Field of View / Fog of War (symmetric shadowcasting).
4. Entity system (Player + Monsters).
5. A* pathfinding for monsters (periodically recomputed).
6. Floor biome / variation via Perlin noise (tile variants).
7. Seeded generation (press T for timestamp seed; R for random).
8. Camera smoothing (lerp).
9. Doors & secret doors (open when walked into).
10. Simple combat (move into monster = attack; space to let monsters take a turn).

## Controls (macOS)
- Movement: WASD or Arrow Keys
- R: Regenerate with random seed
- T: Regenerate with deterministic seed (current timestamp)
- F: Cycle generation algorithm
- Space: Skip turn (monsters path toward you)
- Move into closed/secret door: Opens it
- Move into monster: Attack it

## Algorithms
- Rooms & Corridors: Classic overlapping room placement with connectors, plus probabilistic secret rooms.
- BSP: Binary space partition splits, rooms in leaves, connectors along partitions.
- Cellular: Standard cellular automata with configurable fill probability and smoothing steps.

## Extend Further
- Replace runtime-generated textures with real art (TileSetBuilder).
- Implement granular fog overlay (per-tile alpha) or shader-based masking.
- Add inventory & item pickups (EntityKind.item).
- Introduce turn-based scheduling / energy system.
- Add ranged FOV (light sources) and lighting colors.
- Optimize pathfinding (cache flow fields or use Dijkstra maps).
- Use GKComponent / GKEntity for more complex ECS patterns.

## Configuration
See DungeonConfig for parameters (width, height, algorithm, cellular / BSP tuning, secretRoomChance).

## Notes
- Fog layer currently global; for per-tile darkness, maintain an overlay node per tile or a custom shader.
- Secret door reveals when the tile is opened (walked into).
- Pathfinding can be throttled further for performance (only some monsters per tick).

## License
(Choose a license and add it here.)