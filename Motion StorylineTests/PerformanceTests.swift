import XCTest
import SwiftUI
import AppKit
@testable import Motion_Storyline

final class PerformanceTests: XCTestCase {
    // MARK: - Properties
    
    // Sample canvas elements for testing
    var smallElementSet: [CanvasElement] = []
    var mediumElementSet: [CanvasElement] = []
    var largeElementSet: [CanvasElement] = []
    
    // Common test canvas size
    let testCanvasSize = CGSize(width: 1920, height: 1080)
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        // Set up small element set (10 elements)
        smallElementSet = createTestElements(count: 10)
        
        // Set up medium element set (50 elements)
        mediumElementSet = createTestElements(count: 50)
        
        // Set up large element set (200 elements)
        largeElementSet = createTestElements(count: 200)
    }
    
    override func tearDownWithError() throws {
        smallElementSet = []
        mediumElementSet = []
        largeElementSet = []
    }
    
    // MARK: - Helper Methods
    
    /// Creates a specified number of test elements of various types
    private func createTestElements(count: Int) -> [CanvasElement] {
        var elements: [CanvasElement] = []
        
        // Create a mix of different element types
        for i in 0..<count {
            let elementType: CanvasElement.ElementType
            
            // Distribute element types
            switch i % 4 {
            case 0: elementType = .rectangle
            case 1: elementType = .ellipse
            case 2: elementType = .text
            case 3: elementType = .image
            default: elementType = .rectangle
            }
            
            // Calculate a position that distributes elements across the canvas
            let row = (i / 10) % 20
            let col = i % 10
            let position = CGPoint(
                x: 100 + (col * 180),
                y: 100 + (row * 120)
            )
            
            // Create a color based on the index
            let nsColor = NSColor(
                hue: CGFloat(i % 12) / 12.0,
                saturation: 0.7,
                brightness: 0.9,
                alpha: 1.0
            )
            // Convert NSColor to SwiftUI Color
            let color = Color(nsColor)
            
            // Create the element
            var element = CanvasElement(
                type: elementType,
                position: position,
                size: CGSize(width: 80, height: 80),
                color: color,
                displayName: "Element \(i)"
            )
            
            // Set additional properties based on type
            if elementType == .text {
                element.text = "Text \(i)"
            }
            // Note: Since CanvasElement doesn't have an image property in this implementation,
            // we'll skip setting that property here
            
            elements.append(element)
        }
        
        return elements
    }
    
    /// Render a set of elements to an NSImage for testing render performance
    private func renderTestImage(elements: [CanvasElement], size: CGSize) -> NSImage {
        let image = NSImage(size: NSSize(width: size.width, height: size.height))
        
        image.lockFocus()
        
        // Draw white background
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: size.width, height: size.height).fill()
        
        // Draw each element
        for element in elements {
            // Get element drawing rect
            let rect = NSRect(
                x: element.position.x - element.size.width/2,
                y: element.position.y - element.size.height/2,
                width: element.size.width,
                height: element.size.height
            )
            
            switch element.type {
            case .rectangle:
                // Convert SwiftUI Color to NSColor
                if let cgColor = element.color.cgColor {
                    NSColor(cgColor: cgColor)?.setFill()
                } else {
                    NSColor.white.setFill()
                }
                rect.fill()
            case .ellipse:
                if let cgColor = element.color.cgColor {
                    NSColor(cgColor: cgColor)?.setFill()
                } else {
                    NSColor.white.setFill()
                }
                NSBezierPath(ovalIn: rect).fill()
            case .text:
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                // Safely convert color for text attributes
                let textColor: NSColor
                if let cgColor = element.color.cgColor, let nsColor = NSColor(cgColor: cgColor) {
                    textColor = nsColor
                } else {
                    textColor = NSColor.black // Default to black if color conversion fails
                }
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
                
                let text = element.text
                text.draw(in: rect, withAttributes: attributes)
            case .image, .video, .path:
                // Skip drawing images and other types not implemented in this test
                break
            }
        }
        
        image.unlockFocus()
        return image
    }
    
    /// Creates a basic animation controller with a simple animation
    private func createAnimationController(duration: Double, elementCount: Int) -> AnimationController {
        let animationController = AnimationController()
        animationController.setup(duration: duration)
        
        // Add a basic animation track for each element
        for i in 0..<min(elementCount, 10) { // Limit to 10 animations for larger sets
            let trackId = "element_\(i)_position"
            let track = animationController.addTrack(id: trackId) { (position: CGPoint) in
                // In a real implementation, this would update the element position
            }
            
            // Add keyframes to the track
            track.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
            track.add(keyframe: Keyframe(time: duration / 2, value: CGPoint(x: 300, y: 300)))
            track.add(keyframe: Keyframe(time: duration, value: CGPoint(x: 100, y: 500)))
        }
        
        return animationController
    }
    
    // MARK: - Canvas Rendering Performance Tests
    
    func testSmallCanvasRenderingPerformance() throws {
        measure {
            // Render small element set (10 elements)
            let _ = renderTestImage(elements: smallElementSet, size: testCanvasSize)
        }
    }
    
    func testMediumCanvasRenderingPerformance() throws {
        measure {
            // Render medium element set (50 elements)
            let _ = renderTestImage(elements: mediumElementSet, size: testCanvasSize)
        }
    }
    
    func testLargeCanvasRenderingPerformance() throws {
        measure {
            // Render large element set (200 elements)
            let _ = renderTestImage(elements: largeElementSet, size: testCanvasSize)
        }
    }
    
    // MARK: - Animation Performance Tests
    
    func testSimpleAnimationPlaybackPerformance() throws {
        // Create animation controller with 5-second duration
        let animationController = createAnimationController(duration: 5.0, elementCount: 10)
        
        measure {
            // Simulate animation playback by evaluating at multiple time points
            for time in stride(from: 0.0, to: 5.0, by: 0.1) {
                // Access the current value to simulate animation update
                for trackId in animationController.getAllTracks() {
                    if let track = animationController.getTrack(id: trackId) as? Motion_Storyline.KeyframeTrack<CGPoint> {
                        let _ = track.getValue(at: time)
                    }
                }
            }
        }
    }
    
    func testComplexAnimationPlaybackPerformance() throws {
        // Create animation controller with 5-second duration and more animations
        let animationController = createAnimationController(duration: 5.0, elementCount: 50)
        
        measure {
            // Simulate animation playback by evaluating at multiple time points
            for time in stride(from: 0.0, to: 5.0, by: 0.1) {
                // Access the current value to simulate animation update
                for trackId in animationController.getAllTracks() {
                    if let track = animationController.getTrack(id: trackId) as? Motion_Storyline.KeyframeTrack<CGPoint> {
                        let _ = track.getValue(at: time)
                    }
                }
            }
        }
    }
    
    // MARK: - Export Performance Tests
    
    func testExportSetupPerformance() throws {
        // Measure the performance of setting up an export configuration
        measure {
            for _ in 0..<10 {
                let _ = VideoExporter.ExportConfiguration(
                    format: .video,
                    width: Int(testCanvasSize.width),
                    height: Int(testCanvasSize.height),
                    frameRate: 30.0,
                    bitrate: 8_000_000,
                    proResProfile: .proRes422HQ,
                    includeAudio: true,
                    outputURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_export.mp4"),
                    baseFilename: nil,
                    imageQuality: nil,
                    additionalSettings: nil
                )
            }
        }
    }
    
    func testImagePreparationPerformance() throws {
        // Test the performance of preparing images for export
        // This is a simplified version of what would happen during video export
        
        measure {
            for _ in 0..<5 {
                // Render the small element set
                let image = renderTestImage(elements: smallElementSet, size: testCanvasSize)
                
                // Convert to bitmap representation (similar to what happens in export)
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let _ = NSBitmapImageRep(cgImage: cgImage)
                }
            }
        }
    }
    
    // Note: Full export tests would be integration tests that actually create files
    // Those would be better run manually or as part of a separate test suite
} 