import Foundation
@preconcurrency import AVFoundation
import SwiftUI
import AppKit
import CoreGraphics
import Combine
import os.log

/// Service responsible for rendering canvas elements to a video file
class CanvasVideoRenderer: @unchecked Sendable {
    // Logger for debugging
    private static let logger = OSLog(subsystem: "com.app.Motion-Storyline", category: "CanvasVideoRenderer")
    
    // MARK: - Types
    
    /// Configuration for video rendering
    struct Configuration {
        /// Width of the output video in pixels
        let width: Int
        
        /// Height of the output video in pixels
        let height: Int
        
        /// Duration of the video in seconds
        let duration: Double
        
        /// Frame rate (frames per second)
        let frameRate: Float
        
        /// Original canvas width (for scaling)
        let canvasWidth: CGFloat
        
        /// Original canvas height (for scaling)
        let canvasHeight: CGFloat
        
        /// Background color (default: white)
        let backgroundColor: CGColor
        
        init(
            width: Int,
            height: Int,
            duration: Double,
            frameRate: Float,
            canvasWidth: CGFloat,
            canvasHeight: CGFloat,
            backgroundColor: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ) {
            self.width = width
            self.height = height
            self.duration = duration
            self.frameRate = frameRate
            self.canvasWidth = canvasWidth
            self.canvasHeight = canvasHeight
            self.backgroundColor = backgroundColor
        }
    }
    
    // MARK: - Properties
    
    /// Elements to be rendered
    private var canvasElements: [CanvasElement] = []
    
    /// Animation controller that manages element animations
    private var animationController: AnimationController
    
    /// Progress tracking publisher
    private var progressPublisher = PassthroughSubject<Float, Never>()
    
    /// Progress publisher that can be observed to track export progress
    var progress: AnyPublisher<Float, Never> {
        progressPublisher.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    /// Initialize with canvas elements and animation controller
    /// - Parameters:
    ///   - canvasElements: Canvas elements to render
    ///   - animationController: Animation controller that manages element animations
    init(animationController: AnimationController) {
        self.animationController = animationController
    }
    
    /// Set the canvas elements to render
    /// - Parameter elements: The array of canvas elements
    @MainActor
    func setElements(_ elements: [CanvasElement]) {
        self.canvasElements = elements
    }
    
    // MARK: - Public Methods
    
    /// Render the canvas elements to a video file
    /// - Parameters:
    ///   - configuration: Configuration for the video rendering
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: URL to the created video asset
    func renderToVideo(configuration: Configuration, progressHandler: ((Float) -> Void)? = nil) async throws -> AVAsset {
        // Set up a subscription to forward progress updates if a handler is provided
        var cancellables = Set<AnyCancellable>()
        if let progressHandler = progressHandler {
            progressPublisher
                .receive(on: DispatchQueue.main)
                .sink { progress in 
                    progressHandler(progress)
                    
                    // Also post a notification for any observers
                    NotificationCenter.default.post(
                        name: Notification.Name("ExportProgressUpdate"),
                        object: nil,
                        userInfo: ["progress": progress]
                    )
                }
                .store(in: &cancellables)
        }
        
        // Create the video with animated frames
        let frameCount = Int(configuration.duration * Double(configuration.frameRate))
        
        // Ensure we have a valid duration
        if frameCount <= 0 || configuration.duration <= 0 {
            throw NSError(domain: "MotionStoryline", code: 102, userInfo: [NSLocalizedDescriptionKey: "Invalid export duration. Duration must be greater than 0."])
        }
        
        // Create a temporary file URL for the video
        // Use NSTemporaryDirectory() which is more reliable in sandboxed environments
        let tempDirPath = NSTemporaryDirectory()
        let tempDir = URL(fileURLWithPath: tempDirPath)
        let temporaryVideoURL = tempDir.appendingPathComponent("temp_canvas_\(UUID().uuidString).mov")
        
        // If a temporary file already exists, delete it
        if FileManager.default.fileExists(atPath: temporaryVideoURL.path) {
            try FileManager.default.removeItem(at: temporaryVideoURL)
        }
        
        os_log("Creating temporary video file at: %{public}@", log: OSLog.default, type: .info, temporaryVideoURL.path)
        
        // Note: We don't modify the animation controller during export to avoid UI updates
        // This prevents layout recursion issues during background rendering
        
        // Capture the necessary data for rendering on the main actor
        let elementsForRendering = canvasElements
        let animationControllerRef = animationController
        
        // Create an asset writer to generate a video
        guard let assetWriter = try? AVAssetWriter(outputURL: temporaryVideoURL, fileType: .mov) else {
            throw NSError(domain: "MotionStoryline", code: 103, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset writer"])
        }
        
        // Configure video settings with proper color space information
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: configuration.width,
            AVVideoHeightKey: configuration.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 5000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCAVLC
            ]
        ]
        
        // Create a writer input
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        // Create a pixel buffer adaptor - match CanvasRenderer exactly
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: configuration.width,
            kCVPixelBufferHeightKey as String: configuration.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
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
        
        // Check if writing started successfully
        guard assetWriter.status == .writing else {
            let errorMessage = assetWriter.error?.localizedDescription ?? "Unknown error starting asset writer"
            throw NSError(domain: "MotionStoryline", code: 107, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing: \(errorMessage)"])
        }
        
        assetWriter.startSession(atSourceTime: .zero)
        
        // Bitmap info for context creation - match CanvasRenderer exactly
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        // Scale factor for positioning elements
        let scaleFactor = min(
            CGFloat(configuration.width) / configuration.canvasWidth,
            CGFloat(configuration.height) / configuration.canvasHeight
        )
        
        // Center offset to position elements in the center of the frame
        let xOffset = (CGFloat(configuration.width) - configuration.canvasWidth * scaleFactor) / 2
        let yOffset = (CGFloat(configuration.height) - configuration.canvasHeight * scaleFactor) / 2
        
        // Create a time information
        var frameTime = CMTime.zero
        let frameDuration = CMTimeMake(value: 1, timescale: CMTimeScale(configuration.frameRate))
        
        // Track progress
        var lastReportedProgress: Float = 0
        
        // Create a semaphore to wait for rendering completion
        let semaphore = DispatchSemaphore(value: 0)
        
        // Create a queue for media processing
        let mediaQueue = DispatchQueue(label: "com.app.Motion-Storyline.mediaQueue")
        var lastReportTime: CFTimeInterval = CACurrentMediaTime()
        
        writerInput.requestMediaDataWhenReady(on: mediaQueue) { [weak self] in
            guard let self = self else { return }
            
            // Render each frame with the animation state at that time
            for frameIdx in 0..<frameCount {
                if writerInput.isReadyForMoreMediaData {
                    // Calculate time for this frame
                    let frameTimeInSeconds = Double(frameIdx) / Double(configuration.frameRate)
                    
                    // Get elements for this time point without updating the animation controller
                    // This avoids UI updates during export which can cause layout recursion
                    let elementsForFrame = Self.getElementsAtTime(
                        frameTimeInSeconds, 
                        elements: elementsForRendering, 
                        animationController: animationControllerRef
                    )
                    
                    // Create a context for this frame
                    guard let context = CGContext(
                        data: nil,
                        width: configuration.width,
                        height: configuration.height,
                        bitsPerComponent: 8,
                        bytesPerRow: configuration.width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: bitmapInfo.rawValue
                    ) else {
                        continue
                    }
                    
                    // Draw background
                    context.setFillColor(configuration.backgroundColor)
                    context.fill(CGRect(x: 0, y: 0, width: configuration.width, height: configuration.height))
                    
                    // Transform context to use top-left origin (same as CanvasRenderer)
                    context.translateBy(x: 0, y: CGFloat(configuration.height))
                    context.scaleBy(x: 1, y: -1)
                    
                    // Draw each element
                    for element in elementsForFrame {
                        self.renderElement(
                            element,
                            to: context,
                            scaleFactor: scaleFactor,
                            xOffset: xOffset,
                            yOffset: yOffset
                        )
                    }
                    
                    // Create an image from the context
                    guard let image = context.makeImage() else {
                        continue
                    }
                    
                    // Create a pixel buffer - match CanvasRenderer format
                    var pixelBuffer: CVPixelBuffer?
                    CVPixelBufferCreate(
                        kCFAllocatorDefault,
                        configuration.width,
                        configuration.height,
                        kCVPixelFormatType_32ARGB,
                        attributes as CFDictionary,
                        &pixelBuffer
                    )
                    
                    if let pixelBuffer = pixelBuffer {
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
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
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
                            
                            // Send progress updates (not too frequently)
                            if currentProgress - lastReportedProgress > 0.01 || 
                               currentTime - lastReportTime > 0.5 {
                                
                                if currentTime - lastReportTime > 0.1 {
                                    DispatchQueue.main.async {
                                        self.progressPublisher.send(currentProgress)
                                    }
                                    lastReportedProgress = currentProgress
                                    lastReportTime = currentTime
                                }
                            }
                        } else {
                            // If appending fails, report the error
                            DispatchQueue.main.async {
                                os_log("Failed to append pixel buffer: %{public}@", log: CanvasVideoRenderer.logger, type: .error, assetWriter.error?.localizedDescription ?? "unknown error")
                            }
                            
                            semaphore.signal()
                            return
                        }
                    }
                }
            }
            
            // Send final progress update
            DispatchQueue.main.async {
                self.progressPublisher.send(1.0)
            }
            
            // Finish writing
            writerInput.markAsFinished()
            
            // Finalize the asset writer
            assetWriter.finishWriting {
                // Signal completion after the asset writer has finished
                semaphore.signal()
            }
        }
        
        // Wait for media writing to complete
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
        if assetWriter.status == .failed {
            let errorMessage = assetWriter.error?.localizedDescription ?? "Unknown asset writer error"
            throw NSError(domain: "MotionStoryline", code: 105, userInfo: [NSLocalizedDescriptionKey: "Failed to create video: \(errorMessage)"])
        } else if assetWriter.status != .completed {
            throw NSError(domain: "MotionStoryline", code: 108, userInfo: [NSLocalizedDescriptionKey: "Asset writer finished with unexpected status: \(assetWriter.status.rawValue)"])
        }
        
        // Clean up
        cancellables.removeAll()
        
        // Verify the file was created successfully before returning the asset
        guard FileManager.default.fileExists(atPath: temporaryVideoURL.path) else {
            throw NSError(domain: "MotionStoryline", code: 106, userInfo: [NSLocalizedDescriptionKey: "Temporary video file was not created successfully"])
        }
        
        // Return the final asset
        return AVURLAsset(url: temporaryVideoURL)
    }
    
    // MARK: - Helper Methods
    
    /// Gets a snapshot of canvas elements with animations applied at a specific time
    /// - Parameters:
    ///   - time: The time point to get elements for
    ///   - elements: The canvas elements to animate
    ///   - animationController: The animation controller containing the tracks
    /// - Returns: Array of elements with animation properties applied
    nonisolated private static func getElementsAtTime(_ time: Double, elements: [CanvasElement], animationController: AnimationController) -> [CanvasElement] {
        // Make a deep copy of the current canvas elements
        var elementsAtTime = elements
        
        // For each element, apply all animated properties at the given time
        for i in 0..<elementsAtTime.count {
            let element = elementsAtTime[i]
            let elementId = element.id.uuidString
            
            // Animate position
            let positionTrackId = "\(elementId)_position"
            if let track = animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint>,
               let position = track.getValue(at: time) {
                elementsAtTime[i].position = position
            }
            
            // Animate size
            let sizeTrackId = "\(elementId)_size"
            if let track = animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGFloat>,
               let size = track.getValue(at: time) {
                if elementsAtTime[i].isAspectRatioLocked {
                    let ratio = element.size.height / element.size.width
                    elementsAtTime[i].size = CGSize(width: size, height: size * ratio)
                } else {
                    elementsAtTime[i].size.width = size
                }
            }
            
            // Animate rotation
            let rotationTrackId = "\(elementId)_rotation"
            if let track = animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double>,
               let rotation = track.getValue(at: time) {
                elementsAtTime[i].rotation = rotation
            }
            
            // Animate opacity
            let opacityTrackId = "\(elementId)_opacity"
            if let track = animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double>,
               let opacity = track.getValue(at: time) {
                elementsAtTime[i].opacity = opacity
            }
        }
        
        return elementsAtTime
    }
    
    /// Renders a single element to the given context
    /// - Parameters:
    ///   - element: The element to render
    ///   - context: The graphics context to render to
    ///   - scaleFactor: Scale factor for sizing and positioning
    ///   - xOffset: Horizontal offset for centering
    ///   - yOffset: Vertical offset for centering
    nonisolated private func renderElement(_ element: CanvasElement, to context: CGContext, scaleFactor: CGFloat, xOffset: CGFloat, yOffset: CGFloat) {
        // Helper function to safely convert SwiftUI Color to CGColor with consistent color space
        func convertToCGColor(_ color: Color) -> CGColor {
            // Use the same color conversion approach as CanvasExport.swift for consistency
            // Convert through NSColor to ensure consistent color space
            let nsColor = NSColor(color)
            // Use sRGB color space for consistent rendering across canvas and export
            let colorInRGB = nsColor.usingColorSpace(.sRGB) ?? nsColor
            return colorInRGB.cgColor
        }
        
        // Scale and position the element
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
            // Apply fill color with opacity
            let fillColor = convertToCGColor(element.color)
            context.setFillColor(fillColor)
            context.fill(rect)
            
        case .ellipse:
            // Apply fill color with opacity
            let fillColor = convertToCGColor(element.color)
            context.setFillColor(fillColor)
            context.fillEllipse(in: rect)
            

            
        case .text:
            // Handle text rendering with proper coordinate system handling (same as CanvasRenderer)
            let fontSize = element.fontSize
            
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
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: NSColor(cgColor: convertToCGColor(element.color)) ?? NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
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
            
        case .image:
            // Handle image elements with proper coordinate system handling (same as CanvasRenderer)
            if let assetURL = element.assetURL, assetURL.isFileURL {
                // Use NSImage for consistent image loading and handling
                if let image = NSImage(contentsOfFile: assetURL.path) {
                    // The context is already set up with opacity and rotation
                    // We need to draw the NSImage into the element's rect
                    // NSGraphicsContext is used here to draw NSImage into CGContext
                    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = nsContext
                    
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
                } else {
                    // Fallback placeholder for images
                    context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                    context.fill(rect)
                }
            } else {
                // Fallback placeholder for images
                context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                context.fill(rect)
            }
            
        case .video:
            // Handle video elements with proper coordinate system handling (same as CanvasRenderer)
            if let assetURL = element.assetURL, assetURL.isFileURL {
                let asset = AVAsset(url: assetURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.requestedTimeToleranceBefore = .zero
                imageGenerator.requestedTimeToleranceAfter = .zero
                
                // Calculate video time based on current export time and element's video start time
                // Note: This would need to be passed from the export context
                // For now, using a placeholder approach
                let videoTime = max(0, element.videoStartTime)
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
                    // Fallback placeholder for videos
                    context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                    context.fill(rect)
                }
            } else {
                // Fallback placeholder for videos
                context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                context.fill(rect)
            }
        }
        
        // Restore the context state
        context.restoreGState()
    }
    
    /// Create a black pixel buffer for use in video compositions
    /// - Parameters:
    ///   - width: Width of the buffer
    ///   - height: Height of the buffer
    /// - Returns: A CVPixelBuffer filled with black
    func createBlackFramePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
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
            os_log("Failed to create pixel buffer", log: CanvasVideoRenderer.logger, type: .error)
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
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
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