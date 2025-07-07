import SwiftUI

struct GridBackground: View {
    var showGrid: Bool = true
    var gridSize: CGFloat = 20
    var gridColor: Color = Color(white: 0.5, opacity: 0.2)
    var canvasBackgroundColor: Color = Color(NSColor.windowBackgroundColor)
    var isPreviewMode: Bool = false
    let majorGridEvery: Int = 5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - white in preview mode, custom background otherwise
                if isPreviewMode {
                    Color.white
                } else {
                    canvasBackgroundColor
                }
                
                if showGrid && !isPreviewMode {
                    // Minor grid lines
                    Path { path in
                        // Vertical lines
                        for i in 0...Int(geometry.size.width / gridSize) {
                            let x = CGFloat(i) * gridSize
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        }
                        
                        // Horizontal lines
                        for i in 0...Int(geometry.size.height / gridSize) {
                            let y = CGFloat(i) * gridSize
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(gridColor, lineWidth: 0.5)
                    
                    // Major grid lines
                    Path { path in
                        // Vertical lines
                        for i in 0...Int(geometry.size.width / gridSize) {
                            if i % majorGridEvery == 0 {
                                let x = CGFloat(i) * gridSize
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                            }
                        }
                        
                        // Horizontal lines
                        for i in 0...Int(geometry.size.height / gridSize) {
                            if i % majorGridEvery == 0 {
                                let y = CGFloat(i) * gridSize
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                            }
                        }
                    }
                    .stroke(gridColor.opacity(0.4), lineWidth: 1.0)
                }
                
                // Center crosshair - only show when not in preview mode
                if !isPreviewMode {
                    Path { path in
                        let centerX = geometry.size.width / 2
                        let centerY = geometry.size.height / 2
                        
                        // Horizontal line
                        path.move(to: CGPoint(x: 0, y: centerY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                        
                        // Vertical line
                        path.move(to: CGPoint(x: centerX, y: 0))
                        path.addLine(to: CGPoint(x: centerX, y: geometry.size.height))
                    }
                    .stroke(Color(red: 0.4, green: 0.4, blue: 0.4, opacity: 0.3), lineWidth: 1.0)
                }
            }
        }
    }
} 