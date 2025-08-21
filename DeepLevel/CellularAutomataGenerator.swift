import Foundation
import GameplayKit

/// Generates cave-like dungeons using cellular automata algorithm.
///
/// Creates organic, natural-looking cave systems by starting with random noise
/// and applying smoothing rules repeatedly. The algorithm produces connected
/// cavern systems with irregular walls and open spaces.
///
/// - Since: 1.0.0
final class CellularAutomataGenerator: DungeonGenerating {
    /// Generates a complete dungeon using cellular automata smoothing.
    ///
    /// Starts with random noise based on fill probability, then applies
    /// cellular automata rules to smooth the caves. Ensures connectivity
    /// by finding the largest open region and making it the playable area.
    ///
    /// - Parameters:
    ///   - config: Configuration parameters including fill probability and steps
    ///   - rng: Random number generator for initial noise generation
    /// - Returns: A complete dungeon map with organic cave-like structure
    /// - Complexity: O(width * height * cellularSteps)
    func generate(config: DungeonConfig, rng: inout RandomNumberGenerator) -> DungeonMap {
        var grid = Array(repeating: Array(repeating: false, count: config.height), count: config.width)
        for x in 0..<config.width {
            for y in 0..<config.height {
                if x == 0 || y == 0 || x == config.width-1 || y == config.height-1 {
                    grid[x][y] = true
                } else {
                    grid[x][y] = Double.random(in: 0...1, using: &rng) < config.cellularFillProb
                }
            }
        }
        for _ in 0..<config.cellularSteps {
            grid = step(grid, config: config)
        }
        // Ensure connectivity: find largest open region
        var visited = Array(repeating: false, count: config.width * config.height)
        var best: [(Int,Int)] = []
        for x in 1..<config.width-1 {
            for y in 1..<config.height-1 {
                if !grid[x][y] && !visited[x + y*config.width] {
                    var queue = [(x,y)]
                    var region: [(Int,Int)] = []
                    visited[x + y*config.width] = true
                    var idx = 0
                    while idx < queue.count {
                        let (cx,cy) = queue[idx]; idx += 1
                        region.append((cx,cy))
                        for d in [(-1,0),(1,0),(0,-1),(0,1)] {
                            let nx = cx + d.0, ny = cy + d.1
                            if nx>0 && ny>0 && nx<config.width-1 && ny<config.height-1 && !grid[nx][ny] && !visited[nx + ny*config.width] {
                                visited[nx + ny*config.width] = true
                                queue.append((nx,ny))
                            }
                        }
                    }
                    if region.count > best.count { best = region }
                }
            }
        }
        // Everything not in best region becomes wall
        var tiles: [Tile] = []
        for x in 0..<config.width {
            for y in 0..<config.height {
                let floor = best.contains(where: { $0.0 == x && $0.1 == y })
                tiles.append(Tile(kind: floor ? .floor : .wall))
            }
        }
        let start = best.randomElement(using: &rng) ?? (config.width/2, config.height/2)
        return DungeonMap(width: config.width,
                          height: config.height,
                          tiles: tiles,
                          playerStart: start,
                          rooms: [])
    }
    
    /// Applies one iteration of cellular automata smoothing rules.
    ///
    /// Uses the "4-5" rule: cells with more than 4 adjacent walls become walls,
    /// cells with fewer than 4 adjacent walls become floors. This creates
    /// smooth, organic-looking cave structures.
    ///
    /// - Parameters:
    ///   - grid: Current state of the cellular grid
    ///   - config: Configuration for bounds checking
    /// - Returns: New grid state after applying smoothing rules
    /// - Complexity: O(width * height)
    private func step(_ grid: [[Bool]], config: DungeonConfig) -> [[Bool]] {
        var out = grid
        for x in 1..<config.width-1 {
            for y in 1..<config.height-1 {
                let walls = countAdjacentWalls(grid, x, y)
                if walls > 4 {
                    out[x][y] = true
                } else if walls < 4 {
                    out[x][y] = false
                }
            }
        }
        return out
    }
    
    /// Counts the number of wall cells adjacent to a given position.
    ///
    /// Examines all 8 neighboring cells (including diagonals) to count
    /// how many are walls, used for cellular automata rule application.
    ///
    /// - Parameters:
    ///   - grid: The cellular grid to examine
    ///   - x: X coordinate of the cell to check neighbors for
    ///   - y: Y coordinate of the cell to check neighbors for
    /// - Returns: Number of adjacent wall cells (0-8)
    /// - Complexity: O(1)
    private func countAdjacentWalls(_ grid: [[Bool]], _ x: Int, _ y: Int) -> Int {
        var c = 0
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                if grid[x+dx][y+dy] { c += 1 }
            }
        }
        return c
    }
}