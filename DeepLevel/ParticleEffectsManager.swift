import SpriteKit
import Foundation

/// Manages particle effects for various game elements including fire hydrants, charmed entities, and movement trails.
///
/// Provides centralized particle effect management with efficient handling of visibility,
/// line-of-sight calculations, and effect lifecycle management.
///
/// - Since: 1.0.0
final class ParticleEffectsManager {
    // MARK: - Properties
    
    /// Reference to the game scene for adding/removing particles
    private weak var scene: SKScene?
    
    /// Active fire hydrant particle effects keyed by tile position
    private var fireHydrantEffects: [String: SKEmitterNode] = [:]
    
    /// Active charmed entity heart effects keyed by entity ID
    private var charmedEffects: [UUID: SKEmitterNode] = [:]
    
    /// Active movement trail effects keyed by entity ID
    private var movementTrails: [UUID: MovementTrail] = [:]
    
    /// Tile size for positioning calculations
    private let tileSize: CGFloat
    
    // MARK: - Initialization
    
    init(scene: SKScene, tileSize: CGFloat) {
        self.scene = scene
        self.tileSize = tileSize
    }
    
    // MARK: - Fire Hydrant Effects
    
    /// Creates a water particle effect for a fire hydrant tile
    /// - Parameters:
    ///   - x: Grid X coordinate of the fire hydrant
    ///   - y: Grid Y coordinate of the fire hydrant
    ///   - offsetX: Horizontal offset from tile center
    ///   - offsetY: Vertical offset from tile center
    func createFireHydrantEffect(at x: Int, y: Int, offsetX: CGFloat = 0, offsetY: CGFloat = 0) {
        let key = "\(x),\(y)"
        
        // Remove existing effect if any
        removeFireHydrantEffect(at: x, y: y)
        
        // Create water particle effect
        let waterEffect = createWaterParticleEffect()
        
        // Position at tile center with offset
        let tileCenter = CGPoint(
            x: CGFloat(x) * tileSize + tileSize / 2 + offsetX,
            y: CGFloat(y) * tileSize + tileSize / 2 + offsetY
        )
        waterEffect.position = tileCenter
        waterEffect.zPosition = 25 // Above tiles but below entities
        
        scene?.addChild(waterEffect)
        fireHydrantEffects[key] = waterEffect
    }
    
    /// Removes fire hydrant effect at specified coordinates
    func removeFireHydrantEffect(at x: Int, y: Int) {
        let key = "\(x),\(y)"
        if let effect = fireHydrantEffects[key] {
            effect.removeFromParent()
            fireHydrantEffects.removeValue(forKey: key)
        }
    }
    
    /// Updates visibility of fire hydrant effects based on line of sight
    func updateFireHydrantVisibility(map: DungeonMap, playerX: Int, playerY: Int) {
        for (key, effect) in fireHydrantEffects {
            let components = key.split(separator: ",")
            guard components.count == 2,
                  let x = Int(components[0]),
                  let y = Int(components[1]) else { continue }
            
            let hasLOS = FOV.hasLineOfSight(map: map, fromX: playerX, fromY: playerY, toX: x, toY: y)
            effect.alpha = hasLOS ? 1.0 : 0.0
        }
    }
    
    // MARK: - Charmed Entity Effects
    
    /// Adds heart particle effect to a charmed entity
    func addCharmedHeartEffect(to entity: Entity) {
        // Remove existing effect if any
        removeCharmedHeartEffect(from: entity)
        
        // Create heart particle effect
        let heartEffect = createHeartParticleEffect()
        heartEffect.position = CGPoint(x: 0, y: tileSize * 0.3) // Above entity
        heartEffect.zPosition = 100 // Always visible despite fog of war
        
        entity.addChild(heartEffect)
        charmedEffects[entity.id] = heartEffect
    }
    
    /// Removes heart particle effect from entity
    func removeCharmedHeartEffect(from entity: Entity) {
        if let effect = charmedEffects[entity.id] {
            effect.removeFromParent()
            charmedEffects.removeValue(forKey: entity.id)
        }
    }
    
    // MARK: - Movement Trail Effects
    
    /// Adds movement trail effect to an entity
    func addMovementTrail(to entity: Entity) {
        let trail = MovementTrail(entity: entity, tileSize: tileSize)
        movementTrails[entity.id] = trail
    }
    
    /// Updates movement trails and removes expired ones
    func updateMovementTrails(currentTime: TimeInterval) {
        var toRemove: [UUID] = []
        
        for (id, trail) in movementTrails {
            trail.update(currentTime: currentTime)
            if trail.isExpired {
                toRemove.append(id)
            }
        }
        
        // Remove expired trails
        for id in toRemove {
            movementTrails.removeValue(forKey: id)
        }
    }
    
    /// Triggers movement trail when entity moves
    func onEntityMove(_ entity: Entity, from oldPosition: (Int, Int)) {
        if let trail = movementTrails[entity.id] {
            trail.addTrailPoint(at: oldPosition)
        }
    }
    
    // MARK: - Cleanup
    
    /// Removes all particle effects
    func removeAllEffects() {
        // Remove fire hydrant effects
        for effect in fireHydrantEffects.values {
            effect.removeFromParent()
        }
        fireHydrantEffects.removeAll()
        
        // Remove charmed effects
        for effect in charmedEffects.values {
            effect.removeFromParent()
        }
        charmedEffects.removeAll()
        
        // Remove movement trails
        movementTrails.removeAll()
    }
    
    // MARK: - Private Effect Creation
    
    /// Creates a water particle effect for fire hydrants
    private func createWaterParticleEffect() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        
        // Water droplet texture (simple blue circle)
        emitter.particleTexture = createWaterDropletTexture()
        
        // Emission properties
        emitter.particleBirthRate = 30
        emitter.numParticlesToEmit = 0 // Continuous emission
        
        // Particle lifecycle
        emitter.particleLifetime = 1.5
        emitter.particleLifetimeRange = 0.5
        
        // Position and movement
        emitter.emissionAngle = .pi / 2 // Upward
        emitter.emissionAngleRange = .pi / 4 // Spread
        emitter.particleSpeed = 50
        emitter.particleSpeedRange = 30
        
        // Physics simulation
        emitter.yAcceleration = -150 // Gravity
        emitter.particleBirthRate = 20
        
        // Visual properties
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.1
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.5 // Fade out
        
        // Color (blue water)
        emitter.particleColor = .systemBlue
        emitter.particleColorBlendFactor = 1.0
        
        return emitter
    }
    
    /// Creates a heart particle effect for charmed entities
    private func createHeartParticleEffect() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        
        // Heart emoji texture
        emitter.particleTexture = createHeartTexture()
        
        // Emission properties
        emitter.particleBirthRate = 5
        emitter.numParticlesToEmit = 0 // Continuous emission
        
        // Particle lifecycle
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.5
        
        // Position and movement
        emitter.emissionAngle = .pi / 2 // Upward
        emitter.emissionAngleRange = .pi / 6 // Small spread
        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 15
        
        // Visual properties
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.2
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.3 // Fade out
        
        // Color (red/pink hearts)
        emitter.particleColor = .systemPink
        emitter.particleColorBlendFactor = 0.8
        
        return emitter
    }
    
    /// Creates a simple water droplet texture
    private func createWaterDropletTexture() -> SKTexture {
        #if canImport(UIKit)
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
        #else
        // Fallback for non-UIKit platforms
        return SKColor.systemBlue.dl_texture(square: 8)
        #endif
    }
    
    /// Creates a heart emoji texture
    private func createHeartTexture() -> SKTexture {
        #if canImport(UIKit)
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Draw heart emoji
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.systemPink
            ]
            let heart = "❤️"
            let textSize = heart.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            heart.draw(in: textRect, withAttributes: attributes)
        }
        return SKTexture(image: image)
        #else
        // Fallback for non-UIKit platforms
        return SKColor.systemPink.dl_texture(square: 16)
        #endif
    }
}

// MARK: - Movement Trail Helper

/// Manages particle trail for entity movement
private class MovementTrail {
    private weak var entity: Entity?
    private let tileSize: CGFloat
    private var trailPoints: [(position: CGPoint, timestamp: TimeInterval)] = []
    private var trailNodes: [SKSpriteNode] = []
    private let maxTrailDuration: TimeInterval = 3.0 // 3 seconds as specified
    
    var isExpired: Bool {
        return entity == nil
    }
    
    init(entity: Entity, tileSize: CGFloat) {
        self.entity = entity
        self.tileSize = tileSize
    }
    
    func addTrailPoint(at gridPosition: (Int, Int)) {
        guard let entity = entity else { return }
        
        let worldPosition = CGPoint(
            x: CGFloat(gridPosition.0) * tileSize + tileSize / 2,
            y: CGFloat(gridPosition.1) * tileSize + tileSize / 2
        )
        
        let timestamp = CACurrentMediaTime()
        trailPoints.append((worldPosition, timestamp))
        
        // Create trail node
        let trailNode = SKSpriteNode(color: entity.color, size: CGSize(width: tileSize * 0.4, height: tileSize * 0.4))
        trailNode.position = worldPosition
        trailNode.zPosition = 10 // Below entities but above tiles
        trailNode.alpha = 0.6
        
        entity.parent?.addChild(trailNode)
        trailNodes.append(trailNode)
        
        // Animate fade out
        let fadeAction = SKAction.sequence([
            SKAction.wait(forDuration: maxTrailDuration),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        trailNode.run(fadeAction)
    }
    
    func update(currentTime: TimeInterval) {
        // Remove expired trail points
        let cutoffTime = currentTime - maxTrailDuration
        trailPoints.removeAll { $0.timestamp < cutoffTime }
    }
}

// MARK: - SKColor Extension for Texture Creation

private extension SKColor {
    func dl_texture(square size: CGFloat) -> SKTexture {
        #if canImport(UIKit)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { ctx in
            self.setFill()
            ctx.fill(rect)
        }
        return SKTexture(image: image)
        #else
        // Fallback for non-UIKit platforms - return a simple colored texture
        return SKTexture()
        #endif
    }
}