import SpriteKit

/// Builds SpriteKit tile sets and texture references for dungeon rendering.
///
/// Creates all necessary tile groups and textures for rendering dungeon maps,
/// including floor variants, walls, and different door types. Manages texture
/// caching for performance and supports both iOS/UIKit and macOS/AppKit platforms.
///
/// - Since: 1.0.0
final class TileSetBuilder {
    /// Contains references to tile groups for efficient tile map updates.
    ///
    /// Provides quick access to different tile types without searching
    /// through the complete tile set during rendering operations.
    ///
    /// - Since: 1.0.0
    struct TileRefs {
        /// Array of floor tile groups with different visual variants.
        let floorVariants: [SKTileGroup]
        
        /// Tile group for wall rendering.
        let wall: SKTileGroup
        
        /// Tile group for solid rendering (non-carvable walls).
        let solid: SKTileGroup
        
        /// Tile group for closed door rendering.
        let door: SKTileGroup
        
        /// Tile group for secret door rendering.
        let secretDoor: SKTileGroup
    }
    
    /// Builds a complete tile set with all necessary tile groups.
    ///
    /// Creates textures for different tile types including floor variants,
    /// walls, and doors, then assembles them into a SpriteKit tile set
    /// suitable for tile map rendering.
    ///
    /// - Parameter tileSize: Size of each tile in points
    /// - Returns: A tuple containing the complete tile set and tile group references
    /// - Complexity: O(1) - generates fixed number of tile types
    static func build(tileSize: CGFloat) -> (SKTileSet, TileRefs) {
        // Generate or fetch textures
        let floorTextures = (0..<3).map { variantColor(index: $0).dl_texture(square: tileSize) }
        let wallTexture   = SKColor(white: 0.10, alpha: 1).dl_texture(square: tileSize)
        let solidTexture  = SKColor(white: 0.05, alpha: 1).dl_texture(square: tileSize)  // Darker than wall
        let doorTexture   = SKColor.brown.dl_texture(square: tileSize)
        let secretTexture = SKColor.purple.dl_texture(square: tileSize)
        
        /// Creates a named tile group from a texture.
        ///
        /// - Parameters:
        ///   - name: Name identifier for the tile group
        ///   - texture: Texture to use for the tile group
        /// - Returns: A configured tile group ready for use
        func makeGroup(named name: String, texture: SKTexture) -> SKTileGroup {
            let def = SKTileDefinition(texture: texture, size: CGSize(width: tileSize, height: tileSize))
            let g = SKTileGroup(tileDefinition: def)      // NO name: parameter
            g.name = name                                 // Assign name explicitly
            return g
        }
        
        let floorGroups = floorTextures.enumerated().map { makeGroup(named: "floor_\($0.offset)", texture: $0.element) }
        let wallGroup   = makeGroup(named: "wall", texture: wallTexture)
        let solidGroup  = makeGroup(named: "solid", texture: solidTexture)
        let doorGroup   = makeGroup(named: "doorClosed", texture: doorTexture)
        let secretGroup = makeGroup(named: "doorSecret", texture: secretTexture)
        
        let groups = floorGroups + [wallGroup, solidGroup, doorGroup, secretGroup]
        
        // Basic initializer (broadest compatibility)
        let tileSet = SKTileSet(tileGroups: groups)
        
        let refs = TileRefs(floorVariants: floorGroups,
                            wall: wallGroup,
                            solid: solidGroup,
                            door: doorGroup,
                            secretDoor: secretGroup)
        return (tileSet, refs)
    }
    
    /// Provides color variations for floor tiles.
    ///
    /// Returns different grayscale colors to create visual variety
    /// in floor rendering without using multiple texture files.
    ///
    /// - Parameter index: The variant index (0-2)
    /// - Returns: A color suitable for floor tile rendering
    /// - Complexity: O(1)
    private static func variantColor(index: Int) -> SKColor {
        switch index {
        case 0: return SKColor(white: 0.72, alpha: 1)
        case 1: return SKColor(white: 0.66, alpha: 1)
        default: return SKColor(white: 0.78, alpha: 1)
        }
    }
}

/// Cache for generated textures to avoid recreating identical textures.
private var dlTextureCache: [UInt64: SKTexture] = [:]

/// Extension providing texture generation capabilities for SKColor.
///
/// Adds methods to generate textured sprites directly from colors,
/// with cross-platform support for both iOS and macOS rendering.
private extension SKColor {
    /// Generates a textured square from this color with subtle noise overlay.
    ///
    /// Creates a solid color background with randomly placed dark pixels
    /// for texture. Results are cached for performance using color and size
    /// as the cache key.
    ///
    /// - Parameter size: The width and height of the square texture in points
    /// - Returns: A cached or newly generated texture
    /// - Complexity: O(size²) for new textures, O(1) for cached
    /// - Note: Uses platform-specific rendering (UIKit for iOS, AppKit for macOS)
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
