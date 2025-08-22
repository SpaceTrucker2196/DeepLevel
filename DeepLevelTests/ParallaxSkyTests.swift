import Testing
@testable import DeepLevel

/// Tests for the parallax sky system.
struct ParallaxSkyTests {
    
    @Test func testParallaxSkyInitialization() async throws {
        let sceneSize = CGSize(width: 800, height: 600)
        let parallaxSky = ParallaxSky(sceneSize: sceneSize)
        
        // Should have 3 sky layers
        #expect(parallaxSky.children.count == 3)
        
        // Each layer should be properly positioned
        for child in parallaxSky.children {
            let layer = child as! SKSpriteNode
            #expect(layer.anchorPoint == CGPoint(x: 0.5, y: 0.5))
            #expect(layer.zPosition < 0) // Should be behind everything
        }
    }
    
    @Test func testParallaxMovement() async throws {
        let sceneSize = CGSize(width: 800, height: 600)
        let parallaxSky = ParallaxSky(sceneSize: sceneSize)
        
        // Center sky at origin
        parallaxSky.centerOn(position: .zero)
        
        // Record initial positions
        let initialPositions = parallaxSky.children.map { ($0 as! SKSpriteNode).position }
        
        // Simulate camera movement
        let newCameraPosition = CGPoint(x: 100, y: 50)
        parallaxSky.updateParallax(cameraPosition: newCameraPosition)
        
        // Check that layers moved by different amounts (parallax effect)
        let finalPositions = parallaxSky.children.map { ($0 as! SKSpriteNode).position }
        
        for i in 0..<initialPositions.count {
            // Each layer should move less than the camera movement
            let deltaX = finalPositions[i].x - initialPositions[i].x
            let deltaY = finalPositions[i].y - initialPositions[i].y
            
            #expect(abs(deltaX) < 100) // Movement should be less than camera movement
            #expect(abs(deltaY) < 50)
            #expect(deltaX > 0) // Should move in same direction as camera
            #expect(deltaY > 0)
        }
    }
}