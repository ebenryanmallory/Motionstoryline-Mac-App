import SwiftUI

struct CanvasElementView: View {
    let element: CanvasElement
    let isSelected: Bool
    var onResize: ((CGSize) -> Void)?
    var isTemporary: Bool = false
    var isDragging: Bool = false
    
    var body: some View {
        ZStack {
            // Main element content
            Group {
                switch element.type {
                case .rectangle:
                    Rectangle()
                        .fill(element.color)
                        .opacity(element.opacity)
                case .ellipse:
                    Ellipse()
                        .fill(element.color)
                        .opacity(element.opacity)
                case .text:
                    Text(element.text)
                        .foregroundColor(element.color)
                        .opacity(element.opacity)
                        .frame(width: element.size.width)
                default:
                    EmptyView()
                }
            }
            .frame(width: element.size.width, height: element.size.height)
            
            // Selection overlay
            if isSelected {
                SelectionOverlay(
                    size: element.size,
                    onResize: onResize
                )
            }
            
            // Temporary element style
            if isTemporary {
                Group {
                    if element.type == .rectangle {
                        Rectangle()
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .frame(width: element.size.width, height: element.size.height)
                    } else if element.type == .ellipse {
                        Ellipse()
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .frame(width: element.size.width, height: element.size.height)
                    }
                }
            }
        }
        .position(element.position)
        .rotationEffect(.degrees(element.rotation))
        .shadow(color: isDragging ? Color.black.opacity(0.5) : Color.clear, radius: 8)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.interactiveSpring(), value: isDragging)
    }
}

// Component for selection overlay with handles
struct SelectionOverlay: View {
    let size: CGSize
    var onResize: ((CGSize) -> Void)?
    
    // Handle positions
    private let handleSize: CGFloat = 8
    private let outlineOffset: CGFloat = 4 // Offset for the selection border
    
    var body: some View {
        ZStack {
            // Selection border - use a Rectangle directly positioned at the center
            Rectangle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: size.width + 2*outlineOffset, height: size.height + 2*outlineOffset)
            
            // Corner handles
            Group {
                // Top-left
                ResizeHandle(position: .topLeft, size: handleSize)
                    .position(x: -outlineOffset, y: -outlineOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .topLeft)
                            }
                    )
                
                // Top-right
                ResizeHandle(position: .topRight, size: handleSize)
                    .position(x: size.width + outlineOffset, y: -outlineOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .topRight)
                            }
                    )
                
                // Bottom-left
                ResizeHandle(position: .bottomLeft, size: handleSize)
                    .position(x: -outlineOffset, y: size.height + outlineOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .bottomLeft)
                            }
                    )
                
                // Bottom-right
                ResizeHandle(position: .bottomRight, size: handleSize)
                    .position(x: size.width + outlineOffset, y: size.height + outlineOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .bottomRight)
                            }
                    )
            }
        }
        .frame(width: size.width, height: size.height) // Frame the whole overlay to match element size
    }
    
    private func handleResize(value: DragGesture.Value, corner: ResizeHandle.Position) {
        // Calculate the change in size based on the drag
        let deltaX = value.translation.width
        let deltaY = value.translation.height
        
        // Calculate new size based on which corner is being dragged
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        switch corner {
        case .topLeft:
            newWidth = max(20, size.width - deltaX)
            newHeight = max(20, size.height - deltaY)
        case .topRight:
            newWidth = max(20, size.width + deltaX)
            newHeight = max(20, size.height - deltaY)
        case .bottomLeft:
            newWidth = max(20, size.width - deltaX)
            newHeight = max(20, size.height + deltaY)
        case .bottomRight:
            newWidth = max(20, size.width + deltaX)
            newHeight = max(20, size.height + deltaY)
        }
        
        // For constrained shapes (squares/circles), use the smaller dimension to ensure proportions
        let constrainedSize = min(newWidth, newHeight)
        let newSize = CGSize(width: constrainedSize, height: constrainedSize)
        
        // Call the resize callback
        onResize?(newSize)
    }
}

// Resize handle component
struct ResizeHandle: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let position: Position
    let size: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(
                Rectangle()
                    .stroke(Color.blue, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        
        CanvasElementView(
            element: CanvasElement.rectangle(at: CGPoint(x: 150, y: 150), size: CGSize(width: 200, height: 150)),
            isSelected: true,
            onResize: { _ in }
        )
    }
    .frame(width: 400, height: 300)
} 
#endif
