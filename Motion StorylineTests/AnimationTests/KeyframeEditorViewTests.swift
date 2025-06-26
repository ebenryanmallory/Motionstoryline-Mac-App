import XCTest
import SwiftUI
@testable import Motion_Storyline

final class KeyframeEditorViewTests: XCTestCase {
    // Test properties
    var animationController: AnimationController!
    var testElement: CanvasElement!
    
    override func setUpWithError() throws {
        // Create a fresh animation controller for each test
        animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        // Create a test element with known properties
        testElement = CanvasElement(
            type: .rectangle,
            position: CGPoint(x: 200, y: 300),
            size: CGSize(width: 150, height: 100),
            rotation: 45.0,
            opacity: 0.8,
            color: .blue,
            displayName: "Test Rectangle"
        )
    }
    
    override func tearDownWithError() throws {
        animationController = nil
        testElement = nil
    }
    
    /// Test that tracks are properly created when an element is selected
    func testTrackCreationForSelectedElement() throws {
        // Create a KeyframeEditorView with our test element
        let view = KeyframeEditorView(
            animationController: animationController,
            selectedElement: .constant(testElement)
        )
        
        // Manually simulate the onAppear and onChange behavior
        view.setupTracksForSelectedElement(testElement)
        
        // Get the track IDs that should have been created
        let idPrefix = testElement.id.uuidString
        let positionTrackId = "\(idPrefix)_position"
        let sizeTrackId = "\(idPrefix)_size"
        let rotationTrackId = "\(idPrefix)_rotation"
        let colorTrackId = "\(idPrefix)_color"
        let opacityTrackId = "\(idPrefix)_opacity"
        
        // Verify that all expected tracks were created
        XCTAssertTrue(animationController.hasTrack(id: positionTrackId), "Position track not created")
        XCTAssertTrue(animationController.hasTrack(id: sizeTrackId), "Size track not created")
        XCTAssertTrue(animationController.hasTrack(id: rotationTrackId), "Rotation track not created")
        XCTAssertTrue(animationController.hasTrack(id: colorTrackId), "Color track not created")
        XCTAssertTrue(animationController.hasTrack(id: opacityTrackId), "Opacity track not created")
        
        // Verify that tracks contain initial keyframes at time 0
        let posTrack = animationController.getTrack(id: positionTrackId) as? Motion_Storyline.KeyframeTrack<CGPoint>
        let sizeTrack = animationController.getTrack(id: sizeTrackId) as? Motion_Storyline.KeyframeTrack<CGFloat>
        let rotTrack = animationController.getTrack(id: rotationTrackId) as? Motion_Storyline.KeyframeTrack<Double>
        let colorTrack = animationController.getTrack(id: colorTrackId) as? Motion_Storyline.KeyframeTrack<Color>
        let opacityTrack = animationController.getTrack(id: opacityTrackId) as? Motion_Storyline.KeyframeTrack<Double>
        
        XCTAssertTrue(posTrack?.allKeyframes.contains(where: { $0.time == 0.0 }) ?? false, "Position track missing initial keyframe")
        XCTAssertTrue(sizeTrack?.allKeyframes.contains(where: { $0.time == 0.0 }) ?? false, "Size track missing initial keyframe")
        XCTAssertTrue(rotTrack?.allKeyframes.contains(where: { $0.time == 0.0 }) ?? false, "Rotation track missing initial keyframe")
        XCTAssertTrue(colorTrack?.allKeyframes.contains(where: { $0.time == 0.0 }) ?? false, "Color track missing initial keyframe")
        XCTAssertTrue(opacityTrack?.allKeyframes.contains(where: { $0.time == 0.0 }) ?? false, "Opacity track missing initial keyframe")
    }
    
    /// Test that tracks update when a different element is selected
    func testTrackUpdateWithElementChange() throws {
        // Create a KeyframeEditorView with our test element
        let view = KeyframeEditorView(
            animationController: animationController,
            selectedElement: .constant(testElement)
        )
        
        // Setup tracks for the first element
        view.setupTracksForSelectedElement(testElement)
        
        // Create a second element with different properties
        let secondElement = CanvasElement(
            type: .ellipse,
            position: CGPoint(x: 400, y: 500),
            size: CGSize(width: 200, height: 200),
            rotation: 90.0,
            opacity: 0.5,
            color: .red,
            displayName: "Test Circle"
        )
        
        // Setup tracks for the second element
        view.setupTracksForSelectedElement(secondElement)
        
        // Get the track IDs for the second element
        let idPrefix = secondElement.id.uuidString
        let positionTrackId = "\(idPrefix)_position"
        
        // Verify that the tracks for the second element were created
        XCTAssertTrue(animationController.hasTrack(id: positionTrackId), "Position track for second element was not created")
    }
    
    /// Test that the correct properties are created for the element
    func testPropertiesForSelectedElement() throws {
        // Create a view model with our test element
        let view = KeyframeEditorView(
            animationController: animationController,
            selectedElement: .constant(testElement)
        )
        
        // Access the properties computed property
        let properties = view.properties
        
        // Verify that we get the correct number of properties
        XCTAssertEqual(properties.count, 5, "Should have 5 properties for a rectangle element")
        
        // Verify the property types
        XCTAssertEqual(properties[0].type, .position, "First property should be position")
        XCTAssertEqual(properties[1].type, .size, "Second property should be size")
        XCTAssertEqual(properties[2].type, .rotation, "Third property should be rotation")
        XCTAssertEqual(properties[3].type, .color, "Fourth property should be color")
        XCTAssertEqual(properties[4].type, .opacity, "Fifth property should be opacity")
        
        // Verify property names
        XCTAssertEqual(properties[0].name, "Position", "First property should be named Position")
        XCTAssertEqual(properties[1].name, "Size", "Second property should be named Size")
        XCTAssertEqual(properties[2].name, "Rotation", "Third property should be named Rotation")
        XCTAssertEqual(properties[3].name, "Color", "Fourth property should be named Color") 
        XCTAssertEqual(properties[4].name, "Opacity", "Fifth property should be named Opacity")
        
        // Verify property IDs contain the element's UUID
        let idPrefix = testElement.id.uuidString
        for property in properties {
            XCTAssertTrue(property.id.contains(idPrefix), "Property ID should contain the element UUID")
        }
    }
    
    /// Test that keyframe data is correctly populated and accessible in the UI
    func testKeyframeDataPopulation() throws {
        // Setup a view with our test element
        let view = KeyframeEditorView(
            animationController: animationController,
            selectedElement: .constant(testElement)
        )
        
        // Setup the tracks
        view.setupTracksForSelectedElement(testElement)
        
        // Get the track IDs
        let idPrefix = testElement.id.uuidString
        let positionTrackId = "\(idPrefix)_position"
        let rotationTrackId = "\(idPrefix)_rotation"
        
        // Add some test keyframes at different times
        let position1 = CGPoint(x: 200, y: 300) // Initial position
        let position2 = CGPoint(x: 300, y: 400) // New position at 2.0s
        let rotation1 = 45.0 // Initial rotation
        let rotation2 = 90.0 // New rotation at 2.0s
        
        // Add new keyframes
        animationController.addKeyframe(trackId: positionTrackId, time: 2.0, value: position2)
        animationController.addKeyframe(trackId: rotationTrackId, time: 2.0, value: rotation2)
        
        // Get all keyframe times from animation controller
        let allKeyframeTimes = animationController.getAllKeyframeTimes()
        
        // Verify keyframe times are properly populated
        XCTAssertEqual(allKeyframeTimes.count, 2, "Should have keyframes at 2 time points (0.0 and 2.0)")
        XCTAssertTrue(allKeyframeTimes.contains(0.0), "Should have a keyframe at time 0.0")
        XCTAssertTrue(allKeyframeTimes.contains(2.0), "Should have a keyframe at time 2.0")
        
        // Test position track keyframes
        let positionTrack = animationController.getTrack(id: positionTrackId) as? Motion_Storyline.KeyframeTrack<CGPoint>
        XCTAssertNotNil(positionTrack, "Failed to get position track")
        
        if let posTrack = positionTrack {
            // Check that position keyframes have correct values
            let positionKeyframes = posTrack.allKeyframes
            XCTAssertEqual(positionKeyframes.count, 2, "Position track should have 2 keyframes")
            
            let posKeyframe0 = positionKeyframes.first(where: { $0.time == 0.0 })
            let posKeyframe2 = positionKeyframes.first(where: { $0.time == 2.0 })
            
            XCTAssertNotNil(posKeyframe0, "Position track should have keyframe at time 0.0")
            XCTAssertNotNil(posKeyframe2, "Position track should have keyframe at time 2.0")
            XCTAssertEqual(posKeyframe0?.value, position1, "Position keyframe at time 0.0 should have correct value")
            XCTAssertEqual(posKeyframe2?.value, position2, "Position keyframe at time 2.0 should have correct value")
        }
        
        // Test rotation track keyframes
        let rotationTrack = animationController.getTrack(id: rotationTrackId) as? Motion_Storyline.KeyframeTrack<Double>
        XCTAssertNotNil(rotationTrack, "Failed to get rotation track")
        
        if let rotTrack = rotationTrack {
            // Check that rotation keyframes have correct values
            let rotationKeyframes = rotTrack.allKeyframes
            XCTAssertEqual(rotationKeyframes.count, 2, "Rotation track should have 2 keyframes")
            
            let rotKeyframe0 = rotationKeyframes.first(where: { $0.time == 0.0 })
            let rotKeyframe2 = rotationKeyframes.first(where: { $0.time == 2.0 })
            
            XCTAssertNotNil(rotKeyframe0, "Rotation track should have keyframe at time 0.0")
            XCTAssertNotNil(rotKeyframe2, "Rotation track should have keyframe at time 2.0")
            XCTAssertEqual(rotKeyframe0?.value, rotation1, "Rotation keyframe at time 0.0 should have correct value")
            XCTAssertEqual(rotKeyframe2?.value, rotation2, "Rotation keyframe at time 2.0 should have correct value")
        }
        
        // Ensure animations work by seeking to midpoint and checking interpolated values
        animationController.seekToTime(1.0) // Halfway between keyframes
        
        // Get the interpolated position value at time 1.0 (should be halfway between positions)
        let expectedMidPosition = CGPoint(
            x: position1.x + (position2.x - position1.x) * 0.5,
            y: position1.y + (position2.y - position1.y) * 0.5
        )
        
        if let posTrack = positionTrack, let midPositionValue = posTrack.getValue(at: 1.0) {
            // Allow for small floating point differences
            XCTAssertEqual(midPositionValue.x, expectedMidPosition.x, accuracy: 0.001, "Position X should be correctly interpolated")
            XCTAssertEqual(midPositionValue.y, expectedMidPosition.y, accuracy: 0.001, "Position Y should be correctly interpolated")
        } else {
            XCTFail("Failed to get interpolated position value")
        }
        
        // Get the interpolated rotation value (should be halfway between rotations)
        let expectedMidRotation = rotation1 + (rotation2 - rotation1) * 0.5
        
        if let rotTrack = rotationTrack, let midRotationValue = rotTrack.getValue(at: 1.0) {
            XCTAssertEqual(midRotationValue, expectedMidRotation, accuracy: 0.001, "Rotation should be correctly interpolated")
        } else {
            XCTFail("Failed to get interpolated rotation value")
        }
    }
    

} 