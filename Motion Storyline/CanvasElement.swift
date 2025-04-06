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
    var displayName: String
    
    enum ElementType: String, CaseIterable {
        case rectangle = "Rectangle"
        case ellipse = "Ellipse"
        case text = "Text"
        case image = "Image"
        case video = "Video"
    }
    
    // Factory methods for creating different types of elements
    static func rectangle(at position: CGPoint, size: CGSize = CGSize(width: 100, height: 80)) -> CanvasElement {
        CanvasElement(
            type: .rectangle,
            position: position,
            size: size,
            color: .blue,
            displayName: "Rectangle"
        )
    }
    
    static func ellipse(at position: CGPoint, size: CGSize = CGSize(width: 100, height: 80)) -> CanvasElement {
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
            displayName: "Text"
        )
    }
} 