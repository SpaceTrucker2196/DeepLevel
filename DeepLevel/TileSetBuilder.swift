import SpriteKit

final class TileSetBuilder {
    struct TileRefs {
        let floorVariants: [SKTileGroup]
        let wall: SKTileGroup
        let door: SKTileGroup
        let secretDoor: SKTileGroup
    }
    
    static func build(tileSize: CGFloat) -> (SKTileSet, TileRefs) {
        // Generate or fetch textures
        let floorTextures = (0..<3).map { variantColor(index: $0).dl_texture(square: tileSize) }
        let wallTexture   = SKColor(white: 0.10, alpha: 1).dl_texture(square: tileSize)
        let doorTexture   = SKColor.brown.dl_texture(square: tileSize)
        let secretTexture = SKColor.purple.dl_texture(square: tileSize)
        
        func makeGroup(named name: String, texture: SKTexture) -> SKTileGroup {
            let def = SKTileDefinition(texture: texture, size: CGSize(width: tileSize, height: tileSize))
            let g = SKTileGroup(tileDefinition: def)      // NO name: parameter
            g.name = name                                 // Assign name explicitly
            return g
        }
        
        let floorGroups = floorTextures.enumerated().map { makeGroup(named: "floor_\($0.offset)", texture: $0.element) }
        let wallGroup   = makeGroup(named: "wall", texture: wallTexture)
        let doorGroup   = makeGroup(named: "doorClosed", texture: doorTexture)
        let secretGroup = makeGroup(named: "doorSecret", texture: secretTexture)
        
        let groups = floorGroups + [wallGroup, doorGroup, secretGroup]
        
        // Basic initializer (broadest compatibility)
        let tileSet = SKTileSet(tileGroups: groups)
        
        let refs = TileRefs(floorVariants: floorGroups,
                            wall: wallGroup,
                            door: doorGroup,
                            secretDoor: secretGroup)
        return (tileSet, refs)
    }
    
    private static func variantColor(index: Int) -> SKColor {
        switch index {
        case 0: return SKColor(white: 0.72, alpha: 1)
        case 1: return SKColor(white: 0.66, alpha: 1)
        default: return SKColor(white: 0.78, alpha: 1)
        }
    }
}

private var dlTextureCache: [UInt64: SKTexture] = [:]

private extension SKColor {
    func dl_texture(square size: CGFloat) -> SKTexture {
        // Extract RGBA for cache key
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if !getRed(&r, green: &g, blue: &b, alpha: &a) {
            r = 1; g = 1; b = 1; a = 1
        }
        let key = UInt64(r * 255) << 48
               | UInt64(g * 255) << 32
               | UInt64(b * 255) << 16
               | UInt64(a * 255) << 8
               | UInt64(size.rounded())
        if let cached = dlTextureCache[key] { return cached }
        
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
        #elseif canImport(AppKit)
        let imgSize = NSSize(width: size, height: size)
        let img = NSImage(size: imgSize)
        img.lockFocus()
        self.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imgSize)).fill()
        NSColor(calibratedWhite: 0, alpha: 0.08).setFill()
        for _ in 0..<Int(size/2) {
            let px = CGFloat.random(in: 0..<size)
            let py = CGFloat.random(in: 0..<size)
            NSBezierPath(rect: NSRect(x: px, y: py, width: 1, height: 1)).fill()
        }
        img.unlockFocus()
        texture = SKTexture(image: img)
        #else
        texture = SKTexture()
        #endif
        
        dlTextureCache[key] = texture
        return texture
    }
}
