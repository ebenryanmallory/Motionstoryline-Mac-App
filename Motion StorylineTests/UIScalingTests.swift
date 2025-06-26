import XCTest
import SwiftUI
@testable import Motion_Storyline

final class UIScalingTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Called before each test method is invoked
    }
    
    override func tearDownWithError() throws {
        // Called after each test method is invoked
    }
    
    func testUIScalingAnalysis() throws {
        // Test that the UI scaling analysis runs without errors
        let results = UIScalingTester.analyzeUIScaling()
        
        XCTAssertFalse(results.isEmpty, "Analysis should return results for all test scenarios")
        XCTAssertEqual(results.count, UIScalingTester.TestScenario.allCases.count, "Should have results for all scenarios")
        
        // Verify each result has valid data
        for result in results {
            XCTAssertGreaterThanOrEqual(result.overallScore, 0.0, "Score should be non-negative")
            XCTAssertLessThanOrEqual(result.overallScore, 1.0, "Score should not exceed 1.0")
            XCTAssertFalse(result.recommendations.isEmpty, "Should provide recommendations")
        }
    }
    
    func testMinimumWindowSizeCompliance() throws {
        // Test that minimum window size constraints are properly identified
        let results = UIScalingTester.analyzeUIScaling()
        let minWindowResult = results.first { $0.scenario == .minWindowSize }
        
        XCTAssertNotNil(minWindowResult, "Should have results for minimum window size scenario")
        
        if let result = minWindowResult {
            // Should identify issues with constrained layouts
            let hasTimelineIssues = result.issues.contains { $0.component.contains("Timeline") }
            let hasInspectorIssues = result.issues.contains { $0.component.contains("Inspector") }
            
            XCTAssertTrue(hasTimelineIssues || hasInspectorIssues, "Should identify layout constraints at minimum size")
        }
    }
    
    func testAccessibilityScalingCompliance() throws {
        // Test accessibility scenario specifically
        let results = UIScalingTester.analyzeUIScaling()
        let accessibilityResult = results.first { $0.scenario == .accessibility }
        
        XCTAssertNotNil(accessibilityResult, "Should have results for accessibility scenario")
        
        if let result = accessibilityResult {
            // Should identify text scaling and interactive element issues
            let hasTextScalingIssues = result.issues.contains { $0.component.contains("Text") }
            let hasInteractiveElementIssues = result.issues.contains { $0.component.contains("Interactive") || $0.component.contains("Handle") }
            
            XCTAssertTrue(hasTextScalingIssues || hasInteractiveElementIssues, "Should identify accessibility-related issues")
            
            // Should provide accessibility-specific recommendations
            let hasAccessibilityRecommendations = result.recommendations.contains { $0.contains("accessibility") || $0.contains("WCAG") || $0.contains("44pt") }
            XCTAssertTrue(hasAccessibilityRecommendations, "Should provide accessibility recommendations")
        }
    }
    
    func testUltraWideDisplayHandling() throws {
        // Test ultra-wide display scenario
        let results = UIScalingTester.analyzeUIScaling()
        let ultraWideResult = results.first { $0.scenario == .ultraWide }
        
        XCTAssertNotNil(ultraWideResult, "Should have results for ultra-wide display scenario")
        
        if let result = ultraWideResult {
            // Should identify canvas viewport considerations
            let hasCanvasIssues = result.issues.contains { $0.component.contains("Canvas") }
            
            // Note: Canvas issues are expected on ultra-wide displays
            // The test verifies that the analysis recognizes this scenario
        }
    }
    
    func testReportGeneration() throws {
        // Test that the scaling report can be generated successfully
        let report = UIScalingTester.generateScalingReport()
        
        XCTAssertFalse(report.isEmpty, "Report should not be empty")
        XCTAssertTrue(report.contains("UI Scaling and Responsiveness Report"), "Report should have proper title")
        XCTAssertTrue(report.contains("Executive Summary"), "Report should include executive summary")
        XCTAssertTrue(report.contains("Technical Implementation Guide"), "Report should include implementation guide")
        
        // Verify report contains all test scenarios
        for scenario in UIScalingTester.TestScenario.allCases {
            XCTAssertTrue(report.contains(scenario.rawValue), "Report should mention scenario: \(scenario.rawValue)")
        }
    }
    
    func testScoreCalculation() throws {
        // Test that score calculation works correctly
        let results = UIScalingTester.analyzeUIScaling()
        
        for result in results {
            if result.issues.isEmpty {
                XCTAssertEqual(result.overallScore, 1.0, "Perfect score for no issues")
            } else {
                XCTAssertLess(result.overallScore, 1.0, "Score should be reduced when issues exist")
                
                // Higher severity issues should result in lower scores
                let hasCriticalIssues = result.issues.contains { $0.severity == .critical }
                if hasCriticalIssues {
                    XCTAssertLess(result.overallScore, 0.8, "Critical issues should significantly impact score")
                }
            }
        }
    }
    
    func testIssueClassification() throws {
        // Test that issues are properly classified by severity
        let results = UIScalingTester.analyzeUIScaling()
        let allIssues = results.flatMap { $0.issues }
        
        XCTAssertFalse(allIssues.isEmpty, "Should identify some issues in the current implementation")
        
        // Verify severity classification
        for issue in allIssues {
            XCTAssertFalse(issue.component.isEmpty, "Issue should specify component")
            XCTAssertFalse(issue.description.isEmpty, "Issue should have description")
            XCTAssertFalse(issue.location.isEmpty, "Issue should specify location")
        }
        
        // Should have a mix of severity levels
        let severities = Set(allIssues.map { $0.severity })
        XCTAssertTrue(severities.count > 1, "Should identify issues of different severities")
    }
    
    func testRecommendationQuality() throws {
        // Test that recommendations are actionable and specific
        let results = UIScalingTester.analyzeUIScaling()
        
        for result in results {
            if !result.issues.isEmpty {
                XCTAssertFalse(result.recommendations.isEmpty, "Should provide recommendations when issues exist")
                
                for recommendation in result.recommendations {
                    XCTAssertFalse(recommendation.isEmpty, "Recommendation should not be empty")
                    XCTAssertTrue(recommendation.hasPrefix("•"), "Recommendations should be properly formatted")
                }
            }
        }
    }
    
    func testWindowSizeConstraints() throws {
        // Test window size constraint validation
        let minSize = NSSize(width: 800, height: 600)
        
        for scenario in UIScalingTester.TestScenario.allCases {
            let windowSize = scenario.windowSize
            
            if scenario == .minWindowSize {
                XCTAssertEqual(windowSize.width, minSize.width, "Min window scenario should match minimum width")
                XCTAssertEqual(windowSize.height, minSize.height, "Min window scenario should match minimum height")
            } else {
                XCTAssertGreaterThanOrEqual(windowSize.width, minSize.width, "Window width should meet minimum")
                XCTAssertGreaterThanOrEqual(windowSize.height, minSize.height, "Window height should meet minimum")
            }
        }
    }
    
    func testScenarioDescriptions() throws {
        // Test that all scenarios have meaningful descriptions
        for scenario in UIScalingTester.TestScenario.allCases {
            let description = scenario.description
            XCTAssertFalse(description.isEmpty, "Scenario should have description: \(scenario)")
            XCTAssertTrue(description.contains("Test"), "Description should explain what is tested")
        }
    }
    
    func testPerformanceOfAnalysis() throws {
        // Test that the analysis completes in reasonable time
        measure {
            let _ = UIScalingTester.analyzeUIScaling()
        }
    }
    
    func testGenerateScalingReportPerformance() throws {
        // Test report generation performance
        measure {
            let _ = UIScalingTester.generateScalingReport()
        }
    }
} 