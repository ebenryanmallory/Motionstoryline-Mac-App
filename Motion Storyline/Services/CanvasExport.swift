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
    // Shared instance for static access
    static let shared = CanvasExportRenderer()
    
    private var elements: [CanvasElement] = []
    private var animationController: AnimationController?
    
    struct Configuration {
        let width: Int
        let height: Int
        let duration: Double
        let frameRate: Float
        let canvasWidth: CGFloat
        let canvasHeight: CGFloat
        let proResProfile: VideoExporter.ProResProfile?
    }
    
    // Default initializer for shared instance
    private init() {
        self.animationController = nil
    }
    
    // Initializer with animation controller
    init(animationController: AnimationController) {
        self.animationController = animationController
    }
    
    func setElements(_ elements: [CanvasElement]) {
        self.elements = elements
    }
    
    // Method to match the signature used in DesignCanvas.swift
    func renderToVideo(
        width: Int,
        height: Int,
        duration: Double,
        frameRate: Float,
        elements: [CanvasElement]? = nil,
        animationController: AnimationController? = nil,
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        proResProfile: VideoExporter.ProResProfile? = nil,
        progressHandler: @escaping (Float) -> Void = { _ in }
    ) async throws -> AVAsset {
        // Set elements and animation controller if provided
        if let elements = elements {
            self.elements = elements
        }
        
        if let animationController = animationController {
            self.animationController = animationController
        }
        
        // Create configuration from parameters
        let configuration = Configuration(
            width: width,
            height: height,
            duration: duration,
            frameRate: frameRate,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            proResProfile: proResProfile
        )
        
        return try await renderToVideoInternal(configuration: configuration, progressHandler: progressHandler)
    }
    
    // Internal implementation of renderToVideo
    private func renderToVideoInternal(
        configuration: Configuration,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> AVAsset {
        var elementsToRender = self.elements
        // var placeholderAdded = false // Removed unused variable

        // Check if we have elements to export, add placeholder if not
        if elementsToRender.isEmpty {
            var placeholderText = CanvasElement.text(
                at: CGPoint(x: Double(configuration.canvasWidth)/2, y: Double(configuration.canvasHeight)/2)
            )
            placeholderText.text = "Motion Storyline Export"
            placeholderText.size = CGSize(width: 500, height: 100) // Example size
            placeholderText.color = .black
            placeholderText.textAlignment = .center
            
            elementsToRender.append(placeholderText)
        }

        // Create a temporary URL for the rendered video
        let tempDir = FileManager.default.temporaryDirectory
        let temporaryVideoURL = tempDir.appendingPathComponent("temp_canvas_\(UUID().uuidString).mov")
        
        // If a temporary file already exists, delete it
        if FileManager.default.fileExists(atPath: temporaryVideoURL.path) {
            try FileManager.default.removeItem(at: temporaryVideoURL)
        }
        
        // Determine file type based on codec choice
        let fileType = getFileType(for: configuration)
        
        // Create an asset writer to generate a video
        guard let assetWriter = try? AVAssetWriter(outputURL: temporaryVideoURL, fileType: fileType) else {
            throw NSError(domain: "MotionStoryline", code: 103, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset writer"])
        }
        
        // Configure video settings based on codec choice (H.264 vs ProRes)
        let videoSettings = createVideoSettings(for: configuration)
        
        // Create a writer input
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        // Create a pixel buffer adaptor
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
        assetWriter.startSession(atSourceTime: .zero)
        
        // Bitmap info for context creation - match CanvasImageRenderer exactly
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
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
        let currentAnimationTime = animationController?.currentTime ?? 0.0
        let isCurrentlyPlaying = animationController?.isPlaying ?? false
        
        // Pause the animation during export (if playing)
        if isCurrentlyPlaying {
            animationController?.pause()
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
                        self.animationController?.currentTime = frameTimeInSeconds
                    }
                    
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
                    
                    // Draw white background
                    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: configuration.width, height: configuration.height))
                    
                    // Draw each element
                    for element in elementsToRender { // Use the potentially modified elementsToRender list

                        let scaledSize = CGSize(
                            width: element.size.width * scaleFactor,
                            height: element.size.height * scaleFactor
                        )
                        
                        let scaledPosition = CGPoint(
                            x: element.position.x * scaleFactor + xOffset,
                            y: element.position.y * scaleFactor + yOffset
                        )
                        
                        // Position the element (convert from center to top-left origin for CGContext's bottom-left origin)
                        let rect = CGRect(
                            x: scaledPosition.x - scaledSize.width / 2,
                            y: CGFloat(configuration.height) - scaledPosition.y - scaledSize.height / 2, // Adjusted for Y-up CGContext
                            width: scaledSize.width,
                            height: scaledSize.height
                        )
                        
                        // Save the context state before transformations
                        context.saveGState()
                        
                        // Apply rotation (around the center of the element, adjusted for CGContext)
                        context.translateBy(x: scaledPosition.x, y: CGFloat(configuration.height) - scaledPosition.y) // Translate to element center (Y-flipped)
                        context.rotate(by: -element.rotation * .pi / 180) // Apply rotation (negative for CGContext)
                        context.translateBy(x: -scaledPosition.x, y: -(CGFloat(configuration.height) - scaledPosition.y)) // Translate back
                        
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

                        case .text:
                            // Implement proper text rendering using Core Text
                            let attributedString = NSAttributedString(
                                string: element.text,
                                attributes: [
                                    // Use the element's fontSize property for consistent rendering
                                    .font: NSFont.systemFont(ofSize: element.fontSize),
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
                        case .image:
                            context.saveGState()
                            if let assetURL = element.assetURL, assetURL.isFileURL, 
                               let imageData = try? Data(contentsOf: assetURL), 
                               let nsImage = NSImage(data: imageData) {
                                
                                var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
                                if let cgImage = nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) {
                                    context.setAlpha(CGFloat(element.opacity)) // Apply opacity specifically for the image
                                    context.draw(cgImage, in: rect) // Draw the image in the calculated rect
                                }
                            } else {
                                // Fallback placeholder if image loading fails
                                context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                                context.fill(rect)
                                let p = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                                p.alignment = .center
                                let attrs = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12), NSAttributedString.Key.paragraphStyle: p, NSAttributedString.Key.foregroundColor: NSColor.black]
                                ("Image Error" as NSString).draw(in: rect.insetBy(dx: 5, dy: 5), withAttributes: attrs)
                            }
                            context.restoreGState()
                        case .video:
                            // Draw a placeholder for videos
                            context.setFillColor(CGColor(gray: 0.7, alpha: 1.0))
                            context.fill(rect)
                            let p = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                            p.alignment = .center
                            let attrs = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12), NSAttributedString.Key.paragraphStyle: p, NSAttributedString.Key.foregroundColor: NSColor.black]
                            ("Video Placeholder" as NSString).draw(in: rect.insetBy(dx: 5, dy: 5), withAttributes: attrs)
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
                                self.animationController?.currentTime = currentAnimationTime
                                if isCurrentlyPlaying {
                                    self.animationController?.play()
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
            DispatchQueue.main.sync {
                self.animationController?.currentTime = currentAnimationTime
                if isCurrentlyPlaying {
                    self.animationController?.play()
                }
            }

            // If a placeholder was added, it's part of a local copy 'elementsToRender', so no need to remove from self.elements

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
    
    /// Create video settings based on codec choice (H.264 vs ProRes)
    private func createVideoSettings(for configuration: Configuration) -> [String: Any] {
        if let proResProfile = configuration.proResProfile {
            // ProRes settings
            return [
                AVVideoCodecKey: proResProfile.avCodecKey,
                AVVideoWidthKey: configuration.width,
                AVVideoHeightKey: configuration.height,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ]
                // No compression properties for ProRes - they're handled internally by the codec
            ]
        } else {
            // H.264 settings (existing implementation)
            return [
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
        }
    }
    
    /// Determine the appropriate file type based on codec
    private func getFileType(for configuration: Configuration) -> AVFileType {
        if configuration.proResProfile != nil {
            return .mov  // ProRes requires MOV container
        } else {
            return .mov  // Keep MOV for consistency, can be changed to .mp4 for H.264 if needed
        }
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