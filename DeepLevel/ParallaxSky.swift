import SpriteKit

/// Implements a parallax scrolling sky background effect.
///
/// Creates a multi-layered sky background that scrolls at different rates
/// to simulate depth and provide visual interest during cityMap exploration.
/// The parallax effect moves layers at fractions of the camera movement speed.
///
/// - Since: 1.0.0
final class ParallaxSky: SKNode {
    
    /// Configuration for parallax layer properties.
    private struct LayerConfig {
        let color: SKColor
        let speed: CGFloat  // Multiplier of camera movement (0.0 = stationary, 1.0 = follows camera)
        let alpha: CGFloat
    }
    
    /// Array of sky layers ordered from back to front.
    private var skyLayers: [SKSpriteNode] = []
    
    /// Configuration for each parallax layer.
    private let layerConfigs: [LayerConfig] = [
        LayerConfig(color: SKColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0), speed: 0.1, alpha: 0.8),  // Deep sky
        LayerConfig(color: SKColor(red: 0.6, green: 0.7, blue: 0.95, alpha: 1.0), speed: 0.2, alpha: 0.6), // Mid sky
        LayerConfig(color: SKColor(red: 0.8, green: 0.85, blue: 0.98, alpha: 1.0), speed: 0.3, alpha: 0.4) // Near sky
    ]
    
    /// Size of each layer (should be larger than screen to allow scrolling).
    private let layerSize: CGSize
    
    /// Last camera position to calculate movement delta.
    private var lastCameraPosition: CGPoint = .zero
    
    /// Creates a new parallax sky system.
    ///
    /// - Parameter sceneSize: The size of the scene to determine layer dimensions
    init(sceneSize: CGSize) {
        // Make layers larger than scene to allow parallax movement
        self.layerSize = CGSize(width: sceneSize.width * 3, height: sceneSize.height * 3)
        super.init()
        setupLayers()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Sets up the sky layers with their respective configurations.
    private func setupLayers() {
        // Create layers from back to front
        for config in layerConfigs {
            let layer = SKSpriteNode(color: config.color, size: layerSize)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.alpha = config.alpha
            layer.zPosition = -1000 + CGFloat(skyLayers.count) // Ensure sky is behind everything
            addChild(layer)
            skyLayers.append(layer)
        }
    }
    
    /// Updates the parallax layers based on camera movement.
    ///
    /// Call this method whenever the camera position changes to update
    /// the parallax effect. Each layer moves at a different speed relative
    /// to the camera movement.
    ///
    /// - Parameter cameraPosition: Current camera position in world coordinates
    func updateParallax(cameraPosition: CGPoint) {
        let deltaX = cameraPosition.x - lastCameraPosition.x
        let deltaY = cameraPosition.y - lastCameraPosition.y
        
        // Update each layer with its specific parallax speed
        for (index, layer) in skyLayers.enumerated() {
            let config = layerConfigs[index]
            layer.position.x += deltaX * config.speed
            layer.position.y += deltaY * config.speed
        }
        
        lastCameraPosition = cameraPosition
    }
    
    /// Centers the sky layers on the given position.
    ///
    /// Useful for initial positioning or when teleporting the camera.
    ///
    /// - Parameter position: The position to center the sky on
    func centerOn(position: CGPoint) {
        lastCameraPosition = position
        for layer in skyLayers {
            layer.position = position
        }
    }
}