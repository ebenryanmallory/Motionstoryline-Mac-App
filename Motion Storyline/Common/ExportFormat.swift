import Foundation

/// Defines the various export formats available in the application
public enum ExportFormat {
    /// Video export option (e.g. MP4)
    case video
    
    /// Animated GIF export option
    case gif
    
    /// Sequence of image files export option
    case imageSequence
    
    /// Project file export option for later editing
    case projectFile
} 