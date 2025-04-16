import Foundation
import AVFoundation
import AppKit
import os.log

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
            self.outputURL = outputURL
            self.proResProfile = proResProfile
            self.includeAudio = includeAudio
            self.baseFilename = baseFilename
            self.imageQuality = imageQuality
        }
    }
    
    /// The asset to be exported
    private let asset: AVAsset
    
    /// Initialize with an AVAsset
    public init(asset: AVAsset) {
        self.asset = asset
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
            // Capture fileManager as a local copy to avoid Sendable warning
            let capturedFileManager = fileManager
            
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
                        // Remove existing directory
                        try capturedFileManager.removeItem(at: directoryURL)
                        // Create fresh directory
                        try capturedFileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
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
        var didStartAccessingParent = false
        
        if parentDirectory.startAccessingSecurityScopedResource() {
            didStartAccessingParent = true
            os_log("Successfully accessed parent directory: %{public}@", log: ExportCoordinator.logger, type: .debug, 
                   parentDirectory.path)
        } else {
            os_log("Failed to access parent directory with security-scoped resources: %{public}@", 
                   log: ExportCoordinator.logger, type: .error, parentDirectory.path)
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
            if !FileManager.default.createFile(atPath: testURL.path, contents: Data()) {
                throw NSError(domain: "ExportCoordinator", code: 5,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot write to output directory. Please check permissions."])
            }
            try? FileManager.default.removeItem(at: testURL)
            
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
        let frameExporter = FrameExporter(asset: asset)
        
        do {
            // Export the frames
            _ = try await frameExporter.exportFrameSequence(
                configuration: frameExporterConfig,
                outputDirectory: configuration.outputURL,
                baseFilename: configuration.baseFilename,
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
            outputURL: configuration.outputURL
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
        
        let frameExporter = FrameExporter(asset: asset)
        
        // Export the frames
        _ = try await frameExporter.exportFrameSequence(
            configuration: frameExporterConfig,
            outputDirectory: tempDirectory,
            baseFilename: "gif_frame",
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
            imageQuality: config.imageQuality
        )
    }
} 