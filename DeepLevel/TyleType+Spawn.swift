//
//  TyleType+.swift
//  DeepLevel
//
//  Created by Jeffrey Kunzelman on 8/22/25.
//


import Foundation

extension TileKind {
    /// Indicates whether monsters / charmed entities are allowed to spawn on this tile.
    ///
    /// Adjust this list as you introduce new walkable surface types.
    var isSpawnSurface: Bool {
        switch self {
        case .floor,
             .urban3,
             .street :
            return true
        // If later you decide to allow these, just uncomment:
        // case .sidewalk, .sidewalkTree, .sidewalkHydrant, .park,
        //      .residential1, .residential2, .residential3, .residential4,
        //      .urban1, .urban2, .urban3, .redLight, .retail, .hidingArea:
        //     return true
        default:
            return false
        }
    }
    
    /// Indicates whether this tile is a sidewalk type.
    var isSidewalk: Bool {
        switch self {
        case .sidewalk, .sidewalkTree, .sidewalkHydrant:
            return true
        default:
            return false
        }
    }
}
