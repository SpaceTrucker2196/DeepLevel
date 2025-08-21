import CoreGraphics

struct Rect {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
    
    var center: (Int, Int) { (x + w / 2, y + h / 2) }
    
    func intersects(_ other: Rect) -> Bool {
        !(x + w <= other.x ||
          other.x + other.w <= x ||
          y + h <= other.y ||
          other.y + other.h <= y)
    }
}