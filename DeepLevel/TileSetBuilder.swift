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
        
        // City Map tile references
        let park: SKTileGroup
        let residential1: SKTileGroup
        let residential2: SKTileGroup
        let residential3: SKTileGroup
        let residential4: SKTileGroup
        let urban1: SKTileGroup
        let urban2: SKTileGroup
        let urban3: SKTileGroup
        let redLight: SKTileGroup
        let retail: SKTileGroup
        let sidewalkTree: SKTileGroup
        let sidewalkHydrant: SKTileGroup
        let street: SKTileGroup
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
        
        // City Map textures
        let parkTexture      = SKColor.systemGreen.dl_texture(square: tileSize)
        let residential1Tex  = SKColor.systemBlue.dl_texture(square: tileSize)
        let residential2Tex  = SKColor.systemCyan.dl_texture(square: tileSize)
        let residential3Tex  = SKColor.systemTeal.dl_texture(square: tileSize)
        let residential4Tex  = SKColor.systemIndigo.dl_texture(square: tileSize)
        let urban1Tex        = SKColor.systemGray.dl_texture(square: tileSize)
        let urban2Tex        = SKColor.systemGray2.dl_texture(square: tileSize)
        let urban3Tex        = SKColor.systemGray3.dl_texture(square: tileSize)
        let redLightTex      = SKColor.systemRed.dl_texture(square: tileSize)
        let retailTex        = createRetailTexture(tileSize: tileSize)
        let sidewalkTreeTex  = createSidewalkTreeTexture(tileSize: tileSize)
        let sidewalkHydrantTex = createSidewalkHydrantTexture(tileSize: tileSize)
        let streetTexture    = SKColor.darkGray.dl_texture(square: tileSize)
        
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
        
        // City Map tile groups
        let parkGroup         = makeGroup(named: "park", texture: parkTexture)
        let residential1Group = makeGroup(named: "residential1", texture: residential1Tex)
        let residential2Group = makeGroup(named: "residential2", texture: residential2Tex)
        let residential3Group = makeGroup(named: "residential3", texture: residential3Tex)
        let residential4Group = makeGroup(named: "residential4", texture: residential4Tex)
        let urban1Group       = makeGroup(named: "urban1", texture: urban1Tex)
        let urban2Group       = makeGroup(named: "urban2", texture: urban2Tex)
        let urban3Group       = makeGroup(named: "urban3", texture: urban3Tex)
        let redLightGroup     = makeGroup(named: "redLight", texture: redLightTex)
        let retailGroup       = makeGroup(named: "retail", texture: retailTex)
        let sidewalkTreeGroup = makeGroup(named: "sidewalkTree", texture: sidewalkTreeTex)
        let sidewalkHydrantGroup = makeGroup(named: "sidewalkHydrant", texture: sidewalkHydrantTex)
        let streetGroup       = makeGroup(named: "street", texture: streetTexture)
        
        let groups = floorGroups + [
            wallGroup, doorGroup, secretGroup, sidewalkGroup, drivewayGroup, hidingGroup,
            parkGroup, residential1Group, residential2Group, residential3Group, residential4Group,
            urban1Group, urban2Group, urban3Group, redLightGroup, retailGroup,
            sidewalkTreeGroup, sidewalkHydrantGroup, streetGroup
        ]
        let tileSet = SKTileSet(tileGroups: groups)
        
        let refs = TileRefs(
            floorVariants: floorGroups,
            wall: wallGroup,
            door: doorGroup,
            secretDoor: secretGroup,
            sidewalk: sidewalkGroup,
            driveway: drivewayGroup,
            hidingArea: hidingGroup,
            park: parkGroup,
            residential1: residential1Group,
            residential2: residential2Group,
            residential3: residential3Group,
            residential4: residential4Group,
            urban1: urban1Group,
            urban2: urban2Group,
            urban3: urban3Group,
            redLight: redLightGroup,
            retail: retailGroup,
            sidewalkTree: sidewalkTreeGroup,
            sidewalkHydrant: sidewalkHydrantGroup,
            street: streetGroup
        )
        return (tileSet, refs)
    }
    
    /// Creates a retail tile texture with a $ symbol.
    private static func createRetailTexture(tileSize: CGFloat) -> SKTexture {
        #if canImport(UIKit)
        let rect = CGRect(x: 0, y: 0, width: tileSize, height: tileSize)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { ctx in
            // Background color
            SKColor.systemYellow.setFill()
            ctx.fill(rect)
            
            // Draw $ symbol
            let symbolSize = tileSize * 0.6
            let symbolRect = CGRect(
                x: (tileSize - symbolSize) / 2,
                y: (tileSize - symbolSize) / 2,
                width: symbolSize,
                height: symbolSize
            )
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: symbolSize * 0.8),
                .foregroundColor: UIColor.black
            ]
            let text = "$"
            text.draw(in: symbolRect, withAttributes: attributes)
        }
        return SKTexture(image: image)
        #else
        return SKColor.systemYellow.dl_texture(square: tileSize)
        #endif
    }
    
    /// Creates a sidewalk texture with a tree symbol.
    private static func createSidewalkTreeTexture(tileSize: CGFloat) -> SKTexture {
        #if canImport(UIKit)
        let rect = CGRect(x: 0, y: 0, width: tileSize, height: tileSize)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { ctx in
            // Base sidewalk color
            SKColor.lightGray.setFill()
            ctx.cgContext.fill(rect)
            
            // Draw tree symbol (simple circle)
            let treeSize = tileSize * 0.4
            let treeRect = CGRect(
                x: (tileSize - treeSize) / 2,
                y: (tileSize - treeSize) / 2,
                width: treeSize,
                height: treeSize
            )
            
            UIColor.systemGreen.setFill()
            ctx.cgContext.fillEllipse(in: treeRect)
        }
        return SKTexture(image: image)
        #else
        return SKColor.lightGray.dl_texture(square: tileSize)
        #endif
    }
    
    /// Creates a sidewalk texture with a fire hydrant symbol.
    private static func createSidewalkHydrantTexture(tileSize: CGFloat) -> SKTexture {
        #if canImport(UIKit)
        let rect = CGRect(x: 0, y: 0, width: tileSize, height: tileSize)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { ctx in
            // Base sidewalk color
            SKColor.lightGray.setFill()
            ctx.fill(rect)
            
            // Draw fire hydrant symbol (small red rectangle)
            let hydrantSize = tileSize * 0.3
            let hydrantRect = CGRect(
                x: (tileSize - hydrantSize) / 2,
                y: (tileSize - hydrantSize) / 2,
                width: hydrantSize,
                height: hydrantSize
            )
            
            UIColor.systemRed.setFill()
            ctx.fill(hydrantRect)
        }
        return SKTexture(image: image)
        #else
        return SKColor.lightGray.dl_texture(square: tileSize)
        #endif
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
