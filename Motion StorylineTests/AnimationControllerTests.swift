//
//  AnimationControllerTests.swift
//  Motion StorylineTests
//
//  Created by rpf on 5/12/25.
//

import XCTest
import SwiftUI
@testable import Motion_Storyline

final class AnimationControllerTests: XCTestCase {
    var animationController: AnimationController!
    
    override func setUpWithError() throws {
        animationController = AnimationController()
        animationController.setup(duration: 5.0)
    }
    
    override func tearDownWithError() throws {
        animationController = nil
    }
    
    // MARK: - Controller Setup Tests
    
    func testInitialState() {
        XCTAssertEqual(animationController.currentTime, 0.0)
        XCTAssertEqual(animationController.duration, 5.0)
        XCTAssertFalse(animationController.isPlaying)
        XCTAssertEqual(animationController.getAllTracks().count, 0)
    }
    
    func testSetup() {
        animationController.setup(duration: 10.0)
        XCTAssertEqual(animationController.duration, 10.0)
        XCTAssertEqual(animationController.currentTime, 0.0)
    }
    
    // MARK: - Track Management Tests
    
    func testAddTrack() {
        var capturedValue: Double?
        let track = animationController.addTrack(id: "position.x") { (value: Double) in
            capturedValue = value
        }
        
        // Test track was added
        XCTAssertNotNil(track)
        XCTAssertEqual(track.id, "position.x")
        XCTAssertEqual(animationController.getAllTracks().count, 1)
        XCTAssertTrue(animationController.getAllTracks().contains("position.x"))
        
        // Test the callback works
        _ = track.add(keyframe: Keyframe(time: 0.0, value: 100.0))
        animationController.updateAnimatedProperties()
        XCTAssertEqual(capturedValue, 100.0)
    }
    
    func testGetTrack() {
        let originalTrack = animationController.addTrack(id: "opacity") { (_: Double) in }
        
        // Add a keyframe to the original track
        _ = originalTrack.add(keyframe: Keyframe(time: 0.0, value: 0.5))
        
        // Test retrieving the track
        guard let retrievedTrack = animationController.getTrack(id: "opacity") as Motion_Storyline.KeyframeTrack<Double>? else {
            XCTFail("Failed to retrieve track")
            return
        }
        
        XCTAssertEqual(retrievedTrack.id, "opacity")
        XCTAssertEqual(retrievedTrack.allKeyframes.count, 1)
        XCTAssertEqual(retrievedTrack.allKeyframes[0].time, 0.0)
        XCTAssertEqual(retrievedTrack.allKeyframes[0].value, 0.5)
    }
    
    func testRemoveTrack() {
        let _ = animationController.addTrack(id: "scale") { (_: Double) in }
        
        XCTAssertEqual(animationController.getAllTracks().count, 1)
        
        animationController.removeTrack(id: "scale")
        
        XCTAssertEqual(animationController.getAllTracks().count, 0)
        XCTAssertNil(animationController.getTrack(id: "scale") as Motion_Storyline.KeyframeTrack<Double>?)
    }
    
    // MARK: - Keyframe Tests
    
    func testAddKeyframe() {
        let track = animationController.addTrack(id: "position.y") { (_: Double) in }
        
        let added = animationController.addKeyframe(trackId: "position.y", time: 1.0, value: 200.0, easingFunction: .easeIn)
        
        XCTAssertTrue(added)
        XCTAssertEqual(track.allKeyframes.count, 1)
        XCTAssertEqual(track.allKeyframes[0].time, 1.0)
        XCTAssertEqual(track.allKeyframes[0].value, 200.0)
        
        // Test adding a keyframe at the same time fails
        let duplicateAdded = animationController.addKeyframe(trackId: "position.y", time: 1.0, value: 300.0)
        XCTAssertFalse(duplicateAdded)
        
        // Test adding to non-existent track fails
        let nonExistentAdded = animationController.addKeyframe(trackId: "nonexistent", time: 1.0, value: 100.0)
        XCTAssertFalse(nonExistentAdded)
    }
    
    func testRemoveKeyframe() {
        let track = animationController.addTrack(id: "rotation") { (_: Double) in }
        
        // Add keyframes
        _ = animationController.addKeyframe(trackId: "rotation", time: 0.0, value: 0.0)
        _ = animationController.addKeyframe(trackId: "rotation", time: 2.5, value: 180.0)
        
        XCTAssertEqual(track.allKeyframes.count, 2)
        
        // Remove a keyframe
        let removed = animationController.removeKeyframe(trackId: "rotation", time: 2.5)
        
        XCTAssertTrue(removed)
        XCTAssertEqual(track.allKeyframes.count, 1)
        
        // Test removing from non-existent track
        let nonExistentRemoved = animationController.removeKeyframe(trackId: "nonexistent", time: 0.0)
        XCTAssertFalse(nonExistentRemoved)
        
        // Test removing non-existent keyframe
        let noKeyframeRemoved = animationController.removeKeyframe(trackId: "rotation", time: 3.0)
        XCTAssertFalse(noKeyframeRemoved)
    }
    
    func testGetAllKeyframeTimes() {
        // Add multiple tracks with keyframes at different times
        let positionTrack = animationController.addTrack(id: "position") { (_: CGPoint) in }
        let opacityTrack = animationController.addTrack(id: "opacity") { (_: Double) in }
        let colorTrack = animationController.addTrack(id: "color") { (_: Color) in }
        
        _ = positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 0, y: 0)))
        _ = positionTrack.add(keyframe: Keyframe(time: 2.0, value: CGPoint(x: 100, y: 100)))
        
        _ = opacityTrack.add(keyframe: Keyframe(time: 0.0, value: 0.0))
        _ = opacityTrack.add(keyframe: Keyframe(time: 1.0, value: 0.5))
        _ = opacityTrack.add(keyframe: Keyframe(time: 3.0, value: 1.0))
        
        _ = colorTrack.add(keyframe: Keyframe(time: 1.5, value: Color.red))
        _ = colorTrack.add(keyframe: Keyframe(time: 4.0, value: Color.blue))
        
        let allTimes = animationController.getAllKeyframeTimes()
        
        // Should get times from all tracks, sorted, without duplicates
        XCTAssertEqual(allTimes, [0.0, 1.0, 1.5, 2.0, 3.0, 4.0])
    }
    
    // MARK: - Interpolation Tests
    
    func testLinearInterpolation() {
        var value: Double = 0.0
        
        let track = animationController.addTrack(id: "test") { (newValue: Double) in
            value = newValue
        }
        
        _ = track.add(keyframe: Keyframe(time: 1.0, value: 0.0, easingFunction: .linear))
        _ = track.add(keyframe: Keyframe(time: 3.0, value: 100.0, easingFunction: .linear))
        
        // Test values at specific positions
        animationController.currentTime = 1.0
        animationController.updateAnimatedProperties()
        XCTAssertEqual(value, 0.0)
        
        animationController.currentTime = 2.0
        animationController.updateAnimatedProperties()
        XCTAssertEqual(value, 50.0)
        
        animationController.currentTime = 3.0
        animationController.updateAnimatedProperties()
        XCTAssertEqual(value, 100.0)
    }
    
    func testEasingFunctions() {
        var value: Double = 0.0
        
        let track = animationController.addTrack(id: "test") { (newValue: Double) in
            value = newValue
        }
        
        // Test easeIn
        _ = track.add(keyframe: Keyframe(time: 0.0, value: 0.0, easingFunction: .easeIn))
        _ = track.add(keyframe: Keyframe(time: 2.0, value: 100.0))
        
        animationController.currentTime = 0.0
        animationController.updateAnimatedProperties()
        XCTAssertEqual(value, 0.0)
        
        animationController.currentTime = 1.0
        animationController.updateAnimatedProperties()
        // With easeIn, the value at 50% time should be less than 50% of the way
        XCTAssertLessThan(value, 50.0)
        
        // Test easeOut by replacing keyframes
        track.removeKeyframe(at: 0.0)
        track.removeKeyframe(at: 2.0)
        
        _ = track.add(keyframe: Keyframe(time: 0.0, value: 0.0, easingFunction: .easeOut))
        _ = track.add(keyframe: Keyframe(time: 2.0, value: 100.0))
        
        animationController.currentTime = 1.0
        animationController.updateAnimatedProperties()
        // With easeOut, the value at 50% time should be more than 50% of the way
        XCTAssertGreaterThan(value, 50.0)
    }
    
    func testCustomBezierEasing() {
        var value: Double = 0.0
        
        let track = animationController.addTrack(id: "test") { (newValue: Double) in
            value = newValue
        }
        
        let customBezier = EasingFunction.customCubicBezier(x1: 0.7, y1: 0.0, x2: 0.3, y2: 1.0)
        _ = track.add(keyframe: Keyframe(time: 0.0, value: 0.0, easingFunction: customBezier))
        _ = track.add(keyframe: Keyframe(time: 2.0, value: 100.0))
        
        animationController.currentTime = 1.0
        animationController.updateAnimatedProperties()
        
        // Just verify we get some value from the custom bezier
        XCTAssertGreaterThan(value, 0.0)
        XCTAssertLessThan(value, 100.0)
    }
    
    // MARK: - Playback Tests
    
    func testPlaybackState() {
        XCTAssertFalse(animationController.isPlaying)
        
        animationController.play()
        XCTAssertTrue(animationController.isPlaying)
        
        animationController.pause()
        XCTAssertFalse(animationController.isPlaying)
        
        animationController.reset()
        XCTAssertFalse(animationController.isPlaying)
        XCTAssertEqual(animationController.currentTime, 0.0)
    }
    
    // MARK: - Different Property Type Tests
    
    func testDifferentPropertyTypes() {
        // Using _ to address warning about unused variables
        _ = animationController.addTrack(id: "point") { (newValue: CGPoint) in }
        
        _ = animationController.addTrack(id: "size") { (newValue: CGFloat) in }
        
        _ = animationController.addTrack(id: "color") { (newValue: Color) in }
        
        XCTAssertEqual(animationController.getAllTracks().count, 3)
        XCTAssertTrue(animationController.getAllTracks().contains("point"))
        XCTAssertTrue(animationController.getAllTracks().contains("size"))
        XCTAssertTrue(animationController.getAllTracks().contains("color"))
    }
} 