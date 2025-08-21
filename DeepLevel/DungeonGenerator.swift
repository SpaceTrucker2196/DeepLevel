import Foundation
import GameplayKit

/// Orchestrates dungeon generation using various algorithms and post-processing.
///
/// Acts as the main coordinator for dungeon creation, selecting the appropriate
/// generation algorithm based on configuration and applying visual enhancements
/// like floor variants using procedural noise.
///
/// - Since: 1.0.0
final class DungeonGenerator {
    /// The random number generator used for all generation decisions.
    private var rng: RandomNumberGenerator
    
    /// Configuration parameters controlling generation behavior.
    private let config: DungeonConfig
    
    /// Creates a new dungeon generator with the specified configuration.
    ///
    /// Initializes the appropriate random number generator based on whether
    /// a seed is provided in the configuration for deterministic generation.
    ///
    /// - Parameter config: Configuration parameters for dungeon generation
    init(config: DungeonConfig) {
        self.config = config
        if let seed = config.seed {
            self.rng = SeededGenerator(seed: seed)
        } else {
            self.rng = SystemRandomNumberGenerator()
        }
    }
    
    /// Generates a complete dungeon using the configured algorithm.
    ///
    /// Selects the appropriate generation algorithm, creates the basic dungeon
    /// structure, then applies visual enhancements like floor texture variants
    /// using procedural noise for realistic appearance.
    ///
    /// - Returns: A fully generated dungeon map ready for gameplay
    /// - Complexity: Algorithm-dependent, typically O(width * height)
    func generate() -> DungeonMap {
        var localRng = rng
        let generator: DungeonGenerating
        switch config.algorithm {
        case .roomsCorridors: generator = RoomsGenerator()
        case .bsp: generator = BSPGenerator()
        case .cellular: generator = CellularAutomataGenerator()
        }
        var map = generator.generate(config: config, rng: &localRng)
        applyFloorVariants(&map, rng: &localRng)
        return map
    }
    
    /// Applies visual variety to floor tiles using Perlin noise.
    ///
    /// Uses GameplayKit's Perlin noise to create natural-looking variation
    /// in floor tile appearance, adding visual interest while maintaining
    /// gameplay functionality.
    ///
    /// - Parameters:
    ///   - map: The dungeon map to modify
    ///   - rng: Random number generator for noise seed generation
    /// - Complexity: O(width * height)
    private func applyFloorVariants(_ map: inout DungeonMap, rng: inout RandomNumberGenerator) {
        // Use Perlin noise for variants
        let source = GKPerlinNoiseSource(frequency: 0.08, octaveCount: 3, persistence: 0.5, lacunarity: 2.0, seed: Int32(config.seed ?? UInt64.random(in: 0...UInt64(UInt32.max), using: &rng)))
        let noise = GKNoise(source)
        let sample = GKNoiseMap(noise, size: vector_double2( Double(map.width), Double(map.height)), origin: vector_double2(0,0), sampleCount: vector_int2(Int32(map.width), Int32(map.height)), seamless: false)
        for y in 0..<map.height {
            for x in 0..<map.width {
                let idx = map.index(x: x, y: y)
                if map.tiles[idx].kind == .floor {
                    let val = sample.value(at: vector_int2(Int32(x), Int32(y)))
                    let scaled = Int(((val + 1) / 2.0) * 3.0) // 0-2 variants
                    map.tiles[idx].variant = max(0,min(2,scaled))
                }
            }
        }
    }
}
