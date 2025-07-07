import Foundation
import SwiftUI
import AVFoundation
import AppKit

// MARK: - Image Extension for Placeholders
extension Image {
    static func placeholder(for name: String) -> Image {
        // Create a default image that can be resized
        return Image(systemName: "photo")
    }
}

// MARK: - Placeholder View
struct PlaceholderView: View {
    let name: String
    
    var body: some View {
        let colorMap: [String: Color] = [
            "design_thumbnail": Color.blue,
            "prototype_thumbnail": Color.green,
            "style_thumbnail": Color.red,
            "component_thumbnail": Color.orange,
            "recording_thumbnail": Color.purple,
            "placeholder": Color.gray,
            "video_thumbnail": Color.indigo,
            "animation_thumbnail": Color.pink,
            "presentation_thumbnail": Color.mint
        ]
        
        let color = colorMap[name] ?? Color.gray
        let displayName = name.replacingOccurrences(of: "_thumbnail", with: "")
        
        return ZStack {
            Rectangle()
                .fill(color)
                .aspectRatio(4/3, contentMode: .fit)
            
            Text(displayName.capitalized)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
    
    static func create(for name: String) -> PlaceholderView {
        return PlaceholderView(name: name)
    }
}

public struct MediaAsset: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var type: MediaType
    public var url: URL
    public var duration: TimeInterval?
    public var thumbnail: String?
    public var dateAdded: Date
    public var width: CGFloat?
    public var height: CGFloat?
    
    public enum MediaType: String, Codable {
        case video
        case audio
        case image
        case cameraRecording
    }
    
    public init(id: UUID = UUID(), name: String, type: MediaType, url: URL, 
         duration: TimeInterval? = nil, thumbnail: String? = nil, dateAdded: Date = Date(),
         width: CGFloat? = nil, height: CGFloat? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.duration = duration
        self.thumbnail = thumbnail
        self.dateAdded = dateAdded
        self.width = width
        self.height = height
    }
    
    public static func == (lhs: MediaAsset, rhs: MediaAsset) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Computed property to get dimensions as CGSize
    public var dimensions: CGSize? {
        guard let width = width, let height = height else { return nil }
        return CGSize(width: width, height: height)
    }
}

// MARK: - MediaAsset Dimension Utilities
extension MediaAsset {
    /// Extract dimensions from image or video file
    public static func extractDimensions(from url: URL, type: MediaType) -> CGSize? {
        switch type {
        case .image:
            return extractImageDimensions(from: url)
        case .video, .cameraRecording:
            return extractVideoDimensions(from: url)
        case .audio:
            return nil // Audio files don't have dimensions
        }
    }
    
    private static func extractImageDimensions(from url: URL) -> CGSize? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return image.size
    }
    
    private static func extractVideoDimensions(from url: URL) -> CGSize? {
        let asset = AVAsset(url: url)
        
        // Get video tracks
        let videoTracks = asset.tracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { return nil }
        
        // Get the natural size of the video
        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        
        // Apply transform to get the actual display size
        let videoSize = naturalSize.applying(transform)
        
        // Return absolute values to handle rotations
        return CGSize(width: abs(videoSize.width), height: abs(videoSize.height))
    }
}

public struct Project: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var thumbnail: String
    public var lastModified: Date
    public var mediaAssets: [MediaAsset] = []
    public var audioLayers: [AudioLayer] = [] // Audio tracks in the timeline
    public var isStarred: Bool = false
    
    // Timeline settings
    public var timelineLength: Double = 5.0 // Duration in seconds
    
    // Viewport settings
    public var zoomLevel: CGFloat = 1.0
    public var panOffsetX: CGFloat = 0.0
    public var panOffsetY: CGFloat = 0.0
    
    public init(id: UUID = UUID(), name: String, thumbnail: String, lastModified: Date, 
         mediaAssets: [MediaAsset] = [],
         audioLayers: [AudioLayer] = [],
         isStarred: Bool = false,
         timelineLength: Double = 5.0,
         zoomLevel: CGFloat = 1.0, panOffsetX: CGFloat = 0.0, panOffsetY: CGFloat = 0.0) {
        self.id = id
        self.name = name
        self.thumbnail = thumbnail
        self.lastModified = lastModified
        self.mediaAssets = mediaAssets
        self.audioLayers = audioLayers
        self.isStarred = isStarred
        self.timelineLength = timelineLength
        self.zoomLevel = zoomLevel
        self.panOffsetX = panOffsetX
        self.panOffsetY = panOffsetY
    }
    
    public static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public mutating func addMediaAsset(_ asset: MediaAsset) {
        mediaAssets.append(asset)
        lastModified = Date()
    }
    
    public mutating func addAudioLayer(_ audioLayer: AudioLayer) {
        // Check for duplicate audio at same start time (within 0.1 seconds)
        let hasDuplicate = audioLayers.contains { existingLayer in
            existingLayer.assetURL == audioLayer.assetURL && 
            abs(existingLayer.startTime - audioLayer.startTime) < 0.1
        }
        
        if hasDuplicate {
            print("⚠️ Project: Audio layer already exists at this timeline position. Skipping duplicate.")
            return
        }
        
        audioLayers.append(audioLayer)
        lastModified = Date()
    }
    
    public mutating func removeAudioLayer(withId id: UUID) {
        audioLayers.removeAll { $0.id == id }
        lastModified = Date()
    }
    
    /// Calculate the total number of frames based on timeline length and frame rate
    public func calculateFrameTotal(frameRate: Float) -> Int {
        return Int(timelineLength * Double(frameRate))
    }
    
    /// Update timeline length and mark project as modified
    public mutating func updateTimelineLength(_ newLength: Double) {
        timelineLength = newLength
        lastModified = Date()
    }
} 