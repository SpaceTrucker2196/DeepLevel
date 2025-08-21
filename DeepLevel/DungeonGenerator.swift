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
        // Derive a safe Int32 seed (avoid trapping on Int32 init)
        let seed32: Int32
        if let userSeed = config.seed {
            // Mix / hash userSeed to spread bits, then take lower 32 bits
            var z = userSeed &+ 0x9E3779B97F4A7C15
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            let u32 = UInt32(truncatingIfNeeded: z)
            seed32 = Int32(bitPattern: u32)
        } else {
            seed32 = Int32.random(in: Int32.min...Int32.max, using: &rng)
        }
        
        let source = GKPerlinNoiseSource(
            frequency: 0.08,
            octaveCount: 3,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: seed32
        )
        let noise = GKNoise(source)
        let sample = GKNoiseMap(
            noise,
            size: vector_double2(Double(map.width), Double(map.height)),
            origin: vector_double2(0,0),
            sampleCount: vector_int2(Int32(map.width), Int32(map.height)),
            seamless: false
        )
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
