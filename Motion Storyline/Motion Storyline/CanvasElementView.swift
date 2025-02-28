import SwiftUI

struct CanvasElementView: View {
    let element: CanvasElement
    let isSelected: Bool
    var onResize: ((CGSize) -> Void)?
    var isTemporary: Bool = false
    
    var body: some View {
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
        .position(element.position)
        .rotationEffect(.degrees(element.rotation))
        .overlay(
            isSelected ? 
                SelectionOverlay(
                    size: element.size,
                    onResize: onResize
                )
                : nil
        )
        .overlay(
            isTemporary ?
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
                : nil
        )
    }
}

// Component for selection overlay with handles
struct SelectionOverlay: View {
    let size: CGSize
    var onResize: ((CGSize) -> Void)?
    
    // Handle positions
    private let handleSize: CGFloat = 8
    
    var body: some View {
        ZStack {
            // Selection border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: size.width + 8, height: size.height + 8)
            
            // Corner handles
            Group {
                // Top-left
                ResizeHandle(position: .topLeft, size: handleSize)
                    .position(x: -size.width/2 - 4, y: -size.height/2 - 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .topLeft)
                            }
                    )
                
                // Top-right
                ResizeHandle(position: .topRight, size: handleSize)
                    .position(x: size.width/2 + 4, y: -size.height/2 - 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .topRight)
                            }
                    )
                
                // Bottom-left
                ResizeHandle(position: .bottomLeft, size: handleSize)
                    .position(x: -size.width/2 - 4, y: size.height/2 + 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .bottomLeft)
                            }
                    )
                
                // Bottom-right
                ResizeHandle(position: .bottomRight, size: handleSize)
                    .position(x: size.width/2 + 4, y: size.height/2 + 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleResize(value: value, corner: .bottomRight)
                            }
                    )
            }
        }
    }
    
    private func handleResize(value: DragGesture.Value, corner: ResizeHandle.Position) {
        // Calculate the change in size based on the drag
        let deltaX = value.translation.width
        let deltaY = value.translation.height
        
        // For constrained resizing (maintaining square/circle), use the larger dimension
        let delta = max(abs(deltaX), abs(deltaY))
        
        // Determine the sign based on which corner is being dragged
        let signX: CGFloat
        let signY: CGFloat
        
        switch corner {
        case .topLeft:
            signX = -1
            signY = -1
        case .topRight:
            signX = 1
            signY = -1
        case .bottomLeft:
            signX = -1
            signY = 1
        case .bottomRight:
            signX = 1
            signY = 1
        }
        
        // Calculate the new size, ensuring it doesn't go below minimum size
        let newWidth = max(20, size.width + (signX * delta * 2))
        let newHeight = max(20, size.height + (signY * delta * 2))
        
        // For constrained shapes, use the smaller dimension to ensure it stays a square/circle
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