import XCTest
import SwiftUI
@testable import Motion_Storyline

final class ColorContrastTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Called before each test method is invoked
    }
    
    override func tearDownWithError() throws {
        // Called after each test method is invoked
    }
    
    func testWCAGAACompliance() throws {
        // Test that critical UI elements meet WCAG AA standards
        let result = ColorContrastChecker.analyzeAppContrast()
        
        // Print detailed results for debugging
        print("WCAG AA Compliance Test Results:")
        print("Total color pairs analyzed: \(result.totalPairs)")
        print("AA compliant (normal text): \(result.aaCompliantNormal)/\(result.totalPairs) (\(String(format: "%.1f", result.aaCompliancePercentage))%)")
        print("AA compliant (large text): \(result.aaCompliantLarge)/\(result.totalPairs)")
        
        if !result.failingPairs.isEmpty {
            print("\nFailing color pairs:")
            for pair in result.failingPairs {
                print("- \(pair.description): \(String(format: "%.2f", pair.contrastRatio)) (context: \(pair.context))")
            }
        }
        
        // Critical UI elements should meet AA standards
        let criticalElements = result.failingPairs.filter { pair in
            pair.context.contains("Main interface") ||
            pair.context.contains("Primary buttons") ||
            pair.context.contains("Navigation") ||
            pair.context.contains("Inspector") ||
            pair.context.contains("toolbar")
        }
        
        XCTAssertTrue(criticalElements.isEmpty, 
                      "Critical UI elements must meet WCAG AA standards. Failing elements: \(criticalElements.map { $0.description })")
        
        // At least 90% of all UI elements should meet AA standards
        XCTAssertGreaterThanOrEqual(result.aaCompliancePercentage, 90.0, 
                                    "At least 90% of UI elements should meet WCAG AA standards")
    }
    
    func testSpecificColorPairs() throws {
        // Test specific important color combinations
        
        // Primary button (white on blue)
        let primaryButtonRatio = ColorContrastChecker.calculateContrastRatio(
            foreground: .white,
            background: .blue
        )
        XCTAssertGreaterThanOrEqual(primaryButtonRatio, 4.5, 
                                    "Primary button text must meet WCAG AA standards")
        
        // Secondary text visibility
        let secondaryTextRatio = ColorContrastChecker.calculateContrastRatio(
            foreground: .secondary,
            background: Color(NSColor.windowBackgroundColor)
        )
        XCTAssertGreaterThanOrEqual(secondaryTextRatio, 4.5, 
                                    "Secondary text must meet WCAG AA standards")
        
        // Selected state visibility
        let selectedStateRatio = ColorContrastChecker.calculateContrastRatio(
            foreground: .white,
            background: .blue
        )
        XCTAssertGreaterThanOrEqual(selectedStateRatio, 4.5, 
                                    "Selected state indicators must meet WCAG AA standards")
    }
    
    func testCanvasElementColors() throws {
        // Test that canvas element colors have sufficient contrast against backgrounds
        let windowBackground = Color(NSColor.windowBackgroundColor)
        
        let canvasColors = [
            ("Red", Color(red: 1.0, green: 0.231, blue: 0.188, opacity: 1.0)),
            ("Green", Color(red: 0.204, green: 0.780, blue: 0.349, opacity: 1.0)),
            ("Blue", Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0)),
            ("Orange", Color(red: 1.0, green: 0.584, blue: 0.0, opacity: 1.0)),
            ("Purple", Color(red: 0.690, green: 0.322, blue: 0.871, opacity: 1.0))
        ]
        
        for (colorName, color) in canvasColors {
            let ratio = ColorContrastChecker.calculateContrastRatio(
                foreground: color,
                background: windowBackground
            )
            
            // Canvas elements should have at least 3:1 contrast for visibility
            // (lower requirement since these are design elements, not text)
            XCTAssertGreaterThanOrEqual(ratio, 3.0, 
                                        "\(colorName) canvas elements should be sufficiently visible against background")
        }
    }
    
    func testDarkModeCompatibility() throws {
        // Test color visibility in different appearance modes
        // Note: This is a simplified test since full dark mode testing would require 
        // changing the system appearance
        
        let darkBackground = Color.black
        let lightBackground = Color.white
        
        // Test that primary colors work on both backgrounds
        let testColors: [Color] = [.blue, .red, .green, .orange, .purple]
        
        for color in testColors {
            let darkRatio = ColorContrastChecker.calculateContrastRatio(
                foreground: color,
                background: darkBackground
            )
            let lightRatio = ColorContrastChecker.calculateContrastRatio(
                foreground: color,
                background: lightBackground
            )
            
            // At least one should meet minimum visibility standards
            XCTAssertTrue(darkRatio >= 3.0 || lightRatio >= 3.0, 
                          "Color should be visible on either light or dark background")
        }
    }
    
    func testColorSuggestionAlgorithm() throws {
        // Test the color improvement suggestion algorithm
        let background = Color.white
        let poorContrastColor = Color.gray
        
        let improvedColor = ColorContrastChecker.suggestImprovedColor(
            foreground: poorContrastColor,
            background: background,
            targetRatio: 4.5
        )
        
        let improvedRatio = ColorContrastChecker.calculateContrastRatio(
            foreground: improvedColor,
            background: background
        )
        
        XCTAssertGreaterThanOrEqual(improvedRatio, 4.5, 
                                    "Suggested color should meet target contrast ratio")
    }
    
    func testReadabilityInDifferentSizes() throws {
        // Test readability for different text sizes
        let result = ColorContrastChecker.analyzeAppContrast()
        
        // Large text has lower requirements (3:1 for AA, 4.5:1 for AAA)
        let largeTextAACompliance = Double(result.aaCompliantLarge) / Double(result.totalPairs) * 100
        
        // Large text should have higher compliance rates
        XCTAssertGreaterThanOrEqual(largeTextAACompliance, result.aaCompliancePercentage, 
                                    "Large text should have better or equal compliance than normal text")
        
        // At least 95% should meet large text AA standards
        XCTAssertGreaterThanOrEqual(largeTextAACompliance, 95.0, 
                                    "At least 95% of color pairs should meet large text AA standards")
    }
    
    func testPerformanceOfContrastCalculation() throws {
        // Test that contrast calculation is fast enough for real-time use
        let testPairs = ColorContrastChecker.getAppColorPairs()
        
        measure {
            for pair in testPairs {
                _ = pair.contrastRatio
            }
        }
    }
    
    func testContrastRatioAccuracy() throws {
        // Test known contrast ratios for accuracy
        
        // Black on white should be 21:1 (maximum contrast)
        let blackOnWhite = ColorContrastChecker.calculateContrastRatio(
            foreground: .black,
            background: .white
        )
        XCTAssertEqual(blackOnWhite, 21.0, accuracy: 0.1, 
                       "Black on white should have maximum contrast ratio")
        
        // White on white should be 1:1 (no contrast)
        let whiteOnWhite = ColorContrastChecker.calculateContrastRatio(
            foreground: .white,
            background: .white
        )
        XCTAssertEqual(whiteOnWhite, 1.0, accuracy: 0.1, 
                       "White on white should have no contrast")
        
        // Medium gray should have reasonable contrast
        let grayOnWhite = ColorContrastChecker.calculateContrastRatio(
            foreground: .gray,
            background: .white
        )
        XCTAssertGreaterThan(grayOnWhite, 1.0, 
                             "Gray should have some contrast against white")
        XCTAssertLessThan(grayOnWhite, 21.0, 
                          "Gray should have less than maximum contrast")
    }
}

// MARK: - Color Contrast Report Generator
extension ColorContrastTests {
    
    func testGenerateContrastReport() throws {
        // Generate a comprehensive report for documentation
        let result = ColorContrastChecker.analyzeAppContrast()
        let report = generateContrastReport(result: result)
        
        print("\n" + "="*80)
        print("COLOR CONTRAST COMPLIANCE REPORT")
        print("="*80)
        print(report)
        print("="*80)
        
        // Save report to file if needed for documentation
        // Uncomment the following lines to save report to file:
        /*
        let reportData = report.data(using: .utf8)!
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        let reportURL = documentsPath.appendingPathComponent("contrast_report.txt")
        try reportData.write(to: reportURL)
        print("Report saved to: \(reportURL.path)")
        */
    }
    
    private func generateContrastReport(result: ColorContrastChecker.ContrastAnalysisResult) -> String {
        var report = ""
        
        report += "Generated: \(Date())\n\n"
        
        report += "SUMMARY:\n"
        report += "--------\n"
        report += "Total color pairs analyzed: \(result.totalPairs)\n"
        report += "WCAG AA compliant (normal text): \(result.aaCompliantNormal) (\(String(format: "%.1f", result.aaCompliancePercentage))%)\n"
        report += "WCAG AA compliant (large text): \(result.aaCompliantLarge)\n"
        report += "WCAG AAA compliant (normal text): \(result.aaaCompliantNormal) (\(String(format: "%.1f", result.aaaCompliancePercentage))%)\n"
        report += "WCAG AAA compliant (large text): \(result.aaaCompliantLarge)\n\n"
        
        if !result.failingPairs.isEmpty {
            report += "ISSUES REQUIRING ATTENTION:\n"
            report += "---------------------------\n"
            for pair in result.failingPairs {
                report += "• \(pair.description)\n"
                report += "  Context: \(pair.context)\n"
                report += "  Current ratio: \(String(format: "%.2f", pair.contrastRatio)) (needs 4.5+)\n\n"
            }
        }
        
        report += "RECOMMENDATIONS:\n"
        report += "----------------\n"
        for suggestion in result.improvementSuggestions {
            report += "• \(suggestion)\n"
        }
        
        return report
    }
}

// Helper function for string repetition
private func * (left: String, right: Int) -> String {
    return String(repeating: left, count: right)
} 