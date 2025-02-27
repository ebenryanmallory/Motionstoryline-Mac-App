import Cocoa

// List of image names to generate
let imageNames = [
    "design_thumbnail",
    "prototype_thumbnail",
    "style_thumbnail",
    "component_thumbnail",
    "recording_thumbnail",
    "placeholder",
    "video_thumbnail",
    "animation_thumbnail",
    "presentation_thumbnail"
]

// Colors for each image
let colors: [String: NSColor] = [
    "design_thumbnail": NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
    "prototype_thumbnail": NSColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0),
    "style_thumbnail": NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0),
    "component_thumbnail": NSColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1.0),
    "recording_thumbnail": NSColor(red: 0.7, green: 0.3, blue: 0.8, alpha: 1.0),
    "placeholder": NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
    "video_thumbnail": NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0),
    "animation_thumbnail": NSColor(red: 0.8, green: 0.4, blue: 0.6, alpha: 1.0),
    "presentation_thumbnail": NSColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1.0)
]

// Image size
let size = CGSize(width: 200, height: 150)

// Generate each image
for name in imageNames {
    // Create image context
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        print("Failed to create context for \(name)")
        continue
    }
    
    // Fill background
    let color = colors[name] ?? NSColor.gray
    context.setFillColor(color.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    
    // Add text
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext
    
    let text = name.replacingOccurrences(of: "_thumbnail", with: "")
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 16),
        .foregroundColor: NSColor.white
    ]
    let textSize = text.size(withAttributes: attributes)
    let textRect = CGRect(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attributes)
    
    NSGraphicsContext.restoreGraphicsState()
    
    // Create image and save to file
    if let cgImage = context.makeImage() {
        let image = NSImage(cgImage: cgImage, size: size)
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            
            let url = URL(fileURLWithPath: "../Motion Storyline/Motion Storyline/Assets.xcassets/\(name).imageset/\(name).png")
            do {
                try pngData.write(to: url)
                print("Created \(name).png")
            } catch {
                print("Failed to write \(name).png: \(error)")
            }
        }
    }
}

print("Done generating placeholder images.") 