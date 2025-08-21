import CoreGraphics

/// Represents a rectangular area defined by position and dimensions.
///
/// A simple rectangle structure used for room generation, collision detection,
/// and spatial calculations within the dungeon generation system.
///
/// - Since: 1.0.0
struct Rect {
    /// X coordinate of the rectangle's left edge.
    let x: Int
    
    /// Y coordinate of the rectangle's bottom edge.
    let y: Int
    
    /// Width of the rectangle in grid units.
    let w: Int
    
    /// Height of the rectangle in grid units.
    let h: Int
    
    /// The center point of the rectangle.
    ///
    /// - Returns: A tuple containing the center coordinates (x, y)
    /// - Complexity: O(1)
    var center: (Int, Int) { (x + w / 2, y + h / 2) }
    
    /// Checks if this rectangle intersects with another rectangle.
    ///
    /// Determines whether two rectangles overlap in any way, useful for
    /// collision detection and room placement validation.
    ///
    /// - Parameter other: The rectangle to test intersection against
    /// - Returns: `true` if the rectangles intersect, `false` otherwise
    /// - Complexity: O(1)
    func intersects(_ other: Rect) -> Bool {
        !(x + w <= other.x ||
          other.x + other.w <= x ||
          y + h <= other.y ||
          other.y + other.h <= y)
    }
}