import SpriteKit
import GameplayKit

final class GameScene: SKScene {
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
    private var cameraLerp: CGFloat = 0.18
    
    // FOV
    private var fogNode: SKSpriteNode?
    private let fovRadius: Int = 10
    
    // Algorithm rotation
    private var pendingAlgoIndex = 0
    private let algorithms: [GenerationAlgorithm] = [.roomsCorridors, .bsp, .cellular]
    
    // Movement (tap or queued)
    private var movementDir: (dx: Int, dy: Int) = (0,0)
    
    // Monster path timing
    private var lastMonsterPathUpdate: TimeInterval = 0
    private var monsterPathInterval: TimeInterval = 1.0
    
    // Sizing
    private let tileSize: CGFloat = 24
    
    // Debug
    private let debugLogging = false
    
    // Initialization guard (SpriteKit may call didMove multiple times if scene is re-presented)
    private var initialized = false
    
    // MARK: - Scene Lifecycle
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
    func regenerate(seed: UInt64?) {
        generateDungeon(seed: seed)
    }
    
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
        placePlayer()
        spawnMonsters()
        recomputeFOV()
        updateHUD()
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
                }
                tileMap.setTileGroup(group, forColumn: x, row: y)
            }
        }
        
        fogNode?.removeFromParent()
        let fog = SKSpriteNode(color: .black,
                               size: CGSize(width: CGFloat(map.width)*tileSize,
                                            height: CGFloat(map.height)*tileSize))
        fog.anchorPoint = CGPoint(x: 0, y: 0)
        fog.alpha = 0.0
        addChild(fog)
        fogNode = fog
        
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
        }
        tileMap.setTileGroup(group, forColumn: x, row: y)
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
                       size: CGSize(width: tileSize*0.8, height: tileSize*0.8))
        addChild(p)
        p.moveTo(gridX: p.gridX, gridY: p.gridY, tileSize: tileSize, animated: false)
        player = p
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
                if t.kind == .floor && (x,y) != (player.gridX, player.gridY) {
                    let m = Monster(gridX: x, gridY: y, tileSize: tileSize)
                    addChild(m)
                    m.moveTo(gridX: x, gridY: y, tileSize: tileSize, animated: false)
                    monsters.append(m)
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
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        updatePlayerMovement()
        updateCamera()
        if currentTime - lastMonsterPathUpdate > monsterPathInterval {
            updateMonsters()
            lastMonsterPathUpdate = currentTime
        }
    }
    
    // MARK: - Movement / Combat
    private func updatePlayerMovement() {
        guard movementDir.dx != 0 || movementDir.dy != 0 else { return }
        tryMovePlayer(dx: movementDir.dx, dy: movementDir.dy)
        movementDir = (0,0)
    }
    
    private func tryMovePlayer(dx: Int, dy: Int) {
        guard var map = map,
              let player = player else { return }
        let nx = player.gridX + dx
        let ny = player.gridY + dy
        guard map.inBounds(nx, ny) else { return }
        let idx = map.index(x: nx, y: ny)
        var tile = map.tiles[idx]
        
        if tile.kind == .doorClosed || tile.kind == .doorSecret {
            tile.kind = .floor
            map.tiles[idx] = tile
            self.map = map
            refreshTile(x: nx, y: ny)
            recomputeFOV()
            return
        }
        guard !tile.blocksMovement else { return }
        
        if let monster = monsters.first(where: { $0.gridX == nx && $0.gridY == ny }) {
            attackMonster(monster)
            return
        }
        player.moveTo(gridX: nx, gridY: ny, tileSize: tileSize)
        self.map = map
        recomputeFOV()
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
                    monster.moveTo(gridX: next.0, gridY: next.1, tileSize: tileSize)
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
                    radius: fovRadius)
        self.map = map
        // (Optional) If you want a real fog overlay, you'd update a mask here.
    }
    
    // MARK: - Touch Input (Tap to step toward tap)
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let player = player,
              let touch = touches.first,
              let view = self.view else { return }
        let location = touch.location(in: self)
        let px = CGFloat(player.gridX)*tileSize + tileSize/2
        let py = CGFloat(player.gridY)*tileSize + tileSize/2
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
private extension CGPoint {
    func lerp(to: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: x + (to.x - x)*t,
                y: y + (to.y - y)*t)
    }
}
