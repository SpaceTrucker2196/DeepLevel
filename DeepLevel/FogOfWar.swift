import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

/// Implements a fog of war effect using SpriteKit for enhanced tile visibility.
///
/// Creates a mask layer that reveals explored areas with different opacity levels
/// based on current visibility. Unexplored areas remain completely hidden while
/// explored but not currently visible areas are dimmed.
///
/// - Since: 1.0.0
final class FogOfWar: SKNode {
    
    /// The texture used for revealing tiles (a white square).
    private let revealTexture: SKTexture
    
    /// Array of individual fog tiles corresponding to map tiles.
    private var fogTiles: [SKSpriteNode] = []
    
    /// Width and height of the map in tiles.
    private let mapWidth: Int
    private let mapHeight: Int
    
    /// Size of each tile in points.
    private let tileSize: CGFloat
    
    /// Creates a new fog of war system.
    ///
    /// - Parameters:
    ///   - mapWidth: Width of the map in tiles
    ///   - mapHeight: Height of the map in tiles
    ///   - tileSize: Size of each tile in points
    init(mapWidth: Int, mapHeight: Int, tileSize: CGFloat) {
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.tileSize = tileSize
        
        // Create a simple white texture for revealing tiles
        self.revealTexture = SKTexture.createWhiteTexture(size: CGSize(width: tileSize, height: tileSize))
        
        super.init()
        setupFogTiles()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Sets up the individual fog tiles for each map position.
    private func setupFogTiles() {
        // Remove any existing fog tiles
        removeAllChildren()
        fogTiles.removeAll()
        
        // Create fog tiles for each map position
        for y in 0..<mapHeight {
            for x in 0..<mapWidth {
                let fogTile = SKSpriteNode(color: .black, size: CGSize(width: tileSize, height: tileSize))
                fogTile.anchorPoint = CGPoint(x: 0, y: 0)
                fogTile.position = CGPoint(x: CGFloat(x) * tileSize, y: CGFloat(y) * tileSize)
                fogTile.zPosition = 1000 // Above tiles but below UI
                addChild(fogTile)
                fogTiles.append(fogTile)
            }
        }
    }
    
    /// Updates the fog of war based on the current map state.
    ///
    /// Adjusts the opacity of each fog tile based on whether the corresponding
    /// map tile is visible, explored, or neither.
    ///
    /// - Parameter map: The dungeon map containing visibility information
    func updateFog(for map: DungeonMap) {
        for y in 0..<mapHeight {
            for x in 0..<mapWidth {
                guard map.inBounds(x, y) else { continue }
                
                let tileIndex = y * mapWidth + x
                guard tileIndex < fogTiles.count else { continue }
                
                let mapTile = map.tiles[map.index(x: x, y: y)]
                let fogTile = fogTiles[tileIndex]
                
                // Determine fog opacity based on tile state
                if mapTile.visible {
                    // Currently visible - no fog
                    fogTile.alpha = 0.0
                } else if mapTile.explored {
                    // Explored but not visible - partial fog (dimmed)
                    fogTile.alpha = 0.5
                } else {
                    // Never explored - full fog
                    fogTile.alpha = 1.0
                }
            }
        }
    }
    
    /// Animates the fog reveal effect for newly visible tiles.
    ///
    /// Creates a smooth transition when tiles become visible or are explored
    /// for the first time.
    ///
    /// - Parameters:
    ///   - x: X coordinate of the tile
    ///   - y: Y coordinate of the tile  
    ///   - toAlpha: Target alpha value
    func animateFogReveal(x: Int, y: Int, toAlpha: CGFloat) {
        let tileIndex = y * mapWidth + x
        guard tileIndex < fogTiles.count else { return }
        
        let fogTile = fogTiles[tileIndex]
        fogTile.run(SKAction.fadeAlpha(to: toAlpha, duration: 0.3))
    }
}

/// Extension to create simple textures for fog effects.
private extension SKTexture {
    /// Creates a white texture of the specified size.
    static func createWhiteTexture(size: CGSize) -> SKTexture {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
        #else
        // Fallback for macOS
        return SKTexture(imageNamed: "WhitePixel") // Would need a white pixel image
        #endif
    }
}