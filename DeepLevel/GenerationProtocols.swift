import Foundation

protocol DungeonGenerating {
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap
}