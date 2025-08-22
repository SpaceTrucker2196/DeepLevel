import SpriteKit

/// Builds SpriteKit tile sets and texture references for dungeon rendering.
///
/// Uses an asset PNG ("Grass") for the floor, then generates variants with
/// variable darkness (color blending). Other tiles (walls, doors) remain solid color.
final class TileSetBuilder {
    struct TileRefs {
        let floorVariants: [SKTileGroup]
        let wall: SKTileGroup
        let door: SKTileGroup
        let secretDoor: SKTileGroup
        let sidewalk: SKTileGroup
        let driveway: SKTileGroup
        let hidingArea: SKTileGroup
    }
    
    static func build(tileSize: CGFloat) -> (SKTileSet, TileRefs) {
        // Load base grass texture from asset catalog
        let grassTexture = SKTexture(imageNamed: "Grass")
        let floorTextures = (0..<3).map { darkness in
            grassTexture.dl_darkenedTexture(square: tileSize, darkness: [0.0, 0.18, 0.36][darkness])
        }
        
        let treesTexture     = SKTexture(imageNamed: "Trees")
        let doorTexture      = SKColor.brown.dl_texture(square: tileSize)
        let secretTexture    = SKColor.purple.dl_texture(square: tileSize)
        let sidewalkTexture  = SKTexture(imageNamed: "Sidewalk")
        let drivewayTexture  = SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1).dl_texture(square: tileSize)
        let hidingTexture    = SKTexture(imageNamed: "HidingSpot")
        
        func makeGroup(named name: String, texture: SKTexture) -> SKTileGroup {
            let def = SKTileDefinition(texture: texture, size: CGSize(width: tileSize, height: tileSize))
            let g = SKTileGroup(tileDefinition: def)
            g.name = name
            return g
        }
        
        let floorGroups   = floorTextures.enumerated().map { makeGroup(named: "floor_\($0.offset)", texture: $0.element) }
        let wallGroup     = makeGroup(named: "wall", texture: treesTexture)
        let doorGroup     = makeGroup(named: "doorClosed", texture: doorTexture)
        let secretGroup   = makeGroup(named: "doorSecret", texture: secretTexture)
        let sidewalkGroup = makeGroup(named: "sidewalk", texture: sidewalkTexture)
        let drivewayGroup = makeGroup(named: "driveway", texture: drivewayTexture)
        let hidingGroup   = makeGroup(named: "hidingArea", texture: hidingTexture)
        
        let groups = floorGroups + [wallGroup, doorGroup, secretGroup, sidewalkGroup, drivewayGroup, hidingGroup]
        let tileSet = SKTileSet(tileGroups: groups)
        
        let refs = TileRefs(floorVariants: floorGroups,
                           wall: wallGroup,
                           door: doorGroup,
                           secretDoor: secretGroup,
                           sidewalk: sidewalkGroup,
                           driveway: drivewayGroup,
                           hidingArea: hidingGroup)
        return (tileSet, refs)
    }
}

/// Extension for darkening a texture (floor sprite variant)
private extension SKTexture {
    /// Returns a new texture by blending the base texture with black at a given darkness level.
    func dl_darkenedTexture(square size: CGFloat, darkness: CGFloat) -> SKTexture {
        let node = SKSpriteNode(texture: self)
        node.color = .black
        node.colorBlendFactor = darkness
        node.size = CGSize(width: size, height: size)
        
        let view = SKView(frame: CGRect(x: 0, y: 0, width: Int(size), height: Int(size)))
        return view.texture(from: node)!
    }
}

/// Existing color->texture extension for other tiles
private extension SKColor {
    func dl_texture(square size: CGFloat) -> SKTexture {
        // ... existing implementation ...
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let texture: SKTexture
        #if canImport(UIKit)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { ctx in
            self.setFill()
            ctx.fill(rect)
            UIColor(white: 0, alpha: 0.08).setFill()
            for _ in 0..<Int(size/2) {
                let px = CGFloat.random(in: 0..<size)
                let py = CGFloat.random(in: 0..<size)
                ctx.fill(CGRect(x: px, y: py, width: 1, height: 1))
            }
        }
        texture = SKTexture(image: image)
        #else
        texture = SKTexture()
        #endif
        return texture
    }
}
