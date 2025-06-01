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
        
        // Calculate timeRange if number of frames is specified
        var timeRange: CMTimeRange?
        if let numberOfFrames = configuration.numberOfFrames, numberOfFrames > 0 {
            // Calculate duration based on number of frames and frame rate
            let durationInSeconds = Double(numberOfFrames) / Double(configuration.frameRate)
            let duration = CMTime(seconds: durationInSeconds, preferredTimescale: 600)
            timeRange = CMTimeRange(start: .zero, duration: duration)
            
            print("Limiting export to \(numberOfFrames) frames (\(durationInSeconds) seconds) at \(configuration.frameRate) fps")
        }
        
        // Continue with export implementation, using timeRange if set
        // For example, when setting up AVAssetExportSession:
        if let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) {
            self.exportSession = exportSession
            
            // Set the calculated timeRange if available
            if let timeRange = timeRange {
                exportSession.timeRange = timeRange
            }
            
            // Continue with the rest of the export implementation...
        }
        
        // The rest of the export implementation would go here
        // For brevity, we're just showing the timeRange-related changes
    }
    
    /// Cancel the export operation
    public func cancelExport() {
        // Implement cancellation logic
    }
} 