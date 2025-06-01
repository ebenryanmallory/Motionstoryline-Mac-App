import SwiftUI
import Combine
import AppKit
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import UniformTypeIdentifiers
import Foundation

// MARK: - Canvas Video Renderer for Exports

class CanvasExportRenderer {
    private var elements: [CanvasElement] = []
    private var animationController: AnimationController
    
    struct Configuration {
        let width: Int
        let height: Int
        let duration: Double
        let frameRate: Float
        let canvasWidth: CGFloat
        let canvasHeight: CGFloat
    }
    
    init(animationController: AnimationController) {
        self.animationController = animationController
    }
    
    func setElements(_ elements: [CanvasElement]) {
        self.elements = elements
    }
    
    func renderToVideo(
        configuration: Configuration,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> AVAsset {
        // Create a temporary URL for the rendered video
        let tempDir = FileManager.default.temporaryDirectory
        let temporaryVideoURL = tempDir.appendingPathComponent("temp_canvas_\(UUID().uuidString).mov")
        
        // If a temporary file already exists, delete it
        if FileManager.default.fileExists(atPath: temporaryVideoURL.path) {
            try FileManager.default.removeItem(at: temporaryVideoURL)
        }
        
        // Create an asset writer to generate a video
        guard let assetWriter = try? AVAssetWriter(outputURL: temporaryVideoURL, fileType: .mov) else {
            throw NSError(domain: "MotionStoryline", code: 103, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset writer"])
        }
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: configuration.width,
            AVVideoHeightKey: configuration.height
        ]
        
        // Create a writer input
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        // Create a pixel buffer adaptor
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: configuration.width,
            kCVPixelBufferHeightKey as String: configuration.height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: attributes
        )
        
        // Add the input to the writer
        if assetWriter.canAdd(writerInput) {
            assetWriter.add(writerInput)
        } else {
            throw NSError(domain: "MotionStoryline", code: 104, userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input to asset writer"])
        }
        
        // Start writing
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        
        // Bitmap info for context creation
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        // Scale factor for positioning elements
        let scaleFactor = min(
            CGFloat(configuration.width) / configuration.canvasWidth,
            CGFloat(configuration.height) / configuration.canvasHeight
        )
        
        // Center offset to position elements in the center of the frame
        let xOffset = (CGFloat(configuration.width) - configuration.canvasWidth * scaleFactor) / 2
        let yOffset = (CGFloat(configuration.height) - configuration.canvasHeight * scaleFactor) / 2
        
        // Write frames
        let frameCount = Int(configuration.duration * Double(configuration.frameRate))
        var frameTime = CMTime.zero
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
        
        // Store the current animation state to restore later
        let currentAnimationTime = animationController.currentTime
        let isCurrentlyPlaying = animationController.isPlaying
        
        // Pause the animation during export (if playing)
        if isCurrentlyPlaying {
            animationController.pause()
        }
        
        // Create a queue for writing
        let mediaQueue = DispatchQueue(label: "mediaQueue")
        
        let semaphore = DispatchSemaphore(value: 0)
        writerInput.requestMediaDataWhenReady(on: mediaQueue) {
            // Track the last reported progress to avoid duplicate updates
            var lastReportedProgress: Float = 0
            var lastReportTime: CFTimeInterval = CACurrentMediaTime()
            
            // Helper function to properly convert SwiftUI Color to CGColor
            func convertToCGColor(_ color: Color) -> CGColor {
                // Convert through NSColor to ensure consistent color space
                let nsColor = NSColor(color)
                // Use sRGB color space for consistent rendering across canvas and export
                let colorInRGB = nsColor.usingColorSpace(.sRGB) ?? nsColor
                return colorInRGB.cgColor
            }
            
            // Render each frame with the animation state at that time
            for frameIdx in 0..<frameCount {
                if writerInput.isReadyForMoreMediaData {
                    // Calculate time for this frame
                    let frameTimeInSeconds = Double(frameIdx) / Double(configuration.frameRate)
                    
                    // Update animation controller to this time and update canvas elements
                    DispatchQueue.main.sync {
                        // Set animation time (this updates all animated properties)
                        self.animationController.currentTime = frameTimeInSeconds
                    }
                    
                    // Create a context for this frame
                    guard let context = CGContext(
                        data: nil,
                        width: configuration.width,
                        height: configuration.height,
                        bitsPerComponent: 8,
                        bytesPerRow: configuration.width * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: bitmapInfo.rawValue
                    ) else {
                        continue
                    }
                    
                    // Draw white background
                    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: configuration.width, height: configuration.height))
                    
                    // Draw each element
                    for element in self.elements {
                        let scaledSize = CGSize(
                            width: element.size.width * scaleFactor,
                            height: element.size.height * scaleFactor
                        )
                        
                        let scaledPosition = CGPoint(
                            x: element.position.x * scaleFactor + xOffset,
                            y: element.position.y * scaleFactor + yOffset
                        )
                        
                        // Position the element (convert from center to top-left origin)
                        let rect = CGRect(
                            x: scaledPosition.x - scaledSize.width / 2,
                            y: scaledPosition.y - scaledSize.height / 2,
                            width: scaledSize.width,
                            height: scaledSize.height
                        )
                        
                        // Save the context state before transformations
                        context.saveGState()
                        
                        // Apply rotation (around the center of the element)
                        context.translateBy(x: scaledPosition.x, y: scaledPosition.y)
                        context.rotate(by: element.rotation * .pi / 180)
                        context.translateBy(x: -scaledPosition.x, y: -scaledPosition.y)
                        
                        // Apply opacity
                        context.setAlpha(CGFloat(element.opacity))
                        
                        // Draw based on element type
                        switch element.type {
                        case .rectangle:
                            // Save graphics state
                            context.saveGState()
                            
                            // Apply opacity to the fill color
                            let fillColor = convertToCGColor(element.color)
                            context.setFillColor(fillColor)
                            context.setAlpha(element.opacity)
                            
                            // Draw the rectangle
                            context.fill(rect)
                            
                            // Restore graphics state
                            context.restoreGState()
                        case .ellipse:
                            // Save graphics state
                            context.saveGState()
                            
                            // Apply opacity to the fill color
                            let fillColor = convertToCGColor(element.color)
                            context.setFillColor(fillColor)
                            context.setAlpha(element.opacity)
                            
                            // Draw the ellipse
                            context.fillEllipse(in: rect)
                            
                            // Restore graphics state
                            context.restoreGState()
                        case .path:
                            // Save graphics state
                            context.saveGState()
                            
                            // Set stroke color and width
                            let pathColor = convertToCGColor(element.color)
                            context.setStrokeColor(pathColor)
                            context.setAlpha(element.opacity)
                            context.setLineWidth(2.0)
                            
                            // Draw the path if points are available
                            if element.path.count > 1 {
                                context.beginPath()
                                
                                // Scale points to the element rect
                                let scaledPoints = element.path.map { point in
                                    CGPoint(
                                        x: rect.origin.x + point.x * rect.width,
                                        y: rect.origin.y + point.y * rect.height
                                    )
                                }
                                
                                // Start at the first point
                                context.move(to: scaledPoints[0])
                                
                                // Add lines to remaining points
                                for point in scaledPoints.dropFirst() {
                                    context.addLine(to: point)
                                }
                                
                                // Stroke the path
                                context.strokePath()
                            }
                            
                            // Restore graphics state
                            context.restoreGState()
                        case .text:
                            // Implement proper text rendering using Core Text
                            let attributedString = NSAttributedString(
                                string: element.text,
                                attributes: [
                                    // Use a size relative to the element's height for better proportional scaling
                                    .font: NSFont.systemFont(ofSize: min(rect.height * 0.7, 36)),
                                    // Ensure consistent color conversion
                                    .foregroundColor: {
                                        // First create NSColor from SwiftUI Color
                                        let nsColor = NSColor(element.color)
                                        // Then try to use a consistent color space
                                        return nsColor.usingColorSpace(.sRGB) ?? nsColor
                                    }(),
                                    .paragraphStyle: {
                                        let style = NSMutableParagraphStyle()
                                        switch element.textAlignment {
                                        case .leading:
                                            style.alignment = .left
                                        case .center:
                                            style.alignment = .center
                                        case .trailing:
                                            style.alignment = .right
                                        }
                                        return style
                                    }()
                                ]
                            )
                            
                            // Save the graphics state before drawing text
                            context.saveGState()
                            
                            // Apply element opacity to the entire text
                            context.setAlpha(element.opacity)
                            
                            // Create the text frame to draw in
                            let textPath = CGPath(rect: rect, transform: nil)
                            let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
                            let textFrame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attributedString.length), textPath, nil)
                            
                            // Draw the text
                            CTFrameDraw(textFrame, context)
                            
                            // Restore the graphics state after drawing
                            context.restoreGState()
                        case .image, .video:
                            // Draw a placeholder for images/videos
                            context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                            context.fill(rect)
                        }
                        
                        // Restore the context state
                        context.restoreGState()
                    }
                    
                    // Create an image from the context
                    guard let image = context.makeImage() else {
                        continue
                    }
                    
                    // Create a pixel buffer
                    var pixelBuffer: CVPixelBuffer?
                    let status = CVPixelBufferCreate(
                        kCFAllocatorDefault,
                        configuration.width,
                        configuration.height,
                        kCVPixelFormatType_32ARGB,
                        attributes as CFDictionary,
                        &pixelBuffer
                    )
                    
                    if status == kCVReturnSuccess, let pixelBuffer = pixelBuffer {
                        CVPixelBufferLockBaseAddress(pixelBuffer, [])
                        
                        if let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer) {
                            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                            
                            // Create a context with the pixel buffer
                            let context = CGContext(
                                data: pixelData,
                                width: configuration.width,
                                height: configuration.height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: bitmapInfo.rawValue
                            )
                            
                            // Draw the image to the context
                            if let context = context {
                                context.draw(image, in: CGRect(x: 0, y: 0, width: configuration.width, height: configuration.height))
                            }
                        }
                        
                        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                        
                        // Append the frame to the video
                        if adaptor.append(pixelBuffer, withPresentationTime: frameTime) {
                            // If successful, increment time for next frame
                            frameTime = CMTimeAdd(frameTime, frameDuration)
                            
                            // Calculate progress based on frames processed
                            let currentProgress = Float(frameIdx + 1) / Float(frameCount)
                            let currentTime = CACurrentMediaTime()
                            
                            // Send progress updates
                            if currentProgress - lastReportedProgress > 0.01 || 
                               currentTime - lastReportTime > 0.5 {
                                
                                // Ensure we're not sending progress updates too frequently
                                if currentTime - lastReportTime > 0.1 {
                                    DispatchQueue.main.async {
                                        progressHandler(currentProgress)
                                        NotificationCenter.default.post(
                                            name: Notification.Name("ExportProgressUpdate"),
                                            object: nil,
                                            userInfo: ["progress": currentProgress]
                                        )
                                    }
                                    lastReportedProgress = currentProgress
                                    lastReportTime = currentTime
                                }
                            }
                        } else {
                            // If appending fails, report the error and signal completion
                            print("Debug: Failed to append pixel buffer - \(assetWriter.error?.localizedDescription ?? "unknown error")")
                            
                            // Restore original animation state
                            DispatchQueue.main.async {
                                self.animationController.currentTime = currentAnimationTime
                                if isCurrentlyPlaying {
                                    self.animationController.play()
                                }
                            }
                            
                            semaphore.signal()
                            return
                        }
                    }
                }
            }
            
            // Send final progress update
            DispatchQueue.main.async {
                progressHandler(0.95)
                NotificationCenter.default.post(
                    name: Notification.Name("ExportProgressUpdate"),
                    object: nil,
                    userInfo: ["progress": Float(0.95)]
                )
            }
            
            // Restore original animation state
            DispatchQueue.main.async {
                self.animationController.currentTime = currentAnimationTime
                if isCurrentlyPlaying {
                    self.animationController.play()
                }
            }
            
            // Finish writing
            writerInput.markAsFinished()
            
            // Signal completion
            semaphore.signal()
        }
        
        // Wait for media writing to complete in a non-blocking way
        let group = DispatchGroup()
        group.enter()
        
        mediaQueue.async {
            _ = semaphore.wait(timeout: .distantFuture)
            group.leave()
        }
        
        // Convert DispatchGroup to async/await
        _ = await withCheckedContinuation { continuation in
            group.notify(queue: .main) {
                // Provide haptic feedback when export is completed
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                continuation.resume(returning: true)
            }
        }
        
        // Check for any errors after processing is complete
        if let error = assetWriter.error {
            throw NSError(domain: "MotionStoryline", code: 105, userInfo: [NSLocalizedDescriptionKey: "Failed to create video: \(error.localizedDescription)"])
        }
        
        // Return the final asset
        return AVAsset(url: temporaryVideoURL)
    }
    
    /// Create a black pixel buffer for use in video compositions
    func createBlackFramePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )
        
        if status != kCVReturnSuccess {
            print("Debug: Failed to create pixel buffer")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer!) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)
            let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
            
            // Fill with black
            context?.setFillColor(CGColor(gray: 0, alpha: 1.0))
            context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

// MARK: - Video Exporter

class CanvasVideoExporter {
    // ProRes profiles for high-quality exports
    enum ProResProfile {
        case proRes422Proxy
        case proRes422LT
        case proRes422
        case proRes422HQ
        case proRes4444
        case proRes4444XQ
        
        var avCodecKey: String {
            switch self {
            case .proRes422Proxy: return AVVideoCodecType.proRes422Proxy.rawValue
            case .proRes422LT: return AVVideoCodecType.proRes422LT.rawValue
            case .proRes422: return AVVideoCodecType.proRes422.rawValue
            case .proRes422HQ: return AVVideoCodecType.proRes422HQ.rawValue
            case .proRes4444: return AVVideoCodecType.proRes4444.rawValue
            case .proRes4444XQ: return AVVideoCodecType.proRes4444.rawValue // Using ProRes4444 as fallback
            }
        }
    }
    
    enum ExportError: Error {
        case exportFailed(Error)
        case invalidAsset
        case exportCancelled
        case fileCreationFailed
    }
    
    struct ExportConfiguration {
        enum ExportFormat {
            case video
            case gif
            case imageSequence
            
            var fileExtension: String {
                switch self {
                case .video: return "mp4"
                case .gif: return "gif"
                case .imageSequence: return "png"
                }
            }
        }
        
        let format: ExportFormat
        let width: Int
        let height: Int
        let frameRate: Float
        let proResProfile: ProResProfile?
        let outputURL: URL
    }
    
    private let asset: AVAsset
    private var exportSession: AVAssetExportSession?
    
    init(asset: AVAsset) {
        self.asset = asset
    }
    
    func export(
        with configuration: ExportConfiguration,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
        // Choose appropriate export method based on format
        switch configuration.format {
        case .video:
            await exportVideo(with: configuration, progressHandler: progressHandler, completion: completion)
        case .gif:
            await exportGIF(with: configuration, progressHandler: progressHandler, completion: completion)
        case .imageSequence:
            await exportImageSequence(with: configuration, progressHandler: progressHandler, completion: completion)
        }
    }
    
    private func exportVideo(
        with configuration: ExportConfiguration,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
        // Check if we have a valid asset
        guard asset.tracks.count > 0 else {
            completion(.failure(ExportError.invalidAsset))
            return
        }
        
        // Create an export session for the asset
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(ExportError.invalidAsset))
            return
        }
        
        self.exportSession = exportSession
        
        // Configure the export session
        exportSession.outputURL = configuration.outputURL
        
        // Use different settings based on whether ProRes is requested
        if let proResProfile = configuration.proResProfile {
            // Use ProRes codec
            exportSession.outputFileType = .mov
            
            // The videoSettings property doesn't exist on AVAssetExportSession
            // Instead, use preset names or other configuration options if needed
        } else {
            // Use H.264 codec
            exportSession.outputFileType = .mp4
            
            // The videoSettings property doesn't exist on AVAssetExportSession
            // Use other configuration methods instead
        }
        
        // Create a timer to periodically check progress
        var progressObserver: NSObjectProtocol?
        
        // Setup a timer to update progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let progress = exportSession.progress
            progressHandler(progress)
        }
        
        // Start the export
        await exportSession.export()
        
        // Cleanup timer and observer
        timer.invalidate()
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Check export status
        switch exportSession.status {
        case .completed:
            completion(.success(configuration.outputURL))
        case .cancelled:
            completion(.failure(ExportError.exportCancelled))
        case .failed:
            if let error = exportSession.error {
                completion(.failure(ExportError.exportFailed(error)))
            } else {
                completion(.failure(ExportError.exportFailed(NSError(domain: "VideoExporter", code: 100, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]))))
            }
        default:
            completion(.failure(ExportError.exportFailed(NSError(domain: "VideoExporter", code: 101, userInfo: [NSLocalizedDescriptionKey: "Export ended with status: \(exportSession.status.rawValue)"]))))
        }
    }
    
    private func exportGIF(
        with configuration: ExportConfiguration,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
        // Implement GIF export logic
        // This is a placeholder for the GIF export method
        // In a real implementation, you would extract frames from the video
        // and create an animated GIF file
        
        completion(.failure(NSError(domain: "VideoExporter", code: 102, userInfo: [NSLocalizedDescriptionKey: "GIF export not implemented yet"])))
    }
    
    private func exportImageSequence(
        with configuration: ExportConfiguration,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
        // Implement image sequence export logic
        // This is a placeholder for the image sequence export method
        // In a real implementation, you would extract frames from the video
        // and save them as separate image files
        
        completion(.failure(NSError(domain: "VideoExporter", code: 103, userInfo: [NSLocalizedDescriptionKey: "Image sequence export not implemented yet"])))
    }
    
    func cancel() {
        exportSession?.cancelExport()
    }
} 