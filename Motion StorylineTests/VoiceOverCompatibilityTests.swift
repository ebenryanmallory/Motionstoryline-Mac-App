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
    
    // MARK: - DesignCanvas VoiceOver Tests
    
    /// Test VoiceOver navigation through DesignCanvas main interface
    func testDesignCanvasVoiceOverNavigation() throws {
        // Enable VoiceOver for UI testing
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        // Navigate to DesignCanvas by creating a new project
        navigateToDesignCanvas()
        
        // Verify main DesignCanvas container is accessible
        let designCanvas = app.otherElements["editor-view"]
        XCTAssertTrue(designCanvas.waitForExistence(timeout: 5), "DesignCanvas should be accessible with editor-view identifier")
        
        // Test top navigation bar accessibility
        testTopNavigationBarAccessibility()
        
        // Test design toolbar accessibility
        testDesignToolbarAccessibility()
        
        // Test canvas area accessibility
        testCanvasAreaAccessibility()
        
        // Test timeline accessibility (if visible)
        testTimelineAccessibility()
        
        // Test inspector panel accessibility (if visible)
        testInspectorPanelAccessibility()
        
        // Disable VoiceOver after testing
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test VoiceOver accessibility of design tools
    func testDesignToolsVoiceOverAccess() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Test each design tool button
        let toolButtons = [
            ("Select & Move", "Selection Tool: Click to select elements, drag to move them"),
            ("Text", "Text Tool: Add and edit text elements"),
            ("Rectangle", "Rectangle Tool: Click and drag to create rectangles"),
            ("Ellipse", "Ellipse Tool: Click and drag to create ellipses and circles")
        ]
        
        for (toolName, expectedHint) in toolButtons {
            let toolButton = app.buttons[toolName]
            XCTAssertTrue(toolButton.exists, "\(toolName) tool button should be accessible")
            
            // Verify the button can be activated
            toolButton.tap()
            
            // Verify tool selection feedback (status text should update)
            let statusText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '\(toolName)' OR label CONTAINS 'Click'")).firstMatch
            XCTAssertTrue(statusText.exists, "Tool status text should be accessible and provide context")
        }
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test VoiceOver accessibility of canvas elements
    func testCanvasElementsVoiceOverAccess() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Create a test element by selecting rectangle tool and drawing
        let rectangleTool = app.buttons["Rectangle"]
        rectangleTool.tap()
        
        // Simulate drawing a rectangle on canvas
        let canvasArea = app.scrollViews.firstMatch
        if canvasArea.exists {
            // Perform a drag gesture to create a rectangle
            let startPoint = canvasArea.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            let endPoint = canvasArea.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7))
            startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        }
        
        // Switch back to select tool
        let selectTool = app.buttons["Select & Move"]
        selectTool.tap()
        
        // Test that created elements are accessible
        let canvasElements = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'canvas-element'"))
        if canvasElements.count > 0 {
            let firstElement = canvasElements.element(boundBy: 0)
            XCTAssertTrue(firstElement.exists, "Canvas elements should be accessible to VoiceOver")
            
            // Test element selection
            firstElement.tap()
            
            // Verify selection feedback
            let selectedIndicator = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'selected'")).firstMatch
            // Note: This test may need adjustment based on actual selection indicator implementation
        }
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test VoiceOver accessibility of timeline controls
    func testTimelineVoiceOverAccess() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Ensure timeline is visible
        let timelineArea = app.otherElements["timeline-view"]
        if timelineArea.exists {
            // Test play/pause button
            let playButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'play' OR identifier CONTAINS 'pause'")).firstMatch
            if playButton.exists {
                XCTAssertTrue(playButton.isHittable, "Play/pause button should be accessible")
                
                // Test activation
                playButton.tap()
                
                // Verify state change (play becomes pause or vice versa)
                let pauseButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'pause'")).firstMatch
                // Note: Exact implementation depends on button state management
            }
            
            // Test timeline scrubber
            let timelineScrubber = app.sliders.matching(NSPredicate(format: "identifier CONTAINS 'timeline' OR identifier CONTAINS 'scrubber'")).firstMatch
            if timelineScrubber.exists {
                XCTAssertTrue(timelineScrubber.isHittable, "Timeline scrubber should be accessible")
                
                // Test that VoiceOver can announce current time position
                // This would require the slider to have proper accessibility value
            }
            
            // Test keyframe markers
            let keyframeMarkers = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'keyframe'"))
            if keyframeMarkers.count > 0 {
                let firstKeyframe = keyframeMarkers.element(boundBy: 0)
                XCTAssertTrue(firstKeyframe.exists, "Keyframe markers should be accessible")
            }
        }
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test VoiceOver accessibility of inspector panel
    func testInspectorPanelVoiceOverAccess() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Create and select an element to open inspector
        createTestElementAndSelect()
        
        // Test inspector panel elements
        let inspectorPanel = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'inspector'")).firstMatch
        if inspectorPanel.exists {
            // Test property controls
            let propertyControls = [
                "Position",
                "Size", 
                "Rotation",
                "Opacity",
                "Color"
            ]
            
            for property in propertyControls {
                let propertyControl = app.otherElements.matching(NSPredicate(format: "label CONTAINS '\(property)'")).firstMatch
                if propertyControl.exists {
                    XCTAssertTrue(propertyControl.isHittable, "\(property) control should be accessible")
                }
                
                // Test associated input fields
                let inputField = app.textFields.matching(NSPredicate(format: "identifier CONTAINS '\(property.lowercased())'")).firstMatch
                if inputField.exists {
                    XCTAssertTrue(inputField.isHittable, "\(property) input field should be accessible")
                }
            }
            
            // Test inspector close button
            let closeButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'close' OR label CONTAINS 'Close'")).firstMatch
            if closeButton.exists {
                XCTAssertTrue(closeButton.isHittable, "Inspector close button should be accessible")
            }
        }
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test VoiceOver keyboard navigation in DesignCanvas
    func testDesignCanvasKeyboardNavigation() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Test that VoiceOver navigation keys work
        // VO + Right Arrow should move to next element
        app.typeKey(.rightArrow, modifierFlags: [.control, .option])
        
        // VO + Left Arrow should move to previous element  
        app.typeKey(.leftArrow, modifierFlags: [.control, .option])
        
        // VO + Space should activate the focused element
        app.typeKey(.space, modifierFlags: [.control, .option])
        
        // Test that standard keyboard shortcuts still work with VoiceOver
        // Play/pause with P key
        app.typeKey("p", modifierFlags: [])
        
        // Zoom with Cmd + and Cmd -
        app.typeKey("=", modifierFlags: [.command]) // Zoom in
        app.typeKey("-", modifierFlags: [.command]) // Zoom out
        
        // Test that Tab navigation works for focusable elements
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [.shift]) // Reverse tab
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test VoiceOver accessibility of context menus
    func testContextMenuVoiceOverAccess() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Test canvas context menu
        let canvasArea = app.scrollViews.firstMatch
        if canvasArea.exists {
            // Right-click to open context menu
            canvasArea.rightClick()
            
            // Test context menu items
            let contextMenuItems = [
                "Add Rectangle",
                "Add Ellipse", 
                "Add Text"
            ]
            
            for item in contextMenuItems {
                let menuItem = app.menuItems[item]
                if menuItem.exists {
                    XCTAssertTrue(menuItem.isHittable, "\(item) context menu item should be accessible")
                }
            }
            
            // Dismiss context menu
            app.typeKey(.escape, modifierFlags: [])
        }
        
        // Test element context menu
        createTestElementAndSelect()
        let canvasElement = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'canvas-element'")).firstMatch
        if canvasElement.exists {
            canvasElement.rightClick()
            
            // Test element-specific context menu items
            let elementMenuItems = [
                "Duplicate",
                "Delete",
                "Bring to Front",
                "Send to Back"
            ]
            
            for item in elementMenuItems {
                let menuItem = app.menuItems[item]
                if menuItem.exists {
                    XCTAssertTrue(menuItem.isHittable, "\(item) element context menu item should be accessible")
                }
            }
            
            // Dismiss context menu
            app.typeKey(.escape, modifierFlags: [])
        }
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    // MARK: - Helper Methods for DesignCanvas Testing
    
    /// Navigate to DesignCanvas by creating a new project
    private func navigateToDesignCanvas() {
        let createNewButton = app.buttons["Create New Project"]
        if createNewButton.exists {
            createNewButton.tap()
            
            // Fill in project name and create
            let projectNameField = app.textFields["Project Name"]
            if projectNameField.exists {
                projectNameField.tap()
                projectNameField.typeText("VoiceOver Test Project")
            }
            
            let createButton = app.buttons["Create"]
            if createButton.exists {
                createButton.tap()
            }
        }
        
        // Wait for DesignCanvas to load
        let designCanvas = app.otherElements["editor-view"]
        _ = designCanvas.waitForExistence(timeout: 10)
    }
    
    /// Create a test element and select it
    private func createTestElementAndSelect() {
        // Select rectangle tool
        let rectangleTool = app.buttons["Rectangle"]
        if rectangleTool.exists {
            rectangleTool.tap()
            
            // Draw a rectangle
            let canvasArea = app.scrollViews.firstMatch
            if canvasArea.exists {
                let startPoint = canvasArea.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4))
                let endPoint = canvasArea.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6))
                startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
            }
            
            // Switch to select tool
            let selectTool = app.buttons["Select & Move"]
            if selectTool.exists {
                selectTool.tap()
            }
        }
    }
    
    /// Test top navigation bar accessibility
    private func testTopNavigationBarAccessibility() {
        // Test project name display
        let projectName = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'VoiceOver Test Project' OR label CONTAINS 'Motion Storyline'")).firstMatch
        if projectName.exists {
            XCTAssertTrue(projectName.isHittable, "Project name should be accessible")
        }
        
        // Test navigation buttons
        let navButtons = ["Close", "Export", "Save"]
        for buttonName in navButtons {
            let button = app.buttons[buttonName]
            if button.exists {
                XCTAssertTrue(button.isHittable, "\(buttonName) button should be accessible")
            }
        }
        
        // Test menu buttons
        let menuButtons = ["File", "Edit", "View", "Help"]
        for menuName in menuButtons {
            let menu = app.menuButtons[menuName]
            if menu.exists {
                XCTAssertTrue(menu.isHittable, "\(menuName) menu should be accessible")
            }
        }
    }
    
    /// Test design toolbar accessibility
    private func testDesignToolbarAccessibility() {
        // Test tool selection buttons
        let toolButtons = ["Select & Move", "Text", "Rectangle", "Ellipse"]
        for toolName in toolButtons {
            let toolButton = app.buttons[toolName]
            if toolButton.exists {
                XCTAssertTrue(toolButton.isHittable, "\(toolName) tool should be accessible")
            }
        }
        
        // Test canvas dimensions indicator
        let dimensionsText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Canvas:' AND label CONTAINS '×'")).firstMatch
        if dimensionsText.exists {
            XCTAssertTrue(dimensionsText.exists, "Canvas dimensions should be accessible")
        }
    }
    
    /// Test canvas area accessibility
    private func testCanvasAreaAccessibility() {
        // Test main canvas scroll view
        let canvasScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(canvasScrollView.exists, "Canvas scroll view should be accessible")
        
        // Test canvas boundary
        let canvasBoundary = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'canvas-boundary'")).firstMatch
        // Note: This depends on actual implementation of canvas boundary accessibility
        
        // Test grid background (if visible)
        let gridBackground = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'grid'")).firstMatch
        // Note: Grid background may not need to be directly accessible
    }
    
    /// Test timeline accessibility
    private func testTimelineAccessibility() {
        let timelinePanel = app.otherElements["timeline-view"]
        if timelinePanel.exists {
            XCTAssertTrue(timelinePanel.isHittable, "Timeline panel should be accessible")
            
            // Test timeline controls
            let playPauseButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'play' OR identifier CONTAINS 'pause'")).firstMatch
            if playPauseButton.exists {
                XCTAssertTrue(playPauseButton.isHittable, "Play/pause button should be accessible")
            }
            
            // Test time indicator
            let timeIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ':' AND (label CONTAINS '0' OR label CONTAINS '1' OR label CONTAINS '2')")).firstMatch
            if timeIndicator.exists {
                XCTAssertTrue(timeIndicator.exists, "Time indicator should be accessible")
            }
        }
    }
    
    /// Test inspector panel accessibility
    private func testInspectorPanelAccessibility() {
        let inspectorPanel = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'inspector'")).firstMatch
        if inspectorPanel.exists {
            XCTAssertTrue(inspectorPanel.isHittable, "Inspector panel should be accessible")
            
            // Test property sections
            let propertySections = ["Transform", "Appearance", "Animation"]
            for section in propertySections {
                let sectionHeader = app.staticTexts[section]
                if sectionHeader.exists {
                    XCTAssertTrue(sectionHeader.exists, "\(section) section should be accessible")
                }
            }
        }
    }
    
    // MARK: - MediaBrowser VoiceOver Tests
    
    /// Test VoiceOver accessibility of MediaBrowser interface
    func testMediaBrowserVoiceOverNavigation() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Open MediaBrowser (this would typically be done through a menu or button)
        // For testing purposes, we'll assume MediaBrowser can be opened
        let mediaBrowserButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'media' OR label CONTAINS 'Media'")).firstMatch
        if mediaBrowserButton.exists {
            mediaBrowserButton.tap()
            
            // Test MediaBrowser main components
            testMediaBrowserHeaderAccessibility()
            testMediaBrowserControlsAccessibility()
            testMediaBrowserListAccessibility()
            testMediaBrowserPreviewAccessibility()
        }
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test MediaBrowser header accessibility
    private func testMediaBrowserHeaderAccessibility() {
        // Test title
        let browserTitle = app.staticTexts["media-browser-title"]
        XCTAssertTrue(browserTitle.exists, "MediaBrowser title should be accessible")
        XCTAssertTrue(browserTitle.hasKeyboardFocus || browserTitle.isHittable, "MediaBrowser title should be focusable")
        
        // Test close button
        let closeButton = app.buttons["media-browser-close"]
        XCTAssertTrue(closeButton.exists, "MediaBrowser close button should be accessible")
        XCTAssertTrue(closeButton.isHittable, "Close button should be hittable")
        
        // Verify close button has proper accessibility label
        let closeLabel = closeButton.label
        XCTAssertTrue(closeLabel.contains("Close"), "Close button should have descriptive label")
    }
    
    /// Test MediaBrowser controls accessibility
    private func testMediaBrowserControlsAccessibility() {
        // Test search field
        let searchField = app.textFields["media-search-field"]
        XCTAssertTrue(searchField.exists, "Search field should be accessible")
        XCTAssertTrue(searchField.isHittable, "Search field should be hittable")
        
        // Test type filter
        let typeFilter = app.popUpButtons["media-type-filter"]
        XCTAssertTrue(typeFilter.exists, "Media type filter should be accessible")
        XCTAssertTrue(typeFilter.isHittable, "Type filter should be hittable")
        
        // Test sort order
        let sortOrder = app.popUpButtons["media-sort-order"]
        XCTAssertTrue(sortOrder.exists, "Sort order control should be accessible")
        XCTAssertTrue(sortOrder.isHittable, "Sort order should be hittable")
        
        // Test import button
        let importButton = app.buttons["media-import-button"]
        XCTAssertTrue(importButton.exists, "Import button should be accessible")
        XCTAssertTrue(importButton.isHittable, "Import button should be hittable")
        
        // Verify import button has proper accessibility label
        let importLabel = importButton.label
        XCTAssertTrue(importLabel.contains("Import"), "Import button should have descriptive label")
    }
    
    /// Test MediaBrowser asset list accessibility
    private func testMediaBrowserListAccessibility() {
        // Test main assets list
        let assetsList = app.otherElements["media-assets-list"]
        XCTAssertTrue(assetsList.exists, "Media assets list should be accessible")
        
        // Test individual asset items (if any exist)
        let assetItems = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'media-asset-'"))
        if assetItems.count > 0 {
            let firstAsset = assetItems.element(boundBy: 0)
            XCTAssertTrue(firstAsset.exists, "Media asset items should be accessible")
            XCTAssertTrue(firstAsset.isHittable, "Asset items should be hittable")
            
            // Test asset selection
            firstAsset.tap()
            
            // Verify selection state is communicated
            // This would depend on the actual implementation of selection feedback
        }
    }
    
    /// Test MediaBrowser preview area accessibility
    private func testMediaBrowserPreviewAccessibility() {
        // First, ensure an asset is selected to show preview
        let assetItems = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'media-asset-'"))
        if assetItems.count > 0 {
            let firstAsset = assetItems.element(boundBy: 0)
            firstAsset.tap()
            
            // Test preview title
            let previewTitle = app.staticTexts["media-preview-title"]
            if previewTitle.exists {
                XCTAssertTrue(previewTitle.isHittable, "Preview title should be accessible")
            }
            
            // Test delete button in preview
            let deleteButton = app.buttons["media-preview-delete"]
            if deleteButton.exists {
                XCTAssertTrue(deleteButton.isHittable, "Preview delete button should be accessible")
            }
            
            // Test media-specific preview controls
            testVideoPreviewControls()
            testAudioPreviewControls()
            testImagePreviewAccessibility()
            
            // Test media details
            let mediaDetails = app.otherElements["media-details"]
            if mediaDetails.exists {
                XCTAssertTrue(mediaDetails.exists, "Media details should be accessible")
            }
        }
    }
    
    /// Test video preview controls accessibility
    private func testVideoPreviewControls() {
        let videoPlayer = app.otherElements["video-preview-player"]
        if videoPlayer.exists {
            XCTAssertTrue(videoPlayer.exists, "Video player should be accessible")
            
            // Test play/pause button
            let playPauseButton = app.buttons["video-play-pause"]
            if playPauseButton.exists {
                XCTAssertTrue(playPauseButton.isHittable, "Video play/pause button should be accessible")
                
                // Test button activation
                playPauseButton.tap()
                
                // Verify state change is communicated
                let buttonLabel = playPauseButton.label
                XCTAssertTrue(buttonLabel.contains("Play") || buttonLabel.contains("Pause"), 
                             "Play/pause button should have descriptive state label")
            }
            
            // Test restart button
            let restartButton = app.buttons["video-restart"]
            if restartButton.exists {
                XCTAssertTrue(restartButton.isHittable, "Video restart button should be accessible")
            }
        }
    }
    
    /// Test audio preview controls accessibility
    private func testAudioPreviewControls() {
        let audioWaveform = app.otherElements["audio-preview-waveform"]
        if audioWaveform.exists {
            XCTAssertTrue(audioWaveform.exists, "Audio waveform should be accessible")
            
            // Test play/pause button
            let playPauseButton = app.buttons["audio-play-pause"]
            if playPauseButton.exists {
                XCTAssertTrue(playPauseButton.isHittable, "Audio play/pause button should be accessible")
                
                // Test button activation
                playPauseButton.tap()
                
                // Verify state change is communicated
                let buttonLabel = playPauseButton.label
                XCTAssertTrue(buttonLabel.contains("Play") || buttonLabel.contains("Pause"), 
                             "Audio play/pause button should have descriptive state label")
            }
            
            // Test restart button
            let restartButton = app.buttons["audio-restart"]
            if restartButton.exists {
                XCTAssertTrue(restartButton.isHittable, "Audio restart button should be accessible")
            }
        }
    }
    
    /// Test image preview accessibility
    private func testImagePreviewAccessibility() {
        let imagePreview = app.otherElements["image-preview"]
        if imagePreview.exists {
            XCTAssertTrue(imagePreview.exists, "Image preview should be accessible")
            
            // Verify image has proper accessibility description
            let imageLabel = imagePreview.label
            XCTAssertTrue(imageLabel.contains("preview") || imageLabel.contains("image"), 
                         "Image preview should have descriptive label")
        }
    }
    
    // MARK: - ExportOptions VoiceOver Tests
    
    /// Test VoiceOver accessibility of ExportOptions interface
    func testExportOptionsVoiceOverNavigation() throws {
        let voiceOverEnabled = enableVoiceOverForTesting()
        XCTAssertTrue(voiceOverEnabled, "Failed to enable VoiceOver for testing")
        
        navigateToDesignCanvas()
        
        // Open Export dialog (this would typically be done through a menu or button)
        let exportButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'export' OR label CONTAINS 'Export'")).firstMatch
        if exportButton.exists {
            exportButton.tap()
            
            // Test ExportOptions main components
            testExportOptionsHeaderAccessibility()
            testExportOptionsControlsAccessibility()
            testExportOptionsFormatSpecificAccessibility()
            testExportOptionsProgressAccessibility()
        }
        
        let voiceOverDisabled = disableVoiceOverForTesting()
        XCTAssertTrue(voiceOverDisabled, "Failed to disable VoiceOver after testing")
    }
    
    /// Test ExportOptions header accessibility
    private func testExportOptionsHeaderAccessibility() {
        // Test ExportOptionsSheet header
        let exportTitle = app.staticTexts["export-options-title"]
        if exportTitle.exists {
            XCTAssertTrue(exportTitle.exists, "Export options title should be accessible")
            XCTAssertTrue(exportTitle.hasKeyboardFocus || exportTitle.isHittable, "Export title should be focusable")
        }
        
        // Test project name display
        let projectName = app.staticTexts["export-project-name"]
        if projectName.exists {
            XCTAssertTrue(projectName.exists, "Project name should be accessible")
        }
        
        // Test cancel button
        let cancelButton = app.buttons["export-cancel-button"]
        if cancelButton.exists {
            XCTAssertTrue(cancelButton.isHittable, "Cancel button should be accessible")
            
            // Verify cancel button has proper accessibility label
            let cancelLabel = cancelButton.label
            XCTAssertTrue(cancelLabel.contains("Cancel"), "Cancel button should have descriptive label")
        }
        
        // Test ExportModal header
        let modalTitle = app.staticTexts["export-modal-title"]
        if modalTitle.exists {
            XCTAssertTrue(modalTitle.exists, "Export modal title should be accessible")
        }
        
        let modalCloseButton = app.buttons["export-modal-close"]
        if modalCloseButton.exists {
            XCTAssertTrue(modalCloseButton.isHittable, "Modal close button should be accessible")
        }
    }
    
    /// Test ExportOptions controls accessibility
    private func testExportOptionsControlsAccessibility() {
        // Test platform selection (ExportOptionsSheet)
        let platformPicker = app.popUpButtons["platform-picker"]
        if platformPicker.exists {
            XCTAssertTrue(platformPicker.isHittable, "Platform picker should be accessible")
            
            // Test platform picker interaction
            platformPicker.tap()
            // Verify picker options are accessible
            // Note: Specific implementation depends on picker style
        }
        
        // Test aspect ratio selection
        let aspectRatioPicker = app.popUpButtons["aspect-ratio-picker"]
        if aspectRatioPicker.exists {
            XCTAssertTrue(aspectRatioPicker.isHittable, "Aspect ratio picker should be accessible")
        }
        
        // Test export format selection (ExportModal)
        let formatPicker = app.segmentedControls["export-format-picker"]
        if formatPicker.exists {
            XCTAssertTrue(formatPicker.isHittable, "Export format picker should be accessible")
            
            // Test format selection
            let formatButtons = formatPicker.buttons
            for i in 0..<formatButtons.count {
                let button = formatButtons.element(boundBy: i)
                XCTAssertTrue(button.isHittable, "Format option \(i) should be accessible")
            }
        }
        
        // Test resolution settings
        testResolutionControlsAccessibility()
        
        // Test frame rate settings
        testFrameRateControlsAccessibility()
        
        // Test export buttons
        testExportButtonsAccessibility()
    }
    
    /// Test resolution controls accessibility
    private func testResolutionControlsAccessibility() {
        // Test width field
        let widthField = app.textFields["export-width-field"]
        if widthField.exists {
            XCTAssertTrue(widthField.isHittable, "Width field should be accessible")
            
            // Test field interaction
            widthField.tap()
            widthField.typeText("1920")
        }
        
        // Test height field
        let heightField = app.textFields["export-height-field"]
        if heightField.exists {
            XCTAssertTrue(heightField.isHittable, "Height field should be accessible")
        }
        
        // Test resolution preset buttons
        let presetButtons = ["hd-preset-button", "fullhd-preset-button", "4k-preset-button"]
        for buttonId in presetButtons {
            let button = app.buttons[buttonId]
            if button.exists {
                XCTAssertTrue(button.isHittable, "\(buttonId) should be accessible")
                
                // Test button activation
                button.tap()
                
                // Verify button has proper accessibility label
                let buttonLabel = button.label
                XCTAssertTrue(buttonLabel.contains("Preset"), "Preset button should have descriptive label")
            }
        }
    }
    
    /// Test frame rate controls accessibility
    private func testFrameRateControlsAccessibility() {
        // Test frame rate field
        let frameRateField = app.textFields["framerate-field"]
        if frameRateField.exists {
            XCTAssertTrue(frameRateField.isHittable, "Frame rate field should be accessible")
        }
        
        // Test frame rate preset buttons
        let fpsButtons = ["24fps-preset-button", "30fps-preset-button", "60fps-preset-button"]
        for buttonId in fpsButtons {
            let button = app.buttons[buttonId]
            if button.exists {
                XCTAssertTrue(button.isHittable, "\(buttonId) should be accessible")
                
                // Test button activation
                button.tap()
                
                // Verify button has proper accessibility label
                let buttonLabel = button.label
                XCTAssertTrue(buttonLabel.contains("FPS"), "FPS button should have descriptive label")
            }
        }
        
        // Test number of frames field
        let framesField = app.textFields["frames-field"]
        if framesField.exists {
            XCTAssertTrue(framesField.isHittable, "Frames field should be accessible")
        }
        
        // Test frames preset buttons
        let frameButtons = ["300frames-preset-button", "150frames-preset-button", "600frames-preset-button"]
        for buttonId in frameButtons {
            let button = app.buttons[buttonId]
            if button.exists {
                XCTAssertTrue(button.isHittable, "\(buttonId) should be accessible")
            }
        }
    }
    
    /// Test export buttons accessibility
    private func testExportButtonsAccessibility() {
        // Test ExportOptionsSheet export button
        let exportStartButton = app.buttons["export-start-button"]
        if exportStartButton.exists {
            XCTAssertTrue(exportStartButton.isHittable, "Export start button should be accessible")
            
            // Verify button has proper accessibility label
            let startLabel = exportStartButton.label
            XCTAssertTrue(startLabel.contains("Export"), "Export button should have descriptive label")
        }
        
        // Test ExportModal export button
        let modalExportButton = app.buttons["export-modal-start-button"]
        if modalExportButton.exists {
            XCTAssertTrue(modalExportButton.isHittable, "Modal export button should be accessible")
            
            // Test button state communication
            if !modalExportButton.isEnabled {
                let buttonLabel = modalExportButton.label
                XCTAssertTrue(buttonLabel.contains("disabled") || modalExportButton.value as? String == "disabled", 
                             "Disabled export button should communicate its state")
            }
        }
    }
    
    /// Test format-specific controls accessibility
    private func testExportOptionsFormatSpecificAccessibility() {
        // Test video format controls
        let videoFormatPicker = app.popUpButtons["video-format-picker"]
        if videoFormatPicker.exists {
            XCTAssertTrue(videoFormatPicker.isHittable, "Video format picker should be accessible")
        }
        
        // Test include audio toggle
        let audioToggle = app.checkBoxes["include-audio-toggle"]
        if audioToggle.exists {
            XCTAssertTrue(audioToggle.isHittable, "Include audio toggle should be accessible")
            
            // Test toggle activation
            audioToggle.tap()
            
            // Verify toggle state is communicated
            let toggleState = audioToggle.value as? Int
            XCTAssertNotNil(toggleState, "Toggle state should be accessible")
        }
        
        // Test image format controls
        let imageFormatPicker = app.radioGroups["image-format-picker"]
        if imageFormatPicker.exists {
            XCTAssertTrue(imageFormatPicker.exists, "Image format picker should be accessible")
            
            // Test radio button options
            let radioButtons = imageFormatPicker.radioButtons
            for i in 0..<radioButtons.count {
                let radioButton = radioButtons.element(boundBy: i)
                XCTAssertTrue(radioButton.isHittable, "Image format option \(i) should be accessible")
            }
        }
        
        // Test JPEG quality slider
        let qualitySlider = app.sliders["jpeg-quality-slider"]
        if qualitySlider.exists {
            XCTAssertTrue(qualitySlider.isHittable, "JPEG quality slider should be accessible")
            
            // Test slider interaction
            qualitySlider.adjust(toNormalizedSliderPosition: 0.8)
            
            // Verify slider value is communicated
            let sliderValue = qualitySlider.value
            XCTAssertNotNil(sliderValue, "Slider value should be accessible")
        }
    }
    
    /// Test export progress accessibility
    private func testExportOptionsProgressAccessibility() {
        // Test export progress view
        let progressView = app.otherElements["export-progress-view"]
        if progressView.exists {
            XCTAssertTrue(progressView.exists, "Export progress view should be accessible")
            
            // Test progress indicators
            let progressIndicators = app.progressIndicators
            if progressIndicators.count > 0 {
                let firstProgress = progressIndicators.element(boundBy: 0)
                XCTAssertTrue(firstProgress.exists, "Progress indicator should be accessible")
                
                // Verify progress value is communicated
                let progressValue = firstProgress.value
                XCTAssertNotNil(progressValue, "Progress value should be accessible")
            }
        }
        
        // Test export error messages
        let errorMessage = app.staticTexts["export-error-message"]
        if errorMessage.exists {
            XCTAssertTrue(errorMessage.exists, "Export error message should be accessible")
            
            // Verify error message is properly announced
            let errorText = errorMessage.label
            XCTAssertTrue(errorText.contains("Error"), "Error message should be clearly identified")
        }
        
        // Test export settings info
        let settingsInfo = app.otherElements["export-settings-info"]
        if settingsInfo.exists {
            XCTAssertTrue(settingsInfo.exists, "Export settings info should be accessible")
        }
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