import SwiftUI
import AppKit

/// Utility for checking color contrast ratios and WCAG compliance
struct ColorContrastChecker {
    
    // MARK: - WCAG Standards
    enum WCAGLevel {
        case aa, aaa
        
        var normalTextRatio: Double {
            switch self {
            case .aa: return 4.5
            case .aaa: return 7.0
            }
        }
        
        var largeTextRatio: Double {
            switch self {
            case .aa: return 3.0
            case .aaa: return 4.5
            }
        }
    }
    
    // MARK: - Color Pair Analysis
    struct ColorPair {
        let foreground: Color
        let background: Color
        let description: String
        let context: String
        
        var contrastRatio: Double {
            calculateContrastRatio(foreground: foreground, background: background)
        }
        
        func meetsWCAG(_ level: WCAGLevel, isLargeText: Bool = false) -> Bool {
            let requiredRatio = isLargeText ? level.largeTextRatio : level.normalTextRatio
            return contrastRatio >= requiredRatio
        }
    }
    
    // MARK: - App Color Definitions
    static func getAppColorPairs() -> [ColorPair] {
        var pairs: [ColorPair] = []
        
        // Primary UI Colors
        pairs.append(ColorPair(
            foreground: .primary,
            background: Color(NSColor.windowBackgroundColor),
            description: "Primary text on window background",
            context: "Main interface text"
        ))
        
        pairs.append(ColorPair(
            foreground: .secondary,
            background: Color(NSColor.windowBackgroundColor),
            description: "Secondary text on window background",
            context: "Subtitle and helper text"
        ))
        
        // Button and Interactive Elements
        pairs.append(ColorPair(
            foreground: .white,
            background: .blue,
            description: "White text on blue background",
            context: "Primary buttons (Create, Export, etc.)"
        ))
        
        pairs.append(ColorPair(
            foreground: .blue,
            background: Color(NSColor.controlBackgroundColor),
            description: "Blue text on control background",
            context: "Links and secondary buttons"
        ))
        
        // Selected/Active States
        pairs.append(ColorPair(
            foreground: .white,
            background: .blue,
            description: "Selected tool in toolbar",
            context: "Design toolbar selected state"
        ))
        
        pairs.append(ColorPair(
            foreground: .primary,
            background: Color.blue.opacity(0.1),
            description: "Text on blue selection background",
            context: "Selected items in lists"
        ))
        
        // Canvas and Design Elements
        pairs.append(ColorPair(
            foreground: Color.blue.opacity(0.7),
            background: Color(NSColor.windowBackgroundColor),
            description: "Canvas boundary on background",
            context: "Canvas border visualization"
        ))
        
        // Timeline and Animation Controls
        pairs.append(ColorPair(
            foreground: .orange,
            background: Color(NSColor.controlBackgroundColor),
            description: "Timeline resize handle warning",
            context: "Timeline at maximum height"
        ))
        
        pairs.append(ColorPair(
            foreground: Color(NSColor.separatorColor),
            background: Color(NSColor.controlBackgroundColor),
            description: "Timeline separator",
            context: "Timeline visual elements"
        ))
        
        // Inspector and Sidebar
        pairs.append(ColorPair(
            foreground: .gray,
            background: Color(NSColor.windowBackgroundColor),
            description: "Inspector close button",
            context: "Inspector panel controls"
        ))
        
        // Template Cards
        pairs.append(ColorPair(
            foreground: .blue,
            background: Color.blue.opacity(0.1),
            description: "Template card icon and text",
            context: "Template selection cards"
        ))
        
        // Media Browser
        pairs.append(ColorPair(
            foreground: .gray,
            background: Color.gray.opacity(0.1),
            description: "Audio waveform placeholder",
            context: "Media browser audio preview"
        ))
        
        // Custom Element Colors (from CanvasElement)
        pairs.append(ColorPair(
            foreground: Color(red: 1.0, green: 0.231, blue: 0.188, opacity: 1.0), // Red
            background: Color(NSColor.windowBackgroundColor),
            description: "Red canvas element",
            context: "Canvas elements with red color"
        ))
        
        pairs.append(ColorPair(
            foreground: Color(red: 0.204, green: 0.780, blue: 0.349, opacity: 1.0), // Green
            background: Color(NSColor.windowBackgroundColor),
            description: "Green canvas element",
            context: "Canvas elements with green color"
        ))
        
        pairs.append(ColorPair(
            foreground: Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0), // Blue
            background: Color(NSColor.windowBackgroundColor),
            description: "Blue canvas element",
            context: "Canvas elements with blue color"
        ))
        
        pairs.append(ColorPair(
            foreground: Color(red: 1.0, green: 0.584, blue: 0.0, opacity: 1.0), // Orange
            background: Color(NSColor.windowBackgroundColor),
            description: "Orange canvas element",
            context: "Canvas elements with orange color"
        ))
        
        pairs.append(ColorPair(
            foreground: Color(red: 0.690, green: 0.322, blue: 0.871, opacity: 1.0), // Purple
            background: Color(NSColor.windowBackgroundColor),
            description: "Purple canvas element",
            context: "Canvas elements with purple color"
        ))
        
        // Export and Status
        pairs.append(ColorPair(
            foreground: .white,
            background: Color.black.opacity(0.6),
            description: "Zoom indicator text",
            context: "Canvas zoom level indicator"
        ))
        
        return pairs
    }
    
    // MARK: - Contrast Calculation
    static func calculateContrastRatio(foreground: Color, background: Color) -> Double {
        let fgLuminance = getLuminance(color: foreground)
        let bgLuminance = getLuminance(color: background)
        
        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private static func getLuminance(color: Color) -> Double {
        // Convert SwiftUI Color to NSColor for component extraction
        let nsColor = NSColor(color)
        
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return 0.0
        }
        
        let r = Double(rgbColor.redComponent)
        let g = Double(rgbColor.greenComponent)
        let b = Double(rgbColor.blueComponent)
        
        // Apply gamma correction
        func gammaCorrect(_ component: Double) -> Double {
            if component <= 0.03928 {
                return component / 12.92
            } else {
                return pow((component + 0.055) / 1.055, 2.4)
            }
        }
        
        let rLinear = gammaCorrect(r)
        let gLinear = gammaCorrect(g)
        let bLinear = gammaCorrect(b)
        
        // Calculate relative luminance using ITU-R BT.709 coefficients
        return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
    }
    
    // MARK: - Analysis Results
    struct ContrastAnalysisResult {
        let totalPairs: Int
        let aaCompliantNormal: Int
        let aaCompliantLarge: Int
        let aaaCompliantNormal: Int
        let aaaCompliantLarge: Int
        let failingPairs: [ColorPair]
        let improvementSuggestions: [String]
        
        var aaCompliancePercentage: Double {
            return Double(aaCompliantNormal) / Double(totalPairs) * 100
        }
        
        var aaaCompliancePercentage: Double {
            return Double(aaaCompliantNormal) / Double(totalPairs) * 100
        }
    }
    
    static func analyzeAppContrast() -> ContrastAnalysisResult {
        let colorPairs = getAppColorPairs()
        var aaCompliantNormal = 0
        var aaCompliantLarge = 0
        var aaaCompliantNormal = 0
        var aaaCompliantLarge = 0
        var failingPairs: [ColorPair] = []
        var suggestions: [String] = []
        
        for pair in colorPairs {
            let ratio = pair.contrastRatio
            
            if pair.meetsWCAG(.aa, isLargeText: false) {
                aaCompliantNormal += 1
            } else {
                failingPairs.append(pair)
                suggestions.append("Improve contrast for '\(pair.description)' (current: \(String(format: "%.2f", ratio)), required: 4.5)")
            }
            
            if pair.meetsWCAG(.aa, isLargeText: true) {
                aaCompliantLarge += 1
            }
            
            if pair.meetsWCAG(.aaa, isLargeText: false) {
                aaaCompliantNormal += 1
            }
            
            if pair.meetsWCAG(.aaa, isLargeText: true) {
                aaaCompliantLarge += 1
            }
        }
        
        return ContrastAnalysisResult(
            totalPairs: colorPairs.count,
            aaCompliantNormal: aaCompliantNormal,
            aaCompliantLarge: aaCompliantLarge,
            aaaCompliantNormal: aaaCompliantNormal,
            aaaCompliantLarge: aaaCompliantLarge,
            failingPairs: failingPairs,
            improvementSuggestions: suggestions
        )
    }
    
    // MARK: - Color Suggestions
    static func suggestImprovedColor(foreground: Color, background: Color, targetRatio: Double = 4.5) -> Color {
        let bgLuminance = getLuminance(color: background)
        
        // Calculate target luminance for foreground
        let targetFgLuminance: Double
        if bgLuminance > 0.5 {
            // Dark text on light background
            targetFgLuminance = (bgLuminance + 0.05) / targetRatio - 0.05
        } else {
            // Light text on dark background
            targetFgLuminance = (bgLuminance + 0.05) * targetRatio - 0.05
        }
        
        // Clamp luminance values
        let clampedLuminance = max(0.0, min(1.0, targetFgLuminance))
        
        // Convert back to RGB (simplified approach)
        let grayValue = pow(clampedLuminance, 1/2.2)
        return Color(red: grayValue, green: grayValue, blue: grayValue)
    }
}

// MARK: - SwiftUI Preview Support
#if DEBUG
struct ColorContrastAnalysisView: View {
    @State private var analysisResult: ColorContrastChecker.ContrastAnalysisResult?
    @State private var isAnalyzing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Contrast Analysis")
                .font(.title)
                .fontWeight(.bold)
            
            if isAnalyzing {
                ProgressView("Analyzing colors...")
            } else if let result = analysisResult {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analysis Results")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("WCAG AA Compliance")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(result.aaCompliantNormal)/\(result.totalPairs) pairs (\(String(format: "%.1f", result.aaCompliancePercentage))%)")
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("WCAG AAA Compliance")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(result.aaaCompliantNormal)/\(result.totalPairs) pairs (\(String(format: "%.1f", result.aaaCompliancePercentage))%)")
                        }
                    }
                    
                    if !result.failingPairs.isEmpty {
                        Text("Issues Found")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        ForEach(result.failingPairs.indices, id: \.self) { index in
                            let pair = result.failingPairs[index]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pair.description)
                                    .fontWeight(.semibold)
                                Text("Context: \(pair.context)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Contrast ratio: \(String(format: "%.2f", pair.contrastRatio))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else {
                Button("Run Analysis") {
                    runAnalysis()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func runAnalysis() {
        isAnalyzing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ColorContrastChecker.analyzeAppContrast()
            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
            }
        }
    }
}

#Preview {
    ColorContrastAnalysisView()
}
#endif 