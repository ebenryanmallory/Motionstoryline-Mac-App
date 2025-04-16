//
//  TemplateCardUITests.swift
//  Motion StorylineUITests
//
//  Created by rpf on 2/25/25.
//

import XCTest

final class TemplateCardUITests: XCTestCase {
    
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // Initialize the app
        app = XCUIApplication()
        
        // Set up test environment variables if needed
        app.launchEnvironment["UI_TESTING"] = "1"
        
        // Launch the app
        app.launch()
        
        // Wait for the home screen to fully load
        XCTAssertTrue(app.buttons["New Project"].waitForExistence(timeout: 5), "Home screen did not load properly")
        
        // Make sure we're in the Templates tab for each test
        let templatesTab = app.buttons["Templates"]
        XCTAssertTrue(templatesTab.waitForExistence(timeout: 2), "Templates tab not found")
        templatesTab.click()
    }
    
    override func tearDownWithError() throws {
        // Dismiss any open sheets or dialogs
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        }
        
        // Terminate the app between tests
        app.terminate()
        app = nil
        
        // Wait for any pending animations or operations to complete
        sleep(1)
    }
    
    @MainActor
    func testTemplateCardClicks() throws {
        // Wait a bit longer for the UI to fully initialize after clicking the Templates tab
        sleep(1)
        
        // Verify all template cards exist - use proper lookup and longer timeouts
        let websiteTemplate = app.otherElements.matching(identifier: "website-template").firstMatch
        let mobileAppTemplate = app.otherElements.matching(identifier: "mobile-app-template").firstMatch  
        let componentLibraryTemplate = app.otherElements.matching(identifier: "component-library-template").firstMatch
        let styleGuideTemplate = app.otherElements.matching(identifier: "style-guide-template").firstMatch
        
        XCTAssertTrue(websiteTemplate.waitForExistence(timeout: 5), "Website template card not found")
        XCTAssertTrue(mobileAppTemplate.waitForExistence(timeout: 5), "Mobile app template card not found")
        XCTAssertTrue(componentLibraryTemplate.waitForExistence(timeout: 5), "Component library template card not found")
        XCTAssertTrue(styleGuideTemplate.waitForExistence(timeout: 5), "Style guide template card not found")
        
        // Test clicking on the Website template card
        websiteTemplate.tap()
        
        // Verify that the new project sheet appears
        let newProjectSheet = app.otherElements.matching(identifier: "new-project-sheet").firstMatch
        XCTAssertTrue(newProjectSheet.waitForExistence(timeout: 5), "New project sheet did not appear after template click")
        
        // Verify the project type in the new project sheet is pre-selected to "Prototype"
        let selectedPrototypeCard = app.otherElements.matching(identifier: "selected-project-type-prototype").firstMatch
        XCTAssertTrue(selectedPrototypeCard.waitForExistence(timeout: 5), "Prototype type not pre-selected")
        
        // Cancel the new project sheet
        let cancelButton = app.buttons.matching(identifier: "Cancel").firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button not found in new project sheet")
        cancelButton.tap()
        
        // Verify the sheet is dismissed - wait a bit for the animation
        sleep(1)
        XCTAssertFalse(newProjectSheet.exists, "New project sheet was not dismissed")
        
        // Test clicking on another template card
        mobileAppTemplate.tap()
        XCTAssertTrue(newProjectSheet.waitForExistence(timeout: 5), "New project sheet did not appear after template click")
        
        // This time create a project
        let projectNameField = app.textFields.matching(identifier: "project-name-field").firstMatch
        XCTAssertTrue(projectNameField.waitForExistence(timeout: 5), "Project name field not found")
        projectNameField.tap()
        projectNameField.typeText("Test Project")
        
        let createButton = app.buttons.matching(identifier: "Create").firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create button not found")
        createButton.tap()
        
        // Verify the new project is created and the editor view opens
        // This would depend on your app's specific UI structure
        let editorView = app.otherElements.matching(identifier: "editor-view").firstMatch
        XCTAssertTrue(editorView.waitForExistence(timeout: 5), "Editor view did not appear after creating project")
    }
    
    @MainActor
    func testTemplateSpecificData() throws {
        // Wait a bit longer for the UI to fully initialize after clicking the Templates tab
        sleep(1)
        
        // Verify all template cards exist - use proper lookup and longer timeouts
        let websiteTemplate = app.otherElements.matching(identifier: "website-template").firstMatch
        let mobileAppTemplate = app.otherElements.matching(identifier: "mobile-app-template").firstMatch  
        let componentLibraryTemplate = app.otherElements.matching(identifier: "component-library-template").firstMatch
        let styleGuideTemplate = app.otherElements.matching(identifier: "style-guide-template").firstMatch
        
        XCTAssertTrue(websiteTemplate.waitForExistence(timeout: 5), "Website template card not found")
        XCTAssertTrue(mobileAppTemplate.waitForExistence(timeout: 5), "Mobile app template card not found")
        XCTAssertTrue(componentLibraryTemplate.waitForExistence(timeout: 5), "Component library template card not found")
        XCTAssertTrue(styleGuideTemplate.waitForExistence(timeout: 5), "Style guide template card not found")
        
        // Test each template type to verify it pre-selects the correct project type
        
        // 1. Mobile App Template (should pre-select Design)
        XCTAssertTrue(mobileAppTemplate.waitForExistence(timeout: 5), "Mobile app template not found")
        mobileAppTemplate.tap()
        
        let newProjectSheet = app.otherElements.matching(identifier: "new-project-sheet").firstMatch
        XCTAssertTrue(newProjectSheet.waitForExistence(timeout: 5), "New project sheet did not appear")
        
        // Verify "Design" is selected
        let selectedDesignCard = app.otherElements.matching(identifier: "selected-project-type-design").firstMatch
        XCTAssertTrue(selectedDesignCard.waitForExistence(timeout: 5), "Design type not pre-selected for Mobile App template")
        
        // Cancel and try another template
        let cancelButton = app.buttons.matching(identifier: "Cancel").firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button not found")
        cancelButton.tap()
        
        // Wait for animation
        sleep(1)
        
        // 2. Component Library Template
        XCTAssertTrue(componentLibraryTemplate.waitForExistence(timeout: 5), "Component library template not found")
        componentLibraryTemplate.tap()
        
        XCTAssertTrue(newProjectSheet.waitForExistence(timeout: 5), "New project sheet did not appear")
        
        // Verify "Component Library" is selected
        let selectedComponentLibraryCard = app.otherElements.matching(identifier: "selected-project-type-component-library").firstMatch
        XCTAssertTrue(selectedComponentLibraryCard.waitForExistence(timeout: 5), "Component Library type not pre-selected")
        
        // Cancel and try another template
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button not found")
        cancelButton.tap()
        
        // Wait for animation
        sleep(1)
        
        // 3. Style Guide Template
        XCTAssertTrue(styleGuideTemplate.waitForExistence(timeout: 5), "Style guide template not found")
        styleGuideTemplate.tap()
        
        XCTAssertTrue(newProjectSheet.waitForExistence(timeout: 5), "New project sheet did not appear")
        
        // Verify "Style Guide" is selected
        let selectedStyleGuideCard = app.otherElements.matching(identifier: "selected-project-type-style-guide").firstMatch
        XCTAssertTrue(selectedStyleGuideCard.waitForExistence(timeout: 5), "Style Guide type not pre-selected")
        
        // Finally create a project from a template
        let projectNameField = app.textFields.matching(identifier: "project-name-field").firstMatch
        XCTAssertTrue(projectNameField.waitForExistence(timeout: 5), "Project name field not found")
        projectNameField.tap()
        projectNameField.typeText("Style Guide Test")
        
        let createButton = app.buttons.matching(identifier: "Create").firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create button not found")
        createButton.tap()
        
        // Verify the project is created with the correct template type
        let editorView = app.otherElements.matching(identifier: "editor-view").firstMatch
        XCTAssertTrue(editorView.waitForExistence(timeout: 5), "Editor view did not appear")
        
        // Check for style guide specific elements 
        // (This will depend on how your app differentiates templates in the editor)
        let styleGuideElements = editorView.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "style-guide-"))
        XCTAssertGreaterThan(styleGuideElements.count, 0, "Style guide template elements not found in editor")
    }
} 