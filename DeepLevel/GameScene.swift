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
    private var scaledTileNodes: [SKSpriteNode] = []
    
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
    private let fovRadius: Int = 4  // Reduced from 5 to 4 for better gameplay balance
    
    // Monster AI settings
    private let monsterSeekingRange: Int = 5  // Distance in tiles within which monsters seek the player
    private let playerSeekingTimeout: TimeInterval = 5.0  // Seconds to keep seeking after losing sight
    
    // Particle effects
    private var particleManager: ParticleEffectsManager?
    
    // Parallax sky for cityMap
    private var parallaxSky: ParallaxSky?
    
    // Algorithm rotation
    private var pendingAlgoIndex = 3  // Start with cityMap (index 3) to match DungeonConfig default
    private let algorithms: [GenerationAlgorithm] = [.roomsCorridors, .bsp, .cellular, .cityMap]
    
    // Movement direction for continuous movement
    private var continuousMovementDir: (dx: Int, dy: Int) = (0,0)
    private var lastTapTime: TimeInterval = 0
    private let doubleTapInterval: TimeInterval = 0.3
    
    // Monster path timing
    private var lastMonsterPathUpdate: TimeInterval = 0
    private var monsterPathInterval: TimeInterval = 1.0
    
    // Sizing
    private let tileSize: CGFloat = 72
    
    // Debug
    private let debugLogging = false
    
    // Charmed entity tracking
    private var charmedScore: Int = 0
    
    // Initialization guard
    private var initialized = false
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        guard !initialized else { return }
        initialized = true
        backgroundColor = .black
        setupCameraIfNeeded()
        setupParallaxSky()
        buildTileSetIfNeeded()
        
        particleManager = ParticleEffectsManager(scene: self, tileSize: tileSize)
        
        generateDungeon(seed: nil)
        setupHUD()
        if debugLogging { print("[GameScene] didMove complete") }
    }
    
    // MARK: - Public API (Testing / UI)
    func getCurrentAlgorithmIndex() -> Int {
        return pendingAlgoIndex % algorithms.count
    }
    
    func regenerate(seed: UInt64?) {
        generateDungeon(seed: seed)
    }
    
    func cycleAlgorithm() {
        pendingAlgoIndex = (pendingAlgoIndex + 1) % algorithms.count
        regenerate(seed: currentSeed)
    }
    
    func getAvailableAlgorithms() -> [GenerationAlgorithm] {
        return algorithms
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
    
    private func setupParallaxSky() {
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
              let tileRefs = tileRefs,
              let tileMap = tileMap else { return }
        
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
                case .crosswalk: group = tileRefs.crosswalk
                case .iceCreamTruck: group = tileRefs.iceCreamTruck
                @unknown default:
                    fatalError("Unhandled TileKind: \(tile.kind)")
                }
                tileMap.setTileGroup(group, forColumn: x, row: y)
            }
        }
        
        renderScaledTiles()
        
        fogNode?.removeFromParent()
        fogOfWar?.removeFromParent()
        
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
        case .crosswalk: group = tileRefs.crosswalk
        case .iceCreamTruck: group = tileRefs.iceCreamTruck
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
        particleManager?.addMovementTrail(to: p)
    }
    
    private func moveEntityWithTrail(_ entity: Entity, to position: (Int, Int)) {
        let oldPosition = (entity.gridX, entity.gridY)
        entity.moveTo(gridX: position.0, gridY: position.1, tileSize: tileSize)
        particleManager?.onEntityMove(entity, from: oldPosition)
    }
    
    private func createPassableFunction(for entity: Entity) -> (TileKind) -> Bool {
        return { tileKind in
            !entity.blockingTiles.contains(tileKind)
        }
    }
    
    private func renderScaledTiles() {
        guard let map = map,
              let tileRefs = tileRefs else { return }
        scaledTileNodes.forEach { $0.removeFromParent() }
        scaledTileNodes.removeAll()
        
        for y in 0..<map.height {
            for x in 0..<map.width {
                let tile = map.tiles[map.index(x: x, y: y)]
                guard tile.scale > 1.0 else { continue }
                let texture = getTextureForTile(tile: tile, tileRefs: tileRefs)
                let scaledTile = SKSpriteNode(texture: texture)
                scaledTile.size = CGSize(width: tileSize * tile.scale, height: tileSize * tile.scale)
                scaledTile.position = CGPoint(x: CGFloat(x) * tileSize + tileSize/2,
                                              y: CGFloat(y) * tileSize + tileSize/2)
                scaledTile.zPosition = 1
                addChild(scaledTile)
                scaledTileNodes.append(scaledTile)
            }
        }
    }
    
    private func getTextureForTile(tile: Tile, tileRefs: TileSetBuilder.TileRefs) -> SKTexture? {
        let group: SKTileGroup
        switch tile.kind {
        case .floor: group = tileRefs.floorVariants.first ?? tileRefs.floorVariants[0]
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
        case .crosswalk: group = tileRefs.crosswalk
        case .iceCreamTruck: group = tileRefs.iceCreamTruck
        @unknown default: return nil
        }
        return group.rules.first?.tileDefinitions.first?.textures.first
    }
    
    private func createFireHydrantEffects() {
        guard let map = map, let particleManager = particleManager else { return }
        particleManager.removeAllEffects()
        for y in 0..<map.height {
            for x in 0..<map.width {
                let tile = map.tiles[map.index(x: x, y: y)]
                if tile.kind == .sidewalkHydrant {
                    let offsetX: CGFloat = .random(in: -8...8)
                    let offsetY: CGFloat = .random(in: -8...8)
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
                if t.kind.isSpawnSurface && (x, y) != (player.gridX, player.gridY) {
                    let m = Monster(gridX: x, gridY: y, tileSize: tileSize)
                    addChild(m)
                    m.moveTo(gridX: x, gridY: y, tileSize: tileSize, animated: false)
                    monsters.append(m)
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
        parallaxSky?.updateParallax(cameraPosition: camNode.position)
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        updatePlayerMovement()
        updateCamera()
        particleManager?.updateMovementTrails(currentTime: currentTime)
        
        if currentTime - lastMonsterPathUpdate > monsterPathInterval {
            updateMonsters()
            updateCharmed()
            updateEntityTransparency()
            lastMonsterPathUpdate = currentTime
        }
    }
    
    // MARK: - Movement / Combat
    private func updatePlayerMovement() {
        guard continuousMovementDir.dx != 0 || continuousMovementDir.dy != 0 else { return }
        
        // Try to move in the continuous direction
        let success = tryMovePlayer(dx: continuousMovementDir.dx, dy: continuousMovementDir.dy)
        
        // Stop movement if blocked
        if !success {
            continuousMovementDir = (0,0)
        }
    }


    
    private func tryMovePlayer(dx: Int, dy: Int) -> Bool {
        guard let player = player else { return false }
        return tryMovePlayerToPosition(player.gridX + dx, player.gridY + dy)
    }
    
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
            return false
        }
        guard !tile.blocksMovement else { return false }
        
        if let monster = monsters.first(where: { $0.gridX == nx && $0.gridY == ny }) {
            attackMonster(monster)
            return false
        }
        
        if let charmed = charmedEntities.first(where: { $0.gridX == nx && $0.gridY == ny }) {
            charmEntity(charmed)
            return false
        }
        
        let oldPosition = (player.gridX, player.gridY)
        player.moveTo(gridX: nx, gridY: ny, tileSize: tileSize)
        self.map = map
        particleManager?.onEntityMove(player, from: oldPosition)
        markAdjacentTilesAsExplored()
        recomputeFOV()
        checkCharmedHealing()
        return true
    }
    
    private func markAdjacentTilesAsExplored() {
        guard var map = map,
              let player = player else { return }
        let directions = [(-1, -1), (-1, 0), (-1, 1),
                          (0, -1),           (0, 1),
                          (1, -1),  (1, 0),  (1, 1)]
        for (dx, dy) in directions {
            let x = player.gridX + dx
            let y = player.gridY + dy
            if map.inBounds(x, y) {
                let idx = map.index(x: x, y: y)
                map.tiles[idx].explored = true
            }
        }
        self.map = map
        fogOfWar?.updateFog(for: map)
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
            charmedScore += 1
            charmed.run(.sequence([
                .scale(to: 1.3, duration: 0.1),
                .scale(to: 1.0, duration: 0.1)
            ]))
            charmed.color = .systemBlue
            particleManager?.addCharmedHeartEffect(to: charmed)
            player.heal(amount: 2)
            particleManager?.addPlayerHealingGlow(to: player)
            updateHUD()
            if debugLogging { print("[GameScene] Entity charmed! Player healed to \(player.hp) HP") }
        }
    }
    
    private func checkCharmedHealing() {
        guard let map = map,
              let player = player else { return }
        let playerTile = map.tiles[map.index(x: player.gridX, y: player.gridY)]
        guard playerTile.kind == .hidingArea else { return }
        for charmed in charmedEntities where charmed.isCharmed {
            let dx = abs(charmed.gridX - player.gridX)
            let dy = abs(charmed.gridY - player.gridY)
            if dx <= 1 && dy <= 1 && (dx + dy > 0) {
                let charmedTile = map.tiles[map.index(x: charmed.gridX, y: charmed.gridY)]
                if charmedTile.kind == .hidingArea {
                    let currentTime = CACurrentMediaTime()
                    if currentTime - charmed.lastHealTime > 2.0 {
                        player.hp += 1
                        charmed.lastHealTime = currentTime
                        updateHUD()
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
    
    private func updateMonsters() {
        guard let map = map,
              let player = player else { return }
        
        for monster in monsters {
            let canSeePlayer = FOV.hasLineOfSight(map: map,
                                                  fromX: monster.gridX,
                                                  fromY: monster.gridY,
                                                  toX: player.gridX,
                                                  toY: player.gridY)
            
            // Calculate distance to player
            let dx = abs(monster.gridX - player.gridX)
            let dy = abs(monster.gridY - player.gridY)
            let distanceToPlayer = dx + dy  // Manhattan distance
            
            // Check if player is within seeking range
            let playerWithinSeekingRange = distanceToPlayer <= monsterSeekingRange
            
            if canSeePlayer {
                player.currentlySeen = true
            }
            
            // Only seek player if they can see them AND player is within seeking range
            if canSeePlayer && playerWithinSeekingRange {
                monster.lastPlayerPosition = (player.gridX, player.gridY)
                monster.lastPlayerSightingTime = CACurrentMediaTime()  // Update sighting time
                monster.roamTarget = nil  // Clear roam target when actively seeking
                let path = Pathfinder.aStar(map: map,
                                            start: (monster.gridX, monster.gridY),
                                            goal: (player.gridX, player.gridY),
                                            passable: createPassableFunction(for: monster))
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
                // If player was previously seen but is now out of seeking range or not visible
                if let lastPos = monster.lastPlayerPosition {
                    let timeSinceLastSighting = CACurrentMediaTime() - monster.lastPlayerSightingTime
                    
                    // Only continue seeking last known position if it was recent and within range
                    let lastPosDx = abs(monster.gridX - lastPos.0)
                    let lastPosDy = abs(monster.gridY - lastPos.1)
                    let distanceToLastPos = lastPosDx + lastPosDy
                    
                    // Stop seeking if: too much time passed, we're at the last position, or it's out of range
                    if timeSinceLastSighting > playerSeekingTimeout || 
                       distanceToLastPos <= 1 || 
                       distanceToLastPos > monsterSeekingRange {
                        monster.lastPlayerPosition = nil
                        monster.roamTarget = nil  // Reset roam target for new random movement
                    } else {
                        // Continue moving to last known position
                        let path = Pathfinder.aStar(map: map,
                                                    start: (monster.gridX, monster.gridY),
                                                    goal: lastPos,
                                                    passable: createPassableFunction(for: monster))
                        if path.count > 1 {
                            let next = path[1]
                            moveEntityWithTrail(monster, to: next)
                            if next.0 == lastPos.0 && next.1 == lastPos.1 {
                                monster.lastPlayerPosition = nil
                            }
                        } else {
                            monster.lastPlayerPosition = nil
                        }
                    }
                } else {
                    // No player position known, revert to random roaming
                    roamMonster(monster: monster, map: map)
                }
            }
            
            // Particle effects for detection
            if canSeePlayer && playerWithinSeekingRange {
                particleManager?.addPoliceLight(to: monster)
            } else {
                particleManager?.removePoliceLight(from: monster)
            }
        }
        
        let anyMonsterCanSeePlayer = monsters.contains {
            let dx = abs($0.gridX - player.gridX)
            let dy = abs($0.gridY - player.gridY)
            let distance = dx + dy
            return distance <= monsterSeekingRange && FOV.hasLineOfSight(map: map,
                               fromX: $0.gridX,
                               fromY: $0.gridY,
                               toX: player.gridX,
                               toY: player.gridY)
        }
        player.currentlySeen = anyMonsterCanSeePlayer
    }
    
    private func roamMonster(monster: Monster, map: DungeonMap) {
        if monster.roamTarget == nil ||
            (monster.roamTarget!.0 == monster.gridX && monster.roamTarget!.1 == monster.gridY) {
            monster.roamTarget = findRandomRoamTarget(map: map)
        }
        guard let target = monster.roamTarget else { return }
        let path = Pathfinder.aStar(map: map,
                                    start: (monster.gridX, monster.gridY),
                                    goal: target,
                                    passable: createPassableFunction(for: monster))
        if path.count > 1 {
            moveEntityWithTrail(monster, to: path[1])
        } else {
            monster.roamTarget = findRandomRoamTarget(map: map)
        }
    }
    
    private func findRandomRoamTarget(map: DungeonMap) -> (Int, Int)? {
        for _ in 0..<20 {
            let x = Int.random(in: 0..<map.width)
            let y = Int.random(in: 0..<map.height)
            let tile = map.tiles[map.index(x: x, y: y)]
            if !tile.blocksMovement { return (x, y) }
        }
        return nil
    }
    
    private func updateCharmed() {
        guard let map = map,
              let player = player else { return }
        for charmed in charmedEntities {
            if charmed.isCharmed {
                for monster in monsters {
                    let dx = abs(monster.gridX - charmed.gridX)
                    let dy = abs(monster.gridY - charmed.gridY)
                    if dx <= 2 && dy <= 2 {
                        charmed.isCharmed = false
                        charmed.color = .systemPurple
                        particleManager?.removeCharmedHeartEffect(from: charmed)
                        if debugLogging { print("[GameScene] Charm removed by nearby monster") }
                        break
                    }
                }
            }
            
            if charmed.isCharmed {
                followPlayer(charmed: charmed, map: map, player: player)
            } else {
                roamCharmed(charmed: charmed, map: map)
            }
        }
    }
    
    private func followPlayer(charmed: Charmed, map: DungeonMap, player: Player) {
        let currentTile = map.tiles[map.index(x: charmed.gridX, y: charmed.gridY)]
        if currentTile.kind == .hidingArea { return }
        let path = Pathfinder.aStar(map: map,
                                    start: (charmed.gridX, charmed.gridY),
                                    goal: (player.gridX, player.gridY),
                                    passable: createPassableFunction(for: charmed))
        if path.count > 1 {
            let next = path[1]
            if !(next.0 == player.gridX && next.1 == player.gridY) {
                let hasMonster = monsters.contains { $0.gridX == next.0 && $0.gridY == next.1 }
                if !hasMonster {
                    moveEntityWithTrail(charmed, to: next)
                }
            }
        }
    }
    
    private func roamCharmed(charmed: Charmed, map: DungeonMap) {
        let currentTile = map.tiles[map.index(x: charmed.gridX, y: charmed.gridY)]
        if currentTile.kind == .hidingArea { return }
        if charmed.roamTarget == nil ||
            (charmed.roamTarget!.0 == charmed.gridX && charmed.roamTarget!.1 == charmed.gridY) {
            charmed.roamTarget = findRandomRoamTarget(map: map)
        }
        guard let target = charmed.roamTarget else { return }
        let path = Pathfinder.aStar(map: map,
                                    start: (charmed.gridX, charmed.gridY),
                                    goal: target,
                                    passable: createPassableFunction(for: charmed))
        if path.count > 1 {
            let next = path[1]
            if let player = player, (next.0 == player.gridX && next.1 == player.gridY) {
                // skip
            } else {
                let hasMonster = monsters.contains { $0.gridX == next.0 && $0.gridY == next.1 }
                if !hasMonster {
                    moveEntityWithTrail(charmed, to: next)
                }
            }
        } else {
            charmed.roamTarget = findRandomRoamTarget(map: map)
        }
    }
    
    private func updateEntityTransparency() {
        guard let map = map else { return }
        if let player = player {
            let playerTile = map.tiles[map.index(x: player.gridX, y: player.gridY)]
            player.alpha = playerTile.kind == .hidingArea ? 0.5 : 1.0
        }
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
        fogOfWar?.updateFog(for: map)
        particleManager?.updateFireHydrantVisibility(map: map, playerX: player.gridX, playerY: player.gridY)
    }
    
    // MARK: - Touch Input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let currentTime = CACurrentMediaTime()
        
        // Check for double tap
        if currentTime - lastTapTime < doubleTapInterval {
            handleDoubleTap(touch)
            lastTapTime = 0 // Reset to prevent triple-tap issues
        } else {
            lastTapTime = currentTime
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let player = player,
              let touch = touches.first else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Only handle single tap if it wasn't part of a double-tap
        if currentTime - lastTapTime > doubleTapInterval {
            handleDirectionalTap(touch, player: player)
        }
    }
    
    private func handleDoubleTap(_ touch: UITouch) {
        let location = touch.location(in: self)
        let screenHeight = size.height
        
        // Check if tap is in top or bottom half of screen
        if location.y > screenHeight * 0.5 {
            // Top half - zoom in
            zoomCamera(zoomIn: true)
        } else {
            // Bottom half - zoom out
            zoomCamera(zoomIn: false)
        }
    }
    
    private func handleDirectionalTap(_ touch: UITouch, player: Player) {
        let location = touch.location(in: self)
        let playerScreenPos = CGPoint(
            x: CGFloat(player.gridX) * tileSize + tileSize/2,
            y: CGFloat(player.gridY) * tileSize + tileSize/2
        )
        
        // Check if tapping on or very close to the player - if so, stop movement
        let distanceToPlayer = hypot(location.x - playerScreenPos.x, location.y - playerScreenPos.y)
        if distanceToPlayer < tileSize {
            continuousMovementDir = (0, 0)
            return
        }
        
        // Calculate direction from player to tap location
        let dx = location.x - playerScreenPos.x
        let dy = location.y - playerScreenPos.y
        
        // Determine primary movement direction
        if abs(dx) > abs(dy) {
            // Horizontal movement
            continuousMovementDir = dx > 0 ? (1, 0) : (-1, 0)
        } else {
            // Vertical movement  
            continuousMovementDir = dy > 0 ? (0, 1) : (0, -1)
        }
    }
    
    private func zoomCamera(zoomIn: Bool) {
        guard let camera = camNode else { return }
        
        let currentScale = camera.xScale
        let zoomFactor: CGFloat = zoomIn ? 0.8 : 1.25
        let newScale = currentScale * zoomFactor
        
        // Clamp zoom levels
        let minScale: CGFloat = 0.5
        let maxScale: CGFloat = 2.0
        let clampedScale = max(minScale, min(maxScale, newScale))
        
        let zoomAction = SKAction.scale(to: clampedScale, duration: 0.3)
        zoomAction.timingMode = .easeInEaseOut
        camera.run(zoomAction)
    }
}

// MARK: - CGPoint Lerp
private extension CGPoint {
    func lerp(to: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: x + (to.x - x)*t,
                y: y + (to.y - y)*t)
    }
}
