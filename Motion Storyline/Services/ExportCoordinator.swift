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
        
        /// Duration in seconds (from timeline length)
        public var duration: Double?
        
        /// Number of frames to export (user-specified limit or calculated from duration)
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
            duration: Double? = nil,
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
            self.duration = duration
            self.numberOfFrames = numberOfFrames
            self.outputURL = outputURL
            self.proResProfile = proResProfile
            self.includeAudio = includeAudio
            self.baseFilename = baseFilename
            self.imageQuality = imageQuality
        }
        
        /// Calculate number of frames from duration and frame rate
        public var calculatedFrameCount: Int? {
            guard let duration = duration else { return numberOfFrames }
            return Int(duration * Double(frameRate))
        }
        
        /// Get the effective frame count (user-specified or calculated from duration)
        public var effectiveFrameCount: Int? {
            return numberOfFrames ?? calculatedFrameCount
        }
        
        /// Create export configuration from project with timeline length as default duration
        public static func fromProject(
            _ project: Project,
            format: ExportFormat,
            width: Int,
            height: Int,
            frameRate: Float,
            outputURL: URL,
            proResProfile: VideoExporter.ProResProfile? = nil,
            includeAudio: Bool = true,
            baseFilename: String = "frame",
            imageQuality: CGFloat? = nil
        ) -> ExportConfiguration {
            return ExportConfiguration(
                format: format,
                width: width,
                height: height,
                frameRate: frameRate,
                duration: project.timelineLength,
                numberOfFrames: nil, // Let it calculate from duration
                outputURL: outputURL,
                proResProfile: proResProfile,
                includeAudio: includeAudio,
                baseFilename: baseFilename,
                imageQuality: imageQuality
            )
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
    
    /// Audio layers for export
    private let audioLayers: [AudioLayer]
    
    /// Initialize with an AVAsset
    public init(asset: AVAsset) {
        self.asset = asset
        self.animationController = nil
        self.canvasElements = []
        self.canvasSize = CGSize(width: 1280, height: 720)
        self.audioLayers = []
    }
    
    /// Initialize with animation and canvas data
    init(asset: AVAsset, animationController: AnimationController, canvasElements: [CanvasElement], canvasSize: CGSize, audioLayers: [AudioLayer] = []) {
        self.asset = asset
        self.animationController = animationController
        self.canvasElements = canvasElements
        self.canvasSize = canvasSize
        self.audioLayers = audioLayers
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
            
        case .video, .videoProRes: // Combined .video and .videoProRes
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
            // Placeholder for project file export logic
            // This might involve serializing project data and saving to a file
            os_log("Project file export not yet implemented.", log: ExportCoordinator.logger, type: .default)
            throw NSError(domain: "ExportCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Project file export is not yet implemented."])
        // BatchExport is handled by BatchExportManager, not directly here.
        // If it were to be handled, it would require a different approach.
        default:
            os_log("Unsupported export format: %{public}@", log: ExportCoordinator.logger, type: .error, String(describing: configuration.format))
            throw NSError(domain: "ExportCoordinator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported export format encountered."])
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
            // Log that we're getting elements for a frame at this time
            os_log("Getting elements for frame at time %{public}f", log: ExportCoordinator.logger, type: .debug, time.seconds) // 'time' is the parameter of the closure
            
            guard let self = self else {
                os_log("ExportCoordinator instance is nil, cannot get elements at time.", log: ExportCoordinator.logger, type: .error)
                return []
            }
            
            // Ensure animationController is available
            guard let animationController = self.animationController else {
                 os_log("AnimationController is nil in ExportCoordinator. Cannot apply animations. Returning current elements.", log: ExportCoordinator.logger, type: .error)
                return self.canvasElements 
            }

            // If canvasElements is empty, no need to apply animations
            if self.canvasElements.isEmpty {
                os_log("CanvasElements is empty in ExportCoordinator. Returning empty.", log: ExportCoordinator.logger, type: .info)
                return []
            }
            
            // Call the centralized helper
            return AnimationHelpers.applyAnimations(
                toElements: self.canvasElements, 
                using: animationController,
                at: time.seconds
            )
        }
        
        // Use the actual canvas size, not the export configuration size
        // This ensures coordinate system consistency with the canvas elements
        let frameExporter = FrameExporter(
            getElementsAtTime: getElementsAtTime,
            canvasSize: self.canvasSize  // Use actual canvas size instead of configuration size
        )
        
        do {
            // Calculate endTime if we have frame count specified (from numberOfFrames or duration)
            let startTime = CMTime.zero
            var endTime: CMTime? = nil
            
            if let frameCount = configuration.effectiveFrameCount, frameCount > 0 {
                // Calculate duration based on number of frames and frame rate
                let durationInSeconds = Double(frameCount) / Double(configuration.frameRate)
                endTime = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
                os_log("Limited export to %{public}d frames (%{public}f seconds)", 
                       log: ExportCoordinator.logger, type: .info, frameCount, durationInSeconds)
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
        
        // Check if we have animation data to use canvas rendering
        if let animationController = self.animationController, !self.canvasElements.isEmpty {
            os_log("Using canvas rendering for video export", log: ExportCoordinator.logger, type: .info)
            
            // Use CanvasVideoRenderer for canvas-based export
            let canvasRenderer = CanvasVideoRenderer(animationController: animationController)
            await canvasRenderer.setElements(self.canvasElements)
            
            // Calculate duration based on frame count (from numberOfFrames or duration)
            let duration: Double
            if let frameCount = configuration.effectiveFrameCount, frameCount > 0 {
                duration = Double(frameCount) / Double(configuration.frameRate)
            } else if let configDuration = configuration.duration, configDuration > 0 {
                duration = configDuration
            } else {
                // Use animation controller duration or default to 5 seconds
                duration = animationController.duration > 0 ? animationController.duration : 5.0
            }
            
            // Determine if audio should be included:
            // - includeAudio checkbox must be true
            // - AND we must have at least one audio layer
            let shouldIncludeAudio = configuration.includeAudio && !self.audioLayers.isEmpty
            
            os_log("Audio export decision: includeAudio=%{public}@, audioLayers.count=%{public}d, shouldIncludeAudio=%{public}@", 
                   log: ExportCoordinator.logger, type: .info, 
                   String(configuration.includeAudio), self.audioLayers.count, String(shouldIncludeAudio))
            
            // Create canvas renderer configuration
            let canvasConfig = CanvasVideoRenderer.Configuration(
                width: configuration.width,
                height: configuration.height,
                duration: duration,
                frameRate: configuration.frameRate,
                canvasWidth: self.canvasSize.width,
                canvasHeight: self.canvasSize.height,
                proResProfile: configuration.proResProfile,
                audioLayers: shouldIncludeAudio ? self.audioLayers : nil,
                includeAudio: shouldIncludeAudio
            )
            
            // Render the video using canvas renderer (now handles ProRes directly)
            let renderedAsset = try await canvasRenderer.renderToVideo(
                configuration: canvasConfig,
                progressHandler: progressHandler
            )
            
            // For both H.264 and ProRes, the CanvasVideoRenderer now handles the codec directly
            // We just need to move/copy the file to the final destination if needed
            if configuration.proResProfile != nil {
                os_log("ProRes video rendered directly by CanvasVideoRenderer", log: ExportCoordinator.logger, type: .info)
            } else {
                os_log("H.264 video rendered by CanvasVideoRenderer", log: ExportCoordinator.logger, type: .info)
            }
            
            // Check if we need to move the temporary file to the final location
            // For CanvasVideoRenderer, the asset should be a file-based asset with a URL
            if let urlAsset = renderedAsset as? AVURLAsset {
                let tempURL = urlAsset.url
                // Remove existing file if it exists to handle overwrite
                if FileManager.default.fileExists(atPath: configuration.outputURL.path) {
                    do {
                        try FileManager.default.removeItem(at: configuration.outputURL)
                        os_log("Removed existing file at: %{public}@", log: ExportCoordinator.logger, type: .info, configuration.outputURL.path)
                    } catch {
                        throw NSError(domain: "ExportCoordinator", code: 109, userInfo: [NSLocalizedDescriptionKey: "Failed to remove existing file: \(error.localizedDescription)"])
                    }
                }
                
                // Move the temporary file to the final location
                do {
                    try FileManager.default.moveItem(at: tempURL, to: configuration.outputURL)
                    os_log("Moved rendered video from: %{public}@ to: %{public}@", log: ExportCoordinator.logger, type: .info, tempURL.path, configuration.outputURL.path)
                    return configuration.outputURL
                } catch {
                    throw NSError(domain: "ExportCoordinator", code: 110, userInfo: [NSLocalizedDescriptionKey: "Failed to move rendered video to final location: \(error.localizedDescription)"])
                }
            } else {
                // If no URL is available, return the asset directly
                // This shouldn't normally happen, but we handle it gracefully
                os_log("No URL available from rendered asset, returning configuration URL", log: ExportCoordinator.logger, type: .default)
                return configuration.outputURL
            }
        } else {
            os_log("No animation data available, using traditional VideoExporter", log: ExportCoordinator.logger, type: .info)
            
            // Determine if audio should be included:
            // - includeAudio checkbox must be true
            // - AND we must have at least one audio layer (though traditional VideoExporter may not use audio layers)
            let shouldIncludeAudio = configuration.includeAudio && !self.audioLayers.isEmpty
            
            os_log("Audio export decision for VideoExporter: includeAudio=%{public}@, audioLayers.count=%{public}d, shouldIncludeAudio=%{public}@", 
                   log: ExportCoordinator.logger, type: .info, 
                   String(configuration.includeAudio), self.audioLayers.count, String(shouldIncludeAudio))
            
            // Fallback to traditional VideoExporter (for cases where we have an actual AVAsset)
            // Create VideoExporter configuration
            let videoExporterConfig = VideoExporter.ExportConfiguration(
                format: .video,
                width: configuration.width,
                height: configuration.height,
                frameRate: configuration.frameRate,
                proResProfile: configuration.proResProfile,
                includeAudio: shouldIncludeAudio,
                outputURL: configuration.outputURL,
                numberOfFrames: configuration.effectiveFrameCount
            )
            
            // Create VideoExporter
            let videoExporter = VideoExporter(asset: asset)
            
            // Export directly using async/await
            return try await videoExporter.exportAsync(
                with: videoExporterConfig,
                progressHandler: progressHandler
            )
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
        
        // Calculate endTime if we have frame count specified (from numberOfFrames or duration)
        let startTime = CMTime.zero
        var endTime: CMTime? = nil
        
        if let frameCount = configuration.effectiveFrameCount, frameCount > 0 {
            // Calculate duration based on number of frames and frame rate
            let durationInSeconds = Double(frameCount) / Double(configuration.frameRate)
            endTime = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
            os_log("Limited GIF export to %{public}d frames (%{public}f seconds)", 
                   log: ExportCoordinator.logger, type: .info, frameCount, durationInSeconds)
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
            numberOfFrames: config.effectiveFrameCount
        )
    }
} 