import SwiftUI
import AppKit

// Define a preference key for tracking mouse position
struct MousePositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// Define hover phase for continuous tracking
enum HoverPhase {
    case active(CGPoint)
    case ended
}

// NSViewRepresentable for tracking mouse movement
struct MousePositionView: NSViewRepresentable {
    var onMouseMoved: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackingView()
        view.onMouseMoved = onMouseMoved
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? MouseTrackingView {
            view.onMouseMoved = onMouseMoved
        }
    }
    
    class MouseTrackingView: NSView {
        var onMouseMoved: ((CGPoint) -> Void)?
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            // Enable mouse moved events
            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onMouseMoved?(CGPoint(x: point.x, y: point.y))
        }
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            
            // Remove existing tracking areas
            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }
            
            // Add new tracking area
            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
        }
    }
} 