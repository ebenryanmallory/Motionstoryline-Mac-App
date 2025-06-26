import Foundation
import CoreGraphics
import AppKit
import SwiftUI
import AVFoundation

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
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
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
                
                // Use the element's fontSize property, scaled appropriately
                let fontSize = element.fontSize * scaleFactor
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .foregroundColor: NSColor(cgColor: textColor) ?? NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
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
                if let assetURL = element.assetURL, assetURL.isFileURL {
                    // For video elements, we need to extract a frame at the current time
                    let asset = AVAsset(url: assetURL)
                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    imageGenerator.requestedTimeToleranceBefore = .zero
                    imageGenerator.requestedTimeToleranceAfter = .zero
                    
                    // Calculate video time based on element's video start time
                    // Note: For export, we would need access to the current export time
                    // This is a simplified version - in practice, you'd pass the current export time
                    let videoTime = max(0, element.videoStartTime)
                    let cmTime = CMTime(seconds: videoTime, preferredTimescale: 600)
                    
                    do {
                        let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
                        
                        // Draw the video frame similar to how images are handled
                        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = nsContext
                        
                        context.saveGState()
                        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.size.height)
                        context.scaleBy(x: 1, y: -1)
                        
                        let localImageDrawRect = CGRect(origin: .zero, size: rect.size)
                        context.draw(cgImage, in: localImageDrawRect)
                        
                        NSGraphicsContext.restoreGraphicsState()
                        context.restoreGState()
                        
                        print("[CanvasRenderer] Drew video frame from: \(assetURL.path) at time: \(videoTime)")
                    } catch {
                        print("[CanvasRenderer] Failed to extract video frame: \(error)")
                        // Draw placeholder if frame extraction fails
                        context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                        context.fill(rect)
                    }
                } else {
                    print("[CanvasRenderer] Video element has no valid file assetURL: \(String(describing: element.assetURL))")
                    // Draw placeholder
                    context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                    context.fill(rect)
                }
                break
            }
            context.restoreGState()
        }
        return context.makeImage()
    }

    private static func convertToCGColor(_ color: NSColor) -> CGColor {
        return color.usingColorSpace(.sRGB)?.cgColor ?? NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor
    }
    
    /// Properly converts a SwiftUI Color to CGColor
    private static func convertSwiftUIColorToCGColor(_ color: Color) -> CGColor {
        // Get the NSColor from SwiftUI Color
        let nsColor: NSColor
        
        // Handle named colors
        if color == Color(red: 1.0, green: 0.231, blue: 0.188, opacity: 1.0) {
            nsColor = NSColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
        } else if color == Color(red: 0.204, green: 0.780, blue: 0.349, opacity: 1.0) {
            nsColor = NSColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
        } else if color == Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0) {
            nsColor = NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        } else if color == Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0) {
            nsColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        } else if color == Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0) {
            nsColor = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        } else if color == Color(red: 1.0, green: 0.800, blue: 0.0, opacity: 1.0) {
            nsColor = NSColor(red: 1.0, green: 0.800, blue: 0.0, alpha: 1.0)
        } else if color == Color(red: 1.0, green: 0.584, blue: 0.0, opacity: 1.0) {
            nsColor = NSColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)
        } else if color == Color(red: 0.690, green: 0.322, blue: 0.871, opacity: 1.0) {
            nsColor = NSColor(red: 0.690, green: 0.322, blue: 0.871, alpha: 1.0)
        } else {
            // Convert using NSColor for consistent color space handling
            nsColor = NSColor(color)
        }
        
        // Convert to CGColor ensuring we're in the sRGB color space for consistency
        return nsColor.usingColorSpace(.sRGB)?.cgColor ?? NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor
    }
}
