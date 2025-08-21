import SpriteKit
import GameplayKit

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
    
    // MARK: - Constants
    private enum GameConstants {
        static let tileSize: CGFloat = 24
        static let cameraLerpFactor: CGFloat = 0.18
        static let fieldOfViewRadius: Int = 10
        static let monsterPathUpdateInterval: TimeInterval = 1.0
        static let entitySizeRatio: CGFloat = 0.8
        static let playerAnimationDuration: TimeInterval = 0.12
        static let maxMonsterSpawnAttempts: Int = 50
        static let monsterCount: Int = 5
        static let attackAnimationDuration: TimeInterval = 0.05
        static let attackAnimationScale: CGFloat = 1.2
        static let hudSafeAreaInset: CGFloat = 8
    }
    
    // MARK: - Config / State
    private var config = DungeonConfig()
    private var map: DungeonMap?
    private var currentSeed: UInt64? = nil
    
    // Tile assets
    private var tileMap: SKTileMapNode?
    private var tileRefs: TileSetBuilder.TileRefs?
    
    // Entities
    private var player: Entity?
    private var monsters: [Monster] = []
    
    // Camera / HUD
    private var camNode: SKCameraNode?
    private let hud = HUD()
    
    // FOV
    private var fogNode: SKSpriteNode?
    
    // Algorithm rotation
    private var pendingAlgoIndex = 0
    private let algorithms: [GenerationAlgorithm] = [.roomsCorridors, .bsp, .cellular]
    
    // Movement (tap or queued)
    private var movementDir: (dx: Int, dy: Int) = (0,0)
    
    // Monster path timing
    private var lastMonsterPathUpdate: TimeInterval = 0
    
    // Debug
    private let debugLogging = false
    
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
        buildTileSetIfNeeded()
        generateDungeon(seed: nil)
        setupHUD()
        if debugLogging { print("[GameScene] didMove complete") }
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
    
    private func buildTileSetIfNeeded() {
        guard tileRefs == nil || tileMap == nil else { return }
        let (tileSet, refs) = TileSetBuilder.build(tileSize: GameConstants.tileSize)
        tileRefs = refs
        if tileMap == nil {
            let mapNode = SKTileMapNode(tileSet: tileSet,
                                        columns: 1,
                                        rows: 1,
                                        tileSize: CGSize(width: GameConstants.tileSize, height: GameConstants.tileSize))
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
        placePlayer()
        spawnMonsters()
        recomputeFOV()
        updateHUD()
    }
    
    // MARK: - Tile Management
    
    /// Gets the appropriate tile group for a given tile.
    ///
    /// - Parameter tile: The tile to get the group for
    /// - Returns: The SKTileGroup for rendering this tile
    private func tileGroup(for tile: Tile) -> SKTileGroup? {
        guard let tileRefs = tileRefs else { return nil }
        
        switch tile.kind {
        case .floor:
            let maxIndex = tileRefs.floorVariants.count - 1
            let clamped = max(0, min(maxIndex, tile.variant))
            return tileRefs.floorVariants[clamped]
        case .wall: 
            return tileRefs.wall
        case .doorClosed: 
            return tileRefs.door
        case .doorSecret: 
            return tileRefs.secretDoor
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
                if let group = tileGroup(for: tile) {
                    tileMap.setTileGroup(group, forColumn: x, row: y)
                }
            }
        }
        
        fogNode?.removeFromParent()
        let fog = SKSpriteNode(color: .black,
                               size: CGSize(width: CGFloat(map.width)*GameConstants.tileSize,
                                            height: CGFloat(map.height)*GameConstants.tileSize))
        fog.anchorPoint = CGPoint(x: 0, y: 0)
        fog.alpha = 0.0
        addChild(fog)
        fogNode = fog
        
        if debugLogging { print("[GameScene] buildTileMap complete") }
    }
    
    private func refreshTile(x: Int, y: Int) {
        guard let map = map,
              let tileMap = tileMap,
              map.inBounds(x, y) else { return }
        let idx = map.index(x: x, y: y)
        let tile = map.tiles[idx]
        if let group = tileGroup(for: tile) {
            tileMap.setTileGroup(group, forColumn: x, row: y)
        }
    }
    
    // MARK: - Entities
    private func placePlayer() {
        guard let map = map else { return }
        player?.removeFromParent()
        let start = map.playerStart
        let p = Entity(kind: .player,
                       gridX: start.0,
                       gridY: start.1,
                       color: .systemRed,
                       size: CGSize(width: GameConstants.tileSize*GameConstants.entitySizeRatio, 
                                   height: GameConstants.tileSize*GameConstants.entitySizeRatio))
        addChild(p)
        p.moveTo(gridX: p.gridX, gridY: p.gridY, tileSize: GameConstants.tileSize, animated: false)
        player = p
    }
    
    private func spawnMonsters() {
        guard let map = map,
              let player = player else { return }
        monsters.forEach { $0.removeFromParent() }
        monsters = []
        for _ in 0..<GameConstants.monsterCount {
            var attempts = 0
            while attempts < GameConstants.maxMonsterSpawnAttempts {
                attempts += 1
                let x = Int.random(in: 0..<map.width)
                let y = Int.random(in: 0..<map.height)
                let t = map.tiles[map.index(x: x, y: y)]
                if t.kind == .floor && (x,y) != (player.gridX, player.gridY) {
                    let m = Monster(gridX: x, gridY: y, tileSize: GameConstants.tileSize)
                    addChild(m)
                    m.moveTo(gridX: x, gridY: y, tileSize: GameConstants.tileSize, animated: false)
                    monsters.append(m)
                    break
                }
            }
        }
    }
    
    // MARK: - HUD / Camera
    private func updateHUD() {
        guard let player = player else { return }
        let displayInfo = HUDDisplayInfo(
            seed: currentSeed,
            hp: player.hp,
            algo: algorithms[pendingAlgoIndex % algorithms.count],
            size: size,
            safeInset: GameConstants.hudSafeAreaInset
        )
        hud.update(with: displayInfo)
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateHUD()
    }
    
    private func updateCamera() {
        guard let player = player,
              let camNode = camNode else { return }
        let target = CGPoint(x: CGFloat(player.gridX)*GameConstants.tileSize + GameConstants.tileSize/2,
                             y: CGFloat(player.gridY)*GameConstants.tileSize + GameConstants.tileSize/2)
        camNode.position = camNode.position.lerp(to: target, t: GameConstants.cameraLerpFactor)
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
        if currentTime - lastMonsterPathUpdate > GameConstants.monsterPathUpdateInterval {
            updateMonsters()
            lastMonsterPathUpdate = currentTime
        }
    }
    
    // MARK: - Movement / Combat
    
    /// Checks if a tile allows door interaction.
    ///
    /// - Parameter tile: The tile to check
    /// - Returns: `true` if the tile is a door that can be opened
    private func canOpenDoor(_ tile: Tile) -> Bool {
        tile.kind == .doorClosed || tile.kind == .doorSecret
    }
    
    /// Checks if a position contains a monster.
    ///
    /// - Parameters:
    ///   - x: X coordinate to check
    ///   - y: Y coordinate to check
    /// - Returns: The monster at the position, or nil if none exists
    private func monsterAt(x: Int, y: Int) -> Monster? {
        monsters.first(where: { $0.gridX == x && $0.gridY == y })
    }
    
    /// Processes pending player movement commands.
    ///
    /// Executes queued movement direction and resets the movement state
    /// after processing. Called each frame to provide responsive controls.
    private func updatePlayerMovement() {
        guard movementDir.dx != 0 || movementDir.dy != 0 else { return }
        tryMovePlayer(dx: movementDir.dx, dy: movementDir.dy)
        movementDir = (0,0)
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
        guard var map = map,
              let player = player else { return }
        let nx = player.gridX + dx
        let ny = player.gridY + dy
        guard map.inBounds(nx, ny) else { return }
        let idx = map.index(x: nx, y: ny)
        var tile = map.tiles[idx]
        
        if canOpenDoor(tile) {
            tile.kind = .floor
            map.tiles[idx] = tile
            self.map = map
            refreshTile(x: nx, y: ny)
            recomputeFOV()
            return
        }
        guard !tile.blocksMovement else { return }
        
        if let monster = monsterAt(x: nx, y: ny) {
            attackMonster(monster)
            return
        }
        player.moveTo(gridX: nx, gridY: ny, tileSize: GameConstants.tileSize)
        self.map = map
        recomputeFOV()
    }
    
    private func attackMonster(_ monster: Monster) {
        monster.hp -= 1
        monster.run(.sequence([
            .scale(to: GameConstants.attackAnimationScale, duration: GameConstants.attackAnimationDuration),
            .scale(to: 1.0, duration: GameConstants.attackAnimationDuration)
        ]))
        if monster.hp <= 0 {
            monster.removeFromParent()
            monsters.removeAll { $0 === monster }
        }
        if debugLogging { print("[GameScene] Monster attacked, hp now \(monster.hp)") }
    }
    
    private func updateMonsters() {
        guard let map = map,
              let player = player else { return }
        for monster in monsters {
            let path = Pathfinder.aStar(map: map,
                                        start: (monster.gridX, monster.gridY),
                                        goal: (player.gridX, player.gridY)) { kind in
                switch kind {
                case .wall, .doorClosed, .doorSecret: return false
                case .floor: return true
                }
            }
            if path.count > 1 {
                let next = path[1]
                if next.0 == player.gridX && next.1 == player.gridY {
                    player.hp -= 1
                    updateHUD()
                } else {
                    monster.moveTo(gridX: next.0, gridY: next.1, tileSize: GameConstants.tileSize)
                }
            }
        }
    }
    
    // MARK: - FOV
    private func recomputeFOV() {
        guard var map = map,
              let player = player else { return }
        FOV.compute(map: &map,
                    originX: player.gridX,
                    originY: player.gridY,
                    radius: GameConstants.fieldOfViewRadius)
        self.map = map
        // (Optional) If you want a real fog overlay, you'd update a mask here.
    }
    
    // MARK: - Touch Input (Tap to step toward tap)
    /// Handles touch input for player movement.
    ///
    /// Converts touch screen coordinates to movement direction by determining
    /// which cardinal direction from the player position the touch occurred.
    /// Prioritizes the axis with greater displacement for intuitive movement.
    ///
    /// - Parameters:
    ///   - touches: Set of touch objects representing the input
    ///   - event: The event containing the touches
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let player = player,
              let touch = touches.first,
              let view = self.view else { return }
        let location = touch.location(in: self)
        let px = CGFloat(player.gridX)*GameConstants.tileSize + GameConstants.tileSize/2
        let py = CGFloat(player.gridY)*GameConstants.tileSize + GameConstants.tileSize/2
        let dx = location.x - px
        let dy = location.y - py
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
