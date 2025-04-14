import Foundation
import AVFoundation

/// Defines preset export configurations for various social media platforms
public enum SocialMediaPlatform: String, CaseIterable, Identifiable {
    case instagram = "Instagram"
    case facebook = "Facebook"
    case twitter = "Twitter"
    case youtube = "YouTube"
    case tiktok = "TikTok"
    case linkedin = "LinkedIn"
    case pinterest = "Pinterest"
    case snapchat = "Snapchat"
    case custom = "Custom"
    
    public var id: String { rawValue }
    
    /// Get a user-friendly description of the platform
    public var displayName: String {
        return rawValue
    }
    
    /// Get a description of recommended formats for this platform
    public var formatDescription: String {
        switch self {
        case .instagram:
            return "MP4, up to 60 seconds for feed, H.264 codec"
        case .facebook:
            return "MP4, H.264 codec, AAC audio"
        case .twitter:
            return "MP4, H.264 codec, under 2:20 in length"
        case .youtube:
            return "MP4, H.264 codec, 16:9 aspect ratio recommended"
        case .tiktok:
            return "MP4, 9:16 portrait with 1080x1920 resolution"
        case .linkedin:
            return "MP4, H.264 codec, under 10 minutes"
        case .pinterest:
            return "MP4, H.264 codec, 2:3 aspect ratio recommended"
        case .snapchat:
            return "MP4, 9:16 vertical format, 10 seconds max"
        case .custom:
            return "Custom format and dimensions"
        }
    }
    
    /// Get the recommended video dimensions for this platform
    public func recommendedDimensions(forAspectRatio aspectRatio: AspectRatio? = nil) -> (width: Int, height: Int) {
        switch self {
        case .instagram:
            if let aspectRatio = aspectRatio {
                switch aspectRatio {
                case .square:
                    return (1080, 1080)  // Square post
                case .portrait:
                    return (1080, 1350)  // Portrait post (4:5)
                case .landscape:
                    return (1080, 608)   // Landscape post (1.91:1)
                case .vertical:
                    return (1080, 1920)  // Stories/Reels (9:16)
                case .custom:
                    return (1080, 1080)  // Default to square if custom
                }
            } else {
                return (1080, 1080)  // Default to square
            }
            
        case .facebook:
            if let aspectRatio = aspectRatio {
                switch aspectRatio {
                case .square:
                    return (1080, 1080)
                case .portrait:
                    return (1080, 1350)
                case .landscape:
                    return (1280, 720)   // 16:9
                case .vertical:
                    return (1080, 1920)  // Stories (9:16)
                case .custom:
                    return (1280, 720)
                }
            } else {
                return (1280, 720)  // Default to landscape
            }
            
        case .twitter:
            return (1280, 720)  // 16:9 recommended
            
        case .youtube:
            if let aspectRatio = aspectRatio {
                switch aspectRatio {
                case .landscape:
                    return (1920, 1080)  // Full HD
                case .vertical:
                    return (1080, 1920)  // Shorts
                default:
                    return (1920, 1080)  // Default to landscape
                }
            } else {
                return (1920, 1080)  // Default to landscape
            }
            
        case .tiktok:
            return (1080, 1920)  // 9:16 vertical
            
        case .linkedin:
            return (1920, 1080)  // 16:9 recommended
            
        case .pinterest:
            return (1000, 1500)  // 2:3 recommended
            
        case .snapchat:
            return (1080, 1920)  // 9:16 vertical
            
        case .custom:
            return (1920, 1080)  // Default HD
        }
    }
    
    /// Get the maximum recommended bitrate in bits per second
    public var recommendedBitrate: Int {
        switch self {
        case .instagram:
            return 5_000_000  // 5 Mbps
        case .facebook:
            return 4_000_000  // 4 Mbps
        case .twitter:
            return 5_000_000  // 5 Mbps
        case .youtube:
            return 8_000_000  // 8 Mbps for 1080p
        case .tiktok:
            return 5_000_000  // 5 Mbps
        case .linkedin:
            return 5_000_000  // 5 Mbps
        case .pinterest:
            return 4_000_000  // 4 Mbps
        case .snapchat:
            return 3_000_000  // 3 Mbps
        case .custom:
            return 8_000_000  // 8 Mbps default
        }
    }
    
    /// Get the recommended frame rate
    public var recommendedFrameRate: Float {
        switch self {
        case .instagram, .facebook, .twitter, .youtube, .tiktok:
            return 30.0
        case .linkedin, .pinterest, .snapchat:
            return 24.0
        case .custom:
            return 30.0
        }
    }
    
    /// Get the recommended export format
    public var recommendedFormat: ExportFormat {
        switch self {
        case .instagram, .facebook, .twitter, .youtube, .tiktok, .linkedin, .pinterest, .snapchat:
            return .video
        case .custom:
            return .video
        }
    }
    
    /// Create an export configuration for this platform
    /// - Parameters:
    ///   - aspectRatio: Optional aspect ratio to use
    ///   - outputURL: The URL where the exported file will be saved
    /// - Returns: A configured ExportConfiguration
    public func createExportConfiguration(
        aspectRatio: AspectRatio? = nil,
        outputURL: URL
    ) -> VideoExporter.ExportConfiguration {
        let dimensions = recommendedDimensions(forAspectRatio: aspectRatio)
        
        return VideoExporter.ExportConfiguration(
            format: recommendedFormat,
            width: dimensions.width,
            height: dimensions.height,
            frameRate: recommendedFrameRate,
            bitrate: recommendedBitrate,
            proResProfile: nil,  // Use standard compressed format for social media
            includeAudio: true,
            outputURL: outputURL
        )
    }
    
    /// Get file name suffix for this platform
    public func fileNameSuffix(aspectRatio: AspectRatio? = nil) -> String {
        var suffix = self.rawValue.lowercased()
        
        if let aspectRatio = aspectRatio, aspectRatio != .custom {
            suffix += "_\(aspectRatio.rawValue.lowercased())"
        }
        
        return suffix
    }
}

/// Common aspect ratios used in video
public enum AspectRatio: String, CaseIterable, Identifiable {
    case square = "Square"          // 1:1
    case portrait = "Portrait"      // 4:5
    case landscape = "Landscape"    // 16:9
    case vertical = "Vertical"      // 9:16
    case custom = "Custom"          // User-defined
    
    public var id: String { rawValue }
    
    /// Get the numeric aspect ratio value (width:height)
    public var ratio: Double {
        switch self {
        case .square:
            return 1.0
        case .portrait:
            return 0.8  // 4:5
        case .landscape:
            return 1.78  // 16:9
        case .vertical:
            return 0.5625  // 9:16
        case .custom:
            return 1.0  // Default
        }
    }
    
    /// Get a display name with dimensions
    public func displayNameWithDimensions(for platform: SocialMediaPlatform) -> String {
        let dimensions = platform.recommendedDimensions(forAspectRatio: self)
        return "\(rawValue) (\(dimensions.width)×\(dimensions.height))"
    }
    
    /// Get a user-friendly description
    public var description: String {
        switch self {
        case .square:
            return "1:1 - Perfect for profile pictures and grid layouts"
        case .portrait:
            return "4:5 - Ideal for mobile feeds on Instagram and Facebook"
        case .landscape:
            return "16:9 - Standard for YouTube and traditional video"
        case .vertical:
            return "9:16 - Optimal for Stories, Reels, TikTok, and Shorts"
        case .custom:
            return "User-defined aspect ratio"
        }
    }
} 