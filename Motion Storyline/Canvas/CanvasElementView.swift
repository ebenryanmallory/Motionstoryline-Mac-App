import SwiftUI

struct CanvasElementView: View {
    let element: CanvasElement
    let isSelected: Bool
    var onResize: ((CGSize) -> Void)?
    var onRotate: ((Double) -> Void)?
    var isTemporary: Bool = false
    var isDragging: Bool = false
    
    // Use the element's rotationAnchorPoint property for rotation
    // We convert it to a UnitPoint which is required by rotationEffect
    private var anchorPoint: UnitPoint {
        // The anchor point is expressed in a unit coordinate space where (0,0) is the top-left
        // and (1,1) is the bottom-right. This normalizes the element's center regardless of its size.
        return UnitPoint(x: 0.5, y: 0.5) // Always at the center
    }
    
    var body: some View {
        ZStack {
            // Add a transparent hit area that's easy to click
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: element.size.width + 30, height: element.size.height + 30)
            
            // Main element content
            Group {
                switch element.type {
                case .rectangle:
                    Rectangle()
                        .fill(element.color.opacity(element.opacity))
                        .frame(width: element.size.width, height: element.size.height)
                        .contentShape(Rectangle())
                case .ellipse:
                    Ellipse()
                        .fill(element.color.opacity(element.opacity))
                        .frame(width: element.size.width, height: element.size.height)
                        .contentShape(Ellipse())
                case .text:
                    Text(element.text)
                        .foregroundColor(element.color)
                        .frame(width: element.size.width, height: element.size.height)
                        .multilineTextAlignment(element.textAlignment)
                        .opacity(element.opacity)
                        .contentShape(Rectangle())
                case .path:
                    PathView(points: element.path, color: element.color, opacity: element.opacity)
                        .frame(width: element.size.width, height: element.size.height)
                case .image:
                    if let url = element.assetURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: element.size.width, height: element.size.height)
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fill) // Or .fit, depending on desired behavior
                                    .frame(width: element.size.width, height: element.size.height)
                                    .clipped() // Important if using .fill to prevent overflow
                            case .failure:
                                Image(systemName: "photo") // Placeholder for failure
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: element.size.width, height: element.size.height)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .opacity(element.opacity)
                        .contentShape(Rectangle())
                    } else {
                        Image(systemName: "photo.on.rectangle.angled") // Placeholder if URL is nil
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: element.size.width, height: element.size.height)
                            .foregroundColor(.gray)
                            .opacity(element.opacity)
                            .contentShape(Rectangle())
                    }
                case .video:
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        Image(systemName: "film")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: min(element.size.width, element.size.height) * 0.5)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: element.size.width, height: element.size.height)
                    .opacity(element.opacity)
                    .clipped()
                    .contentShape(Rectangle())
                default:
                    EmptyView()
                }
            }
            
            // Selected element indicator - drawn on top
            if isSelected {
                SelectionOverlay(
                    size: element.size,
                    onResize: onResize,
                    onRotate: onRotate,
                    rotation: element.rotation,
                    isAspectRatioLocked: element.isAspectRatioLocked && element.type != .text
                )
            }
            
            // Draw temporary element outlines for dragging
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
                    } else if element.type == .path {
                        PathView(points: element.path, color: .blue, opacity: 0.5, isOutlineOnly: true)
                            .frame(width: element.size.width, height: element.size.height)
                    }
                }
            }
        }
        .position(element.position)
        // Explicitly set the anchor point to the center of the element
        // The element's position is its center, and we're rotating around that center
        .rotationEffect(.degrees(element.rotation), anchor: anchorPoint)
        .shadow(color: isDragging ? Color.black.opacity(0.5) : Color.clear, radius: 8)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.interactiveSpring(), value: isDragging)
        // Make sure this view is above other elements in the ZStack
        .zIndex(isSelected ? 10 : 5)
        // Explicitly allow hit testing
        .allowsHitTesting(true)
    }
}

struct PathView: View {
    let points: [CGPoint]
    let color: Color
    let opacity: Double
    var isOutlineOnly: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            if !points.isEmpty {
                ZStack {
                    // For filled paths
                    if !isOutlineOnly && points.count > 2 {
                        FilledPathShape(points: points.map { scalePoint($0, in: geometry) })
                            .fill(color.opacity(opacity))
                    }
                    
                    // For outline paths or paths with few points
                    if isOutlineOnly || points.count <= 2 {
                        StrokedPathShape(points: points.map { scalePoint($0, in: geometry) }, shouldClose: points.count > 2)
                            .stroke(color.opacity(opacity), lineWidth: 2)
                    }
                }
            }
        }
    }
    
    // Scale points to fit within the geometry bounds
    private func scalePoint(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: point.x * geometry.size.width,
            y: point.y * geometry.size.height
        )
    }
}

// Shape for filled paths
struct FilledPathShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if let firstPoint = points.first {
            path.move(to: firstPoint)
            
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            
            path.closeSubpath()
        }
        
        return path
    }
}

// Shape for stroked paths
struct StrokedPathShape: Shape {
    let points: [CGPoint]
    let shouldClose: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if let firstPoint = points.first {
            path.move(to: firstPoint)
            
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            
            if shouldClose {
                path.closeSubpath()
            }
        }
        
        return path
    }
}

// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Component for selection overlay with handles
struct SelectionOverlay: View {
    let size: CGSize
    var onResize: ((CGSize) -> Void)?
    var onRotate: ((Double) -> Void)?
    let rotation: Double
    var isAspectRatioLocked: Bool = false
    
    // Handle positions
    private let handleSize: CGFloat = 8
    private let rotationHandleSize: CGFloat = 10
    private let outlineOffset: CGFloat = 4 // Offset for the selection border
    private let rotationHandleOffset: CGFloat = 24 // Distance from the top of the element
    
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
                
                // Rotation handle (top-center)
                ResizeHandle(position: .topCenter, size: rotationHandleSize)
                    .position(x: size.width / 2, y: -rotationHandleOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleRotate(value: value)
                            }
                    )
                
                // Line connecting center to rotation handle
                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: -outlineOffset))
                    path.addLine(to: CGPoint(x: size.width / 2, y: -rotationHandleOffset + rotationHandleSize/2))
                }
                .stroke(Color.blue, lineWidth: 1)
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
        default:
            return
        }
        
        // If aspect ratio is locked, maintain the ratio
        if isAspectRatioLocked {
            let originalRatio = size.width / size.height
            
            // Decide which dimension to prioritize based on the drag direction
            let useWidth = abs(deltaX) > abs(deltaY)
            
            if useWidth {
                newHeight = newWidth / originalRatio
            } else {
                newWidth = newHeight * originalRatio
            }
            
            // Ensure minimum size while maintaining aspect ratio
            if newWidth < 20 {
                newWidth = 20
                newHeight = newWidth / originalRatio
            }
            
            if newHeight < 20 {
                newHeight = 20
                newWidth = newHeight * originalRatio
            }
        } else {
            // When not maintaining aspect ratio, ensure minimum size
            newWidth = max(20, newWidth)
            newHeight = max(20, newHeight)
        }
        
        // Call the resize callback with the new size
        onResize?(CGSize(width: newWidth, height: newHeight))
    }
    
    private func handleRotate(value: DragGesture.Value) {
        // Only process if we have a rotation callback
        guard let onRotate = onRotate else { return }
        
        // Define the rotation anchor point at the center of the element
        // This is equivalent to the element's rotationAnchorPoint property
        let anchorPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Get the current drag position
        let dragPosition = value.location
        
        // Calculate the vector from anchor point to drag position
        let vectorToDragPoint = CGPoint(
            x: dragPosition.x - anchorPoint.x,
            y: dragPosition.y - anchorPoint.y
        )
        
        // Calculate the angle using the arctangent of the vector
        // atan2 returns angle in radians, convert to degrees
        let angleInRadians = atan2(vectorToDragPoint.y, vectorToDragPoint.x)
        let angleInDegrees = angleInRadians * (180 / .pi)
        
        // Adjust to get 0-360 degrees with 0 at the top (subtract 90 degrees)
        let rotationDegrees = (angleInDegrees + 90).truncatingRemainder(dividingBy: 360)
        let normalizedDegrees = rotationDegrees < 0 ? rotationDegrees + 360 : rotationDegrees
        
        // Call the rotation callback with rotation angle relative to the element's rotation anchor point
        onRotate(normalizedDegrees)
    }
}

// Resize handle component
struct ResizeHandle: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight, topCenter
    }
    
    let position: Position
    let size: CGFloat
    
    var body: some View {
        Group {
            if position == .topCenter {
                // Special handle for rotation
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            } else {
                // Regular resize handles
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
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        
        CanvasElementView(
            element: CanvasElement.rectangle(at: CGPoint(x: 150, y: 150), size: CGSize(width: 200, height: 150)),
            isSelected: true,
            onResize: { _ in },
            onRotate: { _ in }
        )
    }
    .frame(width: 400, height: 300)
} 
#endif
