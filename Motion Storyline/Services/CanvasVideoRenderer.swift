import Foundation
@preconcurrency import AVFoundation
import SwiftUI
import AppKit
import CoreGraphics
import Combine
import os.log

/// Service responsible for rendering canvas elements to a video file
@MainActor
class CanvasVideoRenderer {
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
        let tempDir = FileManager.default.temporaryDirectory
        let temporaryVideoURL = tempDir.appendingPathComponent("temp_canvas_\(UUID().uuidString).mov")
        
        // If a temporary file already exists, delete it
        if FileManager.default.fileExists(atPath: temporaryVideoURL.path) {
            try FileManager.default.removeItem(at: temporaryVideoURL)
        }
        
        // Store the current animation state to restore later
        let currentAnimationTime = animationController.currentTime
        let isCurrentlyPlaying = animationController.isPlaying
        
        // Pause the animation during export (if playing)
        if isCurrentlyPlaying {
            await MainActor.run {
                animationController.pause()
            }
        }
        
        // Create a copy of the current elements for rendering
        _ = canvasElements
        
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
            // Capture a weak reference to self to avoid strong reference cycles
            // and store essential variables locally to avoid needing self in the closure
            // let animationController = self.animationController // Removed, use self.animationController
            // let progressPublisher = self.progressPublisher   // Removed, use self.progressPublisher
            // let canvasElements = self.canvasElements           // Removed, was unused and self.canvasElements used later or captured as initialCanvasElements implicitly by usage context
            
            // Render each frame with the animation state at that time
            for frameIdx in 0..<frameCount {
                if writerInput.isReadyForMoreMediaData {
                    // Calculate time for this frame
                    let frameTimeInSeconds = Double(frameIdx) / Double(configuration.frameRate)
                    
                    // Update animation controller on the main thread (synchronously)
                    // and get the elements for this time point
                    var elementsForFrame: [CanvasElement] = []
                    
                    // Use a dispatch semaphore to wait for the main thread task
                    let animationSemaphore = DispatchSemaphore(value: 0)
                    
                    // Dispatch to main thread to update animation state
                    DispatchQueue.main.async {
                        self.animationController.currentTime = frameTimeInSeconds
                        // Get a snapshot of elements at current time
                        elementsForFrame = self.getElementsAtTime(frameTimeInSeconds)
                        animationSemaphore.signal()
                    }
                    
                    // Wait for animation update to complete
                    _ = animationSemaphore.wait(timeout: .distantFuture)
                    
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
                    
                    // Draw background
                    context.setFillColor(configuration.backgroundColor)
                    context.fill(CGRect(x: 0, y: 0, width: configuration.width, height: configuration.height))
                    
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
                    
                    // Create a pixel buffer
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
                            
                            // Restore original animation state
                            DispatchQueue.main.sync {
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
                self.progressPublisher.send(1.0)
            }
            
            // Restore original animation state
            // Use a dispatch semaphore to wait for the main thread task
            let restorationSemaphore = DispatchSemaphore(value: 0)
            
            // Dispatch to main thread to restore animation state
            DispatchQueue.main.async {
                self.animationController.currentTime = currentAnimationTime
                if isCurrentlyPlaying {
                    self.animationController.play()
                }
                restorationSemaphore.signal()
            }
            
            // Wait for restoration to complete
            _ = restorationSemaphore.wait(timeout: .distantFuture)
            
            // Finish writing
            writerInput.markAsFinished()
            
            // Signal completion
            semaphore.signal()
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
        if let error = assetWriter.error {
            throw NSError(domain: "MotionStoryline", code: 105, userInfo: [NSLocalizedDescriptionKey: "Failed to create video: \(error.localizedDescription)"])
        }
        
        // Clean up
        cancellables.removeAll()
        
        // Return the final asset
        return AVAsset(url: temporaryVideoURL)
    }
    
    // MARK: - Helper Methods
    
    /// Gets a snapshot of canvas elements with animations applied at a specific time
    /// - Parameter time: The time point to get elements for
    /// - Returns: Array of elements with animation properties applied
    private func getElementsAtTime(_ time: Double) -> [CanvasElement] {
        // Make a deep copy of the current canvas elements
        var elementsAtTime = canvasElements
        
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
        // Helper function to properly convert SwiftUI Color to CGColor
        func convertToCGColor(_ color: Color) -> CGColor {
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
            
        case .path:
            // Set stroke color and width
            let pathColor = convertToCGColor(element.color)
            context.setStrokeColor(pathColor)
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
            
            // Apply element opacity to the entire text
            context.setAlpha(element.opacity)
            
            // Create the text frame to draw in
            let textPath = CGPath(rect: rect, transform: nil)
            let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
            let textFrame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attributedString.length), textPath, nil)
            
            // Draw the text
            CTFrameDraw(textFrame, context)
            
        case .image:
            // Handle image elements
            if let assetURL = element.assetURL, assetURL.isFileURL,
               let imageData = try? Data(contentsOf: assetURL),
               let nsImage = NSImage(data: imageData) {
                
                var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
                if let cgImage = nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) {
                    context.setAlpha(CGFloat(element.opacity))
                    context.draw(cgImage, in: rect)
                }
            } else {
                // Fallback placeholder for images
                context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                context.fill(rect)
            }
            
        case .video:
            // Handle video elements with timeline synchronization
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
                    context.setAlpha(CGFloat(element.opacity))
                    context.draw(cgImage, in: rect)
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