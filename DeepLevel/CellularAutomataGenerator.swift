import Foundation
import GameplayKit

final class CellularAutomataGenerator: DungeonGenerating {
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