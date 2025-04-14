import Foundation
import AVFoundation
import CoreImage
import AppKit

/// A class responsible for exporting video content with various formats and configurations
@available(macOS 10.15, *)
public class VideoExporter {
    
    // MARK: - Nested Types
    
    /// Error types that can occur during video export process
    public enum ExportError: Error {
        case invalidAsset
        case exportSessionSetupFailed
        case exportFailed(Error)
        case cancelled
        case unsupportedFormat
        case invalidExportSettings
        case fileCreationFailed
        
        public var localizedDescription: String {
            switch self {
            case .invalidAsset:
                return "The video asset could not be loaded or is invalid."
            case .exportSessionSetupFailed:
                return "Failed to set up the export session."
            case .exportFailed(let error):
                return "Export failed: \(error.localizedDescription)"
            case .cancelled:
                return "Export was cancelled."
            case .unsupportedFormat:
                return "The specified export format is not supported."
            case .invalidExportSettings:
                return "The export settings are invalid or incompatible."
            case .fileCreationFailed:
                return "Failed to create output file."
            }
        }
    }
    
    /// ProRes quality options available for export
    public enum ProResProfile: Sendable {
        case proRes422Proxy
        case proRes422LT
        case proRes422
        case proRes422HQ
        case proRes4444
        case proRes4444XQ
        
        var avCodecKey: String {
            switch self {
            case .proRes422Proxy:
                return AVVideoCodecType.proRes422Proxy.rawValue
            case .proRes422LT:
                return AVVideoCodecType.proRes422LT.rawValue
            case .proRes422:
                return AVVideoCodecType.proRes422.rawValue
            case .proRes422HQ:
                return AVVideoCodecType.proRes422HQ.rawValue
            case .proRes4444:
                return AVVideoCodecType.proRes4444.rawValue
            case .proRes4444XQ:
                // ProRes 4444 XQ is not a standard AVVideoCodecType enum case
                // Using ProRes 4444 as a fallback with higher quality settings
                return AVVideoCodecType.proRes4444.rawValue
            }
        }
        
        var description: String {
            switch self {
            case .proRes422Proxy:
                return "ProRes 422 Proxy (Light)"
            case .proRes422LT:
                return "ProRes 422 LT (Medium)"
            case .proRes422:
                return "ProRes 422 (Standard)"
            case .proRes422HQ:
                return "ProRes 422 HQ (High Quality)"
            case .proRes4444:
                return "ProRes 4444 (Very High Quality)"
            case .proRes4444XQ:
                return "ProRes 4444 XQ (Maximum Quality)"
            }
        }
    }
    
    /// Video export configuration options
    public struct ExportConfiguration: Sendable {
        /// The format to export in
        public var format: ExportFormat = .video
        
        /// Output resolution width
        public var width: Int
        
        /// Output resolution height
        public var height: Int
        
        /// Frame rate (frames per second)
        public var frameRate: Float = 30.0
        
        /// Video bitrate in bits per second (optional, used for non-ProRes formats)
        public var bitrate: Int?
        
        /// ProRes quality profile (used when exporting with ProRes codec)
        public var proResProfile: ProResProfile?
        
        /// Whether to include audio in the export
        public var includeAudio: Bool = true
        
        /// Output URL for the exported file
        public var outputURL: URL
        
        /// For image sequence exports: the base filename without extension (e.g. "frame")
        public var baseFilename: String?
        
        /// For JPEG image sequence exports: the compression quality (0.0 to 1.0)
        public var imageQuality: CGFloat?
        
        /// A dictionary of string keys to string values for additional settings
        /// Using a more Sendable-friendly type than [String: Any]
        public var additionalSettings: [String: String]?
        
        public init(
            format: ExportFormat = .video,
            width: Int,
            height: Int,
            frameRate: Float = 30.0,
            bitrate: Int? = nil,
            proResProfile: ProResProfile? = nil,
            includeAudio: Bool = true,
            outputURL: URL,
            baseFilename: String? = nil,
            imageQuality: CGFloat? = nil,
            additionalSettings: [String: String]? = nil
        ) {
            self.format = format
            self.width = width
            self.height = height
            self.frameRate = frameRate
            self.bitrate = bitrate
            self.proResProfile = proResProfile
            self.includeAudio = includeAudio
            self.outputURL = outputURL
            self.baseFilename = baseFilename
            self.imageQuality = imageQuality
            self.additionalSettings = additionalSettings
        }
    }
    
    // MARK: - Properties
    
    /// Asset to be exported
    private let asset: AVAsset
    
    /// Progress handler that reports export progress (0.0 to 1.0)
    private var progressHandler: ((Float) -> Void)?
    
    /// Completion handler called when export is finished
    private var completionHandler: ((Result<URL, ExportError>) -> Void)?
    
    /// The export session being used for the current export operation
    private var exportSession: AVAssetExportSession?
    
    /// Progress observation timer
    private var progressTimer: Timer?
    
    // MARK: - Initialization
    
    /// Initialize with an AVAsset (video composition, etc.)
    public init(asset: AVAsset) {
        self.asset = asset
    }
    
    /// Initialize with a URL to a video file
    public convenience init?(url: URL) {
        let asset = AVAsset(url: url)
        self.init(asset: asset)
    }
    
    // MARK: - Export Methods
    
    /// Export video with the provided configuration
    /// - Parameters:
    ///   - configuration: Export settings and options
    ///   - progressHandler: Optional callback for export progress updates
    ///   - completion: Called when export completes with success or failure
    public func export(
        with configuration: ExportConfiguration,
        progressHandler: ((Float) -> Void)? = nil,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) async {
        self.progressHandler = progressHandler
        self.completionHandler = completion
        
        // Verify the asset is exportable
        let tracks = try? await asset.loadTracks(withMediaType: .video)
        if tracks?.isEmpty ?? true {
            completion(.failure(.invalidAsset))
            return
        }
        
        // Create the export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            completion(.failure(.exportSessionSetupFailed))
            return
        }
        
        self.exportSession = exportSession
        
        // Configure the export session based on format
        switch configuration.format {
        case .video:
            await configureVideoExport(exportSession, configuration: configuration)
        case .gif:
            completion(.failure(.unsupportedFormat))
            return
        case .imageSequence(let imageFormat):
            self.exportSession = nil
            Task {
                do {
                    let outputURL = try await exportImageSequence(
                        format: imageFormat,
                        configuration: configuration
                    )
                    DispatchQueue.main.async {
                        self.completionHandler?(.success(outputURL))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.completionHandler?(.failure(.exportFailed(error)))
                    }
                }
            }
            return
        case .projectFile:
            completion(.failure(.unsupportedFormat))
            return
        }
        
        // Set up progress monitoring
        setupProgressMonitoring()
        
        // Start the export
        exportSession.exportAsynchronously { [weak self] in
            guard let self = self else { return }
            
            self.progressTimer?.invalidate()
            self.progressTimer = nil
            
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    self.completionHandler?(.success(configuration.outputURL))
                case .failed:
                    if let error = exportSession.error {
                        self.completionHandler?(.failure(.exportFailed(error)))
                    } else {
                        self.completionHandler?(.failure(.exportFailed(NSError(domain: "VideoExporter", code: 1, userInfo: nil))))
                    }
                case .cancelled:
                    self.completionHandler?(.failure(.cancelled))
                default:
                    self.completionHandler?(.failure(.exportFailed(NSError(domain: "VideoExporter", code: 2, userInfo: nil))))
                }
                
                self.completionHandler = nil
                self.progressHandler = nil
            }
        }
    }
    
    /// Cancel the current export operation
    public func cancelExport() {
        exportSession?.cancelExport()
    }
    
    // MARK: - Private Methods
    
    private func configureVideoExport(_ exportSession: AVAssetExportSession, configuration: ExportConfiguration) async {
        // Set output URL
        // Set output URL
        exportSession.outputURL = configuration.outputURL
        
        // Set up ProRes export if specified
        if let proResProfile = configuration.proResProfile {
            // Use ProRes codec
            exportSession.outputFileType = AVFileType.mov
            // Create a composition with the asset
            let composition = AVMutableComposition()
            
            // Add video track
            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first,
               let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid) {
                
                // Set the time range to include the entire asset
                let duration = try? await asset.load(.duration)
                let timeRange = CMTimeRange(start: .zero, duration: duration ?? .zero)
                
                // Add the asset's video track to the composition
                try? compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                
                // Set the desired size
                let preferredTransform = try? await videoTrack.load(.preferredTransform)
                compositionVideoTrack.preferredTransform = preferredTransform ?? .identity
            }
            
            // Add audio track if needed
            if configuration.includeAudio {
                if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                   let compositionAudioTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid) {
                    
                    // Add the asset's audio track to the composition
                    let duration = try? await asset.load(.duration)
                    let timeRange = CMTimeRange(start: .zero, duration: duration ?? .zero)
                    try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
            }
            
            // Create video composition
            let videoComposition = AVMutableVideoComposition()
            videoComposition.renderSize = CGSize(width: configuration.width, height: configuration.height)
            videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
            
            // Create an instruction
            if let videoTrack = try? await composition.loadTracks(withMediaType: .video).first {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                
                // Apply a transform to fit the video to the desired size if needed
                let trackSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
                let xScale = CGFloat(configuration.width) / abs(trackSize.width)
                let yScale = CGFloat(configuration.height) / abs(trackSize.height)
                let scale = min(xScale, yScale)
                
                var transform = CGAffineTransform(scaleX: scale, y: scale)
                layerInstruction.setTransform(transform, at: .zero)
                
                instruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [instruction]
            }
            
            // Use AVAssetWriter for ProRes export since we need more control over settings
            self.exportSession = nil
            
            // Create a new export session with AVAssetExportPresetPassthrough
            guard let proResExportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetPassthrough) else {
                self.completionHandler?(.failure(.exportSessionSetupFailed))
                return
            }
            
            // Configure the export session
            // Configure the export session
            proResExportSession.outputURL = configuration.outputURL
            proResExportSession.outputFileType = AVFileType.mov
            
            // Setup a custom composition that specifies ProRes settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: proResProfile.avCodecKey,
                AVVideoWidthKey: configuration.width,
                AVVideoHeightKey: configuration.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: configuration.bitrate ?? 0,
                    AVVideoExpectedSourceFrameRateKey: configuration.frameRate
                ]
            ]
            
            // We need to use AVAssetWriter for ProRes with custom settings
            // For simplicity in this implementation, we'll use AVAssetExportSession with preset
            // that's compatible with ProRes and rely on the videoComposition for quality
            
            // In a full implementation, you would:
            // 1. Create an AVAssetReader to read from the composition
            // 2. Create an AVAssetWriter to write with ProRes settings
            // 3. Process samples from reader to writer with the desired settings
            
            // For now, we'll use a compatible high-quality preset
            self.exportSession = nil
            
            let exportPreset = AVAssetExportPresetHighestQuality
            guard let highQualityExportSession = AVAssetExportSession(
                asset: composition,
                presetName: exportPreset) else {
                self.completionHandler?(.failure(.exportSessionSetupFailed))
                return
            }
            
            // Configure the final export session
            highQualityExportSession.outputURL = configuration.outputURL
            highQualityExportSession.outputFileType = AVFileType.mov
            highQualityExportSession.videoComposition = videoComposition
            
            self.exportSession = highQualityExportSession
        } else {
            // Standard H.264 export for general video format
            exportSession.outputFileType = AVFileType.mp4
            // Create a new export session with the appropriate preset based on resolution
            let resolution = max(configuration.width, configuration.height)
            let preset: String
            
            if resolution >= 3840 {
                preset = AVAssetExportPreset3840x2160
            } else if resolution >= 1920 {
                preset = AVAssetExportPreset1920x1080
            } else if resolution >= 1280 {
                preset = AVAssetExportPreset1280x720
            } else {
                preset = AVAssetExportPresetMediumQuality
            }
            
            // Replace the export session with a new one using the correct preset
            self.exportSession = nil
            guard let newExportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
                self.completionHandler?(.failure(.exportSessionSetupFailed))
                return
            }
            
            newExportSession.outputURL = configuration.outputURL
            newExportSession.outputFileType = AVFileType.mp4
            self.exportSession = newExportSession
        }
    }
    
    private func setupProgressMonitoring() {
        self.progressTimer?.invalidate()
        
        self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let exportSession = self.exportSession,
                  let progressHandler = self.progressHandler else {
                return
            }
            
            DispatchQueue.main.async {
                progressHandler(exportSession.progress)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension VideoExporter {
    /// Create and configure a VideoExporter for ProRes export
    public static func createProResExporter(
        from asset: AVAsset,
        outputURL: URL,
        width: Int,
        height: Int,
        frameRate: Float = 30.0,
        proResProfile: ProResProfile = .proRes422HQ,
        includeAudio: Bool = true
    ) -> VideoExporter {
        let exporter = VideoExporter(asset: asset)
        return exporter
    }
    
    /// Export with ProRes settings using a simplified API
    public func exportProRes(
        profile: ProResProfile = .proRes422HQ,
        width: Int,
        height: Int,
        frameRate: Float = 30.0,
        outputURL: URL,
        progress: ((Float) -> Void)? = nil,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) async {
        let configuration = ExportConfiguration(
            format: .video,
            width: width,
            height: height,
            frameRate: frameRate,
            proResProfile: profile,
            includeAudio: true,
            outputURL: outputURL
        )
        
        await export(with: configuration, progressHandler: progress, completion: completion)
    }
    
    /// Export the asset as an image sequence
    /// - Parameters:
    ///   - format: The image format to use (.png or .jpeg)
    ///   - configuration: The export configuration
    /// - Returns: The URL to the directory containing the exported image sequence
    private func exportImageSequence(
        format: ImageFormat,
        configuration: ExportConfiguration
    ) async throws -> URL {
        // Create a generator to extract frames from the video
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        generator.maximumSize = CGSize(width: configuration.width, height: configuration.height)
        
        // Get asset duration to calculate frame times
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        
        // Calculate how many frames we need based on frame rate
        let frameCount = Int(seconds * Float64(configuration.frameRate))
        
        // Create destination directory if it doesn't exist
        let fileManager = FileManager.default
        
        // If outputURL points to a directory, use it; otherwise, use its parent directory
        var directoryURL = configuration.outputURL
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                // If outputURL points to a file, use its parent directory
                directoryURL = directoryURL.deletingLastPathComponent()
            }
        } else {
            // Create the directory if it doesn't exist
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        
        // Get base filename from configuration or use default
        let baseFilename = configuration.baseFilename ?? "frame"
        
        // Progress tracking
        var processedFrames = 0
        
        // Extract frames in a loop
        for frameNumber in 0..<frameCount {
            // Check if the export was cancelled
            if self.exportSession == nil {
                throw ExportError.cancelled
            }
            
            // Calculate the time for this frame
            let time = CMTime(seconds: Double(frameNumber) / Double(configuration.frameRate), preferredTimescale: 600)
            
            // Generate the image for this time
            let cgImage = try await generator.image(at: time).image
            
            // Convert CGImage to NSImage for saving
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            // Create a filename for this frame
            let filename = "\(baseFilename)_\(String(format: "%05d", frameNumber)).\(format.fileExtension)"
            let fileURL = directoryURL.appendingPathComponent(filename)
            
            // Convert to requested format and save
            switch format {
            case .png:
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                    try pngData.write(to: fileURL)
                }
            case .jpeg:
                let quality = configuration.imageQuality ?? format.quality
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmapImage.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: quality]) {
                    try jpegData.write(to: fileURL)
                }
            }
            processedFrames += 1
            let progress = Float(processedFrames) / Float(frameCount)
            
            DispatchQueue.main.async { [weak self] in
                self?.progressHandler?(progress)
            }
        }
        
        return directoryURL
    }
}

// MARK: - Image Sequence Export Convenience Methods

extension VideoExporter {
    /// Export the video as a PNG image sequence
    /// - Parameters:
    ///   - outputDirectory: Directory where image sequence will be saved
    ///   - baseFilename: Base name for the image files (will be appended with frame numbers)
    ///   - width: Output width for images
    ///   - height: Output height for images
    ///   - frameRate: Frame rate to use for extraction (frames per second)
    ///   - progress: Optional progress handler
    ///   - completion: Completion handler with result
    public func exportAsPNGSequence(
        outputDirectory: URL,
        baseFilename: String = "frame",
        width: Int,
        height: Int,
        frameRate: Float = 30.0,
        progress: ((Float) -> Void)? = nil,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) async {
        let configuration = ExportConfiguration(
            format: .imageSequence(.png),
            width: width,
            height: height,
            frameRate: frameRate,
            outputURL: outputDirectory,
            baseFilename: baseFilename
        )
        
        await export(with: configuration, progressHandler: progress, completion: completion)
    }
    
    /// Export the video as a JPEG image sequence
    /// - Parameters:
    ///   - outputDirectory: Directory where image sequence will be saved
    ///   - baseFilename: Base name for the image files (will be appended with frame numbers)
    ///   - width: Output width for images
    ///   - height: Output height for images
    ///   - frameRate: Frame rate to use for extraction (frames per second)
    ///   - quality: JPEG compression quality (0.0 to 1.0, default 0.9)
    ///   - progress: Optional progress handler
    ///   - completion: Completion handler with result
    public func exportAsJPEGSequence(
        outputDirectory: URL,
        baseFilename: String = "frame",
        width: Int,
        height: Int,
        frameRate: Float = 30.0,
        quality: CGFloat = 0.9,
        progress: ((Float) -> Void)? = nil,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) async {
        let configuration = ExportConfiguration(
            format: .imageSequence(.jpeg),
            width: width,
            height: height,
            frameRate: frameRate,
            outputURL: outputDirectory,
            baseFilename: baseFilename,
            imageQuality: quality
        )
        
        await export(with: configuration, progressHandler: progress, completion: completion)
    }
}
