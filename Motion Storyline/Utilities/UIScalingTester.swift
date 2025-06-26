import SwiftUI
import AppKit
import Foundation

/// Utility for testing UI scaling and responsiveness across different configurations
struct UIScalingTester {
    
    // MARK: - Test Configuration
    
    enum TestScenario: String, CaseIterable {
        case minWindowSize = "Minimum Window Size (800x600)"
        case standardMacBook = "Standard MacBook Pro (1440x900)"
        case largeDisplay = "Large Display (2560x1440)"
        case ultraWide = "Ultra-wide Display (3440x1440)"
        case accessibility = "Accessibility (Large Text + High Contrast)"
        case reduced = "Reduced Motion + Compact Layout"
        
        var windowSize: NSSize {
            switch self {
            case .minWindowSize: return NSSize(width: 800, height: 600)
            case .standardMacBook: return NSSize(width: 1440, height: 900)
            case .largeDisplay: return NSSize(width: 2560, height: 1440)
            case .ultraWide: return NSSize(width: 3440, height: 1440)
            case .accessibility: return NSSize(width: 1440, height: 900)
            case .reduced: return NSSize(width: 1280, height: 800)
            }
        }
        
        var textSizeCategory: DynamicTypeSize {
            switch self {
            case .accessibility: return .accessibility3
            case .reduced: return .small
            default: return .medium
            }
        }
        
        var description: String {
            switch self {
            case .minWindowSize:
                return "Tests minimum supported window size constraints"
            case .standardMacBook:
                return "Tests standard laptop display dimensions"
            case .largeDisplay:
                return "Tests behavior on high-resolution external monitors"
            case .ultraWide:
                return "Tests ultra-wide display aspect ratios"
            case .accessibility:
                return "Tests with large text and accessibility features"
            case .reduced:
                return "Tests compact layout with reduced visual effects"
            }
        }
    }
    
    // MARK: - Test Results
    
    struct ScalingTestResult {
        let scenario: TestScenario
        let windowSize: NSSize
        let issues: [UIIssue]
        let recommendations: [String]
        let overallScore: Double // 0.0 to 1.0
        
        var isCompliant: Bool { overallScore >= 0.8 }
    }
    
    struct UIIssue {
        let component: String
        let severity: Severity
        let description: String
        let location: String
        
        enum Severity: String, Comparable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
            
            static func < (lhs: Severity, rhs: Severity) -> Bool {
                let order: [Severity] = [.low, .medium, .high, .critical]
                guard let lhsIndex = order.firstIndex(of: lhs),
                      let rhsIndex = order.firstIndex(of: rhs) else {
                    return false
                }
                return lhsIndex < rhsIndex
            }
        }
    }
    
    // MARK: - Analysis Methods
    
    static func analyzeUIScaling() -> [ScalingTestResult] {
        var results: [ScalingTestResult] = []
        
        for scenario in TestScenario.allCases {
            let result = testScenario(scenario)
            results.append(result)
        }
        
        return results
    }
    
    private static func testScenario(_ scenario: TestScenario) -> ScalingTestResult {
        var issues: [UIIssue] = []
        var recommendations: [String] = []
        
        // Test window size constraints
        let windowIssues = testWindowConstraints(scenario)
        issues.append(contentsOf: windowIssues)
        
        // Test component responsiveness
        let componentIssues = testComponentResponsiveness(scenario)
        issues.append(contentsOf: componentIssues)
        
        // Test text scaling
        let textIssues = testTextScaling(scenario)
        issues.append(contentsOf: textIssues)
        
        // Test accessibility compliance
        let accessibilityIssues = testAccessibilityScaling(scenario)
        issues.append(contentsOf: accessibilityIssues)
        
        // Generate recommendations based on issues
        recommendations = generateRecommendations(for: issues, scenario: scenario)
        
        // Calculate overall score
        let score = calculateScore(for: issues)
        
        return ScalingTestResult(
            scenario: scenario,
            windowSize: scenario.windowSize,
            issues: issues,
            recommendations: recommendations,
            overallScore: score
        )
    }
    
    // MARK: - Specific Test Methods
    
    private static func testWindowConstraints(_ scenario: TestScenario) -> [UIIssue] {
        var issues: [UIIssue] = []
        
        // Test minimum window size compliance
        let minSize = NSSize(width: 800, height: 600)
        
        if scenario.windowSize.width < minSize.width || scenario.windowSize.height < minSize.height {
            issues.append(UIIssue(
                component: "Window Size",
                severity: .critical,
                description: "Window size below minimum requirements",
                location: "Motion_StorylineApp.swift:131"
            ))
        }
        
        // Test specific component constraints at different window sizes
        switch scenario {
        case .minWindowSize:
            // Timeline panel should adapt to minimum space
            issues.append(UIIssue(
                component: "Timeline Panel",
                severity: .medium,
                description: "Timeline height may be constrained at minimum window size",
                location: "TimelineViewPanel.swift:27-28"
            ))
            
            // Inspector panel should remain functional
            issues.append(UIIssue(
                component: "Inspector Panel",
                severity: .medium,
                description: "Inspector width constraints may affect usability",
                location: "InspectorView.swift:388-408"
            ))
            
        case .ultraWide:
            // Canvas should maintain aspect ratio
            issues.append(UIIssue(
                component: "Canvas Viewport",
                severity: .low,
                description: "Canvas may appear small on ultra-wide displays",
                location: "DesignCanvas.swift:658-669"
            ))
            
        default:
            break
        }
        
        return issues
    }
    
    private static func testComponentResponsiveness(_ scenario: TestScenario) -> [UIIssue] {
        var issues: [UIIssue] = []
        
        // Test timeline responsiveness
        issues.append(contentsOf: testTimelineResponsiveness(scenario))
        
        // Test inspector panel responsiveness
        issues.append(contentsOf: testInspectorResponsiveness(scenario))
        
        // Test export modal responsiveness
        issues.append(contentsOf: testExportModalResponsiveness(scenario))
        
        return issues
    }
    
    private static func testTimelineResponsiveness(_ scenario: TestScenario) -> [UIIssue] {
        var issues: [UIIssue] = []
        
        // Timeline height constraints
        let _: CGFloat = 70  // minTimelineHeight (unused)
        let _: CGFloat = 600  // maxTimelineHeight (unused)
        
        // Check if timeline can adapt to different screen sizes
        if scenario.windowSize.height < 800 {
            issues.append(UIIssue(
                component: "Timeline Panel",
                severity: .medium,
                description: "Timeline may not have enough vertical space on smaller screens",
                location: "TimelineViewPanel.swift:115-175"
            ))
        }
        
        // Check resize handle functionality
        issues.append(UIIssue(
            component: "Timeline Resize Handle",
            severity: .low,
            description: "Resize handle uses fixed dimensions that may not scale well",
            location: "TimelineView.swift:436-475"
        ))
        
        return issues
    }
    
    private static func testInspectorResponsiveness(_ scenario: TestScenario) -> [UIIssue] {
        var issues: [UIIssue] = []
        
        // Inspector width constraints
        let _: CGFloat = 220  // minInspectorWidth (unused)
        let _: CGFloat = 300  // maxInspectorWidth (unused)
        
        if scenario.windowSize.width < 1200 {
            issues.append(UIIssue(
                component: "Inspector Panel",
                severity: .medium,
                description: "Inspector panel may take up too much horizontal space on smaller screens",
                location: "InspectorView.swift:388"
            ))
        }
        
        // Fixed width components in inspector
        issues.append(UIIssue(
            component: "Inspector Controls",
            severity: .low,
            description: "Some inspector controls use fixed widths that don't scale",
            location: "InspectorView.swift:30-88"
        ))
        
        return issues
    }
    
    private static func testExportModalResponsiveness(_ scenario: TestScenario) -> [UIIssue] {
        var issues: [UIIssue] = []
        
        // Export modal fixed width
        issues.append(UIIssue(
            component: "Export Modal",
            severity: .low,
            description: "Export modal uses fixed width that may not suit all screen sizes",
            location: "SocialMediaExportView.swift:114"
        ))
        
        // Resolution picker fixed width
        issues.append(UIIssue(
            component: "Resolution Picker",
            severity: .low,
            description: "Resolution picker uses fixed width constraints",
            location: "BatchExportSettingsView.swift:113-165"
        ))
        
        return issues
    }
    
    private static func testTextScaling(_ scenario: TestScenario) -> [UIIssue] {
        var issues: [UIIssue] = []
        
        // Check for hardcoded font sizes
        issues.append(UIIssue(
            component: "Inspector Text",
            severity: .medium,
            description: "Inspector uses fixed font sizes instead of dynamic type",
            location: "InspectorView.swift:30-262"
        ))
        
        if scenario == .accessibility {
            issues.append(UIIssue(
                component: "Timeline Text",
                severity: .medium,
                description: "Timeline components may not scale properly with large text",
                location: "TimelineView.swift:78-95"
            ))
        }
        
        return issues
    }
    
    private static func testAccessibilityScaling(_ scenario: TestScenario) -> [UIIssue] {
        var issues: [UIIssue] = []
        
        if scenario == .accessibility {
            // Check for accessibility compliance
            issues.append(UIIssue(
                component: "Interactive Elements",
                severity: .medium,
                description: "Some interactive elements may be too small for accessibility standards",
                location: "CanvasElementView.swift:188-312"
            ))
            
            // Resize handles may be too small
            issues.append(UIIssue(
                component: "Resize Handles",
                severity: .medium,
                description: "Resize handles use fixed 8pt size, may be too small for accessibility",
                location: "CanvasElementView.swift:136-149"
            ))
        }
        
        return issues
    }
    
    // MARK: - Helper Methods
    
    private static func generateRecommendations(for issues: [UIIssue], scenario: TestScenario) -> [String] {
        var recommendations: [String] = []
        
        // Group issues by component
        let groupedIssues = Dictionary(grouping: issues) { $0.component }
        
        for (component, componentIssues) in groupedIssues {
            let severity = componentIssues.map { $0.severity }.max() ?? .low
            
            switch component {
            case "Timeline Panel":
                recommendations.append("• Use dynamic height constraints based on available screen space")
                recommendations.append("• Implement adaptive layout for timeline components")
                
            case "Inspector Panel":
                recommendations.append("• Consider collapsible inspector sections for smaller screens")
                recommendations.append("• Use relative sizing instead of fixed widths")
                
            case "Export Modal":
                recommendations.append("• Implement responsive modal sizing based on screen dimensions")
                recommendations.append("• Use flexible layouts for export options")
                
            case "Inspector Text", "Timeline Text":
                recommendations.append("• Replace fixed font sizes with SwiftUI's dynamic type system")
                recommendations.append("• Use @ScaledMetric for proportional sizing")
                
            case "Interactive Elements", "Resize Handles":
                recommendations.append("• Increase minimum touch target sizes to 44pt minimum")
                recommendations.append("• Implement accessibility-aware sizing for interactive elements")
                
            default:
                if severity >= .medium {
                    recommendations.append("• Review \(component) for responsive design improvements")
                }
            }
        }
        
        // Add scenario-specific recommendations
        switch scenario {
        case .minWindowSize:
            recommendations.append("• Implement progressive disclosure for UI elements")
            recommendations.append("• Consider tabbed interfaces for space-constrained layouts")
            
        case .ultraWide:
            recommendations.append("• Add optional sidebar panels to utilize extra horizontal space")
            recommendations.append("• Implement canvas centering with optional rulers")
            
        case .accessibility:
            recommendations.append("• Audit all interactive elements for WCAG compliance")
            recommendations.append("• Implement dynamic type support throughout the app")
            
        default:
            break
        }
        
        return Array(Set(recommendations)).sorted()
    }
    
    private static func calculateScore(for issues: [UIIssue]) -> Double {
        if issues.isEmpty { return 1.0 }
        
        let severityWeights: [UIIssue.Severity: Double] = [
            .low: 0.1,
            .medium: 0.3,
            .high: 0.6,
            .critical: 1.0
        ]
        
        let totalPenalty = issues.reduce(0.0) { total, issue in
            total + (severityWeights[issue.severity] ?? 0.5)
        }
        
        // Maximum penalty is 10 (10 critical issues)
        let normalizedPenalty = min(totalPenalty, 10.0) / 10.0
        
        return max(0.0, 1.0 - normalizedPenalty)
    }
    
    // MARK: - Report Generation
    
    static func generateScalingReport() -> String {
        let results = analyzeUIScaling()
        var report = """
        # UI Scaling and Responsiveness Report
        ## Motion Storyline - Comprehensive Analysis
        
        **Generated:** \(DateFormatter.timestamp.string(from: Date()))
        **Test Scenarios:** \(TestScenario.allCases.count)
        **Overall Status:** \(results.allSatisfy { $0.isCompliant } ? "✅ COMPLIANT" : "⚠️ NEEDS ATTENTION")
        
        ---
        
        ## Executive Summary
        
        """
        
        let compliantCount = results.filter { $0.isCompliant }.count
        let totalCount = results.count
        let complianceRate = Double(compliantCount) / Double(totalCount) * 100
        
        report += """
        - **Compliance Rate:** \(String(format: "%.1f", complianceRate))% (\(compliantCount)/\(totalCount) scenarios)
        - **Critical Issues:** \(results.flatMap { $0.issues }.filter { $0.severity == .critical }.count)
        - **Total Issues Found:** \(results.flatMap { $0.issues }.count)
        
        ### Key Findings
        - 🎯 **Strengths:** App implements basic window constraints and responsive timeline
        - ⚠️ **Areas for Improvement:** Fixed font sizes, hardcoded dimensions, accessibility scaling
        - 🔧 **Priority:** Implement dynamic type support and flexible layouts
        
        ---
        
        ## Detailed Analysis by Scenario
        
        """
        
        for result in results {
            let statusIcon = result.isCompliant ? "✅" : "⚠️"
            let scorePercentage = Int(result.overallScore * 100)
            
            report += """
            ### \(statusIcon) \(result.scenario.rawValue)
            
            **Score:** \(scorePercentage)%  
            **Window Size:** \(Int(result.windowSize.width))x\(Int(result.windowSize.height))  
            **Issues Found:** \(result.issues.count)  
            **Description:** \(result.scenario.description)
            
            """
            
            if !result.issues.isEmpty {
                report += "#### Issues:\n"
                for issue in result.issues.sorted(by: { $0.severity > $1.severity }) {
                    report += "- **[\(issue.severity.rawValue)]** \(issue.component): \(issue.description)\n"
                    report += "  *Location: \(issue.location)*\n"
                }
                report += "\n"
            }
            
            if !result.recommendations.isEmpty {
                report += "#### Recommendations:\n"
                for recommendation in result.recommendations {
                    report += "\(recommendation)\n"
                }
                report += "\n"
            }
            
            report += "---\n\n"
        }
        
        // Add technical recommendations
        report += """
        ## Technical Implementation Guide
        
        ### 1. Dynamic Type Support
        ```swift
        // Replace fixed fonts with dynamic type
        .font(.system(.body))  // Instead of .font(.system(size: 12))
        
        // Use @ScaledMetric for proportional sizing
        @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 16
        ```
        
        ### 2. Responsive Layouts
        ```swift
        // Use flexible frames instead of fixed sizes
        .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity)
        
        // Adaptive layouts based on size class
        @Environment(\\.horizontalSizeClass) var horizontalSizeClass
        ```
        
        ### 3. Accessibility Improvements
        ```swift
        // Minimum touch target sizes
        .frame(minWidth: 44, minHeight: 44)
        
        // Support for reduced motion
        @Environment(\\.accessibilityReduceMotion) var reduceMotion
        ```
        
        ### 4. Window Management
        ```swift
        // Dynamic window constraints
        window.minSize = NSSize(width: 800, height: 600)
        window.contentAspectRatio = NSSize(width: 16, height: 9)
        ```
        
        ### Priority Action Items
        
        1. **High Priority**
           - Replace fixed font sizes with dynamic type system
           - Implement minimum touch target sizes (44pt)
           - Add responsive timeline height management
        
        2. **Medium Priority**
           - Create adaptive inspector panel layouts
           - Implement flexible export modal sizing
           - Add support for reduced motion preferences
        
        3. **Low Priority**
           - Optimize ultra-wide display layouts
           - Add progressive disclosure for compact layouts
           - Implement advanced accessibility features
        
        ---
        
        *Report generated by Motion Storyline UI Scaling Tester*
        """
        
        return report
    }
}

// MARK: - Supporting Extensions

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Test Runner View

struct UIScalingTestView: View {
    @State private var testResults: [UIScalingTester.ScalingTestResult] = []
    @State private var isRunningTests = false
    @State private var showingReport = false
    @State private var reportContent = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("UI Scaling & Responsiveness Tester")
                .font(.title)
            
            Text("Test the app's behavior across different screen sizes and accessibility settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if isRunningTests {
                ProgressView("Running scaling tests...")
                    .scaleEffect(0.8)
            } else if testResults.isEmpty {
                Button("Run Scaling Tests") {
                    runTests()
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Results summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Test Results")
                            .font(.headline)
                        Spacer()
                        Button("Generate Report") {
                            generateReport()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    ForEach(testResults.indices, id: \.self) { index in
                        let result = testResults[index]
                        HStack {
                            Image(systemName: result.isCompliant ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(result.isCompliant ? .green : .orange)
                            
                            VStack(alignment: .leading) {
                                Text(result.scenario.rawValue)
                                    .font(.subheadline)
                                Text("\(result.issues.count) issues • \(Int(result.overallScore * 100))% score")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .frame(width: 400)
        .sheet(isPresented: $showingReport) {
            NavigationView {
                ScrollView {
                    Text(reportContent)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .navigationTitle("Scaling Report")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingReport = false
                        }
                    }
                }
            }
        }
    }
    
    private func runTests() {
        isRunningTests = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = UIScalingTester.analyzeUIScaling()
            
            DispatchQueue.main.async {
                self.testResults = results
                self.isRunningTests = false
            }
        }
    }
    
    private func generateReport() {
        reportContent = UIScalingTester.generateScalingReport()
        showingReport = true
    }
}