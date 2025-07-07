import Foundation
import AVFoundation
import CoreGraphics
import AppKit

/// Shared utility for extracting video frames during rendering operations
struct VideoFrameExtractor {
    
    /// Extracts a video frame and draws it to the specified CGContext
    /// - Parameters:
    ///   - element: The canvas element containing video information
    ///   - currentTime: Current timeline position in seconds
    ///   - rect: The rectangle to draw the video frame in
    ///   - context: The CGContext to draw to
    static func extractAndDrawVideoFrame(
        element: CanvasElement,
        currentTime: TimeInterval,
        rect: CGRect,
        context: CGContext
    ) {
        guard let assetURL = element.assetURL, assetURL.isFileURL else {
            // Draw fallback placeholder for invalid video URL
            context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
            context.fill(rect)
            return
        }
        
        let asset = AVAsset(url: assetURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        // Calculate video time based on current timeline time and element's video start time
        let videoTime = max(0, currentTime - element.videoStartTime)
        let cmTime = CMTime(seconds: videoTime, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
            
            // Draw the video frame with proper coordinate system handling
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
        } catch {
            // Draw fallback placeholder if frame extraction fails
            context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
            context.fill(rect)
        }
    }
}