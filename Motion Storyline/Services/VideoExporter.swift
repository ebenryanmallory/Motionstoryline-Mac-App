import Foundation
@preconcurrency import AVFoundation
import CoreImage
import AppKit

/// A class responsible for exporting video content with various formats and configurations
@available(macOS 10.15, *)
public class VideoExporter: @unchecked Sendable {
    
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
        
        public var description: String {
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
        
        /// Number of frames to export (user-specified limit)
        public var numberOfFrames: Int?
        
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
            additionalSettings: [String: String]? = nil,
            numberOfFrames: Int? = nil
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
            self.numberOfFrames = numberOfFrames
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
    
    /// Export video with the provided configuration (async version)
    /// - Parameters:
    ///   - configuration: Export settings and options
    ///   - progressHandler: Optional callback for export progress updates
    /// - Returns: URL of the exported file
    /// - Throws: ExportError if the export fails
    public func exportAsync(
        with configuration: ExportConfiguration,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> URL {
        // Store progress handler
        self.progressHandler = progressHandler
        
        // Validate asset first
        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            throw ExportError.invalidAsset
        }
        
        // Check if asset has tracks
        let tracks = try? await asset.loadTracks(withMediaType: .video)
        guard let tracks = tracks, !tracks.isEmpty else {
            throw ExportError.invalidAsset
        }
        
        // Calculate timeRange if number of frames is specified
        var timeRange: CMTimeRange?
        if let numberOfFrames = configuration.numberOfFrames, numberOfFrames > 0 {
            // Calculate duration based on number of frames and frame rate
            let durationInSeconds = Double(numberOfFrames) / Double(configuration.frameRate)
            let duration = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
            timeRange = CMTimeRange(start: .zero, duration: duration)
            
            print("Limiting export to \(numberOfFrames) frames (\(durationInSeconds) seconds) at \(configuration.frameRate) fps")
        }
        
        // Create export session
        guard var exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.exportSessionSetupFailed
        }
        
        self.exportSession = exportSession
        
        // Set the calculated timeRange if available
        if let timeRange = timeRange {
            exportSession.timeRange = timeRange
        }
        
        // Configure export session based on format and settings
        exportSession.outputURL = configuration.outputURL
        
        // Set output file type and codec based on configuration
        if let proResProfile = configuration.proResProfile {
            // Use ProRes codec
            exportSession.outputFileType = .mov
            
            // Create video settings for ProRes
            let _: [String: Any] = [
                AVVideoCodecKey: proResProfile.avCodecKey,
                AVVideoWidthKey: configuration.width,
                AVVideoHeightKey: configuration.height
            ]
            
            // Note: AVAssetExportSession doesn't directly support custom video settings
            // For ProRes, we rely on the preset and file type
            exportSession.outputFileType = .mov
        } else {
            // Use standard MP4 format
            exportSession.outputFileType = .mp4
        }
        
        // Set up progress monitoring
        if let progressHandler = progressHandler {
            startProgressMonitoring(progressHandler: progressHandler)
        }
        
        // Handle audio inclusion/exclusion
        print("=== VIDEOEXPORTER AUDIO CONFIGURATION ===")
        print("Include audio setting: \(configuration.includeAudio)")
        
        // Check what tracks are available in the original asset
        let originalVideoTracks = try? await asset.loadTracks(withMediaType: .video)
        let originalAudioTracks = try? await asset.loadTracks(withMediaType: .audio)
        
        print("Original asset has \(originalVideoTracks?.count ?? 0) video tracks")
        print("Original asset has \(originalAudioTracks?.count ?? 0) audio tracks")
        
        if !configuration.includeAudio {
            print("EXCLUDING AUDIO from export")
            // Filter out audio tracks when includeAudio is false
            let videoTracks = try? await asset.loadTracks(withMediaType: .video)
            if let videoTracks = videoTracks, !videoTracks.isEmpty {
                // Create a mutable composition with only video tracks
                let composition = AVMutableComposition()
                let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                // Add video tracks to the composition
                for track in videoTracks {
                    try? videoCompositionTrack?.insertTimeRange(
                        timeRange ?? CMTimeRange(start: .zero, duration: asset.duration),
                        of: track,
                        at: .zero
                    )
                }
                
                // Create a new export session with the audio-free composition
                if let audioFreeExportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
                    self.exportSession = audioFreeExportSession
                    audioFreeExportSession.outputURL = configuration.outputURL
                    audioFreeExportSession.outputFileType = exportSession.outputFileType
                    
                    // Set the calculated timeRange if available
                    if let timeRange = timeRange {
                        audioFreeExportSession.timeRange = timeRange
                    }
                    
                    // Update the export session reference
                    exportSession = audioFreeExportSession
                    print("Created audio-free export session")
                } else {
                    print("Warning: Could not create audio-free export session, proceeding with original")
                }
            }
        } else {
            print("INCLUDING AUDIO in export")
            if let audioTracks = originalAudioTracks, !audioTracks.isEmpty {
                print("Audio tracks available for export: \(audioTracks.count)")
                for (index, track) in audioTracks.enumerated() {
                    print("  Audio track \(index): enabled=\(track.isEnabled), playable=\(track.isPlayable)")
                }
            } else {
                print("WARNING: No audio tracks found in asset, even though includeAudio is true")
            }
        }
        
        print("=== END VIDEOEXPORTER AUDIO CONFIGURATION ===")
        
        // Remove existing file if it exists to handle overwrite
        if FileManager.default.fileExists(atPath: configuration.outputURL.path) {
            do {
                try FileManager.default.removeItem(at: configuration.outputURL)
                print("Removed existing file at: \(configuration.outputURL.path)")
            } catch {
                throw ExportError.exportFailed(error)
            }
        }
        
        // Perform the export using withCheckedContinuation for async/await compatibility
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            exportSession.exportAsynchronously {
                // Stop progress monitoring
                self.stopProgressMonitoring()
                
                // Ensure completion handlers are called on main thread
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        guard let outputURL = exportSession.outputURL else {
                            continuation.resume(throwing: ExportError.fileCreationFailed)
                            return
                        }
                        continuation.resume(returning: outputURL)
                        
                    case .failed:
                        let error = exportSession.error ?? NSError(domain: "VideoExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"])
                        continuation.resume(throwing: ExportError.exportFailed(error))
                        
                    case .cancelled:
                        continuation.resume(throwing: ExportError.cancelled)
                        
                    default:
                        let error = NSError(domain: "VideoExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export resulted in unexpected status: \(exportSession.status.rawValue)"])
                        continuation.resume(throwing: ExportError.exportFailed(error))
                    }
                }
            }
        }
    }
    
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
        // Store handlers
        self.progressHandler = progressHandler
        self.completionHandler = completion
        
        // Validate asset first
        do {
            let isReadable = try await asset.load(.isReadable)
            guard isReadable else {
                await MainActor.run {
                    completion(.failure(.invalidAsset))
                }
                return
            }
        } catch {
            await MainActor.run {
                completion(.failure(.invalidAsset))
            }
            return
        }
        
        // Check if asset has tracks
        let tracks = try? await asset.loadTracks(withMediaType: .video)
        guard let tracks = tracks, !tracks.isEmpty else {
            await MainActor.run {
                completion(.failure(.invalidAsset))
            }
            return
        }
        
        // Calculate timeRange if number of frames is specified
        var timeRange: CMTimeRange?
        if let numberOfFrames = configuration.numberOfFrames, numberOfFrames > 0 {
            // Calculate duration based on number of frames and frame rate
            let durationInSeconds = Double(numberOfFrames) / Double(configuration.frameRate)
            let duration = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
            timeRange = CMTimeRange(start: .zero, duration: duration)
            
            print("Limiting export to \(numberOfFrames) frames (\(durationInSeconds) seconds) at \(configuration.frameRate) fps")
        }
        
        // Create export session
        guard var exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            await MainActor.run {
                completion(.failure(.exportSessionSetupFailed))
            }
            return
        }
        
        self.exportSession = exportSession
        
        // Set the calculated timeRange if available
        if let timeRange = timeRange {
            exportSession.timeRange = timeRange
        }
        
        // Configure export session based on format and settings
        exportSession.outputURL = configuration.outputURL
        
        // Set output file type and codec based on configuration
        if let proResProfile = configuration.proResProfile {
            // Use ProRes codec
            exportSession.outputFileType = .mov
            
            // Create video settings for ProRes
            let _: [String: Any] = [
                AVVideoCodecKey: proResProfile.avCodecKey,
                AVVideoWidthKey: configuration.width,
                AVVideoHeightKey: configuration.height
            ]
            
            // Note: AVAssetExportSession doesn't directly support custom video settings
            // For ProRes, we rely on the preset and file type
            exportSession.outputFileType = .mov
        } else {
            // Use standard MP4 format
            exportSession.outputFileType = .mp4
        }
        
        // Set up progress monitoring
        if let progressHandler = progressHandler {
            startProgressMonitoring(progressHandler: progressHandler)
        }
        
        // Handle audio inclusion/exclusion
        print("=== VIDEOEXPORTER AUDIO CONFIGURATION ===")
        print("Include audio setting: \(configuration.includeAudio)")
        
        // Check what tracks are available in the original asset
        let originalVideoTracks = try? await asset.loadTracks(withMediaType: .video)
        let originalAudioTracks = try? await asset.loadTracks(withMediaType: .audio)
        
        print("Original asset has \(originalVideoTracks?.count ?? 0) video tracks")
        print("Original asset has \(originalAudioTracks?.count ?? 0) audio tracks")
        
        if !configuration.includeAudio {
            print("EXCLUDING AUDIO from export")
            // Filter out audio tracks when includeAudio is false
            let videoTracks = try? await asset.loadTracks(withMediaType: .video)
            if let videoTracks = videoTracks, !videoTracks.isEmpty {
                // Create a mutable composition with only video tracks
                let composition = AVMutableComposition()
                let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                // Add video tracks to the composition
                for track in videoTracks {
                    try? videoCompositionTrack?.insertTimeRange(
                        timeRange ?? CMTimeRange(start: .zero, duration: asset.duration),
                        of: track,
                        at: .zero
                    )
                }
                
                // Create a new export session with the audio-free composition
                if let audioFreeExportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
                    self.exportSession = audioFreeExportSession
                    audioFreeExportSession.outputURL = configuration.outputURL
                    audioFreeExportSession.outputFileType = exportSession.outputFileType
                    
                    // Set the calculated timeRange if available
                    if let timeRange = timeRange {
                        audioFreeExportSession.timeRange = timeRange
                    }
                    
                    // Update the export session reference
                    exportSession = audioFreeExportSession
                    print("Created audio-free export session")
                } else {
                    print("Warning: Could not create audio-free export session, proceeding with original")
                }
            }
        } else {
            print("INCLUDING AUDIO in export")
            if let audioTracks = originalAudioTracks, !audioTracks.isEmpty {
                print("Audio tracks available for export: \(audioTracks.count)")
                for (index, track) in audioTracks.enumerated() {
                    print("  Audio track \(index): enabled=\(track.isEnabled), playable=\(track.isPlayable)")
                }
            } else {
                print("WARNING: No audio tracks found in asset, even though includeAudio is true")
            }
        }
        
        print("=== END VIDEOEXPORTER AUDIO CONFIGURATION ===")
        
        // Remove existing file if it exists to handle overwrite
        if FileManager.default.fileExists(atPath: configuration.outputURL.path) {
            do {
                try FileManager.default.removeItem(at: configuration.outputURL)
                print("Removed existing file at: \(configuration.outputURL.path)")
            } catch {
                await MainActor.run {
                    completion(.failure(.exportFailed(error)))
                }
                return
            }
        }
        
        // Perform the export using withCheckedContinuation for async/await compatibility
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                exportSession.exportAsynchronously {
                    // Stop progress monitoring
                    self.stopProgressMonitoring()
                    
                    // Ensure completion handlers are called on main thread
                    DispatchQueue.main.async {
                        switch exportSession.status {
                        case .completed:
                            guard let outputURL = exportSession.outputURL else {
                                let error = ExportError.fileCreationFailed
                                completion(.failure(error))
                                continuation.resume(throwing: error)
                                return
                            }
                            completion(.success(outputURL))
                            continuation.resume(returning: ())
                            
                        case .failed:
                            let error = exportSession.error ?? NSError(domain: "VideoExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"])
                            let exportError = ExportError.exportFailed(error)
                            completion(.failure(exportError))
                            continuation.resume(throwing: exportError)
                            
                        case .cancelled:
                            let error = ExportError.cancelled
                            completion(.failure(error))
                            continuation.resume(throwing: error)
                            
                        default:
                            let error = NSError(domain: "VideoExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export resulted in unexpected status: \(exportSession.status.rawValue)"])
                            let exportError = ExportError.exportFailed(error)
                            completion(.failure(exportError))
                            continuation.resume(throwing: exportError)
                        }
                    }
                }
            }
        } catch {
            // Handle any errors that occurred during the continuation
            await MainActor.run {
                if let exportError = error as? ExportError {
                    completion(.failure(exportError))
                } else {
                    completion(.failure(.exportFailed(error)))
                }
            }
        }
    }
    
    /// Cancel the export operation
    public func cancelExport() {
        exportSession?.cancelExport()
        stopProgressMonitoring()
        completionHandler?(.failure(.cancelled))
    }
    
    // MARK: - Private Methods
    
    /// Start monitoring export progress
    private func startProgressMonitoring(progressHandler: @escaping (Float) -> Void) {
        // Ensure timer runs on main thread to avoid UI issues
        DispatchQueue.main.async { [weak self] in
            self?.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let exportSession = self.exportSession else { return }
                
                let progress = exportSession.progress
                // Ensure progress handler is called on main thread
                DispatchQueue.main.async {
                    progressHandler(progress)
                }
            }
        }
    }
    
    /// Stop monitoring export progress
    private func stopProgressMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.progressTimer?.invalidate()
            self?.progressTimer = nil
        }
    }
} 