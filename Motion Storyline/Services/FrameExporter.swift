import Foundation
import AVFoundation
import CoreImage
import AppKit
import os.log

/// A service responsible for exporting individual frames from a video asset
@available(macOS 10.15, *)
public class FrameExporter {
    // Logger for debugging
    private static let logger = OSLog(subsystem: "com.app.Motion-Storyline", category: "FrameExporter")
    
    /// Configuration for frame export
    public struct Configuration {
        /// Output resolution width
        public var width: Int
        
        /// Output resolution height
        public var height: Int
        
        /// Frame rate (frames per second)
        public var frameRate: Float
        
        /// Image format to use
        public var imageFormat: ImageFormat
        
        /// For JPEG exports: the compression quality (0.0 to 1.0)
        public var imageQuality: CGFloat?
        
        public init(
            width: Int,
            height: Int,
            frameRate: Float,
            imageFormat: ImageFormat,
            imageQuality: CGFloat? = nil
        ) {
            self.width = width
            self.height = height
            self.frameRate = frameRate
            self.imageFormat = imageFormat
            self.imageQuality = imageFormat == .jpeg ? (imageQuality ?? 0.9) : nil
        }
    }
    
    /// Result of a frame export operation
    public struct ExportResult {
        public let image: CGImage
        public let frameTime: CMTime
        public let frameNumber: Int
    }
    
    // Deprecated: AVAsset/AVAssetImageGenerator logic removed. FrameExporter now renders from canvas state.
    // private let asset: AVAsset
    // public init(asset: AVAsset) { ... }

    /// Initialize with canvas state providers
    /// - Parameters:
    ///   - getElementsAtTime: Closure to provide canvas elements at a given time (timeline position)
    ///   - canvasSize: The size of the canvas to render
    internal init(getElementsAtTime: @escaping (CMTime) -> [CanvasElement], canvasSize: CGSize) {
        self.getElementsAtTime = getElementsAtTime
        self.canvasSize = canvasSize
    }
    private let getElementsAtTime: (CMTime) -> [CanvasElement]
    private let canvasSize: CGSize

    /// Export a single frame by rendering the canvas at the specified time
    /// - Parameters:
    ///   - time: The time point to export
    ///   - configuration: Frame export configuration
    /// - Returns: A CGImage if rendering was successful
    public func exportFrame(at time: CMTime, configuration: Configuration) async throws -> CGImage {
        os_log("Exporting frame at time %{public}f with format %{public}@ (canvas)", log: FrameExporter.logger, type: .debug,
               time.seconds, configuration.imageFormat.rawValue)
        // 1. Get the canvas elements at the given timeline time
        let elements = getElementsAtTime(time)
        // 2. Render the canvas as an image, passing the current timeline time
        guard let cgImage = CanvasRenderer.renderCanvasImage(
            elements: elements,
            size: canvasSize,
            scaleFactor: 1.0,
            currentTime: time.seconds
        ) else {
            throw NSError(domain: "FrameExporter", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to render canvas image at time \(time.seconds)"])
        }
        return cgImage
    }
    
    /// Save a CGImage to disk with the specified format
    /// - Parameters:
    ///   - image: The image to save
    ///   - url: The URL where the image should be saved
    ///   - format: The image format to use
    ///   - quality: The quality setting (for JPEG only)
    public func saveImage(_ image: CGImage, to url: URL, format: ImageFormat, quality: CGFloat? = nil) throws {
        os_log("Saving image to %{public}@ with format %{public}@", log: FrameExporter.logger, type: .debug, 
               url.path, format.rawValue)
        
        // The calling function (exportFrameSequence) should handle security-scoped access
        // for the output directory. We don't need to access the parent here.
        // let directory = url.deletingLastPathComponent()
        // var didStartAccessing = false
        // 
        // if directory.startAccessingSecurityScopedResource() {
        //     didStartAccessing = true
        //     os_log("Successfully accessed directory for saving image: %{public}@", log: FrameExporter.logger, type: .debug,
        //            directory.path)
        // }
        // 
        // // Ensure proper cleanup regardless of outcome
        // defer {
        //     if didStartAccessing {
        //         directory.stopAccessingSecurityScopedResource()
        //     }
        // }
        
        // Create NSImage from CGImage
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        // Create the bitmap representation based on format
        // Use sRGB color space to match video export consistency
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: image.width,
            pixelsHigh: image.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(domain: "FrameExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap representation"])
        }
        
        // Draw image into the bitmap representation
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        nsImage.draw(in: NSRect(x: 0, y: 0, width: image.width, height: image.height))
        NSGraphicsContext.restoreGraphicsState()
        
        // Create the image data based on format
        let imageData: Data?
        switch format {
        case .png:
            imageData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
        case .jpeg:
            let properties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: quality ?? format.quality
            ]
            imageData = bitmapRep.representation(using: NSBitmapImageRep.FileType.jpeg, properties: properties)
        }
        
        // Check if we have valid image data
        guard let imageData = imageData else {
            throw NSError(domain: "FrameExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image data"])
        }
        
        // Create directory if it doesn't exist - This should be handled by the caller (exportFrameSequence)
        // if !FileManager.default.fileExists(atPath: directory.path) {
        //     try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // }
        
        // Extra diagnostics: check if directory is writable
        let directory = url.deletingLastPathComponent()
        let isWritable = FileManager.default.isWritableFile(atPath: directory.path)
        os_log("[DEBUG] saveImage: Directory for image: %{public}@, isWritable: %{public}@", log: FrameExporter.logger, type: .debug, directory.path, String(isWritable))
        if !isWritable {
            os_log("[ERROR] saveImage: Directory is not writable: %{public}@", log: FrameExporter.logger, type: .error, directory.path)
        }
        // Write the data to disk
        do {
            try imageData.write(to: url)
        } catch {
            os_log("[ERROR] Failed to write image data to %{public}@ : %{public}@", log: FrameExporter.logger, type: .error, url.path, error.localizedDescription)
            // Re-throw the error to be handled by the caller
            throw error
        }
        os_log("Successfully saved image to %{public}@", log: FrameExporter.logger, type: .debug, url.path)
    }
    
    /// Export a sequence of frames from the asset
    /// - Parameters:
    ///   - configuration: Frame export configuration
    ///   - outputDirectory: Directory to save frames to
    ///   - baseFilename: Base name for the frame files
    ///   - startTime: Optional start time (defaults to beginning of asset)
    ///   - endTime: Optional end time (defaults to end of asset)
    ///   - progressHandler: Optional callback for export progress
    /// - Returns: Array of exported frame URLs
    public func exportFrameSequence(
        configuration: Configuration,
        outputDirectory: URL,
        baseFilename: String = "frame",
        startTime: CMTime? = nil,
        endTime: CMTime? = nil,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> [URL] {
        os_log("Starting frame sequence export to %{public}@", log: FrameExporter.logger, type: .info, outputDirectory.path)
        
        // Handle security-scoped resources for macOS sandboxed apps
        let parentDirectory = outputDirectory.deletingLastPathComponent()
        var didStartAccessing = false
        os_log("[DEBUG] FrameExporter: Attempting to start security-scoped access on parent directory: %{public}@", log: FrameExporter.logger, type: .debug, parentDirectory.path)
        if parentDirectory.startAccessingSecurityScopedResource() {
            didStartAccessing = true
            os_log("[DEBUG] FrameExporter: Successfully started security-scoped access on parent directory.", log: FrameExporter.logger, type: .debug)
        } else {
            os_log("[DEBUG] FrameExporter: Failed to start security-scoped access on parent directory.", log: FrameExporter.logger, type: .error)
        }
        
        // Ensure proper cleanup of security-scoped resource access regardless of outcome
        defer {
            if didStartAccessing {
                parentDirectory.stopAccessingSecurityScopedResource()
                os_log("[DEBUG] FrameExporter: Stopped security-scoped access on parent directory.", log: FrameExporter.logger, type: .debug)
            }
        }
        
        // Ensure output directory exists and is accessible
        do {
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: outputDirectory.path) {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Check if the directory is writable
            if !FileManager.default.isWritableFile(atPath: outputDirectory.path) {
                throw NSError(domain: "FrameExporter", code: 3, 
                     userInfo: [NSLocalizedDescriptionKey: "Permission denied. You don't have write access to this location."])
            }
            
            // Verify access to the directory by writing a test file
            let testURL = outputDirectory.appendingPathComponent(".test_access")
            if !FileManager.default.createFile(atPath: testURL.path, contents: Data()) {
                throw NSError(domain: "FrameExporter", code: 3,
                     userInfo: [NSLocalizedDescriptionKey: "Failed to write to output directory. Please check permissions."])
            }
            try? FileManager.default.removeItem(at: testURL)
            
        } catch {
            os_log("Directory access error: %{public}@", log: FrameExporter.logger, type: .error, error.localizedDescription)
            
            // Provide more descriptive error messages based on error type
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain {
                switch nsError.code {
                case NSFileWriteNoPermissionError:
                    throw NSError(domain: "FrameExporter", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Permission denied. You don't have write access to this location."])
                case NSFileWriteOutOfSpaceError:
                    throw NSError(domain: "FrameExporter", code: 4, 
                         userInfo: [NSLocalizedDescriptionKey: "Not enough disk space available for export."])
                case NSFileNoSuchFileError:
                    throw NSError(domain: "FrameExporter", code: 5, 
                         userInfo: [NSLocalizedDescriptionKey: "The export directory could not be created."])
                default:
                    throw NSError(domain: "FrameExporter", code: 6, 
                        userInfo: [NSLocalizedDescriptionKey: "Cannot access directory: \(error.localizedDescription)"])
                }
            } else {
                throw NSError(domain: "FrameExporter", code: 7, 
                     userInfo: [NSLocalizedDescriptionKey: "Cannot access export directory: \(error.localizedDescription)"])
            }
        }
        
        // Determine timeline duration (pseudo-code: replace with actual timeline duration provider)
        // let duration = timelineController.duration
        // For now, assume a default duration (e.g., 5 seconds)
        let duration = endTime ?? CMTime(seconds: 5.0, preferredTimescale: 600)
        let actualStartTime = startTime ?? CMTime.zero
        let actualEndTime = endTime ?? duration
        
        // Calculate frame times
        let frameInterval = CMTime(seconds: 1.0 / Double(configuration.frameRate), preferredTimescale: 600)
        var currentTime = actualStartTime
        var frameTimes: [CMTime] = []
        
        while currentTime <= actualEndTime {
            frameTimes.append(currentTime)
            currentTime = CMTimeAdd(currentTime, frameInterval)
        }
        
        os_log("Will export %{public}d frames at %{public}f fps (canvas)", log: FrameExporter.logger, type: .info,
               frameTimes.count, configuration.frameRate)
        
        // Create an array to store frame URLs
        var frameURLs: [URL] = []
        
        // Process each frame
        for (index, time) in frameTimes.enumerated() {
            // Report progress
            let progress = Float(index) / Float(frameTimes.count)
            progressHandler?(progress)
            
            do {
                // Export the frame
                let cgImage = try await exportFrame(at: time, configuration: configuration)
                
                // Create frame filename with padded index
                let paddedIndex = String(format: "%04d", index)
                let filename = "\(baseFilename)_\(paddedIndex).\(configuration.imageFormat.fileExtension)"
                let frameURL = outputDirectory.appendingPathComponent(filename)
                
                // Save the frame
                try saveImage(
                    cgImage, 
                    to: frameURL,
                    format: configuration.imageFormat,
                    quality: configuration.imageQuality
                )
                
                // Add to frame URLs
                frameURLs.append(frameURL)
                
                os_log("Exported frame %{public}d/%{public}d", log: FrameExporter.logger, type: .debug, 
                       index + 1, frameTimes.count)
            } catch {
                os_log("Failed to export frame %{public}d: %{public}@", log: FrameExporter.logger, type: .error, 
                       index, error.localizedDescription)
                
                // Add more context to the error message
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain {
                    switch nsError.code {
                    case NSFileWriteNoPermissionError:
                        throw NSError(domain: "FrameExporter", code: 8, 
                             userInfo: [NSLocalizedDescriptionKey: "Permission denied when writing frames. Check folder permissions."])
                    case NSFileWriteOutOfSpaceError:
                        throw NSError(domain: "FrameExporter", code: 9, 
                             userInfo: [NSLocalizedDescriptionKey: "Ran out of disk space while exporting frames."])
                    default:
                        throw error
                    }
                } else {
                    throw error
                }
            }
        }
        
        // Report completion
        progressHandler?(1.0)
        os_log("Completed frame sequence export: %{public}d frames", log: FrameExporter.logger, type: .info, frameURLs.count)
        
        return frameURLs
    }
} 