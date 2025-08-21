import Foundation
import GameplayKit

final class DungeonGenerator {
    private var rng: RandomNumberGenerator
    private let config: DungeonConfig
    
    init(config: DungeonConfig) {
        self.config = config
        if let seed = config.seed {
            self.rng = SeededGenerator(seed: seed)
        } else {
            self.rng = SystemRandomNumberGenerator()
        }
    }
    
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
