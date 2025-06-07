import SwiftUI
import AVFoundation

/// Represents an audio layer in the animation timeline
public struct AudioLayer: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var assetURL: URL
    public var startTime: TimeInterval // When the audio starts playing in the timeline
    public var duration: TimeInterval
    public var volume: Double
    public var isMuted: Bool
    public var isVisible: Bool // Whether to show in timeline
    public var waveformColor: Color
    
    public init(
        id: UUID = UUID(),
        name: String,
        assetURL: URL,
        startTime: TimeInterval = 0.0,
        duration: TimeInterval,
        volume: Double = 1.0,
        isMuted: Bool = false,
        isVisible: Bool = true,
        waveformColor: Color = .blue
    ) {
        self.id = id
        self.name = name
        self.assetURL = assetURL
        self.startTime = startTime
        self.duration = duration
        self.volume = volume
        self.isMuted = isMuted
        self.isVisible = isVisible
        self.waveformColor = waveformColor
    }
    
    /// Create an AudioLayer from a MediaAsset
    public static func from(mediaAsset: MediaAsset, startTime: TimeInterval = 0.0) -> AudioLayer? {
        guard mediaAsset.type == .audio else { return nil }
        
        return AudioLayer(
            name: mediaAsset.name,
            assetURL: mediaAsset.url,
            startTime: startTime,
            duration: mediaAsset.duration ?? 0.0
        )
    }
    
    /// Check if this audio layer should be playing at a given timeline time
    public func shouldPlay(at timelineTime: TimeInterval) -> Bool {
        return !isMuted && 
               timelineTime >= startTime && 
               timelineTime <= (startTime + duration)
    }
    
    /// Get the audio playback time for a given timeline time
    public func audioTime(for timelineTime: TimeInterval) -> TimeInterval {
        return max(0, timelineTime - startTime)
    }
    
    public static func == (lhs: AudioLayer, rhs: AudioLayer) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Extension to make Color codable for AudioLayer
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let alpha = try container.decode(Double.self, forKey: .alpha)
        
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Convert Color to RGB components
        let uiColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        try container.encode(Double(red), forKey: .red)
        try container.encode(Double(green), forKey: .green)
        try container.encode(Double(blue), forKey: .blue)
        try container.encode(Double(alpha), forKey: .alpha)
    }
} 