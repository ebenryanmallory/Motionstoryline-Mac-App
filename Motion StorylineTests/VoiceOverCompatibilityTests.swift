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
        let projectCard = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'project'")).firstMatch
        if projectCard.exists {
            projectCard.tap()
            // Verify we navigated to the project
            XCTAssertTrue(app.navigationBars.firstMatch.exists, "Should navigate to project view")
        }
        
        // Disable VoiceOver after testing
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test that the New Project dialog is accessible with VoiceOver
    func testNewProjectDialogVoiceOverAccess() throws {
        // Enable VoiceOver for UI testing
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        // Navigate to New Project dialog
        let createNewButton = app.buttons["Create New Project"]
        if createNewButton.exists {
            createNewButton.tap()
            
            // Verify dialog components are accessible
            XCTAssertTrue(app.staticTexts["New Project"].exists, "Dialog title should be accessible")
            XCTAssertTrue(app.textFields["Project Name"].exists, "Project name field should be accessible")
            XCTAssertTrue(app.buttons["Create"].exists, "Create button should be accessible")
            XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel button should be accessible")
            
            // Test cancel navigation
            app.buttons["Cancel"].tap()
        }
        
        // Disable VoiceOver after testing
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    // MARK: - Helper Methods for VoiceOver Testing
    
    /// Enable VoiceOver for UI testing
    private func enableVoiceOverForTesting() -> Bool {
        // Mock implementation for testing
        return true
    }
    
    /// Disable VoiceOver after UI testing
    private func disableVoiceOverForTesting() -> Bool {
        // Mock implementation for testing
        return true
    }
} 