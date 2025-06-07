import SwiftUI

// Helper extension to get RGBA components and color space from SwiftUI.Color
#if os(macOS)
extension Color {
    func getColorInfo() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat, spaceName: String?)? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        let nsColor = NSColor(self)
        let originalColorSpaceName = nsColor.colorSpace.localizedName

        // Try converting to .extendedSRGB first, as this was closer to the original logic
        if let extendedSrgbColor = nsColor.usingColorSpace(.extendedSRGB) {
            extendedSrgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let convertedSpaceName: String? = extendedSrgbColor.colorSpace.localizedName
            print("[Color.getColorInfo] Original color: \(self), Original space: \(originalColorSpaceName ?? "Unknown"). Attempted .extendedSRGB, result space: \(convertedSpaceName ?? "Unknown"). RGBA: r:\(r) g:\(g) b:\(b) a:\(a)")
            return (r, g, b, a, convertedSpaceName)
        } else {
            print("[Color.getColorInfo] Failed to convert \(self) (Original space: \(originalColorSpaceName ?? "Unknown")) to .extendedSRGB. Trying .sRGB as fallback.")
            // Fallback to .sRGB if .extendedSRGB fails
            if let srgbColor = nsColor.usingColorSpace(.sRGB) {
                srgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                let srgbSpaceName: String? = srgbColor.colorSpace.localizedName
                print("[Color.getColorInfo] Original color: \(self). Converted to .sRGB, result space: \(srgbSpaceName ?? "Unknown"). RGBA: r:\(r) g:\(g) b:\(b) a:\(a)")
                return (r, g, b, a, srgbSpaceName)
            } else {
                print("Error: [Color.getColorInfo] Could not convert \(self) (Original space: \(originalColorSpaceName ?? "Unknown")) to .extendedSRGB or .sRGB to extract components.")
                return nil
            }
        }
    }
}
#endif

public struct CanvasElement: Identifiable, Equatable, Codable, Sendable {
    public var id = UUID()
    var type: ElementType
    var position: CGPoint
    var size: CGSize
    var rotation: Double = 0
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0 // Added scale property
    var color: Color = Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0) // Default to explicit sRGB blue
    var text: String = "Text"
    var textAlignment: TextAlignment = .leading
    var displayName: String
    var isAspectRatioLocked: Bool = true // Default to locked aspect ratio

    var assetURL: URL? // URL for image or video assets
    
    // Video-specific properties
    var videoDuration: TimeInterval? // Duration of the video asset
    var videoStartTime: TimeInterval = 0.0 // Start time offset for video playback
    var videoFrameRate: Float = 30.0 // Frame rate of the video (default 30fps)
    
    // Default initializer
    init(
        type: ElementType,
        position: CGPoint,
        size: CGSize,
        rotation: Double = 0,
        opacity: Double = 1.0,
        scale: CGFloat = 1.0, // Added scale to initializer
        color: Color = Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0), // Default to explicit sRGB blue
        text: String = "Text",
        textAlignment: TextAlignment = .leading,
        displayName: String,
        isAspectRatioLocked: Bool = true,

        assetURL: URL? = nil,
        videoDuration: TimeInterval? = nil,
        videoStartTime: TimeInterval = 0.0,
        videoFrameRate: Float = 30.0
    ) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.size = size
        self.rotation = rotation
        self.opacity = opacity
        self.scale = scale // Initialize scale
        self.color = color
        self.text = text
        self.textAlignment = textAlignment
        self.displayName = displayName
        self.isAspectRatioLocked = isAspectRatioLocked

        self.assetURL = assetURL
        self.videoDuration = videoDuration
        self.videoStartTime = videoStartTime
        self.videoFrameRate = videoFrameRate
    }
    
    // Computed property to get the center of the element as the rotation anchor point
    var rotationAnchorPoint: CGPoint {
        // Anchor point is always at the center of the element, relative to its own coordinate space
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }
    
    // Compute the absolute position of the rotation anchor on the canvas
    var absoluteAnchorPosition: CGPoint {
        // The position property is already the center of the element
        return position
    }
    
    enum ElementType: String, CaseIterable, Codable {
        case rectangle = "Rectangle"
        case ellipse = "Ellipse"
        case text = "Text"
        case image = "Image"
        case video = "Video"
    }
    
    // Coding keys for Codable implementation
    // Helper struct for encoding/decoding Color
    struct CodableColor: Codable {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
        var a: CGFloat
        var colorSpaceName: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, type, position, size, rotation, opacity, scale, color, text, textAlignment, displayName, isAspectRatioLocked, assetURL // Added scale
    }
    
    // Custom encoder to handle SwiftUI types
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(encodeCGPoint(position), forKey: .position)
        try container.encode(encodeCGSize(size), forKey: .size)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(scale, forKey: .scale) // Encode scale
        
        // Encode Color
        print("[CanvasElement Encode ID: \(self.id)] Encoding color: \(self.color)")
        #if os(macOS)
        if let (r, g, b, a, spaceName) = self.color.getColorInfo() {
            let codableColor = CodableColor(r: r, g: g, b: b, a: a, colorSpaceName: spaceName)
            try container.encode(codableColor, forKey: .color)
            print("[CanvasElement Encode ID: \(self.id)] Encoded CodableColor via getColorInfo(): r:\(r), g:\(g), b:\(b), a:\(a), space: \(spaceName ?? "nil")")
        } else {
            print("Error: Failed to get ColorInfo for color \(self.color) for ID \(self.id). Encoding as black (sRGB).")
            let fallbackCodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1, colorSpaceName: NSColorSpace.sRGB.localizedName) // Black in sRGB
            try container.encode(fallbackCodableColor, forKey: .color)
        }
        #else
        // Fallback for non-macOS platforms or if the extension is not available (should not happen here)
        print("Warning: macOS Color.getColorInfo() extension not available. Using previous NSColor sRGB fallback for ID \(self.id).")
        let nsColor = NSColor(self.color)
        if let srgbColor = nsColor.usingColorSpace(.sRGB) {
            let codableColor = CodableColor(r: srgbColor.redComponent, g: srgbColor.greenComponent, b: srgbColor.blueComponent, a: srgbColor.alphaComponent, colorSpaceName: NSColorSpace.sRGB.localizedName)
            try container.encode(codableColor, forKey: .color)
        } else {
            print("Error: Could not convert color \(self.color) to sRGB for ID \(self.id) (non-macOS fallback). Encoding as black.")
            try container.encode(CodableColor(r: 0, g: 0, b: 0, a: 1, colorSpaceName: NSColorSpace.sRGB.localizedName), forKey: .color)
        }
        #endif
        
        try container.encode(text, forKey: .text)
        try container.encode(encodeTextAlignment(textAlignment), forKey: .textAlignment)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isAspectRatioLocked, forKey: .isAspectRatioLocked)

        try container.encodeIfPresent(assetURL?.absoluteString, forKey: .assetURL)
    }
    
    // Custom decoder to handle SwiftUI types
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(ElementType.self, forKey: .type)
        
        // Parse position using helper
        self.position = try Self.decodeCGPoint(from: container.decode(String.self, forKey: .position))
        
        // Parse size using helper
        self.size = try Self.decodeCGSize(from: container.decode(String.self, forKey: .size))
        
        self.rotation = try container.decode(Double.self, forKey: .rotation)
        self.opacity = try container.decode(Double.self, forKey: .opacity)
        self.scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1.0
        
        // Color parsing
        print("[CanvasElement Decode ID: \(self.id)] Attempting to decode color.")
        do {
            let codableColor = try container.decode(CodableColor.self, forKey: .color)
            if let storedSpaceName = codableColor.colorSpaceName { // This is String?, likely a localized name
                var matchedColorSpace: NSColorSpace? = nil
                // Attempt to match known color spaces by their localized names
                if storedSpaceName == NSColorSpace.sRGB.localizedName {
                    matchedColorSpace = .sRGB
                } else if storedSpaceName == NSColorSpace.displayP3.localizedName {
                    matchedColorSpace = .displayP3
                } else if storedSpaceName == NSColorSpace.adobeRGB1998.localizedName {
                    matchedColorSpace = .adobeRGB1998
                } // Add other common spaces if needed, e.g., genericRGB, genericGray, etc.
                // Note: NSColorSpace.extendedSRGB.localizedName might also be relevant depending on encoding source

                if let colorSpace = matchedColorSpace {
                    self.color = Color(NSColor(colorSpace: colorSpace, components: [codableColor.r, codableColor.g, codableColor.b, codableColor.a], count: 4))
                    print("[CanvasElement Decode ID: \(self.id)] Successfully decoded color \(self.color) using matched space: \(storedSpaceName)")
                } else {
                    print("[CanvasElement Decode ID: \(self.id)] Could not match stored color space name '\(storedSpaceName)' to known spaces. Using sRGB fallback for components directly.")
                    self.color = Color(red: codableColor.r, green: codableColor.g, blue: codableColor.b, opacity: codableColor.a)
                }
            } else { // codableColor.colorSpaceName was nil
                print("[CanvasElement Decode ID: \(self.id)] No colorSpaceName stored. Using sRGB fallback for components directly.")
                self.color = Color(red: codableColor.r, green: codableColor.g, blue: codableColor.b, opacity: codableColor.a)
            }
        } catch {
            print("Error: [CanvasElement Decode ID: \(self.id)] Failed to decode CodableColor: \(error). Using default color (blue).")
            self.color = Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0) // Default blue
        }
        
        self.text = try container.decode(String.self, forKey: .text)
        self.textAlignment = try Self.decodeTextAlignment(from: container.decode(String.self, forKey: .textAlignment))
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.isAspectRatioLocked = try container.decode(Bool.self, forKey: .isAspectRatioLocked)

        
        if let urlString = try container.decodeIfPresent(String.self, forKey: .assetURL) {
            self.assetURL = URL(string: urlString)
        } else {
            self.assetURL = nil
        }
    }
    
    // Helper functions for decoding types from strings
    public static func decodeCGPoint(from stringValue: String) throws -> CGPoint {
        // Remove common non-numeric characters and trim whitespace
        let cleanedString = stringValue.replacingOccurrences(of: "[{()}]", with: "", options: .regularExpression)
                                       .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let components = cleanedString.split(separator: ",")
        guard components.count == 2,
              let xStr = components.first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines), let x = Double(xStr),
              let yStr = components.last.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines), let y = Double(yStr) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid CGPoint format after cleaning: '\(stringValue)' -> '\(cleanedString)'"))
        }
        return CGPoint(x: x, y: y)
    }

    public static func decodeCGSize(from stringValue: String) throws -> CGSize {
        // Remove common non-numeric characters and trim whitespace
        let cleanedString = stringValue.replacingOccurrences(of: "[{()}]", with: "", options: .regularExpression)
                                       .trimmingCharacters(in: .whitespacesAndNewlines)

        let components = cleanedString.split(separator: ",")
        guard components.count == 2,
              let wStr = components.first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines), let width = Double(wStr),
              let hStr = components.last.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines), let height = Double(hStr) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid CGSize format after cleaning: '\(stringValue)' -> '\(cleanedString)'"))
        }
        return CGSize(width: width, height: height)
    }

    private static func decodeTextAlignment(from stringValue: String) throws -> TextAlignment {
        switch stringValue {
        case "leading": return .leading
        case "center": return .center
        case "trailing": return .trailing
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid TextAlignment string: \(stringValue)"))
        }
    }



    // Helper functions for encoding SwiftUI types to strings
    private func encodeCGPoint(_ point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }
    
    private func encodeCGSize(_ size: CGSize) -> String {
        return "\(size.width),\(size.height)"
    }
    
    private func encodeTextAlignment(_ alignment: TextAlignment) -> String {
        switch alignment {
        case .leading: return "leading"
        case .center: return "center"
        case .trailing: return "trailing"
        }
    }
    

    
    // Factory methods for creating different types of elements
    static func rectangle(at position: CGPoint, size: CGSize = CGSize(width: 100, height: 80), scale: CGFloat = 1.0) -> CanvasElement {
        CanvasElement(
            type: .rectangle,
            position: position,
            size: size,
            scale: scale,
            color: Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0), // Explicit sRGB blue
            displayName: "Rectangle"
        )
    }

    static func ellipse(at position: CGPoint, size: CGSize = CGSize(width: 100, height: 80), scale: CGFloat = 1.0) -> CanvasElement {
        CanvasElement(
            type: .ellipse,
            position: position,
            size: size,
            scale: scale,
            color: Color(red: 0.3, green: 0.7, blue: 0.3, opacity: 1.0), // Explicit sRGB green
            displayName: "Ellipse"
        )
    }
    
    static func text(at position: CGPoint, content: String = "Text", scale: CGFloat = 1.0) -> CanvasElement {
        CanvasElement(
            type: .text,
            position: position,
            size: CGSize(width: 200, height: 50),
            scale: scale,
            color: Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 1.0), // Explicit sRGB dark gray
            text: content,
            textAlignment: .leading,
            displayName: "Text"
        )
    }
    


    public static func image(at position: CGPoint, assetURL: URL?, displayName: String, size: CGSize, scale: CGFloat = 1.0) -> CanvasElement {
        CanvasElement(
            type: .image,
            position: position,
            size: size,
            scale: scale,
            displayName: displayName,
            assetURL: assetURL
        )
    }

    public static func video(at position: CGPoint, assetURL: URL?, displayName: String, size: CGSize, scale: CGFloat = 1.0, videoDuration: TimeInterval? = nil, videoStartTime: TimeInterval = 0.0, videoFrameRate: Float = 30.0) -> CanvasElement {
        CanvasElement(
            type: .video,
            position: position,
            size: size,
            scale: scale,
            displayName: displayName,
            assetURL: assetURL,
            videoDuration: videoDuration,
            videoStartTime: videoStartTime,
            videoFrameRate: videoFrameRate
        )
    }
} 