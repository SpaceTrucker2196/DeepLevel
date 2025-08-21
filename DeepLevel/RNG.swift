import Foundation

/// A seeded random number generator for deterministic random number generation.
///
/// Implements a linear congruential generator with a specific mathematical formula
/// to ensure reproducible random sequences when given the same seed. This is
/// essential for generating consistent dungeon layouts that can be recreated.
///
/// - Since: 1.0.0
struct SeededGenerator: RandomNumberGenerator {
    /// Internal state of the random number generator.
    private var state: UInt64
    
    /// Creates a new seeded random number generator.
    ///
    /// - Parameter seed: The initial seed value for deterministic generation
    init(seed: UInt64) { self.state = seed &* 2685821657736338717 }
    
    /// Generates the next random number in the sequence.
    ///
    /// Uses a combination of XOR shifts and multiplications to produce
    /// high-quality pseudo-random numbers with good distribution properties.
    ///
    /// - Returns: A 64-bit unsigned integer random value
    /// - Complexity: O(1)
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}