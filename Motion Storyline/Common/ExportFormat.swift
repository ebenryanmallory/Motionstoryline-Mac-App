import Foundation

/// Defines the various export formats available in the application
public enum ExportFormat: Sendable, Hashable {
    /// Video export option (e.g. MP4)
    case video
    
    /// Animated GIF export option
    case gif
    
    /// Sequence of image files export option
    case imageSequence(ImageFormat)
    
    /// Project file export option for later editing
    case projectFile
    
    // Implement Hashable conformance manually since we have associated values
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .video:
            hasher.combine(0)
        case .gif:
            hasher.combine(1)
        case .imageSequence(let format):
            hasher.combine(2)
            hasher.combine(format)
        case .projectFile:
            hasher.combine(3)
        }
    }
    
    public static func == (lhs: ExportFormat, rhs: ExportFormat) -> Bool {
        switch (lhs, rhs) {
        case (.video, .video):
            return true
        case (.gif, .gif):
            return true
        case (.imageSequence(let lhsFormat), .imageSequence(let rhsFormat)):
            return lhsFormat == rhsFormat
        case (.projectFile, .projectFile):
            return true
        default:
            return false
        }
    }
}

/// Image formats supported for image sequence export
public enum ImageFormat: String, Sendable, Hashable {
    case png = "png"
    case jpeg = "jpeg"
    
    var fileExtension: String {
        return self.rawValue
    }
    
    var utType: String {
        switch self {
        case .png:
            return "public.png"
        case .jpeg:
            return "public.jpeg"
        }
    }
    
    var quality: CGFloat {
        switch self {
        case .png:
            return 1.0  // PNG is lossless, so quality is always 1.0
        case .jpeg:
            return 0.9  // Default quality for JPEG
        }
    }
}
