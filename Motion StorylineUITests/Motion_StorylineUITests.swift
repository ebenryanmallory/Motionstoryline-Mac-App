//
//  Motion_StorylineUITests.swift
//  Motion StorylineUITests
//
//  Created by rpf on 2/25/25.
//

import XCTest

final class Motion_StorylineUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    @MainActor
    func testKeyboardNavigationInTimeline() throws {
        // Launch the application
        let app = XCUIApplication()
        app.launch()
        
        // Create a new project or open an existing one
        let newProjectButton = app.buttons["New Project"]
        if newProjectButton.exists {
            newProjectButton.click()
        }
        
        // Wait for the design canvas to appear
        let timeline = app.groups["timeline-view"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 5), "Timeline view did not appear")
        
        // Test spacebar for play/pause
        // First, ensure the timeline has focus
        timeline.click()
        
        // Press spacebar to play
        app.typeKey(.space, modifierFlags: [])
        
        // Verify playback has started (the play button should change to pause)
        let pauseButton = app.buttons["pause-button"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 2), "Animation did not start playing")
        
        // Press spacebar again to pause
        app.typeKey(.space, modifierFlags: [])
        
        // Verify playback has stopped
        let playButton = app.buttons["play-button"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 2), "Animation did not stop playing")
        
        // Test left/right arrow keys for frame navigation
        // Move to previous frame with left arrow
        app.typeKey(.leftArrow, modifierFlags: [])
        
        // Verify timeline position changed
        // This would need a way to check the current time value, which depends on the UI implementation
        
        // Move to next frame with right arrow
        app.typeKey(.rightArrow, modifierFlags: [])
        
        // Test adding a keyframe with "K" key
        // First select an element to animate
        let canvasElement = app.groups["canvas-elements"].children(matching: .any).element(boundBy: 0)
        canvasElement.click()
        
        // Press K to add a keyframe at current position
        app.typeKey("k", modifierFlags: [])
        
        // Verify a keyframe was added
        let keyframeIndicator = timeline.images["keyframe-indicator"]
        XCTAssertTrue(keyframeIndicator.exists, "Keyframe was not added with K shortcut")
        
        // Test jumping to next keyframe with tab
        app.typeKey(.tab, modifierFlags: [])
        
        // Test jumping to previous keyframe with shift+tab
        app.typeKey(.tab, modifierFlags: [.shift])
        
        // Test stopping playback with escape key
        // First start playback again
        app.typeKey(.space, modifierFlags: [])
        
        // Then press escape
        app.typeKey(.escape, modifierFlags: [])
        
        // Verify playback stopped
        XCTAssertTrue(playButton.waitForExistence(timeout: 2), "Animation did not stop with escape key")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
