import Foundation
import AVFoundation
import AppKit
import os.log
import SwiftUI
// Import VideoExporter directly since we're using it without the Services namespace

/// A service that coordinates export operations between FrameExporter and VideoExporter
@available(macOS 10.15, *)
public class ExportCoordinator {
    // Logger for debugging
    private static let logger = OSLog(subsystem: "com.app.Motion-Storyline", category: "ExportCoordinator")
    
    /// Export configuration combining all export settings
    public struct ExportConfiguration {
        /// The format to export in
        public var format: ExportFormat
        
        /// Output resolution width
        public var width: Int
        
        /// Output resolution height
        public var height: Int
        
        /// Frame rate (frames per second)
        public var frameRate: Float
        
        /// Number of frames to export (user-specified limit)
        public var numberOfFrames: Int?
        
        /// Output URL for the exported file or directory
        public var outputURL: URL
        
        /// ProRes quality profile (used when exporting with ProRes codec)
        public var proResProfile: VideoExporter.ProResProfile?
        
        /// Whether to include audio in the export
        public var includeAudio: Bool
        
        /// For image sequence exports: the base filename without extension (e.g. "frame")
        public var baseFilename: String
        
        /// For JPEG image sequence exports: the compression quality (0.0 to 1.0)
        public var imageQuality: CGFloat?
        
        public init(
            format: ExportFormat,
            width: Int,
            height: Int,
            frameRate: Float,
            numberOfFrames: Int? = nil,
            outputURL: URL,
            proResProfile: VideoExporter.ProResProfile? = nil,
            includeAudio: Bool = true,
            baseFilename: String = "frame",
            imageQuality: CGFloat? = nil
        ) {
            self.format = format
            self.width = width
            self.height = height
            self.frameRate = frameRate
            self.numberOfFrames = numberOfFrames
            self.outputURL = outputURL
            self.proResProfile = proResProfile
            self.includeAudio = includeAudio
            self.baseFilename = baseFilename
            self.imageQuality = imageQuality
        }
    }
    
    /// The asset to be exported
    private let asset: AVAsset
    
    /// Access to the animation controller for keyframe data
    private let animationController: AnimationController?
    
    /// The current canvas elements to be animated
    private let canvasElements: [CanvasElement]
    
    /// Canvas size for rendering
    private let canvasSize: CGSize
    
    /// Initialize with an AVAsset
    public init(asset: AVAsset) {
        self.asset = asset
        self.animationController = nil
        self.canvasElements = []
        self.canvasSize = CGSize(width: 1280, height: 720)
    }
    
    /// Initialize with animation and canvas data
    init(asset: AVAsset, animationController: AnimationController, canvasElements: [CanvasElement], canvasSize: CGSize) {
        self.asset = asset
        self.animationController = animationController
        self.canvasElements = canvasElements
        self.canvasSize = canvasSize
    }
    
    /// Export the asset using the specified configuration
    /// - Parameters:
    ///   - configuration: Export configuration
    ///   - progressHandler: Optional callback for export progress
    /// - Returns: URL to the exported file(s)
    public func export(
        with configuration: ExportConfiguration,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> URL {
        os_log("Starting export with format: %{public}@", log: ExportCoordinator.logger, type: .info, 
               String(describing: configuration.format))
        
        switch configuration.format {
        case .imageSequence(let imageFormat):
            return try await exportImageSequence(
                with: configuration,
                imageFormat: imageFormat,
                progressHandler: progressHandler
            )
            
        case .video:
            return try await exportVideo(
                with: configuration,
                progressHandler: progressHandler
            )
            
        case .gif:
            return try await exportGIF(
                with: configuration,
                progressHandler: progressHandler
            )
            
        case .projectFile:
            throw NSError(domain: "ExportCoordinator", code: 1, 
                          userInfo: [NSLocalizedDescriptionKey: "Project file export not implemented"])
            
        case .batchExport:
            throw NSError(domain: "ExportCoordinator", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Batch export not implemented"])
        }
    }
    
    /// Check if a directory exists and prompt user for confirmation to overwrite
    /// - Parameter directoryURL: URL to the directory
    /// - Returns: Boolean indicating whether to proceed with export
    private func confirmDirectoryOverwrite(at directoryURL: URL) async throws -> Bool {
        // Check if directory exists
        let fileManager = FileManager.default
        let directoryExists = fileManager.fileExists(atPath: directoryURL.path)
        
        // If the directory doesn't exist, no need for confirmation
        guard directoryExists else {
            return true
        }
        
        // Create continuation for async/await pattern
        return try await withCheckedThrowingContinuation { continuation in
            // We'll use the main thread's FileManager instance later instead of capturing
            
            DispatchQueue.main.async {
                // Create alert to ask for confirmation
                let alert = NSAlert()
                alert.messageText = "Directory Already Exists"
                alert.informativeText = "The directory '\(directoryURL.lastPathComponent)' already exists. Do you want to overwrite its contents?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Overwrite")
                alert.addButton(withTitle: "Cancel")
                
                // Show alert and get user response
                let response = alert.runModal()
                
                if response == .alertFirstButtonReturn {
                    // User chose to overwrite
                    do {
                        // Use FileManager.default directly on the main thread instead of captured value
                        try FileManager.default.removeItem(at: directoryURL)
                        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                        continuation.resume(returning: true)
                    } catch {
                        os_log("Failed to prepare directory for export: %{public}@", 
                               log: ExportCoordinator.logger, type: .error, error.localizedDescription)
                        continuation.resume(throwing: error)
                    }
                } else {
                    // User cancelled
                    continuation.resume(throwing: NSError(domain: "ExportCoordinator", code: 4, 
                                             userInfo: [NSLocalizedDescriptionKey: "Export cancelled by user"]))
                }
            }
        }
    }
    
    /// Export the asset as an image sequence
    private func exportImageSequence(
        with configuration: ExportConfiguration,
        imageFormat: ImageFormat,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> URL {
        os_log("Exporting image sequence in %{public}@ format", log: ExportCoordinator.logger, type: .info, 
               imageFormat.rawValue)
        
        // Access the parent directory with security-scoped resources
        let parentDirectory = configuration.outputURL.deletingLastPathComponent()
        os_log("[DEBUG] ExportCoordinator: outputURL passed to export: %{public}@", log: ExportCoordinator.logger, type: .debug, configuration.outputURL.path)
        os_log("[DEBUG] ExportCoordinator: parentDirectory for security scope: %{public}@", log: ExportCoordinator.logger, type: .debug, parentDirectory.path)
        var didStartAccessingParent = false
        
        if parentDirectory.startAccessingSecurityScopedResource() {
            didStartAccessingParent = true
            os_log("Successfully accessed parent directory: %{public}@", log: ExportCoordinator.logger, type: .debug, parentDirectory.path)
        } else {
            os_log("Failed to access parent directory with security-scoped resources: %{public}@", log: ExportCoordinator.logger, type: .error, parentDirectory.path)
        }
        
        // Ensure we stop accessing the resource when done
        defer {
            if didStartAccessingParent {
                parentDirectory.stopAccessingSecurityScopedResource()
            }
        }
        
        // Check if directory exists and confirm overwrite if needed
        let shouldProceed = try await confirmDirectoryOverwrite(at: configuration.outputURL)
        
        // Return early if user cancelled
        guard shouldProceed else {
            throw NSError(domain: "ExportCoordinator", code: 4, 
                          userInfo: [NSLocalizedDescriptionKey: "Export cancelled by user"])
        }
        
        // Explicitly create the directory before exporting
        do {
            if !FileManager.default.fileExists(atPath: configuration.outputURL.path) {
                try FileManager.default.createDirectory(
                    at: configuration.outputURL, 
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                os_log("Created output directory: %{public}@", log: ExportCoordinator.logger, type: .debug, 
                       configuration.outputURL.path)
            }
            
            // Verify write access with a test file
            let testURL = configuration.outputURL.appendingPathComponent(".test_access")
            let testFileCreated = FileManager.default.createFile(atPath: testURL.path, contents: Data())
            os_log("[DEBUG] ExportCoordinator: Attempted to create test file at %{public}@, success: %{public}@", log: ExportCoordinator.logger, type: .debug, testURL.path, String(testFileCreated))
            if !testFileCreated {
                os_log("[ERROR] ExportCoordinator: Failed to create test file at %{public}@", log: ExportCoordinator.logger, type: .error, testURL.path)
                throw NSError(domain: "ExportCoordinator", code: 5,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot write to output directory. Please check permissions."])
            }
            do {
                try FileManager.default.removeItem(at: testURL)
                os_log("[DEBUG] ExportCoordinator: Successfully removed test file at %{public}@", log: ExportCoordinator.logger, type: .debug, testURL.path)
            } catch {
                os_log("[ERROR] ExportCoordinator: Failed to remove test file at %{public}@ : %{public}@", log: ExportCoordinator.logger, type: .error, testURL.path, error.localizedDescription)
            }
            
        } catch {
            os_log("Failed to create or access output directory: %{public}@", 
                   log: ExportCoordinator.logger, type: .error, error.localizedDescription)
            throw NSError(domain: "ExportCoordinator", code: 5,
                  userInfo: [NSLocalizedDescriptionKey: "Failed to create output directory. Please check permissions and try again."])
        }
        
        // Create FrameExporter configuration
        let frameExporterConfig = FrameExporter.Configuration(
            width: configuration.width,
            height: configuration.height,
            frameRate: configuration.frameRate,
            imageFormat: imageFormat,
            imageQuality: configuration.imageQuality
        )
        
        // Create FrameExporter and export the sequence
        os_log("[DEBUG] FrameExporter will receive outputDirectory: %{public}@", log: ExportCoordinator.logger, type: .debug, configuration.outputURL.path)
        
        // Create a function to get elements at a specific time
        let getElementsAtTime: (CMTime) -> [CanvasElement] = { [weak self] time in
            // Log that we're exporting a frame at this time
            os_log("Exporting frame at time %{public}f", log: ExportCoordinator.logger, type: .debug, time.seconds)
            
            guard let self = self else {
                // If self is nil, return empty array (should never happen)
                return []
            }
            
            // Convert CMTime to seconds for animation calculation
            let timeSeconds = time.seconds
            
            // If we have actual canvas elements and animation controller, use them
            if let animationController = self.animationController, !self.canvasElements.isEmpty {
                // Make a deep copy of the current canvas elements
                var elementsAtTime = self.canvasElements
                
                // For each element, apply all animated properties at the current time
                for i in 0..<elementsAtTime.count {
                    let element = elementsAtTime[i]
                    let elementId = element.id.uuidString
                    
                    let initialElementPositionForFrame = elementsAtTime[i].position // Capture current state from elementsAtTime for this frame's evaluation
                    os_log("[ExportFrameDebug] Element ID: %{public}s, Initial Pos for frame eval: (%f, %f)", log: ExportCoordinator.logger, type: .debug, elementId, initialElementPositionForFrame.x, initialElementPositionForFrame.y)

                    // Update position if there's a position track
                    let positionTrackId = "\(elementId)_position"
                    if let track = animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> {
                        os_log("[ExportFrameDebug] Element ID: %{public}s - Found position track.", log: ExportCoordinator.logger, type: .debug, elementId)
                        if let animatedPosition = track.getValue(at: timeSeconds) {
                            os_log("[ExportFrameDebug] Element ID: %{public}s - Animated Pos from track: (%f, %f). OVERRIDING initial frame eval pos.", log: ExportCoordinator.logger, type: .debug, elementId, animatedPosition.x, animatedPosition.y)
                            elementsAtTime[i].position = animatedPosition
                        } else {
                            os_log("[ExportFrameDebug] Element ID: %{public}s - Position track getValue returned nil. Using initial pos for frame eval: (%f, %f).", log: ExportCoordinator.logger, type: .debug, elementId, initialElementPositionForFrame.x, initialElementPositionForFrame.y)
                            // elementsAtTime[i].position remains initialElementPositionForFrame
                        }
                    } else {
                        os_log("[ExportFrameDebug] Element ID: %{public}s - No position track found. Using initial pos for frame eval: (%f, %f).", log: ExportCoordinator.logger, type: .debug, elementId, initialElementPositionForFrame.x, initialElementPositionForFrame.y)
                        // elementsAtTime[i].position remains initialElementPositionForFrame
                    }
                    os_log("[ExportFrameDebug] Element ID: %{public}s, Final Pos for frame render: (%f, %f)", log: ExportCoordinator.logger, type: .debug, elementId, elementsAtTime[i].position.x, elementsAtTime[i].position.y)
                    
                    // Update scale/size if there's a scale track
                    let sizeTrackId = "\(elementId)_size"
                    if let track = animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGFloat>,
                       let size = track.getValue(at: timeSeconds) {
                        // Apply scale to the original size
                        if elementsAtTime[i].isAspectRatioLocked {
                            let ratio = element.size.height / element.size.width
                            elementsAtTime[i].size = CGSize(width: size, height: size * ratio)
                        } else {
                            elementsAtTime[i].size.width = size
                        }
                    }
                    
                    // Update rotation if there's a rotation track
                    let rotationTrackId = "\(elementId)_rotation"
                    if let track = animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double>,
                       let rotation = track.getValue(at: timeSeconds) {
                        elementsAtTime[i].rotation = rotation
                    }
                    
                    // Update opacity if there's an opacity track
                    let opacityTrackId = "\(elementId)_opacity"
                    if let track = animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double>,
                       let opacity = track.getValue(at: timeSeconds) {
                        elementsAtTime[i].opacity = opacity
                    }
                    
                    // Update color if there's a color track
                    let colorTrackId = "\(elementId)_color"
                    if let track = animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color>,
                       let color = track.getValue(at: timeSeconds) {
                        elementsAtTime[i].color = color
                    }
                    
                    // Path animation if applicable
                    let pathTrackId = "\(elementId)_path"
                    if let track = animationController.getTrack(id: pathTrackId) as? KeyframeTrack<[CGPoint]>,
                       let pathPoints = track.getValue(at: timeSeconds) {
                        elementsAtTime[i].path = pathPoints
                    }
                }
                
                os_log("Exporting frame with %{public}d animated elements", 
                       log: ExportCoordinator.logger, type: .debug, elementsAtTime.count)
                return elementsAtTime
            } else {
                // Fallback to demo animation if no actual data is provided
                // Create example elements
                var elementsAtTime: [CanvasElement] = [
                    // Rectangle that moves horizontally
                    CanvasElement.rectangle(
                        at: CGPoint(x: 640, y: 360),
                        size: CGSize(width: 200, height: 150)
                    ),
                    
                    // Ellipse that changes size
                    CanvasElement.ellipse(
                        at: CGPoint(x: 640, y: 360),
                        size: CGSize(width: 150, height: 150)
                    ),
                    
                    // Text element that changes opacity
                    CanvasElement.text(
                        at: CGPoint(x: 640, y: 200),
                        content: "Motion Storyline"
                    )
                ]
                
                // Apply demo animations
                for i in 0..<elementsAtTime.count {
                    if i == 0 { // For the rectangle (first element)
                        // Simulate horizontal movement animation
                        let newX = 640 + 200 * sin(timeSeconds * 2.0)
                        elementsAtTime[i].position = CGPoint(x: newX, y: elementsAtTime[i].position.y)
                    } else if i == 1 { // For the ellipse (second element)
                        // Simulate size animation
                        let scaleFactor = 1.0 + 0.5 * sin(timeSeconds * 3.0)
                        let baseSize = CGSize(width: 150, height: 150)
                        elementsAtTime[i].size = CGSize(
                            width: baseSize.width * scaleFactor,
                            height: baseSize.height * scaleFactor
                        )
                        
                        // Add rotation animation
                        elementsAtTime[i].rotation = 45 * sin(timeSeconds)
                    } else if i == 2 { // For the text (third element)
                        // Simulate opacity animation
                        elementsAtTime[i].opacity = 0.5 + 0.5 * sin(timeSeconds * 1.5)
                        
                        // Color animation
                        let hue = (timeSeconds / 3.0).truncatingRemainder(dividingBy: 1.0)
                        elementsAtTime[i].color = Color(hue: hue, saturation: 0.7, brightness: 0.9)
                    }
                }
                
                os_log("Using demo animation data because no actual animation controller or elements were provided", 
                       log: ExportCoordinator.logger, type: .info)
                return elementsAtTime
            }
        }
        
        // Use the canvas size from configuration
        let canvasSize = CGSize(width: configuration.width, height: configuration.height)
        
        let frameExporter = FrameExporter(
            getElementsAtTime: getElementsAtTime,
            canvasSize: canvasSize
        )
        
        do {
            // Calculate endTime if we have numberOfFrames specified
            let startTime = CMTime.zero
            var endTime: CMTime? = nil
            
            if let numberOfFrames = configuration.numberOfFrames, numberOfFrames > 0 {
                // Calculate duration based on number of frames and frame rate
                let durationInSeconds = Double(numberOfFrames) / Double(configuration.frameRate)
                endTime = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
                os_log("Limited export to %{public}d frames (%{public}f seconds)", 
                       log: ExportCoordinator.logger, type: .info, numberOfFrames, durationInSeconds)
            }
            
            // Export the frames
            _ = try await frameExporter.exportFrameSequence(
                configuration: frameExporterConfig,
                outputDirectory: configuration.outputURL,
                baseFilename: configuration.baseFilename,
                startTime: startTime,
                endTime: endTime,
                progressHandler: progressHandler
            )
            
            // Return the output directory URL
            return configuration.outputURL
        } catch {
            os_log("Error during image sequence export: %{public}@", 
                   log: ExportCoordinator.logger, type: .error, error.localizedDescription)
            
            // Try to provide more context for common errors
            if error.localizedDescription.contains("Cannot Open") {
                throw NSError(domain: "ExportCoordinator", code: 5, 
                      userInfo: [NSLocalizedDescriptionKey: "Failed to access the output directory. Please check permissions and try again."])
            }
            throw error
        }
    }
    
    /// Export the asset as a video file
    private func exportVideo(
        with configuration: ExportConfiguration,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> URL {
        os_log("Exporting video with ProRes profile: %{public}@", log: ExportCoordinator.logger, type: .info, 
               configuration.proResProfile?.description ?? "Standard MP4")
        
        // Create VideoExporter configuration
        let videoExporterConfig = VideoExporter.ExportConfiguration(
            format: .video,
            width: configuration.width,
            height: configuration.height,
            frameRate: configuration.frameRate,
            proResProfile: configuration.proResProfile,
            includeAudio: configuration.includeAudio,
            outputURL: configuration.outputURL,
            numberOfFrames: configuration.numberOfFrames
        )
        
        // Create VideoExporter
        let videoExporter = VideoExporter(asset: asset)
        
        // Create a continuation to handle async completion
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await videoExporter.export(
                    with: videoExporterConfig,
                    progressHandler: progressHandler
                ) { result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Export the asset as an animated GIF
    private func exportGIF(
        with configuration: ExportConfiguration,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> URL {
        os_log("Exporting GIF animation", log: ExportCoordinator.logger, type: .info)
        
        // Create a temporary directory for the frames
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gifFrames_\(UUID().uuidString)")
        
        // Progress tracking
        let updateProgress: (Float) -> Void = { progress in
            // First 80% is frame export, last 20% is GIF creation
            let adjustedProgress = progress * 0.8
            progressHandler?(adjustedProgress)
        }
        
        // 1. Export frames as PNG images (for higher quality)
        let frameExporterConfig = FrameExporter.Configuration(
            width: configuration.width,
            height: configuration.height,
            frameRate: configuration.frameRate,
            imageFormat: .png
        )
        
        // Create a function to get elements at a specific time
        let getElementsAtTime: (CMTime) -> [CanvasElement] = { time in
            // TODO: Replace with actual canvas elements from project timeline
            return [] // Return empty array for now
        }
        
        // Use the canvas size from configuration
        let canvasSize = CGSize(width: configuration.width, height: configuration.height)
        
        let frameExporter = FrameExporter(
            getElementsAtTime: getElementsAtTime,
            canvasSize: canvasSize
        )
        
        // Calculate endTime if we have numberOfFrames specified
        let startTime = CMTime.zero
        var endTime: CMTime? = nil
        
        if let numberOfFrames = configuration.numberOfFrames, numberOfFrames > 0 {
            // Calculate duration based on number of frames and frame rate
            let durationInSeconds = Double(numberOfFrames) / Double(configuration.frameRate)
            endTime = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
            os_log("Limited GIF export to %{public}d frames (%{public}f seconds)", 
                   log: ExportCoordinator.logger, type: .info, numberOfFrames, durationInSeconds)
        }
        
        // Export the frames
        _ = try await frameExporter.exportFrameSequence(
            configuration: frameExporterConfig,
            outputDirectory: tempDirectory,
            baseFilename: "gif_frame",
            startTime: startTime,
            endTime: endTime,
            progressHandler: updateProgress
        )
        
        // 2. Combine the frames into a GIF
        // TODO: Implement GIF creation logic using the frame images
        // For now, we'll throw an error as a placeholder
        throw NSError(domain: "ExportCoordinator", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "GIF export not fully implemented"])
        
        // Clean up temporary directory
        // try? FileManager.default.removeItem(at: tempDirectory)
        
        // Return the GIF URL
        // return configuration.outputURL
    }
    
    /// Convert an ExportCoordinator.ExportConfiguration to a VideoExporter.ExportConfiguration
    public func createVideoExporterConfiguration(from config: ExportConfiguration) -> VideoExporter.ExportConfiguration {
        return VideoExporter.ExportConfiguration(
            format: config.format,
            width: config.width,
            height: config.height,
            frameRate: config.frameRate,
            proResProfile: config.proResProfile,
            includeAudio: config.includeAudio,
            outputURL: config.outputURL,
            baseFilename: config.baseFilename,
            imageQuality: config.imageQuality,
            numberOfFrames: config.numberOfFrames
        )
    }
} 