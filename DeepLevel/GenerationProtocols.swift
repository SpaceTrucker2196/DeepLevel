import Foundation

/// Protocol defining the interface for dungeon generation algorithms.
///
/// Provides a common interface that all dungeon generation implementations
/// must conform to, enabling interchangeable generation strategies while
/// maintaining consistent input and output formats.
///
/// - Since: 1.0.0
protocol DungeonGenerating {
    /// Generates a complete dungeon map using the specified configuration.
    ///
    /// Creates a fully populated dungeon including room layout, corridors,
    /// doors, and player spawn location based on the provided configuration
    /// and random number generator.
    ///
    /// - Parameters:
    ///   - config: Configuration parameters controlling generation behavior
    ///   - rng: Random number generator for deterministic or random generation
    /// - Returns: A complete dungeon map ready for gameplay
    /// - Complexity: Implementation-dependent, typically O(width * height)
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap
}