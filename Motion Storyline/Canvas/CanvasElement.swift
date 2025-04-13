import SwiftUI

struct CanvasElement: Identifiable {
    var id = UUID()
    var type: ElementType
    var position: CGPoint
    var size: CGSize
    var rotation: Double = 0
    var opacity: Double = 1.0
    var color: Color = .blue
    var text: String = "Text"
    var textAlignment: TextAlignment = .leading
    var displayName: String
    var isAspectRatioLocked: Bool = true // Default to locked aspect ratio
    
    // Computed property to get the center of the element as the rotation anchor point
    var rotationAnchorPoint: CGPoint {
        // Anchor point is always at the center of the element, relative to its own coordinate space
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }
    
    // Compute the absolute position of the rotation anchor on the canvas
    var absoluteAnchorPosition: CGPoint {
        // The position property is already the center of the element
        return position
    }
    
    enum ElementType: String, CaseIterable {
        case rectangle = "Rectangle"
        case ellipse = "Ellipse"
        case text = "Text"
        case image = "Image"
        case video = "Video"
    }
    
    // Factory methods for creating different types of elements
    static func rectangle(at position: CGPoint, size: CGSize = CGSize(width: 100, height: 80)) -> CanvasElement {
        // Ensure we respect the exact size passed in without any minimums
        CanvasElement(
            type: .rectangle,
            position: position,
            size: size,
            color: .blue,
            displayName: "Rectangle"
        )
    }
    
    static func ellipse(at position: CGPoint, size: CGSize = CGSize(width: 100, height: 80)) -> CanvasElement {
        // Ensure we respect the exact size passed in without any minimums
        CanvasElement(
            type: .ellipse,
            position: position,
            size: size,
            color: .green,
            displayName: "Ellipse"
        )
    }
    
    static func text(at position: CGPoint, content: String = "Text") -> CanvasElement {
        CanvasElement(
            type: .text,
            position: position,
            size: CGSize(width: 200, height: 50),
            color: .black,
            text: content,
            textAlignment: .leading,
            displayName: "Text"
        )
    }
} 