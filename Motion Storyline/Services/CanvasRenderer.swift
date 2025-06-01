import Foundation
import CoreGraphics
import AppKit
import SwiftUI

// Service for rendering canvas elements to a CGImage
class CanvasRenderer {
    /// Renders the given canvas elements to a CGImage at the specified size and scale factor.
    /// - Parameters:
    ///   - elements: The array of CanvasElement to render.
    ///   - size: The desired output image size (in points).
    ///   - scaleFactor: The scale factor (for retina, etc).
    ///   - backgroundColor: The background color (default: white).
    /// - Returns: A CGImage containing the rendered canvas, or nil if rendering fails.
    static func renderCanvasImage(
        elements: [CanvasElement],
        size: CGSize,
        scaleFactor: CGFloat = 1.0,
        backgroundColor: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    ) -> CGImage? {
        let width = Int(size.width * scaleFactor)
        let height = Int(size.height * scaleFactor)
        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        // Fill background
        context.setFillColor(backgroundColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Transform context to use top-left origin
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        
        let xOffset = (CGFloat(width) - size.width * scaleFactor) / 2
        let yOffset = (CGFloat(height) - size.height * scaleFactor) / 2
        
        print("[CanvasRenderer] Rendering \(elements.count) elements to \(width)x\(height) canvas")
        for (idx, element) in elements.enumerated() {
            // Log only essential element information, focusing on color
            print("[CanvasRenderer] Element #\(idx): type=\(element.type), color=\(element.color)")
            
            let scaledSize = CGSize(
                width: element.size.width * scaleFactor,
                height: element.size.height * scaleFactor
            )
            let scaledPosition = CGPoint(
                x: element.position.x * scaleFactor + xOffset,
                y: element.position.y * scaleFactor + yOffset
            )
            let rect = CGRect(
                x: scaledPosition.x - scaledSize.width / 2,
                y: scaledPosition.y - scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            context.saveGState()
            // Rotation
            context.translateBy(x: scaledPosition.x, y: scaledPosition.y)
            context.rotate(by: element.rotation * .pi / 180)
            context.translateBy(x: -scaledPosition.x, y: -scaledPosition.y)
            // Opacity
            context.setAlpha(CGFloat(element.opacity))
            switch element.type {
            case .rectangle:
                context.saveGState()
                let fillColor = convertSwiftUIColorToCGColor(element.color)
                context.setFillColor(fillColor)
                context.setAlpha(element.opacity)
                context.fill(rect)
                context.restoreGState()
            case .ellipse:
                context.saveGState()
                let fillColor = convertSwiftUIColorToCGColor(element.color)
                context.setFillColor(fillColor)
                context.setAlpha(element.opacity)
                context.fillEllipse(in: rect)
                context.restoreGState()
            case .path:
                context.saveGState()
                let pathColor = convertSwiftUIColorToCGColor(element.color)
                context.setStrokeColor(pathColor)
                context.setAlpha(element.opacity)
                context.setLineWidth(2.0)
                if !element.path.isEmpty && element.path.count > 1 {
                    context.beginPath()
                    let scaledPoints = element.path.map { point in
                        CGPoint(
                            x: rect.origin.x + point.x * rect.width,
                            y: rect.origin.y + point.y * rect.height
                        )
                    }
                    context.move(to: scaledPoints[0])
                    for pt in scaledPoints.dropFirst() {
                        context.addLine(to: pt)
                    }
                    context.strokePath()
                }
                context.restoreGState()
            case .text:
                context.saveGState()
                
                // Log text element details for debugging
                print("[CanvasRenderer] Text element content: '\(element.text)'")
                print("[CanvasRenderer] Text element rect: \(rect)")
                
                let textColor = convertSwiftUIColorToCGColor(element.color)
                
                // Create paragraph style based on text alignment
                let paragraphStyle = NSMutableParagraphStyle()
                switch element.textAlignment {
                case .leading:
                    paragraphStyle.alignment = .left
                case .center:
                    paragraphStyle.alignment = .center
                case .trailing:
                    paragraphStyle.alignment = .right
                }
                
                // Scale font size based on element height and apply consistent sizing
                let fontSize = min(24 * scaleFactor, rect.height * 0.8)
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .foregroundColor: NSColor(cgColor: textColor) ?? NSColor.black,
                    .paragraphStyle: paragraphStyle
                ]
                
                // Create attributed string with the text content
                let attributedString = NSAttributedString(string: element.text, attributes: attributes)
                
                // Calculate text size to properly center text
                let textSize = attributedString.size()
                
                // Calculate center-aligned text rect
                let textRect: CGRect
                switch element.textAlignment {
                case .center:
                    // Center horizontally
                    textRect = CGRect(
                        x: rect.midX - textSize.width / 2,
                        y: rect.midY - textSize.height / 2,
                        width: textSize.width,
                        height: textSize.height
                    )
                case .leading:
                    // Align to left
                    textRect = CGRect(
                        x: rect.minX,
                        y: rect.midY - textSize.height / 2,
                        width: rect.width,
                        height: textSize.height
                    )
                case .trailing:
                    // Align to right
                    textRect = CGRect(
                        x: rect.maxX - textSize.width,
                        y: rect.midY - textSize.height / 2,
                        width: textSize.width,
                        height: textSize.height
                    )
                }
                
                // Set up NSGraphicsContext to bridge AppKit and CoreGraphics
                // The main CGContext is already Y-flipped. For NSAttributedString drawing,
                // we need to counteract this flip locally.
                context.saveGState() // Save the globally Y-flipped state

                // Translate to the desired bottom-left of the text in the Y-flipped system.
                // textRect.origin.y is top in the flipped system.
                // So, textRect.origin.y + textRect.height is bottom in the flipped system.
                context.translateBy(x: textRect.origin.x, y: textRect.origin.y + textRect.height)
                context.scaleBy(x: 1, y: -1) // Un-flip Y axis locally for text

                // Now that the context is locally upright, draw text at (0,0) of this local system.
                // We need an NSGraphicsContext for NSAttributedString.
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false) // Context is now locally upright
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = nsContext
                
                attributedString.draw(with: CGRect(origin: .zero, size: attributedString.size()), options: [.usesLineFragmentOrigin])
                
                NSGraphicsContext.restoreGraphicsState()
                context.restoreGState() // Restore to globally Y-flipped state

                // Debug: output the final text rendering position (original textRect)
                print("[CanvasRenderer] Text intended at (top-left of bounding box): \(textRect)")
            case .image:
                if let assetURL = element.assetURL, assetURL.isFileURL {
                    // Ensure the URL is a file URL before trying to create NSImage from path
                    if let image = NSImage(contentsOfFile: assetURL.path) {
                        // The context is already set up with opacity and rotation
                        // We need to draw the NSImage into the element's rect
                        // NSGraphicsContext is used here to draw NSImage into CGContext
                        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = nsContext
                        
                        // Prepare the destination rect for drawing the image
                        // The element's 'rect' is already calculated considering its position and size on canvas
                        // The context's CTM already handles the element's rotation and position

                        // Locally flip the context for NSImage drawing to make it upright
                        context.saveGState() // Save current CTM (globally flipped, rotated for element)

                        // Translate to the top-left of the image's rect in the current (flipped) system.
                        // Then, account for local flip: move to bottom-left of where image should draw.
                        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.size.height)
                        context.scaleBy(x: 1, y: -1) // Locally un-flip the Y axis

                        // Now that the context is locally upright, draw image at (0,0) of this local system.
                        let localImageDrawRect = CGRect(origin: .zero, size: rect.size)

                        // NSGraphicsContext is needed for NSImage.draw
                        // The 'context' here is now locally upright.
                        let nsContextForImage = NSGraphicsContext(cgContext: context, flipped: false)
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = nsContextForImage
                        
                        image.draw(in: localImageDrawRect)
                        
                        NSGraphicsContext.restoreGraphicsState() // Restore NSGraphicsContext state
                        context.restoreGState() // Restore CGContext to globally flipped, rotated CTM

                        print("[CanvasRenderer] Drew image from: \(assetURL.path) intended for canvas rect: \(rect)")
                    } else {
                        print("[CanvasRenderer] Failed to load image from: \(assetURL.path)")
                        // Optionally draw a placeholder if image loading fails
                    }
                } else {
                    print("[CanvasRenderer] Image element has no valid file assetURL: \(String(describing: element.assetURL))")
                }
                break
            case .video:
                // TODO: Implement static frame rendering for video elements
                // This would involve using AVAssetImageGenerator to get a CGImage for the current time
                // and then drawing that CGImage similar to how .image elements are handled.
                print("[CanvasRenderer] Video element rendering not yet implemented for export.")
                break
            }
            context.restoreGState()
        }
        return context.makeImage()
    }

    private static func convertToCGColor(_ color: NSColor) -> CGColor {
        return color.usingColorSpace(.deviceRGB)?.cgColor ?? NSColor.black.cgColor
    }
    
    /// Properly converts a SwiftUI Color to CGColor
    private static func convertSwiftUIColorToCGColor(_ color: Color) -> CGColor {
        // Get the NSColor from SwiftUI Color
        let nsColor: NSColor
        
        // Handle named colors
        if color == .red {
            nsColor = NSColor.red
        } else if color == .green {
            nsColor = NSColor.green
        } else if color == .blue {
            nsColor = NSColor.blue
        } else if color == .black {
            nsColor = NSColor.black
        } else if color == .white {
            nsColor = NSColor.white
        } else if color == .yellow {
            nsColor = NSColor.yellow
        } else if color == .orange {
            nsColor = NSColor.orange
        } else if color == .purple {
            nsColor = NSColor.purple
        } else {
            // Convert using NSColor's color provider - more reliable than the previous method
            let provider = color.resolve(in: EnvironmentValues())
            nsColor = NSColor(colorSpace: .deviceRGB, 
                             components: [
                                provider.cgColor.components?[0] ?? 0,
                                provider.cgColor.components?[1] ?? 0,
                                provider.cgColor.components?[2] ?? 0,
                                provider.cgColor.components?[3] ?? 1
                             ],
                             count: 4)
        }
        
        // Convert to CGColor ensuring we're in the RGB color space
        return nsColor.usingColorSpace(.deviceRGB)?.cgColor ?? NSColor.black.cgColor
    }
}
