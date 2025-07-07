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
    
    // Custom Codable implementation to handle Color encoding
    enum CodingKeys: String, CodingKey {
        case id, name, assetURL, startTime, duration, volume, isMuted, isVisible, waveformColor
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.assetURL = try container.decode(URL.self, forKey: .assetURL)
        self.startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        self.duration = try container.decode(TimeInterval.self, forKey: .duration)
        self.volume = try container.decode(Double.self, forKey: .volume)
        self.isMuted = try container.decode(Bool.self, forKey: .isMuted)
        self.isVisible = try container.decode(Bool.self, forKey: .isVisible)
        
        // Decode waveformColor using CodableColor helper
        let codableColor = try container.decode(CodableColor.self, forKey: .waveformColor)
        self.waveformColor = codableColor.toColor()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(assetURL, forKey: .assetURL)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(volume, forKey: .volume)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(isVisible, forKey: .isVisible)
        
        // Encode waveformColor using CodableColor helper
        let codableColor = CodableColor(from: waveformColor)
        try container.encode(codableColor, forKey: .waveformColor)
    }
}

/// Helper struct for encoding/decoding Color in AudioLayer
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(from color: Color) {
        let nsColor = NSColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        // Convert to sRGB colorspace to safely extract components
        if let srgbColor = nsColor.usingColorSpace(.sRGB) {
            srgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        } else {
            // Fallback to default values if conversion fails
            r = 0; g = 0; b = 0; a = 1
            print("Warning: Could not convert color to sRGB in AudioLayer, using black as fallback")
        }
        
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
    
    func toColor() -> Color {
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
} 