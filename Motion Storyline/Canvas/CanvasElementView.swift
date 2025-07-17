import SwiftUI
import AVFoundation

struct CanvasElementView: View {
    let element: CanvasElement
    let isSelected: Bool
    var onResize: ((CGSize) -> Void)?
    var onRotate: ((Double) -> Void)?
    var onTap: ((CanvasElement) -> Void)?
    var isTemporary: Bool = false
    var isDragging: Bool = false
    var currentTime: TimeInterval = 0.0 // Current timeline position for video synchronization
    
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
                .fill(Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.0))
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
                        .font(.system(size: element.fontSize))
                        .foregroundColor(element.color)
                        .frame(width: element.size.width, height: element.size.height, alignment: textFrameAlignment(for: element.textAlignment))
                        .multilineTextAlignment(element.textAlignment)
                        .opacity(element.opacity)
                        .contentShape(Rectangle())

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
                                    .foregroundColor(Color(white: 0.5, opacity: 1.0))
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
                            .foregroundColor(Color(white: 0.5, opacity: 1.0))
                            .opacity(element.opacity)
                            .contentShape(Rectangle())
                    }
                case .video:
                    if let videoURL = element.assetURL {
                        // Calculate the video time based on timeline position and video start offset
                        let videoTime = max(0, currentTime - element.videoStartTime)
                        
                        VideoFrameView(
                            videoURL: videoURL,
                            currentTime: videoTime,
                            size: element.size,
                            opacity: element.opacity
                        )
                    } else {
                        // Fallback placeholder if no video URL
                        ZStack {
                            Rectangle()
                                .fill(Color(white: 0.5, opacity: 1.0).opacity(0.3))
                            Image(systemName: "film")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: min(element.size.width, element.size.height) * 0.5)
                                .foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0).opacity(0.7))
                        }
                        .frame(width: element.size.width, height: element.size.height)
                        .opacity(element.opacity)
                        .clipped()
                        .contentShape(Rectangle())
                    }
                // Removed default case as all ElementType cases (rectangle, ellipse, text, image, video) are handled
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
                            .stroke(Color(red: 0.4, green: 0.4, blue: 0.4, opacity: 0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .frame(width: element.size.width, height: element.size.height)
                    } else if element.type == .ellipse {
                        Ellipse()
                            .stroke(Color(red: 0.4, green: 0.4, blue: 0.4, opacity: 0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .frame(width: element.size.width, height: element.size.height)
                    }
                }
            }
        }
        .position(element.position)
        // Explicitly set the anchor point to the center of the element
        // The element's position is its center, and we're rotating around that center
        .rotationEffect(.degrees(element.rotation), anchor: anchorPoint)
        .shadow(color: isDragging ? Color.black.opacity(0.15) : Color.clear, radius: 3, x: 0, y: 2)
        .animation(.interactiveSpring(), value: isDragging)
        // Make sure this view is above other elements in the ZStack
        .zIndex(isSelected ? 10 : 5)
        // Explicitly allow hit testing
        .allowsHitTesting(true)
        // Add tap gesture to handle selection
        .onTapGesture {
            if let onTap = onTap {
                onTap(element)
            }
        }
    }
    
    // Helper function to convert TextAlignment to Alignment for frame positioning
    private func textFrameAlignment(for textAlignment: TextAlignment) -> Alignment {
        switch textAlignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
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
    
    @State private var hoveredHandles: Set<ResizeHandle.Position> = []
    @State private var initialSize: CGSize = .zero
    @State private var isAnyHandleHovered: Bool = false
    
    // Handle positions
    private let handleSize: CGFloat = 6
    private let outlineOffset: CGFloat = 4 // Offset for the selection border
    
    var body: some View {
        ZStack {
            // Selection border - use a Rectangle directly positioned at the center
            Rectangle()
                .stroke(Color(red: 0.4, green: 0.4, blue: 0.4, opacity: 0.6), lineWidth: 1)
                .frame(width: size.width + 2*outlineOffset, height: size.height + 2*outlineOffset)
            
            // Corner handles - only visible on hover
            Group {
                // Top-left
                ResizeHandle(
                    position: .topLeft, 
                    size: handleSize, 
                    onHover: { hovering in
                        if hovering {
                            hoveredHandles.insert(.topLeft)
                            if !isAnyHandleHovered {
                                isAnyHandleHovered = true
                            }
                        } else {
                            hoveredHandles.remove(.topLeft)
                            if hoveredHandles.isEmpty {
                                isAnyHandleHovered = false
                            }
                        }
                    }
                )
                .position(x: -outlineOffset - handleSize/2, y: -outlineOffset - handleSize/2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleResize(value: value, corner: .topLeft)
                        }
                        .onEnded { _ in
                            initialSize = .zero
                        }
                )
                
                // Top-right
                ResizeHandle(
                    position: .topRight, 
                    size: handleSize, 
                    onHover: { hovering in
                        if hovering {
                            hoveredHandles.insert(.topRight)
                            if !isAnyHandleHovered {
                                isAnyHandleHovered = true
                            }
                        } else {
                            hoveredHandles.remove(.topRight)
                            if hoveredHandles.isEmpty {
                                isAnyHandleHovered = false
                            }
                        }
                    }
                )
                .position(x: size.width + outlineOffset + handleSize/2, y: -outlineOffset - handleSize/2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleResize(value: value, corner: .topRight)
                        }
                        .onEnded { _ in
                            initialSize = .zero
                        }
                )
                
                // Bottom-left
                ResizeHandle(
                    position: .bottomLeft, 
                    size: handleSize, 
                    onHover: { hovering in
                        if hovering {
                            hoveredHandles.insert(.bottomLeft)
                            if !isAnyHandleHovered {
                                isAnyHandleHovered = true
                            }
                        } else {
                            hoveredHandles.remove(.bottomLeft)
                            if hoveredHandles.isEmpty {
                                isAnyHandleHovered = false
                            }
                        }
                    }
                )
                .position(x: -outlineOffset - handleSize/2, y: size.height + outlineOffset + handleSize/2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleResize(value: value, corner: .bottomLeft)
                        }
                        .onEnded { _ in
                            initialSize = .zero
                        }
                )
                
                // Bottom-right
                ResizeHandle(
                    position: .bottomRight, 
                    size: handleSize, 
                    onHover: { hovering in
                        if hovering {
                            hoveredHandles.insert(.bottomRight)
                            if !isAnyHandleHovered {
                                isAnyHandleHovered = true
                            }
                        } else {
                            hoveredHandles.remove(.bottomRight)
                            if hoveredHandles.isEmpty {
                                isAnyHandleHovered = false
                            }
                        }
                    }
                )
                .position(x: size.width + outlineOffset + handleSize/2, y: size.height + outlineOffset + handleSize/2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleResize(value: value, corner: .bottomRight)
                        }
                        .onEnded { _ in
                            initialSize = .zero
                        }
                )
            }
        }
        .frame(width: size.width, height: size.height) // Frame the whole overlay to match element size
    }
    
    private func handleResize(value: DragGesture.Value, corner: ResizeHandle.Position) {
        // Store initial size on first drag
        if initialSize == .zero {
            initialSize = size
        }
        
        // Calculate the change in size based on the drag translation
        let deltaX = value.translation.width
        let deltaY = value.translation.height
        
        // Calculate new size based on which corner is being dragged
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        switch corner {
        case .topLeft:
            // Dragging top-left: moving left increases width, moving up increases height
            newWidth = max(20, initialSize.width - deltaX)
            newHeight = max(20, initialSize.height - deltaY)
        case .topRight:
            // Dragging top-right: moving right increases width, moving up increases height
            newWidth = max(20, initialSize.width + deltaX)
            newHeight = max(20, initialSize.height - deltaY)
        case .bottomLeft:
            // Dragging bottom-left: moving left increases width, moving down increases height
            newWidth = max(20, initialSize.width - deltaX)
            newHeight = max(20, initialSize.height + deltaY)
        case .bottomRight:
            // Dragging bottom-right: moving right increases width, moving down increases height
            newWidth = max(20, initialSize.width + deltaX)
            newHeight = max(20, initialSize.height + deltaY)
        }
        
        // If aspect ratio is locked, maintain the ratio
        if isAspectRatioLocked {
            let originalRatio = initialSize.width / initialSize.height
            
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
    enum Position: Hashable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let position: Position
    let size: CGFloat
    let onHover: ((Bool) -> Void)?
    
    init(position: Position, size: CGFloat, onHover: ((Bool) -> Void)? = nil) {
        self.position = position
        self.size = size
        self.onHover = onHover
    }
    
    var body: some View {
        // Invisible hit area for resize cursor and drag detection
        Rectangle()
            .fill(Color.clear)
            .frame(width: size + 8, height: size + 8)
            .onHover { hovering in
                onHover?(hovering)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    NSCursor.crosshair.set()
                case .ended:
                    NSCursor.arrow.set()
                }
            }
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    ZStack {
        Color(white: 0.5, opacity: 1.0).opacity(0.2)
        
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
