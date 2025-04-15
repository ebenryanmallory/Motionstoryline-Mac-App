import Foundation
import SwiftUI

// MARK: - Image Extension for Placeholders
extension Image {
    static func placeholder(for name: String) -> some View {
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
}

public struct MediaAsset: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var type: MediaType
    public var url: URL
    public var duration: TimeInterval?
    public var thumbnail: String?
    public var dateAdded: Date
    
    public enum MediaType: String, Codable {
        case video
        case audio
        case image
        case cameraRecording
    }
    
    public init(id: UUID = UUID(), name: String, type: MediaType, url: URL, 
         duration: TimeInterval? = nil, thumbnail: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.duration = duration
        self.thumbnail = thumbnail
        self.dateAdded = dateAdded
    }
    
    public static func == (lhs: MediaAsset, rhs: MediaAsset) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct Project: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var thumbnail: String
    public var lastModified: Date
    public var mediaAssets: [MediaAsset] = []
    
    // Viewport settings
    public var zoomLevel: CGFloat = 1.0
    public var panOffsetX: CGFloat = 0.0
    public var panOffsetY: CGFloat = 0.0
    
    public init(id: UUID = UUID(), name: String, thumbnail: String, lastModified: Date, 
         mediaAssets: [MediaAsset] = [],
         zoomLevel: CGFloat = 1.0, panOffsetX: CGFloat = 0.0, panOffsetY: CGFloat = 0.0) {
        self.id = id
        self.name = name
        self.thumbnail = thumbnail
        self.lastModified = lastModified
        self.mediaAssets = mediaAssets
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
} 