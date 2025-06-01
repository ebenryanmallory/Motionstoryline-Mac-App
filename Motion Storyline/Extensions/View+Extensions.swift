import SwiftUI
import AppKit

// Extension to add preferences support to any view
extension View {
    func openPreferences() {
        // Use AppKit to show the app preferences window
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        
        // Post notification that preferences should be shown
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowPreferences"),
            object: nil
        )
    }
    
    // Extension to apply corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// Define which corners to round
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomRight = RectCorner(rawValue: 1 << 2)
    static let bottomLeft = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomRight, .bottomLeft]
    static let top: RectCorner = [.topLeft, .topRight]
    static let bottom: RectCorner = [.bottomLeft, .bottomRight]
    static let leading: RectCorner = [.topLeft, .bottomLeft]
    static let trailing: RectCorner = [.topRight, .bottomRight]
}

// Custom shape for rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        } else {
            path.move(to: topLeft)
        }
        
        // Top right corner
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: Angle(degrees: -90),
                        endAngle: Angle(degrees: 0),
                        clockwise: false)
        } else {
            path.addLine(to: topRight)
        }
        
        // Bottom right corner
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: Angle(degrees: 0),
                        endAngle: Angle(degrees: 90),
                        clockwise: false)
        } else {
            path.addLine(to: bottomRight)
        }
        
        // Bottom left corner
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: Angle(degrees: 90),
                        endAngle: Angle(degrees: 180),
                        clockwise: false)
        } else {
            path.addLine(to: bottomLeft)
        }
        
        // Top left corner
        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: Angle(degrees: 180),
                        endAngle: Angle(degrees: 270),
                        clockwise: false)
        } else {
            path.addLine(to: topLeft)
        }
        
        return path
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// Extension to create NSColor from SwiftUI Color
extension NSColor {
    convenience init(_ color: Color) {
        // Try to get the CGColor first
        if let cgColor = color.cgColor, let nsColor = NSColor(cgColor: cgColor) {
            // Use the components from the created NSColor
            self.init(red: nsColor.redComponent, 
                  green: nsColor.greenComponent, 
                  blue: nsColor.blueComponent, 
                  alpha: nsColor.alphaComponent)
            return
        }
        
        // Fallback to white if we can't create the color
        self.init(white: 1.0, alpha: 1.0)
    }
}

// Helper extension to get CGColor from SwiftUI Color
extension Color {
    // Helper method to extract CGColor safely
    var cgColorSafe: CGColor {
        return self.cgColor ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    }
}
#endif 