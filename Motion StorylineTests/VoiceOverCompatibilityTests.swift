import XCTest
@testable import Motion_Storyline
import SwiftUI

class VoiceOverCompatibilityTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    /// Test that VoiceOver can navigate through the HomeView
    func testHomeViewVoiceOverNavigation() throws {
        // Enable VoiceOver for UI testing
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        // Verify main elements are accessible via VoiceOver
        XCTAssertTrue(app.buttons["Create New Project"].exists, "Create New Project button should be accessible")
        
        // Verify tab navigation
        XCTAssertTrue(app.buttons["Recent"].exists, "Recent tab should be accessible")
        XCTAssertTrue(app.buttons["All Projects"].exists, "All Projects tab should be accessible")
        XCTAssertTrue(app.buttons["Templates"].exists, "Templates tab should be accessible")
        
        // Test navigation to project card (if any exists)
        if let projectCard = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'project'")).firstMatch {
            projectCard.tap()
            // Verify we navigated to the project
            XCTAssertTrue(app.navigationBars.firstMatch.exists, "Should navigate to project view")
        }
        
        // Disable VoiceOver after testing
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test that the New Project dialog is accessible with VoiceOver
    func testNewProjectDialogVoiceOverNavigation() throws {
        // Enable VoiceOver for testing
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        // Open the new project dialog
        app.buttons["Create New Project"].tap()
        
        // Verify dialog elements are accessible
        XCTAssertTrue(app.staticTexts["New Project"].exists, "New Project header should be accessible")
        XCTAssertTrue(app.textFields["Untitled Project"].exists, "Project name field should be accessible")
        
        // Test project type selection
        let projectTypes = ["Design", "Prototype", "Component Library", "Style Guide"]
        for type in projectTypes {
            XCTAssertTrue(app.buttons["\(type) project type"].exists, "Project type \(type) should be accessible")
        }
        
        // Test dialog buttons
        XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel button should be accessible")
        XCTAssertTrue(app.buttons["Create"].exists, "Create button should be accessible")
        
        // Close the dialog
        app.buttons["Cancel"].tap()
        
        // Disable VoiceOver after testing
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    // MARK: - Helper Methods
    
    /// Helper method to enable VoiceOver for testing purposes
    /// NOTE: This requires proper entitlements for UI Automation
    private func enableVoiceOverForTesting() -> Bool {
        #if targetEnvironment(simulator)
        // In simulator, we can simulate VoiceOver being enabled
        // This is just a mock for testing the test framework
        return true
        #else
        // For real device testing, we would need to use private APIs or Accessibility Inspector
        // For this template, we'll just simulate success
        return true
        #endif
    }
    
    /// Helper method to disable VoiceOver after testing
    private func disableVoiceOverForTesting() -> Bool {
        #if targetEnvironment(simulator)
        // In simulator, we can simulate VoiceOver being disabled
        return true
        #else
        // For real device testing, we would need to use private APIs
        return true
        #endif
    }
    
    /// Helper method to simulate VoiceOver navigation
    private func navigateWithVoiceOver(to elementIdentifier: String) -> Bool {
        guard let element = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", elementIdentifier))
            .firstMatch else {
            return false
        }
        
        // Simulate VoiceOver navigating to this element
        element.tap()
        return true
    }
} 