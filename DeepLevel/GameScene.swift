import SpriteKit
import GameplayKit
import QuartzCore

/// The main game scene managing dungeon exploration gameplay.
///
/// Coordinates all aspects of the dungeon exploration experience including
/// procedural generation, real-time rendering, entity management, AI behavior,
/// field-of-view calculations, and user interaction. Serves as the central
/// controller integrating multiple game systems for cohesive gameplay.
///
/// The scene supports multiple generation algorithms, player movement with
/// collision detection, monster AI with pathfinding, dynamic lighting through
/// fog-of-war, and interactive camera controls. All operations are optimized
/// for real-time performance in SpriteKit.
///
/// ## Key Systems
/// - **Generation**: Multiple dungeon algorithms with configurable parameters
/// - **Rendering**: Efficient tile-based rendering with texture caching
/// - **Entities**: Player character and AI-controlled monsters
/// - **Field of View**: Realistic line-of-sight with exploration tracking
/// - **Input**: Touch and keyboard input for movement and interaction
/// - **Camera**: Smooth following camera with HUD overlay
///
/// - Since: 1.0.0
/// - Note: This is a complex scene class managing multiple game systems
/// - Warning: Ensure proper initialization through didMove(to:) before use
final class GameScene: SKScene {
    // MARK: - Config / State
    private var config = DungeonConfig()
    private var map: DungeonMap?
    private var currentSeed: UInt64? = nil
    
    // Tile assets
    private var tileMap: SKTileMapNode?
    private var tileRefs: TileSetBuilder.TileRefs?
    
    // Entities
    private var player: Player?
    private var monsters: [Monster] = []
    private var charmedEntities: [Charmed] = []
    
    // Camera / HUD
    private var camNode: SKCameraNode?
    private let hud = HUD()
    private var cameraLerp: CGFloat = 0.18
    
    // FOV
    private var fogNode: SKSpriteNode?
    private var fogOfWar: FogOfWar?
    private let fovRadius: Int = 5
    
    // Particle effects
    private var particleManager: ParticleEffectsManager?
    
    // Parallax sky for cityMap
    private var parallaxSky: ParallaxSky?
    
    // Algorithm rotation
    private var pendingAlgoIndex = 3  // Start with cityMap (index 3) to match DungeonConfig default
    private let algorithms: [GenerationAlgorithm] = [.roomsCorridors, .bsp, .cellular, .cityMap]
    
    // Movement (tap or queued)
    private var movementDir: (dx: Int, dy: Int) = (0,0)
    
    // Path planning for tap-to-move
    private var plannedPath: [(Int, Int)] = []
    private var footstepNodes: [SKSpriteNode] = []
    private var currentPathIndex: Int = 0
    private var isExecutingPath: Bool = false
    
    // Monster path timing
    private var lastMonsterPathUpdate: TimeInterval = 0
    private var monsterPathInterval: TimeInterval = 1.0
    
    // Sizing
    private let tileSize: CGFloat = 72
    
    // Debug
    private let debugLogging = false
    
    // Charmed entity tracking
    private var charmedScore: Int = 0
    
    // Initialization guard (SpriteKit may call didMove multiple times if scene is re-presented)
    private var initialized = false
    
    // MARK: - Scene Lifecycle
    /// Initializes the game scene when first presented to a view.
    ///
    /// Sets up all game systems including camera, tile rendering, dungeon
    /// generation, and HUD display. Uses an initialization guard to prevent
    /// duplicate setup if the scene is re-presented.
    ///
    /// - Parameter view: The SKView that will present this scene
    override func didMove(to view: SKView) {
        guard !initialized else { return }
        initialized = true
        backgroundColor = .black
        setupCameraIfNeeded()
        setupParallaxSky()
        buildTileSetIfNeeded()
        
        // Initialize particle effects manager
        particleManager = ParticleEffectsManager(scene: self, tileSize: tileSize)
        
        generateDungeon(seed: nil)
        setupHUD()
        if debugLogging { print("[GameScene] didMove complete") }
    }
    
    // MARK: - Public API for Testing
    /// Returns the available algorithms for testing purposes.
//    func getAvailableAlgorithms() -> [GenerationAlgorithm] {
//        return algorithms
//    }
//    
    /// Returns the current algorithm index for testing purposes.
    func getCurrentAlgorithmIndex() -> Int {
        return pendingAlgoIndex % algorithms.count
    }
    
    // MARK: - Public API (e.g., for SwiftUI buttons)
    /// Regenerates the dungeon with a new or existing seed.
    ///
    /// Triggers complete dungeon regeneration using the current algorithm
    /// settings and the specified seed for deterministic or random generation.
    ///
    /// - Parameter seed: Optional seed for deterministic generation, nil for random
    func regenerate(seed: UInt64?) {
        generateDungeon(seed: seed)
    }
    
    /// Cycles to the next available generation algorithm.
    ///
    /// Advances through the available generation algorithms in sequence
    /// and immediately regenerates the dungeon using the new algorithm
    /// with the current seed.
    func cycleAlgorithm() {
        pendingAlgoIndex = (pendingAlgoIndex + 1) % algorithms.count
        regenerate(seed: currentSeed)
    }
    
    /// Returns the array of available algorithms for testing purposes.
    ///
    /// - Returns: Array of all available generation algorithms
    func getAvailableAlgorithms() -> [GenerationAlgorithm] {
        return algorithms
    }
    
//    /// Returns the currently selected algorithm index for testing purposes.
//    ///
//    /// - Returns: The current algorithm index
//    func getCurrentAlgorithmIndex() -> Int {
//        return pendingAlgoIndex
//    }
    
    // MARK: - Setup Helpers
    private func setupCameraIfNeeded() {
        if camNode == nil {
            let cam = SKCameraNode()
            self.camera = cam
            addChild(cam)
            cam.addChild(hud)
            camNode = cam
        }
    }
    
    // MARK: - Parallax Sky Setup
    private func setupParallaxSky() {
        // Only setup parallax sky for cityMap algorithm
        guard algorithms[pendingAlgoIndex % algorithms.count] == .cityMap else { return }
        
        parallaxSky?.removeFromParent()
        let sky = ParallaxSky(sceneSize: size)
        addChild(sky)
        parallaxSky = sky
        
        if debugLogging { print("[GameScene] setupParallaxSky complete for cityMap") }
    }
    
    private func buildTileSetIfNeeded() {
        guard tileRefs == nil || tileMap == nil else { return }
        let (tileSet, refs) = TileSetBuilder.build(tileSize: tileSize)
        tileRefs = refs
        if tileMap == nil {
            let mapNode = SKTileMapNode(tileSet: tileSet,
                                        columns: 1,
                                        rows: 1,
                                        tileSize: CGSize(width: tileSize, height: tileSize))
            mapNode.anchorPoint = CGPoint(x: 0, y: 0)
            mapNode.zPosition = 0
            addChild(mapNode)
            tileMap = mapNode
        } else {
            tileMap?.tileSet = tileSet
        }
    }
    
    private func setupHUD() {
        hud.position = .zero
        updateHUD()
    }
    
    // MARK: - Generation
    private func generateDungeon(seed: UInt64?) {
        buildTileSetIfNeeded()
        guard let _ = tileRefs else {
            assertionFailure("Tile references missing before generation.")
            return
        }
        currentSeed = seed
        var cfg = config
        cfg.seed = seed
        cfg.algorithm = algorithms[pendingAlgoIndex % algorithms.count]
        
        let generator = DungeonGenerator(config: cfg)
        let newMap = generator.generate()
        self.map = newMap
        
        buildTileMap()
        createFireHydrantEffects()
        placePlayer()
        spawnMonsters()
        spawnCharmed()
        recomputeFOV()
        updateHUD()
        
        // Update parallax sky for cityMap
        if algorithms[pendingAlgoIndex % algorithms.count] == .cityMap {
            setupParallaxSky()
            if let player = player, let sky = parallaxSky {
                sky.centerOn(position: CGPoint(x: CGFloat(player.gridX) * tileSize, 
                                             y: CGFloat(player.gridY) * tileSize))
            }
        }
    }
    
    private func buildTileMap() {
        guard let map = map,
              let tileRefs = tileRefs else { return }
        buildTileSetIfNeeded()
        guard let tileMap = tileMap else { return }
        
        tileMap.removeAllChildren()
        tileMap.numberOfColumns = map.width
        tileMap.numberOfRows = map.height
        
        for y in 0..<map.height {
            for x in 0..<map.width {
                let tile = map.tiles[map.index(x: x, y: y)]
                let group: SKTileGroup
                switch tile.kind {
                case .floor:
                    let maxIndex = tileRefs.floorVariants.count - 1
                    let clamped = max(0, min(maxIndex, tile.variant))
                    group = tileRefs.floorVariants[clamped]
                case .wall: group = tileRefs.wall
                case .doorClosed: group = tileRefs.door
                case .doorSecret: group = tileRefs.secretDoor
                case .sidewalk: group = tileRefs.sidewalk
                case .driveway: group = tileRefs.driveway
                case .hidingArea: group = tileRefs.hidingArea
                case .park: group = tileRefs.park
                case .residential1: group = tileRefs.residential1
                case .residential2: group = tileRefs.residential2
                case .residential3: group = tileRefs.residential3
                case .residential4: group = tileRefs.residential4
                case .urban1: group = tileRefs.urban1
                case .urban2: group = tileRefs.urban2
                case .urban3: group = tileRefs.urban3
                case .redLight: group = tileRefs.redLight
                case .retail: group = tileRefs.retail
                case .sidewalkTree: group = tileRefs.sidewalkTree
                case .sidewalkHydrant: group = tileRefs.sidewalkHydrant
                case .street: group = tileRefs.street
                @unknown default:
                    fatalError("Unhandled TileKind: \(tile.kind)")
                }
                tileMap.setTileGroup(group, forColumn: x, row: y)
            }
        }
        
        // Setup enhanced fog of war system
        fogNode?.removeFromParent()
        fogOfWar?.removeFromParent()
        
        // Use enhanced fog of war for cityMap, simple fog for other algorithms
        if algorithms[pendingAlgoIndex % algorithms.count] == .cityMap {
            let enhancedFog = FogOfWar(mapWidth: map.width, mapHeight: map.height, tileSize: tileSize)
            addChild(enhancedFog)
            fogOfWar = enhancedFog
            fogNode = nil
        } else {
            let fog = SKSpriteNode(color: .black,
                                   size: CGSize(width: CGFloat(map.width)*tileSize,
                                                height: CGFloat(map.height)*tileSize))
            fog.anchorPoint = CGPoint(x: 0, y: 0)
            fog.alpha = 0.0
            addChild(fog)
            fogNode = fog
            fogOfWar = nil
        }
        
        if debugLogging { print("[GameScene] buildTileMap complete") }
    }
    
    private func refreshTile(x: Int, y: Int) {
        guard let map = map,
              let tileRefs = tileRefs,
              let tileMap = tileMap,
              map.inBounds(x, y) else { return }
        let idx = map.index(x: x, y: y)
        let tile = map.tiles[idx]
        let group: SKTileGroup
        switch tile.kind {
        case .floor:
            let maxIndex = tileRefs.floorVariants.count - 1
            let clamped = max(0, min(maxIndex, tile.variant))
            group = tileRefs.floorVariants[clamped]
        case .wall: group = tileRefs.wall
        case .doorClosed: group = tileRefs.door
        case .doorSecret: group = tileRefs.secretDoor
        case .sidewalk: group = tileRefs.sidewalk
        case .driveway: group = tileRefs.driveway
        case .hidingArea: group = tileRefs.hidingArea
        case .park: group = tileRefs.park
        case .residential1: group = tileRefs.residential1
        case .residential2: group = tileRefs.residential2
        case .residential3: group = tileRefs.residential3
        case .residential4: group = tileRefs.residential4
        case .urban1: group = tileRefs.urban1
        case .urban2: group = tileRefs.urban2
        case .urban3: group = tileRefs.urban3
        case .redLight: group = tileRefs.redLight
        case .retail: group = tileRefs.retail
        case .sidewalkTree: group = tileRefs.sidewalkTree
        case .sidewalkHydrant: group = tileRefs.sidewalkHydrant
        case .street: group = tileRefs.street
        @unknown default:
            fatalError("Unhandled TileKind: \(tile.kind)")
        }
        tileMap.setTileGroup(group, forColumn: x, row: y)
    }
    
    // MARK: - Entities
    private func placePlayer() {
        guard let map = map else { return }
        player?.removeFromParent()
        let start = map.playerStart
        let p = Player(gridX: start.0,
                       gridY: start.1,
                       tileSize: tileSize)
        addChild(p)
        p.moveTo(gridX: p.gridX, gridY: p.gridY, tileSize: tileSize, animated: false)
        player = p
        
        // Add movement trail for player
        particleManager?.addMovementTrail(to: p)
    }
    
    /// Helper method to move an entity and trigger trail effect
    private func moveEntityWithTrail(_ entity: Entity, to position: (Int, Int)) {
        let oldPosition = (entity.gridX, entity.gridY)
        entity.moveTo(gridX: position.0, gridY: position.1, tileSize: tileSize)
        particleManager?.onEntityMove(entity, from: oldPosition)
    }
    
    /// Creates a passable function for pathfinding based on entity's blocking tiles
    private func createPassableFunction(for entity: Entity) -> (TileKind) -> Bool {
        return { tileKind in
            return !entity.blockingTiles.contains(tileKind)
        }
    }

    /// Creates particle effects for all fire hydrant tiles on the map
    private func createFireHydrantEffects() {
        guard let map = map, let particleManager = particleManager else { return }
        
        // Remove any existing fire hydrant effects
        particleManager.removeAllEffects()
        
        // Scan the map for fire hydrant tiles
        for y in 0..<map.height {
            for x in 0..<map.width {
                let tile = map.tiles[map.index(x: x, y: y)]
                if tile.kind == .sidewalkHydrant {
                    // Create particle effect with configurable offset
                    // Using small random offsets to make hydrants feel more natural
                    let offsetX: CGFloat = CGFloat.random(in: -8...8)
                    let offsetY: CGFloat = CGFloat.random(in: -8...8)
                    particleManager.createFireHydrantEffect(at: x, y: y, offsetX: offsetX, offsetY: offsetY)
                }
            }
        }
    }

    private func spawnMonsters() {
            guard let map = map,
                  let player = player else { return }
            monsters.forEach { $0.removeFromParent() }
            monsters = []
            
            for _ in 0..<5 {
                var attempts = 0
                while attempts < 50 {
                    attempts += 1
                    let x = Int.random(in: 0..<map.width)
                    let y = Int.random(in: 0..<map.height)
                    let t = map.tiles[map.index(x: x, y: y)]
                    
                    // Updated condition: allow floor or street (or anything marked spawnable)
                    if t.kind.isSpawnSurface && (x, y) != (player.gridX, player.gridY) {
                        let m = Monster(gridX: x, gridY: y, tileSize: tileSize)
                        addChild(m)
                        m.moveTo(gridX: x, gridY: y, tileSize: tileSize, animated: false)
                        monsters.append(m)
                        
                        // Add movement trail for monster
                        particleManager?.addMovementTrail(to: m)
                        
                        break
                    }
                }
            }
        }
        
        private func spawnCharmed() {
            guard let map = map,
                  let player = player else { return }
            charmedEntities.forEach { $0.removeFromParent() }
            charmedEntities = []
            charmedScore = 0
            
            for _ in 0..<13 {
                var attempts = 0
                while attempts < 50 {
                    attempts += 1
                    let x = Int.random(in: 0..<map.width)
                    let y = Int.random(in: 0..<map.height)
                    let t = map.tiles[map.index(x: x, y: y)]
                    
                    if t.kind.isSpawnSurface &&
                       (x, y) != (player.gridX, player.gridY) &&
                       !monsters.contains(where: { $0.gridX == x && $0.gridY == y }) {
                        
                        let c = Charmed(gridX: x, gridY: y, tileSize: tileSize)
                        addChild(c)
                        c.moveTo(gridX: x, gridY: y, tileSize: tileSize, animated: false)
                        charmedEntities.append(c)
                        
                        // Add movement trail for charmed entity
                        particleManager?.addMovementTrail(to: c)
                        
                        break
                    }
                }
            }
        }
    
    
    // MARK: - HUD / Camera
    private func updateHUD() {
        guard let player = player else { return }
        hud.update(seed: currentSeed,
                   hp: player.hp,
                   algo: algorithms[pendingAlgoIndex % algorithms.count],
                   charmedScore: charmedScore,
                   size: size)
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateHUD()
    }
    
    private func updateCamera() {
        guard let player = player,
              let camNode = camNode else { return }
        let target = CGPoint(x: CGFloat(player.gridX)*tileSize + tileSize/2,
                             y: CGFloat(player.gridY)*tileSize + tileSize/2)
        camNode.position = camNode.position.lerp(to: target, t: cameraLerp)
        
        // Update parallax sky if present
        if let parallaxSky = parallaxSky {
            parallaxSky.updateParallax(cameraPosition: camNode.position)
        }
    }
    
    // MARK: - Game Loop
    /// Main update loop called each frame by SpriteKit.
    ///
    /// Coordinates all real-time game systems including player movement,
    /// camera tracking, and monster AI updates. Throttles expensive
    /// operations like pathfinding to maintain consistent performance.
    ///
    /// - Parameter currentTime: Current time in seconds since scene start
    override func update(_ currentTime: TimeInterval) {
        updatePlayerMovement()
        updateCamera()
        
        // Update particle effects
        particleManager?.updateMovementTrails(currentTime: currentTime)
        
        if currentTime - lastMonsterPathUpdate > monsterPathInterval {
            updateMonsters()
            updateCharmed()
            updateEntityTransparency()  // Update transparency for entities in hiding areas
            lastMonsterPathUpdate = currentTime
        }
    }
    
    // MARK: - Movement / Combat
    /// Processes pending player movement commands.
    ///
    /// Handles both path execution and legacy directional movement.
    /// For path execution, moves one step at a time along the planned route.
    /// Called each frame to provide responsive controls.
    private func updatePlayerMovement() {
        // Handle path execution
        if isExecutingPath && !plannedPath.isEmpty && currentPathIndex < plannedPath.count {
            executeNextStepInPath()
            return
        }
        
        // Handle legacy directional movement
        guard movementDir.dx != 0 || movementDir.dy != 0 else { return }
        tryMovePlayer(dx: movementDir.dx, dy: movementDir.dy)
        movementDir = (0,0)
    }
    
    /// Executes the next step in the planned path.
    private func executeNextStepInPath() {
        guard let player = player,
              currentPathIndex < plannedPath.count else {
            clearPlannedPath()
            return
        }
        
        let nextPosition = plannedPath[currentPathIndex]
        
        // Check for monsters within 2 tiles and evade if necessary
        if shouldEvadeMonsters(playerPosition: nextPosition) {
            if debugLogging {
                print("[GameScene] Monster within 2 tiles during path execution, seeking hiding spot")
            }
            handleMonsterDetection()
            return
        }
        
        // Check for monsters that can see the player during movement
        if checkForMonsterDetection() {
            if debugLogging {
                print("[GameScene] Monster detected during path execution, seeking hiding spot")
            }
            handleMonsterDetection()
            return
        }
        
        // Execute the movement
        let success = tryMovePlayerToPosition(nextPosition.0, nextPosition.1)
        
        if success {
            // Remove the footstep we just reached
            if currentPathIndex < footstepNodes.count {
                let footstep = footstepNodes[currentPathIndex]
                footstep.removeFromParent()
                // Don't remove from array yet for performance - will be cleared when path completes
            }
            
            currentPathIndex += 1
            
            // Check if we've reached the end of the path
            if currentPathIndex >= plannedPath.count {
                if debugLogging {
                    print("[GameScene] Path execution completed")
                }
                clearPlannedPath()
            }
        } else {
            // Movement failed (blocked), clear the path
            if debugLogging {
                print("[GameScene] Movement blocked, clearing path")
            }
            clearPlannedPath()
        }
    }
    
    /// Checks if any monster can see the player and vice versa.
    ///
    /// Only triggers during path execution to avoid interrupting single steps.
    ///
    /// - Returns: True if mutual line of sight exists between player and any monster
    private func checkForMonsterDetection() -> Bool {
        guard let player = player,
              let map = map,
              plannedPath.count > 2 else { return false } // Only check for longer paths
        
        for monster in monsters {
            // Check if monster can see player
            let monsterCanSeePlayer = FOV.hasLineOfSight(map: map,
                                                        fromX: monster.gridX,
                                                        fromY: monster.gridY,
                                                        toX: player.gridX,
                                                        toY: player.gridY)
            
            // Check if player can see monster
            let playerCanSeeMonster = FOV.hasLineOfSight(map: map,
                                                        fromX: player.gridX,
                                                        fromY: player.gridY,
                                                        toX: monster.gridX,
                                                        toY: monster.gridY)
            
            // If both can see each other, we have mutual line of sight
            if monsterCanSeePlayer && playerCanSeeMonster {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if the player should evade monsters within 2 tiles
    private func shouldEvadeMonsters(playerPosition: (Int, Int)) -> Bool {
        for monster in monsters {
            let dx = abs(monster.gridX - playerPosition.0)
            let dy = abs(monster.gridY - playerPosition.1)
            if dx <= 2 && dy <= 2 {
                return true
            }
        }
        return false
    }
    
    /// Handles monster detection by pathfinding to the nearest hiding spot.
    private func handleMonsterDetection() {
        guard let player = player,
              let map = map else {
            clearPlannedPath()
            return
        }
        
        // Find the nearest explored hiding spot
        if let hidingSpot = findNearestExploredHidingSpot() {
            if debugLogging {
                print("[GameScene] Found hiding spot at (\(hidingSpot.0), \(hidingSpot.1))")
            }
            // Clear current path and plan route to hiding spot
            clearPlannedPath()
            planAndExecutePath(to: hidingSpot)
        } else {
            if debugLogging {
                print("[GameScene] No hiding spot found, stopping movement")
            }
            // No hiding spot found, stop movement
            clearPlannedPath()
        }
    }
    
    /// Finds the nearest explored hiding spot.
    ///
    /// - Returns: Grid coordinates of the nearest hiding spot, or nil if none found
    private func findNearestExploredHidingSpot() -> (Int, Int)? {
        guard let player = player,
              let map = map else { return nil }
        
        var nearestHidingSpot: (Int, Int)? = nil
        var shortestDistance = Int.max
        
        for y in 0..<map.height {
            for x in 0..<map.width {
                let tile = map.tiles[map.index(x: x, y: y)]
                
                // Check if this is an explored hiding spot
                if tile.explored && tile.providesConcealment {
                    let distance = abs(x - player.gridX) + abs(y - player.gridY)
                    if distance < shortestDistance && distance > 0 { // Don't select current position
                        shortestDistance = distance
                        nearestHidingSpot = (x, y)
                    }
                }
            }
        }
        
        return nearestHidingSpot
    }
    
    /// Cleans up path-related resources when the scene is about to be deallocated.
    private func cleanupPathSystem() {
        clearPlannedPath()
    }
    
    /// Attempts to move the player in the specified direction.
    ///
    /// Validates movement against map boundaries and tile collision,
    /// handles door interactions, monster combat, and updates field
    /// of view after successful movement.
    ///
    /// - Parameters:
    ///   - dx: X direction offset (-1, 0, or 1)
    ///   - dy: Y direction offset (-1, 0, or 1)
    private func tryMovePlayer(dx: Int, dy: Int) {
        guard let player = player else { return }
        let nx = player.gridX + dx
        let ny = player.gridY + dy
        _ = tryMovePlayerToPosition(nx, ny)
    }
    
    /// Attempts to move the player to a specific grid position.
    ///
    /// Validates movement against map boundaries and tile collision,
    /// handles door interactions, monster combat, and updates field
    /// of view after successful movement.
    ///
    /// - Parameters:
    ///   - nx: Target X grid coordinate
    ///   - ny: Target Y grid coordinate
    /// - Returns: True if movement was successful, false otherwise
    private func tryMovePlayerToPosition(_ nx: Int, _ ny: Int) -> Bool {
        guard var map = map,
              let player = player else { return false }
        
        guard map.inBounds(nx, ny) else { return false }
        let idx = map.index(x: nx, y: ny)
        var tile = map.tiles[idx]
        
        if tile.kind == .doorClosed || tile.kind == .doorSecret || tile.kind == .driveway {
            tile.kind = .floor
            map.tiles[idx] = tile
            self.map = map
            refreshTile(x: nx, y: ny)
            recomputeFOV()
            return false // Don't move this turn, just open the door
        }
        guard !tile.blocksMovement else { return false }
        
        if let monster = monsters.first(where: { $0.gridX == nx && $0.gridY == ny }) {
            attackMonster(monster)
            return false // Don't move this turn, just attack
        }
        
        // Check for charmed entity collision
        if let charmed = charmedEntities.first(where: { $0.gridX == nx && $0.gridY == ny }) {
            charmEntity(charmed)
            return false // Don't move this turn, just charm
        }
        
        // Capture old position for trail effect
        let oldPosition = (player.gridX, player.gridY)
        
        player.moveTo(gridX: nx, gridY: ny, tileSize: tileSize)
        self.map = map
        
        // Trigger movement trail effect
        particleManager?.onEntityMove(player, from: oldPosition)
        
        // Mark adjacent tiles as explored when moving
        markAdjacentTilesAsExplored()
        
        recomputeFOV()
        
        // Check for healing when charmed entities are nearby in hiding areas
        checkCharmedHealing()
        
        return true
    }
    
    /// Marks all tiles adjacent to the player as explored.
    ///
    /// This implements the requirement that adjacent tiles to the player's
    /// position are considered explored territory.
    private func markAdjacentTilesAsExplored() {
        guard var map = map,
              let player = player else { return }
        
        // Check all 8 adjacent tiles (including diagonals)
        let directions = [(-1, -1), (-1, 0), (-1, 1),
                         (0, -1),           (0, 1),
                         (1, -1),  (1, 0),  (1, 1)]
        
        for (dx, dy) in directions {
            let adjX = player.gridX + dx
            let adjY = player.gridY + dy
            
            if map.inBounds(adjX, adjY) {
                let idx = map.index(x: adjX, y: adjY)
                map.tiles[idx].explored = true
            }
        }
        
        self.map = map
        
        // Update fog of war to reflect new exploration
        if let fogOfWar = fogOfWar {
            fogOfWar.updateFog(for: map)
        }
    }
    
    private func attackMonster(_ monster: Monster) {
        monster.hp -= 1
        monster.run(.sequence([
            .scale(to: 1.2, duration: 0.05),
            .scale(to: 1.0, duration: 0.05)
        ]))
        if monster.hp <= 0 {
            monster.removeFromParent()
            monsters.removeAll { $0 === monster }
        }
        if debugLogging { print("[GameScene] Monster attacked, hp now \(monster.hp)") }
    }
    
    private func charmEntity(_ charmed: Charmed) {
        guard let player = player else { return }
        
        if !charmed.isCharmed {
            charmed.isCharmed = true
            charmedScore += 1  // Increment score when charming
            charmed.run(.sequence([
                .scale(to: 1.3, duration: 0.1),
                .scale(to: 1.0, duration: 0.1)
            ]))
            // Change color to indicate charmed status
            charmed.color = .systemBlue
            
            // Add heart particle effect for charmed entity
            particleManager?.addCharmedHeartEffect(to: charmed)
            
            // Heal the player
            player.heal(amount: 2)
            
            // Add pink glow effect to player
            particleManager?.addPlayerHealingGlow(to: player)
            
            updateHUD()  // Update HUD to reflect new score and HP
            if debugLogging { print("[GameScene] Entity charmed! Player healed to \(player.hp) HP") }
        }
    }
    
    private func checkCharmedHealing() {
        guard let map = map,
              let player = player else { return }
        
        // Check if player is in hiding area
        let playerTile = map.tiles[map.index(x: player.gridX, y: player.gridY)]
        guard playerTile.kind == .hidingArea else { return }
        
        // Check for charmed entities adjacent to player
        for charmed in charmedEntities {
            if charmed.isCharmed {
                let dx = abs(charmed.gridX - player.gridX)
                let dy = abs(charmed.gridY - player.gridY)
                // Adjacent means touching (including diagonally)
                if dx <= 1 && dy <= 1 && (dx + dy > 0) {
                    // Check if charmed is also in hiding area
                    let charmedTile = map.tiles[map.index(x: charmed.gridX, y: charmed.gridY)]
                    if charmedTile.kind == .hidingArea {
                        // Heal player (but not too frequently)
                        let currentTime = CACurrentMediaTime()
                        if currentTime - charmed.lastHealTime > 2.0 { // 2 second cooldown
                            player.hp += 1
                            charmed.lastHealTime = currentTime
                            updateHUD()
                            
                            // Visual feedback
                            player.run(.sequence([
                                .scale(to: 1.1, duration: 0.1),
                                .scale(to: 1.0, duration: 0.1)
                            ]))
                            
                            if debugLogging { print("[GameScene] Player healed by charmed entity! HP now \(player.hp)") }
                        }
                    }
                }
            }
        }
    }
    
    private func updateMonsters() {
        guard let map = map,
              let player = player else { return }
        for monster in monsters {
            // Check if monster can see player
            let canSeePlayer = FOV.hasLineOfSight(map: map,
                                                 fromX: monster.gridX,
                                                 fromY: monster.gridY,
                                                 toX: player.gridX,
                                                 toY: player.gridY)
            
            // Update player's visibility status
            if canSeePlayer {
                player.currentlySeen = true
            }
            
            // Add or remove police light based on visibility
            if canSeePlayer {
                particleManager?.addPoliceLight(to: monster)
            } else {
                particleManager?.removePoliceLight(from: monster)
            }
            
            if canSeePlayer {
                // Monster can see player - pursue them
                monster.lastPlayerPosition = (player.gridX, player.gridY)
                monster.roamTarget = nil // Clear any roam target
                
                let path = Pathfinder.aStar(map: map,
                                            start: (monster.gridX, monster.gridY),
                                            goal: (player.gridX, player.gridY),
                                            passable: createPassableFunction(for: monster))
                }
                if path.count > 1 {
                    let next = path[1]
                    if next.0 == player.gridX && next.1 == player.gridY {
                        player.hp -= 1
                        updateHUD()
                    } else {
                        moveEntityWithTrail(monster, to: next)
                    }
                }
            } else {
                // Monster cannot see player - roam randomly or move to last known position
                if let lastPos = monster.lastPlayerPosition {
                    // Try to move toward last known position
                    let path = Pathfinder.aStar(map: map,
                                                start: (monster.gridX, monster.gridY),
                                                goal: lastPos,
                                                passable: createPassableFunction(for: monster))
                    }
                    if path.count > 1 {
                        let next = path[1]
                        moveEntityWithTrail(monster, to: next)
                        
                        // If reached last known position, clear it and start roaming
                        if next.0 == lastPos.0 && next.1 == lastPos.1 {
                            monster.lastPlayerPosition = nil
                        }
                    } else {
                        // Can't reach last known position, start roaming
                        monster.lastPlayerPosition = nil
                    }
                } else {
                    // Roam randomly
                    roamMonster(monster: monster, map: map)
                }
            }
        }
        
        // Reset player's seen status if no monsters can see them
        let anyMonsterCanSeePlayer = monsters.contains { monster in
            FOV.hasLineOfSight(map: map,
                              fromX: monster.gridX,
                              fromY: monster.gridY,
                              toX: player.gridX,
                              toY: player.gridY)
        }
        player.currentlySeen = anyMonsterCanSeePlayer
    }
    
    private func roamMonster(monster: Monster, map: DungeonMap) {
        // If no roam target or reached current target, pick a new one
        if monster.roamTarget == nil ||
           (monster.roamTarget!.0 == monster.gridX && monster.roamTarget!.1 == monster.gridY) {
            monster.roamTarget = findRandomRoamTarget(map: map)
        }
        
        guard let target = monster.roamTarget else { return }
        
        // Move toward roam target
        let path = Pathfinder.aStar(map: map,
                                    start: (monster.gridX, monster.gridY),
                                    goal: target,
                                    passable: createPassableFunction(for: monster))
        }
        
        if path.count > 1 {
            let next = path[1]
            moveEntityWithTrail(monster, to: next)
        } else {
            // Can't reach target, pick a new one
            monster.roamTarget = findRandomRoamTarget(map: map)
        }
    }
    
    private func findRandomRoamTarget(map: DungeonMap) -> (Int, Int)? {
        // Try to find a random walkable tile
        for _ in 0..<20 { // Try up to 20 times
            let x = Int.random(in: 0..<map.width)
            let y = Int.random(in: 0..<map.height)
            let tile = map.tiles[map.index(x: x, y: y)]
            if !tile.blocksMovement {
                return (x, y)
            }
        }
        return nil
    }
    
    private func updateCharmed() {
        guard let map = map,
              let player = player else { return }
              
        for charmed in charmedEntities {
            // Check if any monster is within 2 tiles and remove charm
            if charmed.isCharmed {
                for monster in monsters {
                    let dx = abs(monster.gridX - charmed.gridX)
                    let dy = abs(monster.gridY - charmed.gridY)
                    if dx <= 2 && dy <= 2 {
                        charmed.isCharmed = false
                        charmed.color = .systemPurple  // Reset to original color
                        
                        // Remove heart particle effect when charm is lost
                        particleManager?.removeCharmedHeartEffect(from: charmed)
                        
                        if debugLogging { print("[GameScene] Charm removed by nearby monster") }
                        break
                    }
                }
            }
            
            if charmed.isCharmed {
                // Follow the player when charmed
                followPlayer(charmed: charmed, map: map, player: player)
            } else {
                // Roam randomly when not charmed
                roamCharmed(charmed: charmed, map: map)
            }
        }
    }
    
    private func followPlayer(charmed: Charmed, map: DungeonMap, player: Player) {
        // Check if charmed is in hiding area - if so, stop movement
        let currentTile = map.tiles[map.index(x: charmed.gridX, y: charmed.gridY)]
        if currentTile.kind == .hidingArea {
            return  // Stop movement when in hiding area
        }
        
        // Use pathfinding to move toward the player
        let path = Pathfinder.aStar(map: map,
                                    start: (charmed.gridX, charmed.gridY),
                                    goal: (player.gridX, player.gridY),
                                    passable: createPassableFunction(for: charmed))
        }
        
        if path.count > 1 {
            let next = path[1]
            // Don't move onto the player's position
            if next.0 != player.gridX || next.1 != player.gridY {
                // Also don't move onto monster positions
                let hasMonster = monsters.contains { $0.gridX == next.0 && $0.gridY == next.1 }
                if !hasMonster {
                    moveEntityWithTrail(charmed, to: next)
                }
            }
        }
    }
    
    private func roamCharmed(charmed: Charmed, map: DungeonMap) {
        // Check if charmed is in hiding area - if so, stop movement
        let currentTile = map.tiles[map.index(x: charmed.gridX, y: charmed.gridY)]
        if currentTile.kind == .hidingArea {
            return  // Stop movement when in hiding area
        }
        
        // If no roam target or reached current target, pick a new one
        if charmed.roamTarget == nil ||
           (charmed.roamTarget!.0 == charmed.gridX && charmed.roamTarget!.1 == charmed.gridY) {
            charmed.roamTarget = findRandomRoamTarget(map: map)
        }
        
        guard let target = charmed.roamTarget else { return }
        
        // Move toward roam target
        let path = Pathfinder.aStar(map: map,
                                    start: (charmed.gridX, charmed.gridY),
                                    goal: target,
                                    passable: createPassableFunction(for: charmed))
        }
        
        if path.count > 1 {
            let next = path[1]
            // Don't move onto the player's or monster's position
            if let player = player, (next.0 == player.gridX && next.1 == player.gridY) {
                // Skip this move
            } else {
                let hasMonster = monsters.contains { $0.gridX == next.0 && $0.gridY == next.1 }
                if !hasMonster {
                    moveEntityWithTrail(charmed, to: next)
                }
            }
        } else {
            // Can't reach target, pick a new one
            charmed.roamTarget = findRandomRoamTarget(map: map)
        }
    }
    
    private func updateEntityTransparency() {
        guard let map = map else { return }
        
        // Update player transparency
        if let player = player {
            let playerTile = map.tiles[map.index(x: player.gridX, y: player.gridY)]
            player.alpha = playerTile.kind == .hidingArea ? 0.5 : 1.0
        }
        
        // Update charmed entities transparency
        for charmed in charmedEntities {
            let charmedTile = map.tiles[map.index(x: charmed.gridX, y: charmed.gridY)]
            charmed.alpha = charmedTile.kind == .hidingArea ? 0.5 : 1.0
        }
    }
    
    // MARK: - FOV
    private func recomputeFOV() {
        guard var map = map,
              let player = player else { return }
        FOV.compute(map: &map,
                    originX: player.gridX,
                    originY: player.gridY,
                    radius: fovRadius)
        self.map = map
        
        // Update fog of war system
        if let fogOfWar = fogOfWar {
            fogOfWar.updateFog(for: map)
        }
        
        // Update fire hydrant particle visibility based on line of sight
        particleManager?.updateFireHydrantVisibility(map: map, playerX: player.gridX, playerY: player.gridY)
    }
    
    // MARK: - Touch Input (Tap to step toward tap)
    /// Handles touch input for player movement.
    ///
    /// Converts touch screen coordinates to grid coordinates and plans a path
    /// from the player's current position to the target tile. Shows footsteps
    /// along the planned route and executes movement step by step.
    ///
    /// - Parameters:
    ///   - touches: Set of touch objects representing the input
    ///   - event: The event containing the touches
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let player = player,
              let touch = touches.first,
              let map = map else { return }
        
        let location = touch.location(in: self)
        
        // Convert screen coordinates to grid coordinates
        let (gridX, gridY) = screenToGrid(location)
        
        // Validate target position
        guard map.inBounds(gridX, gridY) else { return }
        let targetTile = map.tiles[map.index(x: gridX, y: gridY)]
        guard !targetTile.blocksMovement else { return }
        
        // Plan path from player to target
        planAndExecutePath(to: (gridX, gridY))
    }
    
    /// Converts screen coordinates to grid coordinates.
    ///
    /// Accounts for camera position to ensure accurate coordinate conversion.
    ///
    /// - Parameter location: Screen coordinates relative to the scene
    /// - Returns: Grid coordinates as (x, y) tuple
    private func screenToGrid(_ location: CGPoint) -> (Int, Int) {
        // Convert coordinates relative to the scene (accounting for camera)
        let gridX = Int(location.x / tileSize)
        let gridY = Int(location.y / tileSize)
        return (gridX, gridY)
    }
    
    /// Plans a path to the target and sets up visual footsteps.
    ///
    /// Uses A* pathfinding to create a route from the player's current position
    /// to the target, then creates visual footstep markers along the path.
    ///
    /// - Parameter target: Target grid coordinates as (x, y) tuple
    private func planAndExecutePath(to target: (Int, Int)) {
        guard let player = player,
              let map = map else { return }
        
        // If we're already at the target, do nothing
        if player.gridX == target.0 && player.gridY == target.1 {
            return
        }
        
        // Clear any existing path
        clearPlannedPath()
        
        // Find path using A* pathfinding
        let path = Pathfinder.aStar(map: map,
                                    start: (player.gridX, player.gridY),
                                    goal: target,
                                    passable: createPassableFunction(for: player))
        }
        
        // If no path found or path is just the start position, fall back to old directional movement
        if path.isEmpty || path.count <= 1 {
            fallbackToDirectionalMovement(target: target)
            return
        }
        
        // Store the path (excluding starting position)
        plannedPath = Array(path.dropFirst())
        currentPathIndex = 0
        isExecutingPath = true
        
        // Create visual footsteps along the path
        createFootstepNodes()
        
        if debugLogging {
            print("[GameScene] Planned path to (\(target.0), \(target.1)) with \(plannedPath.count) steps")
        }
    }
    
    /// Creates visual footstep nodes along the planned path.
    private func createFootstepNodes() {
        clearFootstepNodes()
        
        for (index, position) in plannedPath.enumerated() {
            let footstep = createFootstepNode(at: position, index: index)
            addChild(footstep)
            footstepNodes.append(footstep)
        }
    }
    
    /// Creates a single footstep node at the specified position.
    ///
    /// - Parameters:
    ///   - position: Grid coordinates for the footstep
    ///   - index: Index in the path for z-position ordering
    /// - Returns: Configured footstep sprite node
    private func createFootstepNode(at position: (Int, Int), index: Int) -> SKSpriteNode {
        let footstep = SKSpriteNode(color: .systemYellow, size: CGSize(width: tileSize * 0.3, height: tileSize * 0.3))
        footstep.position = CGPoint(
            x: CGFloat(position.0) * tileSize + tileSize/2,
            y: CGFloat(position.1) * tileSize + tileSize/2
        )
        footstep.zPosition = 15 // Above tiles, below entities
        footstep.alpha = 0.8
        
        // Add a subtle pulsing animation
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.5),
            SKAction.fadeAlpha(to: 0.8, duration: 0.5)
        ])
        footstep.run(SKAction.repeatForever(pulse))
        
        return footstep
    }
    
    /// Clears all planned path data and visual elements.
    private func clearPlannedPath() {
        plannedPath.removeAll()
        clearFootstepNodes()
        isExecutingPath = false
        currentPathIndex = 0
    }
    
    /// Removes all footstep nodes from the scene.
    private func clearFootstepNodes() {
        for footstep in footstepNodes {
            footstep.removeFromParent()
        }
        footstepNodes.removeAll()
    }
    
    /// Fallback to old directional movement when pathfinding fails.
    ///
    /// - Parameter target: Target grid coordinates
    private func fallbackToDirectionalMovement(target: (Int, Int)) {
        guard let player = player else { return }
        
        let dx = target.0 - player.gridX
        let dy = target.1 - player.gridY
        
        if abs(dx) > abs(dy) {
            movementDir = (dx > 0 ? 1 : -1, 0)
        } else {
            movementDir = (0, dy > 0 ? 1 : -1)
        }
    }
}

// MARK: - CGPoint Lerp
/// Extension providing smooth interpolation for camera movement.
private extension CGPoint {
    /// Linearly interpolates between this point and another.
    ///
    /// - Parameters:
    ///   - to: Target point for interpolation
    ///   - t: Interpolation factor (0.0 to 1.0)
    /// - Returns: Interpolated point between self and target
    func lerp(to: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: x + (to.x - x)*t,
                y: y + (to.y - y)*t)
    }
}
